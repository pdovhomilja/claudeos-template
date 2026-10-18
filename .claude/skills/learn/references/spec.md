# Discipline knowledge base — page spec

Layout of `wiki/disciplines/<d>/` (`<d>` = discipline slug; wikilinks resolve by file name across the whole wiki, so every file name carries the discipline prefix):

```
<d>.md                hub: what the discipline covers, how to use it, Used by, open questions, sources list
<d>-rules.md          the rules (≥ 2 independent sources each) + bench (1 source)
<d>-experts.md        who to learn from, what for, credibility
<d>-for-you.md        in {{USER_NAME}}'s language: how an expert in this discipline thinks; + .html reading copy
<d>-log.md            dated ingest log
topics/<d>-<topic>.md
sources/<p>-<YYYY-MM-DD>-<slug>.md     <p> = short prefix per discipline (social-media → sm, video → vid, seo → seo, web-design → wd)
```

English everywhere except `<d>-for-you.md`, which is in {{USER_NAME}}'s language. Frontmatter on every page:

```
---
title: ...
type: discipline-hub | discipline-rules | discipline-experts | discipline-guide | discipline-log | discipline-topic | discipline-source
discipline: <d>
updated: YYYY-MM-DD
sources: [source page names]        # topics, rules, guide
---
```

## Source
```
---
title: <title>
type: discipline-source
discipline: <d>
kind: reel | video | article | thread | repo | book | own-result
author: <name/handle>
date: YYYY-MM-DD            # published if known, else captured
url: <url>
raw: raw/disciplines/<d>/<folder>/<file>
updated: YYYY-MM-DD
---
## Summary            3–6 lines, own words
## What they do and why it works     the mechanism, not just the tactic
## Claims             numbers they state, marked "(self-reported)"
## Credibility        who, what they sell, bait vs substance, conflicts with our rules
## Rule candidates    - **<rule>** — "<verbatim quote ≤ 20 words>" [location]  |  (inferred) <why>
## Topics             [[<d>-<topic>]], ...
```

## Rules page
Each rule:
```
## N. <rule as an instruction>
<2–4 lines: what to do, why it works (mechanism)>
**Evidence** — "<quote>" — [[source]] [loc]  (2–5 lines, different authors; own results count)
**Applies when:** ...
**Check:** <one question an agent asks about its own draft>
**Tension:** <contradicting source, if any>
```
Then `## Bench` (one source each, with the source link) and `## Retired` (rules our results disproved, with the lesson link).

## Experts page
Table: who · platform/handle · good for · credibility (what they sell, self-reported vs verifiable numbers) · sources ingested.

## For you
Plain language, no jargon without explanation. Sections: How an expert thinks (the 5–10 ideas that matter most) · What we do differently (concrete changes for our work) · Watch out for (traps, guru bait) · Glossary (terms) · What we learn next (open questions). Every claim links to the rule or source. Keep it under ~2 pages; it is rewritten, not appended.
