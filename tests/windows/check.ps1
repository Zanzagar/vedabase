<#
.SYNOPSIS
  Checks a VedaBase install on this Windows PC, as far as a script can.

.DESCRIPTION
  Run it after installing VedaBase from this clone (Install-VedaBase-Windows.cmd),
  in the account to check, without "Run as administrator":

    powershell -ExecutionPolicy Bypass -File tests\windows\check.ps1

  It checks what docs\testing.md asks of a Windows install that needs no
  person: the files windows\install-vedabase.ps1 leaves and the ones it must
  remove, its registry values, its shortcuts and the key Ctrl+Alt+U, this
  account's settings, and VedaBase Unicode on known text, which it puts on the
  clipboard before running the installed converter with its shortcut's
  command. It prints PASS, FAIL, SKIP and NOTE lines, then the checks that
  need a person. Exit status: 0 nothing failed, 1 a check failed, 2 it could
  not run.

  It changes nothing but the clipboard. Your clipboard's text is put back at
  the end (its text only, not its formatting), and so is what VedaBase Unicode
  remembers of its last conversion. The test texts stay in clipboard history
  (Win+V).

  Each path, key and value comes from windows\install-vedabase.ps1 (install:N,
  its line N) or windows\vedabase-unicode.ps1 (unicode:N), as of commit
  5b8bf42. Plain ASCII on purpose: Windows PowerShell 5.1 reads a script
  without a BOM in the ANSI code page, so other letters are written \uXXXX.

.PARAMETER NoVaniBase
  VedaBase was installed with -NoVaniBase: skip VaniBase.

.PARAMETER SkipConverter
  Do not run VedaBase Unicode, and leave the clipboard alone.

.PARAMETER ReplaceClipboard
  Run VedaBase Unicode even when the clipboard holds something other than
  text (a picture, files), which this check cannot put back: it ends empty.
#>
[CmdletBinding()]
param(
  [switch]$NoVaniBase,
  [switch]$SkipConverter,
  [switch]$ReplaceClipboard
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

# ======================================================================== output
# As in tests/common.sh: PASS and FAIL lines, then how many failed. Written to
# the output stream, so that '> check.txt' keeps them.
$script:Failed = 0
function Out-Line([string]$Text) { Write-Output $Text }
function Pass([string]$What) { Out-Line "PASS  $What" }
function Skip([string]$What) { Out-Line "SKIP  $What" }
function Note([string]$What) { Out-Line "NOTE  $What" }
function Fail([string]$What, [string[]]$Detail = @()) {
  $script:Failed++
  Out-Line "FAIL  $What"
  foreach ($line in $Detail) { Out-Line "        $line" }
}
# Check NAME { ... }: the block writes one string for each problem it finds,
# none for a PASS. An exception is a FAIL too, so no check stops the others.
# (The block runs inside this function: its own variables are named CheckX.)
function Check([string]$CheckName, [scriptblock]$CheckBlock) {
  try { $checkProblems = @(& $CheckBlock | Where-Object { $_ -is [string] }) }
  catch { Fail $CheckName @("could not check: $($_.Exception.Message)"); return }
  if ($checkProblems.Count) { Fail $CheckName $checkProblems } else { Pass $CheckName }
}

# Text written with \uXXXX (and \r, \n), so that this file stays ASCII.
function U([string]$Escaped) { [regex]::Unescape($Escaped) }

# TEXT as it reads, then as character codes: a console font may lack a
# letter, and a log in another code page loses it. $null is no text at all.
function Show($Text) {
  if ($null -eq $Text) { return '(no text)' }
  $Text = [string]$Text
  $codes = New-Object System.Text.StringBuilder
  foreach ($c in $Text.ToCharArray()) {
    $n = [int]$c
    if ($n -eq 13) { [void]$codes.Append('\r') }
    elseif ($n -eq 10) { [void]$codes.Append('\n') }
    elseif ($n -lt 32 -or $n -gt 126) { [void]$codes.Append(('\u{0:X4}' -f $n)) }
    else { [void]$codes.Append($c) }
  }
  if ($Text -cmatch '^[\x20-\x7E]*$') { return "'$Text'" }
  if ($Text -match '[\x00-\x1F]') { return "'$($codes.ToString())'" }
  return "'$Text' ($($codes.ToString()))"
}

# Equal character for character (PowerShell's -eq ignores case, and a
# culture's comparison can call different characters equal).
function Same($A, $B) {
  if ($null -eq $A -or $null -eq $B) { return ($null -eq $A -and $null -eq $B) }
  return [string]::Equals([string]$A, [string]$B, [System.StringComparison]::Ordinal)
}

function Show-Difference($Got, $Want) {
  if ($null -eq $Got) { return 'the clipboard holds no text' }
  $g = [string]$Got
  $w = [string]$Want
  $i = 0
  while ($i -lt $g.Length -and $i -lt $w.Length -and [int]$g[$i] -eq [int]$w[$i]) { $i++ }
  $have = 'nothing more'
  if ($i -lt $g.Length) { $have = 'U+{0:X4}' -f [int]$g[$i] }
  $need = 'the end'
  if ($i -lt $w.Length) { $need = 'U+{0:X4}' -f [int]$w[$i] }
  return "at character $($i + 1) it has $have where $need belongs"
}

# ======================================================================== shortcuts (.lnk)
# A shortcut file as [MS-SHLLINK] lays it out: a 76-byte header (its flags at
# 0x14, its window at 0x3C, its key at 0x40), the optional item list, the
# optional LinkInfo (the target's path), then the strings the flags announce.
function Read-ShellLink([byte[]]$B) {
  if ($B.Length -lt 0x4C -or [BitConverter]::ToUInt32($B, 0) -ne 0x4C) { throw 'not a shortcut file' }
  $flags = [BitConverter]::ToUInt32($B, 0x14)
  $link = [ordered]@{
    Flags            = $flags
    IconIndex        = [BitConverter]::ToInt32($B, 0x38)
    ShowCommand      = [BitConverter]::ToUInt32($B, 0x3C)
    # The key's code in the low byte; above it Shift 0x01, Ctrl 0x02, Alt 0x04.
    Hotkey           = [int][BitConverter]::ToUInt16($B, 0x40)
    RunAsAdmin       = (($flags -band 0x2000) -ne 0)
    Target           = ''
    Description      = ''
    RelativePath     = ''
    WorkingDirectory = ''
    Arguments        = ''
    IconLocation     = ''
  }
  $at = 0x4C
  if ($flags -band 0x1) { $at += 2 + [BitConverter]::ToUInt16($B, $at) }   # HasLinkTargetIDList
  if ($flags -band 0x2) {                                                  # HasLinkInfo
    $info = $at
    $size = [int][BitConverter]::ToUInt32($B, $info)
    $headerSize = [int][BitConverter]::ToUInt32($B, $info + 4)
    if ([BitConverter]::ToUInt32($B, $info + 8) -band 0x1) {               # VolumeIDAndLocalBasePath
      if ($headerSize -ge 0x24) {
        $base = Read-CString $B ($info + [int][BitConverter]::ToUInt32($B, $info + 0x1C)) $true
        $suffix = Read-CString $B ($info + [int][BitConverter]::ToUInt32($B, $info + 0x20)) $true
      } else {
        $base = Read-CString $B ($info + [int][BitConverter]::ToUInt32($B, $info + 0x10)) $false
        $suffix = Read-CString $B ($info + [int][BitConverter]::ToUInt32($B, $info + 0x18)) $false
      }
      $link['Target'] = $base + $suffix
    }
    $at = $info + $size
  }
  $wide = ($flags -band 0x80) -ne 0                                        # IsUnicode
  foreach ($s in @(@(0x04, 'Description'), @(0x08, 'RelativePath'), @(0x10, 'WorkingDirectory'),
      @(0x20, 'Arguments'), @(0x40, 'IconLocation'))) {
    if (-not ($flags -band $s[0])) { continue }
    $count = [int][BitConverter]::ToUInt16($B, $at)
    $at += 2
    if ($wide) {
      $text = [System.Text.Encoding]::Unicode.GetString($B, $at, 2 * $count)
      $at += 2 * $count
    } else {
      $chars = New-Object System.Text.StringBuilder
      for ($i = 0; $i -lt $count; $i++) { [void]$chars.Append([char]$B[$at + $i]) }
      $text = $chars.ToString()
      $at += $count
    }
    # Windows counts the letters alone; Wine counts a closing NUL too.
    $nul = $text.IndexOf([char]0)
    if ($nul -ge 0) { $text = $text.Substring(0, $nul) }
    $link[$s[1]] = $text
  }
  New-Object PSObject -Property $link
}

# A NUL-terminated string at AT: UTF-16 when WIDE, else a byte a letter (the
# ANSI code page; the paths here are plain ASCII).
function Read-CString([byte[]]$B, [int]$At, [bool]$Wide) {
  $text = New-Object System.Text.StringBuilder
  if ($Wide) {
    for ($i = $At; $i + 1 -lt $B.Length; $i += 2) {
      $c = [BitConverter]::ToUInt16($B, $i)
      if ($c -eq 0) { break }
      [void]$text.Append([char]$c)
    }
  } else {
    for ($i = $At; $i -lt $B.Length -and $B[$i] -ne 0; $i++) { [void]$text.Append([char]$B[$i]) }
  }
  $text.ToString()
}

# Ctrl+Alt+U as a shortcut stores it: 'U' (0x55) with Ctrl and Alt (0x06)
# above it. install:337 sets 'Ctrl+Alt+U' on the Start-menu shortcut.
$script:CtrlAltU = 0x0655
function Format-Hotkey([int]$Hotkey) {
  if ($Hotkey -eq 0) { return 'no key' }
  $parts = @()
  if ($Hotkey -band 0x0200) { $parts += 'Ctrl' }
  if ($Hotkey -band 0x0400) { $parts += 'Alt' }
  if ($Hotkey -band 0x0100) { $parts += 'Shift' }
  $key = $Hotkey -band 0xFF
  if (($key -ge 0x30 -and $key -le 0x39) -or ($key -ge 0x41 -and $key -le 0x5A)) { $parts += [string][char]$key }
  else { $parts += ('key 0x{0:X2}' -f $key) }
  $parts -join '+'
}

# ======================================================================== logs, tables, permissions
# The installer appends each run to its log (install:547, :631): the last
# run's lines, and when it started.
function Get-LastRun([string]$Transcript) {
  $runs = @($Transcript -split 'PowerShell transcript start')
  $last = $runs[$runs.Count - 1]
  $started = ''
  if ($last -match 'Start time: (\d{4})(\d\d)(\d\d)(\d\d)(\d\d)') {
    $started = '{0}-{1}-{2} {3}:{4}' -f $Matches[1], $Matches[2], $Matches[3], $Matches[4], $Matches[5]
  }
  New-Object PSObject -Property @{ Lines = @($last -split '\r?\n'); Started = $started }
}

# Rows of a tab-separated table, as the installer reads them (install:88-92).
function Read-Table([string]$Path) {
  foreach ($line in ((Read-Text $Path) -split '\r?\n')) {
    if ($line -and -not $line.StartsWith('#')) { , ($line -split "`t") }
  }
}

# True when an allow entry lets every account (Everyone, Authenticated Users,
# Users or INTERACTIVE) write data (0x2: WriteData, or CreateFiles in a
# folder; or generic write or all rights) and no deny entry for them takes it
# away. Entries that only pass to children (InheritOnly) do not count.
function Test-AnyoneMayWrite($Rules) {
  $anyone = @('S-1-1-0', 'S-1-5-11', 'S-1-5-32-545', 'S-1-5-4')
  $allowed = $false
  foreach ($r in @($Rules)) {
    if ($r.InheritOnly -or $anyone -notcontains $r.Sid) { continue }
    $rights = [int64]$r.Rights
    if (($rights -band 0x2) -eq 0 -and ($rights -band 0x50000000) -eq 0) { continue }
    if (-not $r.Allow) { return $false }
    $allowed = $true
  }
  return $allowed
}

# ======================================================================== Windows itself
# All that reads Windows goes through these functions, which tests on Linux
# replace (only the file system is real there, under a stand-in C: drive).
function Test-Preflight {
  if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    return 'Windows restricts PowerShell on this PC (Smart App Control or another App Control policy), so this check cannot run.'
  }
  if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    return 'This is the 32-bit PowerShell, which sees other folders and registry keys than the installer did: run powershell.exe from a normal Command Prompt.'
  }
  return ''
}
function Test-Sta { [System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA }
function Test-Elevated {
  $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  (New-Object System.Security.Principal.WindowsPrincipal $id).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-FolderPath([string]$Name) { [Environment]::GetFolderPath($Name) }
# A path as .NET's file functions take it ('C:\...' stays as it is on Windows).
function Get-OsPath([string]$Path) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path) }
function Read-Bytes([string]$Path) { , [System.IO.File]::ReadAllBytes((Get-OsPath $Path)) }
function Write-Bytes([string]$Path, [byte[]]$Bytes) { [System.IO.File]::WriteAllBytes((Get-OsPath $Path), $Bytes) }
function Read-Text([string]$Path) { [System.IO.File]::ReadAllText((Get-OsPath $Path)) }

# A key's values as a table (names ignore case, as the registry's do) of
# @{Value; Kind}, the default value under ''; $null when the key is missing.
function Get-RegValues([string]$Key) {
  $k = Get-Item -LiteralPath $Key -ErrorAction SilentlyContinue
  if (-not $k) { return $null }
  $all = @{}
  foreach ($name in $k.GetValueNames()) {
    $all[$name] = New-Object PSObject -Property @{
      Value = $k.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
      Kind  = [string]$k.GetValueKind($name)
    }
  }
  return $all
}
function Get-RegString($Values, [string]$Name) {
  if ($null -eq $Values -or -not $Values.ContainsKey($Name)) { return '' }
  return [string]$Values[$Name].Value
}

# The entries of a file's or folder's access list, as @{Sid; Rights; Allow; InheritOnly}.
function Get-AccessRules([string]$Path) {
  $acl = Get-Acl -LiteralPath $Path
  foreach ($r in $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
    New-Object PSObject -Property @{
      Sid         = $r.IdentityReference.Value
      Rights      = [int64][int]$r.FileSystemRights
      Allow       = ([string]$r.AccessControlType -eq 'Allow')
      InheritOnly = (([int]$r.PropagationFlags -band 2) -ne 0)
    }
  }
}

# 'yes' when this account may open the file to write (nothing is written),
# 'no' when Windows refuses, 'busy' when a program has it open.
function Test-Writable([string]$Path) {
  try {
    $stream = [System.IO.File]::Open((Get-OsPath $Path), [System.IO.FileMode]::Open,
      [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    $stream.Close()
    return 'yes'
  } catch {
    $e = $_.Exception
    while ($e -is [System.Management.Automation.MethodInvocationException] -and $e.InnerException) { $e = $e.InnerException }
    if ($e -is [System.UnauthorizedAccessException]) { return 'no' }
    if ($e -is [System.IO.IOException]) { return 'busy' }
    throw
  }
}

# A shortcut's target and arguments as Windows reads them (a second opinion
# when this file's own reading of the .lnk disagrees with the installer).
function Get-LinkByShell([string]$Path) {
  $link = (New-Object -ComObject WScript.Shell).CreateShortcut((Get-OsPath $Path))
  New-Object PSObject -Property @{ Target = $link.TargetPath; Arguments = $link.Arguments }
}

function Initialize-Clipboard { Add-Type -AssemblyName System.Windows.Forms }
# Other programs (clipboard history, cloud clipboard) open the clipboard after
# every change, so a call that finds it busy is tried again (as unicode:100-110).
function Invoke-Clipboard([scriptblock]$Call) {
  for ($try = 1; ; $try++) {
    try { return (& $Call) }
    catch { if ($try -ge 20) { throw }; Start-Sleep -Milliseconds 100 }
  }
}
# The clipboard's text, or $null when it holds none.
function Get-ClipText {
  Invoke-Clipboard {
    if ([System.Windows.Forms.Clipboard]::ContainsText([System.Windows.Forms.TextDataFormat]::UnicodeText)) {
      [System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::UnicodeText)
    } else { $null }
  }
}
# True when the clipboard holds something, but no text (a picture, files).
function Test-ClipOnlyOther {
  Invoke-Clipboard {
    $data = [System.Windows.Forms.Clipboard]::GetDataObject()
    [bool]($data -and @($data.GetFormats()).Count -and -not [System.Windows.Forms.Clipboard]::ContainsText())
  }
}
# TEXT alone on the clipboard, as Unicode; with -AnsiOnly as ANSI text alone,
# which Windows turns into Unicode for whoever asks, as with a copy made in a
# program from 2003. Copied in ($true), so it stays after this check ends.
function Set-ClipText([string]$Text, [switch]$AnsiOnly) {
  $data = New-Object System.Windows.Forms.DataObject
  $format = [System.Windows.Forms.DataFormats]::UnicodeText
  if ($AnsiOnly) { $format = [System.Windows.Forms.DataFormats]::Text }
  $data.SetData($format, $false, $Text)
  [System.Windows.Forms.Clipboard]::SetDataObject($data, $true, 20, 100)
}
function Clear-ClipText { [void](Invoke-Clipboard { [System.Windows.Forms.Clipboard]::Clear() }) }

# Runs VedaBase Unicode with its shortcut's program, arguments and folder,
# through the shell as a click does (a console of its own, which its
# -WindowStyle Hidden then hides). Not the .lnk itself: the shell need not
# hand back a process for a .lnk, and without one there is nothing to wait for.
$script:Started = New-Object System.Collections.ArrayList
function Start-Converter($Run) {
  $start = New-Object System.Diagnostics.ProcessStartInfo
  $start.FileName = $Run.Target
  $start.Arguments = $Run.Arguments
  $start.WorkingDirectory = $Run.WorkingDirectory
  $start.UseShellExecute = $true
  $start.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
  $process = [System.Diagnostics.Process]::Start($start)
  if (-not $process) { throw "Windows started no process for $($Run.Target)" }
  [void]$script:Started.Add($process)
  $process
}
# Its exit status (unicode:13-17), or -1 when it has not ended within SECONDS
# (then this check ends it: it is one this check started).
function Wait-Converter($Process, [int]$Seconds) {
  if ($Process.WaitForExit($Seconds * 1000)) { return $Process.ExitCode }
  try { $Process.Kill() } catch { }
  return -1
}

function Get-SystemSummary {
  $cv = Get-RegValues 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
  $build = Get-RegString $cv 'CurrentBuild'
  $name = 'Windows 10'
  if ($build -match '^\d+$' -and [int]$build -ge 22000) { $name = 'Windows 11' }
  $elevated = 'no'
  if (Test-Elevated) { $elevated = 'yes' }
  '{0} {1}, build {2}.{3} ({4}), {5}; PowerShell {6}; as administrator: {7}; ANSI code page {8}' -f $name,
    (Get-RegString $cv 'DisplayVersion'), $build, (Get-RegString $cv 'UBR'), (Get-RegString $cv 'EditionID'),
    $env:PROCESSOR_ARCHITECTURE, $PSVersionTable.PSVersion, $elevated, (Get-AnsiCodePage)
}
function Get-AnsiCodePage { Get-RegString (Get-RegValues 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage') 'ACP' }

# ======================================================================== what the installer makes
function Initialize-Paths([string]$Checkout) {
  $script:Repo = $Checkout
  $script:AppDir = 'C:\Bhaktivedanta VedaBase 2003'                        # $AppDir, install:49
  $script:NfoDir = "$AppDir\Nfo"                                           # $NfoDir, install:50
  $script:Master = "$NfoDir\Bhaktivedanta Vedabase 2003.nfo"               # $Master, install:51
  $script:MasterSize = 649011200                                           # $MasterSize, install:52
  $script:Sdw = "$NfoDir\Bhaktivedanta Vedabase 2003.sdw"                  # install:386, :605, :617
  $script:VaniNfo = "$NfoDir\VaniBase_25.nfo"                              # install:298
  $script:VaniSdw = "$NfoDir\VaniBase_25.sdw"                              # install:299
  $script:Cache = "$env:ProgramFiles\VedaBase-Setup"                       # $Cache, install:55
  $script:StagedList = "$Cache\staged-in-C-root.txt"                       # install:56
  $script:MachineDone = "$Cache\machine-phase.done"                        # install:57
  $script:SdwBackup = "$Cache\sdw-backup"                                  # install:58
  $script:SdwPending = "$Cache\sdw-restore.pending"                        # install:59
  $script:CachedDefaults = "$Cache\vedabase-defaults.reg"                  # install:60
  $script:StageItems = @('C:\Install.exe', 'C:\Fonts', 'C:\Nfo', 'C:\Spec') # install:61
  $script:ActiveSetupId = '{8C9EE47A-5102-4B2C-B476-0212DFBB3EC0}'         # install:63
  $script:Menu = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Bhaktivedanta VedaBase 2003" # install:312, :335
  $script:SharedDesktop = "$env:PUBLIC\Desktop"                            # install:311, :338, :381
  $script:PowerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" # install:332
  $script:Converter = "$Cache\vedabase-unicode.ps1"                        # install:328
  $script:ConverterArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Converter`"" # install:333
  $script:LastDir = "$env:LOCALAPPDATA\VedaBase"                           # $LastFile, unicode:117
  $script:LastFile = "$LastDir\unicode-last.txt"
}

# ------------------------------------------------------------------------ files it leaves
function Test-Installed {
  Out-Line '-- Files the installer leaves'
  Check "VedaBase: $AppDir\Views.exe, and the master infobase at its full size ($MasterSize bytes; Test-Installed, install:94-97)" {
    if (-not (Test-Path -LiteralPath "$AppDir\Views.exe" -PathType Leaf)) { "missing: $AppDir\Views.exe" }
    if (-not (Test-Path -LiteralPath $Master -PathType Leaf)) { "missing: $Master" }
    elseif ((Get-Item -LiteralPath $Master).Length -ne $MasterSize) { "$Master has $((Get-Item -LiteralPath $Master).Length) bytes" }
  }
  $alias = "$NfoDir\VedaBase_25.nfo"
  Check "VedaBase_25.nfo, the name VedaBase's shadow file asks for, is the master infobase (same size and time; install:284-294)" {
    if (-not (Test-Path -LiteralPath $alias -PathType Leaf)) { "missing: $alias (VedaBase would say the infobase cannot be found)"; return }
    $a = Get-Item -LiteralPath $alias
    $m = Get-Item -LiteralPath $Master
    if ($a.Length -ne $m.Length -or $a.LastWriteTimeUtc -ne $m.LastWriteTimeUtc) { "$alias differs from $Master" }
  }
  try {
    $a = Get-Item -LiteralPath $alias
    if ($a.PSObject.Properties['LinkType'] -and $a.LinkType -eq 'HardLink') { Note 'VedaBase_25.nfo is a hard link to the master infobase' }
    elseif ($a.PSObject.Properties['LinkType']) { Note 'VedaBase_25.nfo is a copy of the master infobase (the hard link failed; install:293)' }
  } catch { }
  Check "VedaBase's shadow file, which holds your notes: $Sdw" {
    if (-not (Test-Path -LiteralPath $Sdw -PathType Leaf)) { "missing: $Sdw" }
  }
  if ($NoVaniBase) {
    Skip 'VaniBase 25 (-NoVaniBase)'
  } else {
    Check 'VaniBase 25: VaniBase_25.nfo at the size manifest\drive-files.tsv gives, and its shadow file VaniBase_25.sdw (install:296-309)' {
      $row = @(Read-Table "$Repo\manifest\drive-files.tsv" | Where-Object { $_[1] -eq 'VaniBase/VaniBase_25.nfo' })
      if (-not $row) { 'manifest\drive-files.tsv has no VaniBase/VaniBase_25.nfo'; return }
      if (-not (Test-Path -LiteralPath $VaniNfo -PathType Leaf)) { "missing: $VaniNfo" }
      elseif ((Get-Item -LiteralPath $VaniNfo).Length -ne [int64]$row[0][2]) { "$VaniNfo has $((Get-Item -LiteralPath $VaniNfo).Length) bytes, not $($row[0][2])" }
      if (-not (Test-Path -LiteralPath $VaniSdw -PathType Leaf)) { "missing: $VaniSdw" }
    }
  }
  Check "Folio's swap and index folder, $AppDir\Temp (Set-SharedTemp, install:344-351)" {
    if (-not (Test-Path -LiteralPath "$AppDir\Temp" -PathType Container)) { "missing: $AppDir\Temp" }
  }
  Check "the shortcuts' icon, $AppDir\vedabase.ico (install:221)" {
    if (-not (Test-Path -LiteralPath "$AppDir\vedabase.ico" -PathType Leaf)) { "missing: $AppDir\vedabase.ico" }
  }

  # docs\testing.md check 1, from the administrator phase's log.
  $log = "$Cache\install.log"
  Check "$log is there, and machine-phase.done says the administrator phase reached its end (install:547, :589)" {
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { "missing: $log" }
    if (-not (Test-Path -LiteralPath $MachineDone -PathType Leaf)) { "missing: $MachineDone"; return }
    $token = (Read-Text $MachineDone).Trim()
    if ($token -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') { "machine-phase.done holds '$token', not a run's token" }
  }
  $run = $null
  try { if (Test-Path -LiteralPath $log -PathType Leaf) { $run = Get-LastRun (Read-Text $log) } } catch { }
  if ($run) {
    $when = ''
    if ($run.Started) { $when = " (started $($run.Started))" }
    Check "the last install run$when logged no error and no file that did not arrive intact (docs\testing.md check 1)" {
      $run.Lines | Where-Object { $_ -cmatch '^error: ' -or $_ -cmatch 'did not arrive intact' } | ForEach-Object { [string]$_ }
    }
    foreach ($w in @($run.Lines | Where-Object { $_ -cmatch '^warning: ' -and $_ -cnotmatch 'did not arrive intact' })) {
      Note "the last install run warned: $($w.Substring(9))"
    }
  }
  $userLog = "$env:TEMP\VedaBase-install.log"
  if (Test-Path -LiteralPath $userLog -PathType Leaf) {
    Check "this account's last run of the installer reached 'Done.' (%TEMP%\VedaBase-install.log; install:608)" {
      $mine = Get-LastRun (Read-Text $userLog)
      if (-not @($mine.Lines | Where-Object { $_ -cmatch '^==> Done\.\s*$' }).Count) { 'it did not: see %TEMP%\VedaBase-install.log' }
      $mine.Lines | Where-Object { $_ -cmatch '^error: ' } | ForEach-Object { [string]$_ }
    }
  } else {
    Skip "this account's installer log (%TEMP%\VedaBase-install.log) is not there: another account ran the installer, or its TEMP was emptied"
  }

  # The copies the installer makes of this checkout's files: if they differ,
  # the install came from another version, and so would every result below.
  Check "VedaBase Unicode, $Converter and balaram-unicode.tsv beside it, as in this checkout (install:327-331)" {
    foreach ($pair in @(@($Converter, "$Repo\windows\vedabase-unicode.ps1"), @("$Cache\balaram-unicode.tsv", "$Repo\lib\balaram-unicode.tsv"))) {
      if (-not (Test-Path -LiteralPath $pair[0] -PathType Leaf)) { "missing: $($pair[0])"; continue }
      $installed = (Read-Text $pair[0]) -replace "`r", ''
      $here = (Read-Text $pair[1]) -replace "`r", ''
      if (-not (Same $installed $here)) { "$($pair[0]) differs from this checkout's copy: run Install-VedaBase-Windows.cmd from this checkout again (it is safe), then this check" }
    }
  }
  Check "Folio's default settings for every account, $CachedDefaults, as in this checkout (install:366)" {
    if (-not (Test-Path -LiteralPath $CachedDefaults -PathType Leaf)) { "missing: $CachedDefaults"; return }
    $installed = [Convert]::ToBase64String((Read-Bytes $CachedDefaults))
    $here = [Convert]::ToBase64String((Read-Bytes "$Repo\windows\vedabase-defaults.reg"))
    if ($installed -ne $here) { "it differs from this checkout's windows\vedabase-defaults.reg" }
  }
}

# ------------------------------------------------------------------------ what it removes
function Test-Removed {
  Out-Line '-- What the installer removes'
  # Remove-Staging (install:399-418) clears only what this installer put at
  # C:\, and keeps a list of what it could not clear.
  $listed = @()
  if (Test-Path -LiteralPath $StagedList -PathType Leaf) { $listed = @((Read-Text $StagedList) -split '\r?\n' | Where-Object { $_ }) }
  foreach ($item in $StageItems) {
    if (-not (Test-Path -LiteralPath $item)) { Pass "$item, staged there for the original installer, is gone"; continue }
    if ($listed -contains $item) { Fail "$item is still there: the installer made it and could not clear it ($StagedList lists it)"; continue }
    Note "$item is there, but the installer did not make it: it was there before the install, so it was left alone (docs\testing.md)"
  }
  Check "$Cache\VaniBase, where VaniBase waited for the install, is gone (install:587)" {
    if (Test-Path -LiteralPath "$Cache\VaniBase") { "still there: $Cache\VaniBase" }
  }
  Check "$SdwPending is gone: notes kept aside during a reinstall were put back (Restore-Notes, install:445)" {
    if (Test-Path -LiteralPath $SdwPending) { "still there: $SdwPending lists notes not yet put back" }
  }
  Check "$AppDir\vedabase-defaults.reg is gone: there any account could change what every account imports (install:367)" {
    if (Test-Path -LiteralPath "$AppDir\vedabase-defaults.reg") { "still there: $AppDir\vedabase-defaults.reg" }
  }
  Check "Install.exe's VedaBase icon is not on this account's own desktop: the installer moves it to the shared one (Move-DesktopIcon, install:378-387)" {
    $desktop = Get-FolderPath 'Desktop'
    if ($desktop -and (Test-Path -LiteralPath "$desktop\Bhaktivedanta VedaBase 2003.lnk")) { "still on this account's desktop: Bhaktivedanta VedaBase 2003.lnk" }
  }
  Check 'the space filler %TEMP%\vedabase-space-filler.tmp is gone (install:453-462, :512)' {
    if (Test-Path -LiteralPath "$env:TEMP\vedabase-space-filler.tmp") { 'still there: %TEMP%\vedabase-space-filler.tmp' }
  }
  if (Test-Path -LiteralPath $SdwBackup) {
    $kept = @(Get-ChildItem -LiteralPath $SdwBackup -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    Note "copies of notes from an earlier install are kept in ${SdwBackup}: $($kept -join ', ')"
  }
}

# ------------------------------------------------------------------------ registry
function Test-Registry {
  Out-Line '-- Registry'
  $fontKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'          # install:234
  $fonts = @(Read-Table "$Repo\manifest\fonts.tsv")
  Check "all $($fonts.Count) fonts of manifest\fonts.tsv are in $env:windir\Fonts and registered in HKLM\...\CurrentVersion\Fonts, such as 'Balaram (TrueType)' (Register-Fonts, install:233-256)" {
    if (-not $fonts.Count) { 'manifest\fonts.tsv lists no fonts' }
    # Registered as the installer counts it (install:236-241): a value whose
    # data ends in the file's name. Its data must name a file that is there.
    $byFile = @{}
    $values = Get-RegValues $fontKey
    if ($null -eq $values) { "the key $fontKey is missing"; return }
    foreach ($name in $values.Keys) {
      $data = $values[$name].Value
      if ($data -is [string] -and $data) { $byFile[$data.Substring($data.LastIndexOf('\') + 1).ToLowerInvariant()] = $data }
    }
    foreach ($row in $fonts) {
      $file = $row[0]
      if (-not (Test-Path -LiteralPath "$env:windir\Fonts\$file" -PathType Leaf)) { "not in $env:windir\Fonts: $file" }
      $data = $byFile[$file.ToLowerInvariant()]
      if (-not $data) { "not registered: $file ('$($row[1])')"; continue }
      $path = "$env:windir\Fonts\$data"
      if ($data.Contains('\')) { $path = $data }
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { "registered as $data, which is not there: $file" }
    }
  }

  # Remove-OldCompatMode (install:522-542) removes only Windows XP mode, from
  # HKLM; docs\testing.md wants no entry at all, in either place.
  $exe = "$AppDir\Views.exe"
  Check "no compatibility mode on $exe (AppCompatFlags\Layers, HKLM and HKCU), as docs\testing.md expects; Windows XP mode makes every start ask for administrator rights" {
    foreach ($key in @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers')) {
      $values = Get-RegValues $key
      if ($values -and $values.ContainsKey($exe)) { "$($key -replace ':', '') has '$($values[$exe].Value)' for it" }
    }
  }

  # Set-SharedTemp (install:344-351).
  foreach ($sub in @('Server\SwapPath', 'Server\Index\TempPath')) {
    $key = "HKLM:\SOFTWARE\WOW6432Node\VedaBase\4\$sub"
    Check "HKLM\SOFTWARE\WOW6432Node\VedaBase\4\$sub points to $AppDir\Temp, which every account may use (Set-SharedTemp, install:344-351)" {
      $values = Get-RegValues $key
      if ($null -eq $values) { 'the key is missing (Install.exe makes it)'; return }
      $now = Get-RegString $values ''
      if ($now.TrimEnd('\') -ne "$AppDir\Temp") { "it points to '$now'" }
    }
  }

  # Register-UserDefaults (install:360-374).
  $activeSetup = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$ActiveSetupId"
  $folioPrefs = 'HKCU\Software\VedaBase\4\Views\NfoView\Preferences'
  $stub = "cmd.exe /c reg query `"$folioPrefs`" /v FontName 2>nul | find /i `"BellCentennial`" >nul || reg import `"$CachedDefaults`""
  Check "Active Setup gives each account Folio's settings at its next sign-in: HKLM\...\Active Setup\Installed Components\$ActiveSetupId, its StubPath importing $CachedDefaults (install:368-373)" {
    $values = Get-RegValues $activeSetup
    if ($null -eq $values) { 'the key is missing'; return }
    $want = [ordered]@{ '' = @('VedaBase 25 settings', 'String'); 'StubPath' = @($stub, 'String'); 'Version' = @('1', 'String'); 'IsInstalled' = @('1', 'DWord') }
    foreach ($name in $want.Keys) {
      $label = $name
      if (-not $name) { $label = '(default)' }
      if (-not $values.ContainsKey($name)) { "it has no value $label"; continue }
      $have = $values[$name]
      if (-not (Same ([string]$have.Value) $want[$name][0]) -or $have.Kind -ne $want[$name][1]) {
        "$label is $($have.Kind) '$($have.Value)', not $($want[$name][1]) '$($want[$name][0])'"
      }
    }
    if (-not (Test-Path -LiteralPath $CachedDefaults -PathType Leaf)) { "the file it imports is missing: $CachedDefaults" }
  }
}

# ------------------------------------------------------------------------ shortcuts
# Checks one shortcut against what the installer gives it (New-Shortcut,
# install:211-229). WANT: Target, Arguments, and optionally WorkingDirectory,
# Icon, Show (1 normal, 7 minimized without taking the focus).
function Test-Link([string]$Path, [string]$Name, $Want) {
  Check "$Name ($Path) opens $($Want.Target) $($Want.Arguments)" {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { 'missing'; return }
    $link = Read-ShellLink (Read-Bytes $Path)
    # Windows may store a path as %SystemDrive%\... and the like.
    $target = Expand $link.Target
    $arguments = Expand $link.Arguments
    if (-not ($target -ieq $Want.Target -and $arguments -ieq $Want.Arguments)) {
      # A second opinion: Windows' own reading, in case a path was stored another way.
      try { $shell = Get-LinkByShell $Path; $target = $shell.Target; $arguments = $shell.Arguments } catch { }
    }
    if (-not ($target -ieq $Want.Target)) { "its target is '$target'" }
    if (-not ($arguments -ieq $Want.Arguments)) { "its arguments are '$arguments'" }
    if ($Want.PSObject.Properties['WorkingDirectory'] -and -not ((Expand $link.WorkingDirectory) -ieq $Want.WorkingDirectory)) { "it starts in '$($link.WorkingDirectory)'" }
    if ($Want.PSObject.Properties['Icon'] -and -not ((Expand $link.IconLocation) -ieq $Want.Icon -and $link.IconIndex -eq 0)) { "its icon is '$($link.IconLocation)',$($link.IconIndex)" }
    if ($Want.PSObject.Properties['Show'] -and $link.ShowCommand -ne $Want.Show) { "its window style is $($link.ShowCommand), not $($Want.Show)" }
    if ($link.RunAsAdmin) { 'it is set to run as administrator' }
  }
}
function New-Want([hashtable]$Fields) { New-Object PSObject -Property $Fields }
function Expand([string]$Text) { [Environment]::ExpandEnvironmentVariables($Text) }

function Test-Shortcuts {
  Out-Line '-- Shortcuts'
  $views = "$AppDir\Views.exe"
  $icon = "$AppDir\vedabase.ico"
  # Install.exe's own icon, moved to the shared desktop or made there (install:378-387).
  Test-Link "$SharedDesktop\Bhaktivedanta VedaBase 2003.lnk" 'the shared desktop''s VedaBase icon' (New-Want @{ Target = $views; Arguments = "`"$Sdw`"" })
  if (-not $NoVaniBase) {
    # install:310-314
    $vani = New-Want @{ Target = $views; Arguments = "`"$VaniSdw`""; WorkingDirectory = $AppDir; Icon = $icon; Show = 1 }
    Test-Link "$SharedDesktop\VaniBase 25.lnk" 'the shared desktop''s VaniBase icon' $vani
    Test-Link "$Menu\VaniBase 25.lnk" 'the Start menu''s VaniBase 25' $vani
  }
  # install:332-338: the same command in both, the key only in the Start menu.
  $unicode = New-Want @{ Target = $PowerShellExe; Arguments = $ConverterArgs; WorkingDirectory = $AppDir; Icon = $icon; Show = 7 }
  $menuLink = "$Menu\VedaBase Unicode.lnk"
  $deskLink = "$SharedDesktop\VedaBase Unicode.lnk"
  Test-Link $menuLink 'the Start menu''s VedaBase Unicode' $unicode
  Test-Link $deskLink 'the shared desktop''s VedaBase Unicode' $unicode
  Check "the Start menu's VedaBase Unicode has the key Ctrl+Alt+U (install:337)" {
    if (-not (Test-Path -LiteralPath $menuLink -PathType Leaf)) { 'the shortcut is missing'; return }
    $key = (Read-ShellLink (Read-Bytes $menuLink)).Hotkey
    if ($key -ne $CtrlAltU) { "its key is $(Format-Hotkey $key) (0x$('{0:X4}' -f $key))" }
  }
  Check 'the desktop''s VedaBase Unicode has no key: Windows takes keys from both places, and two would compete (install:325-326, :338)' {
    if (-not (Test-Path -LiteralPath $deskLink -PathType Leaf)) { 'the shortcut is missing'; return }
    $key = (Read-ShellLink (Read-Bytes $deskLink)).Hotkey
    if ($key -ne 0) { "its key is $(Format-Hotkey $key)" }
  }
  # Windows reads shortcut keys from the desktops and the Start menus; a
  # second Ctrl+Alt+U there would compete with VedaBase Unicode's.
  Check 'no other shortcut on a desktop or in a Start menu has Ctrl+Alt+U' {
    $places = @(
      @((Get-FolderPath 'Desktop'), $false, "this account's desktop"),
      @($SharedDesktop, $false, 'the shared desktop'),
      @((Get-FolderPath 'StartMenu'), $true, "this account's Start menu"),
      @("$env:ProgramData\Microsoft\Windows\Start Menu", $true, 'the shared Start menu'))
    $ours = ''
    if (Test-Path -LiteralPath $menuLink -PathType Leaf) { $ours = Get-OsPath $menuLink }
    foreach ($place in $places) {
      if (-not $place[0] -or -not (Test-Path -LiteralPath $place[0] -PathType Container)) { continue }
      $root = Get-OsPath $place[0]
      $deep = [bool]$place[1]
      foreach ($file in @(Get-ChildItem -LiteralPath $place[0] -Filter '*.lnk' -File -Recurse:$deep -ErrorAction SilentlyContinue)) {
        if ($file.FullName -ieq $ours) { continue }
        # Not a file only in the cloud (OneDrive): reading it would download it.
        if (([int64]$file.Attributes -band 0x441000) -ne 0) { continue }
        try { $key = (Read-ShellLink (Read-Bytes $file.FullName)).Hotkey } catch { continue }
        if ($key -eq $CtrlAltU) { "$($place[2]): $($file.FullName.Substring($root.Length).TrimStart('\', '/'))" }
      }
    }
  }
}

# ------------------------------------------------------------------------ this account
function Test-Account {
  Out-Line '-- This account'
  Check 'Folio''s settings for this account: HKCU\Software\VedaBase\4 (docs\testing.md)' {
    if ($null -eq (Get-RegValues 'HKCU:\Software\VedaBase\4')) { 'the key is missing' }
  }
  # Test-FolioSettings (install:361-364): without it the contents read Crimad-Bhagavatam.
  Check 'Folio''s contents font for this account is BellCentennial (HKCU\...\Views\NfoView\Preferences FontName; install:361-364)' {
    $font = Get-RegString (Get-RegValues 'HKCU:\Software\VedaBase\4\Views\NfoView\Preferences') 'FontName'
    if ($font -cne 'BellCentennial') { "it is '$font'" }
  }
  $mine = Get-RegValues "HKCU:\Software\Microsoft\Active Setup\Installed Components\$ActiveSetupId"
  if ($mine -and $mine.ContainsKey('Version')) { Note "Active Setup has run for this account (version $(Get-RegString $mine 'Version'))" }
  else { Note 'Active Setup has not run for this account yet: it runs at its next sign-in (the installer gave the installing account its settings itself, install:596-599)' }
  # Install.exe lists a file that does not exist, "...Vedabase 4 Sh.sdw";
  # Invoke-FinishPhase (install:600-606) points it at VedaBase. Folio keeps
  # the list after that.
  $recent = Get-RegString (Get-RegValues 'HKCU:\Software\VedaBase\4\Views\Frame\RecentFileList') 'File1'
  if (-not $recent) { Skip 'the File menu''s first recent file: this account has none yet' }
  elseif ($recent -like '*Vedabase 4 Sh*') { Fail "the File menu's first recent file is still Install.exe's '$recent', which is not there (install:600-606)" }
  elseif (Test-Path -LiteralPath $recent -PathType Leaf) { Pass "the File menu's first recent file is there: $recent (install:600-606)" }
  else { Note "the File menu's first recent file, $recent, is not there (Folio keeps this list itself)" }

  # Folio writes its swap and index files and the notes there (install:341-343).
  $shared = @("$AppDir\Temp", $NfoDir, $Sdw)
  if (-not $NoVaniBase) { $shared += $VaniSdw }
  Check "every account may write in $AppDir\Temp and $NfoDir and to the shadow files (Authenticated Users, Users, Everyone or INTERACTIVE; install:341-343)" {
    foreach ($path in $shared) {
      if (-not (Test-Path -LiteralPath $path)) { "missing: $path"; continue }
      if (-not (Test-AnyoneMayWrite @(Get-AccessRules $path))) { "not every account may write: $path" }
    }
  }
  $notes = @($Sdw)
  if (-not $NoVaniBase) { $notes += $VaniSdw }
  foreach ($file in $notes) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $writable = 'no'
    try { $writable = Test-Writable $file } catch { $writable = "unknown ($($_.Exception.Message))" }
    if ($writable -eq 'busy') { Skip "this account can write ${file}: a program has it open (VedaBase?); close it and run this check again"; continue }
    Check "this account can write $file, so notes and highlights can be saved (docs\testing.md check 7)" {
      if ($writable -eq 'no') {
        $readOnly = ''
        if ((Get-Item -LiteralPath $file).IsReadOnly) { $readOnly = ' (the file is read-only)' }
        "Windows refuses this account$readOnly"
      } elseif ($writable -ne 'yes') { "could not tell: $writable" }
    }
  }
}

# ------------------------------------------------------------------------ VedaBase Unicode
# Puts TEXT on the clipboard (unless -Again; -AnsiOnly as a program from 2003
# copies it), runs VedaBase Unicode once for each status in STATUSES, all at
# once, then wants WANT on the clipboard and those exit statuses, in any order.
function Test-Press([string]$Name, [string]$Text, [string]$Want, [int[]]$Statuses, [switch]$AnsiOnly, [switch]$Again) {
  if (-not $Again) {
    $back = $null
    try {
      Set-ClipText $Text -AnsiOnly:$AnsiOnly
      $back = Get-ClipText
    } catch { Fail $Name @("could not put the test's text on the clipboard: $($_.Exception.Message)"); return }
    # Not the converter's doing: then there is nothing to test.
    if (-not (Same $back $Text)) { Skip "$Name (the clipboard read back $(Show $back) after this check put $(Show $Text) there)"; return }
  }
  Check $Name {
    $processes = @(foreach ($s in $Statuses) { Start-Converter $script:Run })
    $ended = @(foreach ($p in $processes) { Wait-Converter $p 30 })
    $got = Get-ClipText
    if (-not (Same $got $Want)) { "the clipboard reads $(Show $got), not $(Show $Want)"; Show-Difference $got $Want }
    $have = (@($ended | Sort-Object) | ForEach-Object { if ($_ -lt 0) { 'none' } else { [string]$_ } }) -join ' and '
    $need = (@($Statuses | Sort-Object) | ForEach-Object { [string]$_ }) -join ' and '
    if ($have -ne $need) { "it ended with status $have, not $need" }
    if ($ended -contains -1) { 'a run did not end within 30 s, so this check ended it: was its window waiting for a click? (unicode:94-98)' }
  }
}

function Save-State {
  $state = @{
    ClipText       = Get-ClipText
    ClipOther      = Test-ClipOnlyOther
    LastDirExisted = (Test-Path -LiteralPath $LastDir -PathType Container)
    LastExisted    = (Test-Path -LiteralPath $LastFile -PathType Leaf)
    LastBytes      = $null
    LastTime       = $null
  }
  if ($state.LastExisted) {
    $state.LastBytes = Read-Bytes $LastFile
    $state.LastTime = (Get-Item -LiteralPath $LastFile).LastWriteTimeUtc
  }
  return $state
}
# In this order: any run of the converter still going, its memory, the clipboard.
function Restore-State($State) {
  foreach ($p in @($script:Started)) { try { if (-not $p.HasExited) { $p.Kill(); [void]$p.WaitForExit(5000) } } catch { } }
  try {
    if ($State.LastExisted) {
      Write-Bytes $LastFile $State.LastBytes
      [System.IO.File]::SetLastWriteTimeUtc((Get-OsPath $LastFile), $State.LastTime)
    } else {
      if (Test-Path -LiteralPath $LastFile) { Remove-Item -LiteralPath $LastFile -Force }
      if (-not $State.LastDirExisted -and (Test-Path -LiteralPath $LastDir) -and
          -not (Get-ChildItem -LiteralPath $LastDir -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $LastDir -Force
      }
    }
  } catch { Fail 'what VedaBase Unicode remembers is put back' @($_.Exception.Message) }
  try { if ($null -ne $State.ClipText) { Set-ClipText $State.ClipText } else { Clear-ClipText } }
  catch { Fail 'your clipboard text is put back' @($_.Exception.Message) }
}

function Test-Converter {
  Out-Line '-- VedaBase Unicode on known text (about a minute: its small window shows after each run, and closes by itself)'
  if (-not (Test-Path -LiteralPath $Converter -PathType Leaf)) { Skip "VedaBase Unicode on known text: $Converter is missing"; return }
  if (-not (Test-Sta)) { Skip 'VedaBase Unicode on known text: the clipboard needs PowerShell in STA mode (powershell -STA)'; return }
  try { Initialize-Clipboard } catch { Fail 'the clipboard can be used from PowerShell' @($_.Exception.Message); return }

  # Its Start-menu shortcut's command, or the installer's if that is unreadable.
  $script:Run = New-Want @{ Target = $PowerShellExe; Arguments = $ConverterArgs; WorkingDirectory = $AppDir }
  try {
    $link = Read-ShellLink (Read-Bytes "$Menu\VedaBase Unicode.lnk")
    if ($link.Target -and $link.Arguments) {
      $script:Run = New-Want @{ Target = (Expand $link.Target); Arguments = (Expand $link.Arguments); WorkingDirectory = (Expand $link.WorkingDirectory) }
    }
  } catch { Note 'VedaBase Unicode runs here as the installer sets it up: its Start-menu shortcut could not be read' }

  $state = $null
  try { $state = Save-State } catch { Fail 'the clipboard can be read' @($_.Exception.Message); return }
  if ($null -eq $state.ClipText -and $state.ClipOther -and -not $ReplaceClipboard) {
    Skip ('VedaBase Unicode on known text: the clipboard holds something other than text (a picture, files), ' +
      'which this check cannot put back. Copy some text, or run it with -ReplaceClipboard.')
    return
  }
  try {
    # docs\testing.md check 8, on the first line of Bg 2.13.
    $verse = U 'dehino ''smin yath\u00E4 dehe'
    $verseU = U 'dehino ''smin yath\u0101 dehe'
    Test-Press "Bg 2.13's first line $(Show $verse) becomes $(Show $verseU) (status 0)" $verse $verseU @(0)
    Test-Press 'run again with no new copy, it changes nothing (status 4: refused, the text being converted already)' '' $verseU @(4) -Again
    Test-Press "'dehino' is left as it is: nothing to convert (status 3)" 'dehino' 'dehino' @(3)
    # docs\testing.md, Windows only: converted, yajna holds nothing outside
    # Windows-1252, so only the remembered result (unicode:112-116) keeps a
    # second run from making yajsa (s with a dot below) of it.
    $yajna = U 'yaj\u00EFa'
    $yajnaU = U 'yaj\u00F1a'
    $yajsa = U 'yaj\u1E63a'
    Test-Press "$(Show $yajna) becomes $(Show $yajnaU) (status 0)" $yajna $yajnaU @(0)
    Test-Press "run again, it does not make $(Show $yajsa) of it (status 4)" '' $yajnaU @(4) -Again
    Test-Press "two runs at once on $(Show $yajna) leave $(Show $yajnaU), never $(Show $yajsa) (statuses 0 and 4: one at a time, unicode:123-128)" $yajna $yajnaU @(0, 4)
    # tests/unicode.sh: all 31 letters in lib\balaram-unicode.tsv's order,
    # Windows-1252 punctuation, and Windows line ends.
    $all = U ('\u00CF\u00EF\u00C4\u00E4\u00C9\u00E9\u00C7\u00E7\u00DC\u00FC\u00D2\u00F2\u00D9\u00F9\u00DF\u00FF' +
      '\u00C0\u00E0\u00CC\u00EC\u00CB\u00EB\u00C5\u00E5\u00C8\u00E8\u00D1\u00F1\u00D6\u00F6\u00FB\r\n' +
      'Bg. 18.65: \u201Cman-man\u00E4 bhava\u201D\u2014Prabhup\u00E4da\u2019s purport\u2026\r\nK\u00E5\u00F1\u00EBa\r\nR\u00E4ma\r\n')
    $allU = U ('\u00D1\u00F1\u0100\u0101\u012A\u012B\u015A\u015B\u016A\u016B\u1E0C\u1E0D\u1E24\u1E25\u1E36\u1E37' +
      '\u1E40\u1E41\u1E44\u1E45\u1E46\u1E47\u1E5A\u1E5B\u1E5C\u1E5D\u1E62\u1E63\u1E6C\u1E6Dl\u0310\r\n' +
      'Bg. 18.65: \u201Cman-man\u0101 bhava\u201D\u2014Prabhup\u0101da\u2019s purport\u2026\r\nK\u1E5B\u1E63\u1E47a\r\nR\u0101ma\r\n')
    Test-Press 'all 31 letters of lib\balaram-unicode.tsv, Windows-1252 punctuation and Windows line ends convert exactly (status 0; tests/unicode.sh)' $all $allU @(0)
    # A copy as a program from 2003 makes it: ANSI text alone, which Windows
    # turns into Unicode with the PC's ANSI code page.
    $sri = U '\u00C7r\u00E9 K\u00E5\u00F1\u00EBa'
    $sriU = U '\u015Ar\u012B K\u1E5B\u1E63\u1E47a'
    $acp = Get-AnsiCodePage
    if ($acp -eq '1252') {
      Test-Press "$(Show $sri) copied as ANSI text alone, as a program from 2003 copies, becomes $(Show $sriU) (status 0)" $sri $sriU @(0) -AnsiOnly
    } else {
      Skip "$(Show $sri) copied as ANSI text alone: this PC's ANSI code page is $acp, not 1252, so the test does not apply (how VedaBase's own copies convert here is untested)"
    }
    $krsna = U 'K\u1E5B\u1E63\u1E47a'
    Test-Press "$(Show $krsna), already Unicode, is left as it is (status 4; its window names two such letters: see that they look right)" $krsna $krsna @(4)
  } finally {
    Restore-State $state
  }
  Check 'your clipboard''s text is back as it was (its text only; it is not shown here)' {
    if (-not (Same (Get-ClipText) $state.ClipText)) { 'the clipboard holds other text now' }
  }
  Check 'what VedaBase Unicode remembers of its last conversion (%LOCALAPPDATA%\VedaBase\unicode-last.txt) is as it was' {
    $there = Test-Path -LiteralPath $LastFile -PathType Leaf
    if ($there -ne $state.LastExisted) { "it was there before: $($state.LastExisted); it is there now: $there" }
    elseif ($there -and [Convert]::ToBase64String((Read-Bytes $LastFile)) -ne [Convert]::ToBase64String($state.LastBytes)) { 'it holds something else now' }
    if (-not $state.LastDirExisted -and (Test-Path -LiteralPath $LastDir)) { '%LOCALAPPDATA%\VedaBase was not there before, and is now' }
  }
}

# ------------------------------------------------------------------------ for a person
function Show-HandChecks {
  $verse = U 'yath\u00E4'
  $verseU = U 'yath\u0101'
  Out-Line ''
  Out-Line 'Still to check by hand (docs\testing.md):'
  Out-Line '  - Checks 2-7 in VedaBase and VaniBase: the title page, the diacritics at Bg 2.13, a search for dehino,'
  Out-Line '    VaniBase''s record count, File > Exit closing promptly, a note still there after reopening. Both must'
  Out-Line '    open from their icons with no administrator prompt.'
  Out-Line "  - Check 8 with the keys: copy Bg 2.13's first line, paste it once ($verse), press Ctrl+Alt+U with VedaBase"
  Out-Line "    in front, paste ($verseU); again with another program in front. Did the keys work at once, or only after"
  Out-Line '    signing out and in? Does a console window flash? Which program has the focus afterwards?'
  Out-Line ("  - The small windows this check showed: did they spell {0} and {1} rightly, not as odd letters?" -f (U '\u0101'), (U '\u1E63'))
  Out-Line ("  - Copy {0} out of a verse and press Ctrl+Alt+U twice quickly: {0}, never {1}. Then the desktop's VedaBase" -f (U 'yaj\u00F1a'), (U 'yaj\u1E63a'))
  Out-Line '    Unicode icon.'
  Out-Line '  - A second account: sign in there, run this check, then checks 2-4 and Ctrl+Alt+U.'
  Out-Line '  - A standard (not administrator) account: install from it with an administrator''s password, run this'
  Out-Line '    check, then a note of a few pages, Ctrl+S, a search, close and save: no "Saving Document..." or'
  Out-Line '    "Updating Index..." that sticks.'
  Out-Line '  - Accept the installer''s restart prompt once, run Install-VedaBase-Windows.cmd again, then this check.'
  Out-Line '  - Copy the .sdw notes somewhere safe, uninstall (Settings > Apps), delete the folder and reinstall without'
  Out-Line '    signing out: VedaBase must still show text. Then this check.'
  Out-Line '  - Write down the prompts (UAC, SmartScreen, "Open File - Security Warning"), any media player, and the'
  Out-Line '    restart messages word for word.'
}

# ======================================================================== main
function Invoke-Check([string]$Checkout) {
  $problem = Test-Preflight
  if ($problem) { Out-Line "error: $problem"; $script:Failed = -1; return }
  Initialize-Paths $Checkout
  Out-Line 'VedaBase install check (tests\windows\check.ps1)'
  Out-Line (Get-SystemSummary)
  Test-Installed
  Test-Removed
  Test-Registry
  Test-Shortcuts
  Test-Account
  if ($SkipConverter) { Skip 'VedaBase Unicode on known text (-SkipConverter)' } else { Test-Converter }
  Out-Line ''
  if ($script:Failed) { Out-Line "$($script:Failed) check(s) failed" } else { Out-Line 'all checks passed' }
  Show-HandChecks
}

# Output to a pipe or a file is set to UTF-8, so that its letters can survive
# (each is shown by its code too); a console window shows them as they are.
# Put back as it was at the end.
$savedEncoding = $null
try {
  if ([Console]::IsOutputRedirected) {
    $savedEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
  }
} catch { $savedEncoding = $null }
try { Invoke-Check (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) }
finally { if ($savedEncoding) { try { [Console]::OutputEncoding = $savedEncoding } catch { } } }
if ($script:Failed -lt 0) { exit 2 }
if ($script:Failed -gt 0) { exit 1 }
exit 0
