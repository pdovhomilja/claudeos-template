---
audit_kind: claudeos
run_id: "YYYYMMDD-HHMM"
started_at: "ISO-8601 UTC"
completed_at: "ISO-8601 UTC"
report_status: complete | partial
rubric_version: claudeos-v1
previous_report: null | audits/YYYY-MM-DD-HHMM.md
scores_comparable: false | true
scores:
  context: null
  connections: null
  capabilities: null
  cadence: null
  raw_total: null
  final: null
  stage: null
---

# claudeOS audit — YYYY-MM-DD

## Blocked on {{USER_NAME}}
<decisions only, or "nothing">

## Conclusion and scope
<what works, the most consequential gap, runtimes, priorities sampled, domains and workflows inspected, what was not checked and why. Mark partial runs.>

## Retrieval probes
| # | Question | Route tried | Source found | Result (direct / fallback / not found) | Freshness |
|---|---|---|---|---|---|

<index vs. folders: unindexed pages, un-ingested raw, routes to retired pages, overview vs. goals and tasks agreement>

## Connections
| Domain | Route | Check run | Result | Evidence (timestamp, non-secret fact) |
|---|---|---|---|---|

## Capabilities
| Workflow | Trigger | Output lands in | Dated real-use evidence | Failure case | Clean-session runnable |
|---|---|---|---|---|---|

## Cadence
| Trigger | Host | Schedule | Expected output | Last due run | Success evidence | Failure visibility | Stop / recover |
|---|---|---|---|---|---|---|---|

## Score
| C | Criteria (id: pts) | Subtotal | Cap |
|---|---|---|---|
| Context | C1 _ C2 _ C3 _ C4 _ C5 _ | /25 | |
| Connections | N1 _ N2 _ N3 _ N4 _ N5 _ | /25 | |
| Capabilities | P1 _ P2 _ P3 _ P4 _ P5 _ | /25 | |
| Cadence | D1 _ D2 _ D3 _ D4 _ D5 _ | /25 | |

Raw total: _ · Caps applied: _ (reason) · **Final: _ /100 · Stage: _**

<how defects vs. unverified evidence limited credit>

## Finding ledger
| ID | Class (defect / gap / opportunity) | Target | First seen | Prior status | Current status | Evidence | Completion check |
|---|---|---|---|---|---|---|---|

<all current findings plus every carried finding, including Not rechecked and compact prior closures>

## Progress since previous audit
<previous report link and comparable scores, or "first recorded baseline". Separate real repairs, evidence-only gains, regressions, scope changes.>

## Top actions
1. **repair / verify / optional** — <action> (A-…) · benefit · done when: <check>
2. …
3. …

Next audit: <when, and what to recheck first>
