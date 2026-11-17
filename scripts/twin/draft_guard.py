"""Why a staged draft must not go out yet, or None.
Used by send-draft.py (refuses) and drafts.py (posts ⛔ instead of ✅)."""
import re

ATTACH_WORDS = re.compile(r"v\s+příloze|přikládám|přiložen|posílám\s+(?:tabulk|soubor)|attached|attachment|enclosed", re.I)


def blocked(fm, body):
    if fm.get("needs_local"):
        return f"needs the main computer: {fm['needs_local']}"
    if not fm.get("attach") and ATTACH_WORDS.search(body):
        return "text mentions an attachment but attach: is empty"
    return None
