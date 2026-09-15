# Cloudflare Tunnel in Docker: No-Port-Forwarding Access Guide


> Cloudflare Tunnel is the cleanest answer to “how do I reach my home server from outside without opening ports”: a small container on your server makes an outbound connection to Cloudflare’s edge, and every request to your domain is carried over that encrypted channel. No port forwarding, no public IP required behind NAT, and TLS […]

**Full guide:** [https://chikewa.com/2026/08/30/cloudflare-tunnel-docker-compose/](https://chikewa.com/2026/08/30/cloudflare-tunnel-docker-compose/) · **Category:** Security & Networking · **Published:** 2026-08-30

---

Cloudflare Tunnel is the cleanest answer to “how do I reach my home server from outside without opening ports”: a small container on your server makes an outbound connection to Cloudflare’s edge, and every request to your domain is carried over that encrypted channel. No port forwarding, no public IP required behind NAT, and TLS is handled at the edge. It is the access layer for everything else on this site — the vault, the dashboard, the media server — and it takes about fifteen minutes to set up. This guide covers the Docker Compose setup, named tunnels versus quick tunnels, routing multiple services, and the failure modes that actually happen.

*Intermediate · 12 min · Docker*

## How it works (in one paragraph)

Instead of the internet reaching your server, your server reaches out to Cloudflare. The `cloudflared` binary opens a persistent, authenticated connection to Cloudflare’s edge network. When a browser hits `ha.example.com`, Cloudflare’s edge accepts the TLS handshake and forwards the request down the tunnel to the container that registered itself as the handler for that host. Your router never sees an inbound connection, there is nothing to forward, and a CGNAT or dynamic-IP household works exactly the same as a fiber line with a static address.

The honest caveat: you are putting your services behind a third-party edge. Cloudflare sees the requests (it is, after all, your web host of record) and can be asked to be your provider’s problem in a way a self-hosted reverse proxy is not. For personal services with strong auth, the trade is almost always worth it. For anything sensitive enough to make that matter, the alternative is Tailscale, which keeps traffic entirely off third-party infrastructure — but it only works between devices you control.

## Prerequisites

- A free Cloudflare account with your domain added (the domain must use Cloudflare’s nameservers — the “orange cloud”)

- Docker + Compose plugin on the server

- A free TCP port is not needed — that is the point

## Step 1: Create the tunnel in the Cloudflare dashboard

- In the Cloudflare dashboard, select your domain, then go to **Network → Tunnels → Create a tunnel**.

- Choose **Docker** as the method. Cloudflare shows you a `cloudflared` container command with an install token — that token is everything, so copy it now.

- Name the tunnel (e.g. `home-server`) and confirm.

At this point Cloudflare has created a tunnel endpoint with no routes behind it. You are giving it a body next.

## Step 2: The compose file

```bash
mkdir -p ~/stacks/cloudflared && cd ~/stacks/cloudflared
```

Create `docker-compose.yml`:

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: CHANGE-ME-INSTALL-TOKEN
    restart: unless-stopped
```

Paste your install token into `TUNNEL_TOKEN` and start it:

```bash
docker compose up -d
docker compose logs -f cloudflared
```

You want to see `Connection to ... established` and `Registered tunnel connection`. The `--no-autoupdate` flag stops the binary from self-updating under your feet — you control updates with `docker compose pull`, which is the same discipline as every other stack on this site.

## Step 3: Point domains at local services

Back in the dashboard’s tunnel page, add **Public Hostname** entries — each one is a domain (or subdomain) mapped to a destination *inside your network*:

Public hostnameServiceDestination

`ha.example.com`Home Assistant`homeassistant:8123`
`vault.example.com`Vaultwarden`vaultwarden:80`
`photos.example.com`Immich`immich:2283`
`git.example.com`Gitea`gitea:3000`

The destination is a plain `host:port` as seen from the server’s network. Two details that bite people:

- **Service names, not 127.0.0.1, when they are containers on the same compose network.** If `cloudflared` and your services live in *different* compose projects (the usual case — each stack has its own directory), the service names are not resolvable. Use the server’s LAN IP (e.g. `192.168.1.10:8123`) or `host.docker.internal` where supported. The LAN-IP approach is the most predictable and is what the table above implies.

- **Ports are the container’s internal port.** Vaultwarden serves on `80` inside the container even though you mapped it to `8222` on the host. If you are routing by LAN IP, use the host-side port (`8222`); if by container name on a shared network, use the internal one (`80`). Pick one model and be consistent — mixing them is the #1 “502 error” cause.

Each new hostname resolves within seconds; no DNS work is needed because Cloudflare owns the zone. TLS certificates are issued automatically for every hostname, including wildcards if you want `*.example.com`.

## Step 4: Verify from outside

On your phone, on mobile data (not home Wi-Fi — you want to prove the path goes through the internet): open `https://ha.example.com`. You should get the Home Assistant login. If you get a `502` or `530` error, the tunnel is up but the destination is wrong — check the host/port model from Step 3 and the service’s own logs.

One more check that matters: make sure the services themselves are *not* reachable on the raw ports from the internet. The tunnel should be the only door. If you had port-forwarded 8222 earlier, remove it — a vault that is reachable both ways has two attack surfaces instead of one.

## Named tunnels vs quick tunnels

Cloudflare also offers `cloudflared tunnel --url http://localhost:8123` — a “quick tunnel” that gives you a random `*.trycloudflare.com` URL with zero dashboard setup. Use it for a ten-minute demo, never for anything permanent: the URL changes every restart, anyone who guesses it can reach the service, and there is no auth layer. Everything in this series runs on named tunnels with real domains.

## Routing multiple services: one tunnel or many?

One tunnel for the whole house is the right default. A single `cloudflared` container, a dozen public hostnames, one token to manage. The failure mode of many-tunnel setups is that you end up with three half-remembered tokens and no single place to see what is exposed. If you want to split things (a work stack, a guest stack), split by *tunnel*, and keep the public hostname list per tunnel short enough that you can read it in ten seconds.

What belongs behind a tunnel: anything with a login page — [Home Assistant](https://chikewa.com/homeassistant-docker-compose-guide/), [Vaultwarden](https://chikewa.com/vaultwarden-docker-compose/), [Immich](https://chikewa.com/immich-docker-compose-photo-library/), Gitea, dashboards. What should not: anything that streams bulk data at you daily. A full movie over the edge works, but it is a long way round; for heavy media access, Tailscale on the same devices is faster and free of the edge entirely. Run both: tunnel for convenience, Tailscale for bulk.

## Keeping it healthy

- **`restart: unless-stopped` is doing real work.** Tunnels drop under some network changes (ISP failover, router reboots). The container reconnects on its own; without the restart policy, one flapped connection means a dead URL until you notice.

- **Watch the dashboard’s connection count.** A healthy tunnel shows active connections. Zero, with the container running, usually means the token was rotated or the server’s outbound traffic is blocked.

- **Update deliberately**: `docker compose pull && docker compose up -d`. Cloudflared updates are frequent and the binary is small, but do it like everything else — when you have five minutes, not during an incident.

- **Keep the token out of git.** Anyone with the install token can rebind the tunnel. Treat it like the admin tokens in the other guides: env file, not repository.

## Resource usage (measured)

StateRAM

Idle (tunnel established, no traffic)~15–30 MiB
Sustained proxying of one busy service~50–80 MiB

It is the cheapest “infrastructure” in the whole stack: a few dozen megabytes that replace a router configuration, a certificate manager, and a dynamic-DNS account.

## FAQ

#### Do I still need the ports published in docker-compose?

Only for LAN access. If you use the tunnel URL from inside the house too (which you can — the traffic just takes a short detour through the edge), you can remove the published ports from the service stacks and the tunnel becomes the sole entry point. Many people keep both: LAN ports for speed on the couch, tunnel for everywhere else.

#### What happens if my home internet goes down?

Everything goes down — the tunnel, the services, the lot. This is not a Cloudflare limitation; it is physics. What the tunnel does remove is the whole class of “my IP changed / my port forwarding broke” failures, which is most of the real-world breakage.

#### Is the free tier enough?

Yes. Named tunnels are free, the certificate is free, and the bandwidth is the same as any other traffic through Cloudflare on your domain. The paid plans add analytics and enterprise controls you do not need for a home server.

#### Can I use this without my domain on Cloudflare?

No — the public hostname model requires the zone to be proxied by Cloudflare. If your domain lives elsewhere and you want no third-party edge at all, that is the Tailscale case: install it on the server and the clients, no domain required.

#### Where does this fit?

This is the door for the rest of the series: [Home Assistant](https://chikewa.com/homeassistant-docker-compose-guide/), [Vaultwarden](https://chikewa.com/vaultwarden-docker-compose/), [Immich](https://chikewa.com/immich-docker-compose-photo-library/), and Gitea all get stable HTTPS URLs from the one container in this guide. And the 3-2-1 backup strategy is what keeps the data behind the door from being the only copy you have.

## What’s next?
The natural next steps from this guide:

- [Vaultwarden behind the tunnel](https://chikewa.com/vaultwarden-docker-compose/)
- [Secure your home server: SSH, firewall and Docker](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)
- [The self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).