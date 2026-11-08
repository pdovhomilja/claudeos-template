#!/bin/bash
# Local search (qmd): installs the qmd command if it is missing, indexes this copy's wiki/ and raw/, and starts the
# first embedding in the background. On a server (the twin's units are installed) also the search server + MCP `qmd`.
# Called by install.sh (laptop) and scripts/vm/bootstrap.sh (server); on an existing copy just run it.
# Safe to run again. The models (about 2.5 GB) download in the background, so a slow line never holds this up;
# keyword search (qmd search) works as soon as this script ends.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
EMBED_MODEL="hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf"   # multilingual; users write in many languages
export PATH="$HOME/.local/bin:$PATH"

node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>24||(a==24&&b>=15)?0:1)' \
  || { echo "qmd needs Node.js 24.15 or newer here. Run the installer again first."; exit 1; }
# --ignore-scripts: no compiler needed. qmd uses no install script's result, and the only one that compiles
# (tree-sitter-javascript, whose linux-arm64 prebuild is really x86-64) is for grammars qmd reads as wasm.
command -v qmd >/dev/null || npm install -g --prefix "$HOME/.local" --ignore-scripts @tobilu/qmd

# Only into a new config: qmd rewrites this file in its own style, and an existing one holds someone's own choice.
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/qmd/index.yml"
if [ ! -f "$CONFIG" ]; then
  mkdir -p "$(dirname "$CONFIG")"
  printf 'models:\n  embed: %s\n' "$EMBED_MODEL" > "$CONFIG"
fi
qmd collection show wiki >/dev/null 2>&1 || qmd collection add "$ROOT/wiki" --name wiki --mask '**/*.md' >/dev/null
qmd collection show raw >/dev/null 2>&1 || qmd collection add "$ROOT/raw" --name raw --mask '**/*.{md,txt}' >/dev/null
qmd update >/dev/null

# Embedding first, so vector search can start; then the query models (vsearch would otherwise fetch them in the foreground).
# Only one embed runs at a time (qmd's own lock), and every session start carries on from wherever this one stopped.
mkdir -p "$ROOT/runs"
if ! kill -0 "$(cat "$ROOT/runs/qmd-first-embed.pid" 2>/dev/null)" 2>/dev/null; then   # a second job would download the same model and break the first
  nohup sh -c 'if nice -n 10 qmd embed --timeout 0 && nice -n 10 qmd pull; then echo done; else echo "stopped: the next qmd embed carries on"; fi' \
    > "$ROOT/runs/qmd-first-embed.log" 2>&1 < /dev/null &
  echo $! > "$ROOT/runs/qmd-first-embed.pid"
fi

if [ -f "$HOME/.config/systemd/user/claudeos-twin.service" ]; then
  cp "$ROOT/scripts/vm/systemd/qmd.service" "$HOME/.config/systemd/user/"
  loginctl show-user "$(id -un)" -p Linger 2>/dev/null | grep -q yes || sudo -n loginctl enable-linger "$(id -un)" \
    || echo "Could not turn on linger: run  sudo loginctl enable-linger $(id -un)  or search stops at logout."
  systemctl --user daemon-reload
  systemctl --user enable --now qmd.service
  claude mcp get qmd >/dev/null 2>&1 || claude mcp add -s user --transport http qmd http://localhost:8181/mcp >/dev/null
fi
echo "Search is set up. Keywords work now; the models download in the background (log: runs/qmd-first-embed.log)."
