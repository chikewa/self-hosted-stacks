# Ollama: Install and Run a Local LLM in 5 Minutes


> One install, one pull, one command: Ollama gets a working local model running fast. Includes measured speeds and the thinking-model behavior that makes replies look empty when they are not.

**Full guide:** [https://chikewa.com/2026/09/18/ollama-local-llm-guide/](https://chikewa.com/2026/09/18/ollama-local-llm-guide/) · **Category:** AI & LLM · **Published:** 2026-09-18

---

Ollama is the fastest way from “I have a server” to “I have a working local model”. One install script, one command to pull a model from its registry, one command to run it — and you get a model you can talk to from the terminal, plus an HTTP API that every chat app and script can use. It wraps the same inference engine that powers the rest of the local AI world, so it is not a toy or a separate technology; it is that engine with a friendly front end. This guide installs it, pulls a model, runs it, measures it, and covers the one behavior that trips people up on the newer thinking models. Everything was done on the lab box: a 4-core Intel i5-6500T, 16 GB of RAM, Debian 12, no discrete GPU.

*Beginner · 10 min · CLI*

## What Ollama actually is

Ollama is a small program with three parts working together:

- **A server** that stays running in the background, holds the loaded models in memory, and answers requests. You usually start it once and forget it.

- **A CLI** (`ollama`) that talks to that server. `ollama pull`, `ollama run`, `ollama list`, `ollama ps`. This is what you type.

- **An HTTP API** on `localhost:11434` with both its own native endpoints and an OpenAI-compatible one, so existing OpenAI clients work with no changes.

The model registry is the part that makes it feel effortless. Instead of hunting for a file and checking it matches your hardware, `ollama pull qwen3:0.6b` downloads the right file and verifies it. The trade-off for that convenience is that the registry is a curated list, so if you want a very specific model file you downloaded yourself, you import it rather than pull it by name.

## Installing it

On the lab box we installed a specific release (v0.34.0) by downloading the binary distribution and running the server directly, which is the same shape as the official install but without needing root for the whole thing. The official one-liner does this for you:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

If you are running as a normal user without the rights the installer wants (as we were in the lab), download the release tarball for your platform, extract it into a folder of your own, and run the server binary directly:

```text
OLLAMA_HOST=127.0.0.1:11434 ./bin/ollama serve
```

The `OLLAMA_HOST` variable is the one worth knowing. By default the server listens on `127.0.0.1`, which is exactly what you want on a private server — nothing outside the machine can reach it. Set it to `0.0.0.0` only if you deliberately want the rest of your network to reach the API, and then you should be putting it behind your VPN rather than exposing it. We confirmed our server was answering `{"version":"0.34.0"}` on its version endpoint before doing anything else.

## Pulling and running a model

Once the server is up, pulling a model is one command. In the lab we pulled a small, fast model to prove the pipeline:

```text
ollama pull qwen3:0.6b
```

This downloaded a 522 MB model (a 0.6B-parameter model at Q4_K_M) and verified its checksum — the pull finished in under a minute on the lab connection. After it completes, `ollama list` shows it with its size, and you can run it interactively:

```text
ollama run qwen3:0.6b "What is the capital of France?"
```

That is the whole “I have a local model” moment: type a question in the terminal, get an answer from a model running on your own hardware. For scripting, the same model is reachable over the API:

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "qwen3:0.6b",
  "prompt": "Say hello",
  "stream": false
}'
```

And for any client written against the OpenAI API, the `/v1/chat/completions` endpoint behaves the same way, which is what makes Ollama the default assumption for third-party chat apps.

## Measuring it

Ollama reports timing in the API response, so you get the real numbers without a separate benchmark tool. On the lab box, a chat request against the 0.6B model came back with the response text, the tokens generated, and the timing for both reading the prompt and generating the answer. What we measured:

- **Token generation: roughly 49 to 52 tokens per second.** That is the answer-writing speed, and at that rate a normal-length reply streams back in well under a second. For a 0.6B model on a 4-core CPU with no GPU, that is comfortably in “instant” territory.

- **Prompt processing: roughly 140 to 235 tokens per second** depending on the run, which is the speed at which it reads your input back. In practice that is fast enough that you will not notice it for normal prompts.

These are small-model numbers, and that is the point of starting small: you get an immediate, pleasant experience that proves the whole setup works, before you spend time on a bigger model that is slower to load and slower to answer. When you move to a larger model, watch the generation rate in the response and decide against that baseline whether the extra intelligence is worth the extra wait.

## The thinking-model gotcha

This is the one that cost us real debugging time in the lab, and it is worth knowing before it confuses you. A number of newer models — the Qwen3 family is a good example — are “thinking” models: before they produce the final answer, they generate an internal chain of reasoning. Ollama returns that reasoning in its own field, separate from the final answer. The practical consequence is that if you read only the main answer field and that field is short or empty, it can look like the model failed to respond at all, when in fact it did its work in the reasoning field and then gave a one-word answer.

In the lab, a request to a thinking model returned its reasoning (a few hundred characters of “let me work this out…”) in the separate field and a short final answer in the main field. Two things follow from this. First, it is a model behavior, not an Ollama bug — the server did exactly what the model told it to. Second, if you are writing a client, read the full response, not just the primary content field, or you will occasionally see “empty” answers that are actually complete. And because thinking burns tokens on reasoning, a thinking model with a tight token limit can spend its whole budget thinking and return little or no final answer — raise the limit if you see that pattern.

## Keeping it running and keeping it private

On a server you want Ollama running as a service so it survives a reboot, and you want its model store on a volume that survives a reinstall. In the lab the model store lived in a dedicated folder, and the whole thing fit on the same NVMe drive as the rest of the stack — a model or two is a few gigabytes, not a storage event. For the “I want it as a container” setup, which is the most reproducible way to run it alongside a chat UI, the official Ollama image does exactly this: a container for the runtime, a volume for the models, and the API on the standard port. That two-container pattern (Ollama plus a chat front end) is what we ran end to end in the lab, and it is covered in the Open WebUI guide. For reaching the UI from your phone or laptop without opening a port, the [Tailscale in Docker](https://chikewa.com/tailscale-docker-compose/) guide is the clean path, and the [security guide](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/) covers why the API should stay on loopback or a private network by default.

## Common gotchas

**The CLI says it cannot connect to a running Ollama.** The server and the CLI are two separate processes, and the CLI only works while the server is running and on the host it expects. If you started the server with a custom `OLLAMA_HOST`, the CLI needs to know the same address. In the lab this showed up whenever the background server had been restarted without the host variable set. Check the server is actually up first; it is the more common cause than a configuration mismatch.

**A pull is slow or stalls.** Model files are large, and the registry is a public service, so pull speed is whatever the internet is giving you. A stalled pull is usually a network hiccup, and re-running the same `pull` resumes rather than starting over. If you are on a slow line, a smaller quantization is the real fix, not patience.

**The model is in the list but the first request is very slow.** The first request after a model has been idle loads its weights into memory, which takes a moment; subsequent requests are fast. This is normal, not a fault. If every request is slow, the model is too big for the box and it is swapping — see the size-and-quantization guide for the memory math.

**Your script gets an empty answer from a thinking model.** Covered above, but it is the most likely thing to look like a bug when it is not. Read the full response including the reasoning field, and raise the token limit if the model is burning its budget on reasoning.

## How this fits the rest of your home server

Ollama is the “set it and forget it” option in the local AI stack: the least fiddly install, the easiest model management, and an API that the rest of your tools already understand. It is the right default for most home servers, and the right thing to put a chat interface in front of. If you want to squeeze more out of a CPU box or you want your hands on the engine, the llama.cpp guide is the deeper route; if you are working on a desktop with a screen, LM Studio is the friendlier one. Whichever runtime you pick, the natural next step is a proper chat window that the whole house can use — the Open WebUI guide — and a bit of monitoring so a loaded model does not quietly take RAM from the services it shares the box with.

Tested on:

OSDebian 12Hardware4-core / 16 GBOllamav0.34.0Modelqwen3:0.6b (Q4_K_M, 522 MB, verified on pull)Measured speed~49-52 t/s generation / ~140-235 t/s promptLast tested: 15 September 2026

## What’s next?
The natural next steps from this guide:

- [Tailscale in Docker](https://chikewa.com/tailscale-docker-compose/)
- [Secure your home server: SSH, firewall and Docker networks](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)

---


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).