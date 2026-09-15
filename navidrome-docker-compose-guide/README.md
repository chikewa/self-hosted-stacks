# Navidrome in Docker: A Self-Hosted Alternative to Spotify (Compose Guide)


> Navidrome is a self-hosted music server that replaces Spotify for your own library: the Docker Compose setup, the official mobile apps, and the settings worth changing.

**Full guide:** [https://chikewa.com/2026/08/23/navidrome-docker-compose-guide/](https://chikewa.com/2026/08/23/navidrome-docker-compose-guide/) · **Category:** Docker & Linux · **Published:** 2026-08-23

---

Beginner · 7 min · Docker · Music

**Tested on:**

OS
Any Linux (verified on Debian 12)

Docker
29.7

Hardware
4-core x86, 16 GB RAM (a 2 GB Raspberry Pi 5 runs it fine)

Software
Navidrome (latest, deluan image) 

Last tested: 22 August 2026

## On this page

- [Why Navidrome over the alternatives](#why-navidrome-over-the-alternatives)

- [Prerequisites](#prerequisites)

- [Step 1: The compose file](#step-1-the-compose-file)

- [Step 2: Start it and load the library](#step-2-start-it-and-load-the-library)

- [Step 3: Connect the official mobile app](#step-3-connect-the-official-mobile-app)

- [Step 4: The settings worth changing](#step-4-the-settings-worth-changing)

- [Step 5: Reaching it from outside your network](#step-5-reaching-it-from-outside-your-network)

- [Resource usage (measured)](#resource-usage-measured)

- [Updating](#updating)

- [FAQ](#faq)

Navidrome is the self-hosted music server that actually replaces Spotify for people who already own their music: it reads a folder of MP3s or FLACs, serves them to any device over a fast web interface, and runs in a single container with about 26 MB of RAM at idle. This guide covers the Docker Compose setup, the official mobile apps, and the settings that matter.

## Why Navidrome over the alternatives

There are a few options for streaming your own library. Here is how they compare on the axes that actually matter day to day:

Navidrome
Jellyfin (audio)
Coherence

Setup effort
1 container, 1 folder
1 container, more config
1 container + DLNA client

Idle RAM (measured)
~26 MiB
~300 MiB+ (multi-service)
~40 MiB

Mobile apps
Official (Substreamer) + many
Official app
Client apps only

Transcoding
On the fly, fast (Go)
Yes, heavier
Limited

Video
No — audio only
Yes
Yes (DLNA)

The honest rule: if you want video and audio in one stack, use Jellyfin (we cover it in the NAS & Media series). If you only need music, Navidrome is lighter, faster, and its mobile app experience is the best of the group.

## Prerequisites

- Docker + Compose plugin

- Your music in one folder (MP3, FLAC, OGG, M4A, OPUS, WAV, WMA all work). Keep the folder structure you like — Navidrome reads artist/album metadata from the files, so filenames and folders mostly do not matter for playback, only for how the UI groups things when tags are missing.

- A free TCP port (this guide uses `4533`, the default)

## Step 1: The compose file

```bash
mkdir -p ~/stacks/navidrome/music && cd ~/stacks/navidrome
```

Create `docker-compose.yml`:

```yaml
services:
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

volumes:
  navidrome_data:
```

Notes on the three choices in that file:

- `./music:/music:ro` — your library is mounted **read-only**. Navidrome never needs to write to your music; keeping it read-only is free safety.

- `ND_SCANSCHEDULE: 1h` — re-scan the library hourly, so new files appear without action. Set to `never` if your library rarely changes and you want zero background work.

- `navidrome_data:/data` — the internal database (play counts, playlists, users) lives in a volume, so updates and container rebuilds never touch it.

## Step 2: Start it and load the library

```bash
docker compose up -d
docker compose logs -f navidrome
```

You will see it scan the folder on first start — one line per track, and the time depends on library size (a few thousand tracks take a couple of minutes; 50,000 can take ten or more). Stop following the log with `Ctrl-C` once it finishes.

Open `http://YOUR_SERVER_IP:4533`. First visit asks you to create the first user, which becomes the administrator. Log in and your library is there, grouped by artist and album, with artwork pulled from embedded tags or Navidrome’s own art fetching.

## Step 3: Connect the official mobile app

The official client is called **Substreamer** (Android and iOS). Setup takes about a minute:

- Install Substreamer from your app store.

- Add a server: `http://YOUR_SERVER_IP:4533` (or the public URL once you have a reverse proxy — see below), then your username and password.

- It fetches the library and behaves like a normal music app: browse, search, playlists, gapless playback, background play.

Non-official clients also work well: the community Navidrome clients on both platforms, and any app that speaks the Subsonic API. Navidrome deliberately implements the Subsonic protocol, which is why so many third-party apps just work.

## Step 4: The settings worth changing

Most of Navidrome works well untouched, but these five are worth a look in *Settings → Server* and *Settings → Player*:

- **Transcoding.** On by default: if a client requests 128 kbps MP3, Navidrome transcodes FLAC on the fly. That is the right default for phones on data. On a fast LAN you can raise the quality or let the client request the original format.

- **Cover art source.** Navidrome can fetch missing artwork from the web. Fine for MP3s with weak tags; for a carefully tagged FLAC library, keep it off to avoid wrong art being cached.

- **Session timeout.** Defaults are generous; tighten if you ever expose the UI publicly.

- **Playlist sharing.** Users can share playlists with each other — useful if you run this for a household.

- **Play counts and “last played.”** On by default, and the data powers the “recently played” views in the app. Nothing to configure, just know it exists.

## Step 5: Reaching it from outside your network

Two honest options:

- **Tailscale (our recommendation):** install Tailscale on the server and on your phone. The server gets a stable address inside your private mesh, no ports opened on the router, traffic encrypted end to end. This is the lowest-risk way to listen to your library on the train.

- **Reverse proxy with TLS:** Caddy or Nginx Proxy Manager in front of Navidrome, with a domain name. More setup, but it also serves as the foundation for every other service you expose later. We cover both paths in the [Security & Networking](https://chikewa.com/category/security-networking/) series.

Do not forward port 4533 directly on your router. An exposed music server with a weak password is a classic credential-stuffing target.

## Resource usage (measured)

From the same verified stack as our [starter guide](https://chikewa.com/self-hosting-starter-guide/):

State
RAM

Idle (no streams)
26 MiB

One stream, FLAC
~40–60 MiB

A 2 GB Pi 5 can comfortably run Navidrome plus several other services. Transcoding is the only CPU-heavy operation, and it is per-stream, so a single listener on a small machine is not a problem.

## Updating

```bash
docker compose pull && docker compose up -d
```

Navidrome runs a quick upgrade/migration on start. Your library is untouched (it is just a folder); your database lives in the volume.

## FAQ

#### Will it stream lossless over my home network?

Yes. Over a LAN the app can play original FLAC files directly. Transcoding only kicks in when a client requests a lower format (typically data connections or older devices).

#### Does it support gapless playback?

The web interface does not do gapless playback; Substreamer does, which is why the app is the recommended client for classical or concept albums.

#### Can I add podcasts?

No — Navidrome is music only. Pair it with an RSS reader like [Miniflux](https://chikewa.com/self-host-miniflux-docker-compose/) and you have a complete, private media stack.

#### What if my tags are a mess?

Fix the tags in the files (Beets, Kid3, or MusicBrainz Picard), then force a rescan from the admin panel. Navidrome does not write tags back to your files, so cleanup tools are safe to run at any time.

#### Where does this fit?

Navidrome is one of the three services in our [self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/). For video, see the Jellyfin guide in the [NAS & Media](https://chikewa.com/category/nas-media/) section (in the pipeline).

## What’s next?

Your music is streaming. From here:

- [Self-hosting Starter Guide: the full path from hardware to a working server](https://chikewa.com/self-hosting-starter-guide/)

- [How to Self-Host Miniflux with Docker: add your own RSS reader](https://chikewa.com/self-host-miniflux-docker-compose/)

- [Browse the full starter stack in one place](https://chikewa.com/recommended-stack/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).