---
name: update
description: Update this claudeOS to the newest template version without losing data or personal edits. Use when the user says "update yourself" (or the same in their language), asks whether there is a new claudeOS version, or a twin brief reports one.
---

# Update claudeOS

`scripts/update.py` does the mechanics: it never changes `wiki/`, `raw/`, `staging/`, `.obsidian/` or files the template does not have, and merges every other template file three ways so the user's own edits stay. The whole update is one commit.

1. **Clean start.** `git pull` (if there is a remote). Commit anything uncommitted with a normal message first.
2. **What is new.** `python3 scripts/update.py --check`. "Up to date" → say so and stop. Otherwise tell the user in their language, in a few plain sentences, what the new version brings (from the printed changelog), and ask whether to update now.
3. **Profile.** If `.claudeos/profile` does not exist (copies set up before 1.0.0), create it:
   ```
   USER_NAME=<the user's name exactly as it stands in CLAUDE.md>
   ASSISTANT_NAME=<your name exactly as it stands in CLAUDE.md>
   DATE=<setup date YYYY-MM-DD: content of .claudeos-setup-done, or the first "Setup" entry in wiki/log.md>
   ```
   The values must match what the setup put in place of `{{USER_NAME}}`, `{{ASSISTANT_NAME}}`, `{{DATE}}`; otherwise every personalised line becomes a conflict. Commit it.
4. **Update.** `python3 scripts/update.py`.
   - Exit 0: done and committed.
   - Exit 2: open each listed file and resolve the markers (`<<<<<<< yours` … `>>>>>>> template X`). Keep the user's own additions and personal content; take the template's new wording and fixes. The "First run" section of `CLAUDE.md` stays deleted when `.claudeos-setup-done` exists. Ask the user only where both sides changed the same thing and the choice matters to them, one plain sentence per question. A binary file comes with `<file>.new`: pick one, delete the other. Then `git add -A <files> && git commit -m "claudeOS update <old> → <new>"`.
   - Lines it printed about kept or deleted files: tell the user in one line.
5. **After updating.** Do every "**After updating:**" step in the changelog sections between the old and the new version (e.g. run the installer again for new tools or plugins). Plugins installed now work from the next start.
6. **Finish.** Push. Log `## [YYYY-MM-DD] note — claudeOS updated to <new>` in `wiki/log.md` with one line on what changed. If the user is unhappy with the result: `git revert <update commit>` and push.
