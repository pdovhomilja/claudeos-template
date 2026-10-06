---
title: Waiting for
type: topic
created: {{DATE}}
updated: {{DATE}}
sources: []
tags: [mail]
---

# Waiting for

Mails {{ASSISTANT_NAME}} sent from its own mailbox that need an answer. `scripts/send-mail.py --wait "…" [--due YYYY-MM-DD]` (or `wait:`/`due:` in a draft's frontmatter) adds the row at send time. The Message-ID ties the reply back to its row.

Format: `- [ ] due · to · subject · what we asked → what to do on reply · sent date · Message-ID`

- **Reply arrives** (twin mail run or a session): find the row by the Message-ID in the reply's `In-Reply-To`/`References`, do the "on reply" step within the tiers, then move the row to Closed with `→ replied YYYY-MM-DD, [[source page]]`.
- **Due date passed with no reply:** the twin's brief lists the row and drafts a reminder in `staging/` (tier 1, {{USER_NAME}} approves).
- **No longer needed:** move to Closed with the reason.

## Open

## Closed
