#!/usr/bin/env bash
# Coach Foundation Hackathon - one-command setup (Mac)
# Installs: Homebrew (+ Apple command line tools), Git, GitHub CLI, Node.js, Python 3.12,
#           Claude Code, UI/UX Pro Max skill. Then connects Claude Code to the hackathon key.
set -e
DIR="$HOME/claude-hackathon"
echo "== Hackathon setup (about 10-20 minutes) =="

# 1. Personal key first, so the rest can run unattended
printf "Paste your personal hackathon key (starts with sk-or-, it stays hidden): "
read -rs KEY < /dev/tty; echo
KEY="$(printf "%s" "$KEY" | tr -d '[:space:]')"
case "$KEY" in sk-or-*) ;; *) echo "That does not look like a valid key. Re-run the command."; exit 1;; esac

# 2. Homebrew (also installs Apple's command line tools). Asks for your Mac password once.
if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ] && [ ! -x /usr/local/bin/brew ]; then
  echo "Installing Homebrew: press RETURN when asked, and type your Mac login password when asked (it won't show)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/tty
fi
if [ -x /opt/homebrew/bin/brew ]; then BREW=/opt/homebrew/bin/brew; else BREW=/usr/local/bin/brew; fi
eval "$($BREW shellenv)"
grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($BREW shellenv)\"" >> "$HOME/.zprofile"

# 3. Git, GitHub CLI, Node.js, Python
echo "Installing Git, GitHub CLI, Node.js and Python..."
brew install git gh node python@3.12

# 4. Claude Code (official native installer)
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
  echo "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi
export PATH="$HOME/.local/bin:$PATH"

# 5. UI/UX Pro Max design skill
echo "Installing the UI/UX Pro Max design skill..."
npm install -g uipro-cli
mkdir -p "$DIR/.claude"
cd "$DIR"
uipro init --ai claude < /dev/null || uipro init --ai claude --offline < /dev/null

# 6. Workspace settings (key + safety rules), scoped to the workspace folder
cat > "$DIR/.claude/settings.local.json" <<JSON
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://openrouter.ai/api",
    "ANTHROPIC_AUTH_TOKEN": "$KEY",
    "ANTHROPIC_API_KEY": "",
    "ANTHROPIC_MODEL": "anthropic/claude-haiku-4.5",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "anthropic/claude-haiku-4.5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "anthropic/claude-haiku-4.5",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "anthropic/claude-haiku-4.5",
    "CLAUDE_CODE_SUBAGENT_MODEL": "anthropic/claude-haiku-4.5",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "200000"
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
  },
  "sandbox": { "enabled": true }
}
JSON
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

# 7. Skip the first-run login screen (auth comes from the hackathon key)
F="$HOME/.claude.json"
if [ ! -s "$F" ] || [ "$(tr -d '[:space:]' < "$F")" = "{}" ]; then
  echo '{"hasCompletedOnboarding": true}' > "$F"
elif grep -q '"hasCompletedOnboarding"' "$F"; then
  sed -i '' 's/"hasCompletedOnboarding": *false/"hasCompletedOnboarding": true/' "$F"
else
  sed -i '' '1s/^{/{"hasCompletedOnboarding": true,/' "$F"
fi

# 8. Typing "claude" anywhere opens it in the hackathon workspace
for RC in "$HOME/.zshrc" "$HOME/.bash_profile"; do
  if ! grep -q ">>> hackathon claude >>>" "$RC" 2>/dev/null; then
    cat >> "$RC" <<'RCEOF'
# >>> hackathon claude >>>
export PATH="$HOME/.local/bin:$PATH"
claude() { cd "$HOME/claude-hackathon" && command claude "$@"; }
# <<< hackathon claude <<<
RCEOF
  fi
done

# 9. Test the connection
echo "Testing Claude..."
if claude_out="$(command claude -p "Reply with exactly: SETUP OK" 2>&1)" && echo "$claude_out" | grep -q "SETUP OK"; then
  CLAUDE_OK=1
else
  CLAUDE_OK=0
fi

# 10. Log in to GitHub (opens your browser)
if ! gh auth status >/dev/null 2>&1; then
  echo ""
  echo "Now log in to GitHub. Press Enter when asked, then paste the code shown here into the browser."
  gh auth login -h github.com -p https -w < /dev/tty || true
fi
if gh auth status >/dev/null 2>&1; then
  gh auth setup-git >/dev/null 2>&1 || true
  if [ -z "$(git config --global user.name)" ]; then
    GH_LOGIN="$(gh api user -q .login)"; GH_ID="$(gh api user -q .id)"
    git config --global user.name "$GH_LOGIN"
    git config --global user.email "$GH_ID+$GH_LOGIN@users.noreply.github.com"
  fi
  GH_OK=1
else
  GH_OK=0
fi

echo ""
if [ "$CLAUDE_OK" = 1 ] && [ "$GH_OK" = 1 ]; then
  echo "PASS - screenshot this and send it to the organisers."
  echo "Close this window, open a NEW Terminal window and type:  claude"
else
  [ "$CLAUDE_OK" = 1 ] || echo "FAIL (Claude) - re-run this setup command. Still failing? Send a screenshot to the help channel."
  [ "$GH_OK" = 1 ] || echo "FAIL (GitHub login) - run:  gh auth login   then try again."
fi
