---
name: done
description: End-of-session close. Saves what this session learned to the wiki and memory, cleans up what the session left behind, commits and pushes, then hands back for /exit.
argument-hint: "(optional) anything to make sure gets saved"
disable-model-invocation: true
---

{{USER_NAME}} is ending the session. Close it so that nothing learned is lost and nothing is left behind. Work through the steps without asking, unless a step says to ask. If an argument was passed, treat it as something that must be saved.

0. **Evening close first?** If `wiki/log.md` has no `## [<today>] note — eod` entry, ask once: "You haven't run /eod today. Do it now?" If yes, read `.claude/skills/eod/SKILL.md` and follow it ({{USER_NAME}} gives the done/half/add line), then continue here. If no, continue.

1. **Pull.** If the repo has a remote: `git pull --rebase origin main` (a twin on a server may have pushed during the session). If uncommitted changes block it, see step 5 first.

2. **Save what was learned.** Go back over the whole conversation and pick out what is durable: decisions {{USER_NAME}} made and why, new facts about people, companies, projects, deadlines, money, open questions that were answered, new open questions. For each:
   - write it to the right wiki page per WIKI.md (Remember: `sources: [conversation YYYY-MM-DD]`; contradictions as `**Update (YYYY-MM-DD):**`, never silent overwrites); new pages get a line in `index.md`;
   - when {{USER_NAME}} answered a question, remove it from every page and doc that still asks it;
   - {{USER_NAME}}'s corrections and preferences about how {{ASSISTANT_NAME}} works go to auto-memory as `feedback` (update an existing memory rather than duplicating it);
   - deliverables made this session: saved where {{USER_NAME}} can find them (`staging/` for drafts), with their version in the file name or header.
   Skip anything the repo or git history already records. Chit-chat and dead ends are not worth saving.

3. **Open loops.** Anything started but not finished goes to `wiki/tasks.md` with what is left and where the files are. Mail sent this session that needs an answer has a row in `wiki/topics/waiting-for.md`. Accepted rows in `wiki/topics/system-improvements.md` that were built get `done`.

4. **Log.** One entry in `wiki/log.md`: `## [YYYY-MM-DD] note — session close: <topics>`, then 1–3 lines with what was done and what carries over.

5. **Clean up what this session created, and only that.** Temporary git worktrees and local branches already merged; scratch files under the scratchpad are fine to leave. Background processes or test containers this session started (remove by name, never a global prune). Uncommitted changes that this session did not make belong to another session or to {{USER_NAME}}: list them and ask before touching them. Before any `git add`, check `git status` for deleted files under `raw/`; restore anything deleted by accident.

6. **Commit and push.** Commit this session's files by path (not `git add -A`), in logical commits. If the wiki changed, run `/graphify . --update` and commit `graphify-out/`. If the repo has a remote: `git pull --rebase origin main && git push origin main`, and confirm `git status -sb` shows `main...origin/main` with nothing ahead.

7. **Hand back.** Reply in at most 8 lines: what was saved (pages), what carries over, anything {{USER_NAME}} must do, and anything you could not do and why. End with: "All saved. Type /exit to close."
