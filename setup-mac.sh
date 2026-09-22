#!/bin/bash
# AI Shift Training Hackathon - one-command setup (Mac)
#
#   Install:  curl -fsSL https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-mac.sh | bash
#   Check:    curl -fsSL https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-mac.sh | bash -s -- --check
#
# What it installs:
#   Needed:    Git (via Apple's developer tools / Homebrew, only if missing), GitHub CLI, Claude Code
#   Nice to have (setup carries on without them): Node.js, Python, the UI/UX Pro Max design skill
# GitHub CLI, Node.js and Python are downloaded straight into your home folder: no password,
# and no slow Homebrew builds on older macOS versions.
#
# Every run ends with "Your Setup Is Complete" or FAIL <code> + what to do.
# Safe to run again any number of times. Written for macOS /bin/bash 3.2.

# Everything is inside main() so bash reads the whole script before running any of it.
main() {
set -u

# ---------- Pinned versions (tested for this event) ----------
CC_VERSION="2.1.278"     # Claude Code
UIPRO_VERSION="2.15.0"   # ui-ux-pro-max-cli (UI/UX Pro Max design skills, uupm.cc)
GH_VERSION="2.101.0"     # GitHub CLI
UV_VERSION="0.12.17"     # uv (installs Python)
NODE_LINE="latest-v22.x" # Node.js 22 LTS
MODEL="openai/gpt-5-mini"
MIN_MACOS=13; MIN_NODE=18; MIN_GH="2.40.0"; MIN_DISK_GB=5

SETUP_CMD="curl -fsSL https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-mac.sh | bash"
HELP_CHAT="https://chat.aishifttraining.com"
DIR="$HOME/claude-hackathon"
TOOLS="$HOME/.local/hackathon-tools"      # Node.js and Python for Claude only
TBIN="$TOOLS/bin"
LOG="$DIR/setup-log.txt"
MODE="install"; [ "${1:-}" = "--check" ] && MODE="check"
STEP="starting"; FAILED=0; NOTES=""

# ---------- Colours ----------
# Every colour works on light AND dark Terminal backgrounds (important messages use a coloured box):
# step titles = white on blue | do this now = black on yellow | tips & fixes = black on light blue
# errors = white on red | progress = bold | OK = green
G=$'\033[1;32m'; B=$'\033[1m'; N=$'\033[0m'
TAG_FAIL=$'\033[1;97;41m'; FIX=$'\033[1;30;106m'; INST=$'\033[1m'; STEPC=$'\033[1;97;44m'; ACT=$'\033[1;30;103m'; OKC=$'\033[1;32m'; TAG_WARN=$'\033[1;30;43m'; DONE=$'\033[1;30;42m'
ok()    { printf "  ${OKC}OK${N}   %s\n" "$1"; }
bad()   { printf "  ${TAG_FAIL} FAIL ${N} %s\n" "$1"; }
warn()  { printf "  ${TAG_WARN} NOTE ${N} %s\n" "$1"; }
act()   { printf "${ACT} %s ${N}\n" "$1"; }
fixmsg(){ printf "${FIX} %s ${N}\n" "$1"; }
step()  { printf "\n${STEPC} STEP %s  -  %s ${N}\n" "$1" "$2"; }   # step "3 of 9" "Git (about 2 minutes)"
note_skip() { NOTES="$NOTES
  - $1"; warn "$1"; }
show_cmd() { printf "\n${ACT} Copy this line, paste it in Terminal, press Return: ${N}\n\n    %s\n\n" "$1"; }

fail() {  # fail CODE "what happened and what to do" [command to show]
  FAILED=1
  printf "\n${TAG_FAIL} FAIL %s ${N}\n${FIX}%s${N}\n" "$1" "$2"
  [ -n "${3:-}" ] && show_cmd "$3"
  printf "\nStill stuck? Take a screenshot of this window and paste it into the Setup Helper chat:\n  ${B}%s${N}  (sign up with the link in your email)\n" "$HELP_CHAT"
  sleep 1; exit 1
}
net_fail() {
  fail N1 "Your internet stopped working, so setup could not download what it needs.
1. Connect to a different Wi-Fi or your phone's hotspot.
2. Run setup again with the command below. It continues where it stopped." "$SETUP_CMD"
}
trap 'st=$?; if [ $st -ne 0 ] && [ "$FAILED" = 0 ]; then printf "\n${TAG_FAIL} FAIL X1 ${N}\n${FIX}Setup stopped during: %s.\nRun setup again. It continues where it stopped.${N}\n" "$STEP"; show_cmd "$SETUP_CMD"; fi' EXIT

# ---------- Internet: wait and retry instead of failing ----------
net_ok() { curl -s -o /dev/null -m 10 -I https://github.com; }
wait_net() {   # waits up to about 3 minutes for the internet to come back
  net_ok && return 0
  printf "${TAG_WARN} Internet problem. ${N} ${FIX}Waiting for your internet to come back... (check your Wi-Fi)${N}\n"
  i=0
  while [ $i -lt "${NET_WAIT_TRIES:-18}" ]; do sleep "${NET_WAIT_SECS:-10}"; net_ok && { ok "Internet is back"; return 0; }; i=$((i+1)); done
  return 1
}
retry() {      # retry "what" command... : tries 3 times, waiting for the internet in between
  what="$1"; shift; n=1
  while :; do
    "$@" && return 0
    [ $n -ge 3 ] && return 1
    printf "${FIX}%s did not work (try %s of 3). Trying again in 10 seconds...${N}\n" "$what" "$n"
    wait_net || return 1
    sleep 10; n=$((n+1))
  done
}
download() { curl -fL --retry 2 --connect-timeout 20 -o "$2" "$1" && [ -s "$2" ]; }

mkdir -p "$DIR" "$TBIN" "$HOME/.local/bin" || fail P8 "Setup could not make its folder. Restart your Mac, then run setup again." "$SETUP_CMD"
: < /dev/tty 2>/dev/null || fail P7 "Please run setup in the Terminal app.
Press Cmd + Space, type Terminal, press Return, and paste the command there." "$SETUP_CMD"

# ---------- Helpers ----------
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)" = "$2" ]; }
have_clt() { xcode-select -p >/dev/null 2>&1; }
real_cmd() {  # /usr/bin/git and python3 are Apple stubs that pop up a window if developer tools are missing
  p="$(command -v "$1" 2>/dev/null)" || return 1
  case "$p" in /usr/bin/*) have_clt || return 1 ;; esac
  printf '%s' "$p"
}
json_num() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\(-\{0,1\}[0-9.eE+-]*\).*/\1/p" | head -n1; }
find_brew() {
  BREW="$(command -v brew 2>/dev/null || true)"
  [ -z "$BREW" ] && [ -x /opt/homebrew/bin/brew ] && BREW=/opt/homebrew/bin/brew
  [ -z "$BREW" ] && [ -x /usr/local/bin/brew ] && BREW=/usr/local/bin/brew
  [ -n "$BREW" ] && eval "$("$BREW" shellenv 2>/dev/null)"
  return 0
}
check_tools() {
  export PATH="$TBIN:$HOME/.local/bin:$PATH"; hash -r
  GIT="$(real_cmd git || true)"
  GH="$(command -v gh 2>/dev/null || true)"
  if [ -n "$GH" ] && ! ver_ge "$("$GH" --version 2>/dev/null | head -n1 | awk '{print $3}')" "$MIN_GH"; then GH=""; fi
  NODE="$(command -v node 2>/dev/null || true)"
  if [ -n "$NODE" ] && ! [ "$("$NODE" -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)" -ge "$MIN_NODE" ] 2>/dev/null; then NODE=""; fi
  PY=""
  for c in python3.12 python3.13 python3.11 python3.10 python3; do
    p="$(real_cmd "$c" || true)"
    if [ -n "$p" ] && "$p" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' >/dev/null 2>&1; then PY="$p"; break; fi
  done
  return 0
}
existing_key() { cat "$HOME/.claude/settings.json" "$DIR/.claude/settings.local.json" 2>/dev/null | sed -n 's/.*"ANTHROPIC_AUTH_TOKEN"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1; }
ARCH="$(uname -m)"

# ===================================================================================
echo ""
printf "${B}==== AI Shift Training - Hackathon Setup ====${N}\n"
if [ "$MODE" = "check" ]; then echo "Check mode: nothing gets installed or changed."
else
  echo "Setup has 9 steps. It takes about 10-15 minutes (up to 30 minutes on a brand-new Mac)."
  act "Keep this window open and your Mac plugged in. Don't close the lid."
fi

# ---------- STEP 1: key ----------
STEP="reading your key"
if [ "$MODE" = "check" ]; then
  KEY="$(existing_key)"
  if [ -z "$KEY" ]; then
    act "No key found yet. Paste your key to test it, or just press Return to skip."
    printf "Key: "; IFS= read -rs KEY < /dev/tty; echo
  fi
else
  step "1 of 9" "Your hackathon key (about 1 minute)"
  if [ -n "${HACKATHON_KEY:-}" ]; then KEY="$HACKATHON_KEY"
  else
    echo "1. Open the email we sent you and copy your key. It starts with sk-or-v1-"
    echo "2. Click in this window and press Cmd + V to paste it."
    echo "3. Press Return."
    fixmsg "You will NOT see the key when you paste. That's normal. Just press Return."
    printf "Key: "; IFS= read -rs KEY < /dev/tty; echo
  fi
fi
KEY="$(printf '%s' "$KEY" | tr -d '[:space:]')"
if [ "$MODE" = "install" ]; then
  case "$KEY" in
    sk-or-v1-*) ok "Key received (it ends in ...${KEY: -4})" ;;
    "") fail K1 "No key was pasted. Run setup again. When it asks for the key, press Cmd + V, then Return." "$SETUP_CMD" ;;
    *)  fail K1 "That is not the hackathon key. Copy the WHOLE key from your email (it starts with sk-or-v1-), then run setup again." "$SETUP_CMD" ;;
  esac
fi

# From here on, what you see is also saved in claude-hackathon/setup-log.txt (the key is never saved).
exec > >(tee -a "$LOG") 2>&1
echo ""; echo "---- $(date) mode=$MODE user=$(whoami) macOS=$(sw_vers -productVersion 2>/dev/null) arch=$ARCH ----"

# ---------- STEP 2: check the Mac ----------
STEP="checking your Mac"
[ "$MODE" = "install" ] && step "2 of 9" "Checking your Mac (about 1 minute)"
[ "$MODE" = "check" ] && step "check" "Checking your Mac (about 1 minute)"
PROBLEMS=""
add_problem() { PROBLEMS="$PROBLEMS
${TAG_FAIL} FAIL $1 ${N} ${FIX}$2${N}"; }

MACOS="$(sw_vers -productVersion 2>/dev/null)"
if [ "${MACOS%%.*}" -ge "$MIN_MACOS" ] 2>/dev/null; then ok "macOS $MACOS"
else bad "macOS $MACOS is too old"; add_problem P1 "Your Mac needs macOS 13 or newer. Update it (System Settings > General > Software Update) or use another laptop."; fi

if [ "$ARCH" = "x86_64" ] && [ "$(sysctl -in hw.optional.arm64 2>/dev/null)" = "1" ]; then
  bad "Terminal is in Rosetta mode"
  add_problem P6 "Quit Terminal. Open Finder > Applications > Utilities. Right-click Terminal > Get Info. Untick 'Open using Rosetta'. Then run setup again."
else ok "Processor: $ARCH"; fi

IS_ADMIN=0; id -Gn | tr ' ' '\n' | grep -qx admin && IS_ADMIN=1
FREE_GB=$(( $(df -k "$HOME" | awk 'NR==2{print $4}') / 1024 / 1024 ))
if [ "$FREE_GB" -ge "$MIN_DISK_GB" ]; then ok "Free space: ${FREE_GB} GB"
else bad "Free space: only ${FREE_GB} GB"; add_problem P3 "Your Mac needs 5 GB of free space. Delete big files or empty the Bin, then run setup again."; fi

if ! net_ok; then wait_net || net_fail; fi
BLOCKED=""
for h in github.com api.github.com raw.githubusercontent.com objects.githubusercontent.com claude.ai openrouter.ai registry.npmjs.org nodejs.org; do
  curl -sS -o /dev/null -m 20 -I "https://$h" >/dev/null 2>&1 || curl -sS -o /dev/null -m 20 -I "https://$h" >/dev/null 2>&1 || BLOCKED="$BLOCKED $h"
done
if [ -z "$BLOCKED" ]; then ok "Internet: all download sites work"
else bad "Internet: these sites are blocked:$BLOCKED"; add_problem P4 "Your internet blocks some download sites. Connect to a different Wi-Fi or your phone's hotspot, then run setup again."; fi

SRV="$(curl -sI -m 15 https://github.com 2>/dev/null | tr -d '\r' | sed -n 's/^[Dd]ate: //p')"
if [ -n "$SRV" ]; then
  S=$(LC_ALL=C date -j -u -f "%a, %d %b %Y %T GMT" "$SRV" +%s 2>/dev/null || echo 0)
  L=$(date -u +%s); D=$(( S > L ? S - L : L - S ))
  if [ "$S" -gt 0 ] && [ "$D" -gt 600 ]; then bad "Clock is wrong"
    add_problem P5 "Open System Settings > General > Date & Time and turn on 'Set time and date automatically'. Then run setup again."
  else ok "Clock"; fi
fi

if [ -n "$KEY" ]; then
  CODE=""; BODY=""
  for t in 1 2 3; do
    RESP="$(curl -sS -m 30 -w $'\n%{http_code}' -H "Authorization: Bearer $KEY" https://openrouter.ai/api/v1/key 2>/dev/null)"
    CODE="$(printf '%s' "$RESP" | tail -n1)"; BODY="$(printf '%s' "$RESP" | sed '$d')"
    case "$CODE" in 200|401|403) break ;; esac
    wait_net || break; sleep 5
  done
  REM="$(printf '%s' "$BODY" | json_num limit_remaining)"
  if [ "$CODE" = "200" ]; then
    if [ -n "$REM" ] && awk "BEGIN{exit !($REM <= 0)}"; then bad "Your key has no credit left"
      add_problem K3 "Your key has no credit. Paste a screenshot into the Setup Helper chat or tell the organisers, so they can top it up."
    else ok "Your key works (ends in ...${KEY: -4})"; fi
  elif [ "$CODE" = "401" ] || [ "$CODE" = "403" ]; then bad "Your key was not accepted"
    add_problem K2 "Copy the key again from your LATEST email and run setup again. Still not accepted? Ask in the Setup Helper chat for a new key."
  else bad "Could not check your key"
    add_problem K4 "Setup could not reach the AI service. Connect to a different Wi-Fi or your phone's hotspot, then run setup again."
  fi
else warn "Key not checked (none given)"; fi

find_brew; check_tools
[ -n "$GIT" ] && ok "Git is already installed" || warn "Git is not installed yet"
if [ "$MODE" = "install" ] && [ -z "$GIT" ] && [ "$IS_ADMIN" = 0 ]; then
  add_problem P2 "This Mac account is not an administrator, and Git needs one to install. Log out, log in with the administrator account (System Settings > Users & Groups shows 'Admin'), then run setup again."
fi

if [ -n "$PROBLEMS" ]; then
  printf "\n${B}Please fix these, then run setup again:${N}%s\n" "$PROBLEMS"
  if [ "$MODE" = "install" ]; then FAILED=1; show_cmd "$SETUP_CMD"; printf "Stuck? Paste a screenshot into the Setup Helper chat: ${B}%s${N}\n" "$HELP_CHAT"; sleep 1; exit 1; fi
fi

# ===================================================================================
if [ "$MODE" = "install" ]; then

# ---------- STEP 3: Git (needed) ----------
STEP="installing Git"
step "3 of 9" "Git (already there: a few seconds / new Mac: about 10-15 minutes)"
if [ -n "$GIT" ]; then ok "Git is already installed. Skipping this step."
else
  echo "Git comes with Apple's developer tools. Setup installs them with Homebrew."
  act "Type your Mac login password and press Return."
  fixmsg "You will NOT see the password while you type. That's normal."
  sudo -v < /dev/tty || fail H3 "Your Mac password was not accepted. Use the password you log in to this Mac with.
No password on this Mac? Set one in System Settings > Users & Groups. Then run setup again." "$SETUP_CMD"
  ( while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
  if [ -z "$BREW" ]; then
    printf "${INST}Installing Homebrew and Apple's developer tools (about 10-15 minutes, up to 30 on a new Mac)...${N}\n"
    act "It can look stuck for a few minutes. That's normal. Keep the window open."
    inst_brew() { HBI="$(mktemp)"; download https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh "$HBI" && NONINTERACTIVE=1 /bin/bash "$HBI" < /dev/null; r=$?; rm -f "$HBI"; return $r; }
    retry "Installing Homebrew" inst_brew || true
    find_brew
    [ -n "$BREW" ] && { grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($BREW shellenv)\"" >> "$HOME/.zprofile"; }
  fi
  check_tools
  if [ -z "$GIT" ]; then
    # Fallback: Apple's own installer for the developer tools (a window opens).
    printf "${INST}Trying Apple's installer instead...${N}\n"
    xcode-select --install >/dev/null 2>&1 || true
    act "A window may pop up asking to install 'command line developer tools'. Click Install, then Agree."
    act "Wait until that window says it's done (about 10 minutes). Then press Return here."
    IFS= read -r _ < /dev/tty
    check_tools
  fi
  if [ -z "$GIT" ]; then
    net_ok || net_fail
    fail T1 "Git could not be installed. Run this in Terminal, click Install in the window that opens, wait until it's done, then run setup again:
  xcode-select --install" "$SETUP_CMD"
  fi
  ok "Git installed"
fi

# ---------- STEP 4: GitHub CLI (needed to publish your website) ----------
STEP="installing GitHub CLI"
step "4 of 9" "GitHub tool (about 1 minute)"
if [ -n "$GH" ]; then ok "GitHub tool is already installed. Skipping this step."
else
  case "$ARCH" in arm64) GA=arm64 ;; *) GA=amd64 ;; esac
  GZ="$TOOLS/gh.zip"
  get_gh() { download "https://github.com/cli/cli/releases/download/v$GH_VERSION/gh_${GH_VERSION}_macOS_$GA.zip" "$GZ" \
             && rm -rf "$TOOLS/gh" && mkdir -p "$TOOLS/gh" && unzip -oq "$GZ" -d "$TOOLS/gh" \
             && ln -sf "$TOOLS/gh/gh_${GH_VERSION}_macOS_$GA/bin/gh" "$HOME/.local/bin/gh"; }
  printf "${INST}Downloading the GitHub tool...${N}\n"
  retry "Downloading the GitHub tool" get_gh || true
  rm -f "$GZ"; check_tools
  if [ -z "$GH" ] && [ -n "$BREW" ] && [ -w "$("$BREW" --prefix)/bin" ]; then
    printf "${INST}Trying Homebrew instead...${N}\n"
    HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 "$BREW" install gh < /dev/null || true
    check_tools
  fi
  if [ -z "$GH" ]; then net_ok || net_fail
    fail T2 "The GitHub tool could not be installed. Run setup again. If it fails again, paste a screenshot into the Setup Helper chat." "$SETUP_CMD"; fi
  ok "GitHub tool installed"
fi

# ---------- STEP 5: Node.js and Python (nice to have, used by the design skill) ----------
STEP="installing Node.js and Python"
step "5 of 9" "Node.js and Python (about 2-4 minutes)"
if [ -n "$NODE" ]; then ok "Node.js is already installed. Skipping it."
else
  case "$ARCH" in arm64) NA=arm64 ;; *) NA=x64 ;; esac
  get_node() {
    F="$(curl -fsSL "https://nodejs.org/dist/$NODE_LINE/SHASUMS256.txt" | awk "/darwin-$NA.tar.gz/{print \$2}")" && [ -n "$F" ] \
      && download "https://nodejs.org/dist/$NODE_LINE/$F" "$TOOLS/node.tgz" \
      && rm -rf "$TOOLS/node" && mkdir -p "$TOOLS/node" && tar -xzf "$TOOLS/node.tgz" -C "$TOOLS/node" --strip-components=1 \
      && ln -sf "$TOOLS/node/bin/node" "$TOOLS/node/bin/npm" "$TOOLS/node/bin/npx" "$TBIN/"
  }
  printf "${INST}Downloading Node.js...${N}\n"
  retry "Downloading Node.js" get_node || true
  rm -f "$TOOLS/node.tgz"; check_tools
  [ -n "$NODE" ] && ok "Node.js installed" || note_skip "Node.js did not install. Setup continues without it (the design skill will be skipped)."
fi
if [ -n "$PY" ]; then ok "Python is already installed. Skipping it."
else
  case "$ARCH" in arm64) UA=aarch64 ;; *) UA=x86_64 ;; esac
  get_py() {
    download "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-$UA-apple-darwin.tar.gz" "$TOOLS/uv.tgz" \
      && tar -xzf "$TOOLS/uv.tgz" -C "$TOOLS" && cp "$TOOLS/uv-$UA-apple-darwin/uv" "$TBIN/uv" \
      && UV_PYTHON_INSTALL_DIR="$TOOLS/python" "$TBIN/uv" python install 3.12 --no-bin < /dev/null \
      && P="$(UV_PYTHON_INSTALL_DIR="$TOOLS/python" "$TBIN/uv" python find 3.12)" && [ -x "$P" ] \
      && ln -sf "$P" "$TBIN/python3.12" && ln -sf "$P" "$TBIN/python3"
  }
  printf "${INST}Downloading Python...${N}\n"
  retry "Downloading Python" get_py || true
  rm -rf "$TOOLS/uv.tgz" "$TOOLS"/uv-*-apple-darwin; check_tools
  [ -n "$PY" ] && ok "Python installed" || note_skip "Python did not install. Setup continues without it."
fi

# ---------- STEP 6: Claude Code (needed) ----------
STEP="installing Claude Code"
step "6 of 9" "Claude Code (about 1-2 minutes)"
CLAUDE="$HOME/.local/bin/claude"
HAVE_CC="$("$CLAUDE" --version 2>/dev/null | awk '{print $1}')"
if [ -n "$HAVE_CC" ] && ver_ge "$HAVE_CC" "$CC_VERSION"; then ok "Claude Code $HAVE_CC is already installed. Skipping this step."
else
  get_cc() { CCI="$(mktemp)"; download https://claude.ai/install.sh "$CCI" && { bash "$CCI" "$CC_VERSION" < /dev/null || bash "$CCI" latest < /dev/null; }; r=$?; rm -f "$CCI"; [ $r = 0 ] && [ -x "$CLAUDE" ]; }
  printf "${INST}Downloading Claude Code...${N}\n"
  retry "Installing Claude Code" get_cc || true
  if [ ! -x "$CLAUDE" ]; then net_ok || net_fail
    fail C1 "Claude Code could not be installed. Run setup again. If it fails again, paste a screenshot into the Setup Helper chat." "$SETUP_CMD"; fi
  "$CLAUDE" --version >/dev/null 2>&1 || fail C2 "Claude Code is installed but won't start. Restart your Mac, then run setup again." "$SETUP_CMD"
  ok "Claude Code installed"
fi

# ---------- STEP 7: design skill (nice to have) ----------
STEP="installing the design skill"
step "7 of 9" "Design skill (about 1 minute)"
mkdir -p "$DIR/.claude"
if [ -f "$HOME/.claude/skills/design-system/SKILL.md" ]; then ok "Design skill is already installed. Skipping this step."
elif [ -z "$NODE" ]; then note_skip "Design skill skipped (it needs Node.js). Claude Code still works."
else
  get_skill() { "$(dirname "$NODE")/npm" install -g --prefix "$HOME/.local" "ui-ux-pro-max-cli@$UIPRO_VERSION" --no-fund --no-audit < /dev/null \
                && ( cd "$DIR" && { "$HOME/.local/bin/uipro" init --ai claude --global --force --offline < /dev/null || "$HOME/.local/bin/uipro" init --ai claude --global --force < /dev/null; } ) \
                && [ -f "$HOME/.claude/skills/ui-ux-pro-max/SKILL.md" ] && rm -rf "$DIR/.claude/skills"; }
  printf "${INST}Installing the design skill...${N}\n"
  retry "Installing the design skill" get_skill && ok "Design skill installed" \
    || note_skip "The design skill did not install. Setup continues without it. Claude Code still works."
fi

# ---------- STEP 8: settings ----------
STEP="saving your settings"
step "8 of 9" "Saving your settings (a few seconds)"
# Sandbox is off on purpose: gh (used to publish) can fail inside the Mac sandbox, and Windows has none.
# The key, model and safety rules go in Claude Code's USER settings (~/.claude/settings.json),
# so they work in every folder. Anything the student already had in that file is kept.
mkdir -p "$HOME/.claude"
CS="$HOME/.claude/settings.json"; HS="$TOOLS/hackathon-settings.json"
[ -s "$CS" ] && cp "$CS" "$CS.hackathon-backup" 2>/dev/null
umask 077
cat > "$HS" <<JSON
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://openrouter.ai/api",
    "ANTHROPIC_AUTH_TOKEN": "$KEY",
    "ANTHROPIC_API_KEY": "",
    "ANTHROPIC_MODEL": "$MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$MODEL",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$MODEL",
    "CLAUDE_CODE_SUBAGENT_MODEL": "$MODEL",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "200000",
    "DISABLE_AUTOUPDATER": "1"
  },
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "deny": [
      "Bash(sudo:*)", "Bash(rm -rf:*)", "Bash(rm -r:*)", "Bash(rmdir:*)",
      "Bash(del:*)", "Bash(Remove-Item:*)", "Bash(format:*)", "Bash(shutdown:*)",
      "Bash(chmod -R:*)", "Bash(chown:*)",
      "Bash(git push --force:*)", "Bash(git push -f:*)", "Bash(gh repo delete:*)",
      "Read(~/.ssh/**)", "Read(~/.aws/**)", "Edit(~/.bashrc)", "Edit(~/.zshrc)"
    ]
  }
}
JSON
MERGED=0
if [ -n "$NODE" ] && "$NODE" -e '
const fs=require("fs"), f=process.argv[1], h=process.argv[2];
let j={}; try { j=JSON.parse(fs.readFileSync(f,"utf8")); } catch(e) {}
const n=JSON.parse(fs.readFileSync(h,"utf8"));
j.env=Object.assign({}, j.env, n.env); j.permissions=j.permissions||{};
j.permissions.disableBypassPermissionsMode=n.permissions.disableBypassPermissionsMode;
j.permissions.deny=[...new Set([...(j.permissions.deny||[]), ...n.permissions.deny])];
fs.writeFileSync(f, JSON.stringify(j,null,2));' "$CS" "$HS"; then MERGED=1
elif [ -n "$PY" ] && "$PY" - "$CS" "$HS" <<'PYEOF'
import json, sys
f, h = sys.argv[1], sys.argv[2]
try: j = json.load(open(f))
except Exception: j = {}
n = json.load(open(h))
j.setdefault("env", {}).update(n["env"]); p = j.setdefault("permissions", {})
p["disableBypassPermissionsMode"] = n["permissions"]["disableBypassPermissionsMode"]
p["deny"] = list(dict.fromkeys(p.get("deny", []) + n["permissions"]["deny"]))
json.dump(j, open(f, "w"), indent=2)
PYEOF
then MERGED=1; fi
[ "$MERGED" = 1 ] || cp "$HS" "$CS"
chmod 600 "$CS"; rm -f "$HS"
umask 022
rm -f "$DIR/.claude/settings.local.json" "$DIR/CLAUDE.md"   # old per-folder copies from earlier setups
# Rules for every folder: ~/.claude/CLAUDE.md (the student's own notes in that file are kept)
CM="$HOME/.claude/CLAUDE.md"; touch "$CM"
sed -i '' '/<!-- >>> hackathon rules >>> -->/,/<!-- <<< hackathon rules <<< -->/d' "$CM"
cat >> "$CM" <<'MD'
<!-- >>> hackathon rules >>> -->
# Hackathon rules for the assistant
- Work in the folder Claude was started in. Create and edit files only inside it. Never change or delete files outside it.
- If you were started in the home folder, Desktop, Documents or Downloads itself, first make a new folder for the project (e.g. bakery/) and work inside it.
- The user's own files (photos, PDFs, logos) may be in another folder. If you can't find a file they mention, say in one line: "Drag the file into this window and press Enter", then copy it into the project's assets/ folder. You may read and copy files from anywhere into the project folder.
- If something is still missing (e.g. a photo), use a placeholder, finish the page, and say in one line how to add the real one later.
- Finish the task, then stop. Don't end with a list of options or "What do you want next?". At most, suggest one next step in one line.
- Never run commands that delete folders, change system settings, or install software globally. Ask first if unsure.
- Keep answers short. Make small changes, then show the result.
- Build with plain HTML/CSS/JS unless the user asks for a framework. No build step, no server.
- Use the ui-ux-pro-max skill for design choices (styles, colours, fonts) if it is installed. On Windows, if python3 fails, use python.
- Put every project in its own folder with index.html at the top of that folder.
- Use relative paths only (e.g. about.html, images/logo.png). Never use C:\ or /Users/ paths.
- Save app data in the browser (localStorage). No databases or backend.
- To show a project, open its index.html in the user's browser.
- To publish a project when asked: work ONLY inside that project's folder. Run git init -b main, git add ., git commit, then gh repo create <folder-name> --public --source=. --push, then enable GitHub Pages with: gh api -X POST repos/<owner>/<repo>/pages -f "source[branch]=main" -f "source[path]=/" . Give the user the link https://<owner>.github.io/<repo>/ (it can take 2 minutes to go live).
- Never run git init in the home folder, Desktop, Documents, Downloads or the claude-hackathon folder itself. Never commit or upload .claude folders, API keys or setup-log.txt. Never force-push, never delete repositories.
- When the user starts a new, unrelated task, remind them to type /clear first.
- Never ask for or store passwords, API keys, or personal data in code.
<!-- <<< hackathon rules <<< -->
MD
printf '.claude/\nsetup-log.txt\n' > "$DIR/.gitignore"
# Skip Claude's first-run screens (login + "do you trust this folder?")
[ -f "$HOME/.claude.json" ] && cp "$HOME/.claude.json" "$HOME/.claude.json.hackathon-backup" 2>/dev/null
if [ -n "$NODE" ]; then
  "$NODE" -e '
const fs=require("fs"), f=process.argv[1], d=process.argv[2];
let j={}; try { j=JSON.parse(fs.readFileSync(f,"utf8")); } catch(e) {}
j.hasCompletedOnboarding=true; j.projects=j.projects||{};
j.projects[d]=Object.assign({}, j.projects[d], {hasTrustDialogAccepted:true});
fs.writeFileSync(f, JSON.stringify(j,null,2));' "$HOME/.claude.json" "$DIR" || true
elif [ ! -s "$HOME/.claude.json" ]; then
  printf '{"hasCompletedOnboarding": true, "projects": {"%s": {"hasTrustDialogAccepted": true}}}\n' "$DIR" > "$HOME/.claude.json"
fi
# Typing "claude" anywhere opens the hackathon folder, with the hackathon tools on PATH
BREWBIN=""; [ -n "$BREW" ] && BREWBIN="$("$BREW" --prefix)/bin:"
for RC in "$HOME/.zshrc" "$HOME/.bash_profile"; do
  touch "$RC"
  sed -i '' '/# >>> hackathon claude >>>/,/# <<< hackathon claude <<</d' "$RC"
  cat >> "$RC" <<RCEOF
# >>> hackathon claude >>>
export PATH="\$HOME/.local/bin:\$PATH"
claude() { ( [ "\$PWD" = "\$HOME" ] && cd "\$HOME/claude-hackathon"; printf '\\033[1;30;106m Claude is working in: %s  (to use a photo or PDF from another folder, drag it into this window) \\033[0m\\n' "\$PWD"; PATH="\$HOME/.local/hackathon-tools/bin:\$HOME/.local/bin:$BREWBIN\$PATH" command claude "\$@" ); }
# <<< hackathon claude <<<
RCEOF
done
ok "Settings saved"

fi  # end of install-only steps

# ===================================================================================
# ---------- STEP 9: test the AI, then connect GitHub ----------
STEP="testing the AI"
[ "$MODE" = "install" ] && step "9 of 9" "Testing the AI and connecting GitHub (about 2-3 minutes)"
find_brew; check_tools
CLAUDE="$HOME/.local/bin/claude"
CL_OK=0; CL_CODE=""; CL_MSG=""
if "$CLAUDE" --version >/dev/null 2>&1; then
  printf "${INST}Asking the AI a test question...${N}\n"
  for attempt in 1 2 3; do
    T="$(mktemp)"
    ( cd "$DIR" && PATH="$TBIN:$HOME/.local/bin:$PATH" "$CLAUDE" -p "Reply with exactly: SETUP OK" ) > "$T" 2>&1 < /dev/null &
    P=$!; i=0
    while kill -0 $P 2>/dev/null && [ $i -lt 180 ]; do sleep 1; i=$((i+1)); done
    TIMED=0; kill -0 $P 2>/dev/null && { kill $P 2>/dev/null; TIMED=1; }
    wait $P 2>/dev/null
    OUT="$(grep -v 'unrecognized_model' "$T")"; rm -f "$T"
    if printf '%s' "$OUT" | grep -q "SETUP OK"; then CL_OK=1; break; fi
    if printf '%s' "$OUT" | grep -Eqi '401|unauthori|invalid.*key|user not found|no auth|402|credit|insufficient'; then break; fi
    if [ $attempt -lt 3 ]; then
      printf "${FIX}The AI did not answer (try %s of 3). Checking internet and trying again...${N}\n" "$attempt"
      wait_net || break; sleep 20
    fi
  done
  if [ "$CL_OK" = 1 ]; then ok "The AI answered (key ends in ...${KEY: -4})"
  else
    if   printf '%s' "$OUT" | grep -Eqi '401|unauthori|invalid.*key|user not found|no auth'; then CL_CODE=C4; CL_MSG="Your key was not accepted. Copy the key from your LATEST email and run setup again."
    elif printf '%s' "$OUT" | grep -Eqi '402|credit|insufficient|payment'; then CL_CODE=C5; CL_MSG="Your key has no credit left. Paste a screenshot into the Setup Helper chat or tell the organisers."
    elif printf '%s' "$OUT" | grep -Eqi '429|rate.?limit|too many|overloaded'; then CL_CODE=C6; CL_MSG="The AI is very busy right now. Wait 5 minutes, then run setup again."
    elif [ "$TIMED" = 1 ] || printf '%s' "$OUT" | grep -Eqi 'ENOTFOUND|ECONNREFUSED|ETIMEDOUT|ECONNRESET|certificate|network|fetch failed'; then CL_CODE=N1; CL_MSG="Your internet stopped working during the AI test. Connect to a different Wi-Fi or your phone's hotspot, then run setup again."
    else CL_CODE=C3; CL_MSG="The AI test did not work. Paste a screenshot of this window into the Setup Helper chat."; fi
    bad "The AI did not answer ($CL_CODE)"
    echo "  Details (for the helpers):"; printf '%s\n' "$OUT" | tail -n 10 | sed 's/^/    /'
  fi
fi

STEP="connecting GitHub"
GH_USER=""
if [ -n "$GH" ]; then
  if ! "$GH" auth status >/dev/null 2>&1 && [ "$MODE" = "install" ]; then
    for t in 1 2 3; do
      printf "\n${INST}Connect your GitHub account (about 2 minutes)${N}\n"
      act "1. Press Return. GitHub should open in your browser by itself."
      echo "   If the browser does NOT open, open this link yourself:  https://github.com/login/device"
      act "2. Make sure you are logged in to GitHub in the browser."
      act "3. Click the green 'Continue' button."
      act "4. Type the 8-character code shown below in this window (it looks like ABCD-1234)."
      act "5. Click the green 'Authorize github' button. Then come back to this window."
      echo "   If it asks 'Authenticate Git with your GitHub credentials?', press Return (Yes)."
      echo ""
      "$GH" auth login -h github.com -p https -w < /dev/tty || true
      "$GH" auth status >/dev/null 2>&1 && break
      if [ $t -lt 3 ]; then
        fixmsg "GitHub is not connected yet (try $t of 3)."
        act "Press Return to try the GitHub step again."
        IFS= read -r _ < /dev/tty
      fi
    done
  fi
  if "$GH" auth status >/dev/null 2>&1; then
    "$GH" auth setup-git >/dev/null 2>&1 || true
    GH_USER="$("$GH" api user -q .login 2>/dev/null)"
    if [ -n "$GH_USER" ] && [ "$MODE" = "install" ] && [ -z "$(git config --global user.name 2>/dev/null)" ]; then
      git config --global user.name "$GH_USER"
      git config --global user.email "$("$GH" api user -q .id)+$GH_USER@users.noreply.github.com"
    fi
  fi
fi

# ---------- Result ----------
printf "\n${STEPC} RESULT ${N}\n"
ALL=1
[ -n "$GIT" ] && ok "Git" || { bad "Git (T1)"; ALL=0; }
[ -n "$GH" ] && ok "GitHub tool" || { bad "GitHub tool (T2)"; ALL=0; }
"$CLAUDE" --version >/dev/null 2>&1 && ok "Claude Code $("$CLAUDE" --version | awk '{print $1}')" || { bad "Claude Code (C1)"; ALL=0; }
grep -q '"ANTHROPIC_AUTH_TOKEN": *"sk-or-' "$HOME/.claude/settings.json" 2>/dev/null && ok "Your settings (work in every folder)" || { bad "Your settings (run setup)"; ALL=0; }
[ "$CL_OK" = 1 ] && ok "The AI works" || { bad "The AI (${CL_CODE:-not tested})"; ALL=0; }
[ -n "$GH_USER" ] && ok "GitHub account: ${B}$GH_USER${N}  (not you? run  gh auth logout  then run setup again)" || { bad "GitHub not connected (G1)"; ALL=0; }
[ -n "$NODE" ] && ok "Node.js" || warn "Node.js not installed (optional)"
[ -n "$PY" ] && ok "Python" || warn "Python not installed (optional)"
[ -f "$HOME/.claude/skills/ui-ux-pro-max/SKILL.md" ] && ok "Design skills (UI/UX Pro Max)" || warn "Design skill not installed (optional)"

echo ""
if [ "$ALL" = 1 ]; then
  printf "${DONE}                                  ${N}\n"
  printf "${DONE}     Your Setup Is Complete       ${N}\n"
  printf "${DONE}                                  ${N}\n\n"
  printf "${G}${B}PASS${N}\n"
  act "Take a screenshot of this window and submit it in the form from your email."
  if [ "$MODE" = "install" ]; then
    echo ""
    echo "To start Claude Code:"
    echo "  1. Quit Terminal (press Cmd + Q)."
    echo "  2. Open Terminal again."
    echo "  3. Type  claude  and press Return."
    echo ""
    echo "Your key works in every folder. In a new Terminal, claude starts in ~/claude-hackathon."
    echo "To work somewhere else, go to that folder first (e.g.  cd Desktop/my-site ), then type  claude"
    echo "If Claude asks 'Do you trust the files in this folder?', press Enter."
  fi
  FAILED=1; sleep 1; exit 0
fi
if [ "$MODE" = "check" ]; then
  printf "${TAG_WARN} CHECK DONE ${N} ${FIX}Anything marked FAIL above is not ready. Run setup to fix it.${N}\n"
  show_cmd "$SETUP_CMD"; FAILED=1; sleep 1; exit 0
fi
[ -n "$CL_CODE" ] && { [ "$CL_CODE" = N1 ] && net_fail; fail "$CL_CODE" "$CL_MSG" "$SETUP_CMD"; }
[ -z "$GH_USER" ] && fail G1 "GitHub is not connected yet. Run setup again and do the GitHub steps (press Return, click the green buttons, type the code).
No GitHub account? Make one at github.com, confirm your email, then run setup again." "$SETUP_CMD"
fail X2 "Something above is marked FAIL. Run setup again." "$SETUP_CMD"
}

main "$@"
