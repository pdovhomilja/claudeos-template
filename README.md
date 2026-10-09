# claudeos-template

A personal AI operating system for [Claude Code](https://claude.com/claude-code). The assistant (default name: **Jarvis**) keeps a persistent, compounding memory as a Markdown wiki — Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) pattern — and you browse it in Obsidian.

## Install (Mac or Linux, about 15 minutes)

You need a **Claude Pro or Max** subscription and a free **GitHub** account (you can create it during the install).

1. Open **Terminal**. On a Mac: press ⌘ + Space, type `Terminal`, press Enter.
2. Copy this line, paste it into Terminal, press Enter:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pdovhomilja/claudeos-template/main/install.sh | bash
   ```

3. First it checks what is already on your computer and shows a list, then waits for Enter:

   ```
   1/7 What is already on this computer
      ✓  Apple developer tools    installed
      ○  Node.js                  will be installed
      ○  GitHub tool (gh)         will be installed
      ✓  Claude Code              installed
      ○  uv                       will be installed
      ○  graphify                 will be installed
      ○  Claude Code plugins      will be installed
      –  Tailscale                not needed on a laptop
      ✓  Obsidian                 installed
      ○  GitHub login             you will log in (step 4)

      Press Enter to install what is missing (5).
   ```

   ✓ is already there, ○ will be done now, – is not needed on this kind of machine. Only what is missing gets installed.
4. Follow what it says on screen. It connects GitHub in your browser (check that it shows **your own** account), makes **your own private copy** of this template (only you can see it), and starts your assistant, which asks you a few questions.
5. Next time: open Terminal and type `jarvis`.

If anything stops, paste the same line again: it continues where it stopped. Nothing is installed outside your home folder except Apple's developer tools and Obsidian on a Mac, git on Linux, and Tailscale on a server.

On a server: `curl -fsSL https://raw.githubusercontent.com/pdovhomilja/claudeos-template/main/install.sh | bash -s -- --server` (the checklist then includes Tailscale and a browser, which it installs; at the end it runs `scripts/vm/bootstrap.sh` for the timers). The browser is Google Chrome in a small remote desktop that only your own devices can open, over Tailscale, so the assistant can use websites through Claude in Chrome; setup steps in [Browser on the server](#browser-on-the-server).

## Quick start by hand (macOS, Linux, Windows)

1. Install [Claude Code](https://claude.com/claude-code) and [Git](https://git-scm.com).
2. Clone this repo, `cd` into it, run `claude`.
3. Say **"run the first-time setup"**. The assistant follows the *First run* section of `CLAUDE.md`: checks the tools and plugins, asks your name, what to call it and your goals; then commits.
4. Open the folder as a vault in Obsidian.
5. Drop a file into `raw/` and say **"ingest"**. That is how the memory grows.

## Run a twin on a server (optional)

A second copy of the assistant can work unattended on a small Linux server: two runs a day (07:30, 13:00) toward the goals in `wiki/goals.md`, a brief in your private Discord channel, drafts you approve with ✅, and an optional mailbox of its own. It never sends anything without your ✅ (see "Goals and tiers" in `CLAUDE.md`).

Each person runs their own: own repo, own server, own Claude subscription, own Tailscale, own Discord bot. Never share a copy that holds someone else's wiki.

1. Push your claudeOS repo to a **private** GitHub repo.
2. Ubuntu 24.04 server, x86_64 (4 vCPU / 8 GB / 64 GB with the browser; 2 vCPU / 4 GB without), a user with sudo. Log in as that user and run:
   `curl -fsSL https://raw.githubusercontent.com/pdovhomilja/claudeos-template/main/install.sh | bash -s -- --server`
3. It shows the checklist, installs Claude Code, Tailscale, uv, graphify and the browser, logs into **your** GitHub (open `github.com/login/device` on your phone or laptop), clones your copy to `~/claudeos`, installs the systemd timers and starts the browser desktop. It prints what is left: `tailscale up`, the browser steps below, `.env` from `.env.example`, `claude` → `/login`, a test run, enabling the timers.
4. Discord: create a server and a bot (Developer Portal → Bot → token; scopes `bot`, permissions Send Messages, Create Public Threads, Send Messages in Threads, Read Message History, Add Reactions; Message Content intent on), invite it to one private channel, put token, channel id and your user id in `.env`.
5. On your laptop keep working with `claude` in your own clone; the session pulls what the twin pushed.

### Browser on the server

The server has its own Google Chrome inside a small desktop, so the assistant can use websites (through Claude in Chrome) and you can watch or help it, e.g. to log in somewhere. Only your own devices on your Tailscale can open it. Once, after the install:

1. On the server, connect Tailscale (skip if done): `sudo tailscale up --ssh`, open the link it prints, log in with **your** Tailscale account.
2. Publish the desktop on your tailnet: `sudo tailscale serve --bg 6080`. The first time it may print a link to turn on HTTPS for your tailnet: open it, click Enable, run the command again. It prints the address, e.g. `https://my-server.tail1234.ts.net`.
3. On your laptop or phone (with Tailscale on), open that address followed by `/vnc.html` and click **Connect**. The password: on the server, `cat ~/.config/tigervnc/password-plain.txt`.
4. In that Chrome: log in to [claude.ai](https://claude.ai), then open the Chrome Web Store, search **Claude**, click **Add to Chrome**, and log in to the extension with the same account.
5. On the server, once: `cd ~/claudeos && claude --chrome`, then ask "open example.com and tell me the page title". When it answers, the assistant can use the browser.

Log in to websites in that Chrome yourself (through `/vnc.html`); the assistant then uses those logins. If the page stays black or says disconnected: `systemctl --user restart claudeos-desktop claudeos-novnc` on the server. Chrome for Linux exists only for x86_64, so ARM servers get no browser.

## Updating

Tell your assistant **"update yourself"**. It checks what is new (`CHANGELOG.md`), asks you, and brings in the newest version as one commit. Your wiki, sources, drafts, Obsidian settings and your own edits to its files are kept; where your edit and the new version touch the same lines, it asks you. To undo, tell it to undo the update. A twin on a server mentions a new version in its Friday brief but never updates by itself.

Copies made before version 1.0.0 do not have the updater yet. Tell the assistant once: *update yourself, following https://github.com/pdovhomilja/claudeos-template/blob/main/.claude/skills/update/SKILL.md*.

## Layout

- `CLAUDE.md` — entry point / instructions (including first-run setup)
- `SOUL.md` — who the assistant is
- `WIKI.md` — how memory works
- `raw/` — your sources (immutable)
- `wiki/` — assistant-maintained memory, browsed in Obsidian
- `.claude/skills/` — project skills (graphify, humanizer, obsidian-*, marketing pack, morning/eod/friday, done, audit, grill-me, handoff)
- `staging/` — drafts waiting for your approval
- `scripts/twin/`, `scripts/vm/` — the server twin and its setup
- `graphify-out/` — knowledge graph, generated by `graphify`
- `audits/` — dated health-check reports from `/audit`
