# Gitea in Docker: Self-Hosted Git Server (Compose Guide)


> Gitea is a fast, single-binary Git forge you run yourself: repositories, pull requests, issue tracking, code review, and CI hooks, in one container that idles at about 100 MB of RAM. If your code currently lives on a public platform and you would rather it live on hardware you own — or you just want […]

**Full guide:** [https://chikewa.com/2026/08/31/gitea-docker-compose/](https://chikewa.com/2026/08/31/gitea-docker-compose/) · **Category:** Productivity · **Published:** 2026-08-31

---

Gitea is a fast, single-binary Git forge you run yourself: repositories, pull requests, issue tracking, code review, and CI hooks, in one container that idles at about 100 MB of RAM. If your code currently lives on a public platform and you would rather it live on hardware you own — or you just want a second remote that survives a provider’s policy change — this is the twenty-minute setup. This guide covers the Docker Compose install, the first repository, Git over SSH, and the settings that keep a personal forge sane.

*Beginner · 9 min · Docker*

## Why self-host your Git

- **Your code is yours, on your disk.** No ToS change, no account suspension, no “legacy” tier. A `git push` to your server is a file copy to a machine you control.

- **It is a free second remote.** Even if you keep using a public platform for collaboration, having every project also pushed to Gitea is cheap off-box (or on-box, other partition) redundancy with zero service dependency.

- **Private by default, no pricing tier.** Private repositories, unlimited collaborators, and no “who can see this” math at the plan boundary.

The honest caveat: Gitea is the community’s forge, not GitHub’s. You do not get the marketplace, the huge ecosystem of third-party integrations, or free public CI minutes. For personal and small-team work it covers 95% of what those platforms do; for “I need 40 people and 30 integrations” you want the big platforms.

## Prerequisites

- Docker + Compose plugin

- Free ports: `3000` (web) and `222` (Git over SSH — the container’s internal port 22, remapped so it does not fight your server’s real SSH)

## Step 1: The compose file

```bash
mkdir -p ~/stacks/gitea && cd ~/stacks/gitea
```

Create `docker-compose.yml`:

```yaml
services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    ports:
      - "3000:3000"
      - "222:22"   # SSH for git clone via SSH (change if 222 is busy)
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=sqlite3
      - GITEA__server__DOMAIN=git.example.com
      - GITEA__server__SSH_PORT=222
      - GITEA__server__ROOT_URL=https://git.example.com/
      - GITEA__security__INSTALL_LOCK=true
    volumes:
      - ./gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
```

Notes on the choices:

- **SQLite, not Postgres.** For a personal or small-team forge, SQLite is the right default: zero extra containers, and Gitea’s own docs say it is fine for the scale at which people self-host. The moment you want multiple instances or very heavy CI load, swap `GITEA__database__DB_TYPE` to `postgres` and add a DB container — the data directory makes the migration path clean.

- `GITEA__server__SSH_PORT=222` — this is the port Git clients use, and it must match the host-side mapping (`222:22`). Get this wrong and the clone URLs Gitea suggests do not work, which is the single most common first-day bug.

- `GITEA__server__DOMAIN` and `GITEA__server__ROOT_URL` — set these to the final public URL (ideally behind the [Cloudflare Tunnel](https://chikewa.com/cloudflare-tunnel-docker-compose/) setup). They control the URLs Gitea prints in its UI and emails.

- `GITEA__security__INSTALL_LOCK=true` — skips the web install wizard, since everything is set via environment. If you prefer the wizard, remove this line and it will guide you through the same settings on first visit.

- `USER_UID/GID` — match your host user so files on the bind mount have sane ownership. On a fresh box, check `id -u`.

## Step 2: Start it and create your account

```bash
docker compose up -d
docker compose logs -f gitea
```

Open `http://YOUR_SERVER_IP:3000`. With `INSTALL_LOCK=true` there is no wizard; log in as `gitea` (the default admin user the image creates for you — you will be asked to set its password on first login), then under **Site Administration → Users** create your real account and make it an administrator. Delete or demote the `gitea` account once yours works. Log in with the real account from here on.

## Step 3: First repository

Top-right **+** → **New Repository** → give it a name, keep it private, do not initialize with a README (you have existing code). Create it, and you get the clone URLs immediately. Two ways to use it:

**HTTPS with a token** — fine for quick use: create a **Personal Access Token** (your avatar → Settings → Applications), then:

```bash
git remote add mygitea https://YOUR_SERVER_IP:3000/you/myproject.git
git push mygitea main
```

**SSH (the better default)** — set up a key once and every clone is passwordless:

- Your avatar → Settings → **SSH Keys** → add your `~/.ssh/id_ed25519.pub`.

- Clone using the SSH URL Gitea shows — note the port: `git@YOUR_SERVER_IP:222:you/myproject.git` (the colon before the path is part of the scp-style syntax; the port comes right after the host).

- To stop typing the port every time, add to `~/.ssh/config`:

```text
Host gitea
  HostName YOUR_SERVER_IP
  Port 222
  User git
```

Now `git clone gitea:you/myproject.git` just works.

## Step 4: The settings worth changing

- **Disable open registration** (Site Administration → Installation → Registration and login, or the env `GITEA__service__DISABLE_REGISTRATION=true`). A personal forge has no business letting strangers create accounts, even behind a tunnel.

- **Require sign-in** for everything (same section: `REQUIRE_SIGNIN_VIEW=true`). Anonymous browsing of your repositories is off by default for private ones, but making sign-in mandatory closes the anonymous corner entirely.

- **Two-factor authentication** for your account (Settings → Security). It is the same TOTP flow as the [Vaultwarden](https://chikewa.com/vaultwarden-docker-compose/) guide — set it up while you are thinking about credentials.

- **Default branch and push rules** per repo: enforce a default branch name, and optionally reject pushes to `main` so everything goes through a pull request. For a solo developer, PR-to-main is a habit that pays off the day you want a second pair of eyes (or an agent) to review your changes.

## External access

Same rule as every other service: no raw port forwarding of 3000. The two paths, in order of preference:

- **Cloudflare Tunnel** — `git.example.com` → `192.168.x.x:3000`, and update `DOMAIN`/`ROOT_URL` to match. HTTPS clones through the tunnel work fine.

- **Tailscale** — SSH clones over the mesh, which is actually the most comfortable day-to-day: `git clone` from anywhere, no public surface at all.

If you use SSH over the tunnel, remember the tunnel routes HTTP(S) — for raw SSH traffic the Tailscale path is simpler. In practice: HTTPS + tunnel for the web UI and HTTPS clones, Tailscale for SSH, or just pick one and live with it.

## Resource usage (measured)

StateRAM

Idle (SQLite, ~50 repos)~100–150 MiB
Pushing a large repo (1 GB)~300 MiB, disk-bound

It will share a 2 GB machine with the rest of the stack without complaint. Disk is the resource to watch: every clone on the server is a full copy of the history.

## Backups and updates

Everything is under `./gitea` — repositories under `gitea/repositories/`, the SQLite database inside `gitea`. The correct backup is the whole folder, copied while the service is idle (or use `docker compose exec gitea git bundle` per-repo for surgical backups):

```bash
restic -r s3:http://YOUR_MINIO_IP:9000/backups backup ~/stacks/gitea
```

Updates are the standard two-liner:

```bash
docker compose pull && docker compose up -d
```

Gitea runs database migrations on start; read the release notes for anything marked as a breaking change and back up `./gitea` first — it is small, and it is the one folder on the machine that is not “re-downloadable”.

## FAQ

#### Can I keep my existing GitHub repos in sync?

Yes, and it is a good habit: add Gitea as a second remote on every project (`git remote add mygitea ...`) and `git push --all mygitea` after your normal pushes. Two minutes of setup, and your code now exists in two places, one of which you own.

#### Does it handle big monorepos?

Fine for hundreds of MB of history. For multi-GB histories, you get the same scaling behaviour as any Git implementation — shallow clones, partial clones, and LFS if you store binaries. Gitea supports Git LFS out of the box (the `GITEA__lfs__ENABLED=true` setting, with LFS files under `./gitea/lfs`).

#### What about CI/CD?

Gitea has built-in Actions (a GitHub Actions-compatible runner) if you want pipelines on the same box. For lighter needs, webhooks from Gitea into whatever you already run are enough — it is the same webhook model as any other forge.

#### Where does this fit?

Gitea is the code layer of the stack: it pairs with the 3-2-1 backup strategy (the next article in this series — the `./gitea` folder is a first-class backup target in [MinIO](https://chikewa.com/minio-docker-compose-s3/)), and it is reachable from anywhere via the [Cloudflare Tunnel](https://chikewa.com/cloudflare-tunnel-docker-compose/) guide. Everything you push there is a second copy of the work — which is the entire point of having it.

## What’s next?
The natural next steps from this guide:

- [The self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/)
- [DokuWiki: a private wiki](https://chikewa.com/dokuwiki-docker-compose-private-wiki/)
- [Secure your home server](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).