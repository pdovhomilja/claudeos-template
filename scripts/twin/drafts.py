#!/usr/bin/env python3
"""Drafts for the owner's approval in Discord: one Discord thread per staging draft, full text inside.
  post <file>    open a thread for the draft and post v1 (with ✅ / ❌ ready to tap)
  repost <file>  post the next version of a revised draft into its thread
  check          act on the owner's ✅ (send via send-draft.py), ❌ (drop), `send as: <text>` (send his text);
                 print `revise <file>` for any other new reply, so mail-poll.sh wakes the twin
  pending        print the open change requests (file, then the owner's words)
State: runs/twin/drafts.json. Only the owner's Discord account counts.
"""
import json, os, re, subprocess, sys, time, urllib.parse, urllib.request
from discord import TOKEN, CHANNEL, OWNER, post_text  # scripts/twin/discord.py
from env import ROOT, RUNS

OK, NO = "✅", "❌"
STATE = os.path.join(RUNS, "drafts.json")
API = "https://discord.com/api/v10"


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, headers={
        "Authorization": f"Bot {TOKEN}", "Content-Type": "application/json",
        "User-Agent": "ClaudeOSTwin (claudeos, 1.0)"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, json.dumps(body).encode() if body else None) as r:
                data = r.read()
                return json.loads(data) if data else None
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 4: raise
            time.sleep(float(json.loads(e.read()).get("retry_after", 1)) + 0.1)  # reactions are limited to ~1 per 0.25 s


def say(channel, text):
    return call("POST", f"/channels/{channel}/messages", {"content": text})["id"]


def react(channel, msg, emoji):
    call("PUT", f"/channels/{channel}/messages/{msg}/reactions/{urllib.parse.quote(emoji)}/@me")


def parse(path):
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", open(path).read(), re.S)
    fm = {k: v.strip().strip("\"'") for k, v in re.findall(r"^(\w+):\s*(.*)$", m.group(1), re.M)}
    return fm, m.group(2).strip("\n")


def load():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save(state):
    json.dump(state, open(STATE, "w"), indent=1, ensure_ascii=False)


def post_version(path, d):
    fm, body = parse(path)
    head = (f"**v{d['version']}** · {OK} send · {NO} drop · reply here to change it · "
            f"`send as:` + your full text sends that word for word\n"
            f"**From:** {os.environ.get('MAIL_FROM', '')}\n**To:** {fm['to']}\n"
            + (f"**Cc:** {fm['cc']}\n" if fm.get("cc") else "") + f"**Subject:** {fm['subject']}")
    d["msg"] = say(d["thread"], head)
    for emoji in (OK, NO):
        react(d["thread"], d["msg"], emoji)
    for i in range(0, len(body), 1900):
        d["last"] = say(d["thread"], body[i:i + 1900])


def post(path):
    state = load()
    fm, _ = parse(path)
    start = say(CHANNEL, f"📝 Draft for your approval: **{fm['subject']}** → {fm['to']}")
    thread = call("POST", f"/channels/{CHANNEL}/messages/{start}/threads",
                  {"name": fm["subject"][:95], "auto_archive_duration": 10080})["id"]
    state[path] = d = {"thread": thread, "version": 1, "old": [], "status": "pending", "requests": []}
    post_version(path, d)
    save(state)


def repost(path):
    state = load()
    d = state[path]
    d["old"].append(d["msg"])
    d["version"] += 1
    d["requests"] = []
    post_version(path, d)
    save(state)


def reacted(d, msg, emoji):
    return any(u["id"] == OWNER for u in call("GET", f"/channels/{d['thread']}/messages/{msg}/reactions/{urllib.parse.quote(emoji)}") or [])


def send(path, d, note):
    out = subprocess.run(["python3", os.path.join(ROOT, "scripts/twin/send-draft.py"), path], capture_output=True, text=True)
    if out.returncode:
        say(d["thread"], f"⚠️ Not sent: {(out.stdout + out.stderr).strip()[-1500:]}")
        post_text(f"⚠️ Draft not sent ({path}), see its thread.")
        d["status"] = "failed"  # warn once, not every 2 minutes; the twin's next run sees it in drafts.json
        return
    d["status"] = "sent"
    say(d["thread"], f"Sent ✅ {note}")
    print("sent", path)


def check():
    state = load()
    for path, d in state.items():
        if d["status"] != "pending":
            continue
        if parse(path)[0].get("status", "").startswith(("sent", "dropped")):  # handled another way, e.g. a `send` line
            d["status"] = "closed"
            continue
        if reacted(d, d["msg"], OK):
            send(path, d, f"(v{d['version']})")
        elif reacted(d, d["msg"], NO):
            d["status"] = "dropped"
            src = open(path).read()
            open(path, "w").write(re.sub(r"^status:.*$", f"status: dropped {time.strftime('%F')} (owner, Discord)", src, count=1, flags=re.M))
            say(d["thread"], "Dropped, nothing sent.")
            print("dropped", path)
        else:
            for old in d["old"]:
                if old not in d.get("warned", []) and reacted(d, old, OK):
                    say(d["thread"], f"That {OK} is on an older version; only v{d['version']} can be sent.")
                    d.setdefault("warned", []).append(old)
            msgs = call("GET", f"/channels/{d['thread']}/messages?limit=50&after={d['last']}") or []
            for m in sorted(msgs, key=lambda m: int(m["id"])):
                d["last"] = m["id"]
                if m["author"]["id"] != OWNER or d["status"] != "pending":
                    continue
                text = m["content"].strip()
                if text.lower().startswith("send as:"):
                    src = open(path).read()
                    head = re.match(r"^---\n.*?\n---\n", src, re.S).group(0)
                    open(path, "w").write(head + "\n" + text[8:].strip() + "\n")
                    send(path, d, "(your text, word for word)")
                else:
                    d["requests"].append(text)
                    print("revise", path)
        save(state)


def pending():
    for path, d in load().items():
        if d["status"] == "pending" and d["requests"]:
            print(f"## {path}\n" + "\n".join(f"- {r}" for r in d["requests"]) + "\n")


if __name__ == "__main__":
    cmd = sys.argv[1]
    {"post": lambda: post(sys.argv[2]), "repost": lambda: repost(sys.argv[2]),
     "check": check, "pending": pending}[cmd]()
