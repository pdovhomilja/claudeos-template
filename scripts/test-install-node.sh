#!/bin/bash
# Tests which Node.js install.sh accepts (has_node) against a fake `node` that reports a chosen version.
# Needs any real node on PATH. Run: bash scripts/test-install-node.sh
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
for c in 18.19.1=rejected 22.5.0=rejected 22.23.0=rejected 24.14.0=rejected 24.15.0=accepted 24.22.2=accepted 25.1.0=accepted; do
  v=${c%=*} want=${c#*=}
  fake_node "$v" "$T/node-$v"
  if PATH="$T/node-$v:$PATH" has_node; then got=accepted; else got=rejected; fi
  [ "$got" = "$want" ] && ok "$v $want" || bad "$v $want (got $got)"
done

exit $FAILED
