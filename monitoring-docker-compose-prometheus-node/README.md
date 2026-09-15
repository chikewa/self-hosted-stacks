# Prometheus and node_exporter in Docker: Metrics Monitoring for a Home Server


> Two containers that turn a running home server into a measured one: Prometheus pulls CPU, memory, disk and network metrics on a schedule, node_exporter exposes them, and you get the first alerts that matter.

**Full guide:** [https://chikewa.com/2026/09/08/monitoring-docker-compose-prometheus-node/](https://chikewa.com/2026/09/08/monitoring-docker-compose-prometheus-node/) · **Category:** Docker & Linux · **Published:** 2026-09-08

---

You can tell a home server is running because a service answers. You cannot tell it is running *well* — CPU climbing, a disk filling, a service that has been restarting every night for a month — unless something is measuring it. That is what Prometheus is for: it pulls metrics from your systems on a schedule, stores them as time-series data, and gives you a query language plus a dashboard to look back over hours, days or months. Paired with the node_exporter agent (which exposes CPU, memory, disk and network stats for the machine it runs on), you get the foundation of a proper monitoring stack in two containers. This guide runs both with Docker Compose and sets up the first meaningful alerts.

*Intermediate · 11 min · Docker*

Everything here was tested on a Debian 12 mini PC with Docker 29.7. I verified the exact metric names, the scrape handshake, and the resource footprint of both containers, and the compose files below are what I ran.

## How Prometheus works (the pull model)

Unlike a monitoring agent that phones home, Prometheus *pulls*: every 15 seconds (the default) it visits a list of targets and asks each one for its current metrics at a `/metrics` endpoint. Each target is a “job”. The data is stored in a local time-series database, and queries use PromQL, a small language for slicing that data (“CPU usage over the last hour”, “disk free bytes on /”). Two consequences of the pull model are worth understanding. First, Prometheus must be able to *reach* each target — if a target is behind NAT or on a different network, the scrape fails and you get a gap. Second, the “is it up?” signal comes free: if Prometheus cannot scrape a target, the target is down, and that is your first and most important alert.

node_exporter is the standard exporter for Linux machines. It is a tiny Go binary that exposes about 2,000 metrics from the kernel: per-core CPU, memory, disk I/O, filesystem usage, network counters, load average, and more. One container of node_exporter on a host is enough to see whether that machine is healthy.

## The compose file

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "127.0.0.1:9090:9090"
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    pid: host
    network_mode: host
    command:
      - "--path.rootfs=/host"
    volumes:
      - /:/host:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro

volumes:
  prometheus-data:
```

Three things in that file are not obvious and each one matters.

**node_exporter uses `network_mode: host` and `pid: host`.** A container normally has its own network namespace, in which case node_exporter would report the container’s (empty) network and nothing about the real host. Running it on the host network makes it see the host’s interfaces, and `pid: host` plus the `--path.rootfs=/host` flag with the read-only `/`, `/proc` and `/sys` mounts make it read the host’s filesystem and kernel stats rather than the container’s. This is the standard way to run node_exporter in Docker and it is the most common reason a first setup reports near-zero, meaningless numbers — the exporter was looking at its own tiny namespace instead of the machine.

**Prometheus keeps its database in a named volume.** The `prometheus-data` volume is your metric history. Delete it and you lose all past data (queries further back than the retention window stop working). Back it up if the history matters to you, or accept that monitoring data is ephemeral.

**The config is mounted read-only.** `prometheus.yml` is the only file you edit day to day — adding a target, changing the scrape interval. Mounting it `:ro` keeps the container from writing to it, and Prometheus reloads it when the file changes (add `--web.enable-lifecycle` to the command, or simply restart the container after an edit; on a home box a restart is simpler and safe).

## The configuration: two jobs

The `prometheus.yml` I tested:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: "node"
    static_configs:
      # node_exporter runs on the host network: use the Docker bridge
      # gateway (172.17.0.1 by default) or the host's LAN IP
      - targets: ["172.17.0.1:9100"]
```

The first job is Prometheus scraping itself — it is on by default in most configs and is useful because “Prometheus up” is the baseline you compare everything else against. The second job points at node_exporter. Because node_exporter runs on the host network, it is *not* at `127.0.0.1` as seen from a Prometheus container on the Docker bridge — inside that container, 127.0.0.1 is the container itself, not your machine. The reachable address is the Docker bridge gateway (find it with `docker network inspect bridge`, commonly `172.17.0.1`) or the host’s LAN IP. In my lab I used the bridge gateway, and that is the value in the compose above. If the node job shows as down, this is the almost-certain cause, and it is purely an addressing detail, not a bug.

## Verifying it works, and the first useful queries

Open `http://<server-ip>:9090`. Click **Targets**: both jobs should be green with a last-scrape timestamp. That one screen tells you the whole pipeline is alive. Then try a few queries in the console (the box at the top of the UI).

- `up` — returns 1 for every target Prometheus can scrape, 0 if it cannot. This is your up/down signal.

- `1 - node_load1` — not load itself but a common way to see headroom; for raw load use `node_load1`.

- `node_memory_MemAvailable_bytes` — how much RAM the host has free, in bytes. Divide by `1024^3` for GiB.

- `node_filesystem_avail_bytes{mountpoint="/"}` — free space on the root disk. This is the one to alert on (see below).

- `rate(node_network_receive_bytes_total[5m])` — network throughput in bytes/sec over the last five minutes. The `rate()` function is the workhorse of PromQL for any per-second counter.

If a query returns no data, the metric name is usually slightly off — Prometheus will autocomplete as you type, and the autocomplete is the fastest way to learn the exact names (they differ between exporter versions).

## The first two alerts worth having

Full alerting needs a third piece (Alertmanager), but two conditions are important enough that you can start by just watching them in the UI, and wire up Alertmanager later. First, `up == 0` for the node job means the exporter — and effectively the machine’s monitoring — is gone; that is a “is my server even on?” alert. Second, a low free-disk expression such as `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} < 0.10` means the root filesystem is under 10% free — the failure that actually takes home servers down, because a full disk stops Docker, stops logs, and cascades. Both are single-line PromQL you can add to a dashboard now and promote to a real alert later.

## Common gotchas

**The node job is permanently down.** Addressing, as above: node_exporter on the host network is not at `127.0.0.1` from a bridge-network container. Use the host’s LAN IP. Confirm by hitting `http://<host-ip>:9100/metrics` from the host itself first — if that works, it is purely the target address in `prometheus.yml`.

**Metrics are all near zero or missing.** node_exporter is reading its own container namespace, which means the `pid: host` / `--path.rootfs` / host-network setup above was not applied. A host’s CPU should show real load; if every `node_cpu_*` value is ~0 while you know the machine is busy, the exporter is not looking at the host.

**Disk usage grows and queries slow down.** Prometheus stores every scraped series. With a few hundred metrics and a 15-second interval it is modest, but it grows linearly with time and with the number of targets. Set a `--storage.tsdb.retention.time` (e.g. `30d`) so the database stops growing without bound, and size the volume accordingly.

**You add Grafana next and it cannot find Prometheus.** Grafana and Prometheus must be able to reach each other’s ports. If both are in the same compose file / network, use the service name (`prometheus:9090`) as the Prometheus server URL in the Grafana datasource, not `localhost` — inside Grafana’s container, `localhost` is Grafana itself.

## How this fits the rest of your home server

Prometheus plus node_exporter is the measurement layer under everything else you run. It answers a different question from the simple “is this URL up?” monitors — Prometheus tells you *how* the machine was behaving in the hours before something stopped, not just that it stopped. Add an exporter per service you care about (each popular app has one) and the same `prometheus.yml` pattern from this guide is how you register them. Keep the whole stack reachable only on the LAN or over a VPN such as Tailscale, and back up the `prometheus-data` volume with the approach in the [3-2-1 backup guide](https://chikewa.com/backup-strategy-3-2-1-restic/) if your metric history is worth keeping. For context on whether your hardware will handle the extra load, the [hardware guide](https://chikewa.com/what-hardware-for-a-home-server/) has the measured CPU and disk numbers from the same box used in these tests.

Tested on:

OSDebian 12Docker29.7.2Hardware4-core / 16 GBSoftwarePrometheus 3.14.0 + node_exporter 1.12.1Last tested: 3 September 2026

## What’s next?
The natural next steps from this guide:

- [The 3-2-1 backup strategy for a home server](https://chikewa.com/backup-strategy-3-2-1-restic/)
- [What hardware for a home server?](https://chikewa.com/what-hardware-for-a-home-server/)
- [The self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)
- **`prometheus.yml`** — Prometheus scrape/evaluation config


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).