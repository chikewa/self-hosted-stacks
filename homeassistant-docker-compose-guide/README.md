# Home Assistant in Docker: A Self-Hosted Smart Home Guide


> Home Assistant is the operating system for smart home devices: it talks to hundreds of brands over local protocols (Zigbee, Z-Wave, MQTT, Wi-Fi) and keeps the automation logic on your own hardware instead of a cloud you do not control. It runs in one container, but unlike most services on this site it expects to […]

**Full guide:** [https://chikewa.com/2026/08/28/homeassistant-docker-compose-guide/](https://chikewa.com/2026/08/28/homeassistant-docker-compose-guide/) · **Category:** Docker & Linux · **Published:** 2026-08-28

---

Home Assistant is the operating system for smart home devices: it talks to hundreds of brands over local protocols (Zigbee, Z-Wave, MQTT, Wi-Fi) and keeps the automation logic on your own hardware instead of a cloud you do not control. It runs in one container, but unlike most services on this site it expects to reach your LAN directly — which changes how you set it up. This guide covers the Docker Compose install, the `.env` file that trips people up, adding devices, and keeping automations running.

*Intermediate · 12 min · Docker*

## Why Home Assistant over a brand hub

Brand hubs (Philips Hue app, Tuya, HomeKit) all share the same weaknesses: your automations live in their cloud, every device from a different vendor needs its own app, and when the cloud has a bad week your lights stop following your schedule. Home Assistant inverts that:

- **Local first.** Zigbee, Z-Wave, Thread, MQTT and most Wi-Fi integrations talk straight to the radio or device. The cloud is optional.

- **One brain for all vendors.** A Hue bridge, a Tuya plug (via the Tuya local integration), an ESPHome light and a Sonoff switch coexist in one UI, one automation engine, one voice interface.

- **Automations you can read.** Every rule is a small YAML document on disk. No black-box “smart scenes” you cannot inspect.

The honest caveat: Home Assistant is a platform, not a product. Setup takes longer than a brand app, and when something misbehaves the answer is “read the integration’s logs” rather than “call support”. For people who already run Docker for anything, that trade is worth it.

## Prerequisites

- Docker + Compose plugin

- A machine on your LAN with a stable IP (this guide assumes `8123` is free)

- Optional: a Zigbee or Z-Wave USB stick if you have (or plan) radio-frequency devices

## Step 1: The compose file

```bash
mkdir -p ~/stacks/homeassistant && cd ~/stacks/homeassistant
```

Create `docker-compose.yml`:

```yaml
services:
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    volumes:
      - ./config:/config
      - /etc/localtime:/etc/localtime:ro
    env_file: .env
    network_mode: host
    restart: unless-stopped
    # Uncomment for Zigbee (ZHA) or USB serial adapters:
    # devices:
    #   - /dev/ttyUSB0:/dev/ttyUSB0
```

Two choices here are deliberate and worth understanding:

- `network_mode: host` — Home Assistant needs to discover and reach many devices on your LAN (mDNS, Chromecast, bridges on fixed IPs). Container networking with published ports works for basic use but breaks a surprising number of integrations that rely on being a real LAN host. Host networking is the documented, lowest-friction option for the official image. The trade: it listens on all host interfaces, so keep it on a machine you trust on that LAN.

- `./config:/config` — your entire HA state lives here: automations, integrations, history (if you enable the SQL recorder), add-ons. This folder is what you back up and what makes a reinstall take minutes.

## Step 2: The .env file (the part that breaks installs)

The official image requires a `PASSWORD` variable in an env file — and it must be at least 12 characters. If the file is missing or too short, the container starts and immediately exits, and the log will not obviously say why. Create `.env` next to the compose file:

```text
PASSWORD=change-me-to-at-least-12-chars
```

Notes:

- This password is *not* your web UI login password. It is an internal variable the image checks at startup; your actual account is created in the setup wizard. People conflate the two and end up “wrong password” loops.

- Keep `.env` out of git and out of backups that leave the house (or encrypt them). The name is scary, but treat it like a credential anyway.

- If you skip this file, `docker compose up` will fail with `env file ... not found` — that error is correct and is the feature working, not a bug.

## Step 3: Start it and run the wizard

```bash
docker compose up -d
docker compose logs -f homeassistant
```

Wait for the line `Home Assistant 2026.x.x`, then open `http://YOUR_SERVER_IP:8123`. The onboarding wizard asks for your name, location (used for sunrise/sunset automations — keep it accurate, or set “precise location off” and enter coordinates manually if you prefer), and your account. That account is your administrator.

## Step 4: Add your first devices

Go to **Settings → Devices & Services → Add Integration**. The practical starting points, in order of “works first try”:

- **Hue Bridge** — if you have any Philips lights, this is the gold standard: reliable, local, fast.

- **ESPHome** — if you ever build or buy flashed ESP devices. Once the device is flashed, HA’s ESPHome integration configures itself from the device.

- **Matter** — for new Matter-certified devices. HA acts as the Matter controller; the phone is just a commissioning remote.

- **ZHA (Zigbee)** — if you plug a Zigbee stick into the server, add the ZHA integration and pair from **Settings → ZHA → Add Device**. Remember to uncomment the `devices:` line in the compose file and restart before pairing.

Each integration’s page lists its quirks (the Tuya local one, for example, needs your local credentials extracted from the device — the integration’s docs walk through it). When an integration “does not work”, the integration’s own documentation page is more current than any blog post; read the troubleshooting section before digging in logs.

## Step 5: Your first automation

The classic starter, and the one that sells the platform:

> Lights in the hallway turn on at sunset when motion is detected, and turn off 5 minutes after the last motion.

In **Settings → Automations & Scenes → Create Automation**, build it with the UI (no YAML needed): trigger *Motion detected* (your sensor), condition *Sun has set*, action *Turn on light* + *Wait 5 minutes* + *Turn off light*. Save it. It now runs entirely on your hardware, and you can open it any time to see exactly what it does.

Once you trust it, add the one that changes your life: *When everyone’s phone leaves the home Wi-Fi for the night, arm the lights/locks scenario.* Phone presence detection works out of the box via Wi-Fi, no extra hardware.

## Keeping it reliable

- **Enable the recorder** (Settings → Dashboard → recorder) if you want graphs and history. It adds a SQLite database to `./config`; a NAS-backed volume or Postgres if you want it serious.

- **Back up `./config` weekly** — it is small (tens to low hundreds of MB) and contains your entire setup. A restic job pointed at [MinIO](https://chikewa.com/minio-docker-compose-s3/) is one command.

- **Update deliberately.** HA ships a new release every two weeks. The container image is `:stable`, so `docker compose pull && docker compose up -d` is the upgrade path, but do it on a weekend, not a Tuesday — integrations occasionally break, and the fix is usually the next patch or a line in your automation.

## Access from outside

Home Assistant’s own docs point at Nabu Casa — a managed, paid remote-access service — but the free, local-first equivalent is a tunnel (Cloudflare Tunnel, covered in the [Security & Networking](https://chikewa.com/category/security-networking/) series) that gives you `ha.example.com` with zero open ports and full TLS. Pair it with a strong password and (ideally) MFA on the HA account, and you can check the house from anywhere without exposing port 8123.

## Resource usage (measured)

StateRAM

Idle, ~20 entities~300–400 MiB
Recorder enabled, ~100 entities~500–700 MiB
Active Zigbee network, ~200 entities~700 MiB–1 GiB

It is a Python app with a database in its pocket — it does not run on 512 MB, and a 2 GB machine is the realistic minimum if you enable the recorder. A Pi 5 with 4–8 GB handles a real household comfortably.

## Updating

```bash
docker compose pull && docker compose up -d
```

## FAQ

#### Can I run it without host networking?

Yes, for a simple setup: publish `8123:8123` and skip `network_mode: host`. You will lose some discovery-based integrations and may need to add static device entries by IP. If everything you run is a bridge (Hue) or a cloud integration, bridge mode is fine. The moment you add Zigbee radios, Chromecasts, or mDNS-dependent devices, host networking is the path of least resistance.

#### What if a device only works through its cloud (Tuya, some Wi-Fi plugs)?

Often there is a local integration (Tuya Local, Shelly, ESPHome flash) that takes the cloud out of the loop. The community is aggressively building these out. If an integration is cloud-only, your automation will depend on that vendor’s cloud — accept it knowingly or choose a device with a local option.

#### Does the UI work on my phone without the app?

The web UI is a full PWA; add it to your home screen and it behaves like an app, including offline-ish caching. The official apps add voice (Assist) and notifications; the web UI is enough for control and automations.

#### How is this different from HomeKit?

HomeKit is a standard for Apple devices; Home Assistant is a platform that can speak to HomeKit (expose your HA devices to Apple Home) while also speaking to everything else. Running HA as the brain and letting Apple Home be one of its outputs is the common power-user topology.

#### Where does this fit?

Home Assistant is the “physical world” layer of a self-hosted home: [Jellyfin](https://chikewa.com/jellyfin-docker-compose-guide/) for the TV, [Navidrome](https://chikewa.com/navidrome-docker-compose-guide/) for the speakers, and HA as the thing that knows when the sun set and the house is empty. All of them reachable from outside the house via a tunnel or Tailscale — see the [Security & Networking](https://chikewa.com/category/security-networking/) series.

## What’s next?
The natural next steps from this guide:

- [Secure your home server first](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)
- [What hardware to run it on](https://chikewa.com/what-hardware-for-a-home-server/)
- [Jellyfin for the living room](https://chikewa.com/jellyfin-docker-compose-guide/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).