#!/bin/bash
# The server part of scripts/qmd-setup.sh under real systemd: a privileged ubuntu:24.04 container with systemd as PID 1,
# a non-root user, Node.js only in ~/.local (no system node, as on a new VM), real qmd, real Claude Code `mcp add`.
# Checks the user service, localhost only, MCP search, a restart of the "machine", and what it costs in memory and disk.
# Downloads about 2.5 GB. Run: bash scripts/test-qmd-server.sh   (KEEP=1 leaves the container running)
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
C=qmd-server-test-$$
FAILED=0
ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept: $C"; return; }; docker rm -f "$C" >/dev/null 2>&1; }
trap cleanup EXIT

docker build -q -t qmd-server-test - >/dev/null <<'DOCKERFILE' || exit 1
FROM ubuntu:24.04
RUN apt-get update -qq && apt-get install -y -qq systemd systemd-sysv dbus libpam-systemd sudo curl ca-certificates iproute2 procps python3 >/dev/null 2>&1
RUN useradd -m -s /bin/bash jarvis && echo 'jarvis ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/jarvis
CMD ["/lib/systemd/systemd"]
DOCKERFILE
docker run -d --name "$C" --privileged --cgroupns=host -v "$ROOT:/w:ro" --tmpfs /run --tmpfs /run/lock qmd-server-test >/dev/null || exit 1
for _ in $(seq 30); do docker exec "$C" systemctl is-system-running 2>/dev/null | grep -qE 'running|degraded' && break; sleep 1; done

as() { docker exec -i -u jarvis -e HOME=/home/jarvis -w /home/jarvis "$C" bash -l -c "export XDG_RUNTIME_DIR=/run/user/\$(id -u) PATH=\$HOME/.local/bin:\$PATH; $1"; }
# One MCP tool call over HTTP, as Claude Code makes it. $1 = tool arguments as JSON
mcp_call() {
  as "cat > /tmp/mcp.sh; bash /tmp/mcp.sh" <<EOF
H='Accept: application/json, text/event-stream'; U=http://localhost:8181/mcp
S=\$(curl -si -m 10 \$U -H "\$H" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}' | tr -d '\r' | sed -n 's/^mcp-session-id: //Ip')
curl -s -m 10 \$U -H "\$H" -H 'Content-Type: application/json' -H "mcp-session-id: \$S" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null
curl -s -m 120 \$U -H "\$H" -H 'Content-Type: application/json' -H "mcp-session-id: \$S" -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"query","arguments":$1}}'
EOF
}
SEARCH='{"searches":[{"type":"vec","query":"how do I cook Italian pasta"},{"type":"vec","query":"jak uvarit italske testoviny"},{"type":"lex","query":"pasta eggs"}],"rerank":false,"limit":1}'

echo "# a new server: Node.js, Claude Code and the copy in the home folder, nothing else"
as 'command -v node' >/dev/null && bad "image has no node" || ok "image has no node"
as "mkdir -p ~/.local/bin ~/.config/systemd/user ~/claudeos/wiki ~/claudeos/raw ~/claudeos/scripts
    cp -r /w/scripts/qmd-setup.sh /w/scripts/vm ~/claudeos/scripts/
    printf '# Carbonara\nThe recipe uses eggs, pecorino cheese and guanciale. Boil the pasta in salted water.\n' > ~/claudeos/wiki/carbonara.md
    printf '# Flat tyre\nHow to patch the inner tube of a road bicycle.\n' > ~/claudeos/wiki/flat-tyre.md
    sed '\$d' /w/install.sh > /tmp/f.sh; . /tmp/f.sh; trap - ERR
    OS=Linux; case \$(uname -m) in aarch64) ARCH=arm64 ;; *) ARCH=amd64 ;; esac; download_node
    curl -fsSL https://claude.ai/install.sh | bash >/dev/null
    cp ~/claudeos/scripts/vm/systemd/* ~/.config/systemd/user/" || exit 1

echo "# setup"
as 'bash ~/claudeos/scripts/qmd-setup.sh' && ok "setup returns" || bad "setup returns"
as 'systemctl --user is-active qmd.service' | grep -qx active && ok "service is active" || { bad "service is active"; as 'systemctl --user status qmd.service --no-pager; journalctl --user -u qmd.service --no-pager | tail -20'; }
docker exec "$C" loginctl show-user jarvis -p Linger | grep -q yes && ok "linger is on (the setup turned it on)" || bad "linger is on"
as 'claude mcp list 2>&1' | grep -E '^qmd:.*localhost:8181' && ok "user MCP server qmd" || bad "user MCP server qmd"

for _ in $(seq 30); do docker exec "$C" ss -ltn | grep -q ':8181 ' && break; sleep 1; done
docker exec "$C" ss -ltn | grep ':8181 '
if docker exec "$C" ss -ltn | grep ':8181 ' | grep -qE '(^|[[:space:]])(127\.0\.0\.1|\[::1\]):8181 ' && ! docker exec "$C" ss -ltn | grep ':8181 ' | grep -qE '(\*|0\.0\.0\.0|\[::\]):8181 '; then ok "listens on localhost only"; else bad "listens on localhost only"; fi

echo "# first embedding (up to 30 min)"
for _ in $(seq 360); do as 'tail -1 ~/claudeos/runs/qmd-first-embed.log' | grep -qE '^(done|stopped)' && break; sleep 5; done
as 'tail -1 ~/claudeos/runs/qmd-first-embed.log' | grep -q '^done' && ok "background job finished" || { bad "background job finished"; as 'tail -20 ~/claudeos/runs/qmd-first-embed.log'; }

echo "# MCP search"
t=$(date +%s); out=$(mcp_call "$SEARCH"); s1=$(( $(date +%s) - t ))
t=$(date +%s); mcp_call "$SEARCH" >/dev/null; s2=$(( $(date +%s) - t ))
echo "   first ${s1}s (loads the model), second ${s2}s"
echo "$out" | grep -q 'wiki/carbonara.md' && ok "hit, as a repo path" || { bad "hit, as a repo path"; echo "$out" | cut -c1-600; }
[ "$s2" -le 5 ] && ok "second search within 5 s" || bad "second search within 5 s (${s2}s)"

echo "# what it costs"
as 'systemctl --user show qmd.service -p MemoryCurrent -p MemoryPeak'
as 'du -sh ~/.cache/qmd/models ~/.local/lib/node_modules/@tobilu/qmd ~/.cache/qmd/index.sqlite'

echo "# the machine restarts, nobody logs in"
docker restart "$C" >/dev/null
for _ in $(seq 40); do as 'systemctl --user is-active qmd.service' 2>/dev/null | grep -qx active && break; sleep 2; done
as 'systemctl --user is-active qmd.service' 2>/dev/null | grep -qx active && ok "service is back" || bad "service is back"
sleep 5
mcp_call "$SEARCH" | grep -q 'wiki/carbonara.md' && ok "search works after the restart" || bad "search works after the restart"

echo "# running it again"
as 'bash ~/claudeos/scripts/qmd-setup.sh' >/dev/null && ok "setup again" || bad "setup again"
[ "$(as 'claude mcp list 2>&1' | grep -c '^qmd:')" = 1 ] && ok "one MCP server" || bad "one MCP server"
as 'systemctl --user is-active qmd.service' | grep -qx active && ok "service still active" || bad "service still active"

exit $FAILED
