<#
.SYNOPSIS
  Installs the Bhaktivedanta VedaBase (Folio Views 4.3, VedaBase 25, VaniBase 25)
  on Windows 10 or 11.

.DESCRIPTION
  Start it by double-clicking Install-VedaBase-Windows.cmd, which asks for
  administrator rights. It follows Ekanatha dasa's README: the files from his
  Google Drive folders go to the root of C:\, and the original Install.exe
  installs them; you click through its wizard. Every file is checked against
  manifest\drive-files.tsv (size and SHA-256) first.

  It also applies what the README leaves out. The shadow file the VedaBase
  icon opens looks for "VedaBase_25.nfo", a name the README's rename removed,
  so a hard link restores it. VaniBase 25 is added with its own icons. Fonts
  Windows did not register are installed (the README's drag-to-Fonts step).
  Running it again is safe: it finishes whatever is missing.

.PARAMETER NoVaniBase
  Leave out VaniBase 25 (393 MB).

.PARAMETER NoCompatMode
  Do not set Windows XP SP3 compatibility mode on Views.exe.
#>
[CmdletBinding()]
param(
  [switch]$NoVaniBase,
  [switch]$NoCompatMode
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Windows PowerShell's progress bar slows downloads badly

$Root = Split-Path -Parent $PSScriptRoot
$Manifest = Join-Path $Root 'manifest\drive-files.tsv'
$AppDir = 'C:\Bhaktivedanta VedaBase 2003'
$NfoDir = Join-Path $AppDir 'Nfo'
$Cache = Join-Path $env:ProgramData 'VedaBase-Setup'
$StagedList = Join-Path $Cache 'staged-in-C-root.txt'
$DriveUrl = 'https://drive.usercontent.google.com/download?export=download&confirm=t&id='
$VedaNfoSize = 649011200

function Say([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Warn([string]$Message) { Write-Host "warning: $Message" -ForegroundColor Yellow }
function Finish([int]$Code) {
  Write-Host ''
  Read-Host 'Press Enter to close this window' | Out-Null
  exit $Code
}
function Fail([string]$Message) {
  Write-Host "error: $Message" -ForegroundColor Red
  Finish 1
}

# --- administrator rights ------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
  if ($NoVaniBase) { $argList += '-NoVaniBase' }
  if ($NoCompatMode) { $argList += '-NoCompatMode' }
  try {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
  } catch {
    Fail 'Administrator rights are needed: the installer writes to C:\ and to the Fonts folder.'
  }
  exit 0
}

# --- the file list ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Manifest)) {
  Fail "Cannot find $Manifest. Keep this folder together with the rest of the download."
}
$Files = foreach ($line in Get-Content -LiteralPath $Manifest -Encoding UTF8) {
  if (-not $line -or $line.StartsWith('#')) { continue }
  $f = $line -split "`t"
  [pscustomobject]@{ Id = $f[0]; Rel = $f[1]; Size = [int64]$f[2]; Sha = $f[3] }
}

# Install.exe, Fonts\, Nfo\ and Spec\ must sit at the root of C:\ (the README);
# VaniBase and the documents go to a cache folder.
function Get-Target([string]$Rel) {
  $win = $Rel -replace '/', '\'
  if ($Rel -eq 'Install.exe' -or $Rel -like 'Fonts/*' -or $Rel -like 'Nfo/*' -or $Rel -like 'Spec/*') {
    return "C:\$win"
  }
  return "$Cache\$win"
}

function Test-Intact([string]$Path, $File) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  if ((Get-Item -LiteralPath $Path).Length -ne $File.Size) { return $false }
  return ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -eq $File.Sha)
}

$Curl = Join-Path $env:SystemRoot 'System32\curl.exe'
function Get-DriveFile($File, [string]$Path) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
  $url = $DriveUrl + $File.Id
  for ($try = 1; $try -le 3; $try++) {
    Say "Downloading $($File.Rel)"
    $ok = $false
    if (Test-Path -LiteralPath $Curl) {
      # curl's progress meter is on stderr; keep PowerShell from treating it as an error.
      $ErrorActionPreference = 'Continue'
      & $Curl -fL --retry 5 --retry-delay 3 -o "$Path.part" $url
      $ok = ($LASTEXITCODE -eq 0)
      $ErrorActionPreference = 'Stop'
    } else {
      try { Invoke-WebRequest -Uri $url -OutFile "$Path.part" -UseBasicParsing; $ok = $true } catch { $ok = $false }
    }
    if ($ok) { Move-Item -LiteralPath "$Path.part" -Destination $Path -Force }
    if (Test-Intact $Path $File) { return }
    Remove-Item -LiteralPath $Path, "$Path.part" -Force -ErrorAction SilentlyContinue
    if ($try -lt 3) { Warn "$($File.Rel) did not arrive intact, retrying"; Start-Sleep -Seconds 5 }
  }
  Fail "$($File.Rel) did not download intact. If the Drive links changed, see README.md."
}

# --- the steps the README does not cover -------------------------------------------
function New-Shortcut([string]$Path, [string]$Arguments) {
  $shell = New-Object -ComObject WScript.Shell
  $link = $shell.CreateShortcut($Path)
  $link.TargetPath = Join-Path $AppDir 'Views.exe'
  $link.Arguments = $Arguments
  $link.WorkingDirectory = $AppDir
  $link.IconLocation = (Join-Path $AppDir 'vedabase.ico') + ',0'
  $link.Save()
}

function Install-MissingFonts {
  if (-not (Test-Path -LiteralPath 'C:\Fonts')) { return }
  $fontsFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
  foreach ($ttf in Get-ChildItem -LiteralPath 'C:\Fonts' -Filter '*.ttf') {
    if (Test-Path -LiteralPath (Join-Path "$env:windir\Fonts" $ttf.Name)) { continue }
    Say "Installing font $($ttf.Name)"
    $fontsFolder.CopyHere($ttf.FullName, 0x14)  # 0x4 no progress window, 0x10 yes to all
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
    New-Shortcut (Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'VaniBase 25.lnk') $arguments
    $menu = Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Bhaktivedanta VedaBase 2003'
    New-Item -ItemType Directory -Force -Path $menu | Out-Null
    New-Shortcut (Join-Path $menu 'VaniBase 25.lnk') $arguments
  }

  # Fonts only once the installer is done, so this never races its own copying.
  if (-not $SkipFonts) { Install-MissingFonts }

  if (-not $NoCompatMode) {
    # Folio Views 4.3 was written for Windows XP; the CrossOver report found
    # newer Windows versions crash it, and XP compatibility is the usual fix.
    $layers = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    New-Item -Path $layers -Force | Out-Null
    New-ItemProperty -Path $layers -Name (Join-Path $AppDir 'Views.exe') -Value '~ WINXPSP3' -PropertyType String -Force | Out-Null
  }
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

# --- main ------------------------------------------------------------------------------
Write-Host 'Bhaktivedanta VedaBase 25 for Windows' -ForegroundColor White
New-Item -ItemType Directory -Force -Path $Cache | Out-Null

$installed = Test-Path -LiteralPath (Join-Path $AppDir 'Views.exe')
if ($installed) {
  $master = Join-Path $NfoDir 'Bhaktivedanta Vedabase 2003.nfo'
  if ((Test-Path -LiteralPath $master) -and (Get-Item -LiteralPath $master).Length -ne $VedaNfoSize) {
    Fail "An older VedaBase is installed in $AppDir. Uninstall it first (Settings > Apps), keeping a copy of your *.sdw files if you made notes, then run this again."
  }
  Say 'Folio Views is already installed; finishing the setup'
} else {
  # Remember which of the C:\ items this run creates, so cleanup removes only those.
  $stageItems = @('C:\Install.exe', 'C:\Fonts', 'C:\Nfo', 'C:\Spec')
  $new = $stageItems | Where-Object { -not (Test-Path -LiteralPath $_) }
  if ($new) { Add-Content -LiteralPath $StagedList -Value $new }
}

foreach ($file in $Files) {
  if ($installed -and $file.Rel -notlike 'VaniBase/*') { continue }
  if ($NoVaniBase -and $file.Rel -like 'VaniBase/*') { continue }
  $target = Get-Target $file.Rel
  if (-not (Test-Intact $target $file)) { Get-DriveFile $file $target }
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
    $running = Get-Process -Name 'irsetup', 'Install' -ErrorAction SilentlyContinue
    # Done while the wizard is still on its last pages, in case its restart
    # prompt gets an OK.
    if (-not $fixed -and (Test-CopyDone)) {
      Complete-Install -SkipFonts
      $fixed = $true
    }
    if ($running) {
      $quietSince = Get-Date
    } elseif (((Get-Date) - $quietSince).TotalSeconds -gt 15) {
      break
    }
    Start-Sleep -Seconds 2
  }
  if (-not (Test-Path -LiteralPath (Join-Path $AppDir 'Views.exe'))) {
    Fail 'The installer did not finish (Views.exe is missing). Run this again to retry.'
  }
}

Complete-Install
Remove-Staging

Say 'Done.'
Write-Host '  Open "Bhaktivedanta VedaBase 2003" (VedaBase 25) or "VaniBase 25" from the desktop or the Start menu.'
$answer = Read-Host 'Open VedaBase now? [Y/n]'
if ($answer -notmatch '^[nN]') {
  # explorer.exe opens the shortcut as you, not as administrator.
  $link = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Bhaktivedanta VedaBase 2003.lnk'
  if (-not (Test-Path -LiteralPath $link)) { $link = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Bhaktivedanta VedaBase 2003.lnk' }
  if (Test-Path -LiteralPath $link) { Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$link`"" }
}
exit 0
