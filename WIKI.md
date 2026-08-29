# WIKI.md — {{ASSISTANT_NAME}}'s persistent memory

Inspired by Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) pattern. The memory is not a chat log or a RAG index — it is a **persistent, compounding wiki** of interlinked Markdown pages that {{ASSISTANT_NAME}} writes and maintains, and {{USER_NAME}} reads (e.g. in Obsidian). Knowledge is compiled once and kept current, not re-derived every session.

## Three layers

| Layer | Path | Owner | Rule |
|---|---|---|---|
| Raw sources | `raw/` | {{USER_NAME}} | Immutable. {{ASSISTANT_NAME}} reads, never edits. |
| Wiki | `wiki/` | {{ASSISTANT_NAME}} | {{ASSISTANT_NAME}} writes and maintains everything here. {{USER_NAME}} reads. |
| Schema | `WIKI.md` (this file) | Both | How the wiki is structured and maintained. Co-evolves over time. |

## Directory layout

```
raw/                    # source of truth, immutable
  YYYY-MM-DD-title.md   # articles, transcripts, emails, notes, documents
  assets/               # images and attachments
  projects/             # {{USER_NAME}}'s project context, nested by owner: <company>/<product>/ (see raw/projects/README.md)

wiki/
  index.md              # catalog of every page, by category — read this FIRST
  log.md                # append-only chronological record of ingests/queries/lints
  overview.md           # the big picture: {{USER_NAME}}, the business, current priorities
  people/               # one page per person
  companies/            # one page per company, client, supplier, competitor
  projects/             # one page per project or initiative
  topics/               # concepts, domains, recurring themes
  sources/              # one summary page per raw source
  syntheses/            # answers, comparisons, analyses worth keeping
  tasks.md              # open to-dos and follow-ups, with owner and date
```

## Page conventions

- Markdown, English (or Czech if the source/topic is Czech). Filenames: `kebab-case.md`.
- Every page starts with YAML frontmatter:
  ```yaml
  ---
  title: Page title
  type: person | company | project | topic | source | synthesis
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
  sources: [2026-08-23-meeting-acme]   # raw files this page draws on
  tags: []
  ---
  ```
- Link between pages with `[[wikilinks]]`. Link generously — connections are the value.
- When a new source contradicts an existing claim, do not silently overwrite. Write: `**Update (YYYY-MM-DD):** previously X, now Y per [[source]]`.
- Cite sources: claims in entity/topic pages point to the `sources/` page they came from.
- `index.md`: one line per page — `- [[page]] — one-line summary (type, updated date)`, grouped by category. Update on every ingest.
- `log.md`: append-only. Every entry starts with `## [YYYY-MM-DD] ingest | query | lint | note — Title` so it can be grepped (`grep "^## \[" wiki/log.md | tail -5`).

## Operations

### Ingest
Trigger: {{USER_NAME}} drops a file into `raw/` (usually `raw/projects/<company>/[<product>/]`, where the folder names are wiki slugs — each folder maps to one `companies/` or `projects/` page) and says "ingest", or pastes/describes something worth remembering.
1. Read the source in full.
2. Briefly tell {{USER_NAME}} the key takeaways (3–7 bullets) and ask if anything should be emphasized.
3. Write `wiki/sources/<name>.md` — summary, key facts, decisions, open questions, links to entities.
4. Create or update every relevant `people/`, `companies/`, `projects/`, `topics/` page. One source may touch 10+ pages — that is expected.
5. Update `overview.md` if priorities or the big picture changed.
6. Update `index.md` and append to `log.md`.

### Query
Trigger: {{USER_NAME}} asks a question about anything the wiki might cover.
1. Read `index.md` first, then drill into the relevant pages. Do not re-read raw sources unless the wiki is insufficient.
2. Answer with citations (`[[page]]`).
3. If the answer is a synthesis worth keeping (comparison, analysis, decision rationale, discovered connection), file it as `wiki/syntheses/<name>.md`, link it, update `index.md` and `log.md`.

### Lint
Trigger: {{USER_NAME}} says "lint the wiki", or roughly every 10 ingests.
Check for: contradictions between pages, stale claims superseded by newer sources, orphan pages with no inbound links, concepts mentioned often but lacking a page, missing cross-references, gaps worth a web search. Report findings, fix the mechanical ones, ask about the judgment calls. Log the pass.

### Remember
Trigger: {{USER_NAME}} says "remember this" or states a durable fact in passing.
Write it to the right wiki page immediately (no raw file needed — the conversation is the source; note `sources: [conversation YYYY-MM-DD]`). Update `index.md` and `log.md`.

## Session start

At the beginning of every session, read `wiki/overview.md`, skim `wiki/index.md` and the last 5 entries of `wiki/log.md`. That is how {{ASSISTANT_NAME}} remembers.

## Principles

- {{USER_NAME}} curates sources, directs analysis, asks questions, and thinks. {{ASSISTANT_NAME}} does all the bookkeeping.
- The wiki should always reflect everything that has been read. Never let a source sit un-integrated.
- Prefer updating an existing page over creating a near-duplicate.
- Keep pages readable by a human in Obsidian — short paragraphs, headings, bullet lists.
- This schema is not final. When a convention stops working, propose a change to {{USER_NAME}} and update this file.
