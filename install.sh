#!/bin/bash
# claudeOS installer for macOS and Linux. Written for people who have never used a terminal.
#   Laptop: curl -fsSL https://raw.githubusercontent.com/pdovhomilja/claudeos-template/main/install.sh | bash
#   Server: ... | bash -s -- --server
# Installs everything into your home folder (no Homebrew needed), creates YOUR private copy of the
# template on YOUR GitHub account, clones it to ~/claudeos and starts the assistant's first-time setup.
# Safe to run again at any time: it skips what is done and continues where it stopped.
# Everything runs inside main(), called on the last line, so a half-downloaded script does nothing.
# Keep it bash 3.2 compatible (macOS /bin/bash).

TEMPLATE="pdovhomilja/claudeos-template"
DIR="$HOME/claudeos"
BIN="$HOME/.local/bin"
STEP="starting"

say()  { printf '\n\033[1m%s\033[0m\n' "$1"; }
info() { printf '   %s\n' "$1"; }
wait_enter() { printf '\n   %s ' "${1:-Press Enter to continue.}"; read -r _ </dev/tty; }
fail() {
  printf '\n\033[31mStopped while %s.\033[0m\n' "$STEP"
  [ -n "${1:-}" ] && printf '%s\n' "$1"
  printf '\nNothing is broken. Paste the same command again and it continues where it stopped.\n'
  printf 'If it stops here again, take a screenshot of this window and send it to whoever gave you the link.\n'
  exit 1
}
trap 'fail' ERR

download_gh() {
  local v tmp os ext
  v=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest); v=${v##*/v}
  tmp=$(mktemp -d)
  if [ "$OS" = Darwin ]; then os=macOS; ext=zip; else os=linux; ext=tar.gz; fi
  curl -fsSL -o "$tmp/gh.$ext" "https://github.com/cli/cli/releases/download/v$v/gh_${v}_${os}_${ARCH}.$ext"
  if [ "$ext" = zip ]; then unzip -q "$tmp/gh.zip" -d "$tmp"; else tar -xzf "$tmp/gh.tar.gz" -C "$tmp"; fi
  cp "$(find "$tmp" -path '*/bin/gh' -type f | head -1)" "$BIN/gh"
  chmod +x "$BIN/gh"
  rm -rf "$tmp"
}

install_obsidian() {   # macOS only; the wiki is easiest to read in Obsidian
  local v tmp dest=/Applications
  v=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/obsidianmd/obsidian-releases/releases/latest); v=${v##*/v}
  tmp=$(mktemp -d)
  [ -w "$dest" ] || { dest="$HOME/Applications"; mkdir -p "$dest"; }
  # one chain: called after `||`, where set -e does not apply
  curl -fsSL -o "$tmp/o.dmg" "https://github.com/obsidianmd/obsidian-releases/releases/download/v$v/Obsidian-$v.dmg" \
    && hdiutil attach -nobrowse -quiet -mountpoint "$tmp/mnt" "$tmp/o.dmg" \
    && cp -R "$tmp/mnt/Obsidian.app" "$dest/"
  local rc=$?
  hdiutil detach -quiet "$tmp/mnt" 2>/dev/null
  rm -rf "$tmp"
  return $rc
}

add_path_to_profile() {   # so a new Terminal window finds the tools in ~/.local/bin
  local f
  case "$(basename "${SHELL:-bash}")" in
    zsh) f="$HOME/.zshrc" ;;
    bash) if [ "$OS" = Darwin ]; then f="$HOME/.bash_profile"; else f="$HOME/.bashrc"; fi ;;
    *) f="$HOME/.profile" ;;
  esac
  grep -qs 'local/bin' "$f" || printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$f"
}

is_claudeos_repo() {   # $1 = owner/name; true only if GitHub says it was created from the template (an earlier run).
  # Never guess from its files: someone's personal claudeOS looks the same and must never be reused.
  [ "$(gh repo view "$1" --json templateRepository -q '(.templateRepository.owner.login // "") + "/" + (.templateRepository.name // "")' 2>/dev/null)" = "$TEMPLATE" ]
}

has_browser() { command -v google-chrome >/dev/null && command -v tigervncserver >/dev/null && command -v websockify >/dev/null; }

install_browser() {   # server only: Chrome inside a remote desktop you open over Tailscale (set up by bootstrap.sh)
  local tmp
  info "Installing the browser and the remote desktop, please wait (a few minutes)…"
  tmp=$(mktemp -d); chmod 755 "$tmp"
  curl -fsSL -o "$tmp/chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  chmod 644 "$tmp/chrome.deb"
  sudo apt-get update -qq </dev/tty >/dev/null
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tigervnc-standalone-server tigervnc-tools openbox novnc websockify \
    dbus-x11 fonts-liberation fonts-noto-color-emoji xfonts-base "$tmp/chrome.deb" </dev/tty >/dev/null 2>&1
  rm -rf "$tmp"
}

has_obsidian() { [ -d /Applications/Obsidian.app ] || [ -d "$HOME/Applications/Obsidian.app" ]; }
has_git() { if [ "$OS" = Darwin ]; then xcode-select -p >/dev/null 2>&1; else command -v git >/dev/null; fi; }
has_plugins() {
  local list
  list=$(claude plugin list 2>/dev/null) || return 1
  case "$list" in *context-mode@context-mode*) ;; *) return 1 ;; esac
  case "$list" in *andrej-karpathy-skills@karpathy-skills*) ;; *) return 1 ;; esac
  case "$list" in *superpowers@claude-plugins-official*) ;; *) return 1 ;; esac
  case "$list" in *last30days@last30days-skill*) ;; *) return 1 ;; esac
  case "$list" in *typesafe@typesafe-ai*) ;; *) return 1 ;; esac
}
has_node() {   # context-mode's server runs on Node.js 22.5 or newer
  command -v node >/dev/null && node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a==22&&b>=5)?0:1)'
}

download_node() {   # Node.js LTS into ~/.local/node, linked into ~/.local/bin
  local f tmp os arch=x64 url=https://nodejs.org/dist/latest-v24.x
  [ "$ARCH" = arm64 ] && arch=arm64
  if [ "$OS" = Darwin ]; then os=darwin; else os=linux; fi
  f=$(curl -fsSL "$url/SHASUMS256.txt" | grep -o "node-v[0-9.]*-$os-$arch\.tar\.gz" | head -1)
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/node.tar.gz" "$url/$f"
  rm -rf "$HOME/.local/node"; mkdir -p "$HOME/.local/node"
  tar -xzf "$tmp/node.tar.gz" -C "$HOME/.local/node" --strip-components=1
  rm -rf "$tmp"
  ln -sf "$HOME/.local/node/bin/node" "$HOME/.local/node/bin/npm" "$HOME/.local/node/bin/npx" "$BIN/"
  hash -r   # bash may still remember an older system node from the checklist
}

install_plugins() {   # one by one; a failed install is retried once with its error message shown
  local p
  for p in mksglu/context-mode=context-mode@context-mode \
           forrestchang/andrej-karpathy-skills=andrej-karpathy-skills@karpathy-skills \
           anthropics/claude-plugins-official=superpowers@claude-plugins-official \
           mvanhorn/last30days-skill=last30days@last30days-skill \
           typesafe-ai/skills=typesafe@typesafe-ai; do
    claude plugin list 2>/dev/null | grep -q "${p#*=}" && continue
    claude plugin marketplace add "${p%%=*}" >/dev/null 2>&1 || claude plugin marketplace add "${p%%=*}" || true
    claude plugin install "${p#*=}" >/dev/null 2>&1 || claude plugin install "${p#*=}" || true
  done
}

row() {   # $1 = yes|no|later|skip, $2 = what, $3 = note; counts what is missing (no) in MISSING
  local mark
  case "$1" in
    yes) mark='\033[32m✓\033[0m' ;;
    no) mark='\033[33m○\033[0m'; MISSING=$((MISSING + 1)) ;;
    later) mark='\033[33m○\033[0m' ;;
    *) mark='–' ;;
  esac
  printf "   %b  %-24s %s\n" "$mark" "$2" "$3"
}

check() {   # $1 = what, $2 = command that succeeds when it is there
  if eval "$2" >/dev/null 2>&1; then row yes "$1" "installed"; else row no "$1" "will be installed"; fi
}

preflight() {
  MISSING=0
  if [ "$OS" = Darwin ]; then check "Apple developer tools" has_git; else check "Git" has_git; fi
  check "Node.js" has_node
  check "GitHub tool (gh)" "command -v gh"
  check "Claude Code" "command -v claude"
  check "uv" "command -v uv"
  check "graphify" "command -v graphify"
  check "Claude Code plugins" has_plugins
  if [ "$SERVER" = 1 ]; then
    check "Tailscale" "command -v tailscale"
    if [ "$ARCH" = amd64 ]; then check "Browser (Chrome)" has_browser; else row skip "Browser (Chrome)" "not available on ARM servers"; fi
    row skip "Obsidian" "not needed on a server"
  else
    row skip "Tailscale" "not needed on a laptop"
    row skip "Browser on the server" "not needed on a laptop"
    if [ "$OS" = Darwin ]; then check "Obsidian" has_obsidian; else row skip "Obsidian" "optional, from obsidian.md"; fi
  fi
  if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    row yes "GitHub login" "logged in as $(gh api user -q .login 2>/dev/null)"
  else
    row later "GitHub login" "you will log in (step 4)"
  fi
}

main() {
  set -Eeuo pipefail
  local SERVER=0 LOGIN NAME n
  [ "${1:-}" = "--server" ] && SERVER=1

  STEP="checking this computer"
  [ "$(id -u)" != 0 ] || fail "Please run it without 'sudo' and not as root: paste the command exactly as you got it."
  { : </dev/tty; } 2>/dev/null || fail "This installer has to run in a Terminal window. Open Terminal, paste the command there and press Enter."
  OS=$(uname -s)
  case "$OS" in Darwin|Linux) ;; *) fail "This installer works on Mac and Linux. On Windows follow the README by hand." ;; esac
  case "$(uname -m)" in arm64|aarch64) ARCH=arm64 ;; x86_64|amd64) ARCH=amd64 ;; *) fail "Unsupported processor: $(uname -m)." ;; esac
  mkdir -p "$BIN"
  export PATH="$BIN:$PATH"

  VERSION=$(curl -fsSL "https://raw.githubusercontent.com/$TEMPLATE/main/VERSION" 2>/dev/null) || VERSION="?"
  printf '\n\033[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
  printf '\033[1m   claudeOS %s\033[0m   your own AI assistant\n' "$VERSION"
  printf '\033[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
  info "An assistant that runs on Claude Code and remembers what you teach it."
  info "Its memory is a private wiki on your own GitHub account; nothing is shared."
  info ""
  info "What this installer does:"
  info "  • installs the tools it needs, mostly into your home folder"
  info "  • makes your private copy of claudeOS on GitHub and puts it in $DIR"
  info "  • adds the command  jarvis  and starts the assistant's first-time setup"
  [ -f "$DIR/VERSION" ] && info "Already installed here: version $(cat "$DIR/VERSION"). It keeps your data and adds what is missing."
  info ""
  info "This takes about 10–15 minutes. You need:"
  info "  • a Claude Pro or Max subscription (claude.ai)"
  info "  • a free GitHub account (you can create one when the browser opens)"
  [ "$OS" = Darwin ] && info "  • maybe your Mac password, once"
  info "You can stop at any time by closing this window, and continue later by pasting the command again."
  wait_enter "Press Enter to start."

  say "1/7 What is already on this computer"
  STEP="checking what is installed"
  preflight
  if [ "$MISSING" = 0 ]; then
    wait_enter "Everything is in place. Press Enter to continue."
  else
    wait_enter "Press Enter to install what is missing ($MISSING)."
  fi

  say "2/7 Basic tools"
  STEP="installing Apple's developer tools"
  if [ "$OS" = Darwin ] && ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install >/dev/null 2>&1 || true
    info "A window from Apple opened. Click \"Install\", agree, and wait until it says done (5–20 minutes)."
    info "If no window appears, look behind this one. This window waits for it."
    n=0
    until xcode-select -p >/dev/null 2>&1; do
      sleep 20; n=$((n + 1)); [ $((n % 3)) = 0 ] && info "still waiting for Apple's installer…"
      [ "$n" -lt 180 ] || fail "Apple's developer tools did not finish within an hour."
    done
  fi
  STEP="turning off Ubuntu's restart questions"
  if [ "$OS" = Linux ] && [ -d /etc/needrestart/conf.d ] && [ ! -f /etc/needrestart/conf.d/claudeos.conf ]; then
    # needrestart would open a dialog inside apt (also in Tailscale's installer) that is hidden and cannot be answered
    printf '$nrconf{restart} = "a";\n$nrconf{kernelhints} = 0;\n$nrconf{ucodehint} = 0;\n' \
      | sudo tee /etc/needrestart/conf.d/claudeos.conf >/dev/null
  fi
  STEP="installing git"
  if [ "$OS" = Linux ] && ! command -v git >/dev/null; then
    command -v apt-get >/dev/null || fail "Please install 'git' with your system's package manager first."
    info "Your computer password may be asked for now (typing it shows nothing; that is normal)."
    info "Installing git, please wait…"
    sudo apt-get update -qq </dev/tty >/dev/null && sudo apt-get install -y -qq git ca-certificates </dev/tty >/dev/null 2>&1
  fi
  info "ok"

  say "3/7 Assistant software"
  add_path_to_profile
  STEP="installing Node.js"
  has_node || download_node
  has_node || fail "Node.js did not install."
  STEP="installing the GitHub tool"
  command -v gh >/dev/null || download_gh
  STEP="installing Claude Code"
  command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash >/dev/null
  command -v claude >/dev/null || fail "Claude Code did not install."
  STEP="installing uv"
  command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1
  STEP="installing graphify"
  command -v graphify >/dev/null || uv tool install -q graphifyy >/dev/null 2>&1 || uv tool install -q graphifyy
  if [ "$SERVER" = 1 ] && ! command -v tailscale >/dev/null; then
    STEP="installing Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1
    command -v tailscale >/dev/null || fail "Tailscale did not install."
  fi
  if [ "$SERVER" = 1 ] && [ "$ARCH" = amd64 ] && ! has_browser; then
    STEP="installing the browser"
    install_browser
    has_browser || fail "The browser did not install."
  fi
  STEP="installing Claude Code plugins"
  has_plugins || install_plugins
  has_plugins || fail "Claude Code plugins did not install (see the messages above)."
  if [ "$OS" = Darwin ] && [ "$SERVER" = 0 ]; then
    if has_obsidian; then
      info "Obsidian: already installed"
    else
      STEP="installing Obsidian"
      info "Obsidian: installing..."
      if install_obsidian; then info "Obsidian: installed"
      else info "(Obsidian skipped: the download did not work, see the message above. You can get it later from obsidian.md)"; fi
    fi
  fi
  info "ok"

  say "4/7 Connect GitHub (stores your assistant's memory, privately)"
  STEP="connecting GitHub"
  n=0
  until gh auth status >/dev/null 2>&1; do
    n=$((n + 1)); [ "$n" -le 3 ] || fail "GitHub login did not finish."
    info "What happens now:"
    info "  1. \"Authenticate Git with your GitHub credentials?\": press Enter (yes)."
    if [ "$SERVER" = 1 ]; then
      info "  2. A one-time code appears. On your phone or laptop open github.com/login/device"
    else
      info "  2. A one-time code appears. Press Enter: your browser opens github.com."
    fi
    info "  3. Log in with the GitHub account of the person this assistant is for, or click \"Sign up\"."
    info "  4. Paste the code, click Continue and then Authorize. Then come back to this window."
    gh auth login -h github.com -p https -w </dev/tty || info "That did not finish. Let's try again."
  done
  LOGIN=$(gh api user -q .login)
  info "Logged in to GitHub as:  $LOGIN"
  info "The assistant's private memory will live in this account. It must belong to the person the assistant is for."
  printf '\n   Press Enter if that is right, or type  other  and Enter to log in with a different account: '
  read -r answer </dev/tty
  if [ "$answer" = "other" ]; then
    gh auth logout -h github.com >/dev/null 2>&1 || true
    info "Logged out. Paste the install command again and log in with the right account."
    exit 0
  fi
  gh auth setup-git >/dev/null
  git config --global user.name >/dev/null || git config --global user.name "$(gh api user -q '.name // .login')"
  git config --global user.email >/dev/null || git config --global user.email "$(gh api user -q .id)+$LOGIN@users.noreply.github.com"
  info "ok"

  say "5/7 Your private copy"
  STEP="creating your private copy on GitHub"
  if [ -d "$DIR/.git" ] && is_claudeos_repo "$(git -C "$DIR" remote get-url origin 2>/dev/null | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')"; then
    info "Found $DIR, keeping it. (To get a newer claudeOS version, tell your assistant: update yourself.)"
  else
    if [ -e "$DIR" ]; then
      mv "$DIR" "$DIR.old-$(date +%Y%m%d-%H%M%S)"
      info "There was already a folder called claudeos; it was renamed, not deleted."
    fi
    NAME=claudeos; n=1
    while gh repo view "$LOGIN/$NAME" >/dev/null 2>&1 && ! is_claudeos_repo "$LOGIN/$NAME"; do
      n=$((n + 1)); NAME="claudeos-$n"
    done
    gh repo view "$LOGIN/$NAME" >/dev/null 2>&1 || gh repo create "$LOGIN/$NAME" --private --template "$TEMPLATE" >/dev/null
    STEP="downloading your private copy"
    n=0
    until gh repo clone "$LOGIN/$NAME" "$DIR" -- -q >/dev/null 2>&1 && [ -f "$DIR/WIKI.md" ]; do
      rm -rf "$DIR"; n=$((n + 1)); [ "$n" -le 24 ] || fail "GitHub is still preparing your copy. Wait a minute."
      sleep 5   # GitHub copies the template in the background
    done
    info "ok: github.com/$LOGIN/$NAME (private), on this computer in $DIR"
  fi

  say "6/7 Shortcut"
  STEP="creating the jarvis command"
  printf '#!/bin/bash\ncd "$HOME/claudeos" && exec claude "$@"\n' > "$BIN/jarvis"
  chmod +x "$BIN/jarvis"
  info "ok: from now on, open Terminal and type  jarvis  then Enter."

  if [ "$SERVER" = 1 ]; then
    say "7/7 Server twin"
    STEP="setting up the server twin"
    [ -f "$DIR/scripts/vm/bootstrap.sh" ] || fail "$DIR is not a copy of the claudeOS template."
    bash "$DIR/scripts/vm/bootstrap.sh" "$(git -C "$DIR" remote get-url origin)"
    exit 0
  fi

  say "7/7 Meet your assistant"
  trap - ERR
  # macOS kqueue rejects the /dev/tty alias (Claude Code dies with EINVAL), so hand it the real device
  TTY=$(ps -o tty= -p $$ | tr -d ' '); case "$TTY" in ""|"?"*) TTY=tty ;; esac
  if [ -f "$DIR/.claudeos-setup-done" ]; then
    info "Everything is already set up. Starting your assistant."
    cd "$DIR" && exec claude </dev/$TTY
  fi
  info "Claude Code starts now. What you will see:"
  info "  1. A colour theme: press Enter."
  info "  2. Login: choose your Claude account (subscription); the browser opens; click Authorize."
  info "  3. \"Do you trust the files in this folder?\": choose Yes."
  info "  4. Your assistant introduces itself and asks a few questions. Just answer in your own words."
  info "To leave later, type /exit. To come back: open Terminal and type  jarvis"
  wait_enter
  cd "$DIR" && exec claude "run the first-time setup" </dev/$TTY
}

main "$@"
