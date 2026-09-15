# Caddy in Docker: Reverse Proxy with Automatic HTTPS for Self-Hosted Services


> One readable Caddyfile, automatic Let’s Encrypt certificates, and a single small container in front of all your services. A tested compose setup plus the multi-site routing patterns that actually work.

**Full guide:** [https://chikewa.com/2026/09/06/caddy-docker-compose/](https://chikewa.com/2026/09/06/caddy-docker-compose/) · **Category:** Docker & Linux · **Published:** 2026-09-06

---

Every self-hosted service starts life behind a raw IP and port: `http://192.168.1.42:8084`. It works, but it is not the web you are used to — no HTTPS, no domain name, no sensible routing. A reverse proxy sits in front of your services and fixes all three: it owns your domain (or a local one), terminates TLS, and routes each hostname to the right container. Caddy is the reverse proxy I recommend for home servers because the configuration is a single readable file and, if you point a real domain at it, HTTPS certificates are obtained and renewed automatically with zero configuration. This guide runs Caddy in Docker Compose and walks through a Caddyfile that actually serves multiple self-hosted services.

*Intermediate · 10 min · Docker*

Everything here was tested on a Debian 12 mini PC with Docker 29.7. In the lab I test plain HTTP routing (no domain, no certificate), and I flag exactly where your setup will differ once you have a domain and a public IP.

## What Caddy does for you

A reverse proxy receives requests on ports 80 (HTTP) and 443 (HTTPS) and forwards them to the services on your network based on the host name in the request. Three things make Caddy a good fit for a home server. First, the `Caddyfile` is plain, human-readable configuration — you will understand every line in the example below. Second, automatic HTTPS: if you configure a real domain, Caddy requests a Let’s Encrypt certificate for it on first use, stores it, and renews it before expiry. There is no cron job to write and no certificate to babysit. Third, it is a single small static binary in the `caddy` image — no database, no plugin system, fast to start and easy to restart when you edit the file.

The flip side to understand: automatic HTTPS needs two things that a LAN-only test does not have — a domain that points at the machine, and inbound 80/443 reaching it. For purely internal use (you browse services by name on your own network), you can run Caddy in plain-HTTP mode, which is what the lab test below does.

## The compose file

```yaml
services:
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "127.0.0.1:8083:80"
      - "127.0.0.1:8443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    environment:
      - TZ=Europe/London

volumes:
  caddy_data:
  caddy_config:
```

Two volumes are the only persistent state. `caddy_data` stores the TLS certificates it obtains (empty in the lab test); `caddy_config` stores Caddy’s internal JSON representation of your Caddyfile. The Caddyfile itself is mounted read-only, so editing it on disk and reloading is the normal workflow. The port mapping here binds to loopback on remapped ports for the lab; on a real server with a domain you would map `"80:80"` and `"443:443"` so Caddy can receive HTTP (for certificate challenges) and HTTPS from the internet.

## A Caddyfile that routes several services

Here is the file I tested. In the lab it responds to any host name on port 80 with a plain text marker, which proves the container is listening and routing. On a real deployment you replace the placeholder sites with your actual host names.

```text
# Lab: prove Caddy serves on :80 with a fixed response.
:80 {
    respond "caddy-lab-ok" 200
}
```

The production-shaped version for a home server with a domain looks like this. Each block is one host name; Caddy matches the incoming `Host` header and proxies to the matching upstream. Upstream addresses use Docker service names when the services are on the same Docker network as Caddy (add Caddy to that network), or the server’s LAN IP otherwise.

```text
cloud.example.com {
    reverse_proxy nextcloud:80
}

vault.example.com {
    reverse_proxy vaultwarden:80
    encode zstd gzip
}

status.example.com {
    reverse_proxy uptime-kuma:3001
}
```

Notice how little is there. No certificate directives: because these are real domains, Caddy obtains and renews the certificates automatically. The `encode` line is optional compression. If you do not yet have a public domain, the common home approach is to use `.local` or `.lan` names with a plain-HTTP site block (the `:80` style, or `cloud.local` without a certificate), and add the domain + HTTPS later when you want the service reachable outside the house.

One routing detail that saves pain: put Caddy on the same custom Docker network as the services it proxies. Then `reverse_proxy nextcloud:80` resolves via Docker’s built-in DNS. If Caddy is on the default bridge and your apps are on a custom network (or vice versa), the service name will not resolve and you will get 502s — the most common first-run error with a reverse proxy.

## Reloading the configuration

Caddy watches `/etc/caddy/Caddyfile` inside the container. When you edit the mounted file, Caddy performs a zero-downtime reload automatically — you do not need to restart the container. You can also trigger it explicitly:

```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

If your edit has a syntax error, the reload fails and Caddy keeps serving the last valid configuration (it does not go down). Check `docker logs caddy` for the specific line that is wrong. This behaviour is why a reverse proxy is safer to configure live than, say, a system nginx on a production box — a typo does not take the site offline.

## Common gotchas

**502 Bad Gateway immediately after adding a site.** Caddy is running but cannot reach the upstream. Almost always a network problem: Caddy and the target service are not on the same Docker network, so the service name does not resolve. Verify from inside Caddy: `docker exec caddy getent hosts nextcloud`. If that fails, join the networks (or use the LAN IP).

**Certificates never appear even though you configured a real domain.** Caddy could not complete the HTTP-01 challenge: inbound port 80 is not reaching the container, the domain’s A record does not point at the machine, or a router in between is terminating/altering HTTP. Confirm `curl -v http://yourdomain` from the internet reaches Caddy before expecting a certificate. On CGNAT or without a public IP, automatic HTTPS via HTTP-01 will not work; use DNS-01 (with a DNS provider token in the Caddyfile) or serve it internally and reach the service over a VPN such as Tailscale.

**Your service redirects to http:// and loops.** Some apps (Nextcloud in particular) detect they are behind a proxy and, unless told the external host, generate URLs with the wrong scheme or name. Set the app’s “trusted domain” and “overwrite protocol” to the public host name — for Nextcloud that means `trusted_domains` plus `overwrite.cli.url` in its config. If the loop persists, temporarily set `trusted_proxies` to your proxy’s address so the app sees the correct `X-Forwarded-For`.

**Port 80 is already used on the host.** If you have another service publishing 80 (a host nginx, a Pi-hole with a web UI on 80), Caddy cannot also bind it. Remap Caddy to a different host port for testing, or move the other service off 80 — but note that Let’s Encrypt’s HTTP-01 challenge specifically needs 80, so a permanent remap breaks automatic HTTPS for the HTTP challenge.

## How this fits the rest of your home server

Caddy is the front door that lets you run many services under one domain without a tangle of ports. Pair it with the [SSH and firewall guide](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/) to keep only 80, 443 and SSH reachable, and everything else internal. If you would rather not expose ports at all, the [Cloudflare Tunnel guide](https://chikewa.com/cloudflare-tunnel-docker-compose/) is the complementary no-port-forwarding path. For internal DNS so your service names resolve cleanly on the LAN, point your devices at a self-hosted resolver such as AdGuard Home or Pi-hole, and for the bigger picture of how to choose what to run, the [self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/).

Tested on:

OSDebian 12Docker29.7.2Hardware4-core / 16 GBSoftwareCaddy 2.11.4Last tested: 3 September 2026

## What’s next?
The natural next steps from this guide:

- [The self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/)
- [Secure your home server: SSH, firewall and Docker networks](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)
- [Cloudflare Tunnel: no-port-forwarding access](https://chikewa.com/cloudflare-tunnel-docker-compose/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)
- **`Caddyfile`** — Caddy reverse-proxy config with automatic HTTPS
- **`Caddyfile`** — Caddy reverse-proxy config with automatic HTTPS


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).