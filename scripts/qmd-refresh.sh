#!/bin/bash
# Search index refresh: keywords now, then in the background (nice, one job at a time) vectors for what changed and any
# model still missing. Every session start runs this, so a first download that was interrupted carries on by itself.
# Log: runs/qmd-embed.log. A second job would download the same model and break the first, hence the pid file.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PATH="$HOME/.local/bin:$PATH"

command -v qmd >/dev/null || { echo "qmd is not installed. Run: bash scripts/qmd-setup.sh"; exit 1; }
qmd update >/dev/null
mkdir -p "$ROOT/runs"
if ! kill -0 "$(cat "$ROOT/runs/qmd-embed.pid" 2>/dev/null)" 2>/dev/null; then
  nohup sh -c 'if nice -n 10 qmd embed --timeout 0 && nice -n 10 qmd pull; then echo done; else echo "stopped: the next refresh carries on"; fi' \
    > "$ROOT/runs/qmd-embed.log" 2>&1 < /dev/null &
  echo $! > "$ROOT/runs/qmd-embed.pid"
fi
