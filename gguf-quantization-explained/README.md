# GGUF and Quantization Explained: Pick the Right Model Size


> What a GGUF file actually is, what 8B and Q4_K_M really mean, and the memory math that turns “which model should I run” from a guess into arithmetic — with real file sizes measured in the lab.

**Full guide:** [https://chikewa.com/2026/09/16/gguf-quantization-explained/](https://chikewa.com/2026/09/16/gguf-quantization-explained/) · **Category:** AI & LLM · **Published:** 2026-09-16

---

Every local model you run is described by a name like `some-model-8B-Q4_K_M.gguf`, and almost everyone treats those bits after the name as magic strings. This guide takes them apart. What is a GGUF file, what do the two numbers in a model name actually mean, what a quantization level really costs in memory and quality, and how to pick one for the box you have. It is the reference the rest of the series points to, because once you understand size and quantization, “which model should I run” stops being a guess and becomes arithmetic.

*Beginner · 10 min · Concepts*

## What a GGUF file is

GGUF is a single-file format for storing a model. Inside one `.gguf` file you get the model’s weights, the architecture description, the chat template (the instructions that tell the model how to format a conversation), and the vocabulary. That single-file property is the whole point: there is no folder of parts to assemble, no separate tokenizer to match, nothing to forget. You copy one file from machine to machine, or download one file, and it runs. llama.cpp, Ollama and LM Studio all read it, which is why the model ecosystem is built on it. A model you download as GGUF for one of those tools is the same file that the others load — the format is the common currency, and the tools are just different front ends for it.

## The two numbers in a model name

Take a name like `model-8B-Q4_K_M`. The **8B** is the parameter count: roughly eight billion parameters. A parameter is a number the model learned, and the count is a coarse measure of how much it can hold in its “head”. More parameters generally means more capability, but also more memory and slower generation, all else equal. The **Q4_K_M** is the quantization, and it is the second, equally important half of the name. You will see the parameter count written as 0.6B, 1.5B, 4B, 8B, 14B, 32B, 70B and so on. As a rule of thumb for the “B” number: the smaller ones are fast and lightweight, the ones in the 4B to 14B range are the current sweet spot for home hardware, and the 32B and 70B models are the high end that want a real GPU or a lot of RAM.

## What quantization means

A model’s parameters are originally stored at high precision, typically 16-bit or 32-bit numbers. Storing and computing on those is accurate but heavy. Quantization is the process of storing each parameter with fewer bits, trading a little precision for a lot less memory and (often) faster computation. The “Q” in the name stands for the number of bits per parameter: Q8 is 8 bits, Q4 is 4 bits, and so on. Going from 16 bits down to 4 bits shrinks the file to a quarter of its size. The cost is that each parameter is now an approximation of the original, and the model’s output quality degrades a little as you compress harder. Quantization is what makes running a 70B model at all possible on consumer hardware — at full precision it would need hundreds of gigabytes, but quantized it can fit in a fraction of that.

## Reading the quantization codes

The codes you see in practice, from highest to lowest quality, are roughly:

- **F16 / F32** — full precision. The original, uncompressed values. Used for training and as a starting point; far too big to run locally.

- **Q8_0** — 8-bit. Very close to full precision in quality, and about half the size. The “safe” high-quality option when your memory allows it.

- **Q6_K** — 6-bit, a “K-quant”. A good quality/size compromise.

- **Q5_K_M** — 5-bit. Often the best balance for models you want to run well without huge memory.

- **Q4_K_M** — 4-bit. The most common default and the one to understand. The “_K” means it is a mixed-precision K-quant: some parts of the model are kept at slightly higher precision than others, which preserves more quality than a flat 4-bit would. The “_M” is a size variant of that scheme. Q4_K_M is the quantization most model hosts offer first, and for good reason: it is small enough to run on modest hardware and good enough that the quality loss is often barely noticeable.

There are also lower options (Q3, Q2 and below) that squeeze the model much smaller at a real quality cost, and they are worth using when the alternative is not being able to run the model at all. The practical guidance is: reach for the highest quantization your memory can hold. If a model’s Q5 does not fit but its Q4 does, run the Q4. Do not run a Q4 when your box could hold the Q5 — the extra quality is free if you have the memory.

## The memory math, with real numbers

Here is the arithmetic that turns a model name into a memory requirement. The weight size in memory is approximately the parameter count times the bits per parameter, divided by 8 to get bytes. Worked out for a few real cases on the kind of hardware in this series:

- A **4.65B model at Q4** is about 2.95 GB of weights. That is the exact model we ran in the lab: it loaded into a 16 GB box with room to spare for a 32k context, and generated at about 14 tokens per second on a 4-core CPU. The file was 2.95 GB on disk, and the loaded model fit comfortably with several gigabytes of RAM left over for the rest of the system.

- A **0.6B model at Q4_K_M** is about 0.5 GB. This is the model we used for the Ollama tests; it loaded and generated almost instantly, which is why starting with a small model is the right first move.

Two things to add to the weight size. First, the context window costs memory on top of the weights, and it grows with the context length, so a 32k context needs more RAM than a 4k one for the same model. Second, if you have a GPU, you want the weights to fit in VRAM, not system RAM — an 8 GB card can hold roughly an 8B model at Q4 plus a modest context, which is why “8B at 4-bit” is the number people aim for on an 8 GB GPU. The whole exercise is the same everywhere: count the parameters, apply the bits, add the context, and check it fits the memory you actually have. If it does not, drop the quantization or the model size, not your expectations about the rest of the box.

## How to pick a quantization for your box

A method that avoids most dead ends:

- **Find your memory budget.** Free system RAM for a CPU box, or VRAM for a GPU. This is the ceiling.

- **Reserve room for context and the OS.** Do not spend the entire budget on weights. Leave a couple of gigabytes for the context and the rest of the system, or you will be swapping.

- **Pick the model size first, then the highest quant that fits.** Decide how smart you need it to be (the “B” number), then take the best quantization your remaining memory allows. Q8 if you can, else Q6, Q5, Q4 in that order.

- **Prefer a smaller model at a higher quant over a bigger one at a lower one, up to a point.** A 7B at Q5 often beats a 13B at Q3, because the lower quant degrades quality faster than the extra parameters add it. There is a crossover where the bigger model wins, but for home hardware the smaller-and-cleaner choice is usually right.

- **Measure, do not assume.** Run the model, note the tokens per second, and judge the output on a few real tasks. The numbers tell you whether the quantization you picked is the right trade for your use.

## Common mistakes

**Picking by parameter count only.** “70B is the best, I want 70B” is how people end up with a model that cannot load on their box. The parameter count and the quantization are one decision, not two. Always do the memory math before you commit to the size.

**Running a low quant when a higher one fits.** If your box can hold the Q5, running the Q4 is leaving quality on the table for free. Check the memory, then take the best quant that fits.

**Setting a huge context on a small box.** The context is real memory, and it is the quiet thing that pushes a “should fit” model into swapping. If a model loads but is mysteriously slow, the context length is the first thing to cut.

**Mixing a model and quantization from different sources without checking they match.** The GGUF file already has its quantization baked in, so a mismatch is not really possible within a single file — but it is worth knowing that the quantization is a property of the file you download, not a setting you apply later. You cannot “quantize down” a file you already have without running a quantization tool on the full-precision weights.

## How this fits the rest of your home server

Size and quantization are the vocabulary that connects every other guide in this series. When the llama.cpp guide tells you to check whether a model fits, this is the math it means. When the Ollama guide says to start with a small model, this is why 0.5 GB loads instantly and 2.95 GB is the sweet spot on a 16 GB box. When you are deciding whether a bigger model is worth it, the tokens-per-second number you measure is the answer to the question this guide sets up. The model file is the constant: pick the size and quantization that fit your memory, download it once as a GGUF, and any of the runtimes can load it. That is the entire decision, reduced to arithmetic and one measurement.

Tested on:

Hardware4-core / 16 GB4.65B model at Q4_K2.95 GB on disk, runs in 16 GB RAM with a 32k context0.6B model at Q4_K_M522 MB on disk, loads instantlyLast tested: 15 September 2026

## What’s next?
The natural next steps from this guide:

- [The self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/)
- [What hardware for a home server?](https://chikewa.com/what-hardware-for-a-home-server/)

---


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).