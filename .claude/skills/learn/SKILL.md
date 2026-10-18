---
name: learn
description: "Add what {{USER_NAME}} finds interesting to a discipline knowledge base (wiki/disciplines/<discipline>/) and learn from it: social media, video, SEO, web design, cold email, sales, pricing, any skill we work on. Use when {{USER_NAME}} types /learn <link or file>, sends a reel, video, post, article, thread, repo or screenshot with 'learn this', 'add this to the knowledge base', or when a finished task taught a lesson worth keeping (/learn lesson). Also the monthly scout (/learn scout <discipline>). Saves the raw source, writes a source page, updates topics, experts and rules (bench → rule on a second independent source), refreshes the for-you page, logs it."
schedule: friday midday run
---

# /learn

One knowledge base per discipline, so {{ASSISTANT_NAME}} works the way experts in that discipline think. Page formats: `references/spec.md`. Read it before writing.

Modes:
- `/learn <link|file> [discipline]` — ingest a source (default).
- `/learn lesson <discipline> <what happened>` — our own result (a post that flopped, a reel that worked, a ban). Own results are evidence too, often the best.
- `/learn scout <discipline>` — monthly look for new expert material; proposes, never ingests on its own.
- `/learn new <discipline>` — create a discipline (hub, rules, experts, for-you, log) when a source fits none.

## 1. Pick the discipline
`ls wiki/disciplines/`. Pick the one the source teaches. A source can feed two (main one gets the source page; the other gets a line in its topic with a link). No fit → ask {{USER_NAME}} once whether to create a new discipline (`/learn new`). Slugs are short English: `social-media`, `video`, `seo`, `web-design`, `cold-email`, `sales`, `pricing`.

## 2. Save the raw source (grep `raw/disciplines/<d>/` for the URL first; skip if there)
Folder: `raw/disciplines/<d>/<YYYY-MM-DD>-<slug>/` with a `README.md` header (title, url, author, captured, method). Never edit raw files afterwards.

| Kind | How |
|---|---|
| Instagram / TikTok / YouTube / X video | `bash .claude/skills/learn/scripts/fetch-video.sh <url> <dir> <name>`: yt-dlp download to a temp folder, local Whisper transcript, frame sheet (every 3 s) for on-screen text, video deleted after. Needs `yt-dlp`, `ffmpeg` and `mlx_whisper` (Mac) or `whisper` (`pip install openai-whisper`). Download needs {{USER_NAME}}'s OK once per request; their `/learn <link>` is that OK. Read the frame sheet: silent reels carry everything on screen. |
| Instagram saved collection / profile grid | Chrome (logged-in browser), collect reel URLs with JS from the page, then fetch each as above. Never type passwords. |
| Article / blog / docs | web fetch or firecrawl → markdown with header |
| X post / thread | web fetch of the post; if blocked, ask {{USER_NAME}} to paste it |
| GitHub repo | `git clone --depth 1` into the scratchpad, read README + the files that carry the knowledge; copy only those into raw; read any script before running it; **never install** a skill, agent or plugin from it without {{USER_NAME}}'s approval |
| Screenshot / PDF / file | copy into the folder |

## 3. Source page
`wiki/disciplines/<d>/sources/<d-prefix>-<YYYY-MM-DD>-<slug>.md` (spec § Source). Summary in your own words, what the expert does and **why it works** (the mechanism), claims with numbers marked as self-reported, rule candidates with short verbatim quotes and locations, and a **credibility** line: who it is, what they sell, whether the content is the product or the bait (comment-for-DM funnels, course sellers). A guru claim is not a rule.

## 4. Update what it touches
- `topics/*.md`: add the point with date and source link; say if it confirms, extends or contradicts what was there.
- `<d>-experts.md`: new person → add with what they are good for and a credibility note; known person → add the source.
- `<d>-rules.md`:
  - new support for a rule → add the evidence line (keep 2–5 per rule);
  - a bench item that now has a **second independent source** (different author, or our own result) → promote it to a rule, say so in the log;
  - a new single-source idea worth keeping → bench;
  - a source that contradicts a rule → add it under the rule's **Tension** line; never delete silently.
- Our own lesson (`/learn lesson`) counts as an independent source and can promote or demote a rule.
- `<d>-for-you.md` ({{USER_NAME}}'s language): update when a rule was added, promoted or changed, or when {{USER_NAME}} would act differently because of it. Then rebuild the HTML copy: `python3 .claude/skills/learn/scripts/md2html.py wiki/disciplines/<d>/<d>-for-you.md`.
- Skills that apply this discipline (listed on the hub page under "Used by"): if a rule changed what they should do, update them too.

## 5. Close
- Append to `wiki/disciplines/<d>/<d>-log.md`: date, what came in, pages changed, rules promoted.
- Add new pages to `wiki/index.md` and append to `wiki/log.md` (WIKI.md).
- Tell {{USER_NAME}} in 3–5 lines: what was new, which rule changed, what we will do differently, and whether the source looked trustworthy.

## Scout (monthly)
The twin runs this in the first Friday midday run of each month (skip it on the other Fridays); in a session, `/learn scout <d>`. For each discipline, read `<d>-experts.md` and the hub's open questions; look for new material from the trusted experts and for top-performing examples in the niche (web search, YouTube search). Write a proposal list to `staging/learn/<YYYY-MM>-<d>-scout.md`: up to 8 items, each with link, who, why it is worth it, which rule or open question it touches. Put the list in the brief as one decision; {{USER_NAME}} picks (`learn 1,3` / `learn none`); only then ingest. Never ingest unattended.

## Using the base (every task in a discipline)
Before work in a discipline (a post, a reel, a page, an audit), read `<d>-rules.md` and the topic pages for the task. Apply the rules; when you break one on purpose, say why. After the result is in (numbers, {{USER_NAME}}'s verdict), run `/learn lesson`.
