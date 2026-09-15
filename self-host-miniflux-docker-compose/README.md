# How to Self-Host Miniflux with Docker: Compose File and the Postgres SSL Fix


> Deploy Miniflux with Docker Compose: the exact compose file, first-run setup, and the Postgres SSL error that stops most first-timers — plus the fix.

**Full guide:** [https://chikewa.com/2026/08/23/self-host-miniflux-docker-compose/](https://chikewa.com/2026/08/23/self-host-miniflux-docker-compose/) · **Category:** Docker & Linux · **Published:** 2026-08-23

---

Beginner · 7 min · Docker · PostgreSQL

**Tested on:**

OS
Any Linux (verified on Debian 12)

Docker
29.7

Hardware
4-core x86, 16 GB RAM

Software
Miniflux (latest) + PostgreSQL 16 

Last tested: 22 August 2026

## On this page

- [What is Miniflux, and why it beats the alternatives](#what-is-miniflux-and-why-it-beats-the-alternatives)

- [Prerequisites](#prerequisites)

- [Step 1: The compose file](#step-1-the-compose-file)

- [Step 2: Start it](#step-2-start-it)

- [Step 3: The restart loop (and the fix)](#step-3-the-restart-loop-and-the-fix)

- [Step 4: First-run setup](#step-4-first-run-setup)

- [Step 5: Use it from your phone](#step-5-use-it-from-your-phone)

- [Resource usage (measured)](#resource-usage-measured)

- [Updating](#updating)

- [FAQ](#faq)

Miniflux is the fastest, lightest RSS reader you can run for yourself: a single Go binary plus a database, idling at about 17 MB of RAM. This guide deploys it with Docker Compose on any Linux machine — and documents the exact error that stops most first-timers, because that is the error we hit too.

## What is Miniflux, and why it beats the alternatives

Miniflux is a minimalist RSS reader written in Go. You point it at your feeds, and it polls, stores, and serves them in a fast interface. The account model is deliberately simple: create users, add feeds, read. No accounts, no cloud, no subscription.

Compared to the other common self-hosted readers:

Miniflux
FreshRSS
Selfoss

Idle RAM (measured)
~17 MiB
~80–150 MiB (PHP-FPM)
~50 MiB

Setup complexity
1 container + Postgres
1 container (PHP) + optional DB
1 container + DB

Mobile clients
Any RSS app + built-in mobile view
Any RSS app
Limited

Update cadence
Frequent, stable
Frequent
Slower

If you want a heavy-featured reader with plugins, FreshRSS is a fine choice. For a low-maintenance daily driver, Miniflux is hard to beat.

## Prerequisites

- A machine with Docker and the Compose plugin (`docker compose version` should print a version)

- A free TCP port on your LAN (this guide uses `8082` — change it if yours is taken)

## Step 1: The compose file

```bash
mkdir -p ~/stacks/miniflux && cd ~/stacks/miniflux
```

Create `docker-compose.yml`:

```yaml
services:
  miniflux:
    image: miniflux/miniflux:latest
    container_name: miniflux
    environment:
      DATABASE_URL: postgres://miniflux:secret@miniflux-db/miniflux?sslmode=disable
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

volumes:
  miniflux_db:
```

Three things in that file matter, and two of them trip people up:

- `?sslmode=disable` at the end of the DATABASE_URL — the current image attempts an SSL connection by default. Without this parameter the container enters a restart loop (see Step 3).

- `secret` as the password is fine for a LAN-only deployment, but if this server ever reaches the internet behind a proxy, change it to something real.

- `BASE_URL` is used for redirects and feed links. Set it to whatever address you will actually type in the browser.

## Step 2: Start it

```bash
docker compose up -d
docker compose ps
```

Both containers should show `Up`. Wait ten seconds, then open `http://YOUR_SERVER_IP:8082` (or `http://localhost:8082` if you are on the same machine).

## Step 3: The restart loop (and the fix)

If instead you see `Restarting` in `docker compose ps`, check the logs:

```bash
docker logs miniflux
```

If the output repeats `pq: SSL is not enabled on the server`, the container is talking to Postgres with SSL on and Postgres has it off. The fix is the `?sslmode=disable` parameter on the DATABASE_URL line, which the compose file above already includes. If you are reading this guide because of that error, that one parameter is the fix.

#### Edge case: schema version mismatch

A second, rarer message is `the database schema is not up to date: current=v0 expected=vNNN`. This happens when a fresh database is created but the first container run aborts before migrations. Running the image once with migrations forced clears it:

```bash
docker run --rm --network miniflux_default \
  -e DATABASE_URL="postgres://miniflux:secret@miniflux-db/miniflux?sslmode=disable" \
  -e RUN_MIGRATIONS=true miniflux/miniflux:latest
```

That command runs the migrations and then starts the server (leave it running until the DB is migrated, or stop it after a few seconds) — after which the compose-managed container starts cleanly. (We hit this during testing; it is not part of the normal path, but it is the other error that appears in every Miniflux+Postgres thread.)

## Step 4: First-run setup

The first visit shows the setup page. Create your admin account — Miniflux generates an initial password it shows you once (or sets one you choose, depending on version).

Then:

- Add your first feed: paste an RSS URL into the “Add feed” field. If a site has no visible RSS link, try appending `/feed`, `/rss`, or `/atom.xml` to its URL, or use a feed-directory site to find it.

- Add the 10–15 feeds you actually read. Resist adding 200 — a full feed list you never finish is the same as not reading.

- Check “Polling interval” in settings: the default is hourly, which is plenty. Faster polling on a small machine just costs CPU for no reading benefit.

## Step 5: Use it from your phone

Miniflux speaks the standard `/api/v1` RSS reader API. Any of these clients work:

- **Reeder (iOS/macOS)** — connect to your server URL, use the API

- **NetNewsWire (macOS/iOS)** — same

- **Fluss (Android)** — the most polished free option on Android

- **The built-in mobile view** — Miniflux serves a decent mobile UI at `/m`, which is honestly good enough for daily use

## Resource usage (measured)

Container
Idle RAM
Notes

miniflux
17.2 MiB
Go binary, one process

postgres:16-alpine
37.6 MiB
Alpine image keeps it small

Both together: under 55 MiB at idle. A 1 GB Raspberry Pi can run this and still have room for a few more services.

## Updating

Miniflux migrates its own schema on startup, so updating is:

```bash
docker compose pull
docker compose up -d
```

Your data lives in the `miniflux_db` volume and survives every update. Back it up with `docker run --rm -v miniflux_db:/data miniflux/miniflux:latest psql ...` or, more simply, `docker exec miniflux-db pg_dumpall > backup.sql` on a cron schedule. (We have a dedicated backups guide in the pipeline.)

## FAQ

#### Does Miniflux work without Postgres?

It also supports SQLite and MySQL, but Postgres is the recommended production database and the one used here. SQLite is fine for a single-user test, but the image’s default expectations are Postgres-centric.

#### Can I add multiple users?

Yes — from the admin panel. Each user gets their own feeds and reading state, which makes Miniflux work as a small family reader.

#### Should I expose port 8082 to the internet?

No. Keep it on the LAN and reach it remotely via Tailscale or a reverse proxy with authentication — see the [Security & Networking](https://chikewa.com/category/security-networking/) guides. RSS readers are a magnet for credential-stuffing bots the moment they are publicly reachable.

#### Where does this fit in a bigger setup?

In our [self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/), Miniflux is one of the three first services, alongside Navidrome and DokuWiki.

## What’s next?

Miniflux is now polling your feeds on its own. From here:

- [Self-hosting Starter Guide: the full path from hardware to a working server](https://chikewa.com/self-hosting-starter-guide/)

- [Navidrome in Docker: add your own music server](https://chikewa.com/navidrome-docker-compose-guide/)

- [DokuWiki in Docker: a private wiki on plain-text files](https://chikewa.com/dokuwiki-docker-compose-private-wiki/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).