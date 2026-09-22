# Coach Foundation Hackathon - one-command setup (Windows PowerShell)
# Installs: Git, GitHub CLI, Node.js, Python 3.12, Claude Code, UI/UX Pro Max skill.
# Then connects Claude Code to the hackathon key.
$ErrorActionPreference = "Continue"
$Dir  = "$env:USERPROFILE\claude-hackathon"
$Shim = "$env:USERPROFILE\.claude-hackathon-bin"
Write-Host "== Hackathon setup (about 10-20 minutes). Click YES whenever Windows asks for permission. =="

function Refresh-Path {
  $env:Path = "$Shim;$env:USERPROFILE\.local\bin;" + [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User") + ";C:\Program Files\Git\cmd;C:\Program Files\GitHub CLI;C:\Program Files\nodejs;$env:APPDATA\npm"
}

# 1. Personal key first, so the rest can run unattended
$sec = Read-Host "Paste your personal hackathon key (starts with sk-or-, it stays hidden)" -AsSecureString
$Key = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)).Trim()
if (-not $Key.StartsWith("sk-or-")) { Write-Host "That does not look like a valid key. Re-run the command." -ForegroundColor Red; return }

# 2. Tools via winget
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host "This Windows version is missing 'winget' (App Installer). Install 'App Installer' from the Microsoft Store, then run this command again." -ForegroundColor Red
  return
}
function Install-Pkg($id, $name, $extra) {
  Write-Host "Installing $name..."
  $wa = @("install","--id",$id,"-e","--source","winget","--silent","--accept-package-agreements","--accept-source-agreements") + $extra
  & winget @wa
}
Refresh-Path
if (-not (Get-Command git  -ErrorAction SilentlyContinue)) { Install-Pkg "Git.Git" "Git" @() }
if (-not (Get-Command gh   -ErrorAction SilentlyContinue)) { Install-Pkg "GitHub.cli" "GitHub CLI" @() }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Install-Pkg "OpenJS.NodeJS.LTS" "Node.js" @() }
$py = "$env:LOCALAPPDATA\Programs\Python\Python312"
if (-not (Test-Path "$py\python.exe")) {
  Install-Pkg "Python.Python.3.12" "Python 3.12" @("--override","/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1")
}
if ((Test-Path "$py\python.exe") -and -not (Test-Path "$py\python3.exe")) { Copy-Item "$py\python.exe" "$py\python3.exe" }
Refresh-Path
$env:Path = "$py;$py\Scripts;$env:Path"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "Git did not install. Install it from https://git-scm.com/download/win (click Next on every screen), then run this command again." -ForegroundColor Red
  return
}

# 3. Claude Code (official native installer)
if (-not (Test-Path "$env:USERPROFILE\.local\bin\claude.exe")) {
  Write-Host "Installing Claude Code..."
  irm https://claude.ai/install.ps1 | iex
}
Refresh-Path
$ClaudeExe = "$env:USERPROFILE\.local\bin\claude.exe"

# 4. UI/UX Pro Max design skill
Write-Host "Installing the UI/UX Pro Max design skill..."
& npm.cmd install -g uipro-cli | Out-Null
New-Item -ItemType Directory -Force -Path "$Dir\.claude" | Out-Null
Set-Location $Dir
& "$env:APPDATA\npm\uipro.cmd" init --ai claude
if ($LASTEXITCODE -ne 0) { & "$env:APPDATA\npm\uipro.cmd" init --ai claude --offline }

# 5. Workspace settings (key + safety rules), scoped to the workspace folder
$settings = @"
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://openrouter.ai/api",
    "ANTHROPIC_AUTH_TOKEN": "$Key",
    "ANTHROPIC_API_KEY": "",
    "ANTHROPIC_MODEL": "openai/gpt-5-mini",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "openai/gpt-5-mini",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "openai/gpt-5-mini",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "openai/gpt-5-mini",
    "CLAUDE_CODE_SUBAGENT_MODEL": "openai/gpt-5-mini",
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
  }
}

"@
[System.IO.File]::WriteAllText("$Dir\.claude\settings.local.json", $settings)
$md = @'
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

'@
[System.IO.File]::WriteAllText("$Dir\CLAUDE.md", $md)

# 6. Skip the first-run login screen (auth comes from the hackathon key)
$F = "$env:USERPROFILE\.claude.json"
try {
  if ((Test-Path $F) -and ((Get-Content $F -Raw).Trim().Length -gt 2)) {
    $j = Get-Content $F -Raw | ConvertFrom-Json
    $j | Add-Member -NotePropertyName hasCompletedOnboarding -NotePropertyValue $true -Force
    [System.IO.File]::WriteAllText($F, ($j | ConvertTo-Json -Depth 100))
  } else {
    [System.IO.File]::WriteAllText($F, '{"hasCompletedOnboarding": true}')
  }
} catch { }

# 7. Typing "claude" anywhere opens it in the hackathon workspace
New-Item -ItemType Directory -Force -Path $Shim | Out-Null
$cmd = "@echo off`r`ncd /d `"%USERPROFILE%\claude-hackathon`"`r`n`"%USERPROFILE%\.local\bin\claude.exe`" %*`r`n"
[System.IO.File]::WriteAllText("$Shim\claude.cmd", $cmd)
$userPath = [Environment]::GetEnvironmentVariable("Path","User")
if ($userPath -notlike "*$Shim*") { [Environment]::SetEnvironmentVariable("Path", "$Shim;$userPath", "User") }
# PowerShell: a profile function always wins over programs on PATH
try {
  $pol = Get-ExecutionPolicy -Scope CurrentUser
  if ($pol -eq "Undefined" -or $pol -eq "Restricted") { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force }
  foreach ($prof in @($PROFILE.CurrentUserAllHosts)) {
    New-Item -ItemType File -Force -Path $prof -ErrorAction SilentlyContinue | Out-Null
    if (-not (Select-String -Path $prof -Pattern "hackathon claude" -Quiet)) {
      Add-Content -Path $prof -Value "`r`n# >>> hackathon claude >>>`r`nfunction claude { Set-Location `"`$HOME\claude-hackathon`"; & `"`$HOME\.local\bin\claude.exe`" @args }`r`n# <<< hackathon claude <<<"
    }
  }
} catch { Write-Host "Note: could not add the PowerShell shortcut ($_)" }

# 8. Test the connection
Write-Host "Testing Claude..."
# Run the test as a separate process: stdout and stderr go to temp files, so Claude Code's
# harmless "[claude-code:unrecognized_model]" notice on stderr can't be mistaken for an error.
$tOut = Join-Path $env:TEMP "hackathon-claude-test.out"
$tErr = Join-Path $env:TEMP "hackathon-claude-test.err"
Remove-Item $tOut, $tErr -ErrorAction SilentlyContinue
$out = ""; $errText = ""
try {
  $p = Start-Process -FilePath $ClaudeExe -ArgumentList '-p', '"Reply with exactly: SETUP OK"' `
        -WorkingDirectory (Get-Location).Path -NoNewWindow -PassThru `
        -RedirectStandardOutput $tOut -RedirectStandardError $tErr
  if (-not $p.WaitForExit(180000)) { try { $p.Kill() } catch {} ; $errText = "Timed out after 3 minutes." }
  if (Test-Path $tOut) { $out = Get-Content $tOut -Raw -ErrorAction SilentlyContinue }
  if (Test-Path $tErr) {
    $errText += ((Get-Content $tErr -ErrorAction SilentlyContinue) |
      Where-Object { $_ -and ($_ -notmatch "unrecognized_model") }) -join "`n"
  }
} catch { $errText = "$_" }
$ClaudeOK = ("$out" -match "SETUP OK")
if (-not $ClaudeOK -and $errText) { Write-Host "Claude test details: $errText" -ForegroundColor Yellow }

# 9. Log in to GitHub (opens your browser)
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "`nNow log in to GitHub. Press Enter when asked, then paste the code shown here into the browser." -ForegroundColor Cyan
  & gh auth login -h github.com -p https -w
}
& gh auth status *> $null
$GhOK = ($LASTEXITCODE -eq 0)
if ($GhOK) {
  & gh auth setup-git *> $null
  if (-not (& git config --global user.name)) {
    $u = (& gh api user | ConvertFrom-Json)
    & git config --global user.name $u.login
    & git config --global user.email "$($u.id)+$($u.login)@users.noreply.github.com"
  }
}

Write-Host ""
if ($ClaudeOK -and $GhOK) {
  Write-Host "PASS - screenshot this and send it to the organisers." -ForegroundColor Green
  Write-Host "Close ALL PowerShell / Terminal windows, open PowerShell again and type:  claude"
} else {
  if (-not $ClaudeOK) { Write-Host "FAIL (Claude) - re-run this setup command. Still failing? Send a screenshot to the help channel." -ForegroundColor Red }
  if (-not $GhOK) { Write-Host "FAIL (GitHub login) - run:  gh auth login   then try again." -ForegroundColor Red }
}
