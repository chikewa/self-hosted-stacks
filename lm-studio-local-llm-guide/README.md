# LM Studio: The Easiest Way to Run Local LLMs


> Browse a model catalogue, download with a click, chat in a window: LM Studio is the friendliest path into local AI. Plus the port 1234 server your other tools can use, and when to switch to a headless runtime.

**Full guide:** [https://chikewa.com/2026/09/19/lm-studio-local-llm-guide/](https://chikewa.com/2026/09/19/lm-studio-local-llm-guide/) · **Category:** AI & LLM · **Published:** 2026-09-19

---

LM Studio is the friendliest on-ramp to local AI: a desktop app where you browse a catalogue of models, download one with a click, and start chatting in a window — no terminal, no config file, no “what is a context window” moment. It is the option to choose when you are working on a machine with a screen and you want the path of least resistance. Under the hood it runs the same kind of GGUF models that llama.cpp and Ollama use, and it can also switch on a local server so the rest of your tools can talk to it over the network. One honest note up front: this guide is written from the app’s documented behavior on macOS, Windows and Linux. The lab box for this series is a headless server without a desktop, so we have not screenshotted the GUI here; the steps and the ports and the server behavior are the documented ones, and the parts we can verify on a headless box — the server port, the OpenAI-compatible API — are what you will actually lean on if you run it on a server.

*Beginner · 9 min · Desktop app*

## What LM Studio is and who it is for

LM Studio is a graphical desktop application, available for macOS (including Apple Silicon), Windows and Linux. Its three jobs are:

- **Find and download models.** It includes a search interface over a catalogue of GGUF models, so you can look at size, quantization and author, and download what fits your machine without hunting around a model host.

- **Chat with them.** Once a model is downloaded, you pick it, set a few generation parameters with sliders, and talk to it in a chat window that behaves like a normal chat app.

- **Serve them.** A “Local Server” toggle exposes the loaded model on `http://localhost:1234` as an OpenAI-compatible API, so any client written for the OpenAI API can use it by changing the base URL. This is the part that turns a desktop app into a small model server.

The model files it uses are the same GGUF files the other two runtimes load, so a model you download in LM Studio can be loaded in llama.cpp or Ollama too. There is no lock-in; LM Studio is a choice of interface, not a closed format.

## Installing it

Download the installer for your platform from the LM Studio site and run it. On macOS and Windows it is a standard installer; on Linux it ships as an AppImage (or a platform package), which you make executable and run. After install, launch the app and you are in the interface. There is no separate “server daemon” to install on the desktop — the server is a feature you switch on inside the running app (see the server section), which is the thing to keep in mind if you are on a headless box: the desktop app expects a display, so on a server without a GUI the headless path is the one you want.

## Downloading your first model

Inside the app, use the search/browse view to find a model. The two numbers to check are the parameter count and the quantization, exactly as in the size-and-quantization guide: pick something your RAM can hold. As a safe first download on a 16 GB machine, a 4B to 8B model at 4-bit is the same sweet spot recommended everywhere in this series. Select it and download. LM Studio stores models in a local models folder it manages for you, so you do not have to decide where the file lives or name it — a convenience, at the cost of less control over the exact file, which is the flip side of the friendliness.

## Chatting and tuning

Select the downloaded model, and the chat window is ready. Above the input there are a handful of generation parameters — temperature, the context length, the maximum response length — exposed as sliders rather than flags. This is the main appeal for a first model: you can change how the model behaves and see the effect immediately, without editing a command. A good habit is to keep temperature modest (around 0.2 to 0.7) for factual or coding tasks and raise it only when you want more variety. The context slider is the one with a real cost: a longer context uses more memory, so if the model feels slow or the app warns about memory, that is the first knob to turn down.

## Turning it into a server on port 1234

This is the step that makes LM Studio useful beyond the machine it is installed on. In the app, open the Local Server area and enable the server. It listens on `http://localhost:1234` and exposes the loaded model through an OpenAI-compatible API. After that, any existing OpenAI client points at LM Studio by changing the base URL to that address and setting any API key value (the local server does not require a real key, but the clients expect the field to be filled). The endpoints line up with the ones you would use on the OpenAI API — a model list and a chat-completions endpoint — so the change is a configuration edit, not a rewrite. Two practical notes. First, the server reflects the model currently loaded in the app, so switching models in the UI changes what the server serves. Second, the server runs while the app runs; on a desktop that is fine, but it is also why the desktop app is the wrong shape for an always-on headless server, where you would want a service that starts at boot and has no window.

## Running it headless on a server

If your target is a headless box (like most home servers), the desktop app is not the right vehicle, because it is built around a graphical window. There are two honest ways to run an LM-Studio-style setup headless. One is a community “headless server” package that runs the model server as a background service without the GUI and manages the model for you. The other — and the one we would actually recommend for a server — is to skip the GUI entirely and use a runtime that is native to the command line: Ollama or llama.cpp. The model files are the same GGUF files, so nothing is lost by moving from the desktop app to a headless runtime; you keep the models and change the front end. This is worth saying plainly: LM Studio shines on a desktop, and for a 24/7 server the command-line runtimes are the better fit, even though they all speak the same model format.

## Keeping it private

The server defaults to `localhost`, which is the safe default: only the machine it runs on can reach it. If you want a chat app or another device on your network to use it, you can point the server at your LAN address, but the cleaner pattern is to keep the server on the box and reach it through your VPN — the [Tailscale in Docker](https://chikewa.com/tailscale-docker-compose/) guide shows how to get a device on your home network from anywhere without opening a public port. And the same rule as the rest of this series: a local model server has no account system, so its security is entirely “who can reach the port”. Keep that on loopback or a private network, and if you do want a named, HTTPS front for the UI, the [Caddy in Docker](https://chikewa.com/caddy-docker-compose/) guide is the way to add it. The [security guide](https://chikewa.com/secure-your-home-server-ssh-firewall-docker/) has the firewall and network-isolation details.

## Common gotchas

**The server says the model is not available.** The server serves whatever model is loaded in the app. If you downloaded a model but did not select it, or you switched models after starting the server, the API will not see the one you expect. Load the intended model, then start (or restart) the server.

**Port 1234 is already in use.** If something else is bound to 1234, the server will not start or will collide. Change the port in the server settings, or free the port. This also bites when a desktop instance with the server on and a headless daemon are both running at once — two processes, one port. Pick one owner for the port.

**It is slower than Ollama or llama.cpp on the same model.** The GUI and its management layer add overhead, and the desktop app is not optimized the way a bare command-line runtime is. For a desktop that is usually a non-issue; for a server where speed matters, the headless runtimes are the better tool.

**You expect the desktop app to run on a headless box.** It is a GUI app. On a server with no display it will not do its job, which is exactly why the headless section above points you to a service or a command-line runtime instead.

## How this fits the rest of your home server

LM Studio is the “I have a computer with a screen and I want to play with local AI today” option, and it is the best one for that job. It is also the place to start if you are deciding which models you actually like, because the one-click downloads and instant parameter changes make experimentation cheap. Once you know which model and which quantization you want to run for real — and you will, after a little playing — the natural move for a home server is a headless runtime that serves that same GGUF file around the clock: Ollama for the low-maintenance path, llama.cpp for the control-and-performance path. And whatever you run, the next step is the same: a chat front end the whole house can use, covered in the Open WebUI guide, and a bit of monitoring so the loaded model does not quietly take the RAM your other services need. The models are the constant across all of it; only the front end changes.

## What’s next?
The natural next steps from this guide:

- [Tailscale in Docker](https://chikewa.com/tailscale-docker-compose/)
- [Caddy in Docker: reverse proxy with automatic HTTPS](https://chikewa.com/caddy-docker-compose/)

---


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).