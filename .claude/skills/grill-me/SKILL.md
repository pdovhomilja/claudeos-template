---
name: grill-me
description: Relentless interview that gets what is in the user's head onto disk — every answer is checkpointed to a capture file in raw/braindumps/ before the next question, and confirmed facts are ingested into the wiki at the end. Use when {{USER_NAME}} says "grill me", wants a plan or decision stress-tested, or wants to build up context on a topic (priorities, a company, a project, a person).
disable-model-invocation: true
---

# Grill me (claudeOS)

Interview method is the `grilling` skill: build the design tree, ask the whole current frontier as one numbered round with a recommended answer per question, wait, recompute, repeat until the frontier is empty. Facts from the filesystem or tools are found by {{ASSISTANT_NAME}}, never asked. This skill adds one rule on top: **the capture file, not the conversation, is the source of truth.**

## Before the first question

1. Read `wiki/index.md` and the pages relevant to the topic, plus any earlier capture on it in `raw/braindumps/`. Ask only about gaps, changes, decisions and trade-offs; reuse what the wiki already knows.
2. Create `raw/braindumps/YYYY-MM-DD-grill-<topic-slug>.md` (real date from `date +%F`; never overwrite, add `-2` on collision). Frontmatter: `title`, `date`, `source: conversation`, `topic`, `status: in progress`. Body: goal of the session in one line, empty `## Summary`, empty `## Q&A`, empty `## Open flags`.
3. Tell {{USER_NAME}} the path in one line, then ask round 1.

## After every round of answers, before the next round

- Append each answered question to `## Q&A`: the question, {{USER_NAME}}'s answer in his words where wording matters, what was confirmed, what stays tentative, and any flag (something {{USER_NAME}} could not answer → who can).
- Update `## Summary` when an answer changes it. Never delete an earlier entry that a later answer supersedes: mark it superseded and point to the newer one.
- Read the file back. If the write failed, say so and keep the answer visible in chat; do not ask the next question on an unsaved answer.
- Keep confirmed facts, {{USER_NAME}}'s tentative ideas, {{ASSISTANT_NAME}}'s suggestions and open questions visibly distinct in the file.

One round, one write. Never batch several rounds into one save.

## When {{USER_NAME}} says stop, pause, or the frontier is empty

1. Set `status: paused` or `status: complete` and note the resume point (next unasked question).
2. Give the 3–7 key takeaways and ask if anything should be emphasized (WIKI.md ingest step 2).
3. Ingest the capture per WIKI.md: `wiki/sources/<same-slug>.md`, then update every relevant `people/`, `companies/`, `projects/`, `topics/` page with **confirmed** facts only, citing the source page. Tentative ideas and {{ASSISTANT_NAME}} suggestions stay in the capture, labeled. Contradictions with existing pages become `**Update (date):**` lines, not silent overwrites.
4. `index.md`, `log.md` (`## [date] ingest — grill: <topic>`), `/graphify . --update`.
5. Recap: capture path, pages updated, open flags with owners, resume point.

Resuming: {{USER_NAME}} names the topic or file → read it, continue numbering from the last question.

Scope: local capture and wiki ingest only. No messages or external writes from inside the interview; if an answer produces a task, list it in the recap for {{USER_NAME}} to place.
