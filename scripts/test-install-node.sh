#!/bin/bash
# Tests which Node.js install.sh accepts (has_node), and that after download_node the same run and a new
# terminal use the downloaded node, not an older system one. Fake `node`s report a chosen version.
# Needs any real node on PATH (zsh cases are skipped without zsh). Run: bash scripts/test-install-node.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
FAILED=0
ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }

REAL_NODE=$(command -v node) || { echo "needs node on PATH"; exit 1; }
sed '$d' "$ROOT/install.sh" > "$T/install-functions.sh"   # without its last line, main does not run
. "$T/install-functions.sh"   # (bash 3.2 cannot source <(…))
trap - ERR

# Fake node: the real one, but process.versions.node says $1.
fake_node() {   # $1 = version, $2 = folder
  mkdir -p "$2"
  printf 'Object.defineProperty(process.versions, "node", { value: "%s" });\n' "$1" > "$2/version.js"
  printf '#!/bin/bash\nexec "%s" -r "%s/version.js" "$@"\n' "$REAL_NODE" "$2" > "$2/node"
  chmod +x "$2/node"
}

echo "# has_node: context-mode 2.x needs Node.js 24.15 or newer"
for c in 18.19.1=rejected 22.5.0=rejected 22.23.0=rejected 24.14.0=rejected 24.9.0=rejected 24.15.0=accepted 24.22.2=accepted 25.1.0=accepted 30.0.0=accepted; do
  v=${c%=*} want=${c#*=}
  fake_node "$v" "$T/node-$v"
  if PATH="$T/node-$v:$PATH" has_node; then got=accepted; else got=rejected; fi
  [ "$got" = "$want" ] && ok "$v $want" || bad "$v $want (got $got)"
done

# A machine with an old system node ahead on PATH. download_node gets a fake 24.22.2 instead of nodejs.org.
fake_node 22.23.0 "$T/old"
fake_node 24.22.2 "$T/pkg/bin"; : > "$T/pkg/bin/npm"; : > "$T/pkg/bin/npx"
tar -czf "$T/node.tar.gz" -C "$T" pkg
curl() {   # only the two calls download_node makes
  case "$*" in
    *SHASUMS256.txt) printf 'x  node-v24.22.2-%s.tar.gz\n' darwin-x64 darwin-arm64 linux-x64 linux-arm64 ;;
    *" -o "*) cp "$T/node.tar.gz" "$3" ;;
  esac
}

echo "# the rest of the install run uses the downloaded node"
(
  HOME="$T/run" BIN="$T/run/.local/bin"
  OS=$(uname -s) ARCH=amd64
  PATH="$T/old:$PATH"
  node -v >/dev/null   # bash now remembers the old node, as after the checklist
  mkdir -p "$BIN"; export PATH="$BIN:$PATH"   # as main does
  has_node || download_node
  has_node && ok "has_node after download_node" || bad "has_node after download_node (node is $(node -p process.versions.node))"
)

# A new terminal after the install: $1 = shell, $2 = line already in its profile ("" = none).
new_shell_node() {
  local h="$T/home-$1-$RANDOM" f
  mkdir -p "$h/.local/bin"
  [ -d /etc/skel ] && cp -R /etc/skel/. "$h/"   # Linux: .profile that reads .bashrc
  ln -s "$T/pkg/bin/node" "$h/.local/bin/node"
  case "$1" in zsh) f=.zshrc ;; *) if [ "$(uname -s)" = Darwin ]; then f=.bash_profile; else f=.bashrc; fi ;; esac
  [ -n "$2" ] && printf '%s\n' "$2" >> "$h/$f"
  HOME="$h" SHELL="/bin/$1" OS=$(uname -s) add_path_to_profile
  env -i HOME="$h" TERM=dumb PATH="$T/old:/usr/bin:/bin" "$1" -lic 'node -p process.versions.node' 2>/dev/null | tail -1
}

echo "# a new terminal uses the downloaded node"
for sh in bash zsh; do
  command -v "$sh" >/dev/null || { echo "skip $sh (not installed)"; continue; }
  v=$(new_shell_node "$sh" "")
  [ "$v" = 24.22.2 ] && ok "$sh, fresh profile" || bad "$sh, fresh profile (got $v)"
  v=$(new_shell_node "$sh" 'export PATH="$PATH:$HOME/.local/bin"')
  [ "$v" = 24.22.2 ] && ok "$sh, profile already adds ~/.local/bin at the end (pipx)" || bad "$sh, profile already adds ~/.local/bin at the end (pipx) (got $v)"
done

exit $FAILED
