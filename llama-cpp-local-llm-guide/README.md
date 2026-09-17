# llama.cpp: Build, Run and Benchmark a Local LLM (CPU)


> Build llama.cpp from source, load a GGUF model, serve it with llama-server and measure real tokens-per-second on a modest 4-core CPU box — the exact flags that matter and the failures we hit.

**Full guide:** [https://chikewa.com/2026/09/17/llama-cpp-local-llm-guide/](https://chikewa.com/2026/09/17/llama-cpp-local-llm-guide/) · **Category:** AI & LLM · **Published:** 2026-09-17

---

llama.cpp is the engine under the hood of most local AI setups, and it is also the most direct way to run a model when you have a CPU box and want to get the most out of it. It is a C++ program: you build it once from source (or grab a prebuilt binary), point it at a model file, and it generates text — from the command line, or as a small HTTP server that other apps can talk to. There is no account, no registry to sign up for, and nothing that phones home. This guide builds it, loads a real model, measures how fast it actually runs, and shows the exact flags that matter. Everything was done on a 4-core Intel i5-6500T with 16 GB of RAM and no discrete GPU, so the numbers here are what a modest CPU box really delivers.

*Intermediate · 12 min · C++ / CLI*

## What llama.cpp gives you

When you build llama.cpp you get a family of small tools in a single `build/bin` folder. The ones you will actually use are:

- **`llama-server`** — runs a model as an HTTP server with an OpenAI-compatible API. This is what you point a chat app or a script at. It is the one we used in the lab.

- **`llama-cli`** — an interactive chat in your terminal. Good for a quick “does this model work” check.

- **`llama-bench`** — measures prompt-processing and token-generation speed for a model. This is how we got the numbers below, and it is the tool to reach for whenever you want to compare models or quantizations objectively.

- **`llama-quantize`** — converts a full-precision model to a smaller quantized version (Q4, Q5, Q8, …). Useful when you have a full model and want to shrink it to fit your memory.

The reason people use it directly rather than a wrapper is control: you choose the context length, the number of threads, the GPU split, and you see exactly what is happening. The cost is that there is no one-click “pull this model” — you manage the model files yourself.

## Building it

The build needs a C++ compiler and CMake. On a Debian/Ubuntu box:

```bash
sudo apt update
sudo apt install -y build-essential cmake git

git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(nproc)
```

On the lab box this completed cleanly with the default CPU backend. The key point for a CPU-only machine: leave GPU support off (which is the default when you have no CUDA toolkit installed). If you *do* have an NVIDIA GPU, you install the CUDA toolkit and add `-DGGML_CUDA=ON` to the `cmake -B build` line, and the same build will offload the model weights to the GPU. We built a CPU Release build here, which is the configuration that produces the honest CPU numbers in this guide.

After the build, everything you need is in `build/bin`. Confirm it with `./build/bin/llama-cli --version`. In the lab we were on a recent build (commit `dd1ea5243`), which is what produced the binary that ran the tests below.

## Loading and running a model

A model for llama.cpp is a `.gguf` file — one file, self-contained, with the weights and the chat template inside it. You get these from a model host such as Hugging Face (the GGUF versions), and you put them anywhere on disk. You do not need a specific folder structure; the tools just take a path.

For a quick interactive test, `llama-cli` is the fastest way to see if a model works at all:

```text
./build/bin/llama-cli -m /path/to/model-Q4_K_M.gguf -c 4096 -t 4
```

The flags that matter:

- `-m` — the model file. Everything else hangs off this.

- `-c` — the context window in tokens. This is how much of the conversation the model can “see” at once. It costs memory, so do not set it larger than you need. 4096 is a fine default; we used 32768 for the server run below.

- `-t` — the number of CPU threads. Match this to your physical cores. On the 4-core lab box, `-t 4` is the honest choice; setting it to 8 would just add contention.

## Running it as a server

For real use, run `llama-server` so your apps can talk to it over HTTP. In the lab this is exactly the command we used:

```text
./build/bin/llama-server \
  -m /home/chikewa/models/gemma-4-E2B-it-UD-Q4_K_XL.gguf \
  --host 0.0.0.0 --port 8080 \
  -c 32768 \
  --api-key-file /home/chikewa/api-keys.txt
```

This serves an OpenAI-compatible API on port 8080. Once it is up, the model list lives at `/v1/models` and chat completions at `/v1/chat/completions`, so any client written for the OpenAI API works unchanged. We confirmed the server answered `{"status":"ok"}` on its health endpoint and returned the loaded model on `/v1/models` before sending any real requests. Two notes from the lab: bind `--host 0.0.0.0` only if you genuinely intend the rest of the network to reach it; on a server that should stay private, `--host 127.0.0.1` is the safer default and you reach it through your VPN. And the `--api-key-file` flag means the server will require a key on requests, which is worth turning on the moment anything other than your own machine might see the port.

## Measuring how fast it actually is

This is the part that turns a guess into a decision. `llama-bench` runs a prompt-processing test (how fast it reads your input) and a token-generation test (how fast it produces the answer), and prints tokens per second for each. On the lab box, with the 4.65B-parameter gemma model at Q4_K and `-t 4`:

```text
./build/bin/llama-bench \
  -m /home/chikewa/models/gemma-4-E2B-it-UD-Q4_K_XL.gguf \
  -p 512 -n 128 -t 4
```

The result we measured:

- **512-token prompt processing: about 48.4 tokens per second.** This is the “it reads your long prompt” speed. At ~48 t/s, a 1,000-token prompt is digested in roughly 20 seconds.

- **128-token generation: about 13.6 tokens per second.** This is the “it writes the answer” speed — the number you feel. 13.6 t/s means a 200-word answer streams back in around 30 seconds, which is genuinely usable for everyday tasks even though it is not instant.

These two numbers are what you want to capture for your own model and your own hardware, because they are the ground truth for whether a bigger model is worth the memory. Run `llama-bench` on the model you are about to commit to, and if generation drops below a pace you find pleasant, the fix is usually a smaller model or a higher quantization trade-off — or a GPU, which is the single biggest jump available.

## Common gotchas

**It is slower than the benchmarks claim.** The most common cause is the context length. `-c` is not free: a 32k context holds a lot of state in memory and can slow generation noticeably compared to a 4k context, especially on CPU. If a model is “supposed” to be fast but is not, halve the context and re-benchmark before blaming the model. The second cause is thread count set above your physical cores, which adds contention rather than speed.

**The model does not fit, or the box swaps.** If you load a model bigger than your available RAM, the operating system will start swapping to disk and the speed will collapse from tens of tokens per second to a trickle. Watch memory while it loads; if free RAM goes negative and swap climbs, the model is too big for the box at that quantization. The fix is a smaller model or a lower quant, per the size-and-quantization guide.

**The server answers but my client gets an empty response.** With a few newer “thinking” models, the model spends its first tokens on internal reasoning that is returned in a separate field rather than in the main answer. If your client only reads the primary content field, it can look like the model returned nothing even though it worked. This is a model-behavior detail, not a llama.cpp bug — check the full response for a separate reasoning field before assuming the server is broken. We hit this with a thinking model in the lab, which is why it is worth knowing.

**Two versions of the binaries, or a stale build.** If you rebuilt and the old behavior persists, you are almost certainly running the old binary from a different path. `which llama-server` and a fresh `--version` tell you exactly which build you are executing.

## How this fits the rest of your home server

llama.cpp is the “I want the model itself, with my hands on it” option in the local AI stack. It is the right first choice on a CPU box because it is the most efficient of the three runtimes on that hardware, and it is the one to reach for when a wrapper is hiding something you want to change. The model files it loads are the same GGUF files that Ollama and LM Studio use, so nothing here is a dead end — if you later want the one-click model downloads or a nicer desktop, you move the runtime and keep the models. For the “just give me a model” path, see the Ollama guide; for the desktop route, the LM Studio guide; and for putting a proper chat window in front of whatever you run, the Open WebUI guide. And because a loaded model will happily hold several gigabytes of RAM, it belongs on a box you are watching — the Prometheus setup is the natural companion, so a chatty model does not quietly crowd out the rest of your services.

Tested on:

OSDebian 12HardwareIntel i5-6500T, 4 cores / 16 GB, no GPUllama.cppbuild dd1ea5243 (b10343-12), CPU Release buildModel4.65B-param model at Q4_K (2.95 GB)Measured speed48.4 t/s prompt (512) / 13.6 t/s generation (128), 4 threadsLast tested: 15 September 2026

## What’s next?
The natural next steps from this guide:

- [What hardware for a home server?](https://chikewa.com/what-hardware-for-a-home-server/)
- [Prometheus and node_exporter in Docker](https://chikewa.com/monitoring-docker-compose-prometheus-node/)
- [The self-hosting starter guide](https://chikewa.com/self-hosting-starter-guide/)

---


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).