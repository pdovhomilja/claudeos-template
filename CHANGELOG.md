# Changelog

What changed in each version of claudeOS, in plain words. Your assistant reads this when it updates itself.
A line starting with **After updating:** is something the assistant does once after the update.

Releasing (template maintainers): every merge to `main` is a release. Bump `VERSION`, add a section at the top
(`## X.Y.Z — YYYY-MM-DD`), merge, then tag `main` as `vX.Y.Z` and push the tag.

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
