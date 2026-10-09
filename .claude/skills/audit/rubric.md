# Four Cs rubric (claudeOS, v1 — anchors follow AIS-OS rubric v2)

Five criteria per C, 5 points each. Award **0, 1, 3 or 5 only**: the highest anchor fully supported by evidence observed in this run. 0 = absent, contradicted, or not evidenced at the 1-point level. Never interpolate, never start at 5 and deduct, never credit infrastructure {{USER_NAME}} does not need. A sample proves the sample; name what was not checked.

## Context — can a fresh session understand {{USER_NAME}} and find things? (25)

| ID | Criterion | 1 | 3 | 5 |
|---|---|---|---|---|
| C1 | Operating context | `overview.md` and SOUL.md identify {{USER_NAME}}, what they do and how they want {{ASSISTANT_NAME}} to work | Priorities, people, and collaboration rules have specific, dated sources | All of that is consistent across `overview.md`, `goals.md` and `tasks.md` |
| C2 | Routing | `index.md` gives at least one usable route | ≥3 of 5 probes succeed through the declared route; index covers every `wiki/*/` page | All 5 direct; no unindexed pages, no un-ingested raw folders, no route to retired pages |
| C3 | Freshness | Changing facts carry dates | Sampled changing facts have a refresh rule and current evidence, or are marked historical with a route to the live source | All sampled current facts verified within their interval; graph not older than the last ingest |
| C4 | Source authority | At least one canonical source is named | WIKI.md's raw → sources → pages chain holds for sampled claims; live systems (a task tool, calendar, mailbox) are named as truth for status where they exist | All sampled chains resolve to a raw file or live read; no unresolved contradiction between pages |
| C5 | Continuity | A decision or project state is recorded | The sampled active project has a current deliverable, decision rationale and next step reachable from its page | A second project or thread resumes the same way |

## Connections — can {{ASSISTANT_NAME}} reach {{USER_NAME}}'s systems? (25)

| ID | Criterion | 1 | 3 | 5 |
|---|---|---|---|---|
| N1 | Domain access | ≥1 applicable domain has a successful read, fewer than half | At least half of applicable domains read successfully | Every applicable domain read successfully in this run |
| N2 | Useful retrieval | A priority-related query and expected answer are documented | One priority-related query returned the right record with date and source | Two distinct priority-related queries did, with completeness limits noted |
| N3 | Reproducible routes | One connection has its route and purpose written down (memory file, wiki page, CLAUDE.md) | Every applicable domain has a documented route or explicit "not connected" | A sampled route was reproduced from the documentation alone |
| N4 | Action boundaries | Read/write scopes and approval rules are documented (SOUL.md boundaries, memory notes) | A needed write path has a prior authorized success recorded, or read-only scope is verified | Sampled operations respect the boundaries; duplicate/failure safeguards evidenced |
| N5 | Freshness and failure visibility | Freshness expectations are documented | Sampled reads are within them; failures surface as errors, not stale data | Recent success on every domain plus at least one demonstrated failure that was reported, not hidden |

If a domain is not applicable, say why. MCP count, keys, and write access earn nothing by themselves.

## Capabilities — do the recurring workflows produce usable results? (25)

| ID | Criterion | 1 | 3 | 5 |
|---|---|---|---|---|
| P1 | Fit and invocation | A workflow has a clear trigger tied to a stated need | One sampled workflow has a dated successful invocation | All sampled workflows do, with no overlapping triggers |
| P2 | Output quality | An example output and acceptance criteria exist | One real output checked against its criteria | All sampled outputs verified, not self-reported |
| P3 | Failure handling | Failure cases are documented | One failure case tested or observed and handled | Every sampled workflow has an observed boundary case and respects side-effect limits |
| P4 | Portability | Dependencies and invocation route documented | Sampled entry points and MCP registrations resolve | A clean session (or the twin) reproduces the workflow from the skill file alone |
| P5 | Repeated use | One dated real use | One workflow used twice with output references | All sampled workflows used repeatedly; corrections folded back into the skill |

## Cadence — does useful work happen without {{USER_NAME}} asking? (25)

| ID | Criterion | 1 | 3 | 5 |
|---|---|---|---|---|
| D1 | Real trigger | A manual ritual or scheduler config exists | One enabled trigger has a verified host and expected output | It has run unattended in that environment |
| D2 | Due executions | A dated manual completion or a failed automatic attempt is recorded | One due automatic run completed with its output | Two distinct due runs completed; no unexplained misses in the period |
| D3 | Observability | Logging and failure notification documented | Inspected runs have timestamps, outcomes, and a verified failure path | A real or safely simulated failure reached {{USER_NAME}} or {{ASSISTANT_NAME}}, and recovery is evidenced |
| D4 | Control | Stop/disable and ownership documented | Config confirms controls and duplicate protection | Stop/recovery demonstrated without side effects |
| D5 | Maintenance loop | Review frequency defined (`/friday`, lint every ~10 ingests, weekly audit) | One completed review fixed something or verified nothing needed | Two cycles recorded with follow-up verification |

Manual-only cadence caps Cadence at **10**. Two back-to-back manual runs are not two due executions.

## Caps and stage

1. If the probes cannot recover {{USER_NAME}}'s purpose or any authoritative priority source: **Context ≤ 10**.
2. No verified automatic trigger: **Cadence ≤ 10**.
3. Raw total = sum of the four. Then the lowest applicable cap wins:
   - any C < 10 → total ≤ **49**
   - any C < 15, or fewer than two verified due automatic successes → total ≤ **69**
   - any C < 20, or an unresolved routing/authority contradiction → total ≤ **84**
4. Final = min(raw, cap). Show every cap applied and why.

| Final | Stage |
|---|---|
| 0–24 | Unproven |
| 25–49 | Foundation |
| 50–69 | Working, with gaps |
| 70–84 | Dependable in the verified scope |
| 85–100 | Maintained and evidenced |

Calibration: a vault with rich wiki pages but no live reads this run stays under 69. Excellent Context/Connections/Capabilities with manual-only cadence is raw 85, final 69.
