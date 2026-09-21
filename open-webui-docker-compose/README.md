# Open WebUI in Docker: A Chat UI for Local LLMs


> One Docker container turns a local model into a chat app the whole house can use. The tested two-container Ollama stack, first login, connecting the model, and the gotchas that actually appear.

**Full guide:** [https://chikewa.com/2026/09/21/open-webui-docker-compose/](https://chikewa.com/2026/09/21/open-webui-docker-compose/) · **Category:** AI & LLM · **Published:** 2026-09-21

---

A model running on your server is powerful, but reaching it through a raw API endpoint is not how a household uses anything. Open WebUI is the most popular self-hosted front end for local models: it runs in a single Docker container, connects to Ollama (or any OpenAI-compatible endpoint) in a couple of lines of configuration, and gives you a clean chat interface with conversations, a model picker and document upload that works in a browser on any device on your network. This guide runs it the way we ran it in the lab — as a two-container stack (Ollama for the model, Open WebUI for the interface) — and walks through the real setup, the first login, connecting the model, and the gotchas that actually appear. Every step below was done and verified on the lab box: a 4-core Intel i5-6500T, 16 GB RAM, Debian 12, Docker 29.7, no discrete GPU.

*Beginner · 11 min · Docker*

## What Open WebUI is

Open WebUI is a web application, not a model runner. It does not load models itself; it connects to a model backend (Ollama, llama.cpp’s server, or any OpenAI-compatible API) and puts a proper interface in front of it. What it adds over a raw API:

- **A chat interface** that behaves like a normal chat app: conversations you can go back to, a model selector, streaming responses.

- **Multi-user support.** Each person gets an account and their own conversation history. This is what turns “the model on the server” into “the family can each use it”.

- **Document and knowledge features** so you can attach a file and ask questions about it, plus prompts, tools and other extensions.

- **A single container** that keeps all of its state (users, chats, settings) in one folder, so the whole thing is trivial to back up and move.

Because it is a front end, the rule for this guide is the same as for the rest of the stack: the model is provided by Ollama (or another runtime), and Open WebUI’s job is to make that model pleasant to use. We used Ollama as the backend in the lab, which is the most common and best-supported pairing.

## The two-container stack

The cleanest, most reproducible setup is a compose file with two services on a shared Docker network: Ollama running the model, and Open WebUI running the interface, with the UI told to reach Ollama by its service name. This is exactly what we ran end to end in the lab, and a chat request went from the browser-facing container, through to the Ollama container, and back with a real model response.

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    volumes:
      - ./ollama:/root/.ollama
    restart: unless-stopped

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    ports:
      - "127.0.0.1:3005:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - WEBUI_SECRET_KEY=change-me-to-a-long-random-string
    depends_on:
      - ollama
    volumes:
      - ./open-webui:/app/backend/data
    restart: unless-stopped
```

The details that matter. The `OLLAMA_BASE_URL` points at Ollama by its service name on the shared network (`http://ollama:11434`), which is why both containers need to be in the same compose project — they can resolve each other by name. The port is published as `127.0.0.1:3005`, bound to loopback, so only the server itself can reach the UI directly; that is the safe default and you reach it from your devices over your VPN. The two volumes are the entire state: `./ollama` holds the downloaded models and `./open-webui` holds the users, chats and settings. Back up those two folders and you can rebuild both containers and lose nothing. The `WEBUI_SECRET_KEY` signs the app’s sessions — set it to a long random string rather than the placeholder, because it is what makes your logged-in state secure. If you have an NVIDIA GPU, add the standard GPU resource reservation to the Ollama service and the model will run on the GPU instead of the CPU.

## First boot and the admin account

Run `docker compose up -d`. Both containers start; Open WebUI takes a little while on first boot while it initializes, so wait for it to report healthy (or for the page to stop showing its loading screen) before trying to log in. The very first thing you do when the UI opens is create the admin account — the first account registered becomes the administrator of the whole instance. Do this before anything else and write the credentials down, because there is no separate “first user” flow and losing them means resetting the auth in the state folder. In the lab we created the admin account and confirmed it by signing back in, which is the step worth doing before you trust anything else.

Confirm the backend connection next. With the `OLLAMA_BASE_URL` set in the compose file, Open WebUI should already see the models that Ollama has. If the model list is empty, the UI cannot reach Ollama — which is almost always a network-name or port issue between the two containers, not a problem with either app. Once the model appears, the pairing is working.

## Getting a model in and having a real conversation

If Ollama has no models yet, pull one. In the lab we used a small, fast model to keep the test clean: a 0.6B model at Q4_K_M, a 522 MB file that Ollama downloaded and verified. With it loaded, we sent a real chat request through the full path — from Open WebUI’s API, to the Ollama container, and back. The response came back with a proper model answer, which is the end-to-end proof that the stack works: the interface, the backend, and the model are all talking to each other correctly. In the UI the same thing is just “type a message and read the answer”, but the API path is worth confirming once, because it is the thing a chat front end is for, and seeing a real response is the fastest way to know the whole chain is healthy.

One behavior to expect with the newer thinking models: some spend their first tokens on internal reasoning that the backend returns in a separate field, and the final answer can be short. If a reply looks unexpectedly brief, that is usually the model’s doing, not a broken connection. And because the UI is where a whole household will live, set a sensible default model and a reasonable context length once, so every user gets a sane experience without fiddling.

## Security: the part that matters most

Open WebUI has accounts, but the model backend it fronts does not, and the security of the whole setup is “who can reach the ports”. Keep the UI on loopback (as the compose file does) and reach it from your devices through your VPN — the [Tailscale in Docker](https://chikewa.com/tailscale-docker-compose/) guide is the clean way to get your phone or laptop onto your home network from anywhere without opening a public port. Do not publish the UI port to your LAN or the internet just because it is convenient; a model front end on an open port is an open door to your server’s compute and to whatever the backend can do. If you do want a named, HTTPS front, the [Caddy in Docker](https://chikewa.com/caddy-docker-compose/) guide shows how to add one in front of the loopback port. The [security guide](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/) covers the firewall rules and network isolation, and setting a real `WEBUI_SECRET_KEY` (not the placeholder) is the small thing that keeps the app’s own session handling secure.

## Common gotchas

**The model list is empty.** The UI cannot reach the backend. In the two-container setup this is almost always that the two services are not on the same network, or the `OLLAMA_BASE_URL` does not match the service name and port. Check that both containers are up, that they share the compose project, and that the URL points at the right name and port. This was the single most common thing in the lab, and it is a configuration issue, not a broken app.

**The page loads but you cannot do anything / you are logged out repeatedly.** Usually the state volume is not persisting, so the app restarts its users on every reload. Confirm the `./open-webui` volume is actually being written to and survives a container restart — a fresh data folder on each start is the tell.

**It is slower than the model “should” be.** Open WebUI adds a little overhead, but the dominant factor is still the model and the hardware. If the backend (Ollama or llama.cpp) is slow, the UI will be slow; measure the backend directly before blaming the front end. On the lab’s CPU box, small models felt instant and larger ones felt slower, which is the model and the hardware, not the interface.

**First boot looks hung.** The container does real work on first start (initializing its database and configuration) and the page shows a loading screen while it does. Give it a moment before concluding it failed; check the container logs if it does not come up, which will say what it is waiting on.

## How this fits the rest of your home server

Open WebUI is the front door of the local AI stack, and it is the step that turns a working model into something the household actually uses. It pairs with whatever runtime you chose — Ollama in this guide, but the same pattern works with llama.cpp’s server or any OpenAI-compatible backend — and it sits on the same security rules as everything else: loopback by default, reached over your VPN, optionally fronted by HTTPS. Its state is one folder, so it belongs in your normal backup routine alongside the model store, and because a loaded model holds real RAM, it is another reason to have the box watched by monitoring. The shape of the finished setup is the whole series in one picture: the hardware you chose, a model you measured and sized for that hardware, a runtime that serves it, and this chat window in front — all private, all on hardware you own, and all reachable from the devices in the house over a network you control.

Tested on:

OSDebian 12Docker29.7.2Hardware4-core / 16 GBStackOpen WebUI (container) + Ollama (container), shared networkModelqwen3:0.6b Q4_K_M (522 MB)Verifiedend-to-end chat through the full two-container stackLast tested: 15 September 2026

## What’s next?
The natural next steps from this guide:

- [Tailscale in Docker](https://chikewa.com/tailscale-docker-compose/)
- [Caddy in Docker: reverse proxy with automatic HTTPS](https://chikewa.com/caddy-docker-compose/)
- [Secure your home server: SSH, firewall and Docker networks](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/)

---


## 📁 Files in this directory

- **`docker-compose.yml`** — The Docker Compose stack (tested)


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).