#!/usr/bin/env python3
# usage: md2html.py <page.md> — writes <page>.html next to it (reading copy; wikilinks become links to sibling .md files)
import sys, re, pathlib, markdown
p = pathlib.Path(sys.argv[1])
t = re.sub(r"^---\n.*?\n---\n", "", p.read_text(), flags=re.S)
title = (re.search(r"^# (.+)$", t, re.M) or [None, p.stem])[1]
t = re.sub(r"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]", lambda m: f"[{m.group(2) or m.group(1)}]({m.group(1)}.md)", t)
css = ("body{font:16px/1.6 -apple-system,system-ui,sans-serif;max-width:860px;margin:2rem auto;padding:0 16px;color:#222;background:#fff}"
       "table{border-collapse:collapse;width:100%;margin:1rem 0}td,th{border:1px solid #ddd;padding:6px 8px;vertical-align:top;text-align:left}"
       "th{background:#f4efe9}a{color:#5C463D}h1,h2,h3{color:#5C463D}code{background:#f4f4f4;padding:1px 4px}")
html = markdown.markdown(t, extensions=["tables"])
p.with_suffix(".html").write_text(f'<!doctype html><html lang="cs"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title><style>{css}</style></head><body>{html}</body></html>')
print(p.with_suffix(".html"))
