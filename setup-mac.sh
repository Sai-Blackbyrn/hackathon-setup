#!/usr/bin/env bash
# Coach Foundation Hackathon - Claude Code setup (Mac / Linux)
set -e
DIR="$HOME/claude-hackathon"
echo "== Hackathon setup =="

# 1. Install Claude Code (official native installer, per-user, no admin needed)
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
  echo "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi
export PATH="$HOME/.local/bin:$PATH"

# 2. Ask for personal key (read from terminal even when piped from curl)
printf "Paste your personal hackathon key (starts with sk-or-): "
read -r KEY < /dev/tty
case "$KEY" in sk-or-*) ;; *) echo "That does not look like a valid key. Re-run the command."; exit 1;; esac

# 3. Create the ONE work folder + settings scoped to that folder only
mkdir -p "$DIR/.claude"
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
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "deny": [
      "Bash(sudo:*)", "Bash(rm -rf:*)", "Bash(rm -r:*)", "Bash(rmdir:*)",
      "Bash(del:*)", "Bash(Remove-Item:*)", "Bash(format:*)", "Bash(shutdown:*)",
      "Bash(chmod -R:*)", "Bash(chown:*)",
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
- Build with plain HTML/CSS/JS unless the user asks for a framework. No build step, no server, no npm.
- Put every project in its own subfolder (e.g. landing-page/, habit-app/) with index.html at the top of that subfolder.
- Use relative paths only (e.g. about.html, images/logo.png). Never use C:\ or /Users/ paths. Everything must work when the subfolder is uploaded to GitHub Pages.
- Save app data in the browser (localStorage). No databases or backend.
- Never put files inside the .claude folder, and remind the user to upload only the project subfolder to GitHub, never the whole claude-hackathon folder.
- When the user starts a new, unrelated task, remind them to type /clear first.
- Never ask for or store passwords, API keys, or personal data in code.
MD

# 4. Test
cd "$DIR"
echo "Testing connection..."
if claude -p "Reply with exactly: SETUP OK" 2>/dev/null | grep -q "SETUP OK"; then
  echo ""; echo "PASS - screenshot this and send it to the organisers."
  echo "From now on: open Terminal, type  cd ~/claude-hackathon  then  claude"
else
  echo ""; echo "FAIL - run  claude  then type  /logout , exit, and re-run this setup. Still failing? Send a screenshot to the help channel."
fi
