<#
.SYNOPSIS
  Installs the Bhaktivedanta VedaBase (Folio Views 4.3, VedaBase 25, VaniBase 25)
  on Windows 10 or 11.

.DESCRIPTION
  Start it by double-clicking Install-VedaBase-Windows.cmd. It follows Ekanatha
  dasa's README: the files from his Google Drive folders go to the root of C:\,
  each checked against manifest\drive-files.tsv (size and SHA-256), and the
  original Install.exe installs them while you click through its wizard.

  It runs in three phases so that each step runs as the right account:
    User     (you)            checks, then asks Windows for administrator rights
    Machine  (administrator)  downloads, Install.exe, and the fixes below
    Finish   (you)            your Folio settings, your desktop icon

  What it adds to the README's steps:
    - The shadow file the VedaBase icon opens names its master infobase
      "VedaBase_25.nfo", while the installed infobase is called
      "Bhaktivedanta Vedabase 2003.nfo"; a hard link gives it both names.
    - VaniBase 25, with its own icons.
    - All 51 fonts registered with Windows (Install.exe only copies them).
    - Folio's per-user settings, without which its contents pane shows broken
      diacritics, for every account on the PC (Active Setup), and Folio's
      swap and index folders pointed at a folder every account can write.

  Running it again is safe: it finishes whatever is missing. Logs:
  %TEMP%\VedaBase-install.log and C:\Program Files\VedaBase-Setup\install.log.

.PARAMETER NoVaniBase
  Leave out VaniBase 25 (393 MB).

.PARAMETER NoCompatMode
  Do not set Windows XP SP2 compatibility mode on Views.exe.
#>
[CmdletBinding()]
param(
  [ValidateSet('User', 'Machine')]
  [string]$Phase = 'User',
  [string]$RunToken = '',
  [switch]$NoVaniBase,
  [switch]$NoCompatMode
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Windows PowerShell's progress bar slows downloads badly

$Root = Split-Path -Parent $PSScriptRoot
$Manifest = Join-Path $Root 'manifest\drive-files.tsv'
$FontList = Join-Path $Root 'manifest\fonts.tsv'
$UserDefaults = Join-Path $PSScriptRoot 'vedabase-defaults.reg'
$AppDir = 'C:\Bhaktivedanta VedaBase 2003'
$NfoDir = Join-Path $AppDir 'Nfo'
$Master = Join-Path $NfoDir 'Bhaktivedanta Vedabase 2003.nfo'
$MasterSize = 649011200
# Under Program Files, where only administrators can create folders, so no
# other account can plant files the elevated phase would trust.
$Cache = Join-Path $env:ProgramFiles 'VedaBase-Setup'
$StagedList = Join-Path $Cache 'staged-in-C-root.txt'
$MachineDone = Join-Path $Cache 'machine-phase.done'
$SdwBackup = Join-Path $Cache 'sdw-backup'
$SdwPending = Join-Path $Cache 'sdw-restore.pending'
$CachedDefaults = Join-Path $Cache 'vedabase-defaults.reg'
$StageItems = @('C:\Install.exe', 'C:\Fonts', 'C:\Nfo', 'C:\Spec')
$DriveUrl = 'https://drive.usercontent.google.com/download?export=download&confirm=t&id='
$ActiveSetup = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{8C9EE47A-5102-4B2C-B476-0212DFBB3EC0}'

function Say([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Warn([string]$Message) { Write-Host "warning: $Message" -ForegroundColor Yellow }
function Fail([string]$Message) {
  Write-Host "error: $Message" -ForegroundColor Red
  Write-Host ''
  Read-Host 'Press Enter to close this window' | Out-Null
  exit 1
}

# reg.exe reports even success on stderr, which Windows PowerShell
# turns into a terminating error when $ErrorActionPreference is Stop.
function Invoke-Tool([string]$Exe, [string[]]$Arguments) {
  $saved = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Exe @Arguments 2>&1 | Out-Null; return $LASTEXITCODE }
  finally { $ErrorActionPreference = $saved }
}

function Read-Table([string]$Path) {
  foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
    if ($line -and -not $line.StartsWith('#')) { , ($line -split "`t") }
  }
}

function Test-Installed {
  (Test-Path -LiteralPath (Join-Path $AppDir 'Views.exe')) -and
  (Test-Path -LiteralPath $Master) -and ((Get-Item -LiteralPath $Master).Length -eq $MasterSize)
}

# ======================================================================== User phase
function Invoke-UserPhase {
  Write-Host 'Bhaktivedanta VedaBase 25 for Windows' -ForegroundColor White
  foreach ($f in $Manifest, $FontList, $UserDefaults) {
    if (-not (Test-Path -LiteralPath $f)) {
      Fail "Cannot find $f. Extract the whole ZIP (right-click it, Extract All) and run the installer from the extracted folder."
    }
  }
  # Files unzipped from a download carry the Mark of the Web; clear it so
  # Windows does not question the scripts again in the elevated window.
  Get-ChildItem -LiteralPath $Root -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
  if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Fail ('Windows is restricting PowerShell here (Smart App Control or another App Control policy). ' +
      'That policy would also block the 2003 VedaBase programs. See "Smart App Control" in README.md.')
  }
  $sac = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -ErrorAction SilentlyContinue
  if ($sac -and $sac.PSObject.Properties['VerifiedAndReputablePolicyState'] -and $sac.VerifiedAndReputablePolicyState -eq 1) {
    Warn ('Smart App Control is on, so Windows may block the 2003 VedaBase programs. ' +
      'See "Smart App Control" in README.md before turning it off.')
  }
  $free = (Get-PSDrive -Name C).Free
  if ($free -lt 3GB) { Fail ('Drive C: needs at least 3 GB free (it has {0:N1} GB).' -f ($free / 1GB)) }

  Say 'Windows will now ask for administrator rights (the installer writes to C:\ and the Fonts folder).'
  $token = [guid]::NewGuid().ToString()
  $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Phase Machine -RunToken $token"
  if ($NoVaniBase) { $argLine += ' -NoVaniBase' }
  if ($NoCompatMode) { $argLine += ' -NoCompatMode' }
  try {
    $proc = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
      -Verb RunAs -ArgumentList $argLine -PassThru
  } catch {
    Fail 'Administrator permission was not given, so nothing was installed.'
  }
  # Wait for that one process only (Start-Process -Wait would also wait for
  # anything the installer leaves running, such as a media player).
  $proc.WaitForExit()
  $done = (Test-Path -LiteralPath $MachineDone) -and (([string](Get-Content -LiteralPath $MachineDone -Raw)).Trim() -eq $token)
  if (-not $done) {
    Fail "The administrator window did not finish. Its log is $Cache\install.log; run this installer again to continue."
  }
  Invoke-FinishPhase
}

# ======================================================================== Machine phase

function Test-Intact([string]$Path, $Size, [string]$Sha) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  if ((Get-Item -LiteralPath $Path).Length -ne [int64]$Size) { return $false }
  return ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -eq $Sha)
}

# Install.exe, Fonts\, Nfo\ and Spec\ must sit at the root of C:\ (the README);
# VaniBase goes to the cache folder. The documents in the Drive folders are not
# needed (returns $null).
function Get-Target([string]$Rel) {
  $win = $Rel -replace '/', '\'
  if ($Rel -eq 'Install.exe' -or $Rel -like 'Fonts/*' -or $Rel -like 'Nfo/*' -or $Rel -like 'Spec/*') {
    return "C:\$win"
  }
  if ($Rel -like 'VaniBase/*') { return "$Cache\$win" }
  return $null
}

# Windows' curl checks certificate revocation through Schannel, which fails on
# networks that block the revocation servers; curl 7.70+ can skip that check
# when the servers are unreachable. Older builds (Windows 10 1803 had 7.55)
# would reject the option.
$script:CurlRevoke = $null
function Test-CurlRevokeBestEffort {
  if ($null -eq $script:CurlRevoke) {
    $script:CurlRevoke = $false
    try {
      $v = (& "$env:SystemRoot\System32\curl.exe" --version 2>$null | Select-Object -First 1)
      if ($v -match '^curl (\d+)\.(\d+)') {
        $script:CurlRevoke = ([int]$Matches[1] -gt 7) -or ([int]$Matches[1] -eq 7 -and [int]$Matches[2] -ge 70)
      }
    } catch { }
  }
  return $script:CurlRevoke
}

function Get-DriveFile($Row, [string]$Path) {
  $id, $rel, $size, $sha = $Row
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
  $url = $DriveUrl + $id
  $curl = "$env:SystemRoot\System32\curl.exe"
  $extra = @()
  if (Test-CurlRevokeBestEffort) { $extra = @('--ssl-revoke-best-effort') }
  for ($try = 1; $try -le 3; $try++) {
    Say "Downloading $rel"
    $ok = $false
    if (Test-Path -LiteralPath $curl) {
      # curl's progress meter is on stderr; keep PowerShell from treating it as an error.
      $ErrorActionPreference = 'Continue'
      & $curl -fL --retry 5 --retry-delay 3 --connect-timeout 30 --speed-limit 1024 --speed-time 120 @extra -o "$Path.part" $url
      $ok = ($LASTEXITCODE -eq 0)
      $ErrorActionPreference = 'Stop'
    } else {
      try { Invoke-WebRequest -Uri $url -OutFile "$Path.part" -UseBasicParsing; $ok = $true } catch { $ok = $false }
    }
    if ($ok) { Move-Item -LiteralPath "$Path.part" -Destination $Path -Force }
    if (Test-Intact $Path $size $sha) { return }
    Remove-Item -LiteralPath $Path, "$Path.part" -Force -ErrorAction SilentlyContinue
    if ($try -lt 3) { Warn "$rel did not arrive intact, retrying"; Start-Sleep -Seconds (10 * $try) }
  }
  throw ("$rel did not download intact. Usually Google Drive is limiting downloads for a while: " +
    'wait a few hours and run the installer again. Check the internet connection and free disk space too.')
}

function New-Shortcut([string]$Path, [string]$Arguments) {
  # WScript.Shell belongs to Windows Script Host, which Microsoft is phasing
  # out with VBScript; a missing shortcut must not stop the install.
  try {
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($Path)
    $link.TargetPath = Join-Path $AppDir 'Views.exe'
    $link.Arguments = $Arguments
    $link.WorkingDirectory = $AppDir
    $link.IconLocation = (Join-Path $AppDir 'vedabase.ico') + ',0'
    $link.Save()
  } catch {
    Warn "Could not create the shortcut $Path ($($_.Exception.Message))"
  }
}

# Copy any missing font into C:\Windows\Fonts and register every one that no
# registry value points at yet, then load them for this session.
function Register-Fonts {
  $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
  $known = @{}
  foreach ($p in (Get-ItemProperty -LiteralPath $key).PSObject.Properties) {
    if ($p.Value -is [string] -and $p.Value) {
      $v = $p.Value
      $known[$v.Substring($v.LastIndexOf('\') + 1).ToLowerInvariant()] = $true
    }
  }
  $added = @()
  foreach ($row in Read-Table $FontList) {
    $file, $name = $row
    $dest = "$env:windir\Fonts\$file"
    if (-not (Test-Path -LiteralPath $dest)) {
      if (-not (Test-Path -LiteralPath "C:\Fonts\$file")) { Warn "Font $file is missing"; continue }
      Copy-Item -LiteralPath "C:\Fonts\$file" -Destination $dest
    }
    if (-not $known.ContainsKey($file.ToLowerInvariant())) {
      New-ItemProperty -LiteralPath $key -Name $name -Value $file -PropertyType String -Force | Out-Null
      $added += $dest
    }
  }
  if ($added) {
    Say "Registered $($added.Count) fonts with Windows"
    try {
      Add-Type -Namespace VedaBaseSetup -Name Gdi -MemberDefinition '[System.Runtime.InteropServices.DllImport("gdi32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)] public static extern int AddFontResource(string file);'
      foreach ($f in $added) { [void][VedaBaseSetup.Gdi]::AddFontResource($f) }
    } catch {
      Warn 'The new fonts load at the next sign-in; restart Windows if the diacritics look wrong.'
    }
  }
}

function Complete-Install([switch]$SkipFonts) {
  # The shadow file the VedaBase icon opens names its master "VedaBase_25.nfo".
  # Re-link if an old alias survived an uninstall and no longer matches.
  $alias = Join-Path $NfoDir 'VedaBase_25.nfo'
  if (Test-Path -LiteralPath $alias) {
    $a = Get-Item -LiteralPath $alias
    $m = Get-Item -LiteralPath $Master
    if ($a.Length -ne $m.Length -or $a.LastWriteTimeUtc -ne $m.LastWriteTimeUtc) { Remove-Item -LiteralPath $alias -Force }
  }
  if (-not (Test-Path -LiteralPath $alias)) {
    Say 'Linking VedaBase_25.nfo to the installed infobase'
    try { New-Item -ItemType HardLink -Path $alias -Target $Master | Out-Null }
    catch { Copy-Item -LiteralPath $Master -Destination $alias }
  }

  if (-not $NoVaniBase) {
    $src = Join-Path $Cache 'VaniBase'
    $nfo = Join-Path $NfoDir 'VaniBase_25.nfo'
    $sdw = Join-Path $NfoDir 'VaniBase_25.sdw'
    if (Test-Path -LiteralPath "$src\VaniBase_25.nfo") {
      if (-not (Test-Path -LiteralPath $nfo) -or (Get-Item -LiteralPath $nfo).Length -ne (Get-Item -LiteralPath "$src\VaniBase_25.nfo").Length) {
        Say 'Adding VaniBase 25'
        Copy-Item -LiteralPath "$src\VaniBase_25.nfo" -Destination $nfo -Force
      }
    }
    # Copied once only: your notes and highlights live in the shadow file.
    if (-not (Test-Path -LiteralPath $sdw) -and (Test-Path -LiteralPath "$src\VaniBase_25.sdw")) {
      Copy-Item -LiteralPath "$src\VaniBase_25.sdw" -Destination $sdw
    }
    $arguments = "`"$sdw`""
    New-Shortcut "$env:PUBLIC\Desktop\VaniBase 25.lnk" $arguments
    $menu = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Bhaktivedanta VedaBase 2003"
    New-Item -ItemType Directory -Force -Path $menu | Out-Null
    New-Shortcut "$menu\VaniBase 25.lnk" $arguments
  }

  # Fonts only once the installer is done, so this never races its own copying.
  if (-not $SkipFonts) { Register-Fonts }
}

# Install.exe records the installing account's TEMP folder as Folio's swap and
# index folders. Another account cannot write there, so point both at a folder
# inside the program folder, which every account may write to.
function Set-SharedTemp {
  $temp = Join-Path $AppDir 'Temp'
  New-Item -ItemType Directory -Force -Path $temp | Out-Null
  foreach ($k in 'Server\SwapPath', 'Server\Index\TempPath') {
    $key = "HKLM:\SOFTWARE\WOW6432Node\VedaBase\4\$k"
    if (Test-Path -LiteralPath $key) { Set-ItemProperty -LiteralPath $key -Name '(default)' -Value $temp }
  }
}

# Install.exe writes Folio's display settings only for the account that ran it.
# Active Setup gives every account the defaults at its next sign-in, and the
# finish phase gives them to you now. Both check the contents font rather than
# the key, which Folio creates itself when it closes. The file imported at
# sign-in lives in the cache, which only administrators can change: in the
# program folder any account could edit it, and it would be imported into
# every other account.
$FolioPrefs = 'HKCU\Software\VedaBase\4\Views\NfoView\Preferences'
function Test-FolioSettings {
  $p = Get-ItemProperty -LiteralPath 'HKCU:\Software\VedaBase\4\Views\NfoView\Preferences' -ErrorAction SilentlyContinue
  return [bool]($p -and $p.PSObject.Properties['FontName'] -and $p.FontName -eq 'BellCentennial')
}
function Register-UserDefaults {
  Copy-Item -LiteralPath $UserDefaults -Destination $CachedDefaults -Force
  Remove-Item -LiteralPath (Join-Path $AppDir 'vedabase-defaults.reg') -Force -ErrorAction SilentlyContinue
  if (-not (Test-Path -LiteralPath $ActiveSetup)) { New-Item -Path $ActiveSetup | Out-Null }
  $stub = "cmd.exe /c reg query `"$FolioPrefs`" /v FontName 2>nul | find /i `"BellCentennial`" >nul || reg import `"$CachedDefaults`""
  New-ItemProperty -LiteralPath $ActiveSetup -Name '(default)' -Value 'VedaBase 25 settings' -PropertyType String -Force | Out-Null
  New-ItemProperty -LiteralPath $ActiveSetup -Name 'StubPath' -Value $stub -PropertyType String -Force | Out-Null
  New-ItemProperty -LiteralPath $ActiveSetup -Name 'Version' -Value '1' -PropertyType String -Force | Out-Null
  New-ItemProperty -LiteralPath $ActiveSetup -Name 'IsInstalled' -Value 1 -PropertyType DWord -Force | Out-Null
}

# Install.exe puts its desktop icon on the desktop of the account that ran it;
# move it to the shared desktop so every account sees it.
function Move-DesktopIcon {
  $name = 'Bhaktivedanta VedaBase 2003.lnk'
  $mine = Join-Path ([Environment]::GetFolderPath('Desktop')) $name
  $public = Join-Path $env:PUBLIC "Desktop\$name"
  if (Test-Path -LiteralPath $mine) {
    if (Test-Path -LiteralPath $public) { Remove-Item -LiteralPath $mine -Force }
    else { Move-Item -LiteralPath $mine -Destination $public -Force }
  }
  if (-not (Test-Path -LiteralPath $public)) { New-Shortcut $public "`"$NfoDir\Bhaktivedanta Vedabase 2003.sdw`"" }
}

# The installer has finished copying once Views.exe and the whole infobase exist
# and nothing holds the infobase open any more.
function Test-CopyDone {
  if (-not (Test-Installed)) { return $false }
  try { [IO.File]::Open($Master, 'Open', 'Read', 'None').Close(); return $true } catch { return $false }
}

# Cleanup deletes only files whose size and SHA-256 match the manifest, inside
# the staging items this installer created (recorded in the cache, which only
# administrators can write), then any of those folders left empty.
function Remove-Staging {
  if (-not (Test-Path -LiteralPath $StagedList)) { return }
  $ours = @(Get-Content -LiteralPath $StagedList | Where-Object { $_ -in $StageItems })
  foreach ($row in Read-Table $Manifest) {
    $rel = $row[1]
    if ($rel -eq 'Install.exe') { $top = 'C:\Install.exe' }
    elseif ($rel -like 'Fonts/*' -or $rel -like 'Nfo/*' -or $rel -like 'Spec/*') { $top = 'C:\' + $rel.Split('/')[0] }
    else { continue }
    $path = 'C:\' + ($rel -replace '/', '\')
    if ($top -in $ours -and (Test-Intact $path $row[2] $row[3])) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
  }
  $left = @()
  foreach ($item in $ours) {
    if ((Test-Path -LiteralPath $item -PathType Container) -and -not (Get-ChildItem -LiteralPath $item -Force | Select-Object -First 1)) {
      Remove-Item -LiteralPath $item -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $item) { $left += $item }
  }
  if ($left) { Set-Content -LiteralPath $StagedList -Value $left } else { Remove-Item -LiteralPath $StagedList -Force }
}

# Shadow files kept aside before a wizard run go back afterwards, even if a
# restart cut that run short: the list of them stays until they are back.
function Restore-Notes {
  if (-not (Test-Path -LiteralPath $SdwPending) -or -not (Test-Path -LiteralPath $NfoDir)) { return }
  foreach ($name in @(Get-Content -LiteralPath $SdwPending)) {
    $saved = Join-Path $SdwBackup $name
    if ($name -and (Test-Path -LiteralPath $saved)) { Copy-Item -LiteralPath $saved -Destination (Join-Path $NfoDir $name) -Force }
  }
  Remove-Item -LiteralPath $SdwPending -Force
  Say "Kept your existing notes and highlights (.sdw files; a copy stays in $SdwBackup)"
}

function Invoke-Wizard {
  # Reinstalling over an earlier copy replaces its shadow files, which hold the
  # user's notes; keep them aside and put them back afterwards.
  if (Test-Path -LiteralPath $NfoDir) {
    $kept = @(Get-ChildItem -LiteralPath $NfoDir -Filter '*.sdw' -File)
    if ($kept) {
      New-Item -ItemType Directory -Force -Path $SdwBackup | Out-Null
      $kept | Copy-Item -Destination $SdwBackup -Force
      Set-Content -LiteralPath $SdwPending -Value ($kept | ForEach-Object { $_.Name })
    }
  }

  Say 'Starting the original installer, Install.exe'
  Write-Host @'

  In the installer window:
    1. Next, then Accept the license, then type your name, then Next.
    2. Next again (ignore its list of old Windows versions).
    3. "Select Install Type": choose Custom, then Next.
    4. Tick "All Folio Program Files" and "VedaBase Master Files"
       (leave "WinAmp media player" unticked), then Next.
    5. Next, Next, Install, then Next, Next and Finish.
    6. Close the Fonts window it opens. If it asks to restart now, choose
       Cancel. This window finishes the setup.

'@
  Start-Process -FilePath 'C:\Install.exe' -WorkingDirectory 'C:\'
  # The launcher hands over to irsetup.exe and exits; follow whichever runs.
  $fixed = $false
  $quietSince = Get-Date
  while ($true) {
    # Done while the wizard is still on its last pages, in case its restart
    # prompt gets an OK.
    if (-not $fixed -and (Test-CopyDone)) {
      Complete-Install -SkipFonts
      $fixed = $true
    }
    if (Get-Process -Name 'irsetup', 'Install' -ErrorAction SilentlyContinue) {
      $quietSince = Get-Date
    } elseif (((Get-Date) - $quietSince).TotalSeconds -gt 15) {
      break
    }
    Start-Sleep -Seconds 2
  }

  Restore-Notes
  if (-not (Test-Path -LiteralPath (Join-Path $AppDir 'Views.exe'))) {
    throw 'The installer did not finish (Views.exe is missing). Run this installer again to retry.'
  }
  if (-not (Test-Installed)) {
    throw 'The VedaBase infobase was not installed. Run this installer again and tick "VedaBase Master Files" on the "Select Packages" page.'
  }
}

function Invoke-MachinePhase {
  Write-Host 'VedaBase setup (administrator)' -ForegroundColor White
  New-Item -ItemType Directory -Force -Path $Cache | Out-Null
  try { Start-Transcript -LiteralPath (Join-Path $Cache 'install.log') -Append | Out-Null } catch { }
  Restore-Notes  # notes kept aside by a run that a restart cut short

  $installed = Test-Installed
  if ($installed) { Say 'Folio Views is already installed; finishing the setup' }
  elseif ((Test-Path -LiteralPath $Master) -and (Get-Item -LiteralPath $Master).Length -ne $MasterSize) {
    throw ("$AppDir holds a different VedaBase infobase: an older VedaBase, or an install that was cut short. " +
      "Copy your notes (the .sdw files in $NfoDir) somewhere safe, uninstall it (Settings > Apps; if it is " +
      'not listed there, delete the folder), then run this installer again.')
  }
  # Remember which C:\ items this run creates, so cleanup removes only those.
  $new = $StageItems | Where-Object { -not (Test-Path -LiteralPath $_) }
  if ($new) { Add-Content -LiteralPath $StagedList -Value $new }

  foreach ($row in Read-Table $Manifest) {
    $rel = $row[1]
    $target = Get-Target $rel
    if (-not $target) { continue }
    if ($rel -like 'VaniBase/*') {
      if ($NoVaniBase) { continue }
      # Already in place: the infobase at its full size, or the user's own shadow file.
      $inApp = Join-Path $NfoDir ($rel -replace '^VaniBase/', '')
      if ((Test-Path -LiteralPath $inApp) -and ($rel -like '*.sdw' -or (Get-Item -LiteralPath $inApp).Length -eq [int64]$row[2])) { continue }
    } elseif ($installed) {
      # Already installed: only fonts that never reached C:\Windows\Fonts.
      if ($rel -notlike 'Fonts/*' -or (Test-Path -LiteralPath "$env:windir\Fonts\$($rel -replace '^Fonts/', '')")) { continue }
    }
    if (-not (Test-Intact $target $row[2] $row[3])) { Get-DriveFile $row $target }
  }

  # Folio Views 4.3 is an XP-era program; XP SP2 compatibility is what devotees
  # used against its hang on exit under Windows 7. reg.exe changes this one
  # value without touching the other programs' settings in the key.
  $layers = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
  if ($NoCompatMode) {
    # Undo an earlier run's setting (reg.exe exits 1 when there is none).
    $null = Invoke-Tool 'reg.exe' @('delete', $layers, '/v', "$AppDir\Views.exe", '/f', '/reg:64')
  } else {
    $code = Invoke-Tool 'reg.exe' @('add', $layers, '/v', "$AppDir\Views.exe", '/t', 'REG_SZ', '/d', '~ WINXPSP2', '/f', '/reg:64')
    if ($code -ne 0) { Warn 'Could not set compatibility mode on Views.exe' }
  }

  if (-not $installed) { Invoke-Wizard }

  Complete-Install
  Set-SharedTemp
  Register-UserDefaults
  Move-DesktopIcon
  Remove-Item -LiteralPath (Join-Path $Cache 'VaniBase') -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Staging
  Set-Content -LiteralPath $MachineDone -Value $RunToken
}

# ======================================================================== Finish phase
function Invoke-FinishPhase {
  # Folio keeps its fonts and toolbar layout under HKCU. If Install.exe wrote
  # them into another account, the contents pane shows broken diacritics.
  if (-not (Test-FolioSettings)) {
    Say 'Restoring Folio''s default settings for your account'
    if ((Invoke-Tool 'reg.exe' @('import', $UserDefaults)) -ne 0) { Warn "Could not import $UserDefaults" }
  }

  Say 'Done.'
  Write-Host '  Open "Bhaktivedanta VedaBase 2003" (VedaBase 25) or "VaniBase 25" from the desktop or the Start menu.'
  Write-Host '  If VedaBase ever freezes when closing (a known problem of this 2003 program on newer'
  Write-Host '  Windows), end it from Task Manager (Ctrl+Shift+Esc).'
  $answer = Read-Host 'Open VedaBase now? [Y/n]'
  if ($answer -notmatch '^[nN]') {
    Start-Process -FilePath (Join-Path $AppDir 'Views.exe') -WorkingDirectory $AppDir `
      -ArgumentList "`"$NfoDir\Bhaktivedanta Vedabase 2003.sdw`""
  }
}

# ======================================================================== main
if ($Phase -eq 'Machine') {
  try {
    Invoke-MachinePhase
  } catch {
    Fail $_.Exception.Message
  }
  exit 0
}
try { Start-Transcript -LiteralPath (Join-Path $env:TEMP 'VedaBase-install.log') -Append | Out-Null } catch { }
Invoke-UserPhase
exit 0
