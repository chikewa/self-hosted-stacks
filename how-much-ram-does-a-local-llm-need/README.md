# How Much RAM Does a Local LLM Need?


> Sizing a local LLM to your machine is arithmetic, not guesswork. Here is the formula, three models measured on one box, and the honest trade-off between a smarter model and a slower answer.

**Full guide:** [https://chikewa.com/2026/09/22/how-much-ram-does-a-local-llm-need/](https://chikewa.com/2026/09/22/how-much-ram-does-a-local-llm-need/) · **Category:** AI & LLM · **Published:** 2026-09-22

---

The most common reason a local AI setup disappoints is a RAM mismatch: the model does not fit, or it fits so tightly that the machine swaps and everything grinds to a halt. The good news is that this is arithmetic, not guesswork. A model’s memory need is dominated by the size of its weights, and that size is printed right on the file. This article gives you the formula, and then proves it with three real models measured on one modest box — the same machine, the same day, the same software — so the numbers you see are directly comparable.

*Intermediate · 9 min · Local AI*

## The formula: weights plus a working margin

When a model loads, its weights have to sit in memory. For a GGUF file at 4-bit (the `Q4_K_M` quantization that most people use as a default), the weights-in-memory are almost exactly the file size on disk. On top of that the engine needs a working margin for the context window and the compute buffers. A reliable rule of thumb:

**Free RAM needed ≈ model file size + 1 to 2 GB.**

That is the whole trick. You do not need to understand attention heads or KV-cache math to size your machine. You look at the file, add a couple of gigabytes, and compare it to what you have free. If it fits with room to spare, it will run. If it does not, it will run badly or not at all.

There is one nuance worth stating plainly: this is about *RAM*, not VRAM. On a CPU-only box the weights live in system memory and the CPU computes. If you have a GPU with enough VRAM, the weights can move there and generation gets much faster, but the “does it fit” question is the same — just answered against your VRAM instead of your RAM.

## What we actually measured

We ran three Qwen3 models at 4-bit on a single box — a 4-core Intel i5-6500T with 16 GB of RAM, no discrete GPU — and recorded both the memory the weights took and the real speed. The benchmark was llama.cpp with four threads, measuring prompt processing (how fast it reads your input) and token generation (how fast it writes the answer).

Model (Q4_K_M)Weights in RAMPrompt speedGeneration speedFree RAM left (of 16 GB)

Qwen3 0.6B~0.5 GB~48 tokens/s~47 tokens/s~15 GB
Qwen3 4B~2.3 GB~30 tokens/s~9 tokens/s~13 GB
Qwen3 8B~4.9 GB~9 tokens/s~5 tokens/s~11 GB

Two things jump out. First, **an 8B model fits comfortably in a 16 GB box.** Its weights are about 5 GB, so with the working margin you are using roughly 6–7 GB out of 16, leaving plenty of room for the OS, your other containers, and a healthy context window. The answer to “can a 16 GB mini PC run an 8B model?” is a clear yes — it is not even close to the edge.

Second, and this is the part most articles skip: **fitting and feeling fast are different things.** On a CPU box the generation speed drops as the model grows. The 0.6B model streams back almost instantly. The 4B model is comfortable for everyday use. The 8B model produces a token about every 0.2 seconds, which for a long answer is a noticeable wait — it works, it is private, it is yours, but it is not instant. If your box only has a CPU, that trade-off between how smart the model is and how patiently you are willing to wait is the real decision.

## Turning this into a decision

Match the model to the machine you actually have, not the one you wish you had:

- **8 GB of RAM:** run the small end — a 0.6B to a 4B model at 4-bit. It will feel fast and leave room for everything else. Do not push an 8B model on an 8 GB box; you will spend your session watching it swap.

- **16 GB of RAM:** the sweet spot for CPU local AI. A 4B model is the everyday workhorse (fast and useful), and an 8B model is the step up when you want more quality and can tolerate the slower generation.

- **32 GB or more, or a GPU:** you can move to 13B–14B models at 4-bit, or run an 8B model with a large context window and still feel fine. A GPU with 8 GB+ of VRAM is the single biggest speed upgrade, because it lifts the generation rate that a CPU is capped on.

The quantization is doing real work in these numbers. The 4-bit `Q4_K_M` files are the sweet spot for most people: a good balance of quality and size. Going to a lower quantization (3-bit) shrinks the model and makes it fit more easily at a cost to quality; going to 6- or 8-bit improves quality but roughly doubles the memory, which is when a 16 GB box stops being comfortable. The [GGUF and quantization guide](https://chikewa.com/gguf-quantization-explained/) covers what the names like `Q4_K_M` actually mean and when it is worth changing them.

## Context is the hidden second consumer

The weights are the big, predictable number. The context window is the smaller, variable one: the more conversation history and reference text you keep in front of the model, the more extra memory it needs. A model that fits with a 4,000-token context may not fit the same model with a 32,000-token context on the same 16 GB box. If your setup fits at short context and starts failing or slowing on long ones, that is the context growing into your free RAM, not the model. If you need long context on a CPU box, keep the model in the smaller size class rather than fighting the memory.

## Troubleshooting: when it does not fit

A few of the things you will actually see, and what they mean:

**“Out of memory” on load, or the model fails to start.** The weights plus margin exceed free RAM. Drop the model size a class, or lower the quantization. Check how much is actually free with `free -h` — the OS and other containers count against it.

**It loads but the machine is unusable and the fan is screaming.** That is swap. The model barely fit, so every inference paged memory to disk. It is not a speed problem, it is a fit problem. Same fix: smaller model or more RAM.

**It is much slower than the numbers above.** Make sure you are using as many threads as physical cores (not logical), that nothing else is hogging the CPU, and that you are not running an 8-bit quantization by accident on a CPU box. The speed you should expect on a given model is the one in the table for your size class.

## Bottom line

You do not need to guess whether your hardware can run a local model. Weigh the file, add a couple of gigabytes, and compare it to your free RAM: 8 GB runs the small models, 16 GB runs a comfortable 4B and a workable 8B, and a GPU is what makes it feel instant. The numbers in the table are measured, not estimated, and the method transfers to any model and any box — including the mini PCs that are the natural home for this kind of setup, covered in the [home server hardware guide](https://chikewa.com/what-hardware-for-a-home-server/).

Tested on:

CPU / SoCIntel Core i5-6500T (4 cores, no GPU)RAM16 GBOSDebian 12Enginellama.cpp build dd1ea5243, 4 threadsModelsQwen3 0.6B / 4B / 8B at Q4_K_MResult8B weights ~4.9 GB fit 16 GB; 0.6B ~47 t/s, 4B ~9 t/s, 8B ~5 t/sLast tested: 21 September 2026

## What’s next?
The natural next steps from this guide:

- [Run local AI on your home server](https://chikewa.com/run-local-ai-home-server/)
- [GGUF and quantization explained](https://chikewa.com/gguf-quantization-explained/)
- [Ollama: pull and run a model](https://chikewa.com/ollama-local-llm-guide/)
- [What hardware for a home server (measured)](https://chikewa.com/what-hardware-for-a-home-server/)

---


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).