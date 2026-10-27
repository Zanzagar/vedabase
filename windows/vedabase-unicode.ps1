<#
.SYNOPSIS
  Turns text copied out of VedaBase into Unicode.

.DESCRIPTION
  VedaBase's fonts draw Sanskrit letters in place of ordinary ones (n with a
  tilde shows as s with a dot below, a with a dieresis as a with a macron), so
  text copied out of it reads wrongly anywhere else. This puts the Unicode
  letters on the clipboard instead, using the table in balaram-unicode.tsv.
  The installer copies both into C:\Program Files\VedaBase-Setup and makes a
  "VedaBase Unicode" shortcut (Ctrl+Alt+U) that runs this with no arguments.

  Exit status: 0 converted; 3 nothing to convert; 4 not converted, because the
  text already holds Unicode letters the conversion makes (a with a macron,
  s with a dot below, ...) or is the text it converted last: once converted, an
  n with a tilde means just that, and converting again would turn it into s
  with a dot. 1: the clipboard could not be read or written.

  Plain ASCII on purpose: Windows PowerShell 5.1 reads a script without a BOM
  in the ANSI code page, so the Sanskrit letters are made from their codes.

  The twin of bin/vedabase-unicode (Linux, macOS); tests/unicode.sh holds the
  two to the same results. Written for Windows PowerShell 5.1.

.PARAMETER InFile
  Convert this UTF-8 file into OutFile instead of the clipboard (for testing).
#>
[CmdletBinding()]
param(
  [string]$InFile = '',
  [string]$OutFile = '',
  [string]$Map = ''
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$Utf8 = New-Object System.Text.UTF8Encoding $false

# Installed, the table sits beside this script; in the repository, in lib\.
if (-not $Map) {
  $Map = Join-Path $PSScriptRoot 'balaram-unicode.tsv'
  if (-not (Test-Path -LiteralPath $Map)) {
    $Map = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib') 'balaram-unicode.tsv'
  }
}

# One legacy character to one Unicode string. A Dictionary keyed by [char],
# not a hashtable: PowerShell's hashtables ignore case, and the table holds
# upper- and lowercase letters that must stay apart.
$Table = New-Object 'System.Collections.Generic.Dictionary[char,string]'
foreach ($line in [System.IO.File]::ReadAllLines($Map, $Utf8)) {
  if ($line -eq '' -or $line.StartsWith('#')) { continue }
  $cols = $line.Split("`t")
  if ($cols.Count -ne 2 -or $cols[0].Length -ne 1) { throw "Bad line in ${Map}: $line" }
  $Table.Add($cols[0][0], $cols[1])
}
# The Unicode letters the table makes that are not legacy letters too (all but
# the two n with a tilde): text holding one of them is not fresh from VedaBase.
$Made = @($Table.Values | Where-Object { -not ($_.Length -eq 1 -and $Table.ContainsKey($_[0])) })
# One pass over the text: what a row writes is never read again, so the n
# with a tilde made from i with a dieresis does not go on to become s with a dot.
$Pattern = '[' + (($Table.Keys | ForEach-Object { '\u{0:X4}' -f [int]$_ }) -join '') + ']'
$Evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $Table[$m.Value[0]] }

# Returns @(status, text): 0 and the converted text, or 3 or 4 and the text as it was.
function Convert-VedaBaseText([string]$Text) {
  foreach ($u in $Made) {
    if ($Text.Contains($u)) { return @(4, $Text) }
  }
  $out = [regex]::Replace($Text, $Pattern, $Evaluator)
  if ([string]::Equals($out, $Text, [System.StringComparison]::Ordinal)) { return @(3, $Text) }
  return @(0, $out)
}

function Get-Message([int]$Status) {
  switch ($Status) {
    0 { 'Converted to Unicode. Paste it where you like.' }
    3 { 'Nothing to convert: the copied text has none of VedaBase''s old diacritics. Copy some text in VedaBase first.' }
    4 { "Not converted: the copied text already has Unicode diacritics (such as $([char]0x0101) or $([char]0x1E63)), so it is not fresh from VedaBase. Copy it again in VedaBase, then convert." }
  }
}

# ---------------------------------------------------------------- file mode
if ($InFile) {
  $result = Convert-VedaBaseText ([System.IO.File]::ReadAllText($InFile, $Utf8))
  [System.IO.File]::WriteAllText($OutFile, $result[1], $Utf8)
  if ($result[0] -ne 0) { [Console]::Error.WriteLine((Get-Message $result[0])) }
  exit $result[0]
}

# ---------------------------------------------------------------- clipboard mode
Add-Type -AssemblyName System.Windows.Forms

# A small window that closes itself; it is the only sign the shortcut gives.
function Show-Note([string]$Text, [int]$Seconds, [int]$Icon) {
  try { (New-Object -ComObject WScript.Shell).Popup($Text, $Seconds, 'VedaBase Unicode', $Icon) | Out-Null }
  catch { [System.Windows.Forms.MessageBox]::Show($Text, 'VedaBase Unicode') | Out-Null }
}

# Other programs (clipboard history, cloud clipboard) open the clipboard right
# after every copy, so a busy clipboard is tried again before giving up.
function Get-ClipboardText {
  for ($i = 0; $i -lt 20; $i++) {
    try {
      if (-not [System.Windows.Forms.Clipboard]::ContainsText()) { return '' }
      return [System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::UnicodeText)
    } catch { Start-Sleep -Milliseconds 100 }
  }
  throw 'Windows would not let the converter read the clipboard. Try again.'
}

# The last result is remembered (as a hash, not the text), so pressing the
# shortcut twice does not convert the converted text again.
$LastFile = Join-Path (Join-Path $env:LOCALAPPDATA 'VedaBase') 'unicode-last.txt'
function Get-Hash([string]$Text) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($sha.ComputeHash($Utf8.GetBytes($Text))) } finally { $sha.Dispose() }
}

try {
  $text = Get-ClipboardText
  $last = ''
  if (Test-Path -LiteralPath $LastFile) { $last = [System.IO.File]::ReadAllText($LastFile).Trim() }
  if ($text -ne '' -and $last -eq (Get-Hash $text)) {
    Show-Note 'Not converted: this is the text it has just converted. Copy some text in VedaBase, then convert.' 6 48
    exit 4
  }
  $result = Convert-VedaBaseText $text
  if ($result[0] -ne 0) {
    Show-Note (Get-Message $result[0]) 6 48
    exit $result[0]
  }
  # Copied into the clipboard (true), so it stays after this script ends;
  # 20 tries 100 ms apart while another program holds it.
  [System.Windows.Forms.Clipboard]::SetDataObject($result[1], $true, 20, 100)
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LastFile) | Out-Null
  [System.IO.File]::WriteAllText($LastFile, (Get-Hash $result[1]))
  Show-Note (Get-Message 0) 2 64
  exit 0
} catch {
  Show-Note ("Could not convert: " + $_.Exception.Message) 0 16
  exit 1
}
