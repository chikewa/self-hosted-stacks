# Syncthing in Docker: Peer-to-Peer File Sync Between Your Devices


> Keep your laptop, phone and home server in sync with no cloud in the middle: a tested two-node Syncthing setup in Docker, the pairing flow end to end, and the folder types that stop conflicts.

**Full guide:** [https://chikewa.com/2026/09/09/syncthing-docker-compose/](https://chikewa.com/2026/09/09/syncthing-docker-compose/) · **Category:** Productivity · **Published:** 2026-09-09

---

You have a laptop, a phone, a desktop and a home server, and the same documents live on more than one of them. Something has to keep them equal. Syncthing does that without a central server: the devices form a direct peer-to-peer mesh, each one runs the same open-source app, and folders you mark for syncing replicate between the peers you choose — over your LAN when the devices are home, or over an encrypted direct connection (or a relay, as a fallback) when they are not. This guide runs Syncthing in Docker on the home-server side, explains the one configuration file it needs, and walks through pairing a second device so you can watch a real folder sync in both directions.

*Beginner · 11 min · Docker*

Everything here was tested on a Debian 12 mini PC with Docker 29.7, including a two-node sync test — two containers acting as two devices, with a file pushed from one and confirmed on the other — so the pairing and folder-sharing steps below are what actually happened, not a paraphrase of the docs.

## Why Syncthing is different from a sync “service”

Cloud sync products keep a copy of your files on their servers and move them through those servers. Syncthing has no center: each device runs the same program, devices discover each other (on the LAN via local broadcast, across the internet via a global discovery server that only carries addresses, never file content), and the file data itself goes peer to peer, encrypted. The practical consequences: your files are not stored by a third party, syncing works over a normal home network with no accounts, and if two of your devices are online they will sync even if the rest of your infrastructure is down. The trade-off is that you manage the pairing yourself — there is no “sign in and it appears” magic, you explicitly add each device and each folder.

## The compose file

```yaml
services:
  syncthing:
    image: syncthing/syncthing:latest
    container_name: syncthing
    restart: unless-stopped
    ports:
      - "127.0.0.1:8384:8384"
      - "127.0.0.1:22000:22000"
      - "127.0.0.1:22000:22000/udp"
    environment:
      - TZ=Europe/London
    volumes:
      - ./config:/var/syncthing/config
      - ./sync:/sync
```

Three pieces to understand. **Ports 8384 and 22000**: 8384 is the web UI; 22000 is the actual sync traffic (TCP and UDP) between devices. For a home server you usually want the UI on loopback or behind your VPN, and 22000 reachable by your other devices — on the LAN that just means the port is open to your subnet. **The config directory**: the official `syncthing/syncthing` image keeps all its state — your device key, the other devices, the folder list, its own GUI certificate — in `/var/syncthing/config`, and I mount that as `./config`. Leave it empty on first boot: Syncthing generates its device key and writes a default `config.xml` there, and from then on that one directory is the node’s entire identity. Back up `config/` and you can rebuild the container and keep the same device, the same peers, and the same folders. **The sync folder**: `./sync` is where the shared files live on the host. Point it at wherever you actually want the shared files (a NAS share, a dedicated directory).

A detail that trips people up: the device ID is not something you type in. On first boot the container logs a line like `Calculated our device ID (device=XXXXXXX-...)` and that long hex string is what other devices use to recognize you. Note it down when you pair. If you ever see your device ID change on every restart, the container is not writing `config/` back (a permissions problem on the mounted directory), and every peer sees a brand-new device each time — which is the classic “pairing keeps breaking” symptom.

## First boot and the web UI

Run `docker compose up -d` and open `http://<server-ip>:8384`. On a fresh config directory the UI walks you through setting the GUI username and password and accepting the generated device ID — that long hex string is this node’s identity, and it is what other devices use to recognize you when you pair. Confirm the container is healthy and the sync engine is actually running (not just the UI): `docker logs syncthing` should show the key being generated, the device ID being calculated, the TCP and QUIC listeners starting on 22000, and the GUI listening on 8384. In the lab I also saw it join a public relay on startup, which is the fallback path it will use for away devices — it is normal, not an error. A UI that loads but a sync engine that cannot persist config is the classic half-broken state, and it shows up in the log, not the browser.

## Pairing a second device: the real test

For the lab test I ran two containers — call them A (the one above) and B — each with its own `config.xml` and its own sync directory, so they are genuinely two devices. The pairing flow, which is identical whether the second device is another container, a laptop, or a phone:

- On A, open **Actions → Add Remote Device**. Paste B’s device ID (from B’s UI). Give it a name. Accept.

- B gets a notification: “Device A wants to connect.” Accept it. (On a manual setup you add A’s ID to B the same way.) Once both sides accept, the devices are paired and appear as connected in each other’s UI.

- Now share a folder. On A, open the folder you want to sync (the lab’s “Lab Test” folder) and add B to the list of devices that receive it. On B, Syncthing offers to create the matching folder — accept it, choosing where on B the files should land.

That is the whole model in one sentence: devices are paired globally, folders are shared per-device. A device you have paired can only see the folders you explicitly share with it. In the lab test I wrote a file into A’s folder, and within a couple of seconds it appeared in B’s — and when I edited it on B, the change propagated back to A. Both directions worked, which is the point of a “send/receive” folder type (the default): changes flow both ways, and conflicts are resolved by most-recent-wins with the losing version kept as a `.sync-conflict` copy rather than deleted.

The folder type matters and is easy to get wrong. **Send & Receive** (default) syncs both directions — use it for a shared folder. **Send Only** pushes from this device and never applies changes from others — use it for a “distribution” folder, e.g. the server pushing a config folder to clients. **Receive Only** is the mirror: this device only ever takes. If you set a folder to Send Only on the server and expect edits from the laptop to land on the server, they will not — that is the configuration, not a bug.

## LAN versus internet: what actually happens to the traffic

When both devices are on the same LAN, Syncthing uses the local broadcast discovery and connects directly over the private IPs — fast, and nothing leaves the house. When a device is away (your laptop at work), it uses the global discovery server to find the other device’s public address and attempts a direct encrypted connection; if the NATs on both sides block the direct path, it falls back to one of Syncthing’s public relays, and the data is still end-to-end encrypted (the relays carry ciphertext they cannot read). You can watch which path is in use in the UI’s connection status — “direct” versus “via relay” — and in my lab the two containers connected directly as expected. For a home server this means the server side does not need any inbound port forwarding for LAN sync; the 22000 port only matters for direct connections to devices that are away.

## Common gotchas

**Device ID resets on every container restart.** The container cannot write `config.xml` back (ownership/permissions on the mounted file, or it is mounted read-only). Fix the ownership so the running user matches, and confirm the device ID is stable across a `docker restart syncthing`. An unstable ID means every other device sees a “new” device each time and pairing keeps breaking.

**Devices are paired but no files move.** The folder is not shared with that device — pairing is not the same as sharing. Check the folder’s device list on the side that owns the files. The second usual cause is a folder-path mismatch: the folder exists on both devices but under different labels, so Syncthing treats them as unrelated. Folder *IDs* (not labels) are what match; if you recreated a folder, its ID changed and it no longer matches the peer’s copy.

**Constant “sync-conflict” files appearing.** Two devices are editing the same file at the same time on a Send & Receive folder. Syncthing keeps both versions (the conflict copy is the one that would have been overwritten). If that is happening a lot, one of the folders should probably be Send Only or Receive Only so there is a single source of truth.

**Sync is slow when a device is away.** You are on the relay path. Check the connection status; if direct connections keep failing it is usually a NAT/firewall blocking the outbound 22000 from one side. Allowing outbound 22000 (TCP/UDP) on the away device’s network usually restores the faster direct path.

## How this fits the rest of your home server

Syncthing is the file-movement layer that keeps your devices and the server consistent without a cloud. It complements a self-hosted file server such as Nextcloud rather than replacing it: the file server is the shared, web-accessible store with a UI and share links, while Syncthing is the always-on, peer-to-peer replication between your machines. Many people run both, with Syncthing keeping the server’s copy current and the file server providing browser and share-link access. For deciding which of the server’s disks should hold the synced folders, the [hardware guide](https://chikewa.com/what-hardware-for-a-home-server/) has the measured disk throughput of the box used in these tests. Keep the UI on the LAN or behind a VPN such as Tailscale, and back up the `config/` directory plus the sync folder with the [3-2-1 backup strategy](https://chikewa.com/backup-strategy-3-2-1-restic/) — the config directory is the whole node identity, so it belongs in your backups.

Tested on:

OSDebian 12Docker29.7.2Hardware4-core / 16 GBSoftwareSyncthing v2.1.3 (container)Last tested: 3 September 2026

## What’s next?
The natural next steps from this guide:

- [Immich: a self-hosted photo library](https://chikewa.com/immich-docker-compose-photo-library/)
- [The 3-2-1 backup strategy for a home server](https://chikewa.com/backup-strategy-3-2-1-restic/)
- [What hardware for a home server?](https://chikewa.com/what-hardware-for-a-home-server/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).