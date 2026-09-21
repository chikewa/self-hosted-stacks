# How Many 4K Streams Can Your Home Server Transcode?


> How many simultaneous 4K streams can your home server actually transcode before the picture buffers? We measured it on real hardware, with the numbers that set the ceiling and the method to repeat it on your own box.

**Full guide:** [https://chikewa.com/2026/09/21/jellyfin-4k-hardware-transcoding/](https://chikewa.com/2026/09/21/jellyfin-4k-hardware-transcoding/) · **Category:** NAS & Media · **Published:** 2026-09-21

---

The question that decides whether a home server is worth it: *how many 4K streams can it actually transcode at once?* Not how many the marketing page promises, and not what a YouTube comment claims, but what the hardware does when three people in the house all hit play at the same time. This article answers that with a real test. We took a modest box, generated a genuine 4K source file, and ran Jellyfin’s hardware transcode path (Intel Quick Sync) under load, counting exactly how many simultaneous 4K-to-1080p transcodes the machine keeps up with before the picture starts buffering. Everything below was measured on the same machine, on the same day.

*Intermediate · 9 min · Jellyfin*

## Why transcoding is the real limit

Most home servers do not transcode at all. If your TV or phone can play the file directly, Jellyfin sends the raw stream over and the CPU sits idle — that is called direct play, and it is cheap. The problem only appears when a device cannot play the source: a phone that will not decode 10-bit HEVC, a smart TV that only wants 8-bit H.264 at a certain bitrate, or a client on a slow connection that needs the video scaled down and re-encoded. That is when the server has to *transcode*, and that is where the hardware either keeps up or it does not.

On a modern Intel CPU the transcode is handed off to the integrated graphics unit through a feature called Quick Sync (QSV). The idea is that the video encoder is a dedicated block of silicon, so re-encoding a stream should cost the general-purpose cores almost nothing. In practice the ceiling is set by a mix of the encoder, the scaling step, the memory bus, and how many streams are competing for all of it. That is the number we wanted to find.

## The test setup

We used a box that is deliberately unglamorous, because most people are not buying a $1,500 workstation for a media server:

- **CPU:** Intel Core i5-6500T — a 4-core Skylake from 2015

- **Graphics:** Intel HD Graphics 530 (the iGPU with Quick Sync)

- **RAM:** 16 GB

- **OS / runtime:** Debian 12, Docker 29.7.2

- **Jellyfin:** 10.11.11, with ffmpeg 7.1.4, transcode running with the `/dev/dri` device passed through

The source was a 30-second 4K (3840×2160) H.264 8-bit file at about 20 Mbps — a realistic streaming bitrate. Each test transcoded it to 1080p H.264 at 8 Mbps, which is exactly the kind of downscale a phone or TV triggers. To simulate *N* simultaneous viewers we ran *N* independent transcodes of the same file at once and watched how long a 30-second clip actually took. If a 30-second clip takes 30 seconds or less, the machine is keeping up with real time. If it takes longer, the viewer is buffering.

## How many streams it kept up with

Concurrent 4K→1080p streamsTime to transcode 30 sKept up with real time?Peak RAM

111 sYes — 2.7× faster than real time~437 MiB
221 sYes — 1.4× faster~881 MiB
332 sBarely — 0.94× (just under real time)~1.33 GB
442 sNo — falls behind (0.71×)~1.76 GB
664 sNo — clearly behind (0.47×)~2.63 GB

Read that table as a household. One or two people streaming 4K that needs transcoding: completely comfortable, the box has headroom. Three: it is at its limit, holding real time but with no margin — add a fourth viewer or a second 10-bit title and it starts to slip. Four or more simultaneous transcodes: the picture buffers. For a box this old and this cheap, three concurrent hardware transcodes is a genuinely good result.

The RAM line is worth noticing too. Each additional transcode added roughly 0.4–0.5 GB, so even six streams used less than 3 GB of the 16 GB available. RAM was never the constraint here — the encoder throughput was. That matters if you are sizing a machine: for a media server, the question is almost always the CPU and iGPU, not the memory, unless you are also running a lot of other heavy services.

## The gotcha: not every QSV pipeline works

There is one thing that would have wasted hours, so it is documented here. We first tried to force the *entire* pipeline onto the iGPU — hardware decode, hardware scale, hardware encode — the fully-accelerated path. On this Intel driver (the iHD video driver) that combination failed with a filter error: *“Impossible to convert between the formats supported by the filter”*. The fully-accelerated chain simply did not negotiate a valid pixel format.

The combination that worked — and the one that produced the numbers above — was CPU decode, a standard software scale to 1080p, and the QSV encoder for the final H.264 step. That is essentially what Jellyfin’s default transcode profile does, and it is the practical recommendation: let the encoder ride the iGPU and do the scaling on the CPU. If you are chasing the all-on-GPU path on an Intel iGPU, expect to hit driver limits; the encoder-offload path is the reliable one.

## What this means for your hardware

This box is a 2015 Skylake. Newer Intel iGPUs — the iGPU in an Intel N100 mini PC, or anything Alder Lake and later — have faster QSV encoders and more of them, so a modern mini PC will comfortably do more than three simultaneous 4K transcodes and will transcode 10-bit HEVC and AV1 sources that this older chip struggles with. The exact ceiling will be different on your hardware, but the shape of the test is the same and you can repeat it on your own box: generate a 4K source, run the transcode with your real device passthrough, and count how many concurrent streams hold real time. The method is the point, because it turns “my TV buffers sometimes” into a number you can act on.

A few things that change the number in practice:

- **Source format.** 8-bit H.264 sources are the cheap case. 10-bit HEVC or AV1 sources cost more to decode, so the ceiling drops.

- **Output resolution and bitrate.** Transcoding to 720p is cheaper than to 1080p; a higher output bitrate costs more.

- **How much is direct play.** The more of your household that direct-plays, the fewer transcodes you actually ever need, and the more margin you have left.

## Troubleshooting a server that buffers

If your Jellyfin is buffering when you know it should be able to keep up, work down this list:

**Confirm it is transcoding at all.** If it is direct-playing, the buffer is a network problem, not a CPU problem. The web client and the TV app show which mode is active. If it is transcoding and buffering, you have hit the ceiling above.

**Check the device is actually passed through.** On a Linux box the container needs `/dev/dri` mapped in and the user running it in the right group. If the passthrough is missing, Jellyfin falls back to a slow software encoder and the ceiling drops to a fraction of what the table shows.

**Look at the transcode profile.** A profile that outputs 10-bit or a very high bitrate is doing more work per stream than it needs to be. For phones and TVs, 8-bit H.264 at a moderate bitrate is almost always enough.

**Watch the real resource.** If the CPU is pinned and RAM is low, you are CPU-bound and the only real fixes are fewer concurrent transcodes, a cheaper output profile, or a faster machine.

## Bottom line

For a 4-core 2015 box with a basic Intel iGPU: three concurrent 4K-to-1080p transcodes is the ceiling, RAM is not the bottleneck, the encoder-offload (not all-on-GPU) path is the reliable one, and a modern N100-class mini PC will do meaningfully better. If you are deciding what to buy for a media server, the transcoding headroom is the spec that actually predicts whether the household gets buffering — and it is a number you can measure on any candidate machine with the method above.

Tested on:

CPU / SoCIntel Core i5-6500T (4 cores, 2015)GraphicsIntel HD Graphics 530 (Quick Sync)RAM16 GBOSDebian 12Docker29.7.2Jellyfin10.11.11 (ffmpeg 7.1.4)Result3 concurrent 4K→1080p transcodes at real time; 4+ fall behindLast tested: 21 September 2026

## What’s next?
The natural next steps from this guide:

- [Set up Jellyfin with Docker Compose](https://chikewa.com/jellyfin-docker-compose-guide/)
- [Reach Jellyfin from outside with Tailscale](https://chikewa.com/tailscale-docker-compose/)
- [What hardware for a home server (measured)](https://chikewa.com/what-hardware-for-a-home-server/)
- [More NAS & media guides](https://chikewa.com/category/nas-media/)

---


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).