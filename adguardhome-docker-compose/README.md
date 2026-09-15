# AdGuard Home in Docker: Network-Level Ad Blocking for Your Home


> AdGuard Home turns your home server into the DNS resolver for the whole house and blocks ads and tracking at the name-lookup stage. One container, a tested compose file, and a working setup wizard walkthrough.

**Full guide:** [https://chikewa.com/2026/09/04/adguardhome-docker-compose/](https://chikewa.com/2026/09/04/adguardhome-docker-compose/) · **Category:** Security & Networking · **Published:** 2026-09-04

---

Your router is the front door of your whole network, and right now most of the traffic through it goes to a DNS resolver you have never chosen. AdGuard Home flips that: it becomes the DNS server for every device in your home, filters ads and tracking at the name-lookup stage, and gives you a web interface to tune exactly what gets blocked. It is one of the most popular first services people add to a home server, and for good reason — a single container handles DNS for the entire house, with almost no RAM.

*Beginner · 9 min · Docker*

This guide runs AdGuard Home with Docker Compose, walks through the first-run setup, and shows you how to point your devices at it. Everything here was tested on a real mini PC running Debian 12, and the exact compose file below is what I used.

## What AdGuard Home actually does

Every time an app on your phone looks up `example.com`, it asks a DNS resolver. Most resolvers are run by your ISP, and they will happily resolve `ads.doubleclick.net` along with everything else. AdGuard Home sits between your devices and the upstream resolvers (Google, Cloudflare, or whatever you pick), answers queries for your LAN, and checks each name against blocklists first. If the name is on a list, the query returns nothing and the ad never loads. If it is clean, the query passes through to your chosen upstream, and you get the normal answer.

Because filtering happens at DNS level, it works for apps that ignore regular browser ad blockers: system apps, game ads, video pre-roll, and the tracking calls baked into most mobile apps. It also gives you per-device control — a whitelist for the kid’s tablet, a stricter profile for the laptop, and so on.

## The compose file

Two things to understand before the file: the ports and the volumes. The web interface lives on port 3000 by default. DNS lives on port 53 — the same port your host may already use, so for lab testing I bind it to 5354 and note the change you’ll make on a real server. The two volumes are the only persistent state: `config/` holds the web interface database and settings, `filters/` holds the downloaded blocklists. Back those up and you can rebuild the container at any time.

```yaml
services:
  adguardhome:
    image: adguard/adguardhome:latest
    container_name: adguardhome
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:3000"
      - "127.0.0.1:5354:53/udp"
      - "127.0.0.1:5354:53/tcp"
    environment:
      - TZ=Europe/London
    volumes:
      - ./config:/opt/adguardhome/work
      - ./filters:/opt/adguardhome/filter
```

On a real home server you would change the DNS mapping to `"53:53/udp"` and `"53:53/tcp"` so devices can use it on the standard port. If 53 is already taken by something else (a host-level resolver, Pi-hole, Unbound), pick a free port on the host side, e.g. `"5354:53/udp"`, and use that port in your router’s DHCP settings instead. The container side stays 53 either way.

## First boot: the web setup wizard

Start the stack with `docker compose up -d`. On first launch the container generates its own DNS key material and builds the initial database, and the web server redirects *everything* to `/install.html` until you complete the one-time setup — you will see a log line like `webapi: This is the first launch of AdGuard Home, redirecting everything to /install.html`. That redirect is normal, not an error, and it is also the signal that the container is up and ready for you. In the lab the container was serving that page within a few seconds of starting.

Open `http://<server-ip>:3000` and you land on the install wizard. It asks you to set the admin username and password (do not skip this — it is the login for the control panel of your whole network) and the optional web access password used by the mobile app. Only once you finish this step does AdGuard Home start the actual DNS resolver on port 53 — before that, the port is bound but not answering queries, which is the single most confusing thing on first boot if you test DNS too early. After the wizard completes you land in the interface with a few things to do immediately:

- **Choose upstream DNS servers** (Settings → DNS → Upstream DNS). A sensible default pair is `9.9.9.9` and `149.112.112.112` (Quad9, which blocks known malicious domains out of the box).

- **Confirm the DNS listening port** is 53, or whatever you mapped on the host.

- **Enable a blocklist** (Filters → Blocklists). The built-in *AdGuard DNS filter* is enabled by default; adding *StevenBlack’s hosts* or *OISD* gives broader coverage.

## Pointing devices at AdGuard Home

You have two options. The clean one is to set the DNS server in your router’s DHCP configuration so every device that gets an address automatically uses AdGuard Home. The manual one is to set a static DNS on individual devices (e.g. the server’s LAN IP, or the port you remapped). I recommend DHCP as the default and static overrides only where you want a specific device to use different upstreams — AdGuard Home supports per-client DNS policies for exactly this.

Test it: on a phone, run a speed test or open `https://dns.google` — or simply run `dig @192.168.x.x example.com` from any machine that has `dig`. If you see the server IP in the answer’s server field, the device is querying AdGuard Home. Then open `ads.yourdomain.tld` or a known ad domain from the blocklist and confirm it fails to resolve.

## Performance: what it actually costs

AdGuard Home is a small Go binary. In my lab, freshly up and idle it held around 24 MiB of RAM, which is in line with the low single-digit-to-low-tens-of-MiB range people report under normal household load — it scales gently with query volume and, more, with how many blocklists you have loaded in memory. CPU was negligible — I did not see it register on the load average at all. The one thing to watch is blocklist size: each filter you enable is downloaded and kept in memory. With 4–5 popular filters enabled you are looking at a few hundred MiB of disk and a modest RAM increase; with 30+ aggressive filters, resolution latency goes up. Start with two or three filters, add more only when you notice a specific ad or tracker slipping through.

## Common gotchas

**Nothing resolves after pointing devices at it.** The container is up but DNS is not listening on the port you expect. Check `ss -ulnp | grep 53` inside the container or on the host — UDP, not just TCP, must be mapped. Most “it works on the server but not the LAN” problems are a missing `/udp` suffix.

**The web UI is slow or 404s after a while.** AdGuard Home rewrites some of its own files during first-run and updates. If you bind the config directory and the container restarts before finishing, the UI can be in a half-written state. Delete the `config/` directory and let it re-initialize; that is safe because it is only the first-run state.

**You want DoT or DoH from the container.** The image supports DNS-over-TLS (port 853) and DNS-over-HTTPS (port 80, which is why you see an optional `8085:80` mapping in some compose files). For a home-only setup you do not need them; enable DoH only if you are serving a public endpoint behind a reverse proxy, and make sure you are not also publishing 80 for another service on the same interface.

**Blocked domains you actually use.** Use the query log (in the web UI) to find the exact domain, then add it to the allowed list rather than disabling a whole filter. Per-device allow rules are the cleanest way to keep a strict global policy but relax it for one machine.

## How this fits the rest of your home server

AdGuard Home pairs naturally with the rest of a self-hosted stack. If you are exposing services on the web, the [Cloudflare Tunnel guide](https://chikewa.com/cloudflare-tunnel-docker-compose/) shows a no-port-forwarding way to reach them, while AdGuard Home keeps your internal DNS tidy so LAN names resolve without extra mapping. If you are worried about what happens when the server itself goes down, the [3-2-1 backup strategy guide](https://chikewa.com/backup-strategy-3-2-1-restic/) covers backing up the `config/` and `filters/` directories, which is all you need to restore this container fully. And if you have not hardened the box yet, the [SSH and firewall guide](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/) shows how to keep port 3000 off the public internet — it should only be reachable from your LAN or through a VPN. For the full list of services we have tested and written up, see [the software index](https://chikewa.com/software/).

Tested on:

OSDebian 12Docker29.7.2Hardware4-core / 16 GBSoftwareAdGuard Home 0.107.79Last tested: 3 September 2026

## What’s next?
The natural next steps from this guide:

- [Cloudflare Tunnel: no-port-forwarding access](https://chikewa.com/cloudflare-tunnel-docker-compose/)
- [The 3-2-1 backup strategy for a home server](https://chikewa.com/backup-strategy-3-2-1-restic/)
- [Secure your home server: SSH, firewall and Docker networks](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).