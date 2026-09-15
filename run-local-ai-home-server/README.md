# Run Local AI on Your Home Server: The Complete Guide


> Local AI has crossed a line: your own mini PC can run a real language model. What your hardware can handle, the three runtimes compared, how to size a model, and a chat window in front of it.

**Full guide:** [https://chikewa.com/2026/09/15/run-local-ai-home-server/](https://chikewa.com/2026/09/15/run-local-ai-home-server/) · **Category:** AI & LLM · **Published:** 2026-09-15

---

Local AI has crossed a line: you no longer need a data-centre’s worth of silicon to run a model that answers questions, drafts text and summarizes documents. On the same mini PC or old desktop you already use for your home server, you can run a large language model entirely on your own hardware — no API key, no per-token bill, no prompt ever leaving your network. This guide is the map for that whole territory. It tells you what your machine can realistically run, which of the three main runtimes (llama.cpp, Ollama and LM Studio) fits how you work, how to pick a model by its size and quantization, and how to put a proper chat interface in front of it. Every command and number below was checked on real lab hardware, and each section links out to the dedicated guide for that piece of the stack.

*Beginner · 12 min · Local AI*

Why people bother: a local model is private by default, works offline, costs nothing after the hardware, and you can swap models whenever you like. The trade-off is that the quality ceiling is set by your RAM and GPU, so the first honest question is not “which app” but “what can my box actually run”.

## What your hardware needs to run

The single most important number is how much of a model’s weights fit in memory at once. A model’s on-disk size is a close proxy for the memory it will want when loaded, plus a margin for the context window you give it. As a working rule:

- **Roughly 4–8 GB of free memory** runs small models (around 0.5B to 4B parameters at 4-bit) comfortably on CPU. These are fast and good enough for summarization, quick Q&A and drafts.

- **8–16 GB** opens up mid-size models (7B–14B at 4-bit). On CPU these are slower but usable for short tasks.

- **A GPU with 8+ GB of VRAM** changes everything: it lets you load the model weights into fast video memory and generate at tens of tokens per second instead of a handful. This is the difference between “it answers” and “it feels instant”.

In the lab we used a 4-core Intel i5-6500T with 16 GB of RAM and no discrete GPU. It ran a 4.65B-parameter model at 4-bit at about **48 tokens per second** reading a prompt and **14 tokens per second** generating. That is genuinely usable for everyday tasks — you type, and the answer streams back in a couple of seconds. The point is not that this box is powerful; it is that a modest box is enough to start, and you can always grow into a GPU later.

If you are deciding what to buy specifically for this, the [home server hardware guide](https://chikewa.com/what-hardware-for-a-home-server/) has real benchmarks and the same “mini PC is the best all-rounder” conclusion applies: a used mini PC with 16 GB of RAM is the cheapest way into local AI that does not feel like a toy.

## The three runtimes, and when to use each

Under the hood, all three popular tools are doing the same job: loading a GGUF model file and serving it. They differ in how much they hide and how much control they give you.

- **llama.cpp** is the foundation. It is a C++ program you build once, and it gives you the most control and the best pure-CPU performance. You drive it from the command line. Choose it when you want maximum performance on a CPU box, you are comfortable in a terminal, or you want to tinker with context length, threads and quantization yourself.

- **Ollama** wraps the same engine in a single install script and a tiny CLI plus an API. One command pulls a model from a registry; another runs it. It is the fastest way to “just have a local model” and the one most tools assume. Choose it for a low-maintenance, scriptable setup.

- **LM Studio** is a desktop app with a graphical interface: browse a model catalogue, one-click download, chat in a window, and flip on a local server when an app needs the API. Choose it if you want the friendliest on-ramp and you are working on a machine with a screen rather than a headless server.

The good news is that the model files are interchangeable across all three. A GGUF you download for Ollama can be loaded in llama.cpp, and vice versa. So pick the runtime for how you like to work, not out of fear of being locked in. A practical comparison of the three, with the numbers we measured, is in the llama.cpp vs Ollama vs LM Studio comparison.

## Choosing a model: size and quantization

Every model you will run is described by two numbers: its **parameter count (the “B” number — 0.6B, 4B, 8B, 14B, 70B) and its quantization** (Q4_K_M, Q5_K_M, Q8_0, and so on). More parameters generally means smarter output; a higher quantization means less quality lost when the model is compressed to fit in memory. The two trade against each other on the same memory budget: a smaller model at a higher quant often outperforms a bigger model at a lower one, up to a point.

As a starting point on a 16 GB box with no GPU, a 4B to 8B model at 4-bit is the sweet spot. It loads quickly, leaves room for a long context, and is fast enough to be pleasant. If you add an 8 GB GPU, an 8B to 14B model at 4- or 5-bit is the target. What each quantization level actually costs in memory and quality — including what “Q4_K_M” means rather than treating it as a magic string — is broken down in the GGUF and quantization explainer.

## Putting a chat interface in front of your model

A raw API endpoint is powerful but unfriendly for day-to-day use. Most people want a chat window with conversations, a model picker and a place to paste documents. **Open WebUI** is the most popular self-hosted option: it runs in a Docker container, connects to Ollama (or any OpenAI-compatible endpoint) in a couple of lines of config, and gives you a clean, chat-app-style interface that works in a browser on any device on your network. It is the natural “front door” once your model is running, and it is what we set up in the lab. The full setup, with a working two-container compose file and the real gotchas, is in the Open WebUI in Docker guide.

## Keeping it safe on your network

Because a local model has no account system of its own, the security of the whole thing comes down to how you expose it. The defaults are your friend: bind the model server and the web UI to `127.0.0.1` (loopback) so only your own machine can reach them, or to a private Docker network. To use the UI from your laptop or phone, put it behind your VPN rather than opening a port to the internet — [Tailscale in Docker](https://chikewa.com/tailscale-docker-compose/) is the simplest way to reach a service on your home network from anywhere without punching holes in your router. If you do want the UI reachable across the house, the [home server security guide](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/) covers firewalls and Docker network isolation, and [Caddy in Docker](https://chikewa.com/caddy-docker-compose/) shows how to front it with HTTPS if you need a proper domain. One rule matters more than all the rest: a model server is a compute box, not a public service — never expose its port directly to the open internet.

## A practical order to follow

When we set this up in the lab, this was the order that avoided the most dead ends:

- **Decide the budget.** Check your free RAM and whether you have a GPU. This sets which model size you are realistic about.

- **Pick the runtime.** Terminal and control: llama.cpp. Low-maintenance and scriptable: Ollama. Desktop and graphical: LM Studio.

- **Run one small model first.** A 0.5B to 4B model at 4-bit. Get one real answer back before you spend time on anything bigger. This is the fastest way to prove the whole pipeline works.

- **Measure it.** Note tokens per second. Now you have a baseline to compare bigger models against, instead of guessing.

- **Grow.** Move to a bigger or better-quantized model, add a longer context, and only then add a GPU if the CPU speed stops being acceptable.

- **Add the front door.** Once the model is happy, put Open WebUI in front of it so the whole house can actually use it.

Each of those steps is its own guide. Start with the runtime that matches how you like to work, run a small model, measure it, and build up from there. That sequence — small and real first, bigger later — is what keeps the whole thing from becoming a pile of downloaded model files you never actually use.

## How this fits the rest of your home server

Local AI is just another resident on the box, and it plays by the same rules as the rest of your stack. It wants a fair share of RAM and, if you give it a GPU, the whole GPU while it is loaded; keep an eye on the box with the [Prometheus and node_exporter setup](https://chikewa.com/monitoring-docker-compose-prometheus-node/) so a chatty model does not quietly eat memory your media server needs. Back up the models folder and the runtime’s state with the same approach as the [3-2-1 backup strategy](https://chikewa.com/backup-strategy-3-2-1-restic/) — a model is a few gigabytes of file, and re-downloading it is the only thing slower than losing it. And because the model lives on the server and the people using it live on their phones and laptops, the [self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/) is the right place to recap how all of this sits together on a machine you already run. That is the whole shape of it: the hardware you chose, the runtime you picked, one small model running, a measured baseline, and a chat window in front — all on hardware you already own.

## What’s next?
The natural next steps from this guide:

- [The self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/)
- [What hardware for a home server?](https://chikewa.com/what-hardware-for-a-home-server/)
- [All AI & LLM guides](https://chikewa.com/category/ai-llm/)

---


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).