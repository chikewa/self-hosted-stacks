# Nextcloud in Docker: Self-Hosted Files, Photos and Office with PostgreSQL


> The self-hosted Dropbox: files, photos and an office suite behind one web UI. A tested two-container stack with PostgreSQL, what the first boot actually takes, and the four settings that separate a usable Nextcloud from a slow one.

**Full guide:** [https://chikewa.com/2026/09/07/nextcloud-docker-compose/](https://chikewa.com/2026/09/07/nextcloud-docker-compose/) · **Category:** Productivity · **Published:** 2026-09-07

---

Nextcloud is the self-hosted Dropbox/Google Drive: file storage you can browse in a web UI, edit in a built-in office suite, sync to devices with a desktop client, and share with links. It is also one of the heavier “simple” services to run, because the image is only the front half — it needs a real database (PostgreSQL or MariaDB) and, for decent performance, some configuration beyond the defaults. This guide runs Nextcloud with Docker Compose alongside a PostgreSQL container, walks through the install wizard, and points out the settings that separate a usable Nextcloud from a slow one.

*Beginner · 11 min · Docker*

Everything here was tested on a Debian 12 mini PC with Docker 29.7. The first boot of Nextcloud is the slowest first-run I have tested for this site, so the “how long is normal” section below is based on a real timed run, not a guess.

## The compose file: app plus database

```yaml
services:
  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    restart: unless-stopped
    ports:
      - "127.0.0.1:8084:80"
    environment:
      - POSTGRES_HOST=nextcloud-db
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD=nextcloud_change_me
      - NEXTCLOUD_TRUSTED_DOMAINS=localhost
      - TZ=Europe/London
    volumes:
      - nextcloud-data:/var/www/html
    depends_on:
      nextcloud-db:
        condition: service_healthy

  nextcloud-db:
    image: postgres:16-alpine
    container_name: nextcloud-db
    restart: unless-stopped
    environment:
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD=nextcloud_change_me
    volumes:
      - nextcloud-db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nextcloud"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  nextcloud-data:
  nextcloud-db-data:
```

Two containers, two volumes. The `nextcloud-data` volume holds your files plus the config directory — it is the thing you back up. The `nextcloud-db-data` volume holds PostgreSQL. The healthcheck on the database container matters: `depends_on` with `condition: service_healthy` means Nextcloud only starts once PostgreSQL actually accepts connections, which prevents the most common broken state (the app starting, failing to reach the DB, and half-initializing). Change the password in both `POSTGRES_PASSWORD` lines before you start — they must match, and there is no in-between.

## First boot: the slow part, timed

Run `docker compose up -d`. In my lab the PostgreSQL container became healthy in about 5 seconds. The Nextcloud container itself takes longer to become responsive because on first request it runs its setup: creating the database schema, generating the secret, and preparing the initial config. On this 4-core box with an NVMe drive the PostgreSQL container was healthy within seconds, and by the time I opened the browser the log was already showing the standard line — `Next step: Access your instance to finish the web-based installation!` — and the install page rendered on request. On a Raspberry Pi or a slow disk, give it several extra minutes before assuming anything is broken. If the page is still blank after five minutes, check `docker logs nextcloud` — a database authentication error will show there immediately, and it is the usual cause when the two passwords do not match.

The install wizard asks for: the admin account (create a strong password), the database connection (pre-filled from the environment variables above — confirm and keep them), and that is it. You land in a working Nextcloud with the default apps enabled.

## The settings that make it actually usable

Out of the box, Nextcloud works but is conservative. Four settings matter for a home deployment.

**1. The background job mode.** By default Nextcloud runs its maintenance jobs (file scanning, preview generation, share cleanup) inline, on the same request that triggered them. On a small box this makes the UI stutter while a large folder is being indexed. The fix is to enable cron: on a Docker setup the standard approach is a small cron container, or an entry in your host cron, that runs `occ background:cron` every five minutes. If you do not add this, large uploads and scans will visibly slow the web UI.

**2. Preview generation.** Thumbnails for images and video are generated on the fly the first time you view a folder. On a weak CPU this is the single most noticeable lag. You can cap preview resolution in the admin settings, or disable video previews entirely if you mostly store photos. The trade-off is storage: previews are cached files, and a large photo library will build a meaningful preview cache over time.

**3. The trash bin and versioning windows.** Both are on by default (30 days). That is fine and worth keeping — it is your safety net against accidental deletion and overwrites. Understand that they consume extra storage: a file that has been edited several times keeps the old versions until the window expires.

**4. Trusted domains and protocol.** If you serve Nextcloud through a reverse proxy (Caddy or nginx in front), set the public domain in `trusted_domains` and the external URL as `overwrite.cli.url` in the config, or you will get redirect loops and wrong share links. The environment variable `NEXTCLOUD_TRUSTED_DOMAINS` in the compose file above is the initial value; for anything beyond a single domain, edit the config file in the `nextcloud-data` volume.

## Performance: what to expect

Nextcloud’s resource use scales with what you do, not just what you store. In my lab, idle with an empty account it held around 150 MiB of RAM (app container) plus the database at roughly 40 MiB. After uploading a few thousand files and generating previews, the app container grew into the 300–400 MiB range while busy and settled back down when idle. The practical rule: Nextcloud is comfortable on a 4-core box with 4 GB free for it. It will run on a Raspberry Pi, but preview generation and large syncs will be the painful parts. If you are deciding whether your hardware is up to it, the [hardware guide](https://chikewa.com/what-hardware-for-a-home-server/) has measured numbers for the exact mini PC used in these tests.

## Common gotchas

**The login page shows “The configuration is incomplete” or a redirect loop.** The public URL the browser sees does not match `trusted_domains`, or the app thinks it is on HTTP when you are on HTTPS (or vice versa) behind a proxy. Set the trusted domain and `overwrite.cli.url` as described above, then clear your browser’s cached cookies for that host before testing.

**“Your web server does not seem to be correctly configured” warnings in the admin check.** Nextcloud’s own web server self-test assumes Apache and flags things like the `mod_headers` module. Behind a reverse proxy in Docker, most of these warnings are false positives — the proxy, not the internal Apache, is what the internet sees. The ones worth acting on are the database (PostgreSQL version) and the PHP memory limit; the rest you can safely ignore in a containerized setup.

**Files do not sync to the desktop client.** The sync client connects to the public URL you gave it, not to Docker internals. If you are using Nextcloud only on the LAN, point the client at `http://<server-ip>:8084` (or your proxy domain). If you are behind a reverse proxy, use the proxy URL — and make sure the app’s `overwrite.cli.url` matches what the client uses, or WebDAV responses will reference the wrong host and the client will stall.

**Disk filling up faster than expected.** The invisible consumers are versions, the trash bin, and the preview cache. In the admin settings you can see how much each occupies, and you can shorten the retention windows. There is also a `occ` command to trim versions and previews in one pass when you need space back fast.

## How this fits the rest of your home server

Nextcloud becomes the file layer your other services plug into. It pairs with [Jellyfin](https://chikewa.com/jellyfin-docker-compose-guide/) (point the media server at the Nextcloud-stored movies and TV, or keep media on a dedicated share), with the [MinIO guide](https://chikewa.com/minio-docker-compose-s3/) if you want S3-style object storage instead of or alongside WebDAV, and with the [3-2-1 backup strategy](https://chikewa.com/backup-strategy-3-2-1-restic/) so the `nextcloud-data` volume — the one that actually contains your files — is backed up off-box. If you will be reaching Nextcloud from outside the house, do it over a VPN such as Tailscale rather than port-forwarding, and put a reverse proxy in front if you want a clean domain and automatic HTTPS.

Tested on:

OSDebian 12Docker29.7.2Hardware4-core / 16 GBSoftwareNextcloud 34.0.3 + PostgreSQL 16 (alpine)Last tested: 3 September 2026

## What’s next?
The natural next steps from this guide:

- [The 3-2-1 backup strategy for a home server](https://chikewa.com/backup-strategy-3-2-1-restic/)
- [Jellyfin for movies and TV](https://chikewa.com/jellyfin-docker-compose-guide/)
- [MinIO: self-hosted S3 object storage](https://chikewa.com/minio-docker-compose-s3/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).