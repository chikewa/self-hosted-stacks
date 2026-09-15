# What Hardware for a Home Server? Raspberry Pi vs Mini PC vs Desktop


> Raspberry Pi, used mini PC or repurposed desktop? A buying guide with real disk benchmarks, RAM guidance and the 3-2-1 storage rule.

**Full guide:** [https://chikewa.com/2026/08/24/what-hardware-for-a-home-server/](https://chikewa.com/2026/08/24/what-hardware-for-a-home-server/) · **Category:** Hardware · **Published:** 2026-08-24

---

The most expensive decision in self-hosting is the one you make before the first `docker compose up`: what hardware does the server run on? Get it wrong and you either pay for performance you never use, or spend every transcoding session wishing you had. This guide is the buying decision, not the assembly instructions. It compares the three realistic options for a first home server — a Raspberry Pi, a used mini PC, and a repurposed desktop — with the kind of numbers that are hard to get from a product page, because we measured them.

*Beginner · 10 min · Linux*

## What a home server actually needs

Before comparing machines, it is worth being precise about the workload, because “home server” is three different jobs that people merge into one.

**Job 1 is the always-on baseline:** a handful of small containers (RSS, notes, a music server) idling 24/7. This is where power consumption is the real cost: a machine that idles at 6 W costs roughly four times less to run per year than one that idles at 24 W, on typical EU tariffs, and it will outlive its components because the disks and fans do the little work.

**Job 2 is bursty media work:** transcoding, photo optimization, large initial scans. This is CPU- and disk-bound, and it is the job that punishes underpowered hardware. A machine that idles beautifully can still be the wrong machine if it cannot take a 1080p transcode without the rest of the house noticing.

**Job 3 is storage:** files, photos, backups. This is where capacity and endurance matter more than anything else, and where the storage decision is separate from the computer decision. We cover storage at the end, because it is the one part of a home server that is genuinely hard to upgrade later.

## Option 1: Raspberry Pi

The Raspberry Pi is the classic entry point for good reasons: it idles at about 3–5 W, it is cheap, it is quiet, and for Job 1 it is completely sufficient. A Pi running a dozen small containers is the right machine for a first server that is learning what it will actually be used for.

The honest limits are Job 2 and storage. There is no hardware transcoding worth having, single- or dual-core performance is a fraction of a mini PC, and the microSD slot is the weakest storage path in the hobby — fine for the OS, wrong for a media library. The pricing situation is also worth knowing before you buy: after the 2025–2026 memory-price increases, the line-up we see is roughly **$45 for a 1 GB Pi 5, $85 for an 8 GB Pi 4, and $205 for a 16 GB Pi 5**, with a 16 GB board at the top. If a Pi is the right machine for you, the 8 GB model is the one to buy — 1 GB is a development toy, not a server.

Our rule of thumb: buy the Pi to learn the workflow, and treat it as a trial of your actual needs. Most people who start on a Pi discover within a year exactly which job it cannot do, and that discovery is worth the price of admission.

## Option 2: the used mini PC (our default recommendation)

For a server that will do all three jobs, the used mini PC is the best value in the hobby, and it is the class of hardware the Chikewa lab runs. The shape of the deal is consistent across the market: machines from the 2019–2023 corporate refresh cycle (the Intel NUC class, Dell, Lenovo, HP equivalents) sell used with a 4- or 6-core U-series or T-series CPU, 16 GB of RAM and a 256–512 GB NVMe, for a fraction of the new price.

Why this class wins for most people. It idles at 10–15 W — far above a Pi, far below a desktop. Its cores handle the baseline containers with room to spare. And crucially, most of them have an Intel iGPU, which means hardware transcoding is available out of the box: the same Quick Sync path our [Jellyfin guide](https://chikewa.com/jellyfin-docker-compose-guide/) documents. That is a feature the Pi simply does not have, and it is the feature that separates “direct play” from “stutter” when a client asks for a transcode.

What to check before buying, in order:

- **Generation, not brand.** Anything from Intel 8th generation (Coffee Lake, 2017) onward has four real cores and DDR4; anything older is fine for Job 1 only.

- **RAM: 16 GB if you can get it, 8 GB as the floor.** Containers are cheap, but a media server with a big library and a few active streams eats RAM faster than you expect.

- **Two M.2 slots if you can find them.** One for the OS, one for a faster media SSD. This is the single most common “I should have checked this” in used mini PC buying.

- **No visible corrosion, and a seller who will boot it for you.** A used machine that will not POST is not a bargain, it is a repair project.

The lab machine for this series is exactly this class: a 4-core i5-6500T (2.5 GHz, 3.1 GHz burst), 16 GB of RAM and a 233 GB NVMe drive. It idles Jellyfin at around 240 MiB, handles a 1080p transcode without breaking a sweat, and its disk numbers are below, because disk is where used hardware surprises you.

## Option 3: the repurposed desktop

If you already own a desktop, or can get one for nothing, it is a legitimate server: maximum cores per euro, easy RAM upgrades, and storage space no mini PC matches. The case against it is the steady state: an old desktop idles at 40–80 W, which on a 24/7 schedule costs more per year than the machine cost secondhand, and it is louder than you remember.

Our rule: a repurposed desktop is the right server for a heavy transcoding or backup workload you have already proven you need, and the wrong server for a first machine. Do not buy a desktop to start with; earn it.

## Storage: the decision that is hard to reverse

The computer is replaceable; the data is not. Three principles, in order of importance.

**1. The 3-2-1 rule before any product choice.** Three copies of what matters, on two different media, with one off-site or off-box. For a home server this usually means the original, a second disk in the same box, and a drive that physically leaves the house (or a remote backup target). No amount of fast storage compensates for two copies in one fire.

**2. Match the disk to the job.** OS and databases want NVMe; media and bulk storage want big, cheap, low-power HDDs; photos and anything you are transcribing want SSD. Our lab numbers on the NVMe — **622 MB/s sustained writes, 1.1 GB/s reads** — are what “fast enough for anything” looks like, and they come from a drive that costs a small fraction of the machine. For a first server, one NVMe for the OS and one large HDD for media is the configuration we would actually build.

**3. Never put the only copy of your data on the same drive as the OS.** A corrupted filesystem takes the data down with the system that was supposed to serve it. A separate volume, a separate disk, ideally a separate machine for the second copy.

#### The numbers we measured

ComponentSpecMeasured

CPUIntel i5-6500T, 4 cores, 2.5 GHz / 3.1 GHz burst173 MB/s single-core sha256
RAM16 GB DDR413 GB available at rest
Disk233 GB NVMe (8% used)622 MB/s write, 1.1 GB/s read (sustained, 512 MB)
SwapNone configured—

Context for the sha256 number: it is a single-core memory-bound load, which is roughly what a checksum-heavy backup job or a small transcode looks like to one core. Four of those cores working in parallel is why a 4-core U-series machine feels fast for server work even at modest clocks.

## Decision summary

- **Learning, low budget, low power:** 8 GB Raspberry Pi, OS on a quality microSD, small SSD for anything persistent.

- **The default for a real first server:** used 8th-gen-or-newer mini PC, 16 GB RAM, NVMe for OS + large HDD for media, iGPU for transcoding.

- **Heavy transcoding / backup you have already proven:** repurposed desktop or a current-gen box with a discrete GPU.

- **Every option:** 3-2-1 for the data that matters, and a second disk before the first one is full.

Whichever you choose, the next step is the same: a clean Linux install, Docker, and the [starter guide](https://chikewa.com/self-hosting-starter-guide/). The hardware only decides how much headroom you have when the stack grows.

## FAQ

#### Is a Pi 5 enough for a family media server?

For direct play of well-encoded content, yes. The moment a client needs a transcode, there is no hardware path to save it, and the CPU will spend the rest of the movie at 100%. It is a great learning machine and a limited media server, and it is worth being clear about which one you are buying.

#### How much RAM do I actually need?

8 GB runs a modest stack with headroom; 16 GB is the number we recommend for anything that will host a media library plus a few other services, because it is cheap used and it removes a whole class of “why is it swapping” questions. 32 GB is only justified with a big Plex/Jellyfin library plus a VM or two.

Should I buy new instead of used?

For the computer part of a home server, used is almost always the better deal: the performance gap between a two-year-old and a current mini PC is smaller than the price gap, and the failure modes (a disk, a fan) are the same either way. New money is better spent on storage, where reliability and warranty still matter.

Tested on:

OSDebian 12Docker29.7.2Hardwarei5-6500T / 16 GB RAM / 233 GB NVMeSoftwareNVMe: 622 MB/s write, 1.1 GB/s readLast tested: 23 August 2026

## What’s next?
The natural next steps from this guide:

- [The Self-Hosting Starter Guide](https://chikewa.com/self-hosting-starter-guide/)
- [Jellyfin in Docker: self-hosted media server](https://chikewa.com/jellyfin-docker-compose-guide/)
- [Secure your home server: SSH, firewall and Docker networks](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)

---


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).