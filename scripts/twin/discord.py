#!/usr/bin/env python3
"""Twin <-> owner over one Discord channel. Bot token, no library.
  read              print the owner's messages since the last read (and remember the cursor)
  peek              print only the count of the owner's messages since the last read (cursor untouched)
  post <file.md>    post a markdown file, chunked to Discord's 2000-char limit
  post-text <text>  post one message
  chan-read <ENV>   print messages that @mention the bot (not its own) in the channel whose id is in env var <ENV>
                    (a watched channel from scripts/twin/discord-channels.txt) since the last chan-read;
                    those ending in [done] are marked CLOSING (read, never answer). Read by scripts/twin/discord-watch.sh
  chan-peek <ENV>   print only their count (cursor untouched)
  chan-post <ENV> <text>  post there; refused after CHANNEL_DAILY_LIMIT posts a day (bot-to-bot loop guard)
Env: DISCORD_BOT_TOKEN, DISCORD_CHANNEL_ID, DISCORD_OWNER_ID, plus each watched channel's env var
"""
import datetime, json, os, sys, urllib.request
from env import RUNS  # loads .env

TOKEN = os.environ["DISCORD_BOT_TOKEN"]
CHANNEL = os.environ["DISCORD_CHANNEL_ID"]
OWNER = os.environ["DISCORD_OWNER_ID"]  # only the owner's messages count as replies
API = f"https://discord.com/api/v10/channels/{CHANNEL}/messages"
CURSOR = os.path.join(RUNS, "discord-last-id")
CHANNEL_DAILY_LIMIT = 30


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


def post_text(text, channel=CHANNEL):
    while text:
        chunk, text = text[:1990], text[1990:]
        if text:
            cut = chunk.rfind("\n")
            if cut > 500:
                text, chunk = chunk[cut + 1:] + text, chunk[:cut]
        call("POST", f"https://discord.com/api/v10/channels/{channel}/messages", {"content": chunk})


def chan_new(env):
    me = call("GET", "https://discord.com/api/v10/users/@me")["id"]
    cursor = os.path.join(RUNS, f"discord-{env}-last-id")
    last = open(cursor).read().strip() if os.path.exists(cursor) else ""
    url = f"https://discord.com/api/v10/channels/{os.environ[env]}/messages?limit=50" + (f"&after={last}" if last else "")
    raw = call("GET", url)
    msgs = [m for m in raw if m["author"]["id"] != me and any(u["id"] == me for u in m.get("mentions", []))]
    msgs.sort(key=lambda m: int(m["id"]))
    return msgs, raw


def closing(m):  # a message ending in [done] closes the exchange: read it, never answer it
    return m["content"].rstrip().endswith("[done]")


def chan_read(env):
    msgs, raw = chan_new(env)
    for m in msgs:
        bot = " (bot)" if m["author"].get("bot") else ""
        done = " [CLOSING: read, never answer]" if closing(m) else ""
        print(f"- [{m['timestamp'][:16]}] {m['author']['username']}{bot} <@{m['author']['id']}>{done}: {m['content']}")
    if not msgs:
        print("(none)")
    else:
        print(f"(open: {sum(not closing(m) for m in msgs)})")  # discord-watch.sh: 0 = read-only run
    if raw:  # cursor = newest message fetched, so nothing posted meanwhile is skipped
        open(os.path.join(RUNS, f"discord-{env}-last-id"), "w").write(max(raw, key=lambda m: int(m["id"]))["id"])


def chan_post(env, text):
    log = os.path.join(RUNS, f"discord-{env}-posts-{datetime.date.today()}.txt")
    n = len(open(log).readlines()) if os.path.exists(log) else 0
    if n >= CHANNEL_DAILY_LIMIT:
        sys.exit(f"refused: {n} posts in {env} today (limit {CHANNEL_DAILY_LIMIT})")
    post_text(text, os.environ[env])
    open(log, "a").write(datetime.datetime.now().isoformat(timespec="minutes") + "\n")


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
    elif cmd == "chan-read":
        chan_read(sys.argv[2])
    elif cmd == "chan-peek":
        print(len(chan_new(sys.argv[2])[0]))
    elif cmd == "chan-post":
        chan_post(sys.argv[2], sys.argv[3])
