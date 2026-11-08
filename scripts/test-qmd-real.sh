#!/bin/bash
# The real thing on this machine, in a throwaway home: the installer's qmd step, scripts/qmd-setup.sh, a real model
# download and embedding, keyword and vector hits on a small sample. Nothing outside the throwaway home is touched
# (an existing ~/.config/qmd and ~/.cache/qmd stay as they are). Downloads about 2.5 GB. Needs Node.js 24.15+ on PATH.
# Run: bash scripts/test-qmd-real.sh     On a clean Linux: docker run --rm -v "$PWD:/w:ro" ubuntu:24.04 bash /w/scripts/test-qmd-real.sh --clean-ubuntu
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [ "${1:-}" = --clean-ubuntu ]; then   # as root in the container: what a cloud image has, a user, Node.js from the installer
  apt-get update -qq >/dev/null; apt-get install -y -qq curl ca-certificates >/dev/null 2>&1
  command -v gcc make >/dev/null && echo "note: this image has a compiler"
  useradd -m tester
  su - tester -c "bash -c '
    sed \"\\\$d\" $ROOT/install.sh > /tmp/f.sh; . /tmp/f.sh; trap - ERR
    OS=Linux; case \$(uname -m) in aarch64) ARCH=arm64 ;; *) ARCH=amd64 ;; esac; mkdir -p \$BIN; export PATH=\$BIN:\$PATH
    download_node; bash $ROOT/scripts/test-qmd-real.sh'"
  exit $?
fi

NODE_DIR=$(dirname "$(command -v node)")
H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT
FAILED=0
ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }
node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>24||(a==24&&b>=15)?0:1)' || { echo "needs Node.js 24.15+"; exit 1; }

mkdir -p "$H/claudeos/scripts/vm/systemd" "$H/claudeos/wiki/twin/2026-11" "$H/claudeos/raw/mail"
cp "$ROOT/scripts/qmd-setup.sh" "$ROOT/scripts/qmd-refresh.sh" "$H/claudeos/scripts/"
printf '# Carbonara\nThe recipe uses eggs, pecorino cheese and guanciale. Boil the pasta in salted water.\n' > "$H/claudeos/wiki/carbonara.md"
printf '# Flat tyre\nHow to patch the inner tube of a road bicycle at the side of the road.\n' > "$H/claudeos/wiki/flat-tyre.md"
printf '# Night brief\nCarbonara carbonara carbonara, written by the twin.\n' > "$H/claudeos/wiki/twin/2026-11/brief.md"
printf 'Faktura od dodavatele za pronajem kancelare v Praze, splatnost do konce mesice.\n' > "$H/claudeos/raw/mail/faktura.txt"

export HOME="$H" PATH="$H/.local/bin:$NODE_DIR:/usr/bin:/bin"
unset XDG_CONFIG_HOME XDG_CACHE_HOME
BIN="$H/.local/bin"; mkdir -p "$BIN"

sed '$d' "$ROOT/install.sh" > "$H/install-functions.sh"; . "$H/install-functions.sh"; trap - ERR

echo "# install"
install_qmd >"$H/npm.log" 2>&1 && ok "install_qmd" || { bad "install_qmd"; tail -20 "$H/npm.log"; exit 1; }
[ "$(command -v qmd)" = "$H/.local/bin/qmd" ] && ok "qmd is in ~/.local/bin" || bad "qmd is in ~/.local/bin (got $(command -v qmd))"
qmd --version

echo "# setup"
t0=$(date +%s)
bash "$H/claudeos/scripts/qmd-setup.sh" && ok "setup returns" || bad "setup returns"
s=$(( $(date +%s) - t0 ))
[ "$s" -lt 30 ] && ok "setup returned in ${s}s, models still downloading" || bad "setup took ${s}s"
[ "$(qmd search carbonara --files | head -1 | cut -d, -f3)" = qmd://wiki/carbonara.md ] && ok "keyword hit at once" || bad "keyword hit at once"
qmd search carbonara --files | grep -q twin && bad "twin briefs stay out of the index" || ok "twin briefs stay out of the index"
grep -q "$H" "$H/.config/qmd/index.yml" && ok "paths in qmd's config are the throwaway home" || bad "paths in qmd's config"
bash "$H/claudeos/scripts/qmd-setup.sh" >/dev/null && ok "setup again while the first embed runs" || bad "setup again while the first embed runs"

echo "# first embedding in the background (up to 30 min)"
for _ in $(seq 360); do
  grep -qE '^(done|stopped)' "$H/claudeos/runs/qmd-embed.log" && break
  sleep 5
done
tail -1 "$H/claudeos/runs/qmd-embed.log" | grep -q '^done' && ok "background job finished" || { bad "background job finished"; tail -20 "$H/claudeos/runs/qmd-embed.log"; }
echo "   took $(( $(date +%s) - t0 ))s"; du -sh "$H/.cache/qmd/models" "$H/.local/lib/node_modules/@tobilu/qmd"; ls -1 "$H/.cache/qmd/models"
ls "$H/.cache/qmd/models" | grep -q Qwen3-Embedding && ok "the Qwen3 embedding model was used" || bad "the Qwen3 embedding model was used"

echo "# searches"
t=$(date +%s); top=$(qmd vsearch "how do I cook Italian pasta" -n 1 --files 2>/dev/null | head -1 | cut -d, -f3); echo "   vsearch $(( $(date +%s) - t ))s: $top"
[ "$top" = qmd://wiki/carbonara.md ] && ok "vector hit, other words than the source" || bad "vector hit, other words than the source (got $top)"
top=$(qmd vsearch "Wie repariere ich mein Fahrrad?" -n 1 --files 2>/dev/null | head -1 | cut -d, -f3)
[ "$top" = qmd://wiki/flat-tyre.md ] && ok "vector hit, other language than the source" || bad "vector hit, other language than the source (got $top)"
top=$(qmd vsearch "office rent invoice" -n 1 --files 2>/dev/null | head -1 | cut -d, -f3)
[ "$top" = qmd://raw/mail/faktura.txt ] && ok "raw .txt is found" || bad "raw .txt is found (got $top)"

echo "# the first job was interrupted before the query model: a session-start refresh recovers it"
rm -f "$H"/.cache/qmd/models/*query-expansion*
printf '# Sourdough\nFeed the starter with flour and water.\n' > "$H/claudeos/wiki/sourdough.md"
t=$(date +%s); bash "$H/claudeos/scripts/qmd-refresh.sh" && ok "refresh returns at once ($(( $(date +%s) - t ))s)" || bad "refresh returns"
[ "$(qmd search starter --files | head -1 | cut -d, -f3)" = qmd://wiki/sourdough.md ] && ok "new file found by keyword" || bad "new file found by keyword"
for _ in $(seq 240); do grep -qE '^(done|stopped)' "$H/claudeos/runs/qmd-embed.log" && break; sleep 5; done
tail -1 "$H/claudeos/runs/qmd-embed.log" | grep -q '^done' && ok "refresh finished" || { bad "refresh finished"; tail -5 "$H/claudeos/runs/qmd-embed.log"; }
ls "$H"/.cache/qmd/models/*query-expansion*.gguf >/dev/null 2>&1 && ok "query model is back" || bad "query model is back"
qmd status | grep -q Pending && bad "nothing pending" || ok "nothing pending"
t=$(date +%s); bash "$H/claudeos/scripts/qmd-refresh.sh" >/dev/null; for _ in $(seq 60); do grep -qE '^(done|stopped)' "$H/claudeos/runs/qmd-embed.log" && break; sleep 1; done; echo "   refresh with nothing to do: $(( $(date +%s) - t ))s"

exit $FAILED
