# Vaultwarden in Docker: Self-Hosted Bitwarden Password Manager


> Vaultwarden is a self-hosted server compatible with the Bitwarden client apps: your passwords, notes, cards and identities live in an encrypted database you control, and every official Bitwarden app — browser extension, desktop, mobile — connects to it unchanged. It runs in a single container with a tiny footprint, which makes it one of the […]

**Full guide:** [https://chikewa.com/2026/08/29/vaultwarden-docker-compose/](https://chikewa.com/2026/08/29/vaultwarden-docker-compose/) · **Category:** Security & Networking · **Published:** 2026-08-29

---

Vaultwarden is a self-hosted server compatible with the Bitwarden client apps: your passwords, notes, cards and identities live in an encrypted database you control, and every official Bitwarden app — browser extension, desktop, mobile — connects to it unchanged. It runs in a single container with a tiny footprint, which makes it one of the cheapest “replace a SaaS” moves in self-hosting. This guide covers the Docker Compose setup, connecting the apps, the admin panel, and the backup habit that matters most.

*Beginner · 8 min · Docker*

## What you are actually getting

- **Bitwarden-compatible server.** Vaultwarden implements the Bitwarden server API. Clients do not know or care that it is not bitwarden.com — you just change the server URL.

- **Zero-knowledge encryption.** Vault and items are encrypted on your device before they reach the server. The server stores ciphertext. A copy of the database on a NAS is useless to anyone who does not have your master password.

- **One container, one folder.** No database server to babysit: state (SQLite) and attachments live in a single `/data` volume.

The honest caveat: Vaultwarden is a community project maintained by volunteers. It is the de-facto standard for self-hosted Bitwarden, but it is not Bitwarden’s own enterprise server — you give up official enterprise features (SSO/SAML, fine-grained org policies) in exchange for running on a Pi.

## Prerequisites

- Docker + Compose plugin

- A free TCP port (this guide uses `8222`; the container serves on 80 internally)

- Strong credentials — this is the thing that guards every other login you have

## Step 1: The compose file

```bash
mkdir -p ~/stacks/vaultwarden && cd ~/stacks/vaultwarden
```

Create `docker-compose.yml`:

```yaml
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    ports:
      - "8222:80"
    environment:
      DOMAIN: "https://vault.example.com"
      SIGNUPS_ALLOWED: "true"
      # After the first account exists, flip this to "false"
      ADMIN_TOKEN: CHANGE-ME-64-CHARS-HEX
    volumes:
      - ./data:/data
    restart: unless-stopped
```

Notes on the three environment variables:

- `DOMAIN` — the public URL clients will use. Set it to your final TLS URL before connecting apps, because some app flows (email, OAuth-style links) embed it. If you are LAN-only for now, `http://YOUR_SERVER_IP:8222` works, but update it when you add TLS.

- `SIGNUPS_ALLOWED` — leave `true` only long enough to create your account, then set it to `false` and restart. Open signups on a public URL is how people end up with stranger accounts in their vault server.

- `ADMIN_TOKEN` — required to open the admin panel (at `/admin`). Generate it with `openssl rand -hex 32`. It is a master key to the admin interface: treat it like a password and keep it out of git.

## Step 2: Start it and create your account

```bash
docker compose up -d
docker compose logs -f vaultwarden
```

Open `http://YOUR_SERVER_IP:8222` and register. Your first account is an administrator of the implicit personal organization. Set a *very* strong master password here — it is the only key that decrypts your vault, and there is no “forgot password” that works the way you hope. Write it down offline.

Immediately after: set `SIGNUPS_ALLOWED: "false"` and `docker compose up -d` again.

## Step 3: Connect the official Bitwarden apps

This is the part that makes Vaultwarden feel free: every official Bitwarden client works against it.

- **Browser extension (Firefox/Chrome/Edge/Safari):** in the extension settings, set *Self-hosted* and enter the server URL (`http://YOUR_SERVER_IP:8222` or your TLS URL). Log in with your Vaultwarden account.

- **Mobile apps (iOS/Android):** add a new organization / server, enter the same URL, log in.

- **Desktop apps:** same — set the server URL in settings before logging in.

Everything syncs between them through your server. The extension autofills, the mobile app has the vault offline, and the desktop app is your admin fallback. You are now running your own password infrastructure with no configuration difference visible in the clients.

## Step 4: The admin panel

Open `http://YOUR_SERVER_IP:8222/admin` and paste your `ADMIN_TOKEN`. Useful things in there:

- **Users** — see every account, disable one you no longer recognize.

- **Settings → Global settings** — the runtime view of every environment variable, editable without editing the compose file (changes apply on save; the compose values remain the source of truth on restart).

- **System** — server version, pending updates, and a one-click *update server* button.

## Step 5: TLS and external access

Browsers are increasingly strict about where they will send a master password. For a URL you use daily, put TLS in front — the two clean options from the [Security & Networking](https://chikewa.com/category/security-networking/) series:

- **Cloudflare Tunnel** — `https://vault.example.com`, no open ports, certificates handled. We document it in the [Security & Networking](https://chikewa.com/category/security-networking/) series.

- **Reverse proxy with a real certificate** — Caddy or Nginx Proxy Manager, same idea, more knobs.

Then update `DOMAIN` in the compose file to the HTTPS URL, restart, and point all clients at it. Do not forward port 8222 on the router: a publicly scannable login page for your password vault is precisely what attackers probe first.

## Backups (the part that actually matters)

Everything is in `./data` — the SQLite database, attachments, and (if enabled) the encrypted audit log. A backup is copying that one folder. Because the contents are already encrypted with your master password, you can store the backup anywhere, including the same machine’s offsite target:

```bash
restic -r s3:http://YOUR_MINIO_IP:9000/backups backup ~/stacks/vaultwarden/data
```

One habit that saves you: **export a full encrypted vault file from the Bitwarden app once a month** (Vault → Export → Encrypted JSON) and keep it somewhere the server cannot reach. If the `data` volume is ever corrupted or lost, that file plus your master password is a complete restore. The server database is the source of truth; the encrypted export is the insurance policy.

## Resource usage (measured)

StateRAM

Idle~30–50 MiB
Syncing a large vault (thousands of items)~80–120 MiB

It will run on the smallest Pi you own, next to everything else, and you will forget it is there. That is the point.

## Updating

```bash
docker compose pull && docker compose up -d
```

Vaultwarden migrations run automatically on start. Check the admin panel’s system page after the first start to confirm the new version. As with any service guarding credentials, a one-line restic backup of `./data` before a major update is free insurance.

## FAQ

#### Is this secure? It is not Bitwarden Inc’s server.

The encryption model is the same: zero-knowledge, AES-256, keys never leave your device. The risk profile shifts from “a company holds ciphertext and could be compelled” to “you hold the ciphertext and must not lose your master password”. For most people that is a net improvement. Read the project’s security page for the details, and note it is a community project — audit it if that matters to you.

#### Can I migrate from bitwarden.com?

Yes, in two steps. Export an *encrypted* JSON from the official app (never the unencrypted CSV to a file you store), then in the Vaultwarden-connected app use **Import** to bring that encrypted file in. Your items land in your self-hosted vault with their encryption intact.

#### What about 2FA?

Vaultwarden supports TOTP (authenticator apps) and YubiKey/WebAuthn per user, set under your profile. Turn on TOTP the day you create the account. The master password plus TOTP is the floor for a credential vault.

#### Can I run it on the same box as everything else?

Yes — it is one of the lightest services in this whole series. The only requirement is that `./data` is included in whatever backup job protects the rest of the stacks.

#### Where does this fit?

Vaultwarden is the credentials layer: it is what you log into for [Miniflux](https://chikewa.com/self-host-miniflux-docker-compose/), [Jellyfin](https://chikewa.com/jellyfin-docker-compose-guide/), and every admin panel on this site. Reaching it from outside the house is the tunnel setup from the [Security & Networking](https://chikewa.com/category/security-networking/) series, and its `data` folder is one line in a restic job — the 3-2-1 backup strategy guide walks through that loop.

## What’s next?
The natural next steps from this guide:

- [Secure your home server: SSH, firewall and Docker](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)
- [Miniflux: a private RSS reader](https://chikewa.com/self-host-miniflux-docker-compose/)
- [The self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).