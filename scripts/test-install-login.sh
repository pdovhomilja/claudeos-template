#!/bin/bash
# Tests the server's copy-free Claude login (login_with_qr in install.sh) against a fake `claude`.
# Needs tmux. Run: bash scripts/test-install-login.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'tmux kill-session -t qrtest 2>/dev/null; tmux kill-session -t other-tmux 2>/dev/null; tmux -L claudeos-login kill-server 2>/dev/null; rm -rf "$T"' EXIT
FAILED=0
ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }

KEY="sk-ant-oat01-$(printf 'A%.0s' $(seq 90))_x-Y"
URL="https://claude.com/cai/oauth/authorize?code=true&client_id=abc&scope=user%3Ainference&state=$(printf 'z%.0s' $(seq 300))"

# Fake claude: like Claude Code, it breaks long lines at the window width with real line breaks.
mkdir -p "$T/bin"
cat > "$T/bin/claude" <<EOF
#!/bin/bash
w=\$(tput cols)
wrap() { printf '%s\n' "\$1" | fold -w "\$w"; }
[ "\$1" = setup-token ] || exit 1
echo " Browser didn't open? Use the url below to sign in"
wrap "$URL"
while true; do
  printf ' Paste code here if prompted > '
  read -r code
  if [ "\$code" = "good-code#state" ]; then
    echo " Your OAuth token (valid for 1 year):"; wrap "$KEY"; sleep 30; exit 0
  fi
  echo " OAuth error: That code wasn't accepted."; echo " Press Enter to retry."; read -r _
done
EOF
chmod +x "$T/bin/claude"

# Runs login_with_qr in a terminal (tmux), types $1 as the code; output in $T/out, exit code in $T/rc.
run_login() {
  rm -f "$T/out" "$T/rc" "$T/token"
  cat > "$T/run.sh" <<EOF
export PATH="$T/bin:\$PATH"
source <(sed '\$d' "$ROOT/install.sh")
trap - ERR
TOKEN_FILE="$T/token"
login_with_qr > "$T/out" 2>&1
echo \$? > "$T/rc"
EOF
  env -u TMUX tmux new-session -d -s qrtest -x 120 -y 40 "bash $T/run.sh"
  for _ in $(seq 30); do grep -q 'Paste the code' "$T/out" 2>/dev/null && break; sleep 0.5; done
  env -u TMUX tmux send-keys -t qrtest -l "  $1 "; env -u TMUX tmux send-keys -t qrtest Enter
  for _ in $(seq 60); do [ -f "$T/rc" ] && break; sleep 0.5; done
  env -u TMUX tmux kill-session -t qrtest 2>/dev/null
}

echo "# right code"
run_login "good-code#state"
[ "$(cat "$T/rc" 2>/dev/null)" = 0 ] && ok "returns 0" || bad "returns 0 (got $(cat "$T/rc" 2>/dev/null))"
[ "$(cat "$T/token" 2>/dev/null)" = "$KEY" ] && ok "key saved" || bad "key saved"
[ "$(stat -c %a "$T/token" 2>/dev/null || stat -f %Lp "$T/token" 2>/dev/null)" = 600 ] && ok "key file mode 600" || bad "key file mode 600"
grep -qxF "   $URL" "$T/out" && ok "link printed on one line" || bad "link printed on one line"
grep -q 'sk-ant-oat01' "$T/out" && bad "key not shown" || ok "key not shown"
grep -q 'good-code' "$T/out" && bad "code not shown" || ok "code not shown"
env -u TMUX tmux -L claudeos-login ls >/dev/null 2>&1 && bad "login window closed" || ok "login window closed"

echo "# wrong code"
run_login "bad-code"
[ "$(cat "$T/rc" 2>/dev/null)" = 0 ] && ok "returns 0 (the caller retries)" || bad "returns 0 (got $(cat "$T/rc" 2>/dev/null))"
[ -e "$T/token" ] && bad "no key saved" || ok "no key saved"
grep -q 'did not work' "$T/out" && ok "says it did not work" || bad "says it did not work"
env -u TMUX tmux -L claudeos-login ls >/dev/null 2>&1 && bad "login window closed" || ok "login window closed"

echo "# a tmux is already running (as on jarvisOS: ttyd -> tmux), started without the fake claude on its PATH"
env -u TMUX PATH=/usr/bin:/bin tmux new-session -d -s other-tmux 'sleep 600'
run_login "good-code#state"
[ "$(cat "$T/token" 2>/dev/null)" = "$KEY" ] && ok "key saved" || bad "key saved (got rc $(cat "$T/rc" 2>/dev/null))"
env -u TMUX tmux has-session -t other-tmux 2>/dev/null && ok "the running tmux is left alone" || bad "the running tmux is left alone"

exit $FAILED
