---
name: friday
description: 30-minute Friday review — brain dump, close the week, check goals, pick next week's three priorities, prune tasks.
disable-model-invocation: true
---

Run the steps in order; announce each with its time budget; stop at 30 minutes and carry the rest to next Friday.

**0. Brain dump (10 min).** Say: "Dump. Everything in your head, any order, no sorting." Write the text verbatim to `raw/braindumps/YYYY-MM-DD.md` (frontmatter: date, source: conversation). Sort every item: task → `wiki/tasks.md`; decision or fact → wiki (`remember` flow per WIKI.md). Show what went where in one table.

**1. Close the week (5 min).** From `wiki/tasks.md` and `wiki/log.md` since last Friday: done count, slips (`slip` notes), what carried. Move ticked tasks older than a week out of the open list.

**2. Goals (5 min).** For each goal in `wiki/goals.md`: Current vs Outcome, one line. Ask if any goal changes; the user sets goals, the assistant only proposes.

**3. Next week's three (5 min).** Propose three priorities ranked by goal gap per hour of the user's time and hard dates. The user confirms or swaps.

**4. Prune (5 min).** Exactly 5 of the oldest open tasks: keep / done / drop, one each. Never more than 5.

Finish: append `## [YYYY-MM-DD] note — friday: …` to `wiki/log.md` with the three priorities, done count and slips; run `/graphify . --update`.
