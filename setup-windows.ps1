# AI Shift Training Hackathon - one-command setup (Windows PowerShell)
#
#   Install:  irm https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-windows.ps1 | iex
#   Check:    $env:HACK_CHECK='1'; irm https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-windows.ps1 | iex
#
# What it installs:
#   Needed:    Git (with Git Bash), GitHub CLI, Claude Code
#   Nice to have (setup carries on without them): Node.js, Python, the UI/UX Pro Max design skill
# Tools are downloaded into your own folder first, so there are no Windows permission popups.
# Only if a download fails does setup try the Windows installer (winget), which shows popups.
#
# Every run ends with "Your Setup Is Complete" or FAIL <code> + what to do.
# Safe to run again any number of times. Written for Windows PowerShell 5.1.
# Never calls "exit": with "irm | iex" that would close the student's window.

function Invoke-HackathonSetup {
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'   # much faster downloads in PowerShell 5.1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# ---------- Pinned versions (tested for this event) ----------
$CcVersion    = '2.1.278'                 # Claude Code
$UiproVersion = '2.15.0'                  # ui-ux-pro-max-cli (UI/UX Pro Max design skills, uupm.cc)
$GhVersion    = '2.101.0'                 # GitHub CLI
$GitTag       = 'v2.55.0.windows.5'; $GitVer = '2.55.0.5'   # Git for Windows (PortableGit)
$UvVersion    = '0.12.17'                 # uv (installs Python)
$NodeLine     = 'latest-v22.x'            # Node.js 22 LTS
$Model        = 'openai/gpt-5-mini'            # default model (students can switch with /model)
$FastModel    = 'openai/gpt-5-mini'            # small background jobs and helpers
$MinBuild = 17763; $MinNode = 18; $MinDiskGB = 5
$NetTries = 18; if ($env:HACK_NET_TRIES) { $NetTries = [int]$env:HACK_NET_TRIES }

$SetupCmd = 'irm https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-windows.ps1 | iex'
$HelpChat = 'https://chat.aishifttraining.com'
$Mode = 'install'; if ($env:HACK_CHECK -eq '1') { $Mode = 'check' }
Remove-Item Env:HACK_CHECK -ErrorAction SilentlyContinue
$script:Step = 'starting'
$Notes = @()

# ---------- Colours ----------
# installing = cyan | do this now = black on yellow | error = white on red | fix = yellow
function OK($t)   { Write-Host "  OK   $t" -ForegroundColor Green }
function TAG($t, $bg) { Write-Host " $t " -ForegroundColor White -BackgroundColor $bg -NoNewline }
function BAD($t)  { Write-Host "  " -NoNewline; TAG 'FAIL' 'DarkRed'; Write-Host " $t" }
function NOTE($t) { Write-Host "  " -NoNewline; Write-Host " NOTE " -ForegroundColor Black -BackgroundColor DarkYellow -NoNewline; Write-Host " $t" }
function ACT($t)  { Write-Host " $t " -ForegroundColor Black -BackgroundColor Yellow }
function FIXT($t) { Write-Host " $t " -ForegroundColor Black -BackgroundColor Cyan }
function INST($t) { Write-Host $t -ForegroundColor White }
function STEPH($n, $t) { Write-Host ""; Write-Host " STEP $n  -  $t " -ForegroundColor White -BackgroundColor DarkBlue }
function SKIP($t) { $script:Notes += $t; NOTE $t }
function Show-Cmd($c) {
  Write-Host ""; ACT "Copy this line, paste it in PowerShell (right-click to paste), press Enter:"
  Write-Host ""; Write-Host "    $c"; Write-Host ""
}
function Fail($code, $msg, $cmd) {
  Write-Host ""
  TAG "FAIL $code" 'DarkRed'; Write-Host ""
  FIXT $msg
  if ($cmd) { Show-Cmd $cmd }
  Write-Host ""
  Write-Host "Still stuck? Take a screenshot of this window and paste it into the Setup Helper chat:"
  Write-Host "  $HelpChat  (sign up with the link in your email)" -ForegroundColor White
  throw "HACKATHON_FAIL"
}
function NetFail {
  Fail N1 "Your internet stopped working, so setup could not download what it needs.`n1. Connect to a different Wi-Fi or your phone's hotspot.`n2. Run setup again with the command below. It continues where it stopped." $SetupCmd
}

# ---------- Internet: wait and retry instead of failing ----------
function Test-Net {
  try { Invoke-WebRequest -Uri 'https://github.com' -Method Head -UseBasicParsing -TimeoutSec 10 | Out-Null; return $true }
  catch { return [bool]$_.Exception.Response }
}
function Wait-Net {
  if (Test-Net) { return $true }
  TAG 'Internet problem.' 'DarkYellow'; FIXT ' Waiting for your internet to come back... (check your Wi-Fi)'
  for ($i = 0; $i -lt $NetTries; $i++) { Start-Sleep -Seconds 10; if (Test-Net) { OK 'Internet is back'; return $true } }
  return $false
}
function Invoke-Retry($what, [scriptblock]$sb) {
  for ($n = 1; $n -le 3; $n++) {
    $r = $false
    try { $r = [bool](& $sb | Select-Object -Last 1) } catch { $r = $false }
    $ErrorActionPreference = 'Continue'
    if ($r) { return $true }
    if ($n -lt 3) {
      FIXT "$what did not work (try $n of 3). Trying again in 10 seconds..."
      if (-not (Wait-Net)) { return $false }
      Start-Sleep -Seconds 10
    }
  }
  return $false
}
function Get-File($url, $out) {
  try { Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 900; return ((Test-Path $out) -and ((Get-Item $out).Length -gt 1000)) }
  catch { return $false }
}

# ---------- Folders ----------
# Usernames with Arabic letters or spaces (C:\Users\محمد, C:\Users\Ahmed Ali) break paths in some tools.
# For those users, the work folder and the tools go to C:\ instead.
$ProfileUnsafe = ($env:USERPROFILE -match '[^\x21-\x7E]')
$Dir = "$env:USERPROFILE\claude-hackathon"; $Tools = "$env:LOCALAPPDATA\hackathon-tools"
if ($ProfileUnsafe) {
  try { New-Item -ItemType Directory -Force -Path 'C:\claude-hackathon', 'C:\hackathon-tools' -ErrorAction Stop | Out-Null; $Dir = 'C:\claude-hackathon'; $Tools = 'C:\hackathon-tools' } catch {}
}
$script:Dir = $Dir
$Shim = "$env:USERPROFILE\.claude-hackathon-bin"
$ClaudeExe = "$env:USERPROFILE\.local\bin\claude.exe"
try { New-Item -ItemType Directory -Force -Path "$Dir\.claude", "$Dir\.tmp", $Tools -ErrorAction Stop | Out-Null }
catch { Fail P8 "Setup could not make its folder. Restart your laptop, then run setup again." $SetupCmd }
$env:UV_CACHE_DIR = "$Tools\uv-cache"; $env:UV_PYTHON_INSTALL_DIR = "$Tools\python"; $env:npm_config_cache = "$Tools\npm-cache"
$Arch = $env:PROCESSOR_ARCHITECTURE

# ---------- Finding tools ----------
function Refresh-Path {
  $py = Find-PythonDir
  $env:Path = "$Shim;$env:USERPROFILE\.local\bin;$Tools\git\cmd;$Tools\gh\bin;$Tools\node;$Tools\npm;" + $(if ($py) { "$py;$py\Scripts;" } else { '' }) +
    [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') +
    ";C:\Program Files\Git\cmd;C:\Program Files\GitHub CLI;C:\Program Files\nodejs;$env:APPDATA\npm"
}
function Find-GitBash {
  $c = @("$Tools\git\bin\bash.exe")
  $g = Get-Command git -ErrorAction SilentlyContinue
  if ($g) { $c += (Join-Path (Split-Path (Split-Path $g.Source)) 'bin\bash.exe') }
  $c += 'C:\Program Files\Git\bin\bash.exe', "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
  foreach ($p in $c) { if ($p -and (Test-Path $p)) { return $p } }
  return $null
}
function Test-PyExe($exe) {
  if (-not $exe -or -not (Test-Path $exe)) { return $false }
  try { return ((& $exe -c "import sys; print(sys.version_info >= (3,10))" | Out-String).Trim() -eq 'True') } catch { return $false }
}
function Find-PythonDir {
  $c = @()
  if (Test-Path "$Tools\python-path.txt") { $c += (Get-Content "$Tools\python-path.txt" -ErrorAction SilentlyContinue | Select-Object -First 1) }
  $c += "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe", "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe"
  foreach ($p in $c) { if (Test-PyExe $p) { return (Split-Path $p) } }
  return $null
}
function Node-Major { try { return [int]((& node -v) -replace '^v','').Split('.')[0] } catch { return 0 } }
function Test-Tools {
  Refresh-Path
  $s = @{}
  $s.git    = [bool](Get-Command git -ErrorAction SilentlyContinue) -and [bool](Find-GitBash)
  $s.gh     = [bool](Get-Command gh -ErrorAction SilentlyContinue)
  $s.node   = ((Node-Major) -ge $MinNode)
  $s.python = [bool](Find-PythonDir)
  return $s
}
function Winget-Install($id, $name, $extra) {   # backup plan: the Windows installer (shows permission popups)
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
  INST "Trying the Windows installer for $name instead..."
  ACT "A Windows popup will ask 'Do you want to allow this app to make changes?'. Click YES."
  ACT "No popup? Look for a flashing shield icon on the taskbar and click it."
  $wa = @('install', '--id', $id, '-e', '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements') + $extra
  & winget @wa
  $ErrorActionPreference = 'Continue'
  return $true
}

Write-Host ""
Write-Host "==== AI Shift Training - Hackathon Setup ====" -ForegroundColor White
if ($Mode -eq 'check') { Write-Host "Check mode: nothing gets installed or changed." }
else {
  Write-Host "Setup has 9 steps. It takes about 10-15 minutes."
  ACT "Keep this window open and your laptop plugged in."
}

# ---------- STEP 1: key ----------
$script:Step = 'reading your key'
$Key = ''
$SettingsFile = "$env:USERPROFILE\.claude\settings.json"     # user settings: key + rules work in every folder
$OldSettings = "$Dir\.claude\settings.local.json"
if ($Mode -eq 'check') {
  foreach ($sf in @($SettingsFile, $OldSettings)) { if (-not $Key -and (Test-Path $sf)) { try { $Key = ((Get-Content $sf -Raw | ConvertFrom-Json).env.ANTHROPIC_AUTH_TOKEN) } catch {} } }
  if (-not $Key) {
    ACT "No key found yet. Paste your key to test it (right-click), or just press Enter to skip."
    $sec = Read-Host "Key" -AsSecureString
    $Key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
  }
} else {
  STEPH '1 of 9' 'Your hackathon key (about 1 minute)'
  Write-Host "1. Open the email we sent you and copy your key. It starts with sk-or-v1-"
  Write-Host "2. Click in this window and RIGHT-CLICK to paste it (or press Ctrl + V)."
  Write-Host "3. Press Enter."
  FIXT "You will only see ***** when you paste. That's normal. Just press Enter."
  $sec = Read-Host "Key" -AsSecureString
  $Key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
$Key = ("$Key" -replace '\s', '')
if ($Mode -eq 'install') {
  if (-not $Key) { Fail K1 "No key was pasted. Run setup again. When it asks for the key, right-click to paste, then press Enter." $SetupCmd }
  if (-not $Key.StartsWith('sk-or-v1-')) { Fail K1 "That is not the hackathon key. Copy the WHOLE key from your email (it starts with sk-or-v1-), then run setup again." $SetupCmd }
  OK "Key received (it ends in ...$($Key.Substring($Key.Length-4)))"
}
$KeyEnd = if ($Key.Length -ge 4) { $Key.Substring($Key.Length-4) } else { '' }

# From here on, what you see is also saved in setup-log.txt (the key is never saved).
try { Start-Transcript -Path "$Dir\setup-log.txt" -Append | Out-Null; $script:Transcript = $true } catch {}

# ---------- STEP 2: check the laptop ----------
$script:Step = 'checking your laptop'
if ($Mode -eq 'install') { STEPH '2 of 9' 'Checking your laptop (about 1 minute)' } else { STEPH 'check' 'Checking your laptop (about 1 minute)' }
$Problems = @()

$build = [Environment]::OSVersion.Version.Build
if ($build -ge $MinBuild) { OK "Windows build $build" }
else { BAD "Windows is too old (build $build)"; $Problems += ,@('P1', "Run Windows Update (Settings > Windows Update), restart, then run setup again.") }
if ($Arch -eq 'ARM64') { NOTE "ARM laptop (Snapdragon). Tell the organisers if anything fails." } else { OK "Processor: $Arch" }

$IsElevated = $false
try { $IsElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch {}
if ($IsElevated) {
  $desktopUser = $null
  try { $desktopUser = (Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" | Select-Object -First 1 | Invoke-CimMethod -MethodName GetOwner).User } catch {}
  if ($desktopUser -and ($desktopUser -ne $env:USERNAME)) {
    BAD "PowerShell is running as a different user"
    $Problems += ,@('W3', "Close this window. Open PowerShell the normal way (do NOT choose 'Run as administrator'). Then run setup again.")
  }
}
if ($ProfileUnsafe) { NOTE "Your Windows username has special letters or a space, so your work folder is $Dir" }

try { $freeGB = [math]::Floor((Get-PSDrive ($env:SystemDrive.TrimEnd(':'))).Free / 1GB) } catch { $freeGB = 99 }
if ($freeGB -ge $MinDiskGB) { OK "Free space: $freeGB GB" }
else { BAD "Free space: only $freeGB GB"; $Problems += ,@('P3', "Your laptop needs 5 GB of free space. Delete big files or empty the Recycle Bin, then run setup again.") }

if (-not (Test-Net)) { if (-not (Wait-Net)) { NetFail } }
function Test-Site($h) {
  for ($t = 1; $t -le 2; $t++) {
    try { Invoke-WebRequest -Uri "https://$h" -Method Head -UseBasicParsing -TimeoutSec 20 | Out-Null; return $true }
    catch { if ($_.Exception.Response) { return $true } }
  }
  return $false
}
$blocked = @()
foreach ($h in 'github.com','api.github.com','raw.githubusercontent.com','objects.githubusercontent.com','claude.ai','openrouter.ai','registry.npmjs.org','nodejs.org') {
  if (-not (Test-Site $h)) { $blocked += $h }
}
if ($blocked.Count -eq 0) { OK "Internet: all download sites work" }
else { BAD "Internet: these sites are blocked: $($blocked -join ', ')"; $Problems += ,@('P4', "Your internet blocks some download sites. Connect to a different Wi-Fi or your phone's hotspot, then run setup again.") }

try {
  $r = Invoke-WebRequest -Uri 'https://github.com' -Method Head -UseBasicParsing -TimeoutSec 15
  $srv = [DateTime]::Parse($r.Headers['Date'], [Globalization.CultureInfo]::InvariantCulture).ToUniversalTime()
  if ([math]::Abs(($srv - (Get-Date).ToUniversalTime()).TotalMinutes) -gt 10) {
    BAD "Clock is wrong"; $Problems += ,@('P5', "Open Settings > Time & language > Date & time. Turn on 'Set time automatically' and click 'Sync now'. Then run setup again.")
  } else { OK "Clock" }
} catch {}

if ($Key) {
  $kr = $null; $sc = 0
  for ($t = 1; $t -le 3; $t++) {
    try { $kr = Invoke-RestMethod -Uri 'https://openrouter.ai/api/v1/key' -Headers @{ Authorization = "Bearer $Key" } -TimeoutSec 30; $sc = 200; break }
    catch { $sc = 0; try { $sc = [int]$_.Exception.Response.StatusCode } catch {}; if ($sc -eq 401 -or $sc -eq 403) { break }; if (-not (Wait-Net)) { break }; Start-Sleep -Seconds 5 }
  }
  if ($sc -eq 200) {
    $rem = $kr.data.limit_remaining
    if (($rem -ne $null) -and ([double]$rem -le 0)) { BAD "Your key has no credit left"; $Problems += ,@('K3', "Your key has no credit. Paste a screenshot into the Setup Helper chat or tell the organisers, so they can top it up.") }
    else { OK "Your key works (ends in ...$KeyEnd)" }
  } elseif ($sc -eq 401 -or $sc -eq 403) { BAD "Your key was not accepted"; $Problems += ,@('K2', "Copy the key again from your LATEST email and run setup again. Still not accepted? Ask in the Setup Helper chat for a new key.") }
  else { BAD "Could not check your key"; $Problems += ,@('K4', "Setup could not reach the AI service. Connect to a different Wi-Fi or your phone's hotspot, then run setup again.") }
} else { NOTE "Key not checked (none given)" }

if ($Problems.Count -gt 0) {
  Write-Host ""; Write-Host "Please fix these, then run setup again:" -ForegroundColor White
  foreach ($p in $Problems) { TAG "FAIL $($p[0])" 'DarkRed'; Write-Host " "; FIXT $p[1] }
  if ($Mode -eq 'install') {
    Show-Cmd $SetupCmd
    Write-Host "Stuck? Paste a screenshot into the Setup Helper chat: $HelpChat"
    throw "HACKATHON_FAIL"
  }
}

# ===================================================================================
if ($Mode -eq 'install') {
$gitArch = if ($Arch -eq 'ARM64') { 'arm64' } else { '64-bit' }
$ghArch  = if ($Arch -eq 'ARM64') { 'arm64' } else { 'amd64' }
$nodeArch = if ($Arch -eq 'ARM64') { 'arm64' } else { 'x64' }
$uvArch  = if ($Arch -eq 'ARM64') { 'aarch64' } else { 'x86_64' }

# ---------- STEP 3: Git (needed) ----------
$script:Step = 'installing Git'
STEPH '3 of 9' 'Git (about 2-3 minutes)'
if ((Test-Tools).git) { OK "Git is already installed. Skipping this step." }
else {
  INST "Downloading Git (about 60 MB)..."
  $ok = Invoke-Retry 'Downloading Git' {
    $exe = "$Tools\PortableGit.exe"
    if (-not (Get-File "https://github.com/git-for-windows/git/releases/download/$GitTag/PortableGit-$GitVer-$gitArch.7z.exe" $exe)) { return $false }
    INST "Unpacking Git (about 1 minute)..."
    Start-Process -FilePath $exe -ArgumentList "-o`"$Tools\git`"", '-y' -Wait -WindowStyle Hidden
    Remove-Item $exe -Force -ErrorAction SilentlyContinue
    return (Test-Path "$Tools\git\bin\bash.exe")
  }
  if (-not (Test-Tools).git) {
    if (Winget-Install 'Git.Git' 'Git' @()) { Start-Sleep -Seconds 2 }
    if (-not (Test-Tools).git -and (Get-Command winget -ErrorAction SilentlyContinue)) {
      FIXT "Git did not install. This usually means the popup was closed or No was clicked. Trying once more."
      Winget-Install 'Git.Git' 'Git' @() | Out-Null
    }
  }
  if (-not (Test-Tools).git) {
    if (-not (Test-Net)) { NetFail }
    Fail T1 "Git could not be installed. Run setup again. If Windows Security showed a warning, allow the file, then run setup again." $SetupCmd
  }
  OK "Git installed"
}

# ---------- STEP 4: GitHub CLI (needed to publish your website) ----------
$script:Step = 'installing the GitHub tool'
STEPH '4 of 9' 'GitHub tool (about 1 minute)'
if ((Test-Tools).gh) { OK "GitHub tool is already installed. Skipping this step." }
else {
  INST "Downloading the GitHub tool..."
  Invoke-Retry 'Downloading the GitHub tool' {
    $z = "$Tools\gh.zip"
    if (-not (Get-File "https://github.com/cli/cli/releases/download/v$GhVersion/gh_${GhVersion}_windows_$ghArch.zip" $z)) { return $false }
    Remove-Item "$Tools\gh" -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $z -DestinationPath "$Tools\gh" -Force
    Remove-Item $z -Force -ErrorAction SilentlyContinue
    return (Test-Path "$Tools\gh\bin\gh.exe")
  } | Out-Null
  if (-not (Test-Tools).gh) { Winget-Install 'GitHub.cli' 'the GitHub tool' @() | Out-Null }
  if (-not (Test-Tools).gh) {
    if (-not (Test-Net)) { NetFail }
    Fail T2 "The GitHub tool could not be installed. Run setup again. If it fails again, paste a screenshot into the Setup Helper chat." $SetupCmd
  }
  OK "GitHub tool installed"
}
# Make git and gh work in every new PowerShell window too
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
foreach ($p in @("$Tools\gh\bin", "$Tools\git\cmd")) {
  if ((Test-Path $p) -and ($userPath -notlike "*$p*")) { $userPath = "$p;$userPath" }
}
[Environment]::SetEnvironmentVariable('Path', $userPath, 'User')

# ---------- STEP 5: Node.js and Python (nice to have, used by the design skill) ----------
$script:Step = 'installing Node.js and Python'
STEPH '5 of 9' 'Node.js and Python (about 2-4 minutes)'
if ((Test-Tools).node) { OK "Node.js is already installed. Skipping it." }
else {
  INST "Downloading Node.js..."
  Invoke-Retry 'Downloading Node.js' {
    $sums = (Invoke-WebRequest -Uri "https://nodejs.org/dist/$NodeLine/SHASUMS256.txt" -UseBasicParsing -TimeoutSec 60).Content
    $name = ($sums -split "`n" | Where-Object { $_ -match "win-$nodeArch\.zip\s*$" } | Select-Object -First 1) -replace '^\S+\s+', ''
    if (-not $name) { return $false }
    $z = "$Tools\node.zip"
    if (-not (Get-File "https://nodejs.org/dist/$NodeLine/$($name.Trim())" $z)) { return $false }
    Remove-Item "$Tools\node", "$Tools\node-tmp" -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $z -DestinationPath "$Tools\node-tmp" -Force
    $inner = Get-ChildItem "$Tools\node-tmp" -Directory | Select-Object -First 1
    Move-Item $inner.FullName "$Tools\node"
    Remove-Item $z, "$Tools\node-tmp" -Recurse -Force -ErrorAction SilentlyContinue
    return (Test-Path "$Tools\node\node.exe")
  } | Out-Null
  if (-not (Test-Tools).node) { Winget-Install 'OpenJS.NodeJS.LTS' 'Node.js' @() | Out-Null }
  if ((Test-Tools).node) { OK "Node.js installed" } else { SKIP "Node.js did not install. Setup continues without it (the design skill will be skipped)." }
}
if ((Test-Tools).python) { OK "Python is already installed. Skipping it." }
else {
  INST "Downloading Python..."
  Invoke-Retry 'Downloading Python' {
    $z = "$Tools\uv.zip"
    if (-not (Get-File "https://github.com/astral-sh/uv/releases/download/$UvVersion/uv-$uvArch-pc-windows-msvc.zip" $z)) { return $false }
    Expand-Archive -Path $z -DestinationPath "$Tools\uv" -Force
    Remove-Item $z -Force -ErrorAction SilentlyContinue
    & "$Tools\uv\uv.exe" python install 3.12 --no-bin | Out-Host
    $ErrorActionPreference = 'Continue'
    $p = (& "$Tools\uv\uv.exe" python find 3.12 | Out-String).Trim()
    if (Test-PyExe $p) { [IO.File]::WriteAllText("$Tools\python-path.txt", $p); return $true }
    return $false
  } | Out-Null
  if (-not (Test-Tools).python) { Winget-Install 'Python.Python.3.12' 'Python' @('--override','/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1') | Out-Null }
  $pd = Find-PythonDir
  if ($pd -and -not (Test-Path "$pd\python3.exe")) { Copy-Item "$pd\python.exe" "$pd\python3.exe" -ErrorAction SilentlyContinue }
  if ((Test-Tools).python) { OK "Python installed" } else { SKIP "Python did not install. Setup continues without it." }
}

# ---------- STEP 6: Claude Code (needed) ----------
$script:Step = 'installing Claude Code'
STEPH '6 of 9' 'Claude Code (about 1-2 minutes)'
$haveCc = ''
if (Test-Path $ClaudeExe) { try { $haveCc = ((& $ClaudeExe --version) -split ' ')[0] } catch {} }
if ($haveCc -and (([version]$haveCc) -ge ([version]$CcVersion))) { OK "Claude Code $haveCc is already installed. Skipping this step." }
else {
  INST "Downloading Claude Code..."
  Invoke-Retry 'Installing Claude Code' {
    try { & ([scriptblock]::Create((Invoke-RestMethod https://claude.ai/install.ps1 -TimeoutSec 120))) $CcVersion } catch {}
    $ErrorActionPreference = 'Continue'
    return (Test-Path $ClaudeExe)
  } | Out-Null
  if (-not (Test-Path $ClaudeExe)) {
    if (-not (Test-Net)) { NetFail }
    Fail C1 "Claude Code could not be installed. If Windows Security showed a warning: open Windows Security > Virus & threat protection > Protection history, allow claude.exe. Then run setup again." $SetupCmd
  }
  $ccv = ''; try { $ccv = (& $ClaudeExe --version | Out-String).Trim() } catch {}
  if (-not $ccv) { Fail C2 "Claude Code is installed but won't start. Antivirus may be blocking it: open Windows Security > Virus & threat protection > Protection history, allow claude.exe. Then run setup again." $SetupCmd }
  OK "Claude Code installed"
}
$ErrorActionPreference = 'Continue'

# ---------- STEP 7: design skill (nice to have) ----------
$script:Step = 'installing the design skill'
STEPH '7 of 9' 'Design skill (about 1 minute)'
$HasSkill = { Test-Path "$env:USERPROFILE\.claude\skills\ui-ux-pro-max\SKILL.md" }
if (Test-Path "$env:USERPROFILE\.claude\skills\design-system\SKILL.md") { OK "Design skill is already installed. Skipping this step." }
elseif (-not (Test-Tools).node) { SKIP "Design skill skipped (it needs Node.js). Claude Code still works." }
else {
  INST "Installing the design skill..."
  $okSkill = Invoke-Retry 'Installing the design skill' {
    $npm = Join-Path (Split-Path (Get-Command node).Source) 'npm.cmd'
    $o = cmd /c "`"$npm`" install -g --prefix `"$Tools\npm`" ui-ux-pro-max-cli@$UiproVersion --no-fund --no-audit 2>&1"
    $uipro = "$Tools\npm\uipro.cmd"
    if (-not (Test-Path $uipro)) { return $false }
    Push-Location $Dir
    & $uipro init --ai claude --global --force --offline | Out-Host
    $ErrorActionPreference = 'Continue'
    if (-not (& $HasSkill)) { & $uipro init --ai claude --global --force | Out-Host; $ErrorActionPreference = 'Continue' }
    Pop-Location
    if (& $HasSkill) { Remove-Item "$Dir\.claude\skills" -Recurse -Force -ErrorAction SilentlyContinue }   # old per-folder copy
    return (& $HasSkill)
  }
  if ($okSkill) { OK "Design skill installed" } else { SKIP "The design skill did not install. Setup continues without it. Claude Code still works." }
}

# ---------- STEP 8: settings ----------
$script:Step = 'saving your settings'
STEPH '8 of 9' 'Saving your settings (a few seconds)'
$GitBash = Find-GitBash
$envBlock = [ordered]@{
  ANTHROPIC_BASE_URL = 'https://openrouter.ai/api'
  ANTHROPIC_AUTH_TOKEN = $Key
  ANTHROPIC_API_KEY = ''
  ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
  ANTHROPIC_DEFAULT_HAIKU_MODEL = $FastModel
  ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
  CLAUDE_CODE_SUBAGENT_MODEL = $FastModel
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'
  CLAUDE_CODE_MAX_CONTEXT_TOKENS = '200000'
  DISABLE_AUTOUPDATER = '1'
}
if ($GitBash) { $envBlock.CLAUDE_CODE_GIT_BASH_PATH = $GitBash }
$picker = [ordered]@{
  replaceBuiltInOptions = $true
  options = @(
    [ordered]@{ model = 'openai/gpt-5-mini'; label = 'GPT-5 mini'; description = 'Default. Fast and cheapest' },
    [ordered]@{ model = 'anthropic/claude-haiku-4.5'; label = 'Claude Haiku 4.5'; description = 'Most Claude-like. Good for building sites' },
    [ordered]@{ model = 'anthropic/claude-sonnet-5'; label = 'Claude Sonnet 5'; description = 'Best results. Uses credit fast' },
    [ordered]@{ model = 'openai/gpt-5.6-terra'; label = 'GPT-5.6 Terra'; description = 'Stronger. Uses more credit' },
    [ordered]@{ model = 'openai/gpt-5.6-sol'; label = 'GPT-5.6 Sol'; description = 'Strongest. Uses credit fastest' }
  )
}
$settings = [ordered]@{
  env = $envBlock
  model = $Model
  modelPicker = $picker
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
$Utf8 = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude" | Out-Null
$cur = $null
if ((Test-Path $SettingsFile) -and ((Get-Content $SettingsFile -Raw).Trim().Length -gt 2)) {
  Copy-Item $SettingsFile "$SettingsFile.hackathon-backup" -Force -ErrorAction SilentlyContinue
  try { $cur = Get-Content $SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $cur = $null }
}
if ($cur) {   # keep everything the student already had; add or replace only the hackathon parts
  if (-not $cur.env) { $cur | Add-Member -NotePropertyName env -NotePropertyValue (New-Object PSObject) -Force }
  foreach ($k in $envBlock.Keys) { $cur.env | Add-Member -NotePropertyName $k -NotePropertyValue $envBlock[$k] -Force }
  $cur.env.PSObject.Properties.Remove('ANTHROPIC_MODEL')                       # old setting that blocked /model choices
  if (-not $cur.model) { $cur | Add-Member -NotePropertyName model -NotePropertyValue $Model -Force }   # keep the student's own choice
  $cur | Add-Member -NotePropertyName modelPicker -NotePropertyValue $picker -Force
  if (-not $cur.permissions) { $cur | Add-Member -NotePropertyName permissions -NotePropertyValue (New-Object PSObject) -Force }
  $cur.permissions | Add-Member -NotePropertyName disableBypassPermissionsMode -NotePropertyValue 'disable' -Force
  $deny = @(@($cur.permissions.deny) + $settings.permissions.deny | Where-Object { $_ } | Select-Object -Unique)
  $cur.permissions | Add-Member -NotePropertyName deny -NotePropertyValue $deny -Force
  [IO.File]::WriteAllText($SettingsFile, ($cur | ConvertTo-Json -Depth 20), $Utf8)
} else {
  [IO.File]::WriteAllText($SettingsFile, ($settings | ConvertTo-Json -Depth 10), $Utf8)
}
Remove-Item $OldSettings, "$Dir\CLAUDE.md" -Force -ErrorAction SilentlyContinue   # old per-folder copies
$md = @'
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
'@
$CM = "$env:USERPROFILE\.claude\CLAUDE.md"
$oldCm = ''; if (Test-Path $CM) { $oldCm = [string](Get-Content $CM -Raw -Encoding UTF8) }
$oldCm = [regex]::Replace($oldCm, '(?s)\r?\n?<!-- >>> hackathon rules >>> -->.*?<!-- <<< hackathon rules <<< -->\r?\n?', '')
[IO.File]::WriteAllText($CM, ($(if ($oldCm.Trim()) { $oldCm.TrimEnd() + "`n`n" } else { '' }) + $md), $Utf8)
[IO.File]::WriteAllText("$Dir\.gitignore", ".claude/`nsetup-log.txt`n.tmp/`n", $Utf8)

# Skip Claude's first-run screens (login + "do you trust this folder?")
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
} catch { NOTE "If Claude asks 'Do you trust the files in this folder?', press Enter." }

# Typing "claude" works in the current folder (a plain new PowerShell window starts in the hackathon folder).
# The .cmd file must only contain plain letters, so the user's folders are written as %VARIABLES%.
function To-Cmd($p) { if (-not $p) { return '' }; return (($p -replace [regex]::Escape($env:LOCALAPPDATA), '%LOCALAPPDATA%') -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%') }
$pyDir = Find-PythonDir
$shimPath = @("$Tools\git\cmd", "$Tools\gh\bin", "$Tools\node", "$Tools\npm") + $(if ($pyDir) { @($pyDir, "$pyDir\Scripts") } else { @() }) | ForEach-Object { To-Cmd $_ }
$shimLines = @('@echo off', "set `"PATH=$($shimPath -join ';');%PATH%`"")
if ($GitBash) { $shimLines += "set `"CLAUDE_CODE_GIT_BASH_PATH=$(To-Cmd $GitBash)`"" }
if ($ProfileUnsafe) { $shimLines += "set `"TEMP=$Dir\.tmp`"", "set `"TMP=$Dir\.tmp`"" }
$shimLines += "if /i `"%CD%`"==`"%USERPROFILE%`" cd /d `"$(To-Cmd $Dir)`"", "if /i `"%CD%`"==`"%SystemRoot%\system32`" cd /d `"$(To-Cmd $Dir)`"", 'echo Claude is working in: %CD%', 'echo To use a photo or PDF from another folder, drag it into this window.', '"%USERPROFILE%\.local\bin\claude.exe" %*'
New-Item -ItemType Directory -Force -Path $Shim | Out-Null
[IO.File]::WriteAllText("$Shim\claude.cmd", (($shimLines -join "`r`n") + "`r`n"), (New-Object System.Text.ASCIIEncoding))
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
if ($userPath -notlike "*$Shim*") { [Environment]::SetEnvironmentVariable('Path', "$Shim;$userPath", 'User') }
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
} catch { NOTE "Typing claude still works through the shortcut file." }
OK "Settings saved"

}  # end of install-only steps

# ===================================================================================
# ---------- STEP 9: test the AI, then connect GitHub ----------
$script:Step = 'testing the AI'
if ($Mode -eq 'install') { STEPH '9 of 9' 'Testing the AI and connecting GitHub (about 2-3 minutes)' }
$tools = Test-Tools
$gb = Find-GitBash; if ($gb) { $env:CLAUDE_CODE_GIT_BASH_PATH = $gb }
$ClOK = $false; $ClCode = ''; $ClMsg = ''; $out = ''; $timed = $false
$ccv = ''; if (Test-Path $ClaudeExe) { try { $ccv = ((& $ClaudeExe --version) -split ' ')[0] } catch {} }
if ($ccv) {
  INST "Asking the AI a test question..."
  for ($attempt = 1; $attempt -le 3; $attempt++) {
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
    if ($out -match '401|unauthori|invalid.*key|user not found|no auth|402|credit|insufficient') { break }
    if ($attempt -lt 3) {
      FIXT "The AI did not answer (try $attempt of 3). Checking internet and trying again..."
      if (-not (Wait-Net)) { break }; Start-Sleep -Seconds 20
    }
  }
  if ($ClOK) { OK "The AI answered (key ends in ...$KeyEnd)" }
  else {
    if     ($out -match '401|unauthori|invalid.*key|user not found|no auth') { $ClCode = 'C4'; $ClMsg = 'Your key was not accepted. Copy the key from your LATEST email and run setup again.' }
    elseif ($out -match '402|credit|insufficient|payment') { $ClCode = 'C5'; $ClMsg = 'Your key has no credit left. Paste a screenshot into the Setup Helper chat or tell the organisers.' }
    elseif ($out -match '429|rate.?limit|too many|overloaded') { $ClCode = 'C6'; $ClMsg = 'The AI is very busy right now. Wait 5 minutes, then run setup again.' }
    elseif ($timed -or $out -match 'ENOTFOUND|ECONNREFUSED|ETIMEDOUT|ECONNRESET|certificate|network|fetch failed') { $ClCode = 'N1' }
    elseif ($out -match 'bash|git-bash|Git Bash') { $ClCode = 'W4'; $ClMsg = 'Claude Code cannot find Git Bash. Run setup again.' }
    else { $ClCode = 'C3'; $ClMsg = 'The AI test did not work. Paste a screenshot of this window into the Setup Helper chat.' }
    BAD "The AI did not answer ($ClCode)"
    Write-Host "  Details (for the helpers):"
    ($out -split "`n" | Select-Object -Last 10) | ForEach-Object { Write-Host "    $_" }
  }
}

$script:Step = 'connecting GitHub'
$GhUser = ''
function Gh-Ok { cmd /c "gh auth status >nul 2>&1"; return ($LASTEXITCODE -eq 0) }
if ($tools.gh) {
  if (-not (Gh-Ok) -and $Mode -eq 'install') {
    for ($t = 1; $t -le 3; $t++) {
      Write-Host ""; INST "Connect your GitHub account (about 2 minutes)"
      ACT "1. Press Enter. GitHub should open in your browser by itself."
      Write-Host "   If the browser does NOT open, open this link yourself:  https://github.com/login/device"
      ACT "2. Make sure you are logged in to GitHub in the browser."
      ACT "3. Click the green 'Continue' button."
      ACT "4. Type the 8-character code shown below in this window (it looks like ABCD-1234)."
      ACT "5. Click the green 'Authorize github' button. Then come back to this window."
      Write-Host "   If it asks 'Authenticate Git with your GitHub credentials?', press Enter (Yes)."
      Write-Host ""
      & gh auth login -h github.com -p https -w
      $ErrorActionPreference = 'Continue'
      if (Gh-Ok) { break }
      if ($t -lt 3) { FIXT "GitHub is not connected yet (try $t of 3)."; Read-Host "Press Enter to try the GitHub step again" | Out-Null }
    }
  }
  if (Gh-Ok) {
    cmd /c "gh auth setup-git >nul 2>&1"
    $GhUser = (& gh api user -q .login | Out-String).Trim()
    if ($GhUser -and $Mode -eq 'install' -and -not (& git config --global user.name)) {
      & git config --global user.name $GhUser
      & git config --global user.email "$((& gh api user -q .id | Out-String).Trim())+$GhUser@users.noreply.github.com"
    }
  }
}

# ---------- Result ----------
Write-Host ""; Write-Host " RESULT " -ForegroundColor White -BackgroundColor DarkBlue
$All = $true
if ($tools.git) { OK "Git" } else { BAD "Git (T1)"; $All = $false }
if ($tools.gh)  { OK "GitHub tool" } else { BAD "GitHub tool (T2)"; $All = $false }
if ($ccv) { OK "Claude Code $ccv" } else { BAD "Claude Code (C1)"; $All = $false }
if ((Test-Path $SettingsFile) -and ((Get-Content $SettingsFile -Raw) -match '"ANTHROPIC_AUTH_TOKEN":\s*"sk-or-')) { OK "Your settings (work in every folder)" } else { BAD "Your settings (run setup)"; $All = $false }
if ($ClOK) { OK "The AI works" } else { BAD "The AI ($(if ($ClCode) { $ClCode } else { 'not tested' }))"; $All = $false }
if ($GhUser) { OK "GitHub account: $GhUser  (not you? run  gh auth logout  then run setup again)" } else { BAD "GitHub not connected (G1)"; $All = $false }
if ($tools.node)   { OK "Node.js" } else { NOTE "Node.js not installed (optional)" }
if ($tools.python) { OK "Python" } else { NOTE "Python not installed (optional)" }
if (Test-Path "$env:USERPROFILE\.claude\skills\ui-ux-pro-max\SKILL.md") { OK "Design skills (UI/UX Pro Max)" } else { NOTE "Design skill not installed (optional)" }

Write-Host ""
if ($All) {
  Write-Host "                                  " -BackgroundColor Green
  Write-Host "     Your Setup Is Complete       " -ForegroundColor Black -BackgroundColor Green
  Write-Host "                                  " -BackgroundColor Green
  Write-Host ""
  Write-Host "PASS" -ForegroundColor Green
  ACT "Take a screenshot of this window and submit it in the form from your email."
  if ($Mode -eq 'install') {
    Write-Host ""
    Write-Host "To start Claude Code:"
    Write-Host "  1. Close ALL PowerShell windows."
    Write-Host "  2. Open PowerShell again (Windows key, type PowerShell, Enter)."
    Write-Host "  3. Type  claude  and press Enter."
    Write-Host ""
    Write-Host "Your key works in every folder. In a new PowerShell window, claude starts in: $Dir"
    Write-Host "To work somewhere else, go to that folder first (e.g.  cd Desktop\my-site ), then type  claude"
    Write-Host "If Claude asks 'Do you trust the files in this folder?', press Enter."
  }
  return
}
if ($Mode -eq 'check') {
  TAG 'CHECK DONE' 'DarkYellow'; FIXT " Anything marked FAIL above is not ready. Run setup to fix it."
  Show-Cmd $SetupCmd
  return
}
if ($ClCode -eq 'N1') { NetFail }
if ($ClCode) { Fail $ClCode $ClMsg $SetupCmd }
if (-not $GhUser) { Fail G1 "GitHub is not connected yet. Run setup again and do the GitHub steps (press Enter, click the green buttons, type the code).`nNo GitHub account? Make one at github.com, confirm your email, then run setup again." $SetupCmd }
Fail X2 "Something above is marked FAIL. Run setup again." $SetupCmd
}

# ---------- Run it. Any unexpected error still ends with a clear message. ----------
try { Invoke-HackathonSetup }
catch {
  if ("$_" -ne 'HACKATHON_FAIL') {
    Write-Host ""
    Write-Host " FAIL X1 " -ForegroundColor White -BackgroundColor DarkRed
    Write-Host "Setup stopped during: $script:Step. Run setup again. It continues where it stopped. " -ForegroundColor Black -BackgroundColor Cyan
    Write-Host ""
    Write-Host " Copy this line, paste it in PowerShell (right-click to paste), press Enter: " -ForegroundColor Black -BackgroundColor Yellow
    Write-Host ""
    Write-Host "    irm https://raw.githubusercontent.com/Sai-Blackbyrn/hackathon-setup/refs/heads/main/setup-windows.ps1 | iex"
    Write-Host ""
    Write-Host "Still stuck? Paste a screenshot into the Setup Helper chat: https://chat.aishifttraining.com"
    Write-Host "Details: $_"
  }
}
finally { if ($script:Transcript) { try { Stop-Transcript | Out-Null } catch {} } }
