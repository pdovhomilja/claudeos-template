#!/bin/bash
# Set up the twin on a fresh Ubuntu 24.04 server, as the user that will run it (not root; needs sudo).
# Usage: bash bootstrap.sh git@github.com:<you>/<your-claudeos>.git
# Safe to re-run. Stops at the steps only a human can do and says what to do.
set -euo pipefail
REPO="${1:?usage: bootstrap.sh <git ssh url of your claudeOS repo>}"
DIR="$HOME/claudeos"
export PATH="$HOME/.local/bin:$PATH"

echo "== packages"
sudo apt-get update -qq
sudo NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git python3 curl unattended-upgrades
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
command -v graphify >/dev/null || uv tool install graphifyy

echo "== deploy key"
KEY="$HOME/.ssh/claudeos_deploy"
if [ ! -f "$KEY" ]; then
  mkdir -p ~/.ssh && ssh-keygen -q -t ed25519 -N "" -C "claudeos twin $(hostname)" -f "$KEY"
  printf 'Host github.com\n  IdentityFile %s\n  IdentitiesOnly yes\n' "$KEY" >> ~/.ssh/config
  ssh-keyscan -q github.com >> ~/.ssh/known_hosts 2>/dev/null
fi
if [ ! -d "$DIR/.git" ]; then
  if ! git clone -q "$REPO" "$DIR" 2>/dev/null; then
    echo; echo "Add this as a deploy key WITH write access on the repo (GitHub → Settings → Deploy keys), then re-run:"
    cat "$KEY.pub"; exit 1
  fi
fi
git -C "$DIR" config user.name >/dev/null || git -C "$DIR" config user.name "claudeOS twin"
git -C "$DIR" config user.email >/dev/null || git -C "$DIR" config user.email "twin@$(hostname)"

echo "== timers"
mkdir -p ~/.config/systemd/user
cp "$DIR"/scripts/vm/systemd/* ~/.config/systemd/user/
sudo loginctl enable-linger "$USER"
systemctl --user daemon-reload

if command -v google-chrome >/dev/null && command -v tigervncserver >/dev/null; then
  echo "== browser desktop"
  VNC="$HOME/.config/tigervnc"; mkdir -p "$VNC"; chmod 700 "$VNC"
  if [ ! -f "$VNC/passwd" ]; then   # VNC passwords are at most 8 characters
    python3 -c 'import secrets, string; print("".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(8)))' > "$VNC/password-plain.txt"
    vncpasswd -f < "$VNC/password-plain.txt" > "$VNC/passwd"
    chmod 600 "$VNC/passwd" "$VNC/password-plain.txt"
  fi
  printf '#!/bin/sh\nopenbox-session &\nexec google-chrome --no-first-run --start-maximized --password-store=basic\n' > "$VNC/xstartup"
  chmod 755 "$VNC/xstartup"
  systemctl --user enable --now claudeos-desktop.service claudeos-novnc.service
fi

echo; echo "Left for you (once):"
tailscale status >/dev/null 2>&1 || echo "  - sudo tailscale up --ssh     (log in with YOUR Tailscale account)"
if [ -f "$HOME/.config/tigervnc/passwd" ]; then
  echo "  - browser: sudo tailscale serve --bg 6080   (once, after tailscale up; enable HTTPS if it asks)"
  echo "    then open https://<this server's tailscale name>/vnc.html on your laptop or phone;"
  echo "    password: cat ~/.config/tigervnc/password-plain.txt"
  echo "  - in that Chrome: log in to claude.ai, install the \"Claude\" extension from the Chrome Web Store,"
  echo "    then on the server run once: cd $DIR && claude --chrome   (connects Claude to that browser)"
fi
[ -f "$DIR/.env" ] || echo "  - cp $DIR/.env.example $DIR/.env and fill it in (Discord bot, optional mailbox)"
echo "  - cd $DIR && claude, then /login with YOUR Claude account, and say 'run the first-time setup' if not done yet"
echo "  - test: bash $DIR/scripts/twin/run.sh midday   (brief appears in Discord)"
echo "  - then: systemctl --user enable --now claudeos-twin.timer claudeos-mail.timer"
