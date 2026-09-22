#!/bin/bash
# AI Shift Training Hackathon - one-command setup (Mac)
#
#   Install:  curl -fsSL https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-mac.sh | bash
#   Check:    curl -fsSL https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-mac.sh | bash -s -- --check
#
# Installs Homebrew (+ Apple command line tools), Git, GitHub CLI, Node.js, Python 3.12,
# Claude Code and the UI/UX Pro Max skill, then connects Claude Code to the hackathon key.
#
# Every run ends in PASS (with a checklist) or FAIL <code> with one sentence saying what to do.
# Codes are listed in TROUBLESHOOTING.md. Safe to re-run any number of times.
# Written for macOS /bin/bash 3.2 (no bash 4 features).

# The whole script lives inside main() so bash reads all of it before running anything.
# (With "curl | bash", a command that reads input could otherwise eat the rest of the script,
# and a dropped connection would run half a script.)
main() {
set -u

# ---------- Pinned versions (tested for this event) ----------
CC_VERSION="2.1.278"          # Claude Code
UIPRO_VERSION="2.2.3"         # uipro-cli (UI/UX Pro Max skill)
MODEL="openai/gpt-5-mini"
MIN_MACOS=13; MIN_NODE=18; MIN_GH="2.40.0"; MIN_DISK_GB=5

DIR="$HOME/claude-hackathon"
LOG="$DIR/setup-log.txt"
MODE="install"; [ "${1:-}" = "--check" ] && MODE="check"
STEP="starting"; FAILED=0

G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; C=$'\033[36m'; B=$'\033[1m'; N=$'\033[0m'
ok()   { printf "  ${G}OK${N}   %s\n" "$1"; }
bad()  { printf "  ${R}FAIL${N} %s\n" "$1"; }
warn() { printf "  ${Y}NOTE${N} %s\n" "$1"; }
say()  { printf "\n${C}%s${N}\n" "$1"; }
fail() {  # fail CODE "what to do"
  FAILED=1
  printf "\n${R}${B}FAIL %s${N}\n${B}%s${N}\n\n" "$1" "$2"
  printf "Take a screenshot of this window and send it to the help group.\n"
  printf "If you can, also send this file: claude-hackathon/setup-log.txt\n"
  sleep 1; exit 1
}
# Unexpected stop (closed lid, Ctrl+C, a crash): still tell the student what to do.
trap 'st=$?; if [ $st -ne 0 ] && [ "$FAILED" = 0 ]; then printf "\n${R}${B}FAIL X1${N}\n${B}Setup stopped during: %s. Run the same command again. It continues where it stopped.${N}\nIf it stops again, send a screenshot of this window to the help group.\n" "$STEP"; fi' EXIT

mkdir -p "$DIR" || fail P8 "Setup could not create the folder claude-hackathon in your home folder. Restart the Mac and run the command again."

# ---------- Must run in the Terminal app, with a keyboard ----------
if ! : < /dev/tty 2>/dev/null; then
  fail P7 "Run this command in the Terminal app (press Cmd + Space, type Terminal, press Return), not in another app."
fi

# ---------- Helpers ----------
ver_ge() { # ver_ge HAVE NEED  -> true if HAVE >= NEED
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)" = "$2" ]
}
have_clt() { xcode-select -p >/dev/null 2>&1; }
# /usr/bin/git and /usr/bin/python3 are Apple stubs that pop up an install window if the
# command line tools are missing. Only count them if the tools are really there.
real_cmd() {
  p="$(command -v "$1" 2>/dev/null)" || return 1
  case "$p" in /usr/bin/*) have_clt || return 1 ;; esac
  printf '%s' "$p"
}
node_major() { "$1" -v 2>/dev/null | sed 's/^v//' | cut -d. -f1; }
json_num() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\(-\{0,1\}[0-9.eE+-]*\).*/\1/p" | head -n1; }

find_brew() {
  BREW="$(command -v brew 2>/dev/null || true)"
  [ -z "$BREW" ] && [ -x /opt/homebrew/bin/brew ] && BREW=/opt/homebrew/bin/brew
  [ -z "$BREW" ] && [ -x /usr/local/bin/brew ] && BREW=/usr/local/bin/brew
  if [ -n "$BREW" ]; then
    BREW_PREFIX="$("$BREW" --prefix 2>/dev/null)"
    BREW_REPO="$("$BREW" --repository 2>/dev/null)"
    eval "$("$BREW" shellenv 2>/dev/null)"
  fi
}

# Which tools are missing or too old? Sets NEED (brew formula names).
check_tools() {
  NEED=""
  GIT="$(real_cmd git || true)"; [ -z "$GIT" ] && NEED="$NEED git"
  GH="$(command -v gh 2>/dev/null || true)"
  if [ -z "$GH" ] || ! ver_ge "$("$GH" --version 2>/dev/null | head -n1 | awk '{print $3}')" "$MIN_GH"; then NEED="$NEED gh"; fi
  NODE="$(command -v node 2>/dev/null || true)"
  if [ -z "$NODE" ] || [ "$(node_major "$NODE")" -lt "$MIN_NODE" ] 2>/dev/null; then NEED="$NEED node"; fi
  PY=""
  for c in python3.12 python3.13 python3.11 python3.10 python3; do
    p="$(real_cmd "$c" || true)"
    if [ -n "$p" ] && "$p" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' >/dev/null 2>&1; then PY="$p"; break; fi
  done
  [ -z "$PY" ] && NEED="$NEED python@3.12"
  NEED="$(echo $NEED)"   # trim
  return 0
}

read_key() {
  if [ -n "${HACKATHON_KEY:-}" ]; then KEY="$HACKATHON_KEY"
  else
    printf "Paste your personal hackathon key (starts with sk-or-).\nPaste with Cmd + V, then press Return. Nothing shows while you paste. That's normal.\nKey: "
    IFS= read -rs KEY < /dev/tty; echo
  fi
  KEY="$(printf '%s' "$KEY" | tr -d '[:space:]')"
}

existing_key() {
  sed -n 's/.*"ANTHROPIC_AUTH_TOKEN"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$DIR/.claude/settings.local.json" 2>/dev/null | head -n1
}

# ===================================================================================
echo ""
echo "${B}== AI Shift Training hackathon setup ==${N}"
if [ "$MODE" = "check" ]; then echo "Check mode: nothing is installed or changed."; else echo "This takes 10-30 minutes. Keep this window open and your laptop plugged in."; fi

# ---------- 1. Key ----------
STEP="reading your key"
if [ "$MODE" = "check" ]; then
  KEY="$(existing_key)"
  if [ -z "$KEY" ]; then
    printf "No key found on this Mac yet. Paste your key to test it, or just press Return to skip.\nKey: "
    IFS= read -rs KEY < /dev/tty; echo; KEY="$(printf '%s' "$KEY" | tr -d '[:space:]')"
  fi
else
  read_key
  case "$KEY" in
    sk-or-v1-*) printf "Key received (ends in ...%s)\n" "${KEY: -4}" ;;
    "") fail K1 "No key was pasted. Run the command again. When it asks for the key, press Cmd + V, then Return." ;;
    *)  fail K1 "That is not a hackathon key. Copy the whole key from your email (it starts with sk-or-v1-) and run the command again." ;;
  esac
fi

# From here on, everything shown is also saved to setup-log.txt (the key is never shown).
exec > >(tee -a "$LOG") 2>&1
echo ""; echo "---- $(date) mode=$MODE user=$(whoami) ----"

# ---------- 2. Preflight: find every problem before installing anything ----------
STEP="checking your Mac"
say "Checking your Mac..."
PROBLEMS=""
add_problem() { PROBLEMS="$PROBLEMS
${R}${B}FAIL $1${N}  $2"; }

MACOS="$(sw_vers -productVersion 2>/dev/null)"
if [ "${MACOS%%.*}" -ge "$MIN_MACOS" ] 2>/dev/null; then ok "macOS $MACOS"
else bad "macOS $MACOS"; add_problem P1 "Your macOS ($MACOS) is too old. You need macOS 13 (Ventura) or newer. Update in System Settings > General > Software Update, or use another laptop."; fi

ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ] && [ "$(sysctl -in hw.optional.arm64 2>/dev/null)" = "1" ]; then
  bad "Terminal is running in Rosetta mode"
  add_problem P6 "Terminal is set to 'Open using Rosetta'. Quit Terminal. In Finder open Applications > Utilities, right-click Terminal > Get Info, untick 'Open using Rosetta', then run the command again."
else ok "Processor: $ARCH"; fi

IS_ADMIN=0; id -Gn | tr ' ' '\n' | grep -qx admin && IS_ADMIN=1
[ "$IS_ADMIN" = 1 ] && ok "Administrator account" || warn "This Mac account is not an administrator"

FREE_GB=$(( $(df -k "$HOME" | awk 'NR==2{print $4}') / 1024 / 1024 ))
if [ "$FREE_GB" -ge "$MIN_DISK_GB" ]; then ok "Free disk space: ${FREE_GB} GB"
else bad "Free disk space: ${FREE_GB} GB"; add_problem P3 "Your Mac needs at least ${MIN_DISK_GB} GB of free space (it has ${FREE_GB} GB). Delete large files or empty the Bin, then run the command again."; fi

BLOCKED=""
for h in github.com api.github.com raw.githubusercontent.com objects.githubusercontent.com claude.ai openrouter.ai registry.npmjs.org formulae.brew.sh ghcr.io; do
  curl -sS -o /dev/null -m 20 -I "https://$h" >/dev/null 2>&1 || BLOCKED="$BLOCKED $h"
done
if [ -z "$BLOCKED" ]; then ok "Internet: all download sites reachable"
else bad "Internet: cannot reach$BLOCKED"; add_problem P4 "Your internet is blocking a download site ($(echo $BLOCKED)). Switch to home Wi-Fi or a phone hotspot, then run the command again."; fi

SRV="$(curl -sI -m 15 https://github.com 2>/dev/null | tr -d '\r' | sed -n 's/^[Dd]ate: //p')"
if [ -n "$SRV" ]; then
  S=$(LC_ALL=C date -j -u -f "%a, %d %b %Y %T GMT" "$SRV" +%s 2>/dev/null || echo 0)
  L=$(date -u +%s); D=$(( S > L ? S - L : L - S ))
  if [ "$S" -gt 0 ] && [ "$D" -gt 600 ]; then bad "Clock is wrong by $((D/60)) minutes"
    add_problem P5 "Your Mac's clock is wrong. Open System Settings > General > Date & Time, turn on 'Set time and date automatically', then run the command again."
  else ok "Clock"; fi
fi

if [ -n "$KEY" ]; then
  RESP="$(curl -sS -m 30 -w $'\n%{http_code}' -H "Authorization: Bearer $KEY" https://openrouter.ai/api/v1/key 2>/dev/null)"
  CODE="$(printf '%s' "$RESP" | tail -n1)"; BODY="$(printf '%s' "$RESP" | sed '$d')"
  REM="$(printf '%s' "$BODY" | json_num limit_remaining)"
  if [ "$CODE" = "200" ]; then
    if [ -n "$REM" ] && awk "BEGIN{exit !($REM <= 0)}"; then bad "Key has no credit left"
      add_problem K3 "Your key has no credit left. Send this screenshot to the help group so we can top it up."
    else ok "Hackathon key works (ends in ...${KEY: -4})"; fi
  elif [ "$CODE" = "401" ] || [ "$CODE" = "403" ]; then bad "Key was rejected"
    add_problem K2 "Your key was rejected. Copy the whole key from your latest email again and run the command again. Still failing? Ask the help group for a new key."
  else bad "Could not check the key (answer: ${CODE:-none})"
    add_problem K4 "Setup could not reach the AI service to check your key. Try another Wi-Fi or a phone hotspot, then run the command again."
  fi
else warn "Key not checked (none given)"; fi

find_brew
check_tools
if [ -n "$BREW" ]; then
  if [ -w "$BREW_PREFIX" ] && [ -w "$BREW_REPO" ]; then ok "Homebrew ($BREW_PREFIX)"
  else BREW_OWNER="$(stat -f %Su "$BREW_REPO" 2>/dev/null)"; warn "Homebrew belongs to the Mac account '$BREW_OWNER'"; fi
else
  warn "Homebrew not installed yet (setup will install it)"
fi
[ -n "$NEED" ] && warn "To install:$( [ -z "$BREW" ] && echo " Homebrew") $NEED" || ok "Git, GitHub CLI, Node.js and Python already installed"

# Installing anything needs an administrator account.
if [ "$MODE" = "install" ] && { [ -z "$BREW" ] || [ -n "$NEED" ]; } && [ "$IS_ADMIN" = 0 ]; then
  add_problem P2 "This Mac account is not an administrator, so it cannot install the tools. Log out, log in with an administrator account (System Settings > Users & Groups shows which), then run the command again."
fi

if [ -n "$PROBLEMS" ]; then
  printf "\n${B}Fix these, then run the same command again:${N}%s\n" "$PROBLEMS"
  if [ "$MODE" = "install" ]; then
    FAILED=1
    printf "\nSetup stopped before installing anything. Take a screenshot of this window and send it to the help group if you need help.\n"
    sleep 1; exit 1
  fi
fi

# ===================================================================================
if [ "$MODE" = "install" ]; then

# ---------- 3. Mac password (only if something needs it) ----------
NEED_SUDO=0
[ -z "$BREW" ] && NEED_SUDO=1
if [ -n "$BREW" ] && [ -n "$NEED" ] && { [ ! -w "$BREW_PREFIX" ] || [ ! -w "$BREW_REPO" ]; }; then
  STEP="taking over Homebrew"
  printf "\n${Y}${B}Homebrew on this Mac was installed by another Mac account ('%s').${N}\n" "$BREW_OWNER"
  printf "Setup needs to take it over to add:%s\nAfter this, the account '%s' will not be able to update Homebrew until it runs the same fix.\n" " $NEED" "$BREW_OWNER"
  printf "Type YES and press Return to continue (anything else stops): "
  IFS= read -r ANS < /dev/tty
  [ "$ANS" = "YES" ] || [ "$ANS" = "yes" ] || fail H2 "You chose not to take over Homebrew. Log in to the Mac account '$BREW_OWNER' and run the command there, or run it again and type YES."
  NEED_SUDO=2
fi
if [ "$NEED_SUDO" != 0 ]; then
  STEP="asking for your Mac password"
  say "Type your Mac login password and press Return. Nothing shows while you type. That's normal."
  if ! sudo -v < /dev/tty; then
    fail H3 "Your Mac password was not accepted. Use the password you log in to this Mac with. If this account has no password, set one in System Settings > Users & Groups, then run the command again."
  fi
  # Keep the password valid for the rest of the setup (Homebrew can take a while).
  ( while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
fi
if [ "$NEED_SUDO" = 2 ]; then
  sudo chown -R "$(whoami)" "$BREW_PREFIX" "$BREW_REPO" && chmod -R u+w "$BREW_PREFIX" "$BREW_REPO" \
    || fail H2 "Setup could not take over Homebrew. Log in to the Mac account '$BREW_OWNER' and run the command there."
fi

# ---------- 4. Homebrew ----------
if [ -z "$BREW" ]; then
  STEP="installing Homebrew"
  say "Installing Homebrew and Apple's developer tools."
  echo "On a new Mac this downloads a lot and can take 10-30 minutes. Keep this window open, even if it looks stuck."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null
  find_brew
  [ -n "$BREW" ] || fail H1 "Homebrew did not install. Check your internet (try a phone hotspot) and run the command again. If this Mac is managed by a school or company, use your own laptop."
  grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($BREW shellenv)\"" >> "$HOME/.zprofile"
  check_tools
fi

# ---------- 5. Git, GitHub CLI, Node.js, Python: only what is missing, never upgrade ----------
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_ANALYTICS=1
if [ -n "$NEED" ]; then
  STEP="installing $NEED"
  say "Installing:$( echo " $NEED") (5-15 minutes)..."
  for f in $NEED; do
    "$BREW" install "$f" < /dev/null || "$BREW" install "$f" < /dev/null || true
  done
  hash -r; check_tools
fi
case " $NEED " in *" git "*)        fail T1 "Git did not install. Check your internet and run the command again. Still failing? Send this screenshot and setup-log.txt to the help group." ;; esac
case " $NEED " in *" gh "*)         fail T2 "GitHub CLI did not install. Check your internet and run the command again. Still failing? Send this screenshot and setup-log.txt to the help group." ;; esac
case " $NEED " in *" node "*)       fail T3 "Node.js did not install. Check your internet and run the command again. Still failing? Send this screenshot and setup-log.txt to the help group." ;; esac
case " $NEED " in *"python@3.12"*)  fail T4 "Python did not install. Check your internet and run the command again. Still failing? Send this screenshot and setup-log.txt to the help group." ;; esac

# ---------- 6. Claude Code (pinned version, official installer) ----------
STEP="installing Claude Code"
CLAUDE="$HOME/.local/bin/claude"
HAVE_CC="$("$CLAUDE" --version 2>/dev/null | awk '{print $1}')"
if [ -z "$HAVE_CC" ] || ! ver_ge "$HAVE_CC" "$CC_VERSION"; then
  say "Installing Claude Code $CC_VERSION..."
  CCI="$(mktemp)"
  if curl -fsSL https://claude.ai/install.sh -o "$CCI"; then
    bash "$CCI" "$CC_VERSION" < /dev/null || bash "$CCI" latest < /dev/null || true
  fi
  rm -f "$CCI"
fi
[ -x "$CLAUDE" ] || fail C1 "Claude Code did not install. Check your internet (try a phone hotspot) and run the command again."
"$CLAUDE" --version >/dev/null 2>&1 || fail C2 "Claude Code installed but will not start. Restart the Mac and run the command again. Still failing? Send this screenshot to the help group."
export PATH="$HOME/.local/bin:$BREW_PREFIX/bin:$PATH"

# ---------- 7. UI/UX Pro Max design skill ----------
STEP="installing the design skill"
say "Installing the UI/UX Pro Max design skill..."
NPM="$(dirname "$NODE")/npm"; [ -x "$NPM" ] || NPM="$(command -v npm)"
"$NPM" install -g --prefix "$HOME/.local" "uipro-cli@$UIPRO_VERSION" --no-fund --no-audit < /dev/null \
  || "$NPM" install -g --prefix "$HOME/.local" "uipro-cli@$UIPRO_VERSION" --no-fund --no-audit < /dev/null || true
mkdir -p "$DIR/.claude"
( cd "$DIR" && { "$HOME/.local/bin/uipro" init --ai claude < /dev/null || "$HOME/.local/bin/uipro" init --ai claude --offline < /dev/null; } ) || true
find "$DIR/.claude/skills" -name SKILL.md 2>/dev/null | grep -q . \
  || fail S1 "The design skill did not install. Check your internet and run the command again."

# ---------- 8. Workspace settings (key + safety rules), only for the hackathon folder ----------
# Sandbox is OFF on purpose: Claude Code's docs say gh (used to publish) can fail inside the
# Mac sandbox, and Windows has no sandbox, so both groups now see the same behaviour.
STEP="saving your settings"
umask 077
cat > "$DIR/.claude/settings.local.json" <<JSON
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
umask 022
cat > "$DIR/CLAUDE.md" <<'MD'
# Hackathon rules for the assistant
- Only create and edit files inside this folder. Never touch files outside it.
- Never run commands that delete folders, change system settings, or install software globally. Ask first if unsure.
- Keep answers short. Make small changes, then show the result.
- Build with plain HTML/CSS/JS unless the user asks for a framework. No build step, no server.
- Use the ui-ux-pro-max skill for design choices (styles, colours, fonts). On Windows, if python3 fails, use python.
- Put every project in its own subfolder (e.g. bakery/, habit-app/) with index.html at the top of that subfolder.
- Use relative paths only (e.g. about.html, images/logo.png). Never use C:\ or /Users/ paths.
- Save app data in the browser (localStorage). No databases or backend.
- To show a project, open its index.html in the user's browser.
- To publish a project when asked: work ONLY inside that project's subfolder. Run git init -b main, git add ., git commit, then gh repo create <subfolder-name> --public --source=. --push, then enable GitHub Pages with: gh api -X POST repos/<owner>/<repo>/pages -f "source[branch]=main" -f "source[path]=/" . Give the user the link https://<owner>.github.io/<repo>/ (it can take 2 minutes to go live).
- Never run git init in the main claude-hackathon folder, never commit or upload the .claude folder, never force-push, never delete repositories.
- When the user starts a new, unrelated task, remind them to type /clear first.
- Never ask for or store passwords, API keys, or personal data in code.
MD
# Keep the key and the log out of anything published by mistake.
printf '.claude/\nsetup-log.txt\n' > "$DIR/.gitignore"

# ---------- 9. Skip the first-run screens (login + "do you trust this folder?") ----------
STEP="preparing Claude Code"
[ -f "$HOME/.claude.json" ] && cp "$HOME/.claude.json" "$HOME/.claude.json.hackathon-backup" 2>/dev/null
"$NODE" -e '
const fs=require("fs"), f=process.argv[1], d=process.argv[2];
let j={}; try { j=JSON.parse(fs.readFileSync(f,"utf8")); } catch(e) {}
j.hasCompletedOnboarding=true; j.projects=j.projects||{};
j.projects[d]=Object.assign({}, j.projects[d], {hasTrustDialogAccepted:true});
fs.writeFileSync(f, JSON.stringify(j,null,2));' "$HOME/.claude.json" "$DIR" || true

# ---------- 10. Typing "claude" anywhere opens the hackathon workspace ----------
for RC in "$HOME/.zshrc" "$HOME/.bash_profile"; do
  touch "$RC"
  sed -i '' '/# >>> hackathon claude >>>/,/# <<< hackathon claude <<</d' "$RC"
  cat >> "$RC" <<RCEOF
# >>> hackathon claude >>>
export PATH="\$HOME/.local/bin:\$PATH"
claude() { ( cd "\$HOME/claude-hackathon" && PATH="\$HOME/.local/bin:$BREW_PREFIX/bin:\$PATH" command claude "\$@" ); }
# <<< hackathon claude <<<
RCEOF
done

fi  # end of install-only steps

# ===================================================================================
# ---------- 11. Verify everything (install and check mode) ----------
STEP="checking the result"
find_brew; export PATH="$HOME/.local/bin:${BREW_PREFIX:-/opt/homebrew}/bin:$PATH"; hash -r; check_tools
CLAUDE="$HOME/.local/bin/claude"
ALL=1
say "Result:"
[ -n "$GIT" ]  && ok "Git $("$GIT" --version | awk '{print $3}')" || { bad "Git missing (T1)"; ALL=0; }
case " $NEED " in *" gh "*) bad "GitHub CLI missing or too old (T2)"; ALL=0 ;; *) ok "GitHub CLI $("$GH" --version | head -n1 | awk '{print $3}')" ;; esac
case " $NEED " in *" node "*) bad "Node.js missing or too old (T3)"; ALL=0 ;; *) ok "Node.js $("$NODE" -v)" ;; esac
[ -n "$PY" ]   && ok "Python $("$PY" --version 2>&1 | awk '{print $2}')" || { bad "Python missing (T4)"; ALL=0; }
if "$CLAUDE" --version >/dev/null 2>&1; then ok "Claude Code $("$CLAUDE" --version | awk '{print $1}')"; else bad "Claude Code missing (C1)"; ALL=0; fi
find "$DIR/.claude/skills" -name SKILL.md 2>/dev/null | grep -q . && ok "Design skill" || { bad "Design skill missing (S1)"; ALL=0; }
[ -f "$DIR/.claude/settings.local.json" ] && ok "Hackathon settings" || { bad "Hackathon settings missing (run the setup command)"; ALL=0; }

# Claude test: talk to the AI once, and explain any failure.
CL_OK=0
if [ "$ALL" = 1 ] || "$CLAUDE" --version >/dev/null 2>&1; then
  for attempt in 1 2; do
    T="$(mktemp)"
    ( cd "$DIR" && "$CLAUDE" -p "Reply with exactly: SETUP OK" ) > "$T" 2>&1 < /dev/null &
    P=$!; i=0
    while kill -0 $P 2>/dev/null && [ $i -lt 180 ]; do sleep 1; i=$((i+1)); done
    TIMED=0; kill -0 $P 2>/dev/null && { kill $P 2>/dev/null; TIMED=1; }
    wait $P 2>/dev/null
    OUT="$(grep -v 'unrecognized_model' "$T")"; rm -f "$T"
    if printf '%s' "$OUT" | grep -q "SETUP OK"; then CL_OK=1; break; fi
    if printf '%s' "$OUT" | grep -Eqi '429|rate.?limit|too many requests|overloaded' && [ $attempt = 1 ]; then
      echo "  The AI service is busy. Trying again in 30 seconds..."; sleep 30; continue
    fi
    break
  done
  if [ "$CL_OK" = 1 ]; then ok "AI connection (key ends in ...${KEY: -4})"
  else
    ALL=0
    if   printf '%s' "$OUT" | grep -Eqi '401|unauthori|invalid.*key|user not found|no auth'; then CL_CODE=C4; CL_MSG="Your key was rejected. Copy the whole key from your latest email and run the setup command again."
    elif printf '%s' "$OUT" | grep -Eqi '402|credit|insufficient|payment'; then CL_CODE=C5; CL_MSG="Your key has no credit left. Send this screenshot to the help group."
    elif printf '%s' "$OUT" | grep -Eqi '429|rate.?limit|too many|overloaded'; then CL_CODE=C6; CL_MSG="The AI service is busy right now. Wait 5 minutes and run the command again."
    elif [ "$TIMED" = 1 ] || printf '%s' "$OUT" | grep -Eqi 'ENOTFOUND|ECONNREFUSED|ETIMEDOUT|ECONNRESET|certificate|network|fetch failed'; then CL_CODE=C7; CL_MSG="Claude Code could not reach the AI service. Try another Wi-Fi or a phone hotspot, then run the command again."
    else CL_CODE=C3; CL_MSG="The AI test did not answer as expected. Send this screenshot and setup-log.txt to the help group."; fi
    bad "AI connection ($CL_CODE)"
    echo "  Details (for the help group):"; printf '%s\n' "$OUT" | tail -n 10 | sed 's/^/    /'
  fi
fi

# ---------- 12. GitHub login (needed to publish your site) ----------
GH_USER=""
if [ -n "${GH:-}" ]; then
  if ! "$GH" auth status >/dev/null 2>&1 && [ "$MODE" = "install" ]; then
    STEP="logging in to GitHub"
    say "Now log in to GitHub."
    echo "1. Press Return when asked. Your browser opens."
    echo "2. Copy the 8-character code shown here, paste it in the browser, and click Authorize."
    "$GH" auth login -h github.com -p https -w < /dev/tty || true
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
if [ -n "$GH_USER" ]; then ok "GitHub account: ${B}$GH_USER${N}  (not you? run: gh auth logout   then run the setup again)"
else bad "GitHub not logged in (G1)"; ALL=0; fi

# ---------- 13. Final answer ----------
echo ""
if [ "$ALL" = 1 ] && [ "$CL_OK" = 1 ]; then
  printf "${G}${B}PASS${N} - take a screenshot of this window and send it to the organisers.\n"
  [ "$MODE" = "install" ] && printf "Now quit Terminal (Cmd + Q), open it again, and type:  ${B}claude${N}\n"
  FAILED=1; exit 0   # FAILED=1 only silences the X1 message
fi
if [ "${CL_CODE:-}" != "" ] && [ "$CL_OK" = 0 ]; then fail "$CL_CODE" "$CL_MSG"; fi
if [ -z "$GH_USER" ]; then fail G1 "GitHub login did not finish. Run the setup command again and complete the browser step (paste the code, click Authorize). No GitHub account yet? Create one at github.com and verify your email first."; fi
fail X2 "Something above is marked FAIL. Run the setup command again. Still failing? Send this screenshot and setup-log.txt to the help group."
}

main "$@"
