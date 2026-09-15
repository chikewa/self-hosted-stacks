# DokuWiki in Docker: A Private Wiki on Plain-Text Files (Compose Guide)


> DokuWiki stores every page as a plain-text file — no database, no lock-in. The Docker Compose setup, the five-minute wizard, and how to back a plain-text wiki up by copying a folder.

**Full guide:** [https://chikewa.com/2026/08/23/dokuwiki-docker-compose-private-wiki/](https://chikewa.com/2026/08/23/dokuwiki-docker-compose-private-wiki/) · **Category:** Productivity · **Published:** 2026-08-23

---

Beginner · 7 min · Docker · Wiki

**Tested on:**

OS
Any Linux (verified on Debian 12)

Docker
29.7

Hardware
4-core x86, 16 GB RAM

Software
DokuWiki (stable) 

Last tested: 22 August 2026

## On this page

- [Why DokuWiki in 2026](#why-dokuwiki-in-2026)

- [Prerequisites](#prerequisites)

- [Step 1: The compose file](#step-1-the-compose-file)

- [Step 2: Start and run the wizard](#step-2-start-and-run-the-wizard)

- [Step 3: The editor and page syntax](#step-3-the-editor-and-page-syntax)

- [Step 4: The settings worth changing](#step-4-the-settings-worth-changing)

- [Step 5: Backing up a plain-text wiki](#step-5-backing-up-a-plain-text-wiki)

- [Resource usage (measured)](#resource-usage-measured)

- [Updating](#updating)

- [FAQ](#faq)

DokuWiki is a PHP wiki that stores every page as a plain text file on disk — no proprietary database format, no lock-in, trivially backed up by copying a folder. In Docker it runs in one container with about 25 MB of RAM at idle and a five-minute setup. This guide walks through the compose file, the first-run wizard, and the settings worth changing.

## Why DokuWiki in 2026

Self-hosted wiki options fall into two camps. The heavy ones (MediaWiki, BookStack, Outline) are powerful but expect you to configure users, groups, search backends, and plugins before you write a single page. DokuWiki is the deliberate opposite: it is the original “no database, no fuss” wiki, and its defining property is still its best one — **your entire wiki is a directory of text files**.

DokuWiki
BookStack
Outline

Storage format
Plain text files
MySQL/MariaDB
PostgreSQL

Setup time
~5 min
~15 min
~15 min + auth

Idle RAM (measured)
~25 MiB
~100 MiB+
~200 MiB+

Backup
Copy a folder
DB dump + uploads
DB dump + uploads

Best for
Personal/family notes, documentation
Team knowledge bases
Polished team docs

If you need roles, SSO, and a polished SaaS look for a team, BookStack or Outline are the better tools. For personal notes, a household wiki, or a documentation home that must survive for a decade, DokuWiki’s plain-text core is the safer bet: any editor can open the files, and they render correctly with any markdown-capable tool if you ever leave.

## Prerequisites

- Docker + Compose plugin

- A free TCP port (this guide uses `8081`)

## Step 1: The compose file

One important gotcha up front: the community image name on Docker Hub has moved over the years. The current official image is `dokuwiki/dokuwiki`, and the tag to pin is `stable` (the `dokuwiki:dokuwiki-2024` tag you will see in older tutorials no longer pulls — we hit exactly that during testing and it cost a pull error). Use this:

```bash
mkdir -p ~/stacks/dokuwiki && cd ~/stacks/dokuwiki
```

```yaml
services:
  dokuwiki:
    image: dokuwiki/dokuwiki:stable
    container_name: dokuwiki
    ports:
      - "8081:80"
    volumes:
      - dokuwiki_data:/dokuwiki/data
      - dokuwiki_conf:/dokuwiki/conf
    restart: unless-stopped

volumes:
  dokuwiki_data:
  dokuwiki_conf:
```

Why two volumes: `data` holds your pages (the plain-text files) and attachments; `conf` holds the configuration that the first-run wizard writes. Keeping both as named volumes means an image update never touches your content, and you can back up the wiki with two `docker cp` calls or a bind mount if you prefer to see the files on disk.

## Step 2: Start and run the wizard

```bash
docker compose up -d
docker compose ps
```

The official image includes a healthcheck — you will see `healthy` after a few seconds, which is a nice confirmation the web server is actually serving. Open `http://YOUR_SERVER_IP:8081`.

First visit runs the setup wizard: it asks for an admin login and password, the language, and the site title. That is the entire configuration. After the wizard, `conf/` contains a `local.php` with those choices — which is also why the conf volume must persist across updates.

## Step 3: The editor and page syntax

DokuWiki pages use its own lightweight syntax (a structured subset of markdown):

- `== Heading ==` and `=== Sub-heading ===`

- `* bullet` and `# numbered`

- `[[namespace:page]]` for internal links — creating the link also creates the page skeleton

- `----` for a horizontal rule

- Tables, code blocks (`<<<code>>>`), and images have short, regular forms

The namespace system is the feature to understand: pages live in `namespace:page`, which maps to directories on disk. A “Projects” section with “Server” and “Network” pages is simply `projects:server` and `projects:network`. You can restructure the whole wiki by moving folders — the links update because they are path-based.

## Step 4: The settings worth changing

- **Authentication.** The default is the internal user store, which is correct for a LAN wiki. Do not expose DokuWiki to the internet without putting it behind an auth layer (reverse proxy or Tailscale) — see the [Security & Networking](https://chikewa.com/category/security-networking/) series.

- **Revisions and diffs.** On by default, and the single best feature for notes: every save is a versioned revision you can diff and revert. Keep it on.

- **Search.
 The built-in full-text index is fine up to a few thousand pages. Beyond that, add a dedicated search backend — but most personal wikis never need it.

- Media uploads.** Allowed by default for logged-in users. Restrict who can upload if you run a multi-user household wiki.

- **Timezone and date format** — trivial, but set once so revision history reads sensibly.

## Step 5: Backing up a plain-text wiki

This is where the architecture pays off. A complete backup is:

```bash
docker run --rm -v dokuwiki_data:/data -v dokuwiki_conf:/conf \
  -v ~/backups:/backup alpine tar czf /backup/dokuwiki-$(date +%F).tar.gz \
  --transform 's,^,dokuwiki/,' /data /conf
```

Run it weekly from cron. Restore is the inverse: extract into the volumes (or point a fresh container at the extracted folders). No database dump, no export format, no version compatibility matrix between wiki releases. Compare that to a database-backed wiki, where a failed restore means reconstructing a schema.

## Resource usage (measured)

State
RAM

Idle
25 MiB

Editing a page
~30–40 MiB

From the same verified stack as our [starter guide](https://chikewa.com/self-hosting-starter-guide/). It is the lightest of the three starter services.

## Updating

```bash
docker compose pull && docker compose up -d
```

DokuWiki ships a built-in upgrade routine that runs on start when a new version is detected; the wizard’s configuration in `conf` survives untouched.

## FAQ

#### Can I import existing markdown or org-mode notes?

Yes, with the import plugins (Markdown, reStructuredText, and others) or by pasting — DokuWiki converts on save. For a one-off migration of a large tree, converting to DokuWiki syntax with a script and dropping the files into the `data` volume works too, since the format is predictable.

#### Does it work offline / without internet?

Completely. No phoning home, no external fonts required, no analytics. It is one of the few web apps that is genuinely self-contained.

#### Multiple users?

Yes — create users in the admin panel, and groups let you control who can edit which namespaces. A household “shared notes” wiki with per-person namespaces is a common setup.

#### Where does this fit?

DokuWiki is the third service in our [self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/), alongside [Miniflux](https://chikewa.com/self-host-miniflux-docker-compose/) and [Navidrome](https://chikewa.com/navidrome-docker-compose-guide/). If your notes grow into a team knowledge base, the [NAS & Media](https://chikewa.com/category/nas-media/) and future “team tools” guides cover the heavier options.

## What’s next?

Your wiki is live and backed up by a folder copy. From here:

- [Self-hosting Starter Guide: the full path from hardware to a working server](https://chikewa.com/self-hosting-starter-guide/)

- [How to Self-Host Miniflux with Docker: your reading, your rules](https://chikewa.com/self-host-miniflux-docker-compose/)

- [Navidrome in Docker: your own music server](https://chikewa.com/navidrome-docker-compose-guide/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).