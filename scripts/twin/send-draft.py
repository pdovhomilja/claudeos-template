#!/usr/bin/env python3
"""Send a staged draft from the assistant's mailbox. Only on the owner's approval (tier 1).
Usage: python3 scripts/twin/send-draft.py staging/<draft>.md
Frontmatter: to, cc, subject, in_reply_to (threads it), wait/due (add a waiting-for row),
             attach (comma-separated file paths, ~ allowed), needs_local (work only the main computer can do), status: draft
Refuses a draft with needs_local: set, or one whose text mentions an attachment while attach: is empty (draft_guard.py).
"""
import os, re, subprocess, sys, tempfile, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
path = sys.argv[1]
src = open(path).read()
m = re.match(r"^---\n(.*?)\n---\n(.*)$", src, re.S)
fm = {k: v.strip().strip("\"'") for k, v in re.findall(r"^(\w+):[ \t]*(.*)$", m.group(1), re.M)}
if fm.get("status", "").startswith(("sent", "dropped")):
    sys.exit(f"not sending, status: {fm['status']}")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from draft_guard import blocked
if why := blocked(fm, m.group(2)):
    sys.exit(f"not sending, {why}")

with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as body:
    body.write(m.group(2).strip("\n") + "\n")
cmd = ["python3", os.path.join(ROOT, "scripts/send-mail.py"), "--to", fm["to"], "--subject", fm["subject"], "--body-file", body.name]
for k in ("cc", "in_reply_to", "wait", "due"):
    if fm.get(k): cmd += ["--" + k.replace("_", "-"), fm[k]]
for f in filter(None, (x.strip() for x in fm.get("attach", "").split(","))):
    cmd += ["--attach", os.path.expanduser(f)]
out = subprocess.run(cmd, capture_output=True, text=True)
print(out.stdout + out.stderr, end="")
mid = re.search(r"Message-ID: (\S+)", out.stdout)
if out.returncode or not mid or "refused: {}" not in out.stdout:
    sys.exit("send failed")
status = f"status: sent {time.strftime('%F %H:%M')} (Message-ID {mid.group(1)})"
open(path, "w").write(re.sub(r"^status:.*$", status, src, count=1, flags=re.M))
print("sent", path)
