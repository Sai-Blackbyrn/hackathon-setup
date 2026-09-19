# Coach Foundation Hackathon - Claude Code setup (Windows PowerShell)
$ErrorActionPreference = "Stop"
$Dir = "$env:USERPROFILE\claude-hackathon"
Write-Host "== Hackathon setup =="

# 0. Git for Windows is required by Claude Code on Windows
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "Git for Windows is missing. Install it from https://git-scm.com/download/win (all defaults), close PowerShell, then run this command again." -ForegroundColor Red
  return
}

# 1. Install Claude Code (official native installer, per-user)
$env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Claude Code..."
  irm https://claude.ai/install.ps1 | iex
  $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}

# 2. Personal key
$Key = Read-Host "Paste your personal hackathon key (starts with sk-or-)"
if (-not $Key.StartsWith("sk-or-")) { Write-Host "That does not look like a valid key. Re-run the command." -ForegroundColor Red; return }

# 3. ONE work folder + settings scoped to it
New-Item -ItemType Directory -Force -Path "$Dir\.claude" | Out-Null
$settings = @"
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://openrouter.ai/api",
    "ANTHROPIC_AUTH_TOKEN": "$Key",
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
  }
}
"@
[System.IO.File]::WriteAllText("$Dir\.claude\settings.local.json", $settings)   # UTF-8 without BOM
$md = @'
# Hackathon rules for the assistant
- Only create and edit files inside this folder. Never touch files outside it.
- Never run commands that delete folders, change system settings, or install software globally. Ask first if unsure.
- Keep answers short. Make small changes, then show the result.
- Build with plain HTML/CSS/JS unless the user asks for a framework.
- When the user starts a new, unrelated task, remind them to type /clear first.
- Never ask for or store passwords, API keys, or personal data in code.
'@
[System.IO.File]::WriteAllText("$Dir\CLAUDE.md", $md)

# 4. Test
$ErrorActionPreference = "Continue"   # native stderr must not abort the test
Set-Location $Dir
Write-Host "Testing connection..."
$out = (claude -p "Reply with exactly: SETUP OK" 2>&1 | Out-String)
if ($out -match "SETUP OK") {
  Write-Host "`nPASS - screenshot this and send it to the organisers." -ForegroundColor Green
  Write-Host "From now on: open PowerShell, type  cd ~\claude-hackathon  then  claude"
} else {
  Write-Host "`nFAIL - run  claude  then type  /logout , exit, and re-run this setup. Still failing? Send a screenshot to the help channel." -ForegroundColor Red
}
