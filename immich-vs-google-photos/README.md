# Immich vs Google Photos: Can You Actually Replace It?


> Immich is the credible answer to ‘I want to stop using Google Photos.’ Here is where it matches, where it still falls short, and the one slow step that is the real work: the migration.

**Full guide:** [https://chikewa.com/2026/09/24/immich-vs-google-photos/](https://chikewa.com/2026/09/24/immich-vs-google-photos/) · **Category:** NAS & Media · **Published:** 2026-09-24

---

Google Photos is where most people’s pictures already live, and “what if I stopped using it” is one of the most common self-hosting motivations — usually a mix of privacy, control, and not wanting a cloud service to decide what happens to a decade of family photos. Immich is the leading self-hosted answer. This is an honest comparison of the two, including the things Immich still does not match, and what it actually takes to move off Google Photos rather than run the two side by side.

*Intermediate · 8 min · Immich*

## What you get on each side

Google Photos is a polished, finished product. Backup from your phone is automatic and invisible, search by text (“sunset at the beach”) and by object is excellent, the timeline is beautiful, and sharing is frictionless because your contacts are already there. The trade-offs are that it is a closed service, your data is on their infrastructure, it is subject to their terms and their pricing for extra storage, and the ML features and your photos are processed on their servers.

Immich gives you the same core job — a photo library that backs up from your phone, groups by face, searches by object and by natural-language query, and stores the original files — but on your own hardware. The machine learning runs on your box, the originals are plain files in a folder you can copy anywhere, and there is no account and no service in the path. The setup is covered in the [Immich Docker guide](https://chikewa.com/immich-docker-compose-photo-library/).

## Where Immich genuinely matches Google Photos

- **Automatic phone backup.** The Android and iOS apps back up your camera roll to the server, and the phone keeps working offline. For the “stop losing photos if I lose my phone” job, it does it.

- **Face grouping.** It detects and groups faces so you can find everyone, the way Google does.

- **Object and text search.** The machine-learning side supports object detection and a natural-language query box, so “what did I shoot of the dog” works.

- **The originals are yours.** Everything lands in a plain upload folder. Google Photos’ originals are accessible but tied to the service; Immich’s are literally files on your disk.

## Where Immich still does not match

Being honest about the gap matters, because it is the difference between “replace it this weekend” and “run it alongside for a while.”

- **Polish of the web and timeline experience.** Google Photos’ interface is more refined. Immich is good and improving, but a long session in the timeline and the editing tools is still a notch behind.

- **Sharing with people who are not on the system.** Sharing a photo with a relative is frictionless in Google because they are there. In Immich, sharing with someone outside your server means sending them a file or a link, not a native share.

- **Search quality out of the box.** Google’s search is trained on an enormous corpus and is very good immediately. Immich’s search depends on the ML models running on your hardware and takes time to index a large library.

- **Indexing time on first import.** The ML side (faces, embeddings) is CPU-hungry on first import. A large library takes a while to fully index — hours on a decent desktop CPU, longer on a Raspberry Pi. The backup and browsing work from the first photo; the smart features catch up in the background.

## The migration is the real work

Running Immich is straightforward; the hard part is getting your existing photos off Google Photos and into it, because Google does not offer a clean bulk download of the originals in a layout that Immich wants. The practical path is:

- Use Google Takeout to request your photos and videos as originals (not screenshots), which produces a large archive.

- Extract it and let Immich import the folder as a library — it scans the files and builds the timeline.

- Let the machine-learning indexing run in the background until faces and search catch up.

After that, point your phone’s Immich app at the server for new photos, and you are running your own library with the old photos inside it. Plan for the Takeout export to be slow and large; it is the least glamorous step, but it is the only one that moves the history.

## Resource reality

Immich is one of the heavier “simple” self-hosted apps, because it carries a real machine-learning pipeline. In the lab an empty-library Immich stack idled at roughly 1.3 GB of RAM across its four containers (server, database, machine-learning, and cache) on a 4-core box. A comfortable deployment wants at least 4 GB free for it, more if you are indexing a large library on CPU. That is real, but it is the same class of box that runs a media server, so for most homelabbers it fits.

## Whichever you pick

If you…PickWhy

Want zero effort, best-in-class search, and do not mind a closed cloudGoogle PhotosMost polished, best search, frictionless sharing
Want your photos and the ML on your own hardware, no serviceImmichOriginals are files you own, no account, no cloud in the path
Are on a home server already and want to reduce a dependencyImmichIt fits the same box and removes a recurring storage cost
Mainly share photos with family who are all on GoogleGoogle PhotosNative sharing wins until your household is on Immich

## Bottom line

Immich is a real replacement for the core job of Google Photos — automatic backup, face groups, object and text search, and originals you own — and for a home-server person it removes a recurring cloud dependency and keeps the data on hardware they control. The honest gaps are polish, out-of-the-box search quality, and the friction of sharing with people outside your system, plus a migration where the Google Takeout export is the slow part. If you are willing to do the one-time migration and accept that the smart features take time to index, Immich is the credible “I want to replace Google Photos” answer.

Tested on:

Immichv3.2.2 (4 containers)OS / runtimeDebian 12, Docker 29.7.2Idle RAM (empty library)~1.3 GB total (server 755 MiB, postgres 364 MiB, ML 169 MiB, cache 12 MiB)NoteA fresh install must use the current ghcr.io/immich-app/postgres image (see the Immich guide)Last tested: 21 September 2026

## What’s next?
The natural next steps from this guide:

- [Immich Docker Compose photo library](https://chikewa.com/immich-docker-compose-photo-library/)
- [3-2-1 backup strategy with restic](https://chikewa.com/backup-strategy-3-2-1-restic/)
- [Reach Immich remotely with Tailscale](https://chikewa.com/tailscale-docker-compose/)
- [Nextcloud for file storage](https://chikewa.com/nextcloud-docker-compose/)

---


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).