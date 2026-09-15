# Secure Your Home Server: SSH, Firewall and Docker Networks


> Three layers of home server security, verified in the lab: key-only SSH, the host firewall, and Docker internal networks with outbound traffic blocked.

**Full guide:** [https://chikewa.com/2026/08/24/secure-your-home-server-ssh-firewall-docker/](https://chikewa.com/2026/08/24/secure-your-home-server-ssh-firewall-docker/) · **Category:** Security & Networking · **Published:** 2026-08-24

---

A home server is a machine that other people and devices on your network rely on every day. That makes security not a feature but a foundation: if the box is reachable in the wrong ways, everything running on it — photos, files, media — is reachable too. This guide covers the three layers that matter most, in the order they should be built: SSH, the host firewall, and Docker network isolation. Everything here was run and verified in the Chikewa lab on a Debian 12 machine, and every command you see is a command that actually executed there.

*Intermediate · 12 min · Linux*

## Why home server security is different

A laptop connects to networks you control; a home server usually sits behind a router with a dynamic IP, runs services that must be reachable by design, and rarely gets the patch attention a phone or laptop does. The threat model is simple and worth stating plainly: scanners probe residential IP ranges constantly, and anything that answers on a public port gets attempted logins within minutes. The goal of this guide is not paranoia — it is making sure the only things that answer are the things you intend to expose, and that they answer with keys, not passwords.

## Layer 1: SSH

SSH is how you administer the box, and it is the first thing attackers try. Hardening it is a ten-minute job with a permanent payoff. We verified every step on Debian 12 with OpenSSH 9.2p1.

#### Keys before you touch the config

Generate a keypair on your laptop — do this *before* you change anything on the server:

```bash
ssh-keygen -t ed25519 -C "your-name@laptop"
```

We used ed25519 in the lab: it is the modern default, faster and shorter than RSA. Copy the public half to the server:

```bash
ssh-copy-id user@your-server
```

Now test that key authentication works *while your normal password session is still alive*:

```bash
ssh -o BatchMode=yes user@your-server "echo KEY-AUTH-OK"
```

The `-o BatchMode=yes` flag disables password prompting, so this test can only succeed with a key. If it prints `KEY-AUTH-OK`, you are safe to lock the door. If it prints `Permission denied (publickey, password)` — which is exactly what happened in the lab until the public key was in place — fix the key first, because the next step removes the password fallback entirely.

#### Locking out passwords

Add a drop-in config (Debian reads `/etc/ssh/sshd_config.d/` after the main file, so this wins without editing the original):

```bash
sudo mkdir -p /etc/ssh/sshd_config.d
sudo tee /etc/ssh/sshd_config.d/10-chikewa.conf The `sshd -t` syntax check is not optional. A typo here does not just fail the reload — depending on timing it can lock you out of a server you cannot reach. Run it, read the result, and only then:

```bash
sudo systemctl reload ssh
```

Reload, not restart: it applies the new config to new connections without dropping the one you are sitting in. From this point, every login requires a key. Keep a second key on a different device — losing the laptop should not mean losing the server.

## Layer 2: The host firewall

SSH hardening protects the door. The firewall decides which doors exist. On Debian the tool is UFW, and the posture we use in the lab is deny-incoming, allow-outgoing, with explicit exceptions:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status verbose
```

Two things about this that are worth knowing before you type `enable`. First, enable it only after `allow OpenSSH`, or you will cut the very session you are typing in. Second, UFW manages its own iptables rules, and Docker manages its own; they coexist, but it means Docker-published ports can answer *before* the host firewall ever sees the packet. That is the whole reason for the next layer, and the most common source of the belief that “my firewall isn’t working.” It is working; it just is not the layer that answers port 8096.

#### What to expose

The honest answer for most people: **nothing**. A home server should be reachable from your LAN and from your phone *via a private network*, not from the public internet. The only port we would put on a residential box is 22, and even that is worth revisiting once you have a private-network option (see Layer 3 and our [guide to running services](https://chikewa.com/navidrome-docker-compose-guide/), which shows the loopback-bound pattern). If a service genuinely must be public, it goes behind a reverse proxy with TLS and authentication — never a bare port forward.

## Layer 3: Docker network isolation

Docker’s default bridge network connects every container to each other and gives them outbound internet access by design. That is convenient and, for a server that hosts strangers’ content, occasionally exactly what you do not want. Docker offers the fix as a flag on the network itself.

Creating an internal network and putting a container on it:

```bash
docker network create --internal internal-services
docker run --rm --network internal-services alpine ping -c1 -W2 8.8.8.8
```

On a default network the ping succeeds. On an `--internal` network it fails — which is what we verified in the lab: the container starts fine, but every outbound connection is refused. The network literally has no route out. Combine that with loopback-bound ports (the `127.0.0.1:8096:8096` pattern from our [Jellyfin guide](https://chikewa.com/jellyfin-docker-compose-guide/)) and you have a container that can be reached only from the host, which in turn is reached only from your LAN or private network.

The mental model to keep: **default bridge** is for containers that need the internet (webhooks, updates, APIs); **internal** is for containers that serve you and no one else. Sorting your stack into those two buckets is more security work than any single rule, and it takes five minutes with `docker network ls`.

## Verifying the whole stack

Security that you cannot observe is security you cannot trust. Three checks we run after every change:

```text
# What is actually listening, and where?
ss -tlnp

# Is the firewall where it should be?
sudo ufw status verbose

# Do the container networks behave?
docker network ls
docker network inspect internal-services --format '{{range .Containers}}{{.Name}} {{end}}'
```

The first command is the one that surprises people. In the lab, after binding Jellyfin to loopback, `ss -tlnp` showed `127.0.0.1:8096` — and the same box’s default bridge carried `172.17.0.1/16`, an address space your whole LAN can route to if a port is ever published to it. Knowing which interface an IP lives on is the difference between “is this exposed?” and a guess.

## What this does not cover

This is the foundation, deliberately. It does not cover a reverse proxy with TLS, which is the natural next step for any public service and belongs in its own guide; it does not cover backing up the config volumes that now hold your server’s identity (the `ssh` config, the UFW rules, the Docker named volumes); and it does not cover Tailscale-style private networking in depth, although the loopback pattern above is exactly the pattern you would pair with it. If a guide on remote access appears in this series, that is where it picks up.

## FAQ

#### Do I really need UFW if Docker already has its own rules?

Yes, for the non-Docker parts of the box: SSH, anything you run outside containers, and as a second opinion on what is reachable. But do not expect it to police Docker-published ports — that is Docker’s job, and the loopback-binding pattern is the right tool there.

#### I lost access. Now what?

This is why the key-first, test-before-lock sequence exists. If you are already locked out and you have no second key, the recovery path is physical or console access to the machine, or a cloud provider’s serial console — not a password reset over the network, because that is precisely what the config now refuses.

#### Should I change port 22?

It stops the lowest-effort scanners, which is real but small; it also creates a non-standard you will have to remember and document. We keep 22 and rely on keys plus the firewall. Security through port obfuscation buys you noise reduction, not protection.

Tested on:

OSDebian 12Docker29.7.2Hardware4-core i5-6500T / 16 GB RAMSoftwareOpenSSH 9.2p1Last tested: 23 August 2026

## What’s next?
The natural next steps from this guide:

- [Jellyfin in Docker: self-hosted media server](https://chikewa.com/jellyfin-docker-compose-guide/)
- [The Self-Hosting Starter Guide](https://chikewa.com/self-hosting-starter-guide/)
- [Navidrome: self-hosted music server](https://chikewa.com/navidrome-docker-compose-guide/)

---


## Related

- 🏠 More tested stacks: [https://chikewa.com](https://chikewa.com)
- 📚 All stacks in one place: [../README.md](../README.md)

## License

MIT — see [../LICENSE](../LICENSE).