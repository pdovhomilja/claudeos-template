#!/bin/bash
# claudeOS installer for a new user (macOS or Linux).
#   Laptop: curl -fsSL <url>/install.sh | bash
#   Server: curl -fsSL <url>/install.sh | bash -s -- --server
# Installs the tools, creates YOUR private repo from the template on YOUR GitHub account,
# clones it to ~/claudeos and starts Claude Code on the first-time setup. Safe to re-run.
set -euo pipefail
TEMPLATE="pdovhomilja/claudeos-template"
DIR="$HOME/claudeos"
SERVER=0; [ "${1:-}" = "--server" ] && SERVER=1
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
say() { printf '\n== %s\n' "$1"; }

say "Tools"
case "$(uname -s)" in
  Darwin)
    command -v brew >/dev/null || { echo "Install Homebrew first (https://brew.sh), then run this again."; exit 1; }
    for p in git gh; do command -v $p >/dev/null || brew install -q $p; done ;;
  Linux)
    command -v git >/dev/null && command -v gh >/dev/null || { sudo apt-get update -qq; sudo apt-get install -y -qq git gh curl; } ;;
  *) echo "Unsupported OS. On Windows follow the README quick start."; exit 1 ;;
esac
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
command -v graphify >/dev/null || uv tool install -q graphifyy

say "GitHub"
gh auth status >/dev/null 2>&1 || gh auth login -h github.com -p https -w </dev/tty
gh auth setup-git

if [ ! -d "$DIR/.git" ]; then
  say "Your claudeOS repo"
  read -r -p "Name of your new private repo [claudeos]: " NAME </dev/tty
  NAME="${NAME:-claudeos}"
  OWNER="$(gh api user -q .login)"
  gh repo view "$OWNER/$NAME" >/dev/null 2>&1 || gh repo create "$NAME" --private --template "$TEMPLATE"
  for i in 1 2 3 4 5 6; do gh repo clone "$OWNER/$NAME" "$DIR" -- -q 2>/dev/null && break; sleep 5; done  # template copy is async
  [ -d "$DIR/.git" ] || { echo "Could not clone $OWNER/$NAME. Re-run in a minute."; exit 1; }
fi

if [ "$SERVER" = 1 ]; then
  say "Server twin"
  bash "$DIR/scripts/vm/bootstrap.sh" "$(git -C "$DIR" remote get-url origin)"
  exit 0
fi

say "Done. Starting Claude Code: log in with your own Claude account, then it runs the setup."
cd "$DIR" && exec claude "run the first-time setup" </dev/tty
