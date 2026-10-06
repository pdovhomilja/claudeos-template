#!/usr/bin/env python3
"""Twin <-> owner over one Discord channel. Bot token, no library.
  read              print the owner's messages since the last read (and remember the cursor)
  peek              print only the count of the owner's messages since the last read (cursor untouched)
  post <file.md>    post a markdown file, chunked to Discord's 2000-char limit
  post-text <text>  post one message
Env: DISCORD_BOT_TOKEN, DISCORD_CHANNEL_ID, DISCORD_OWNER_ID
"""
import json, os, sys, urllib.request
from env import RUNS  # loads .env

TOKEN = os.environ["DISCORD_BOT_TOKEN"]
CHANNEL = os.environ["DISCORD_CHANNEL_ID"]
OWNER = os.environ["DISCORD_OWNER_ID"]  # only the owner's messages count as replies
API = f"https://discord.com/api/v10/channels/{CHANNEL}/messages"
CURSOR = os.path.join(RUNS, "discord-last-id")


def call(method, url, body=None):
    req = urllib.request.Request(url, method=method, headers={
        "Authorization": f"Bot {TOKEN}", "Content-Type": "application/json",
        "User-Agent": "ClaudeOSTwin (claudeos, 1.0)"})
    with urllib.request.urlopen(req, json.dumps(body).encode() if body else None) as r:
        return json.load(r)


def fetch_new():
    last = open(CURSOR).read().strip() if os.path.exists(CURSOR) else ""
    url = API + "?limit=50" + (f"&after={last}" if last else "")
    msgs = [m for m in call("GET", url) if m["author"]["id"] == OWNER]
    msgs.sort(key=lambda m: int(m["id"]))
    return msgs


def read():
    msgs = fetch_new()
    for m in msgs:
        print(f"- [{m['timestamp'][:16]}] {m['author']['username']}: {m['content']}")
    if not msgs:
        print("(none)")
    newest = call("GET", API + "?limit=1")
    if newest:
        open(CURSOR, "w").write(newest[0]["id"])


def post_text(text):
    while text:
        chunk, text = text[:1990], text[1990:]
        if text:
            cut = chunk.rfind("\n")
            if cut > 500:
                text, chunk = chunk[cut + 1:] + text, chunk[:cut]
        call("POST", API, {"content": chunk})


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "read":
        read()
    elif cmd == "peek":
        print(len(fetch_new()))
    elif cmd == "post":
        post_text(open(sys.argv[2]).read())
    elif cmd == "post-text":
        post_text(sys.argv[2])
