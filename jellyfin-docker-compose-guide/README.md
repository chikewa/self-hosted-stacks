# Jellyfin in Docker: A Self-Hosted Media Server for Movies and TV


> Run Jellyfin with Docker Compose: the tested compose file, loopback port binding, hardware transcoding with Quick Sync and real RAM numbers from the Chikewa lab.

**Full guide:** [https://chikewa.com/2026/08/24/jellyfin-docker-compose-guide/](https://chikewa.com/2026/08/24/jellyfin-docker-compose-guide/) · **Category:** NAS & Media · **Published:** 2026-08-24

---

Jellyfin is the self-hosted answer to Netflix and Plex: an open-source media server that plays your own movies and TV from your own disk, with no subscription and no upload limits. It is also one of the most misunderstood services in the self-hosting world, because the difference between a smooth setup and a constant transcoding fight comes down to a few decisions you make before the first movie. This guide walks through the Docker Compose setup we run in the Chikewa lab, what the hardware actually has to do, and the configuration choices that matter.

*Beginner · 12 min · Docker*

## What is Jellyfin?

Jellyfin streams video, music, photos and podcasts from folders on your server to any device on your network or on the internet. It was forked from the old free version of Plex in 2018, and unlike Plex it is fully open source: no premium tier, no server-side limits, no account required. The server does the heavy lifting (metadata scraping, transcoding, photo optimization) and thin clients on phones, TVs, browsers and media players do the playback.

Two properties make it a good first “big” self-hosted service. First, it is a single container with no database dependency: the only thing you point it at is a folder of media files. Second, its default configuration is genuinely reasonable, which means the gap between “it started” and “it is actually usable” is small. The things that do trip people up are documented below, because they tripped us.

## Requirements

Anything that runs Docker runs Jellyfin. The realistic floor is the same as the rest of the stack: 2 GB of RAM and a few hundred MB of disk for the configuration database. The real constraint is not starting the server, it is transcoding. If a client asks for a format the hardware cannot decode natively, Jellyfin re-encodes it on the CPU, and that is where underpowered machines start stuttering.

Our lab machine is a 4-core i5-6500T with 16 GB of RAM and an NVMe disk. It idles Jellyfin at around 240 MiB of RAM and can comfortably handle direct play for the family and one light transcode at a time. If you are buying hardware specifically for a media server, read our [hardware guide](https://chikewa.com/what-hardware-for-a-home-server/) before you buy.

## The Compose File

The complete file, exactly as it runs in the lab:

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    ports:
      - "127.0.0.1:8096:8096"
    volumes:
      - jellyfin-config:/config
      - ./media:/media
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
    restart: unless-stopped

volumes:
  jellyfin-config:
```

Three decisions in this file are worth understanding.

#### The port binding

Notice the port is published as `127.0.0.1:8096:8096`, not `8096:8096`. That single change makes the difference between “my media server is reachable from the living room” and “my media server is reachable from the entire internet”. Bound to loopback, Jellyfin answers only on the host itself; you reach it from other devices through a reverse proxy or a private network, and we cover both in our [security guide](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/). We verified with `ss -tlnp` that the socket listens on `127.0.0.1:8096` only.

#### The volumes

Two things need to survive container recreation. `jellyfin-config` is a named volume holding the SQLite database, plugin state and user settings — losing it means re-creating users and re-scanning the library. `./media` is your actual movie and TV folder, mounted read-only in spirit (Jellyfin never needs to write to your media, only read it). Keep media on the fastest disk you have: scan times and seek performance for random playback both depend on it.

#### The environment variables

`PUID` and `PGID` make the container run as your regular user instead of root, which matters if you ever mount media from a share with restrictive permissions. `TZ` keeps the activity log and the trickplay schedule sane. Nothing else is required.

## First Run

Start it and watch the logs:

```bash
docker compose up -d
docker compose logs -f jellyfin
```

The first boot takes noticeably longer than the other services in this series. On our machine the image pull, the database migrations and the plugin load completed in under a minute, and the log ended with `Core startup complete`. The health endpoint is a good objective check:

```bash
curl http://localhost:8096/health
# Healthy
```

Open `http://localhost:8096` (or through your proxy) and create the admin account. The setup wizard then asks where your media lives: the path is `/media`, because that is the mount point inside the container, not the host path. This is the most common first-run mistake — entering the host path makes Jellyfin scan an empty directory and you get a server that runs perfectly with zero content.

## Library Setup

Add your first library, choose “TV Shows” or “Movies”, point it at the right subfolder of `/media` and let it scan. Jellyfin pulls metadata from TMDb by default, which works well for English content; the first scan of a medium library (a few hundred titles) took a few minutes in our test, downloading posters and fan art for everything.

Two settings pay for themselves quickly. Under the library, enable **save image assets to the content folder** if you want the metadata to survive a config loss. And check **realtime monitoring** so new files are picked up without a manual rescan.

## Hardware Transcoding

Direct play means the client decodes the file as-is: cheap, fast, and what you want 95% of the time. Transcoding happens when a client cannot play the source format. Our lab image ships with ffmpeg 7.1.4, and the encoder list includes `h264_qsv`, `av1_qsv` and `hevc_qsv` — Intel Quick Sync. The image also bundles the i965 driver, and the host exposes `/dev/dri` when the CPU has an Intel iGPU, so Quick Sync transcoding is available out of the box on most mini PC hardware.

To use it, pass the device through and enable hardware transcoding in the admin dashboard (Playback → Transcoding). The compose addition is:

```yaml
devices:
      - /dev/dri:/dev/dri
```

Without the iGPU, transcoding falls back to the CPU, which on a 4-core i5 handles a single 1080p encode but will struggle with several. If transcoding quality matters to you, that is a hardware conversation, not a configuration one.

#### A pitfall we hit: you cannot exec ffmpeg

Our first attempt to test the transcoder was `docker exec jellyfin ffmpeg -hwaccels`, which failed confusingly. The Jellyfin entrypoint intercepts every argument and hands it to the .NET server, so arbitrary commands never reach a shell. To inspect the bundled ffmpeg you need a separate container from the same image, or check the running server’s logs, which print the full encoder and hwaccel list at startup. The list we captured is in our [hardware guide](https://chikewa.com/what-hardware-for-a-home-server/), if you want to compare.

## First Login and Daily Use

Once the library is scanned, add a user per household member (the admin account is a fine user too, but separate users keep watch states and parental controls clean). Install a client: the browser works everywhere, the Android and iOS apps are good, and most smart TVs either run a native app or play through a browser. From the TV we verified direct play of 1080p MKV without a single transcode, which is the whole point.

Remote access is the next natural step. Because we bound the port to loopback, the two clean options are a reverse proxy with authentication or a private network like Tailscale; the security guide covers the decision. Do not solve “I want to watch at my parents’ house” by republishing port 8096 on 0.0.0.0.

## Updating

Jellyfin images move fast. The safe update:

```bash
docker compose pull
docker compose up -d
docker compose logs -f jellyfin   # watch for "Core startup complete"
```

Configuration and the database live in the named volume, so updates are non-destructive. One thing to know: after a major version bump the logs show a batch of Entity Framework migration warnings on the first boot. In our test run they appeared, the migrations applied, and the server came up cleanly. They look alarming and are cosmetic; what you should actually watch for is a missing `Core startup complete`.

## Troubleshooting

#### The server runs but the library is empty

Nine times out of ten this is the host-path-instead-of-container-path mistake from the first run. The media folder inside the container is `/media`. Check the library path in the admin dashboard, not the compose file.

#### Playback stutters on one device only

That device is transcoding when it should direct play. Open the activity log during playback: it records every transcode with the codec and resolution. If you see transcodes for a format your client should support, the file’s codec or profile is outside the client’s native range — re-encode that file, or accept the transcode.

#### High CPU during scans

Large initial scans and photo optimization are CPU-heavy by design and settle down. If CPU stays high with no scans running, check the trickplay generation schedule (it runs daily and is optional) and the number of concurrent transcodes in the playback settings.

## Resource Usage

Measured in the lab, steady state with a 200-title library and no active playback: **236 MiB RAM, negligible CPU**. The disk footprint of the config volume is tens of MB; the media is, of course, your own. Add roughly 0.5–1 GB per active hardware transcode, more for CPU transcoding.

## FAQ

#### Is Jellyfin legal?

Jellyfin is a legal, open-source application. What you put on the server is your responsibility, exactly as with any storage device you own.

#### Can it replace Plex for a household?

For the core job — stream my library to my devices — yes, and without a premium subscription. You give up some of Plex’ polished remote streaming and its ecosystem of third-party integrations. For most home setups that trade is a win.

#### What about music?

Jellyfin plays music, but if music is the priority, a dedicated server like [Navidrome](https://chikewa.com/navidrome-docker-compose-guide/) uses less RAM and has a better mobile experience. We run both in the lab.

Tested on:

OSDebian 12Docker29.7.2Hardware4-core i5-6500T / 16 GB RAM / NVMeSoftwareJellyfin 10.11.11 (ffmpeg 7.1.4)Last tested: 23 August 2026

## What’s next?
The natural next steps from this guide:

- [Navidrome: self-hosted music server](https://chikewa.com/navidrome-docker-compose-guide/)
- [Secure your home server: SSH, firewall and Docker networks](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)
- [What hardware for a home server?](https://chikewa.com/what-hardware-for-a-home-server/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).