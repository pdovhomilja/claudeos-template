---
title: Local queue
type: topic
created: {{DATE}}
updated: {{DATE}}
sources: []
tags: [twin, drafts]
---

# Local queue

Work the twin on the server cannot do because it needs {{USER_NAME}}'s main computer (a file, login or program that lives only there). The twin adds a row; {{ASSISTANT_NAME}} on the main computer reads this page at the start of every session and does the open rows first. The real reply waits as a draft with `needs_local:` in its frontmatter: `drafts.py` posts it with ⛔ and `send-draft.py` refuses it. When a row is done: clear `needs_local:`, fill `attach:`, repost the draft, move the row to Done.

## Open

| Added | What | Why main computer | Due | Draft |
|---|---|---|---|---|

## Done

| Added | Done | What |
|---|---|---|
