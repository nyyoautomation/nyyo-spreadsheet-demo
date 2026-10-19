<#
Nyyo Sheets kit - install the Apps Script automations into your own Google Sheet (Windows).
Free 1-click install kit, MIT licence. Nyyo Automation.

  powershell -ExecutionPolicy Bypass -File .\setup.ps1                       installs the kit into your Sheet with clasp (asks for your Script ID once)
  powershell -ExecutionPolicy Bypass -File .\setup.ps1 -ScriptId ID_OR_LINK  same, giving the Script ID (or the Apps Script editor link) up front
  powershell -ExecutionPolicy Bypass -File .\setup.ps1 -CopyPaste            no Node.js needed: makes output\NyyoSheetsKit.gs to paste by hand
  powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Check                checks the kit and your settings; sends nothing to Google

Options: -ReplaceOtherCode (your Apps Script project already holds other code), -NoOpen
Safe to run again: your Script ID is kept, the install is reused, the project's current code is backed up
in output\backups\ before every push, and other code is never replaced unless you ask.
Works with Windows PowerShell 5.1 and PowerShell 7 (also on Mac / Linux).
#>
param([switch]$CopyPaste, [switch]$Check, [switch]$NoOpen, [switch]$ReplaceOtherCode, [string]$ScriptId = '')
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$KitVersion = '1.0.0'
$KitDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Order = @('Config.gs', 'Clean.gs', 'Sheets.gs', 'Triggers.gs', 'Menu.gs')
function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Die($code, $m) { Write-Host "[x] $m" -ForegroundColor Red; exit $code }
$Utf8 = New-Object System.Text.UTF8Encoding($false)
function ReadLf($p) { ([IO.File]::ReadAllText($p, $Utf8)) -replace "`r", '' }
function WriteLf($p, $text) { [IO.File]::WriteAllText($p, $text, $Utf8) }
$OnWindows = ($env:OS -eq 'Windows_NT')
$Interactive = -not [Console]::IsInputRedirected

Set-Location $KitDir
foreach ($f in $Order + 'appsscript.json') {
  if (-not (Test-Path (Join-Path $KitDir "apps-script/$f"))) { Die 3 "Kit file apps-script/$f is missing: run this script from the unzipped kit folder." }
}
foreach ($d in 'output', 'config') { New-Item -ItemType Directory -Force -Path (Join-Path $KitDir $d) | Out-Null }

# ---- 1. The one-file version (always made: it is also the fallback) ----
$Bundle = Join-Path $KitDir 'output/NyyoSheetsKit.gs'
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("/**`n * Nyyo Sheets kit $KitVersion - one-file copy-paste version, built from apps-script/ by setup.`n")
[void]$sb.Append(" * Paste ALL of this into Extensions > Apps Script (replace what is there), click Save,`n")
[void]$sb.Append(" * choose nyyoSetup next to Run, click Run and allow access. Then reload the spreadsheet tab.`n */`n")
foreach ($f in $Order) { [void]$sb.Append("`n// ===== $f =====`n"); [void]$sb.Append((ReadLf (Join-Path $KitDir "apps-script/$f"))) }
WriteLf "$Bundle.tmp" $sb.ToString(); Move-Item -Force "$Bundle.tmp" $Bundle
Say 'Copy-paste file ready: output\NyyoSheetsKit.gs'

function CopyPasteHelp {
  $copied = $false
  if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
    try { Set-Clipboard -Value (ReadLf $Bundle) -ErrorAction Stop; $copied = $true } catch { $copied = $false }
  }
  if ($copied) { Say 'The code is now in your clipboard.' } else { Say 'Open output\NyyoSheetsKit.gs and copy all of it (Ctrl + A, then Ctrl + C).' }
  Say 'In your Google Sheet: Extensions > Apps Script, select everything in Code.gs, paste, click Save.'
  Say "Choose nyyoSetup next to Run, click Run and allow access (INSTALL.md, Step 5). Then reload the Sheet: menu 'Nyyo kit'."
  if (-not $NoOpen -and $OnWindows) { Start-Process notepad.exe $Bundle }
}
if ($CopyPaste) { CopyPasteHelp; exit 0 }

# ---- 2. Node.js (for clasp, Google's Apps Script tool). Without it: copy-paste instead ----
$NodeOk = $false
if ((Get-Command node -ErrorAction SilentlyContinue) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
  $major = 0; [void][int]::TryParse(("$(& node -e "console.log(process.versions.node.split('.')[0])" 2>$null)").Trim(), [ref]$major)
  if ($major -ge 20) { $NodeOk = $true } else { Warn "Node.js $(& node -v) is too old (20 or newer is needed)." }
} else { Warn 'Node.js not found.' }
if (-not $NodeOk) {
  Warn 'Using the copy-paste install instead (2 minutes by hand). For the automatic one, install Node.js (INSTALL.md, Step 1) and run setup.ps1 again.'
  CopyPasteHelp; exit 1
}

# ---- 3. Your Script ID (asked once, kept in config\script-id.txt) ----
$IdFile = Join-Path $KitDir 'config/script-id.txt'
function ParseId($v) {
  $v = ("$v" -replace '\s', '')
  if ($v -match '/projects/([^/?#]+)') { $v = $Matches[1] } elseif ($v -match '/d/([^/?#]+)') { $v = $Matches[1] }
  $v = ($v -split '[?#]')[0]
  if ($v -cmatch '^[A-Za-z0-9_-]{25,120}$') { return $v } else { return $null }
}
$Sid = $null
if ($ScriptId) {
  $Sid = ParseId $ScriptId
  if (-not $Sid) { Die 3 'That does not look like a Script ID: copy it from Apps Script > Project Settings > IDs (INSTALL.md, Step 3).' }
} elseif (Test-Path $IdFile) {
  $Sid = ParseId (Get-Content $IdFile -Raw)
  if (-not $Sid) { Die 3 'config\script-id.txt does not hold a valid Script ID. Run setup.ps1 -ScriptId YOUR_ID' }
} elseif ($Interactive) {
  Say 'Open your Sheet > Extensions > Apps Script > Project Settings (gear icon) and copy the Script ID.'
  $Sid = ParseId (Read-Host 'Paste the Script ID (or the Apps Script page link) here, then press Enter')
  if (-not $Sid) { Die 3 'That does not look like a Script ID (INSTALL.md, Step 3). Run setup.ps1 again.' }
} else { Die 3 'No Script ID yet: run setup.ps1 -ScriptId YOUR_SCRIPT_ID (INSTALL.md, Step 3).' }
$old = $null; if (Test-Path $IdFile) { $old = (Get-Content $IdFile -Raw).Trim() }
if ($old -ne $Sid) {
  if (Test-Path $IdFile) { Copy-Item -Force $IdFile "$IdFile.previous" }
  WriteLf "$IdFile.tmp" "$Sid`n"; Move-Item -Force "$IdFile.tmp" $IdFile
  Say 'Saved your Script ID in config\script-id.txt.'
}

# ---- 4. clasp, pinned in package-lock.json (installed once in node_modules, checked by hash) ----
$sha = [Security.Cryptography.SHA256]::Create()
$DepsHash = (($sha.ComputeHash([IO.File]::ReadAllBytes((Join-Path $KitDir 'package-lock.json'))) | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16)
$Stamp = Join-Path $KitDir 'node_modules/.nyyo-deps'
if ($OnWindows) { $ClaspBin = Join-Path $KitDir 'node_modules/.bin/clasp.cmd' } else { $ClaspBin = Join-Path $KitDir 'node_modules/.bin/clasp' }
if ((Test-Path $Stamp) -and ((Get-Content $Stamp -Raw).Trim() -eq $DepsHash) -and (Test-Path $ClaspBin)) { Say 'clasp already installed.' }
else {
  Say 'Installing clasp 3.4.1 (first time only: about 1 minute)...'
  & npm ci --ignore-scripts --no-audit --no-fund --update-notifier=false --loglevel=error | Out-Null
  if ($LASTEXITCODE -ne 0) { Die 4 'Install failed. Check your internet connection and run setup.ps1 again.' }
  WriteLf $Stamp $DepsHash
}
$Clasp = $ClaspBin; if ($env:NYYO_CLASP) { $Clasp = $env:NYYO_CLASP }

# ---- 5. Stage exactly the files to push ----
$Push = Join-Path $KitDir 'output/push'
if (Test-Path $Push) { Remove-Item -Recurse -Force $Push }
New-Item -ItemType Directory -Force -Path $Push | Out-Null
foreach ($f in $Order + 'appsscript.json') { WriteLf (Join-Path $Push $f) (ReadLf (Join-Path $KitDir "apps-script/$f")) }
function WriteProject($dir) { WriteLf (Join-Path $dir '.clasp.json') ("{""scriptId"": ""$Sid"", ""rootDir"": ""."", ""scriptExtensions"": ["".gs""]}`n") }
WriteProject $Push
function GoogleError($text) {
  if ($text -match 'Apps Script API') { Die 4 'Turn on the Apps Script API at https://script.google.com/home/usersettings , wait a minute, then run setup.ps1 again.' }
  elseif ($text -match 'not found|404|does not have permission|permission denied|403') { Die 4 'Google cannot find that Script ID for your account. Check the ID (INSTALL.md, Step 3) and that you signed in with the account that owns the Sheet.' }
  elseif ($text -match 'invalid_grant|credentials|log ?in') { Die 4 'Your Google sign-in has expired: run node_modules\.bin\clasp logout, then setup.ps1 again.' }
  else { Die 4 'Google returned an error (shown above). See INSTALL.md, Troubleshooting.' }
}
function RunClasp($dir) {  # runs clasp in $dir with the remaining args; returns output text, sets $script:RC
  $a = $args
  Push-Location $dir
  try { $out = (& $Clasp @a 2>&1 | Out-String) ; $script:RC = $LASTEXITCODE } finally { Pop-Location }
  return $out
}
if ($Check) {
  Say "Check only: these files would be sent to your Apps Script project $Sid"
  $o = RunClasp $Push 'show-file-status'; Write-Host $o.TrimEnd()
  if ($RC -ne 0) { Die 4 'clasp could not read the kit files.' }
  Say 'Check finished. Nothing was sent to Google.'; exit 0
}

# ---- 6. Google sign-in (once; clasp keeps it in your home folder, outside this kit) ----
$who = RunClasp $KitDir 'show-authorized-user'
if ($who -match 'not logged in') {
  if (-not $Interactive) { Die 4 'Not signed in to Google yet: run setup.ps1 in a PowerShell window so the sign-in page can open.' }
  Say 'A browser page opens: sign in with the Google account that owns the Sheet and click Allow.'
  & $Clasp login
  if ($LASTEXITCODE -ne 0) { Die 4 'Google sign-in did not finish. Run setup.ps1 again.' }
}

# ---- 7. Back up what is in the project now, and never replace other code silently ----
$StampName = Get-Date -Format 'yyyyMMdd-HHmmss'; $n = 1; $Bk = Join-Path $KitDir ('output/backups/{0}-{1:D2}' -f $StampName, $n)
while (Test-Path $Bk) { $n++; $Bk = Join-Path $KitDir ('output/backups/{0}-{1:D2}' -f $StampName, $n) }  # always a new, empty folder
New-Item -ItemType Directory -Force -Path $Bk | Out-Null; WriteProject $Bk
$LogFile = Join-Path $KitDir 'output/last-google-reply.txt'
$o = RunClasp $Bk 'pull'; WriteLf $LogFile $o; Write-Host $o.TrimEnd()
if ($RC -ne 0) { GoogleError $o }
Remove-Item -Force (Join-Path $Bk '.clasp.json')
$Other = @()
$bkFull = (Resolve-Path $Bk).Path
foreach ($file in (Get-ChildItem -Path $Bk -Recurse -File | Where-Object { $_.Name -ne 'appsscript.json' } | Sort-Object FullName)) {
  $rel = $file.FullName.Substring($bkFull.Length + 1) -replace '\\', '/'
  if ($Order -contains $rel) { continue }
  if ($rel -eq 'Code.gs' -and ((ReadLf $file.FullName) -replace '\s', '') -eq 'functionmyFunction(){}') { continue }
  $Other += $rel
}
if ($Other.Count -gt 0 -and -not $ReplaceOtherCode) {
  Die 3 "Your Apps Script project already holds other code: $($Other -join ' '). Nothing was changed (copy saved in output\backups\$(Split-Path -Leaf $Bk)). Use a new Sheet, or run setup.ps1 -ReplaceOtherCode to replace it (the copy stays)."
}
if ($Other.Count -gt 0) { Warn "Replacing other code: $($Other -join ' ') (a copy is in output\backups\$(Split-Path -Leaf $Bk))." }
$bkManifest = Join-Path $Bk 'appsscript.json'
if (Test-Path $bkManifest) {  # keep the time zone already set on the project (it decides the hour of the daily refresh)
  try {
    $tz = (ReadLf $bkManifest | ConvertFrom-Json).timeZone
    if ($tz) {
      $pm = Join-Path $Push 'appsscript.json'
      WriteLf $pm ((ReadLf $pm) -replace '"timeZone":\s*"[^"]*"', ('"timeZone": "' + $tz + '"'))
    }
  } catch { }
}
$all = @(Get-ChildItem -Directory (Join-Path $KitDir 'output/backups') | Sort-Object Name)
if ($all.Count -gt 10) { $all[0..($all.Count - 11)] | ForEach-Object { Remove-Item -Recurse -Force $_.FullName } }  # keep the last 10

# ---- 8. Push ----
Say 'Sending the kit to your Apps Script project...'
$o = RunClasp $Push 'push' '--force'; WriteLf $LogFile $o; Write-Host $o.TrimEnd()
if ($RC -ne 0) { GoogleError $o }
Write-Host ''
Say "Installed Nyyo Sheets kit $KitVersion in your Apps Script project."
Say 'Next, in your Sheet: reload the tab, then menu Nyyo kit > 1. Set up (Google asks for access the first time: INSTALL.md, Step 5).'
if (-not $NoOpen -and $Interactive) { [void](RunClasp $Push 'open-container') }
exit 0
