# The Self-Hosting Starter Guide: From Zero to a Working Home Server


> Go from a blank Linux machine to a working home server: pick your hardware, install Docker and run a tested three-app starter stack — RSS reader, music server and private wiki.

**Full guide:** [https://chikewa.com/2026/08/23/self-hosting-starter-guide/](https://chikewa.com/2026/08/23/self-hosting-starter-guide/) · **Category:** Getting Started · **Published:** 2026-08-23

---

Beginner · 10 min · Linux · Docker

**Tested on:**

OS
Ubuntu 24.04 LTS (Debian 12 works too)

Docker
29

Hardware
4-core x86, 16 GB RAM

Software
Starter stack (Miniflux, PostgreSQL 16, Navidrome, DokuWiki) 

Last tested: 22 August 2026

## On this page

- [Why self-host at all?](#why-self-host-at-all)

- [Step 1: Choose your hardware](#step-1-choose-your-hardware)

- [Step 2: Install an operating system](#step-2-install-an-operating-system)

- [Step 3: Install Docker](#step-3-install-docker)

- [Step 4: Pick your first stack](#step-4-pick-your-first-stack)

- [Step 5: Run the stack](#step-5-run-the-stack)

- [Step 6: The three first-run tasks](#step-6-the-three-first-run-tasks)

- [Measured resource usage](#measured-resource-usage)

- [What comes next](#what-comes-next)

- [Frequently asked questions](#frequently-asked-questions)

You do not need a rack of servers to start self-hosting. You need one machine, Docker, and a few well-chosen applications. This guide takes you from a blank Linux machine to a working home server with a working RSS reader, a personal music server, and a private wiki — every file tested on real hardware.

## Why self-host at all?

Every month you pay for another subscription, you are renting someone else’s computer. Self-hosting flips the model: you buy the hardware once (or reuse what you already have) and run the software yourself. The benefits, in order of how they matter to real users:

- **Your data stays yours.** Photos, music, notes, and feeds live on your disk, on your terms, with your backup strategy.

- **No subscription fatigue.** A home server running four services costs a few pounds per month in electricity, not four monthly fees that keep going up.

- **Privacy by architecture.** Your reading habits, your playlists, and your notes never pass through a company that may change its policies tomorrow.

- **You actually learn infrastructure.** Networking, containers, reverse proxies, backups — the skills transfer directly to paid work.

The honest trade-offs: you are the IT department now. Updates, outages, and security patches are your responsibility. A home server also needs a real IP address or a workaround (Tailscale, Cloudflare Tunnel) to be reached from outside your house — we cover that in the security series.

## Step 1: Choose your hardware

You have three sensible starting points, depending on budget:

#### Option A: Repurpose an old PC (free)

Any x86 machine from roughly the last decade works as a starter server. The practical minimum: 8 GB of RAM, a solid-state drive (even a cheap SATA SSD makes a huge difference), and a power supply you trust. Old desktops are the classic choice, and a single 60 W machine idling costs roughly £15–25 per year at UK rates.

#### Option B: Raspberry Pi 5 (around £80–100)

The 16 GB model is the sweet spot for a starter stack: it runs the apps in this guide comfortably, idles around 5 W, and fits on a shelf. Use a quality case with active cooling and a 2.5″ SATA SSD via the HAT if you plan to store media — the Pi’s microSD slot will die on you under sustained writes.

#### Option C: Used mini PC (around £150–250)

Used Intel NUCs, Dell OptiPlexes, and HP Elites from office clearances offer x86 performance at a fraction of the price of new hardware. This is the best bang-per-pound if you want headroom for media transcoding later.

## Step 2: Install an operating system

For a dedicated server, use a minimal Linux install rather than a desktop:

- **Debian 12 (bookworm):** the safest default. Minimal install, no desktop, extremely stable, huge community.

- **Ubuntu Server 24.04 LTS:** the friendlier choice if you want the most tutorials to match. Also an excellent default.

- **Truenas Scale or Proxmox:** skip these for your first server. They add virtualisation and ZFS, which are powerful but premature until you know what you are running.

During installation: give the machine a fixed IP on your LAN (or reserve one in your router’s DHCP table), and set a hostname like `server`. You will not want to remember a changing IP.

## Step 3: Install Docker

Docker packages software into containers: isolated environments that start in seconds, take up only what they use, and are identical on any Linux machine. This is what makes self-hosting actually manageable instead of a tangle of system packages.

On Debian or Ubuntu, the official install is a few lines:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc echo \ "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \ https://download.docker.com/linux/$(. /etc/os-release && echo $ID) \ $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \ sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Then add your user to the docker group so you stop typing `sudo`:

```bash
sudo usermod -aG docker $USER
# log out and back in, then verify:
docker compose version
```

If that command prints a version number, you are ready.

## Step 4: Pick your first stack

This is the part most guides get wrong. They hand you a list of forty apps and you spend two weeks configuring Sonarr and Prowlarr before you have used anything. Start with three services that you will actually touch every day:

App
What it does
Why first

**Miniflux**
RSS reader — aggregates every feed you follow
Instant daily value; your reading no longer depends on an algorithm

**Navidrome**
Personal music server — streams your library to any device
One folder, one app, works with the official Substreamer app

**DokuWiki**
Plain-text wiki for notes and documentation
Zero-friction writing; your notes are files on disk, not a proprietary format

Each of these has a dedicated guide on this site with the exact compose file, tested setup steps, and the real errors we hit along the way:

- [Self-hosting Miniflux with Docker (including the Postgres SSL error that stops first-timers)](https://chikewa.com/self-host-miniflux-docker-compose/)

- [Navidrome: a self-hosted alternative to Spotify and Apple Music](https://chikewa.com/navidrome-docker-compose-guide/)

- [DokuWiki in Docker: a private wiki without the setup pain](https://chikewa.com/dokuwiki-docker-compose-private-wiki/)

## Step 5: Run the stack

Everything below was verified on a 4-core / 16 GB Ubuntu machine with Docker 29. Create a project directory:

```bash
mkdir -p ~/stacks/starter/music && cd ~/stacks/starter
```

Drop in a `docker-compose.yml` with the three services (full annotated files in each linked guide):

```yaml
services:
  miniflux:
    image: miniflux/miniflux:latest
    container_name: miniflux
    environment:
      DATABASE_URL: postgres://miniflux:***@miniflux-db/miniflux?sslmode=disable
      BASE_URL: http://localhost:8082
    ports:
      - "8082:8080"
    depends_on:
      - miniflux-db
    restart: unless-stopped

  miniflux-db:
    image: postgres:16-alpine
    container_name: miniflux-db
    environment:
      POSTGRES_USER: miniflux
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: miniflux
    volumes:
      - miniflux_db:/var/lib/postgresql/data
    restart: unless-stopped

  navidrome:
    image: deluan/navidrome:latest
    container_name: navidrome
    ports:
      - "4533:4533"
    environment:
      ND_SCANSCHEDULE: 1h
      ND_LOGLEVEL: info
    volumes:
      - ./music:/music:ro
      - navidrome_data:/data
    restart: unless-stopped

  dokuwiki:
    image: dokuwiki/dokuwiki:stable
    container_name: dokuwiki
    ports:
      - "8081:80"
    volumes:
      - dokuwiki_data:/dokuwiki/data
      - dokuwiki_conf:/dokuwiki/conf
    restart: unless-stopped

volumes:
  miniflux_db:
  navidrome_data:
  dokuwiki_data:
  dokuwiki_conf:
```

Then start it:

```bash
docker compose up -d
docker compose ps
```

All four containers should show `Up`. The ports: Miniflux on `:8082`, DokuWiki on `:8081`, Navidrome on `:4533`. Open them from your laptop on the same network: `http://SERVER_IP:8082`, and so on.

## Step 6: The three first-run tasks

- **Miniflux:** first visit asks you to create the admin account. Then add feeds — start with the 10 you actually read. If the container keeps restarting with `pq: SSL is not enabled on the server`, your DATABASE_URL is missing `?sslmode=disable` (full fix in the Miniflux guide).

- **Navidrome:** put MP3/FLAC files in the `music/` folder, then create your first account at `:4533`. It scans the library on first login. The official mobile app (Substreamer) pairs in one minute.

- **DokuWiki:** first visit runs a tiny config wizard (admin login, language). That is the whole setup.

## Measured resource usage

Because we run this stack, here is what it actually costs, measured with `docker stats` after a day of normal use (RSS polling, a music session, some wiki edits):

Container
Idle RAM
Idle CPU

miniflux
17 MiB
~0%

miniflux-db (Postgres)
38 MiB
~0%

navidrome
26 MiB
~0%

dokuwiki
25 MiB
~0%

**Total: about 106 MiB of RAM** for a full starter stack. A Raspberry Pi 5 with 4 GB has 40× the headroom this needs. The real cost of this stack is the electricity of the machine it lives on — which you were already paying.

## What comes next

Once these three are boring (the goal), the natural expansion path is:

- **Nextcloud** or **Immich** for photos and files (see the NAS & Media section)

- **AdGuard Home** for network-wide ad and tracker blocking (Security & Networking)

- **A reverse proxy** (Caddy or Nginx Proxy Manager) plus Tailscale, so the stack is reachable from anywhere without opening ports on your router — this is the single highest-value upgrade after the starter stack, and we cover it in the security series

- **Monitoring**: Uptime Kuma, so your server tells you it is down instead of you finding out

## Frequently asked questions

#### Is self-hosting safe if I am not a security expert?

Yes, with discipline: keep Docker updated, use a reverse proxy with TLS instead of exposing ports, and do not expose admin interfaces directly to the internet. The starter stack above is LAN-only, which is the safe default. Our [Security & Networking](https://chikewa.com/category/security-networking/) guides cover hardening step by step.

#### Docker or Kubernetes?

Docker Compose. Kubernetes on a home server is solving a problem you do not have. You will use 90% of what Compose gives you for 10% of the complexity.

#### Can I run this on a VPS instead of at home?

The same compose file runs unchanged on a VPS — that is part of Docker’s point. A VPS is a fine starting point if your home connection is bad or your ISP blocks inbound connections. 

#### What about the initial hardware cost?

If you already own a spare PC, the marginal cost is electricity (a few pounds a month). A Raspberry Pi 5 path is around £100–150 all-in. After that, most services are free software. That is the whole pitch: one small fixed cost instead of an open-ended subscription stack.

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).