#!/bin/bash
# Twin — one unattended run on the server. Called by the systemd timers (claudeos-twin 07:30 and 13:00) or by hand.
# Usage: bash scripts/twin/run.sh [night|midday|mail "<uids>"]
#   mail mode is started by mail-poll.sh with the uids of new mail that must be handled now.
set -uo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
cd "$(dirname "$0")/../.." || exit 1

HOUR=$(date +%H)
MODE="${1:-$([ "$HOUR" -lt 10 ] && echo night || echo midday)}"
MAIL_IDS="${2:-}"
RUNS="$PWD/runs/twin"; mkdir -p "$RUNS"
STAMP="$(date +%F-%H%M)"
LOG="$RUNS/$STAMP-$MODE.log"
PROMPT_FILE=scripts/twin/prompt.md
[ "$MODE" = mail ] && PROMPT_FILE=scripts/twin/prompt-mail.md

# .env may hold bare notes; export only KEY=value lines (quotes stripped)
eval "$(python3 -c '
import re, shlex
for l in open(".env"):
    m = re.match(r"^([A-Za-z_]\w*)=(.*)$", l.rstrip("\n"))
    if m: print("export %s=%s" % (m.group(1), shlex.quote(m.group(2).strip().strip("\"").strip("\x27"))))
')"

# Commit leftovers first, so the pull never needs an autostash.
git add -A wiki raw staging >/dev/null 2>&1; git commit -qm "twin: leftovers before $MODE run $STAMP" >/dev/null 2>&1 || true
git pull --rebase -q origin main >> "$LOG" 2>&1

# Briefs live in month folders (wiki/twin/YYYY-MM/). Set below the pull, so edits never shift the bytes bash already read.
BRIEF=""; IMPROVE=""
[ "$MODE" != mail ] && BRIEF="wiki/twin/$(date +%Y-%m)/$(date +%F)-$MODE.md" && mkdir -p "$(dirname "$BRIEF")"
[ "$MODE" = night ] && IMPROVE="wiki/twin/$(date +%Y-%m)/$(date +%F)-improve.md"

REPLIES="$(python3 scripts/twin/discord.py read 2>>"$LOG" || echo "(discord unavailable)")"

PROMPT="$(cat "$PROMPT_FILE")

## This run
- Mode: $MODE
- Date: $(date '+%Y-%m-%d %H:%M %Z')
- Write the brief to: ${BRIEF:-(no brief in mail mode)}
- Improvement brief: ${IMPROVE:-(night run only)}
- New mail uids: ${MAIL_IDS:-(none)}

## The owner's replies in Discord since the last run
$REPLIES"

# MCP servers added with `claude mcp add -s user` load automatically; add their tools to --allowedTools.
claude -p "$PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(git add:*),Bash(git commit:*),Bash(ls:*),Bash(cat:*),Bash(head:*),Bash(tail:*),Bash(wc:*),Bash(find:*),Bash(grep:*),Bash(date:*),Bash(python3 scripts/twin/send-draft.py:*),Bash(python3 scripts/twin/drafts.py post:*),Bash(python3 scripts/twin/drafts.py repost:*),Bash(python3 scripts/twin/drafts.py pending),Bash(python3 scripts/twin/mailbox.py list),Bash(python3 scripts/twin/mailbox.py read:*),Bash(python3 scripts/twin/discord.py post-text:*)" \
  --disallowedTools "Bash(git push:*),Bash(python3 scripts/send-mail.py:*)" \
  --model claude-opus-5-5 \
  --max-turns 200 \
  >> "$LOG" 2>&1
echo "claude exit: $?" >> "$LOG"

# run.sh pushes, not Claude (the prompt says so).
git add -A wiki raw staging >/dev/null 2>&1
git commit -qm "twin: $MODE run $STAMP" >/dev/null 2>&1 || true
git pull --rebase -q origin main >> "$LOG" 2>&1
git push -q origin main >> "$LOG" 2>&1 || echo "push failed" >> "$LOG"

if [ "$MODE" = mail ]; then
  :   # mail mode posts its own line to Discord (or nothing)
elif [ -f "$BRIEF" ]; then
  python3 scripts/twin/discord.py post "$BRIEF" >> "$LOG" 2>&1
else
  python3 scripts/twin/discord.py post-text "Twin $MODE run $STAMP finished without a brief. Log: $LOG" >> "$LOG" 2>&1
fi
# Claude login (/login) runs out ~28 days after login and refreshing does not extend it; warn 5 days ahead.
LOGIN_DAYS=$(python3 -c 'import json,os,time; o=json.load(open(os.path.expanduser("~/.claude/.credentials.json")))["claudeAiOauth"]; print(int((o["refreshTokenExpiresAt"]/1000-time.time())//86400))' 2>/dev/null)
[ "$MODE" = night ] && [ -n "$LOGIN_DAYS" ] && [ "$LOGIN_DAYS" -lt 5 ] && python3 scripts/twin/discord.py post-text \
  "Claude login on the server ($(hostname)) runs out in $LOGIN_DAYS days. In a terminal: ssh into it, run claude, then /login." >> "$LOG" 2>&1
[ -n "$IMPROVE" ] && [ -f "$IMPROVE" ] && python3 scripts/twin/discord.py post "$IMPROVE" >> "$LOG" 2>&1
exit 0
