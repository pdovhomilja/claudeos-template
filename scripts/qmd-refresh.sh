#!/bin/bash
# Search index refresh: keywords now, then in the background (nice, one job at a time) any model still missing and
# vectors for what changed. Every session start runs this, so a first download that was interrupted carries on by itself.
# Log: runs/qmd-embed.log. A second job would download the same model and break the first, hence the pid file.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PATH="$HOME/.local/bin:$PATH"

if [ "${1:-}" = --job ]; then
  MODELS="${XDG_CACHE_HOME:-$HOME/.cache}/qmd/models"
  EMBED=$(sed -n 's|^ *embed: *hf:.*/\(.*\)\.gguf.*|\1|p' "${XDG_CONFIG_HOME:-$HOME/.config}/qmd/index.yml" 2>/dev/null | head -1)
  EMBED=${EMBED:-embeddinggemma}   # qmd's default when the config names none
  has_model() { ls "$MODELS"/*"$1"*.gguf >/dev/null 2>&1; }   # a partial download ends in .ipull
  all_models() { has_model "$EMBED" && has_model query-expansion && has_model reranker; }

  # qmd pull deletes every model it cannot confirm with huggingface.co and then waits for the line, with no limit. So only
  # when a model is missing and the site answers. Pull comes first: a model `qmd embed` fetched has no .etag, which pull
  # takes as outdated and downloads again. The limit (6 h, 2.4 GB on a line near 1 Mbit/s) kills the group: bin/qmd is a
  # wrapper that does not pass signals on to the process doing the work.
  if ! all_models && curl -fsI -m 10 https://huggingface.co >/dev/null 2>&1; then
    node -e '
      const c = require("child_process").spawn("nice", ["-n", "10", "qmd", "pull"], { stdio: "inherit", detached: true });
      const t = setTimeout(() => process.kill(-c.pid, "SIGKILL"), process.argv[1] * 1000);
      c.on("exit", (code) => { clearTimeout(t); process.exit(code === 0 ? 0 : 1); });
    ' "${QMD_PULL_SECONDS:-21600}" || true
  fi
  embedded=""
  if has_model "$EMBED"; then   # without it qmd embed would wait for the same line, and it has no limit (a big wiki takes hours)
    nice -n 10 qmd embed --timeout 0 && embedded=1
  fi
  if [ -n "$embedded" ] && all_models; then echo "done"; else echo "stopped: the next refresh carries on"; fi
  exit 0
fi

command -v qmd >/dev/null || { echo "qmd is not installed. Run: bash scripts/qmd-setup.sh"; exit 1; }
qmd update >/dev/null
mkdir -p "$ROOT/runs"
if ! kill -0 "$(cat "$ROOT/runs/qmd-embed.pid" 2>/dev/null)" 2>/dev/null; then
  nohup bash "$ROOT/scripts/qmd-refresh.sh" --job > "$ROOT/runs/qmd-embed.log" 2>&1 < /dev/null &
  echo $! > "$ROOT/runs/qmd-embed.pid"
fi
