---
name: eod
description: 2-minute evening close — tick tasks from a one-line status, log why the Must slipped, carry the rest.
argument-hint: "done: X, half: Y"
disable-model-invocation: true
---

1. Parse the user's line (argument or next message): "done: …", "half: …", "not: …", "add: …".
2. **Update `wiki/tasks.md`:** done → tick it (`- [x]`, with today's date); half → stays open, append `progress YYYY-MM-DD: …`; add → new open line with owner and date.
3. **If today's Must is not done**, ask exactly one question: "Why not — in one line?" Append the answer to the task as `slip YYYY-MM-DD: …`. No follow-up, no advice.
4. Append one line to `wiki/log.md`: `## [YYYY-MM-DD] note — eod: Must <done|slipped>; N done; carry: …`.
5. Reply in ≤6 lines: what moved, what carries to tomorrow. Tomorrow's Must is picked in `/morning`, not now.
