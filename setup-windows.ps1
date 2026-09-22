# AI Shift Training Hackathon - one-command setup (Windows PowerShell)
#
#   Install:  irm https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-windows.ps1 | iex
#   Check:    $env:HACK_CHECK='1'; irm https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-windows.ps1 | iex
#
# Installs Git, GitHub CLI, Node.js, Python 3.12, Claude Code and the UI/UX Pro Max skill,
# then connects Claude Code to the hackathon key.
#
# Every run ends in PASS (with a checklist) or FAIL <code> with one sentence saying what to do.
# Codes are listed in TROUBLESHOOTING.md. Safe to re-run any number of times.
# Written for Windows PowerShell 5.1 (the version every Windows 10/11 laptop has).
# Never calls "exit": with "irm | iex" that would close the student's window.

function Invoke-HackathonSetup {
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'   # makes downloads much faster in PowerShell 5.1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# ---------- Pinned versions (tested for this event) ----------
$CcVersion    = '2.1.278'   # Claude Code
$UiproVersion = '2.2.3'     # uipro-cli (UI/UX Pro Max skill)
$Model        = 'openai/gpt-5-mini'
$MinBuild = 17763; $MinNode = 18; $MinDiskGB = 5

$Mode = 'install'; if ($env:HACK_CHECK -eq '1') { $Mode = 'check' }
Remove-Item Env:HACK_CHECK -ErrorAction SilentlyContinue
$script:Step = 'starting'

function OK($t)   { Write-Host "  OK   $t" -ForegroundColor Green }
function BAD($t)  { Write-Host "  FAIL $t" -ForegroundColor Red }
function NOTE($t) { Write-Host "  NOTE $t" -ForegroundColor Yellow }
function SAY($t)  { Write-Host ""; Write-Host $t -ForegroundColor Cyan }
function Fail($code, $msg) {
  Write-Host ""
  Write-Host "FAIL $code" -ForegroundColor Red
  Write-Host $msg -ForegroundColor White
  Write-Host ""
  Write-Host "Take a screenshot of this window and send it to the help group."
  Write-Host "If you can, also send this file: $script:Dir\setup-log.txt"
  throw "HACKATHON_FAIL"
}

# ---------- Workspace folder ----------
# Usernames with Arabic letters or spaces (C:\Users\محمد, C:\Users\Ahmed Ali) break file paths in
# some tools. For those users the workspace and temp folder go to C:\claude-hackathon instead.
$ProfileUnsafe = ($env:USERPROFILE -match '[^\x21-\x7E]')
$Dir = "$env:USERPROFILE\claude-hackathon"
if ($ProfileUnsafe) {
  $Dir = 'C:\claude-hackathon'
  try { New-Item -ItemType Directory -Force -Path $Dir -ErrorAction Stop | Out-Null }
  catch { $Dir = "$env:USERPROFILE\claude-hackathon" }
}
$script:Dir = $Dir
$Shim = "$env:USERPROFILE\.claude-hackathon-bin"
$ClaudeExe = "$env:USERPROFILE\.local\bin\claude.exe"
$PyDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
try { New-Item -ItemType Directory -Force -Path "$Dir\.claude", "$Dir\.tmp" -ErrorAction Stop | Out-Null }
catch { Fail P8 "Setup could not create the folder $Dir. Restart the laptop and run the command again." }

function Refresh-Path {
  $env:Path = "$PyDir;$PyDir\Scripts;$Shim;$env:USERPROFILE\.local\bin;" +
    [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') +
    ";C:\Program Files\Git\cmd;C:\Program Files\GitHub CLI;C:\Program Files\nodejs;$env:APPDATA\npm"
}
function Ver-Ge($have, $need) { try { return ([version]$have -ge [version]$need) } catch { return $false } }
function Node-Major { try { return [int]((& node -v 2>$null) -replace '^v','').Split('.')[0] } catch { return 0 } }
function Find-GitBash {
  $g = Get-Command git -ErrorAction SilentlyContinue
  $c = @()
  if ($g) { $c += (Join-Path (Split-Path (Split-Path $g.Source)) 'bin\bash.exe') }
  $c += 'C:\Program Files\Git\bin\bash.exe', "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
  foreach ($p in $c) { if ($p -and (Test-Path $p)) { return $p } }
  return $null
}
function Test-Tools {
  Refresh-Path
  $s = @{}
  $s.git    = [bool](Get-Command git -ErrorAction SilentlyContinue) -and [bool](Find-GitBash)
  $s.gh     = [bool](Get-Command gh -ErrorAction SilentlyContinue)
  $s.node   = ((Node-Major) -ge $MinNode)
  $s.python = (Test-Path "$PyDir\python.exe")
  return $s
}

Write-Host ""
Write-Host "== AI Shift Training hackathon setup ==" -ForegroundColor White
if ($Mode -eq 'check') { Write-Host "Check mode: nothing is installed or changed." }
else { Write-Host "This takes 10-30 minutes. Keep this window open and your laptop plugged in." }

# ---------- 1. Key ----------
$script:Step = 'reading your key'
$Key = ''
$SettingsFile = "$Dir\.claude\settings.local.json"
if ($Mode -eq 'check') {
  if (Test-Path $SettingsFile) { try { $Key = ((Get-Content $SettingsFile -Raw | ConvertFrom-Json).env.ANTHROPIC_AUTH_TOKEN) } catch {} }
  if (-not $Key) {
    $sec = Read-Host "No key found on this laptop. Paste your key to test it (right-click to paste), or just press Enter to skip" -AsSecureString
    $Key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
  }
} else {
  Write-Host "Paste your personal hackathon key (starts with sk-or-)."
  Write-Host "Right-click to paste (or Ctrl + V), then press Enter. You will only see * while you paste. That's normal."
  $sec = Read-Host "Key" -AsSecureString
  $Key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
$Key = ("$Key" -replace '\s', '')
if ($Mode -eq 'install') {
  if (-not $Key) { Fail K1 "No key was pasted. Run the command again. When it asks for the key, right-click to paste, then press Enter." }
  if (-not $Key.StartsWith('sk-or-v1-')) { Fail K1 "That is not a hackathon key. Copy the whole key from your email (it starts with sk-or-v1-) and run the command again." }
  Write-Host "Key received (ends in ...$($Key.Substring($Key.Length-4)))"
}
$KeyEnd = if ($Key.Length -ge 4) { $Key.Substring($Key.Length-4) } else { '' }

# From here on, everything shown is also saved to setup-log.txt (the key is never shown).
try { Start-Transcript -Path "$Dir\setup-log.txt" -Append | Out-Null; $script:Transcript = $true } catch {}

# ---------- 2. Preflight: find every problem before installing anything ----------
$script:Step = 'checking your laptop'
SAY "Checking your laptop..."
$Problems = @()

$build = [Environment]::OSVersion.Version.Build
if ($build -ge $MinBuild) { OK "Windows build $build" }
else { BAD "Windows build $build"; $Problems += ,@('P1', "Your Windows is too old (build $build). Run Windows Update (Settings > Windows Update), restart, then run the command again.") }

$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -eq 'ARM64') { NOTE "ARM laptop (Snapdragon). Most tools run in compatibility mode; tell the organisers if anything fails." } else { OK "Processor: $arch" }

$groups = (whoami /groups) 2>$null | Out-String
$IsAdminMember = ($groups -match 'S-1-5-32-544')
$IsElevated = $false
try { $IsElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch {}
if ($IsAdminMember) { OK "Administrator account" } else { NOTE "This Windows account is not an administrator" }
if ($IsElevated) {
  $desktopUser = $null
  try { $desktopUser = (Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" | Select-Object -First 1 | Invoke-CimMethod -MethodName GetOwner).User } catch {}
  if ($desktopUser -and ($desktopUser -ne $env:USERNAME)) {
    BAD "PowerShell is running as a different user ($env:USERNAME)"
    $Problems += ,@('W3', "You opened PowerShell as another user ($env:USERNAME). Close this window, open PowerShell normally (do NOT choose 'Run as administrator'), then run the command again.")
  } else { NOTE "PowerShell was opened as administrator. That's OK for you, but next time open it normally." }
}

if ($ProfileUnsafe) { NOTE "Your Windows username has special letters or a space, so your work folder is $Dir" }

try { $freeGB = [math]::Floor((Get-PSDrive ($env:SystemDrive.TrimEnd(':'))).Free / 1GB) } catch { $freeGB = 99 }
if ($freeGB -ge $MinDiskGB) { OK "Free disk space: $freeGB GB" }
else { BAD "Free disk space: $freeGB GB"; $Problems += ,@('P3', "Your laptop needs at least $MinDiskGB GB of free space on $env:SystemDrive (it has $freeGB GB). Delete large files or empty the Recycle Bin, then run the command again.") }

function Test-Site($h) {
  try { Invoke-WebRequest -Uri "https://$h" -Method Head -UseBasicParsing -TimeoutSec 20 | Out-Null; return $true }
  catch { if ($_.Exception.Response) { return $true } else { return $false } }
}
$blocked = @()
foreach ($h in 'github.com','api.github.com','raw.githubusercontent.com','objects.githubusercontent.com','claude.ai','openrouter.ai','registry.npmjs.org','cdn.winget.microsoft.com') {
  if (-not (Test-Site $h)) { $blocked += $h }
}
if ($blocked.Count -eq 0) { OK "Internet: all download sites reachable" }
else { BAD "Internet: cannot reach $($blocked -join ', ')"; $Problems += ,@('P4', "Your internet is blocking a download site ($($blocked -join ', ')). Switch to home Wi-Fi or a phone hotspot, then run the command again.") }

try {
  $r = Invoke-WebRequest -Uri 'https://github.com' -Method Head -UseBasicParsing -TimeoutSec 15
  $srv = [DateTime]::Parse($r.Headers['Date'], [Globalization.CultureInfo]::InvariantCulture).ToUniversalTime()
  $diff = [math]::Abs(($srv - (Get-Date).ToUniversalTime()).TotalMinutes)
  if ($diff -gt 10) { BAD "Clock is wrong by $([math]::Round($diff)) minutes"; $Problems += ,@('P5', "Your laptop's clock is wrong. Open Settings > Time & language > Date & time, turn on 'Set time automatically', click 'Sync now', then run the command again.") }
  else { OK "Clock" }
} catch {}

if ($Key) {
  try {
    $kr = Invoke-RestMethod -Uri 'https://openrouter.ai/api/v1/key' -Headers @{ Authorization = "Bearer $Key" } -TimeoutSec 30
    $rem = $kr.data.limit_remaining
    if (($rem -ne $null) -and ([double]$rem -le 0)) { BAD "Key has no credit left"; $Problems += ,@('K3', "Your key has no credit left. Send this screenshot to the help group so we can top it up.") }
    else { OK "Hackathon key works (ends in ...$KeyEnd)" }
  } catch {
    $sc = 0; try { $sc = [int]$_.Exception.Response.StatusCode } catch {}
    if ($sc -eq 401 -or $sc -eq 403) { BAD "Key was rejected"; $Problems += ,@('K2', "Your key was rejected. Copy the whole key from your latest email again and run the command again. Still failing? Ask the help group for a new key.") }
    else { BAD "Could not check the key"; $Problems += ,@('K4', "Setup could not reach the AI service to check your key. Try another Wi-Fi or a phone hotspot, then run the command again.") }
  }
} else { NOTE "Key not checked (none given)" }

$tools = Test-Tools
$missing = @($tools.Keys | Where-Object { -not $tools[$_] })
if ($missing.Count -eq 0) { OK "Git, GitHub CLI, Node.js and Python already installed" } else { NOTE "To install: $($missing -join ', ')" }

$Winget = Get-Command winget -ErrorAction SilentlyContinue
$needWingetTools = @($missing | Where-Object { $_ -ne 'python' })
if ($Mode -eq 'install' -and $missing.Count -gt 0 -and -not $Winget) {
  $Problems += ,@('W1', "Your Windows is missing 'App Installer'. Open the Microsoft Store, search for App Installer, click Install or Update, then run the command again.")
}
if ($Mode -eq 'install' -and $needWingetTools.Count -gt 0 -and -not $IsAdminMember) {
  $Problems += ,@('P2', "This Windows account is not an administrator, so it cannot install the tools. Sign in with an administrator account (Settings > Accounts shows which), then run the command again.")
}

if ($Problems.Count -gt 0) {
  Write-Host ""
  Write-Host "Fix these, then run the same command again:" -ForegroundColor White
  foreach ($p in $Problems) { Write-Host "FAIL $($p[0])  $($p[1])" -ForegroundColor Red }
  if ($Mode -eq 'install') {
    Write-Host ""
    Write-Host "Setup stopped before installing anything. Take a screenshot of this window and send it to the help group if you need help."
    throw "HACKATHON_FAIL"
  }
}

# ===================================================================================
if ($Mode -eq 'install') {

# ---------- 3. Tools via winget: only what is missing; each result is checked ----------
function Ensure-Tool($key, $name, $id, $extra, $code) {
  if ((Test-Tools)[$key]) { return }
  $script:Step = "installing $name"
  for ($attempt = 1; $attempt -le 2; $attempt++) {
    Write-Host ""
    if ($key -ne 'python') {
      Write-Host "Installing $name..." -ForegroundColor Cyan
      Write-Host ">> A Windows popup will ask 'Do you want to allow this app to make changes?'. Click YES." -ForegroundColor Yellow
      Write-Host ">> No popup? Look for a flashing shield icon on the taskbar and click it." -ForegroundColor Yellow
    } else { Write-Host "Installing $name..." -ForegroundColor Cyan }
    $wa = @('install', '--id', $id, '-e', '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements') + $extra
    & winget @wa
    $ec = $LASTEXITCODE
    $ErrorActionPreference = 'Continue'
    if ((Test-Tools)[$key]) { OK "$name installed"; return }
    if ($attempt -eq 1) {
      Write-Host "$name did not install (code $ec). This usually means the permission popup was closed or No was clicked." -ForegroundColor Yellow
      Write-Host "Trying once more. When the popup appears, click YES." -ForegroundColor Yellow
      Start-Sleep -Seconds 3
    }
  }
  Fail $code "$name did not install. Run the command again and click YES on every Windows permission popup (check the taskbar for a flashing shield). If it still fails, antivirus or a school/company policy may be blocking it: use your own laptop or send this screenshot to the help group."
}

if ($missing.Count -gt 0) {
  $script:Step = 'preparing the Windows installer'
  & winget source update *> $null
}
Ensure-Tool 'git'    'Git'         'Git.Git'           @() 'T1'
Ensure-Tool 'gh'     'GitHub CLI'  'GitHub.cli'        @() 'T2'
if (-not (Test-Tools).node -and (Get-Command node -ErrorAction SilentlyContinue)) {
  # Node.js is there but too old: update only this one tool.
  $script:Step = 'updating Node.js'
  Write-Host ""; Write-Host "Your Node.js is too old ($(& node -v)). Updating it..." -ForegroundColor Cyan
  Write-Host ">> If a Windows popup asks for permission, click YES." -ForegroundColor Yellow
  & winget upgrade --id OpenJS.NodeJS.LTS -e --source winget --silent --accept-package-agreements --accept-source-agreements
  if (-not (Test-Tools).node) {
    & winget install --id OpenJS.NodeJS.LTS -e --source winget --silent --force --accept-package-agreements --accept-source-agreements
  }
  if (-not (Test-Tools).node) { Fail T3 "Your old Node.js ($(& node -v)) could not be updated. Open Settings > Apps, uninstall Node.js (and nvm if you see it), then run the command again." }
}
Ensure-Tool 'node'   'Node.js'     'OpenJS.NodeJS.LTS' @() 'T3'
Ensure-Tool 'python' 'Python 3.12' 'Python.Python.3.12' @('--override','/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1') 'T4'
if ((Test-Path "$PyDir\python.exe") -and -not (Test-Path "$PyDir\python3.exe")) { Copy-Item "$PyDir\python.exe" "$PyDir\python3.exe" -ErrorAction SilentlyContinue }
Refresh-Path
$GitBash = Find-GitBash
if (-not $GitBash) { Fail W4 "Git is installed without Git Bash, which Claude Code needs. Run the command again. If it still fails, uninstall Git in Settings > Apps, then run the command again." }

# ---------- 4. Claude Code (pinned version, official installer) ----------
$script:Step = 'installing Claude Code'
$haveCc = ''
if (Test-Path $ClaudeExe) { try { $haveCc = ((& $ClaudeExe --version 2>$null) -split ' ')[0] } catch {} }
if (-not $haveCc -or -not (Ver-Ge $haveCc $CcVersion)) {
  SAY "Installing Claude Code $CcVersion..."
  try { & ([scriptblock]::Create((Invoke-RestMethod https://claude.ai/install.ps1))) $CcVersion }
  catch { try { & ([scriptblock]::Create((Invoke-RestMethod https://claude.ai/install.ps1))) latest } catch {} }
}
$ErrorActionPreference = 'Continue'
if (-not (Test-Path $ClaudeExe)) {
  Fail C1 "Claude Code did not install. If Windows Security showed a warning, open Windows Security > Virus & threat protection > Protection history, allow claude.exe, then run the command again. Otherwise check your internet and run the command again."
}
$ccv = ''; try { $ccv = (& $ClaudeExe --version 2>$null | Out-String).Trim() } catch {}
if (-not $ccv) { Fail C2 "Claude Code installed but will not start. Antivirus may be blocking it: open Windows Security > Virus & threat protection > Protection history, allow claude.exe, then run the command again." }

# ---------- 5. UI/UX Pro Max design skill ----------
$script:Step = 'installing the design skill'
SAY "Installing the UI/UX Pro Max design skill..."
$npmOut = & npm.cmd install -g "uipro-cli@$UiproVersion" --no-fund --no-audit 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { $npmOut += & npm.cmd install -g "uipro-cli@$UiproVersion" --no-fund --no-audit 2>&1 | Out-String }
$uipro = "$env:APPDATA\npm\uipro.cmd"
Push-Location $Dir
if (Test-Path $uipro) {
  & $uipro init --ai claude
  $ErrorActionPreference = 'Continue'
  if (-not (Get-ChildItem "$Dir\.claude\skills" -Recurse -Filter SKILL.md -ErrorAction SilentlyContinue)) { & $uipro init --ai claude --offline }
}
Pop-Location
if (-not (Get-ChildItem "$Dir\.claude\skills" -Recurse -Filter SKILL.md -ErrorAction SilentlyContinue)) {
  Write-Host ($npmOut -split "`n" | Select-Object -Last 10 | Out-String)
  Fail S1 "The design skill did not install. Check your internet and run the command again."
}

# ---------- 6. Workspace settings (key + safety rules), only for the hackathon folder ----------
$script:Step = 'saving your settings'
$envBlock = [ordered]@{
  ANTHROPIC_BASE_URL = 'https://openrouter.ai/api'
  ANTHROPIC_AUTH_TOKEN = $Key
  ANTHROPIC_API_KEY = ''
  ANTHROPIC_MODEL = $Model
  ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
  ANTHROPIC_DEFAULT_HAIKU_MODEL = $Model
  ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
  CLAUDE_CODE_SUBAGENT_MODEL = $Model
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'
  CLAUDE_CODE_MAX_CONTEXT_TOKENS = '200000'
  DISABLE_AUTOUPDATER = '1'
  CLAUDE_CODE_GIT_BASH_PATH = $GitBash
}
$settings = [ordered]@{
  env = $envBlock
  permissions = [ordered]@{
    disableBypassPermissionsMode = 'disable'
    deny = @(
      'Bash(sudo:*)','Bash(rm -rf:*)','Bash(rm -r:*)','Bash(rmdir:*)',
      'Bash(del:*)','Bash(Remove-Item:*)','Bash(format:*)','Bash(shutdown:*)',
      'Bash(chmod -R:*)','Bash(chown:*)',
      'Bash(git push --force:*)','Bash(git push -f:*)','Bash(gh repo delete:*)',
      'Read(~/.ssh/**)','Read(~/.aws/**)','Edit(~/.bashrc)','Edit(~/.zshrc)'
    )
  }
}
$Utf8 = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without BOM
[IO.File]::WriteAllText($SettingsFile, ($settings | ConvertTo-Json -Depth 10), $Utf8)
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
[IO.File]::WriteAllText("$Dir\CLAUDE.md", $md, $Utf8)
# Keep the key and the log out of anything published by mistake.
[IO.File]::WriteAllText("$Dir\.gitignore", ".claude/`nsetup-log.txt`n.tmp/`n", $Utf8)

# ---------- 7. Skip the first-run screens (login + "do you trust this folder?") ----------
$script:Step = 'preparing Claude Code'
$F = "$env:USERPROFILE\.claude.json"
try {
  $j = $null
  if ((Test-Path $F) -and ((Get-Content $F -Raw).Trim().Length -gt 2)) {
    Copy-Item $F "$F.hackathon-backup" -Force -ErrorAction SilentlyContinue
    $j = Get-Content $F -Raw -Encoding UTF8 | ConvertFrom-Json
  }
  if (-not $j) { $j = New-Object PSObject }
  $j | Add-Member -NotePropertyName hasCompletedOnboarding -NotePropertyValue $true -Force
  if (-not $j.projects) { $j | Add-Member -NotePropertyName projects -NotePropertyValue (New-Object PSObject) -Force }
  foreach ($k in @($Dir, ($Dir -replace '\\','/'))) {
    $j.projects | Add-Member -NotePropertyName $k -NotePropertyValue ([pscustomobject]@{ hasTrustDialogAccepted = $true }) -Force
  }
  [IO.File]::WriteAllText($F, ($j | ConvertTo-Json -Depth 100), $Utf8)
} catch { NOTE "Could not pre-accept the first-run screens. If Claude asks 'Do you trust the files in this folder?', press Enter." }

# ---------- 8. Typing "claude" anywhere opens the hackathon workspace ----------
# The .cmd file only contains plain letters (%USERPROFILE% is expanded when it runs),
# so it works for Arabic usernames too.
New-Item -ItemType Directory -Force -Path $Shim | Out-Null
if ($ProfileUnsafe) { $cdLine = "cd /d `"$Dir`""; $tmpLine = "set `"TEMP=$Dir\.tmp`"`r`nset `"TMP=$Dir\.tmp`"`r`n" }
else { $cdLine = 'cd /d "%USERPROFILE%\claude-hackathon"'; $tmpLine = '' }
$cmd = "@echo off`r`nset `"PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%PATH%`"`r`n$tmpLine$cdLine`r`n`"%USERPROFILE%\.local\bin\claude.exe`" %*`r`n"
[IO.File]::WriteAllText("$Shim\claude.cmd", $cmd, (New-Object System.Text.ASCIIEncoding))
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
if ($userPath -notlike "*$Shim*") { [Environment]::SetEnvironmentVariable('Path', "$Shim;$userPath", 'User') }
# PowerShell: a profile function wins over programs on PATH. Rewritten cleanly on every run.
try {
  $pol = Get-ExecutionPolicy -Scope CurrentUser
  if ($pol -eq 'Undefined' -or $pol -eq 'Restricted') { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force -ErrorAction Stop }
  $prof = $PROFILE.CurrentUserAllHosts
  New-Item -ItemType Directory -Force -Path (Split-Path $prof) -ErrorAction SilentlyContinue | Out-Null
  $old = ''; if (Test-Path $prof) { $old = [string](Get-Content $prof -Raw -ErrorAction SilentlyContinue) }
  $block = "# >>> hackathon claude >>>`r`nfunction claude { & `"`$HOME\.claude-hackathon-bin\claude.cmd`" @args }`r`n# <<< hackathon claude <<<"
  if ($old -notlike "*$block*") {
    $old = [regex]::Replace($old, '(?s)\r?\n?# >>> hackathon claude >>>.*?# <<< hackathon claude <<<', '')
    Set-Content -Path $prof -Value ($old.TrimEnd() + "`r`n`r`n" + $block + "`r`n") -Encoding UTF8 -NoNewline -ErrorAction Stop
  }
} catch { NOTE "Could not add the PowerShell shortcut. Typing claude still works through the shortcut file." }

}  # end of install-only steps

# ===================================================================================
# ---------- 9. Verify everything (install and check mode) ----------
$script:Step = 'checking the result'
SAY "Result:"
$tools = Test-Tools
$All = $true
if ($tools.git)    { OK "Git $(((& git --version) -split ' ')[2])" } else { BAD "Git or Git Bash missing (T1)"; $All = $false }
if ($tools.gh)     { OK "GitHub CLI $(((& gh --version | Select-Object -First 1) -split ' ')[2])" } else { BAD "GitHub CLI missing (T2)"; $All = $false }
if ($tools.node)   { OK "Node.js $(& node -v)" } else { BAD "Node.js missing or too old (T3)"; $All = $false }
if ($tools.python) { OK "Python $(((& "$PyDir\python.exe" --version 2>&1) -split ' ')[1])" } else { BAD "Python 3.12 missing (T4)"; $All = $false }
$ccv = ''; if (Test-Path $ClaudeExe) { try { $ccv = ((& $ClaudeExe --version 2>$null) -split ' ')[0] } catch {} }
if ($ccv) { OK "Claude Code $ccv" } else { BAD "Claude Code missing (C1)"; $All = $false }
if (Get-ChildItem "$Dir\.claude\skills" -Recurse -Filter SKILL.md -ErrorAction SilentlyContinue) { OK "Design skill" } else { BAD "Design skill missing (S1)"; $All = $false }
if (Test-Path $SettingsFile) { OK "Hackathon settings" } else { BAD "Hackathon settings missing (run the setup command)"; $All = $false }

# Claude test: talk to the AI once, and explain any failure.
$gb = Find-GitBash; if ($gb) { $env:CLAUDE_CODE_GIT_BASH_PATH = $gb }
$ClOK = $false; $ClCode = ''; $ClMsg = ''
if ($ccv) {
  for ($attempt = 1; $attempt -le 2; $attempt++) {
    $tOut = Join-Path $Dir '.tmp\claude-test.out'; $tErr = Join-Path $Dir '.tmp\claude-test.err'
    Remove-Item $tOut, $tErr -ErrorAction SilentlyContinue
    $timed = $false; $out = ''
    try {
      $p = Start-Process -FilePath $ClaudeExe -ArgumentList '-p', '"Reply with exactly: SETUP OK"' -WorkingDirectory $Dir `
            -NoNewWindow -PassThru -RedirectStandardOutput $tOut -RedirectStandardError $tErr
      if (-not $p.WaitForExit(180000)) { try { $p.Kill() } catch {}; $timed = $true }
      $out = (@(Get-Content $tOut -ErrorAction SilentlyContinue) + @(Get-Content $tErr -ErrorAction SilentlyContinue) |
              Where-Object { $_ -and ($_ -notmatch 'unrecognized_model') }) -join "`n"
    } catch { $out = "$_" }
    if ($out -match 'SETUP OK') { $ClOK = $true; break }
    if ($attempt -eq 1 -and $out -match '429|rate.?limit|too many requests|overloaded') {
      Write-Host "  The AI service is busy. Trying again in 30 seconds..."; Start-Sleep -Seconds 30; continue
    }
    break
  }
  if ($ClOK) { OK "AI connection (key ends in ...$KeyEnd)" }
  else {
    $All = $false
    if     ($out -match '401|unauthori|invalid.*key|user not found|no auth') { $ClCode = 'C4'; $ClMsg = 'Your key was rejected. Copy the whole key from your latest email and run the setup command again.' }
    elseif ($out -match '402|credit|insufficient|payment') { $ClCode = 'C5'; $ClMsg = 'Your key has no credit left. Send this screenshot to the help group.' }
    elseif ($out -match '429|rate.?limit|too many|overloaded') { $ClCode = 'C6'; $ClMsg = 'The AI service is busy right now. Wait 5 minutes and run the command again.' }
    elseif ($timed -or $out -match 'ENOTFOUND|ECONNREFUSED|ETIMEDOUT|ECONNRESET|certificate|network|fetch failed') { $ClCode = 'C7'; $ClMsg = 'Claude Code could not reach the AI service. Try another Wi-Fi or a phone hotspot, then run the command again.' }
    elseif ($out -match 'bash|git-bash|Git Bash') { $ClCode = 'W4'; $ClMsg = 'Claude Code cannot find Git Bash. Run the setup command again. If it still fails, send this screenshot to the help group.' }
    else { $ClCode = 'C3'; $ClMsg = 'The AI test did not answer as expected. Send this screenshot and setup-log.txt to the help group.' }
    BAD "AI connection ($ClCode)"
    Write-Host "  Details (for the help group):"
    ($out -split "`n" | Select-Object -Last 10) | ForEach-Object { Write-Host "    $_" }
  }
}

# ---------- 10. GitHub login (needed to publish your site) ----------
$GhUser = ''
if ($tools.gh) {
  & gh auth status *> $null
  if ($LASTEXITCODE -ne 0 -and $Mode -eq 'install') {
    $script:Step = 'logging in to GitHub'
    SAY "Now log in to GitHub."
    Write-Host "1. Press Enter when asked. Your browser opens."
    Write-Host "2. Copy the 8-character code shown here, paste it in the browser, and click Authorize."
    & gh auth login -h github.com -p https -w
  }
  & gh auth status *> $null
  if ($LASTEXITCODE -eq 0) {
    & gh auth setup-git *> $null
    $GhUser = (& gh api user -q .login 2>$null | Out-String).Trim()
    if ($GhUser -and $Mode -eq 'install' -and -not (& git config --global user.name)) {
      & git config --global user.name $GhUser
      & git config --global user.email "$((& gh api user -q .id | Out-String).Trim())+$GhUser@users.noreply.github.com"
    }
  }
}
if ($GhUser) { OK "GitHub account: $GhUser  (not you? run: gh auth logout   then run the setup again)" }
else { BAD "GitHub not logged in (G1)"; $All = $false }

# ---------- 11. Final answer ----------
Write-Host ""
if ($All -and $ClOK) {
  Write-Host ""
  Write-Host "                            " -BackgroundColor Green
  Write-Host "   Your Setup Is Complete   " -ForegroundColor Black -BackgroundColor Green
  Write-Host "                            " -BackgroundColor Green
  Write-Host ""
  Write-Host "PASS - take a screenshot of this window and send it to the organisers." -ForegroundColor Green
  if ($Mode -eq 'install') { Write-Host "Now close ALL PowerShell windows, open PowerShell again, and type:  claude" }
  return
}
if ($Mode -eq 'check') {
  Write-Host "CHECK DONE - items marked FAIL above are not ready. Run the setup command to fix them, or send this screenshot to the help group." -ForegroundColor Yellow
  return
}
if ($ClCode) { Fail $ClCode $ClMsg }
if (-not $GhUser) { Fail G1 "GitHub login did not finish. Run the setup command again and complete the browser step (paste the code, click Authorize). No GitHub account yet? Create one at github.com and verify your email first." }
Fail X2 "Something above is marked FAIL. Run the setup command again. Still failing? Send this screenshot and setup-log.txt to the help group."
}

# ---------- Run it. Any unexpected error still ends with a clear message. ----------
try { Invoke-HackathonSetup }
catch {
  if ("$_" -ne 'HACKATHON_FAIL') {
    Write-Host ""
    Write-Host "FAIL X1" -ForegroundColor Red
    Write-Host "Setup stopped during: $script:Step. Run the same command again. It continues where it stopped." -ForegroundColor White
    Write-Host "If it stops again, send a screenshot of this window to the help group."
    Write-Host "Details: $_"
  }
}
finally { if ($script:Transcript) { try { Stop-Transcript | Out-Null } catch {} } }
