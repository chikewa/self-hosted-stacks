# Immich in Docker: Self-Hosted Photo Library (Compose Guide)


> Immich is the self-hosted photo backup that finally closes the loop on Google Photos: unlimited storage, on-device ML, automatic face and object grouping, and a mobile app that behaves like the one you are replacing — while every file stays in a folder you own. It is heavier than most single-container services (three to five […]

**Full guide:** [https://chikewa.com/2026/08/27/immich-docker-compose-photo-library/](https://chikewa.com/2026/08/27/immich-docker-compose-photo-library/) · **Category:** NAS & Media · **Published:** 2026-08-27

---

Immich is the self-hosted photo backup that finally closes the loop on Google Photos: unlimited storage, on-device ML, automatic face and object grouping, and a mobile app that behaves like the one you are replacing — while every file stays in a folder you own. It is heavier than most single-container services (three to five containers, a Postgres variant with vector search), so this guide walks through the full Docker Compose stack, the app setup, and the decisions that actually matter.

*Beginner · 10 min · Docker*

## What Immich actually does

- **Unlimited backup** from the Android/iOS apps: your library syncs, originals are stored on your server, and the phone app keeps working offline.

- **Machine learning** — face grouping, object detection, blur search, and a natural-language query box (“sunset at the beach”) — running on your own hardware.

- **Standard files** — everything lands in a plain `upload/` folder. Immich’s database is metadata; the photos are just files you can copy anywhere.

The honest caveat: the ML side (face detection, embeddings) is CPU-hungry on first import. A 50,000-photo library on a Pi 5 takes days to fully index; on a modern desktop CPU it takes hours. The backup and browsing parts work fine on a Pi from the first photo.

## Prerequisites

- Docker + Compose plugin

- A machine with at least 4 GB RAM for comfortable use of the ML pipeline (it starts earlier with less, but indexing will be glacial)

- A free TCP port (this guide uses `2283` for the web UI and API)

- Optional but recommended: a GPU (Coral TPU or NVIDIA) for the ML container — it makes indexing dramatically faster

## Step 1: The compose file

Immich’s official stack has four containers: the server, the ML worker, Redis (queue), and a Postgres fork with vector search built in. The full file:

```yaml
services:
  immich:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich
    ports:
      - "2283:2283"
    environment:
      DB_HOSTNAME: immich-db
      DB_DATABASE_NAME: immich
      DB_USERNAME: immich
      DB_PASSWORD: CHANGE-ME-DB-PASSWORD
      TZ: Europe/London
      IMMICH_UPLOAD_LOCATION: /usr/src/app/upload
    volumes:
      - ./upload:/usr/src/app/upload
      - immich_config:/config
    depends_on:
      - immich-db
      - immich-redis
    restart: unless-stopped

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:release
    container_name: immich-machine-learning
    restart: unless-stopped
    # Optional: uncomment to use the GPU (e.g. Pi 5 + Coral or NVIDIA host)
    # devices:
    #   - "/dev/dri:/dev/dri"

  immich-redis:
    image: docker.io/valkey/valkey:9
    container_name: immich-redis
    restart: unless-stopped

  immich-db:
    image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0
    container_name: immich-db
    environment:
      POSTGRES_PASSWORD: CHANGE-ME-DB-PASSWORD
      POSTGRES_USER: immich
      POSTGRES_DB: immich
    volumes:
      - immich_db_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  immich_db_data:
  immich_config:
```

Notes on the non-obvious parts:

- **The database image is a Postgres build with the vector extensions compiled in** — Immich needs pgvector and pgvecto.rs for blur search and the embedding store. As of Immich v3.2.x the image moved from `tensorchord/vectordb` (retired from Docker Hub) to `ghcr.io/immich-app/postgres`. Do not swap it for a plain `postgres:16`; the server will refuse to start without the extensions.

- `DB_HOSTNAME: immich-db` — containers in the same compose network resolve each other by service name. This is why the DB container must be named exactly that (or the environment value updated to match).

- `./upload:/usr/src/app/upload` — your actual photos live here, as plain files. This is the volume you back up.

- `immich_config:/config` — the ML model cache. It fills on first run (hundreds of MB of models download once). Named volume, so it survives container rebuilds.

## Step 2: Start the stack

```bash
docker compose up -d
docker compose logs -f immich
```

First start takes a couple of minutes: the ML container downloads its models, the database initializes. Then open `http://YOUR_SERVER_IP:2283`.

## Step 3: Create your account

The first user you create becomes the administrator. Enter a name, email, and a strong password. There is no separate setup wizard — the web UI is your admin panel, under **Admin** in the left menu once you are in.

## Step 4: Connect the mobile apps

Immich has first-party apps on both platforms (search “Immich” in the Play Store / App Store — not the clone apps).

- Open the app, choose **Self-Hosted**, and enter `http://YOUR_SERVER_IP:2283` (or your TLS URL once you have a reverse proxy).

- Log in with the account you created.

- Grant photo library access. The app uploads originals and caches locally, so it keeps working on the train.

Android users: enable **Battery Unrestricted** for the app if you want background upload to be reliable. This is the single most common “why is it not syncing” fix.

## Step 5: Let it catch up

On first import the ML queue backs up: every photo gets face detection, object tags, and embedding vectors computed. Watch progress under **Admin → System → Machine Learning**. Two practical settings:

- **Limit concurrent ML jobs.** Default is fine on 4+ cores; on a Pi, the queue simply runs slowly — leave it, do not restart the stack, let it chew through the backlog.

- **Pause the queue** if you want to copy a huge library in without the server fighting for CPU. Resume when the transfer is done.

## Step 6: The features worth turning on

- **Face grouping** — automatic, no configuration. After a while of indexing, people get clustered; name the groups and they persist across devices.

- **Search** — text search, blur search (upload a reference photo), and the natural-language box all work once embeddings exist. Blur search is the one that reliably surprises people.

- **Sharing** — share albums or individual photos by link. Public links are the way to send photos to people who do not have an Immich account.

- **Trash & versioning** — deletions go to trash first; the web UI can also keep multiple versions of an edited photo.

## Access from outside your network

Same two honest options as every other service on this site:

- **Tailscale** — install it on the server and the phones. No open ports, encrypted mesh, works on mobile data. The lowest-risk path for a photo library.

- **Cloudflare Tunnel or a reverse proxy with TLS** — more setup, but gives you a stable public URL and real certificates. We cover both in the [Security & Networking](https://chikewa.com/category/security-networking/) series.

Do not forward port 2283 on your router with the default setup. An exposed photo server is a magnet for automated probing, and the app’s login page is public.

## Resource usage (measured)

StateRAM

Idle (all containers up, no import)~1.2–1.6 GiB total
Active import, 4-core desktop CPU~2.5 GiB, ML queue at full speed
Pi 5, indexing only~1.5 GiB, queue crawling (hours per 1k photos)

The number to plan around is the ML container: it is the only one that grows. If your machine is tight, you can run the backup stack without the ML container entirely — photos still sync and browse, they just do not get faces or search until you add it back.

## Updating

```bash
docker compose pull && docker compose up -d
```

Immich is active-release software; expect breaking changes between major versions, and the web UI will tell you when a migration is needed. Before any major update, back up two things: the `upload/` folder (your photos) and a `pg_dump` of `immich-db`:

```bash
docker compose exec immich-db pg_dump -U immich immich > immich-db-backup.sql
```

## FAQ

#### Will it replace Google Photos without data loss?

Yes, in the practical sense. The apps upload originals; you can then archive or delete the cloud copies. The one behavioural difference: Immich edits (filters, crops) are stored as separate versions, not as edits to the original file.

#### Can I import an existing library from a folder?

Yes. On the server, copy your photos into `./upload/library/<your-account-email>/` (keep the folder structure you like — dates and albums come from the files), then trigger a rescan from the web UI: **Admin → System** has a rescan/scan trigger, or simply restart the stack and Immich will pick up the new files on start. The import is where the ML queue gets its big backlog; expect the indexing to take as long as the first sync.

#### Does it work with a NAS?

Yes. Point the `upload` volume at a NAS share (e.g. `/mnt/nas/photos:/usr/src/app/upload`) and everything else is unchanged. Just know that network storage caps your import speed and makes ML indexing slower still.

#### What about backups of Immich itself?

Two artifacts: the `upload/` folder and the database. Copy `upload/` to another machine or to [MinIO](https://chikewa.com/minio-docker-compose-s3/) (S3), and dump the DB with the `pg_dump` command above. That is a complete, restorable backup.

#### Where does this fit?

Immich is the media layer for photos and videos in the same way [Jellyfin](https://chikewa.com/jellyfin-docker-compose-guide/) is for the movie and TV library. Run them side by side on the same machine and you have the full self-hosted media stack, with [MinIO](https://chikewa.com/minio-docker-compose-s3/) as the off-machine safety copy.

## What’s next?
The natural next steps from this guide:

- [Jellyfin for movies and TV](https://chikewa.com/jellyfin-docker-compose-guide/)
- [Navidrome for music](https://chikewa.com/navidrome-docker-compose-guide/)
- [The self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).