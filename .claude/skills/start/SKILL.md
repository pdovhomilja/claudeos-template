---
name: start
description: Opens every session started with the jarvis command — a short greeting, whether a newer claudeOS version is available (and offers to update), what is new since the version the user last saw, and what to do next. Runs the first-time setup instead when it has not been done yet.
---

1. **Not set up yet?** If `.claudeos-setup-done` does not exist, run the first-time setup from `CLAUDE.md` now and skip the rest of this skill.
2. **Catch up.** `git pull` (if there is a remote), then the session start from `WIKI.md`. Read `wiki/goals.md` and `wiki/tasks.md`.
3. **Update available?** Run `python3 scripts/update.py --check` (it only fetches; it changes nothing). "Up to date", no network or any error → skip this step silently. Otherwise keep the installed and newest version numbers and the 1–3 points of the printed changelog that matter most to the user.
4. **New version?** Compare `VERSION` with `.claudeos/seen-version`. If they differ: read the `CHANGELOG.md` sections newer than the seen version (only the newest section if the file is missing) and keep the 2–4 points that change what the user can do. Write `VERSION` into `.claudeos/seen-version` and commit it.
5. **Greet**, all of it in the user's language (see `SOUL.md`), under 12 lines, in this shape:
   - one line: hello by name;
   - **Update available: X → Y** (only if step 3 found one): those points in plain words, then ask whether to update now. On yes, follow `.claude/skills/update/SKILL.md` before anything else; on no, carry on and ask again at the next start;
   - **New in X.Y.Z** (only if step 4 found something): those points in plain words;
   - **Today:** up to three open items from `wiki/tasks.md` that are due or overdue, or else the goal with the biggest gap; nothing open → one line saying so;
   - **You can ask me, for example:** two or three things that fit their goals and the skills in `.claude/skills/` (e.g. "/morning to plan the day", "drop a file into raw and say ingest").

   End with one short question about what to do now (or the update question, if there is one), then wait. No motivational text.
