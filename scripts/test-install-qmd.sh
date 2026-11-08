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
  "collection show") grep -q "^  $3:" "$HOME/.config/qmd/index.yml" 2>/dev/null || grep -qx "$3" "$CALLS.collections" 2>/dev/null ;;
  "collection add") shift 2; while [ $# -gt 0 ]; do [ "$1" = --name ] && echo "$2" >> "$CALLS.collections"; shift; done ;;
  "embed "*) [ -z "${FAKE_EMBED_SLOW:-}" ] || sleep 2; [ -z "${FAKE_EMBED_FAILS:-}" ] ;;
esac'
fake npm '[ -z "${FAKE_NPM_FAILS:-}" ] || exit 1; mkdir -p "$HOME/.local/bin"; cp "$FAKES/qmd" "$HOME/.local/bin/qmd"'
fake claude 'case "$1 ${2:-}" in "mcp get") [ -f "$CALLS.mcp" ] ;; "mcp add") : > "$CALLS.mcp" ;; esac'
fake systemctl
fake loginctl 'echo "Linger=${FAKE_LINGER:-no}"'
fake sudo
fake curl '[ -z "${FAKE_SERVER_DOWN:-}" ]'
fake journalctl 'echo "the last lines of the service log"'

# A copy of this repo's files in a throwaway home; prints the home. $1 = laptop | server
new_home() {
  local h="$T/home-$1-$RANDOM"
  mkdir -p "$h/claudeos/scripts/vm/systemd" "$h/claudeos/wiki" "$h/claudeos/raw"
  cp "$ROOT/scripts/qmd-setup.sh" "$ROOT/scripts/qmd-refresh.sh" "$h/claudeos/scripts/"
  cp "$ROOT/scripts/vm/systemd/qmd.service" "$h/claudeos/scripts/vm/systemd/"
  if [ "$1" = server ]; then mkdir -p "$h/.config/systemd/user"; : > "$h/.config/systemd/user/claudeos-twin.service"; fi
  echo "$h"
}
# Run the setup with the fakes on PATH, all but qmd: that appears in the home once the fake npm "installed" it.
TOOLS="$T/tools"; mkdir -p "$TOOLS"
for f in npm claude systemctl loginctl sudo curl journalctl; do ln -s "$FAKES/$f" "$TOOLS/$f"; done
setup() {   # $1 = home
  local h="$1"
  env -u XDG_CONFIG_HOME HOME="$h" CALLS="$h/calls" FAKES="$FAKES" PATH="$TOOLS:$(dirname "$(command -v node)"):/usr/bin:/bin" \
    FAKE_EMBED_FAILS="${FAKE_EMBED_FAILS:-}" FAKE_EMBED_SLOW="${FAKE_EMBED_SLOW:-}" FAKE_LINGER="${FAKE_LINGER:-no}" \
    FAKE_SERVER_DOWN="${FAKE_SERVER_DOWN:-}" FAKE_NPM_FAILS="${FAKE_NPM_FAILS:-}" QMD_HEALTH_TRIES=2 \
    bash "$h/claudeos/scripts/${SCRIPT:-qmd-setup.sh}" > "$h/out" 2>&1
}
# The first embedding runs in the background: wait until it has written its last line.
wait_bg() { for _ in $(seq 50); do [ -n "$(tail -1 "$1/claudeos/runs/qmd-embed.log" 2>/dev/null)" ] && return; sleep 0.1; done; }

echo "# laptop, nothing installed yet"
h=$(new_home laptop)
setup "$h"; rc=$?; wait_bg "$h"
[ "$rc" = 0 ] && ok "setup exits 0" || { bad "setup exits 0 (got $rc)"; cat "$h/out"; }
has "qmd installed into ~/.local without root" "npm install -g --prefix $h/.local --ignore-scripts @tobilu/qmd" "$h/calls"
has "wiki collection points at this copy" "path: \"$h/claudeos/wiki\"" "$h/.config/qmd/index.yml"
has "wiki collection takes markdown" 'pattern: "**/*.md"' "$h/.config/qmd/index.yml"
has "twin briefs stay out of the index" '- "twin/**"' "$h/.config/qmd/index.yml"
has "raw collection points at this copy" "path: \"$h/claudeos/raw\"" "$h/.config/qmd/index.yml"
has "raw collection takes markdown and text" 'pattern: "**/*.{md,txt}"' "$h/.config/qmd/index.yml"
has "embed model in the config" "embed: hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf" "$h/.config/qmd/index.yml"
has "keywords work at once: update before returning" "qmd update" "$h/calls"
has "embedding has no 30-minute cap" "qmd embed --timeout 0" "$h/calls"
has "all models fetched in the background" "qmd pull" "$h/calls"
has "background log ends with done" "done" "$h/claudeos/runs/qmd-embed.log"
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

echo "# a config that is already there keeps its model; only what is missing is added"
h=$(new_home laptop); mkdir -p "$h/.config/qmd"; printf 'models:\n  embed: my-own-model\n' > "$h/.config/qmd/index.yml"
setup "$h"; wait_bg "$h"
has "wiki added with qmd's own command" "qmd collection add $h/claudeos/wiki --name wiki --mask **/*.md" "$h/calls"
has "raw added with qmd's own command" "qmd collection add $h/claudeos/raw --name raw --mask **/*.{md,txt}" "$h/calls"
has "own model stays" "my-own-model" "$h/.config/qmd/index.yml"
hasnt "our model not forced on it" "Qwen3" "$h/.config/qmd/index.yml"

echo "# the first job was interrupted: the next session's refresh recovers it, no setup by hand"
h=$(new_home laptop)
FAKE_EMBED_FAILS=1 setup "$h"; wait_bg "$h"
hasnt "first job did not reach the models" "qmd pull" "$h/calls"
: > "$h/calls"
SCRIPT=qmd-refresh.sh setup "$h"; rc=$?; wait_bg "$h"
[ "$rc" = 0 ] && ok "refresh exits 0" || bad "refresh exits 0 (got $rc)"
has "refresh updates the keywords" "qmd update" "$h/calls"
has "refresh carries on embedding" "qmd embed" "$h/calls"
has "refresh fetches the query models that are missing" "qmd pull" "$h/calls"
h2=$(new_home laptop)
SCRIPT=qmd-refresh.sh setup "$h2"; rc=$?
[ "$rc" != 0 ] && ok "refresh without qmd says so" || bad "refresh without qmd says so"
has "and how to fix it" "qmd-setup.sh" "$h2/out"

echo "# running it again while the first embedding is still going (two jobs would download the same model)"
h=$(new_home laptop)
FAKE_EMBED_SLOW=1 setup "$h"; FAKE_EMBED_SLOW=1 setup "$h"; rc=$?; sleep 3; wait_bg "$h"
[ "$rc" = 0 ] && ok "second run exits 0" || bad "second run exits 0 (got $rc)"
[ "$(grep -c 'qmd embed' "$h/calls")" = 1 ] && ok "one background job" || { bad "one background job"; cat "$h/calls"; }
has "its log survives the second run" "done" "$h/claudeos/runs/qmd-embed.log"

echo "# an embedding that fails (no network) does not fail the setup"
h=$(new_home laptop)
FAKE_EMBED_FAILS=1 setup "$h"; rc=$?; wait_bg "$h"
[ "$rc" = 0 ] && ok "setup exits 0" || bad "setup exits 0 (got $rc)"
hasnt "log does not claim done" "done" "$h/claudeos/runs/qmd-embed.log"

echo "# server"
h=$(new_home server)
setup "$h"; rc=$?; wait_bg "$h"
[ "$rc" = 0 ] && ok "setup exits 0" || { bad "setup exits 0 (got $rc)"; cat "$h/out"; }
[ -f "$h/.config/systemd/user/qmd.service" ] && ok "unit installed" || bad "unit installed"
has "unit enabled" "systemctl --user enable qmd.service" "$h/calls"
has "unit restarted, so a changed unit takes effect" "systemctl --user restart qmd.service" "$h/calls"
has "says it is set up" "Search is set up" "$h/out"
has "linger on, so it survives logout and reboot" "sudo -n loginctl enable-linger $(id -un)" "$h/calls"
has "user MCP server, localhost" "claude mcp add -s user --transport http qmd http://localhost:8181/mcp" "$h/calls"
: > "$h/calls"
FAKE_LINGER=yes setup "$h"; wait_bg "$h"
hasnt "linger not asked for again" "enable-linger" "$h/calls"
hasnt "MCP server not added twice" "claude mcp add" "$h/calls"

echo "# Claude Code's MCP setting in ~/.claude/settings.json (server only)"
same() { if cmp -s "$2" "$3"; then ok "$1"; else bad "$1"; diff "$2" "$3" | sed 's/^/     /'; fi; }
# $1 = what the settings file holds before the run. Prints the home; the run's exit code goes to $h/rc.
with_settings() {
  local h; h=$(new_home "$2"); mkdir -p "$h/.claude"; printf '%s' "$1" > "$h/.claude/settings.json"; cp "$h/.claude/settings.json" "$h/before.json"
  setup "$h"; echo $? > "$h/rc"; wait_bg "$h"; echo "$h"
}
h=$(new_home server)
setup "$h"; rc=$?; wait_bg "$h"
printf '{\n  "env": {\n    "MCP_PROTOCOL_NEGOTIATION": "legacy"\n  }\n}\n' > "$T/want.json"
same "no settings file: created with the setting" "$T/want.json" "$h/.claude/settings.json"
setup "$h"; wait_bg "$h"
same "run again: file identical" "$T/want.json" "$h/.claude/settings.json"

h=$(with_settings '{"model":"opus","env":{"FOO":"bar"},"permissions":{"allow":["Bash(ls:*)"]}}' server)
cat > "$T/want.json" <<'JSON'
{
  "model": "opus",
  "env": {
    "FOO": "bar",
    "MCP_PROTOCOL_NEGOTIATION": "legacy"
  },
  "permissions": {
    "allow": [
      "Bash(ls:*)"
    ]
  }
}
JSON
same "other keys kept, setting added" "$T/want.json" "$h/.claude/settings.json"

h=$(with_settings '{"model":"opus"}' server)
printf '{\n  "model": "opus",\n  "env": {\n    "MCP_PROTOCOL_NEGOTIATION": "legacy"\n  }\n}\n' > "$T/want.json"
same "no env yet: env added" "$T/want.json" "$h/.claude/settings.json"

h=$(with_settings '{"env":{"MCP_PROTOCOL_NEGOTIATION":"legacy"},   "x":1}' server)
same "already there: not even reformatted" "$h/before.json" "$h/.claude/settings.json"

h=$(with_settings '{"env":{"MCP_PROTOCOL_NEGOTIATION":"auto"}}' server)
same "the owner's own value stays" "$h/before.json" "$h/.claude/settings.json"

for broken in '{"model": "opus",' '[]' '{"env":"not an object"}'; do
  h=$(with_settings "$broken" server)
  same "not usable ($broken): left as it is" "$h/before.json" "$h/.claude/settings.json"
  [ "$(cat "$h/rc")" = 0 ] && ok "not usable ($broken): setup exits 0" || { bad "not usable ($broken): setup exits 0"; cat "$h/out"; }
  has "not usable ($broken): setup carried on" "Search is set up" "$h/out"
  [ "$(grep -c 'settings.json' "$h/out")" = 1 ] && ok "not usable ($broken): one line says what to do" || { bad "not usable ($broken): one line says what to do"; cat "$h/out"; }
done

h=$(new_home laptop)
setup "$h"; wait_bg "$h"
[ ! -e "$h/.claude/settings.json" ] && ok "laptop: no settings file created" || bad "laptop: no settings file created"
h=$(with_settings '{"model":"opus"}' laptop)
same "laptop: settings file untouched" "$h/before.json" "$h/.claude/settings.json"

echo "# a server whose service does not come up"
h=$(new_home server)
FAKE_SERVER_DOWN=1 setup "$h"; rc=$?; wait_bg "$h"
[ "$rc" != 0 ] && ok "setup fails" || bad "setup fails"
hasnt "does not claim success" "Search is set up" "$h/out"
has "says what is wrong" "qmd.service did not start" "$h/out"
has "shows the service log" "the last lines of the service log" "$h/out"

echo "# the unit finds node and qmd wherever they are (nvm, another prefix); a user service's PATH has neither"
h=$(new_home server); mkdir -p "$h/nvm/bin" "$h/.local/bin"
printf '#!/bin/bash\nexit 0\n' > "$h/nvm/bin/node"; cp "$FAKES/qmd" "$h/nvm/bin/qmd"; chmod +x "$h/nvm/bin/node"
env -u XDG_CONFIG_HOME HOME="$h" CALLS="$h/calls" FAKES="$FAKES" QMD_HEALTH_TRIES=2 PATH="$h/nvm/bin:$TOOLS:/usr/bin:/bin" bash "$h/claudeos/scripts/qmd-setup.sh" > "$h/out" 2>&1; wait_bg "$h"
U="$h/.config/systemd/user/qmd.service"
has "unit runs that qmd" "ExecStart=$h/nvm/bin/qmd mcp --http --port 8181" "$U"
has "unit's PATH has that node" "Environment=PATH=$h/nvm/bin:" "$U"
has "unit in the repo works by itself" 'Environment=PATH=%h/.local/bin:' "$ROOT/scripts/vm/systemd/qmd.service"
has "unit listens on the port the MCP server is registered with" "--port 8181" "$ROOT/scripts/vm/systemd/qmd.service"

echo "# installer"
sed '$d' "$ROOT/install.sh" > "$T/install-functions.sh"; . "$T/install-functions.sh"; trap - ERR
(
  HOME="$T/inst"; mkdir -p "$HOME"; CALLS="$T/inst-calls"; export HOME CALLS FAKES PATH="$FAKES:$PATH"
  install_qmd
)
(
  HOME="$T/inst2"; mkdir -p "$HOME"; CALLS="$T/inst2-calls"; FAKE_NPM_FAILS=1; export HOME CALLS FAKES FAKE_NPM_FAILS PATH="$FAKES:$PATH"
  set -Eeuo pipefail; trap 'echo STOPPED' ERR
  install_qmd
  echo "installer goes on"
) > "$T/inst2-out" 2>&1
has "a failed qmd install does not stop the installer" "installer goes on" "$T/inst2-out"
hasnt "no stop" "STOPPED" "$T/inst2-out"
has "it warns" "qmd did not install" "$T/inst2-out"
has "and says how to recover" "qmd-setup.sh" "$T/inst2-out"
h=$(new_home laptop)
FAKE_NPM_FAILS=1 setup "$h"; first=$?
setup "$h"; second=$?; wait_bg "$h"
[ "$first" != 0 ] && [ "$second" = 0 ] && ok "qmd-setup.sh recovers after a failed install" || bad "qmd-setup.sh recovers after a failed install ($first, $second)"
has "install_qmd uses the same command as the setup script" "npm install -g --prefix $T/inst/.local --ignore-scripts @tobilu/qmd" "$T/inst-calls"
(
  OS=Linux ARCH=amd64 SERVER=0
  has_node() { :; }; has_git() { :; }; has_plugins() { :; }; has_claude_login() { :; }
  gh() { :; }; claude() { :; }
  preflight
) > "$T/preflight" 2>&1
has "checklist has a qmd row" "qmd" "$T/preflight"

echo "# twin: search missing or down shows up in Discord, not only in a log"
twin() {   # $1 = home, night or midday in $2
  local h="$1"; mkdir -p "$h/claudeos/scripts/twin" "$h/bin"
  cp "$ROOT/scripts/twin/run.sh" "$ROOT/scripts/twin/prompt.md" "$ROOT/scripts/twin/prompt-mail.md" "$h/claudeos/scripts/twin/"
  printf 'import sys\nopen(sys.argv[0]+".log","a").write(" ".join(sys.argv[1:])+"\\n")\n' > "$h/claudeos/scripts/twin/discord.py"
  : > "$h/claudeos/.env"
  printf '#!/bin/bash\nexit 0\n' > "$h/bin/claude"; chmod +x "$h/bin/claude"
  (cd "$h/claudeos" && git init -q . 2>/dev/null)
  HOME="$h" CALLS="$h/calls" FAKES="$FAKES" PATH="$h/bin:$TOOLS:/usr/bin:/bin" bash "$h/claudeos/scripts/twin/run.sh" "$2" >/dev/null 2>&1
}
h=$(new_home server); twin "$h" night
has "night run reports qmd missing" "qmd-setup.sh" "$h/claudeos/scripts/twin/discord.py.log"
h=$(new_home server); : > "$h/calls"; twin "$h" midday
hasnt "only the night run, not every run" "qmd-setup.sh" "$h/claudeos/scripts/twin/discord.py.log"
h=$(new_home server); FAKE_SERVER_DOWN=1 setup "$h"; wait_bg "$h"; printf '#!/bin/bash\nexit 3\n' > "$h/.local/bin/systemctl"; chmod +x "$h/.local/bin/systemctl"; twin "$h" night
has "night run reports the service down" "qmd-setup.sh" "$h/claudeos/scripts/twin/discord.py.log"
h=$(new_home server); setup "$h"; wait_bg "$h"; twin "$h" night
hasnt "all well: no message" "qmd-setup.sh" "$h/claudeos/scripts/twin/discord.py.log"

exit $FAILED
