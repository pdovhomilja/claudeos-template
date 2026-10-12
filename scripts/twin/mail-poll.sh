#!/bin/bash
# Quick check every 2 min (08–23, systemd timer claudeos-mail). Sends drafts the owner approved with ✅
# (scripts/twin/drafts.py) and wakes Claude (run.sh mail) only when there is something to do: new mail that
# replies to the assistant's mail or comes from the owner or a watched sender, any new mail in a mailbox listed
# in scripts/twin/mailboxes.txt, a message from the owner in
# Discord, or a change request on a draft. Other new mail waits for the next day run.
# Usage: mail-poll.sh [list]
set -uo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
cd "$(dirname "$0")/../.." || exit 1
RUNS="$PWD/runs/twin"; mkdir -p "$RUNS"

if [ "${1:-}" = "list" ]; then python3 scripts/twin/mailbox.py list; exit 0; fi

DRAFTS=$(python3 scripts/twin/drafts.py check 2>>"$RUNS/drafts.err" | grep '^revise' || true)
UIDS=""
if grep -q '^MAIL_SERVER=.' .env 2>/dev/null; then
  NEW=$(python3 scripts/twin/mailbox.py new 2>>"$RUNS/mailbox.err" || true)
  UIDS=$(echo $NEW | xargs -r python3 scripts/twin/mailbox.py wake 2>>"$RUNS/mailbox.err" || true)
fi
# Watched mailboxes (scripts/twin/mailboxes.txt): every new mail wakes Claude, id box:<prefix>:<uid>.
BOXU=$(grep -v '^#' scripts/twin/mailboxes.txt 2>/dev/null | awk 'NF{print $1}' | while read -r b; do
  python3 scripts/twin/mailbox.py new --box "$b" 2>>"$RUNS/mailbox.err" | sed "s/^/box:$b:/"
done || true)
UIDS=$(printf '%s\n%s\n' "$UIDS" "$BOXU" | grep . || true)
REPLIES=$(python3 scripts/twin/discord.py peek 2>/dev/null || echo 0)
if [ -z "$UIDS" ] && [ "$REPLIES" = "0" ] && [ -z "$DRAFTS" ]; then exit 0; fi

echo "$(date '+%F %H:%M') mail-poll: mail=$(echo "$UIDS" | grep -c .) replies=$REPLIES drafts=$(echo "$DRAFTS" | grep -c .)" >> "$RUNS/mail-poll.log"
bash scripts/twin/run.sh mail "$(echo $UIDS)"
