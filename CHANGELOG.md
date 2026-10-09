# Changelog

What changed in each version of claudeOS, in plain words. Your assistant reads this when it updates itself.
A line starting with **After updating:** is something the assistant does once after the update.

Releasing (template maintainers): every merge to `main` is a release. Bump `VERSION`, add a section at the top
(`## X.Y.Z — YYYY-MM-DD`), merge, then tag `main` as `vX.Y.Z` and push the tag.

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
