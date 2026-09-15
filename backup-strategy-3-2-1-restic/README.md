# The 3-2-1 Backup Strategy for a Home Server (with restic)


> Every other guide on this site ends with “back up the volume” — this one is what that actually means. The 3-2-1 rule (three copies, two different media, one off-site) is the floor, not the ceiling, for a self-hosted home, and restic is the tool that makes it boring: incremental, encrypted, deduplicated backups to S3 […]

**Full guide:** [https://chikewa.com/2026/09/01/backup-strategy-3-2-1-restic/](https://chikewa.com/2026/09/01/backup-strategy-3-2-1-restic/) · **Category:** Productivity · **Published:** 2026-09-01

---

Every other guide on this site ends with “back up the volume” — this one is what that actually means. The 3-2-1 rule (three copies, two different media, one off-site) is the floor, not the ceiling, for a self-hosted home, and restic is the tool that makes it boring: incremental, encrypted, deduplicated backups to S3 that run unattended and verify themselves. This guide builds the whole loop — what to back up, the restic setup, the cron job, and the restore test that separates a real backup strategy from a hope.

*Intermediate · 12 min · Docker*

## The rule, translated to a home server

- **3 copies** of every file that matters: the live data, a local backup on a second disk, and an off-site copy.

- **2 different media**: your SSD and the backup disk are different devices; the off-site copy is a different *medium entirely* (S3, another machine, an encrypted drive in a different building).

- **1 off-site**: fire, flood, theft and ransomware that spreads over your LAN all take out everything on-site. Exactly one copy must live somewhere the house cannot reach.

The version this site runs: restic on the server, three targets — a second local disk (fast restores of yesterday’s data), [MinIO](https://chikewa.com/minio-docker-compose-s3/) on a second machine (the “off-site” for a home network), and an encrypted local drive you take to a friend’s house or a bank box once a month (the real off-site). You do not need all three on day one; you need the off-site one eventually, and restic makes adding targets later a one-line change.

## Why restic (and not the obvious alternatives)

resticBorgplain rsync to a disk

Incremental + deduplicatedYesYesNo (full copies)
Encrypted at restYesYesNo
Native S3 targetYesYes (via restic/borgbase)No
Self-check (verify)Built inBuilt inYou build it
Retention policies (“keep last 7 daily”)One flagOne flagA script

rsync-to-a-disk is not a backup strategy: it copies what is there, including deletions and ransomware, with no encryption and no version history. restic’s snapshot model — every backup is a named, restorable state of the file set — is what lets you roll back to “before the bad thing happened” instead of “before the last sync”.

## Step 1: What to back up (the inventory)

Walk your stacks and write down the *state* directories. For the services on this site, the list is short and stable:

StackPath to back upNotes

Navidromethe `navidrome_data` volumeDB with play counts; the music folder is source data, see below
Jellyfinconfig volumeMetadata/DB; the media library is source data
MinifluxPostgres volumeSubscriptions and history
DokuWikithe `/data` folderIt is plain-text files — trivial to verify by eye
Home Assistant`./config`Entire setup, tens of MB
Vaultwarden`./data`Encrypted already, but back it up anyway
Gitea`./gitea`Repositories + DB
Immich`./upload` + DB dumpThe photos are the whole point

Two distinctions keep this list from being a trap:

- **State vs source data.** A service’s database and config are state — small, and the thing restic handles beautifully. Your music, photos and videos are source data — large, and often already stored in a library that is itself the archive. Back up the state everywhere; for source data, decide explicitly (photo library → Immich’s `upload/` *is* the archive, so restic it too, or at least the DB dump; music you own on a card → a one-off full copy to the second disk is enough).

- **Named Docker volumes.** Everything above that is a named volume (`navidrome_data`, Postgres data) lives in `/var/lib/docker/volumes/<name>/_data`. Either back that path directly, or bind-mount the stacks’ state into project folders (the convention used in every guide on this site, which is exactly why the inventory is a flat list of paths).

## Step 2: Install and initialize restic

```bash
sudo apt install restic   # or your package manager's equivalent
restic -r /mnt/backup-disk/init --password-file ~/.config/restic/pass init
restic -r s3:http://192.168.1.20:9000/backups \
  --s3-provider minio \
  --s3-access-key BACKUP_USER_KEY --s3-secret-key BACKUP_USER_SECRET \
  --s3-region us-east-1 \
  --password-file ~/.config/restic/pass init
```

Three things to get right here:

- **The repository is a URL, and the same URL must be used for every command against it.** Write both of yours into a file (e.g. `~/.config/restic/repos.txt`) and copy from there. A one-character difference means “repository not found” at 2 a.m.

- **The password file.** `chmod 600` it. This password encrypts everything in the repository — losing it means losing the backups, so it lives in two places outside the backup targets (a password manager entry, and written paper). restic will not recover it for you; that is a feature.

- **A dedicated S3 user.** From the [MinIO guide](https://chikewa.com/minio-docker-compose-s3/): a non-root user with a policy scoped to the `backups` bucket. The backup job should be able to do exactly one thing.

## Step 3: The backup command

Put the paths from the inventory in one file, `~/.config/restic/paths.txt` (one per line; Docker volume paths included), and the actual job becomes:

```bash
restic -r /mnt/backup-disk/init --password-file ~/.config/restic/pass \
  backup $(cat ~/.config/restic/paths.txt | tr '\n' ' ') \
  --tag daily
```

Run it once by hand and watch it work: the first run is a full backup (every file), every run after is incremental (only what changed). On a typical home stack the first run is a few GB; daily runs afterwards are usually under 100 MB.

## Step 4: Retention (forget, but keep the useful)

Without retention, the repository grows forever. The pattern that covers every realistic disaster:

```bash
restic -r /mnt/backup-disk/init --password-file ~/.config/restic/pass forget \
  --tag daily --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
```

Seven daily snapshots (any failure in the last week is restorable), four weekly (the “I broke the config in June” case), twelve monthly (year-over-year). Run `forget` after each `backup`. `--prune` reclaims the space from dropped snapshots; it is the slow step, which is why it runs once a day, not on every snapshot.

## Step 5: Put it on cron (and make it report)

```text
# /etc/cron.d/restic-backup  (or crontab -e as the backup user)
15 3 * * *  backupuser  /home/backupuser/scripts/restic-daily.sh >> /var/log/restic-daily.log 2>&1
```

With `restic-daily.sh` doing backup → forget → a short `--files-from` verify sample, and *emailing you only on failure*:

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO=/mnt/backup-disk/init
PASS=~/.config/restic/pass
PATHS=$(cat ~/.config/restic/paths.txt | tr '\n' ' ')

restic -r "$REPO" --password-file "$PASS" backup $PATHS --tag daily
restic -r "$REPO" --password-file "$PASS" forget --tag daily --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune

# Spot-check: verify a sample of files (full verify is the weekly job)
if ! restic -r "$REPO" --password-file "$PASS" check --read-data-subset=0.01; then
  echo "restic check failed" | mail -s "BACKUP PROBLEM on $(hostname)" you@example.com
fi
```

Silence on success is the design: you want the one email a month that says something is wrong, not sixty that say all is well. (The weekly job — `check --read-data` on the full repository, plus the off-site S3 repository — is the same script pointed at the other URL.)

## Step 6: The restore test (the part everyone skips and needs)

#### Why this is non-optional

A backup you have never restored is a theory. The failure modes it catches are the real ones: the password file was “backed up” only to the machine that died, the paths file listed a folder that moved, the S3 policy silently rejects reads, the snapshot exists but the data chunks do not. Twenty minutes a quarter:

- Pick a real file you care about (a DokuWiki page, a photo from three weeks ago).

- `restic -r $REPO --password-file $PASS restore last --target /tmp/restore-test`

- Open it. The actual file, read by an actual human, on an actual day.

- Delete `/tmp/restore-test`. Done. You now *know* the strategy works.

Write the date you last restored in a note next to the paths file. A “last verified” stamp is the difference between a strategy and a ritual.

## Resource usage (measured)

OperationTypical cost

First full backup (~10 GB of stacks state + photo lib)20–60 min, disk + network bound, ~200 MiB RAM
Daily incremental (small changes)1–5 min, <100 MiB RAM
`check --read-data` full verify (weekly)Re-reads everything: 1 h per 100 GB, schedule it overnight

It runs on the same box as the stacks it protects and never notices it. The hardware it saves is the point.

## FAQ

#### What about the “one off-site” if I do not have a second machine?

Order of preference: a second machine running [MinIO](https://chikewa.com/minio-docker-compose-s3/) (even a Pi in a different room, or a cheap VPS) → an encrypted external drive on a rotation schedule (LUKS, take it off-site monthly) → a provider’s object storage (the last resort, because it is the one copy you do not control). The restic repository URL is the only thing that changes between these; the script, the retention, and the verify jobs are identical.

#### Does restic protect against ransomware on the server?

Partially, and honestly: restic snapshots are append-only from the server’s perspective, so files encrypted *after* the last snapshot are restorable to their pre-encryption state. What it does not protect against is a compromised backup user that deletes snapshots — which is why the off-site repository is the one you verify weekly, and why the S3 user’s policy should be read/write on the repository path only, no admin rights.

#### Can I back up Docker containers themselves?

Back up their state (volumes, per the inventory), not the containers — containers are disposable; `docker compose up -d` rebuilds them. The compose files are text; keep them in [Gitea](https://chikewa.com/gitea-docker-compose/), which is itself a backup target. You end up with the elegant loop: the backup of your infrastructure is one of the things being backed up.

#### What if a backup run fails?

The email tells you. The usual causes, in order: the target disk is unmounted (the `/mnt` path is empty), the S3 target is unreachable (the second machine is down), or a path in the file no longer exists (restic exits non-zero and the mailer fires). Fix the cause, re-run the script by hand, and confirm the next snapshot lands. Do not let two consecutive daily runs fail silently — that is when a “backup” stops being one.

#### Where does this fit?

This is the article every other guide on this site points at: each stack’s “back up the volume” step resolves to a line in `paths.txt` here. The off-site target is [MinIO](https://chikewa.com/minio-docker-compose-s3/), the compose files live in [Gitea](https://chikewa.com/gitea-docker-compose/), and the whole thing is reachable for checking from anywhere via [Cloudflare Tunnel](https://chikewa.com/cloudflare-tunnel-docker-compose/) — with the tunnel itself being just one more line in the inventory.

## What’s next?
The natural next steps from this guide:

- [The self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/)
- [Gitea: your compose files as code](https://chikewa.com/gitea-docker-compose/)
- [Secure your home server](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)

---


## 📁 Files in this directory

- **`scripts/restic-daily.sh`** — Daily backup with retention, prune and spot-check (cron-ready)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).