---
name: audit
description: Evidence-based health check of claudeOS — scores Context, Connections, Capabilities and Cadence (Four Cs, 25 each), probes retrieval routes, verifies live connections read-only, and saves a dated report in audits/ with a finding ledger carried across runs. Use when {{USER_NAME}} says "audit claudeOS", "audit {{ASSISTANT_NAME}}", "how healthy is the system", or weekly during active setup.
disable-model-invocation: true
---

# claudeOS audit

Answer one question with evidence: **can a fresh {{ASSISTANT_NAME}} session understand {{USER_NAME}}, reach their systems, do the recurring work, and does useful work happen without them asking?** Score the Four Cs with [rubric.md](rubric.md) and save the report with [report-template.md](report-template.md). The number is *verified operational reliability*, not usefulness. A folder, a configured MCP, a skill file, or a confident sentence in a wiki page is not evidence; a successful read, a dated output, or a run record is.

Read-only toward everything inspected. The only writes are the new report under `audits/` and one line in `wiki/log.md`. No repairs, no timer or cron changes, no messages, no test alerts. Never inflate or depress a score to motivate a rerun.

Adapted from the AIS-OS `/audit` skill (Four Cs of an AI OS™ © 2026 Nate Herk, MIT).

## 1. Scope and prior evidence

1. `date -u +%Y-%m-%dT%H:%M:%SZ` for the run timestamp; run id `YYYYMMDD-HHMM`.
2. Read `CLAUDE.md`, `SOUL.md`, `WIKI.md`, `wiki/overview.md`, `wiki/goals.md`, `wiki/index.md`, `wiki/tasks.md`, last 10 entries of `wiki/log.md`.
3. List `audits/` (create it if missing). Read the latest complete report's frontmatter and **Finding ledger** only (not the whole file). No report → this run is the **first recorded baseline**; say so, invent no delta.
4. Runtimes in scope: Claude Code in this folder, and the twin on a server if one is set up (CLAUDE.md, "Twin"). Outside tools the assistant talks to are *connections*, not runtimes.
5. Pick {{USER_NAME}}'s current top three priorities from `goals.md`, `overview.md` and today's Must in `tasks.md`. Everything below is sampled against those, not against the most polished pages.

## 2. Context — five retrieval probes

For each probe: question → declared route (`index.md` → page, or CLAUDE.md rule) → source found → result **direct / fallback (grep or graphify) / not found** → freshness (page `updated` vs. what the fact needs). A fallback hit proves the fact exists, not that the route works.

1. What does {{USER_NAME}} do, for whom, and what matters this quarter? (`overview.md`, `goals.md`)
2. Where is the authoritative current priority and how would I verify it? (`goals.md`, `tasks.md`, or a task tool named in the wiki)
3. Latest deliverable and next step for one active project from the top three. (`projects/` page → `raw/` folder or `staging/`)
4. One previous decision or lesson and its supporting source. (a `**Update (date):**` line or synthesis → `sources/` page → `raw/`)
5. One external record: a contract, official document or registry fact, and how it is reached. (a `sources/` page → raw file or URL)

Also: compare `index.md` with the immediate contents of `wiki/*/` and `raw/` — unindexed pages, raw folders with no `sources/` page, zips or exports sitting in `raw/` un-ingested. Check that `overview.md` priorities agree with `goals.md` and `tasks.md`.

## 3. Connections — read-only checks

List the domains that apply to {{USER_NAME}} from `overview.md`, CLAUDE.md, the memory notes and `claude mcp list` (plus the claude.ai connectors in this session). Typical ones below; add what they use, drop what they don't (say why). Run the cheapest read that proves auth and data; record tool, timestamp, and one non-secret fact returned. Mark **verified / documented only / failed / not applicable (reason)**.

| Domain | Typical route | Safe check |
|---|---|---|
| Tasks | `wiki/tasks.md`, or a task MCP named in the wiki | read today's Must; one list call on the tool |
| Calendar | calendar connector | list today's events |
| Email | mail connector; {{ASSISTANT_NAME}}'s mailbox (`scripts/twin/mailbox.py`) | newest threads of the last day; `mailbox.py list` |
| Files / documents | drive connector, synced folders | one search or listing |
| Business systems | any MCP for finances, CRM, cases, infrastructure | its cheapest read (`whoami`, a list, a stats call) |
| Twin | ssh to the server named in the wiki | `systemctl --user list-timers 'claudeos-*'`; date of the newest brief in `wiki/twin/` |
| Knowledge graph | `graphify-out/graph.json` | mtime vs. last `wiki/log.md` entry |

Do not print secrets or bulk private records. A tool that is configured but errors is **failed**, with the error text. Skip an SSH check if the host is unreachable within one attempt; mark unverified.

## 4. Capabilities — three priority workflows

Choose up to three from: `/morning`, `/eod`, `/friday`, `/done`, ingest (WIKI.md), `/graphify --update`, `humanizer` on outbound text, `/grill-me`, a mail draft approved in Discord, a twin run. Prefer the ones the top three priorities depend on. For each: trigger, inputs, where the output lands, **dated evidence of real use** (`wiki/log.md` entries, task ticks, twin briefs, sent drafts), one failure case observed or documented, and whether a clean session could run it from the skill file alone. Do not run paid or side-effecting workflows to manufacture evidence.

## 5. Cadence — what runs without {{USER_NAME}}

Inventory: the twin's systemd timers (`claudeos-twin` twice a day, `claudeos-mail` every 2 minutes 08–23), any other schedulers named in the wiki, and the manual rituals (`/morning`, `/eod`, `/friday` count with the rubric's 10/25 cap). For each enabled trigger: host, schedule, expected output, last due run, success evidence (brief in `wiki/twin/`, run logs in `runs/twin/`, Discord post, push in `git log`), failure visibility, stop/recovery command. No twin → say so; Cadence is then capped by the rubric.

## 6. Score

Apply [rubric.md](rubric.md): 20 criteria, 0/1/3/5 only, subtotals, caps in order, final, stage. Show the arithmetic. Distinguish **defect** (checked, broken) from **verification gap** (not checked, unknown). Missing evidence earns nothing but is not a defect.

Findings get stable ids `A-<run-id>-NN`. Carry every open item from the prior ledger with status New / Still open / Resolved / Reopened / Not rechecked / No longer applicable. Resolved needs the original completion check to pass now.

## 7. Report and save

Chat reply, in this order, under ~40 lines:

1. **Blocked on {{USER_NAME}}** — decisions only, or "nothing".
2. One-paragraph conclusion: what works, the most consequential gap, score and stage.
3. Four subtotals, caps applied, final.
4. Top three actions, each labeled **repair / verify / optional**, with the finding id and the check that proves it done.
5. Progress vs. prior report (transitions), or "first baseline".
6. Path of the saved report.

Saved report: fill [report-template.md](report-template.md) completely, write to `audits/YYYY-MM-DD-HHMM.md` (never overwrite; add a suffix on collision), read it back, then append `## [YYYY-MM-DD] audit — <final>/100 <stage>; top gap: <one line>` to `wiki/log.md`. If saving fails, say **report not saved** and put the full report in chat. Do not touch `index.md`, `overview.md`, or any other wiki page; the audit observes, the fixes happen in later sessions.

Recommend rerunning weekly during active setup and after any fix that targets a finding.
