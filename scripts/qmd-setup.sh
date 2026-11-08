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

# A new config gets everything. An existing one keeps its model and paths: qmd rewrites that file in its own style, it
# may hold someone's own choice, and `qmd collection add` is the only safe way in (it cannot ignore, so twin/ stays in there).
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/qmd/index.yml"
if [ ! -f "$CONFIG" ]; then
  mkdir -p "$(dirname "$CONFIG")"
  cat > "$CONFIG" <<YAML
models:
  embed: $EMBED_MODEL
collections:
  wiki:
    path: "$ROOT/wiki"
    pattern: "**/*.md"
    ignore:
      - "twin/**"
  raw:
    path: "$ROOT/raw"
    pattern: "**/*.{md,txt}"
YAML
fi
qmd collection show wiki >/dev/null 2>&1 || qmd collection add "$ROOT/wiki" --name wiki --mask '**/*.md' >/dev/null
qmd collection show raw >/dev/null 2>&1 || qmd collection add "$ROOT/raw" --name raw --mask '**/*.{md,txt}' >/dev/null
bash "$ROOT/scripts/qmd-refresh.sh"

if [ -f "$HOME/.config/systemd/user/claudeos-twin.service" ]; then
  # Written with the qmd and node this machine really has (nvm, another prefix); a user service's PATH has neither.
  sed -e "s|^ExecStart=[^ ]*|ExecStart=$(command -v qmd)|" \
      -e "s|^Environment=PATH=.*|Environment=PATH=$(dirname "$(command -v node)"):$(dirname "$(command -v qmd)"):/usr/local/bin:/usr/bin:/bin|" \
      "$ROOT/scripts/vm/systemd/qmd.service" > "$HOME/.config/systemd/user/qmd.service"
  loginctl show-user "$(id -un)" -p Linger 2>/dev/null | grep -q yes || sudo -n loginctl enable-linger "$(id -un)" \
    || echo "Could not turn on linger: run  sudo loginctl enable-linger $(id -un)  or search stops at logout."
  for _ in $(seq 20); do systemctl --user show-environment >/dev/null 2>&1 && break; sleep 1; done   # linger starts the user's systemd a moment later
  systemctl --user daemon-reload
  systemctl --user enable qmd.service
  systemctl --user restart qmd.service
  claude mcp get qmd >/dev/null 2>&1 || claude mcp add -s user --transport http qmd http://localhost:8181/mcp >/dev/null
  up=""
  for _ in $(seq "${QMD_HEALTH_TRIES:-30}"); do curl -fsS -m 2 http://localhost:8181/health >/dev/null 2>&1 && { up=1; break; }; sleep 1; done
  if [ -z "$up" ]; then   # enable and restart succeed even when the service crash-loops
    echo "qmd.service did not start. Its log:"
    journalctl --user -u qmd.service -n 10 --no-pager || true
    exit 1
  fi
fi
echo "Search is set up. Keywords work now; the models download in the background (log: runs/qmd-embed.log)."
