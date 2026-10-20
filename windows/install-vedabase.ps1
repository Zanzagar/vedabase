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

  The fixes the README leaves out:
    - The shadow file the VedaBase icon opens looks for "VedaBase_25.nfo", a
      name the README's rename removed; a hard link restores it.
    - VaniBase 25 is added, with its own icons.
    - All 51 fonts are registered with Windows. Install.exe only copies them,
      which is why the README says to drag them onto Fonts if the diacritics
      fail.
    - Folio's per-user settings (fonts, toolbars) are restored if they landed in
      another account, as happens when you elevate with a different
      administrator or under Administrator protection; without them the
      contents pane shows broken diacritics.

  Running it again is safe: it finishes whatever is missing.

.PARAMETER NoVaniBase
  Leave out VaniBase 25 (393 MB).

.PARAMETER NoCompatMode
  Do not set Windows XP SP2 compatibility mode on Views.exe.
#>
[CmdletBinding()]
param(
  [ValidateSet('User', 'Machine')]
  [string]$Phase = 'User',
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
$Cache = Join-Path $env:ProgramData 'VedaBase-Setup'
$StagedList = Join-Path $Cache 'staged-in-C-root.txt'
$MachineOk = Join-Path $Cache 'machine-phase.ok'
$DriveUrl = 'https://drive.usercontent.google.com/download?export=download&confirm=t&id='
$VedaNfoSize = 649011200

function Say([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Warn([string]$Message) { Write-Host "warning: $Message" -ForegroundColor Yellow }
function Fail([string]$Message) {
  Write-Host "error: $Message" -ForegroundColor Red
  Write-Host ''
  Read-Host 'Press Enter to close this window' | Out-Null
  exit 1
}

# reg.exe reports even success on stderr, which Windows PowerShell turns into a
# terminating error when $ErrorActionPreference is Stop; run it with that relaxed.
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

# ======================================================================== User phase
function Invoke-UserPhase {
  Write-Host 'Bhaktivedanta VedaBase 25 for Windows' -ForegroundColor White
  foreach ($f in $Manifest, $FontList) {
    if (-not (Test-Path -LiteralPath $f)) {
      Fail "Cannot find $f. Extract the whole ZIP (right-click it, Extract All) and run the installer from there."
    }
  }
  if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Fail ('Windows is restricting PowerShell here (Smart App Control or another App Control policy). ' +
      'That policy would also block the 2003 VedaBase programs. Turn off Smart App Control in ' +
      'Windows Security > App & browser control > Smart App Control settings, then run this again.')
  }
  $sac = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -ErrorAction SilentlyContinue
  if ($sac -and $sac.PSObject.Properties['VerifiedAndReputablePolicyState'] -and $sac.VerifiedAndReputablePolicyState -eq 1) {
    Warn ('Smart App Control is on. Windows may block the 2003 VedaBase programs; if it does, turn it off in ' +
      'Windows Security > App & browser control > Smart App Control settings and run this again.')
  }
  $free = (Get-PSDrive -Name C).Free
  if ($free -lt 3GB) { Fail ('Drive C: needs at least 3 GB free (it has {0:N1} GB).' -f ($free / 1GB)) }

  Say 'Windows will now ask for administrator rights (the installer writes to C:\ and the Fonts folder).'
  Remove-Item -LiteralPath $MachineOk -Force -ErrorAction SilentlyContinue
  $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Phase Machine"
  if ($NoVaniBase) { $argLine += ' -NoVaniBase' }
  if ($NoCompatMode) { $argLine += ' -NoCompatMode' }
  try {
    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
      -Verb RunAs -ArgumentList $argLine -Wait
  } catch {
    Fail 'Administrator permission was not given, so nothing was installed.'
  }
  if (-not (Test-Path -LiteralPath $MachineOk)) {
    Fail 'The administrator window did not finish. Run this installer again to continue where it stopped.'
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
# VaniBase and the documents go to the cache folder.
function Get-Target([string]$Rel) {
  $win = $Rel -replace '/', '\'
  if ($Rel -eq 'Install.exe' -or $Rel -like 'Fonts/*' -or $Rel -like 'Nfo/*' -or $Rel -like 'Spec/*') {
    return "C:\$win"
  }
  return "$Cache\$win"
}

function Get-DriveFile($Row, [string]$Path) {
  $id, $rel, $size, $sha = $Row
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
  $url = $DriveUrl + $id
  $curl = "$env:SystemRoot\System32\curl.exe"
  for ($try = 1; $try -le 3; $try++) {
    Say "Downloading $rel"
    $ok = $false
    if (Test-Path -LiteralPath $curl) {
      # curl's progress meter is on stderr; keep PowerShell from treating it as an error.
      $ErrorActionPreference = 'Continue'
      & $curl -fL --retry 5 --retry-delay 3 --connect-timeout 30 --speed-limit 1024 --speed-time 120 -o "$Path.part" $url
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
  throw "$rel did not download intact. Google Drive may be limiting downloads of this file; try again later. If the links changed, see README.md."
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
    if ($p.Value -is [string]) { $known[(Split-Path -Leaf $p.Value).ToLowerInvariant()] = $true }
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
  $master = Join-Path $NfoDir 'Bhaktivedanta Vedabase 2003.nfo'
  $alias = Join-Path $NfoDir 'VedaBase_25.nfo'
  if (-not (Test-Path -LiteralPath $alias)) {
    Say 'Linking VedaBase_25.nfo to the installed infobase'
    try { New-Item -ItemType HardLink -Path $alias -Target $master | Out-Null }
    catch { Copy-Item -LiteralPath $master -Destination $alias }
  }

  if (-not $NoVaniBase) {
    $src = Join-Path $Cache 'VaniBase'
    $nfo = Join-Path $NfoDir 'VaniBase_25.nfo'
    $sdw = Join-Path $NfoDir 'VaniBase_25.sdw'
    if (-not (Test-Path -LiteralPath $nfo) -or (Get-Item -LiteralPath $nfo).Length -ne (Get-Item -LiteralPath "$src\VaniBase_25.nfo").Length) {
      Say 'Adding VaniBase 25'
      Copy-Item -LiteralPath "$src\VaniBase_25.nfo" -Destination $nfo -Force
    }
    # Copied once only: your notes and highlights live in the shadow file.
    if (-not (Test-Path -LiteralPath $sdw)) { Copy-Item -LiteralPath "$src\VaniBase_25.sdw" -Destination $sdw }
    $arguments = "`"$sdw`""
    New-Shortcut "$env:PUBLIC\Desktop\VaniBase 25.lnk" $arguments
    $menu = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Bhaktivedanta VedaBase 2003"
    New-Item -ItemType Directory -Force -Path $menu | Out-Null
    New-Shortcut "$menu\VaniBase 25.lnk" $arguments
  }

  # Fonts only once the installer is done, so this never races its own copying.
  if (-not $SkipFonts) { Register-Fonts }
}

# The installer has finished copying once Views.exe and the whole infobase exist
# and nothing holds the infobase open any more.
function Test-CopyDone {
  $master = Join-Path $NfoDir 'Bhaktivedanta Vedabase 2003.nfo'
  if (-not (Test-Path -LiteralPath (Join-Path $AppDir 'Views.exe'))) { return $false }
  if (-not (Test-Path -LiteralPath $master) -or (Get-Item -LiteralPath $master).Length -ne $VedaNfoSize) { return $false }
  try { [IO.File]::Open($master, 'Open', 'Read', 'None').Close(); return $true } catch { return $false }
}

function Remove-Staging {
  if (-not (Test-Path -LiteralPath $StagedList)) { return }
  foreach ($path in Get-Content -LiteralPath $StagedList) {
    if ($path) { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue }
  }
  Remove-Item -LiteralPath $StagedList -Force
}

function Invoke-MachinePhase {
  Write-Host 'VedaBase setup (administrator)' -ForegroundColor White
  New-Item -ItemType Directory -Force -Path $Cache | Out-Null

  $installed = Test-Path -LiteralPath (Join-Path $AppDir 'Views.exe')
  if ($installed) {
    $master = Join-Path $NfoDir 'Bhaktivedanta Vedabase 2003.nfo'
    if ((Test-Path -LiteralPath $master) -and (Get-Item -LiteralPath $master).Length -ne $VedaNfoSize) {
      throw "An older VedaBase is installed in $AppDir. Uninstall it first (Settings > Apps), keeping a copy of your *.sdw files if you made notes, then run this again."
    }
    Say 'Folio Views is already installed; finishing the setup'
  }
  # Remember which C:\ items this run creates, so cleanup removes only those.
  $new = @('C:\Install.exe', 'C:\Fonts', 'C:\Nfo', 'C:\Spec') | Where-Object { -not (Test-Path -LiteralPath $_) }
  if ($new) { Add-Content -LiteralPath $StagedList -Value $new }

  foreach ($row in Read-Table $Manifest) {
    $rel = $row[1]
    if ($installed -and $rel -notlike 'VaniBase/*' -and $rel -notlike 'Fonts/*') { continue }
    if ($NoVaniBase -and $rel -like 'VaniBase/*') { continue }
    $target = Get-Target $rel
    if (-not (Test-Intact $target $row[2] $row[3])) { Get-DriveFile $row $target }
  }

  if (-not $NoCompatMode) {
    # Folio Views 4.3 is an XP-era program; XP SP2 compatibility is what
    # devotees used against its hang on exit under Windows 7. reg.exe adds the
    # value without touching the other programs' settings in this key.
    $code = Invoke-Tool 'reg.exe' @('add', 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
      '/v', "$AppDir\Views.exe", '/t', 'REG_SZ', '/d', '~ WINXPSP2', '/f', '/reg:64')
    if ($code -ne 0) { Warn 'Could not set compatibility mode on Views.exe' }
  }

  if (-not $installed) {
    Say 'Starting the original installer, Install.exe'
    Write-Host @'

  In the installer window:
    1. Next, then Accept the license, then type your name, then Next.
    2. "Select Install Type": choose Custom, then Next.
    3. Tick "All Folio Program Files" and "VedaBase Master Files"
       (leave "WinAmp media player" unticked), then Next.
    4. Next, Next, Install, then Next and Finish.
    5. If it asks to restart now, choose Cancel. This window finishes the setup.

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
    if (-not (Test-Path -LiteralPath (Join-Path $AppDir 'Views.exe'))) {
      throw 'The installer did not finish (Views.exe is missing). Run this installer again to retry.'
    }
  }

  Complete-Install
  Remove-Staging
  Set-Content -LiteralPath $MachineOk -Value (Get-Date -Format s)
}

# ======================================================================== Finish phase
function Invoke-FinishPhase {
  # Folio keeps its fonts and toolbar layout under HKCU. If Install.exe wrote
  # them into another account, the contents pane shows broken diacritics.
  if (-not (Test-Path -LiteralPath 'HKCU:\Software\VedaBase\4\Views')) {
    Say 'Restoring Folio''s default settings for your account'
    if ((Invoke-Tool 'reg.exe' @('import', $UserDefaults)) -ne 0) { Warn "Could not import $UserDefaults" }
  }

  # Install.exe puts its desktop icon in the account that ran it.
  $desktop = [Environment]::GetFolderPath('Desktop')
  $name = 'Bhaktivedanta VedaBase 2003.lnk'
  if (-not (Test-Path -LiteralPath "$desktop\$name") -and -not (Test-Path -LiteralPath "$env:PUBLIC\Desktop\$name")) {
    New-Shortcut "$desktop\$name" "`"$NfoDir\Bhaktivedanta Vedabase 2003.sdw`""
  }

  Say 'Done.'
  Write-Host '  Open "Bhaktivedanta VedaBase 2003" (VedaBase 25) or "VaniBase 25" from the desktop or the Start menu.'
  Write-Host '  If VedaBase ever hangs when closing, use File > Exit rather than the window''s X.'
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
Invoke-UserPhase
exit 0
