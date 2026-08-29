# raw/projects — {{USER_NAME}}'s project context

Drop anything that gives {{ASSISTANT_NAME}} context on a project, school subject, company, or hobby here: docs, notes, exports, screenshots, PDFs. {{ASSISTANT_NAME}} reads, never edits (see WIKI.md). Say "ingest" and the file gets summarised into the wiki.

Conventions
- Filenames date-prefixed where it makes sense: `YYYY-MM-DD-title.ext`.
- One folder per project, named with the wiki slug (kebab-case). Each folder maps to one `wiki/projects/<slug>.md` page.
- Need a new folder? Create it and {{ASSISTANT_NAME}} will add the page on the next ingest.

Example
```
school/                 projects/school
  math/                 projects/math
game-dev/               projects/game-dev
```
