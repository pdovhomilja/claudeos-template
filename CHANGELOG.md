# Changelog

What changed in each version of claudeOS, in plain words. Your assistant reads this when it updates itself.
A line starting with **After updating:** is something the assistant does once after the update.

Releasing (template maintainers): every merge to `main` is a release. Bump `VERSION`, add a section at the top
(`## X.Y.Z — YYYY-MM-DD`), merge, then tag `main` as `vX.Y.Z` and push the tag.

## 1.11.0 — 2026-11-08

- Your assistant can now search everything in `wiki/` and `raw/` by meaning, in any language, not only by the exact words: `qmd`, a local search tool. Nothing leaves your computer. The knowledge graph (graphify) stays as it is; search sits beside it.
- The installer adds `qmd` and sets up the search index. Its models (about 2.5 GB) download in the background, so a slow line does not hold up the install; keyword search works at once, search by meaning a little later. Each session refreshes the index in the background and carries on a download that was interrupted. If `qmd` cannot be installed, the installer warns and goes on; paste the command again later.
- On a server, search also runs as a small service on the server itself (`qmd.service`, only reachable from that server), because on a 4-core amd64 server without a graphics card the command alone takes about 20 s per search and the service a few seconds. The setup also sets one Claude Code option on a server, so search is ready at once when a session starts. The twin may use it, and says in Discord if search is missing or down.
- **After updating:** run `bash scripts/qmd-setup.sh` (Mac, Linux and servers alike; on a server it also sets up the service and the MCP server `qmd`, and it says so if the service does not start). It needs Node.js 24.15 or newer, which the 1.10.2 step checks. If it prints a line about linger, tell the owner to run that one command. On a server, restart Claude Code so the `mcp__qmd__*` tools load, and if the service `claudeos-discord-watch` runs, restart it once so it loads the new tools: `systemctl --user restart claudeos-discord-watch.service`. **If you are on a laptop and this copy has a twin on a server,** the twin only gets these files through git; the same steps must run there. After you push, on the server: `git -C ~/claudeos pull`, `bash ~/claudeos/scripts/qmd-setup.sh`, and the restart above. Do it over ssh if you can reach the server; otherwise give the owner these lines to paste there. Until then the twin's night run reports in Discord that search is not working. On Windows there is no script: run `npm install -g --ignore-scripts @tobilu/qmd`; if `%USERPROFILE%\.config\qmd\index.yml` does not exist, create it with the two lines `models:` and `  embed: hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf`; then in this folder `qmd collection add wiki --name wiki --mask "**/*.md"`, `qmd collection add raw --name raw --mask "**/*.{md,txt}"`, `qmd update`, and `qmd pull` then `qmd embed` in the background. Tell the owner in one sentence that the search models are downloading in the background (about 2.5 GB) and that with a lot of material on a server without a graphics card the first indexing can take hours; it carries on by itself at each session.

## 1.10.2 — 2026-11-08

- The installer now asks for Node.js 24.15 or newer, because context-mode 2.x needs it. On an older Node.js its hook stops every terminal command in Claude Code. A computer with an older Node.js (for example 22.x) now gets Node.js 24 in your home folder, like a computer without one.
- New terminal windows find that Node.js first, also when your shell profile already added `~/.local/bin` at the end of PATH (pipx does this).
- `scripts/test-install-node.sh` tests both.
- **After updating:** run `node -v` in a new terminal. If it shows a version older than v24.15, tell the owner to paste the install command again (it adds Node.js 24 and changes nothing else), then restart Claude Code. If the owner manages Node.js with nvm, Homebrew or asdf, its line in the shell profile still comes first; tell them to switch that manager to Node.js 24.15 or newer instead.

## 1.10.1 — 2026-11-07

- The context-mode plugin has a big new version (2.x). New installs get it anyway; copies installed earlier stay on 1.x, whose database module can break after a Node.js update. Nothing else changes.
- **After updating:** run `/ctx-upgrade` (or say "ctx upgrade") and follow what it prints. Then check `~/.claude/plugins/cache/context-mode/context-mode/<newest version>/hooks/hooks.json`: if its commands still point to an older version folder (seen on a Mac after 1.0.169 → 2.1.5), replace that old folder name with the newest one in that file, so the new hooks run. Tell the owner to restart Claude Code.

## 1.10.0 — 2026-11-01

- Server install, step 4 (Connect Claude): nothing has to be copied out of the terminal any more. The installer shows the login link on one line and a QR code under it, sized so the code and the prompt fit a 35-row browser terminal (click the link or scan the code with your phone), you paste back only the short code from the browser, and it saves the year-long key by itself without showing it. This makes the login work in a terminal in the browser, where copying a link over several lines and the long key failed. It needs `tmux` and `qrencode`, which the installer now adds on servers with apt; without `tmux`, or if no link appears, it falls back to the old way.
- `scripts/test-install-login.sh` tests this login against a fake `claude` (needs tmux).

## 1.9.0 — 2026-10-26

- Every start with `jarvis` now checks whether a newer claudeOS version is out. If there is one, the assistant says what it brings and asks whether to update; you no longer have to watch for updates yourself. Without a network connection the check is skipped quietly.

## 1.8.0 — 2026-10-26

- A watched Discord channel can allow extra tools for its own runs: add them as a third column in `scripts/twin/discord-channels.txt` (comma-separated, no spaces), for example the read tools of an MCP server the channel's skill uses. Other channels and the owner's channel don't get them. Lines with two columns work as before.
- **After updating:** on the server, if the service `claudeos-discord-watch` runs, restart it once so it loads the new script: `systemctl --user restart claudeos-discord-watch.service`. Otherwise nothing to do.

## 1.7.0 — 2026-10-25

- The assistant can talk in more Discord channels than yours, for example with another person's assistant. List each channel in `scripts/twin/discord-channels.txt` with a project skill that says what may be answered there, and put the channel id in `.env` under the name you list. A message that mentions the bot gets an answer within about a minute, day and night, from an always-on service on the server (`claudeos-discord-watch`). Everything written there is treated as a question, never as an instruction.
- A message ending in `[done]` closes an exchange: the assistant reads it and notes what is new, but never answers it. Two bots cannot talk in circles: at most 5 answers per channel in 15 minutes and 30 a day.
- The bot shows as online in Discord while the server runs (`claudeos-discord-presence`, needs Node.js 22 or newer, which the installer already sets up).
- **After updating:** on the server, only if `scripts/twin/discord-channels.txt` lists a channel: `cp ~/claudeos/scripts/vm/systemd/claudeos-discord-*.service ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable --now claudeos-discord-watch.service claudeos-discord-presence.service`. Otherwise tell the owner the feature exists and do nothing.

## 1.6.0 — 2026-10-18

- New skill `learn`: send the assistant a video, post, article or repo you found interesting with `/learn <link>`, and it builds a knowledge base per discipline (social media, video, SEO, sales…) in `wiki/disciplines/`. Ideas from one person wait on a "bench"; a rule needs two independent sources or your own results. A short page per discipline, in your language, explains how an expert in it thinks. Once a month (first Friday) the twin proposes new material in the brief; you pick, nothing is added on its own.
- Videos are transcribed on your machine: install `yt-dlp`, `ffmpeg` and Whisper (`mlx-whisper` on a Mac, `openai-whisper` elsewhere) when you first use it.

## 1.5.1 — 2026-10-15

- The twin's `git pull` no longer fails with "Cannot rebase onto multiple branches" when two runs start at the same moment (for example a mail run during the 07:30 run). Pulls now wait for each other through a lock file (`.git/pull.lock`). If you added scheduled jobs of your own that run `git pull` on the server, start them the same way: `flock .git/pull.lock git pull ...`.

## 1.5.0 — 2026-10-14

- Mail the assistant read and answered is now marked read, in its own mailbox and in every mailbox in `scripts/twin/mailboxes.txt`. Before, answered mail stayed unread and cluttered the mail app. Sending a reply does it on its own; for a mail answered another way, `python3 scripts/twin/mark-read.py "<Message-ID>"` does the same.

## 1.4.0 — 2026-10-12

- The twin can watch more mailboxes than the assistant's own, for example an address collecting documents for one case. List each in `scripts/twin/mailboxes.txt` with a wiki page that says what to do with its mail, and put its login in `.env` (`<PREFIX>_SERVER`, `<PREFIX>_LOGIN`, `<PREFIX>_PASS`). Any new mail there wakes the twin within 2 minutes. It still never replies on its own.

## 1.3.0 — 2026-10-12

- Recurring jobs without touching system files: give a project skill a `schedule:` line in its frontmatter (for example `schedule: monday night run`) and the twin follows it in that run. Sending still waits for your ✅ like any other draft.

## 1.2.1 — 2026-10-12

- `jarvis` opens with the plain word `start` instead of `/start`. On a brand-new install Claude Code did not know `/start` yet at its very first start ("Unknown command: /start"); the word works from the first second. Typing `/start` in a session still works.
- **After updating:** in `~/.local/bin/jarvis`, change `set -- /start` to `set -- start`.

## 1.2.0 — 2026-10-12

- Typing `jarvis` now opens with a short greeting: what is new since the version you last saw (once per version), what is due today, and a few things you can ask. It is the new `/start`; `jarvis "your question"` still goes straight to your question.
- The installer starts the first-time setup through `/start` too. On the very first start Claude Code can skip it after its own first-start questions (colour, trust); the installer now says to type `/start` if it only waits.
- **After updating:** in `~/.local/bin/jarvis`, put the line `[ $# -gt 0 ] || set -- /start` just before the last line (`exec claude "$@"`), so plain `jarvis` opens with the greeting.

## 1.1.1 — 2026-10-11

- Server install: `.env` (it holds the Claude key) can only be read by you; it was readable by other users of the server.
- Server install: the closing list says to log out and in again before typing `jarvis` (the window the installer ran in does not know the new command yet), and no longer suggests plain `claude`, which does not use the key from `.env`.
- The installer says the Claude login link on a server runs over several lines and all of them have to be copied.
- **After updating:** on a server, run `chmod 600 ~/claudeos/.env`.

## 1.1.0 — 2026-10-11

- The installer logs in to Claude at step 4, right after installing it, instead of at the very end. Without a Claude subscription you find out in the first minutes, not after the whole install.
- On a server the installer uses `claude setup-token`: a key that lasts a year instead of a login that runs out after about 28 days. It is saved in `.env` (never committed); the twin and the `jarvis` command read it from there.
- If you already had a `claudeos` folder, the installer still renames it (never deletes it), and now your assistant offers to bring its content in during the first-time setup: files go to `raw/migrated/`, get read into the wiki, and what it learns there answers the setup questions in advance. The old folder is not touched.

## 1.0.5 — 2026-10-10

- The twin warns you in Discord when its Claude login on the server has fewer than 5 days left (a `/login` lasts about 28 days). The warning comes with the morning run and tells you what to do: ssh in, run `claude`, then `/login`.

## 1.0.4 — 2026-10-09

- New `/done`: closes a session. Saves what was learned to the wiki and memory, notes what is unfinished, cleans up, commits and pushes, then tells you to type /exit.
- New `/audit`: a health check of your assistant. It scores what it knows about you, which of your tools it can actually reach, which routines really work and what runs without you (Four Cs, 100 points), and saves a dated report in `audits/` that the next audit compares against.

## 1.0.3 — 2026-10-09

- The installer says what it did with Obsidian on a Mac: "already installed", "installed", or why the download did not work (it used to skip silently).

## 1.0.2 — 2026-10-09

- The command to open your assistant is now `jarvis` (was `claudeos`). The folder stays `~/claudeos`.
- The installer opens with a welcome screen: what claudeOS is, what it will do, and the version it installs.
- On a Mac the installer no longer crashes at the last step with "EINVAL: invalid argument, kqueue" when it starts Claude Code.
- **After updating:** run the installer once more so the `jarvis` command exists: `curl -fsSL https://raw.githubusercontent.com/pdovhomilja/claudeos-template/main/install.sh | bash`. The old `claudeos` command keeps working until you delete it.

## 1.0.1 — 2026-10-08

- Mail drafts can carry files: put `attach: path, path` in the draft and the file goes out with the mail when you approve it.
- When a mail asks for something one of your skills handles (say, a monthly file to clean up), the twin now follows that skill, saves the attachments next to the mail and attaches its result to the reply draft. Recurring mail jobs become a skill of your own; the system files stay the same.

## 1.0.0 — 2026-10-08

- Versions and updates: say "update yourself" and the assistant brings in the newest version. Your wiki, sources, drafts, settings and your own edits to its files are kept.
- The installer installs Node.js first and all five plugins (context-mode, superpowers, karpathy skills, last30days, typesafe), and stops if one is missing.
- Server install no longer hangs on Ubuntu's hidden "newer kernel" dialog and no longer stops silently at the deploy key.
- **After updating:** run the installer once more (it only adds what is missing): `curl -fsSL https://raw.githubusercontent.com/pdovhomilja/claudeos-template/main/install.sh | bash` (add `-s -- --server` on a server).
