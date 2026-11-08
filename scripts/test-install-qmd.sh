#!/bin/bash
# Tests scripts/qmd-setup.sh and the installer's qmd step against fake qmd, npm, claude, systemctl, loginctl and
# sudo, which log how they were called. No network, no real models; scripts/test-qmd-real.sh runs the real thing.
# Run: bash scripts/test-install-qmd.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
FAILED=0
ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }
has() { if grep -qF -- "$2" "$3"; then ok "$1"; else bad "$1 (no '$2' in $3)"; sed 's/^/     /' "$3"; fi; }
hasnt() { if grep -qF -- "$2" "$3"; then bad "$1 ('$2' in $3)"; sed 's/^/     /' "$3"; else ok "$1"; fi; }

# Fake tools. Each logs "<tool> <args>" to $CALLS. Fake qmd keeps its collections in a file, like the real one in index.yml.
FAKES="$T/fakes"; mkdir -p "$FAKES"
fake() { printf '#!/bin/bash\necho "%s $*" >> "$CALLS"\n%s\n' "$1" "${2:-}" > "$FAKES/$1"; chmod +x "$FAKES/$1"; }
fake qmd 'case "$1 ${2:-}" in
  "collection show") grep -qx "$3" "$CALLS.collections" 2>/dev/null ;;
  "collection add") shift 2; while [ $# -gt 0 ]; do [ "$1" = --name ] && echo "$2" >> "$CALLS.collections"; shift; done ;;
  "embed "*) [ -z "${FAKE_EMBED_SLOW:-}" ] || sleep 2; [ -z "${FAKE_EMBED_FAILS:-}" ] ;;
esac'
fake npm 'mkdir -p "$HOME/.local/bin"; cp "$FAKES/qmd" "$HOME/.local/bin/qmd"'
fake claude 'case "$1 ${2:-}" in "mcp get") [ -f "$CALLS.mcp" ] ;; "mcp add") : > "$CALLS.mcp" ;; esac'
fake systemctl
fake loginctl 'echo "Linger=${FAKE_LINGER:-no}"'
fake sudo

# A copy of this repo's files in a throwaway home; prints the home. $1 = laptop | server
new_home() {
  local h="$T/home-$1-$RANDOM"
  mkdir -p "$h/claudeos/scripts/vm/systemd" "$h/claudeos/wiki" "$h/claudeos/raw"
  cp "$ROOT/scripts/qmd-setup.sh" "$h/claudeos/scripts/"
  cp "$ROOT/scripts/vm/systemd/qmd.service" "$h/claudeos/scripts/vm/systemd/"
  if [ "$1" = server ]; then mkdir -p "$h/.config/systemd/user"; : > "$h/.config/systemd/user/claudeos-twin.service"; fi
  echo "$h"
}
# Run the setup with the fakes on PATH, all but qmd: that appears in the home once the fake npm "installed" it.
TOOLS="$T/tools"; mkdir -p "$TOOLS"
for f in npm claude systemctl loginctl sudo; do ln -s "$FAKES/$f" "$TOOLS/$f"; done
setup() {   # $1 = home
  local h="$1"
  env -u XDG_CONFIG_HOME HOME="$h" CALLS="$h/calls" FAKES="$FAKES" PATH="$TOOLS:$(dirname "$(command -v node)"):/usr/bin:/bin" \
    FAKE_EMBED_FAILS="${FAKE_EMBED_FAILS:-}" FAKE_EMBED_SLOW="${FAKE_EMBED_SLOW:-}" FAKE_LINGER="${FAKE_LINGER:-no}" bash "$h/claudeos/scripts/qmd-setup.sh" > "$h/out" 2>&1
}
# The first embedding runs in the background: wait until it has written its last line.
wait_bg() { for _ in $(seq 50); do [ -n "$(tail -1 "$1/claudeos/runs/qmd-first-embed.log" 2>/dev/null)" ] && return; sleep 0.1; done; }

echo "# laptop, nothing installed yet"
h=$(new_home laptop)
setup "$h"; rc=$?; wait_bg "$h"
[ "$rc" = 0 ] && ok "setup exits 0" || { bad "setup exits 0 (got $rc)"; cat "$h/out"; }
has "qmd installed into ~/.local without root" "npm install -g --prefix $h/.local --ignore-scripts @tobilu/qmd" "$h/calls"
has "wiki collection points at this copy" "qmd collection add $h/claudeos/wiki --name wiki --mask **/*.md" "$h/calls"
has "raw collection points at this copy" "qmd collection add $h/claudeos/raw --name raw --mask **/*.{md,txt}" "$h/calls"
has "embed model in the config" "embed: hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf" "$h/.config/qmd/index.yml"
hasnt "no path in the config we write" "$h" "$h/.config/qmd/index.yml"
has "keywords work at once: update before returning" "qmd update" "$h/calls"
has "embedding has no 30-minute cap" "qmd embed --timeout 0" "$h/calls"
has "all models fetched in the background" "qmd pull" "$h/calls"
has "background log ends with done" "done" "$h/claudeos/runs/qmd-first-embed.log"
hasnt "no service on a laptop" "systemctl" "$h/calls"
hasnt "no MCP server on a laptop" "claude mcp" "$h/calls"

echo "# running it again"
printf 'collections: rewritten by qmd in its own style\n' >> "$h/.config/qmd/index.yml"
cp "$h/.config/qmd/index.yml" "$T/before.yml"; : > "$h/calls"
setup "$h"; rc=$?; wait_bg "$h"
[ "$rc" = 0 ] && ok "second run exits 0" || bad "second run exits 0 (got $rc)"
hasnt "qmd not installed twice" "npm install" "$h/calls"
hasnt "collections not added twice" "collection add" "$h/calls"
cmp -s "$h/.config/qmd/index.yml" "$T/before.yml" && ok "config qmd rewrote stays as it is" || bad "config qmd rewrote stays as it is"

echo "# running it again while the first embedding is still going (two jobs would download the same model)"
h=$(new_home laptop)
FAKE_EMBED_SLOW=1 setup "$h"; FAKE_EMBED_SLOW=1 setup "$h"; rc=$?; sleep 3; wait_bg "$h"
[ "$rc" = 0 ] && ok "second run exits 0" || bad "second run exits 0 (got $rc)"
[ "$(grep -c 'qmd embed' "$h/calls")" = 1 ] && ok "one background job" || { bad "one background job"; cat "$h/calls"; }
has "its log survives the second run" "done" "$h/claudeos/runs/qmd-first-embed.log"

echo "# an embedding that fails (no network) does not fail the setup"
h=$(new_home laptop)
FAKE_EMBED_FAILS=1 setup "$h"; rc=$?; wait_bg "$h"
[ "$rc" = 0 ] && ok "setup exits 0" || bad "setup exits 0 (got $rc)"
hasnt "log does not claim done" "done" "$h/claudeos/runs/qmd-first-embed.log"

echo "# server"
h=$(new_home server)
setup "$h"; rc=$?; wait_bg "$h"
[ "$rc" = 0 ] && ok "setup exits 0" || { bad "setup exits 0 (got $rc)"; cat "$h/out"; }
[ -f "$h/.config/systemd/user/qmd.service" ] && ok "unit installed" || bad "unit installed"
has "unit enabled and started" "systemctl --user enable --now qmd.service" "$h/calls"
has "linger on, so it survives logout and reboot" "sudo -n loginctl enable-linger $(id -un)" "$h/calls"
has "user MCP server, localhost" "claude mcp add -s user --transport http qmd http://localhost:8181/mcp" "$h/calls"
: > "$h/calls"
FAKE_LINGER=yes setup "$h"; wait_bg "$h"
hasnt "linger not asked for again" "enable-linger" "$h/calls"
hasnt "MCP server not added twice" "claude mcp add" "$h/calls"

echo "# the unit finds node without a login shell (systemd's PATH has no ~/.local/bin)"
has "unit sets PATH" 'Environment=PATH=%h/.local/bin:' "$ROOT/scripts/vm/systemd/qmd.service"
has "unit listens on the port the MCP server is registered with" "--port 8181" "$ROOT/scripts/vm/systemd/qmd.service"

echo "# installer"
sed '$d' "$ROOT/install.sh" > "$T/install-functions.sh"; . "$T/install-functions.sh"; trap - ERR
(
  HOME="$T/inst"; mkdir -p "$HOME"; CALLS="$T/inst-calls"; export HOME CALLS FAKES PATH="$FAKES:$PATH"
  install_qmd
)
has "install_qmd uses the same command as the setup script" "npm install -g --prefix $T/inst/.local --ignore-scripts @tobilu/qmd" "$T/inst-calls"
(
  OS=Linux ARCH=amd64 SERVER=0
  has_node() { :; }; has_git() { :; }; has_plugins() { :; }; has_claude_login() { :; }
  gh() { :; }; claude() { :; }
  preflight
) > "$T/preflight" 2>&1
has "checklist has a qmd row" "qmd" "$T/preflight"

exit $FAILED
