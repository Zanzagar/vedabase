#!/usr/bin/env bash
# The Unicode converter through its public doors, on one corpus of worked
# examples: the shell filter (bin/vedabase-unicode -, which Linux runs as
# 'vedabase unicode -' and the Mac app runs as it is), under bash and, with
# VB_TEST_BASH32, the bash 3.2 macOS ships; and its Windows twin
# (windows/vedabase-unicode.ps1 -InFile -OutFile) under PowerShell 7
# (VB_TEST_PWSH, or pwsh on PATH). Then both must agree byte for byte on every
# character Windows-1252 can hold. Needs no install; takes seconds.
set -u
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
B=$VB_TEST_WORK/unicode
rm -rf -- "$B"; mkdir -p "$B"; chmod 700 "$B"
VB_TEST_BASH32=${VB_TEST_BASH32:-}
VB_TEST_PWSH=${VB_TEST_PWSH:-$(command -v pwsh || true)}

# run IMPL IN OUT: one conversion; the exit status is the converter's.
# BSD_SED=1 puts a sed first on PATH that always ends its output in a newline,
# as some BSD seds do: the shell filter must not depend on sed for line ends.
run() {
  local path=$PATH
  [[ ${BSD_SED:-} != 1 ]] || path=$B/bsd-sed:$PATH
  case $1 in
    bash) PATH=$path "$REPO/bin/vedabase-unicode" - <"$2" >"$3" 2>"$B/err" ;;
    bash32) PATH=$path "$VB_TEST_BASH32" "$REPO/bin/vedabase-unicode" - <"$2" >"$3" 2>"$B/err" ;;
    pwsh) "$VB_TEST_PWSH" -NoProfile -NonInteractive -File "$REPO/windows/vedabase-unicode.ps1" \
      -InFile "$2" -OutFile "$3" >"$B/err" 2>&1 ;;
  esac
}
show() { local s=${1//$'\r'/\\r}; printf '%s' "${s//$'\n'/\\n}"; }
filter() { # TEXT: leaves the result in $B/out and the exit status in $status
  printf '%s' "$1" >"$B/in"
  rm -f -- "$B/out"
  run "$impl" "$B/in" "$B/out" && status=0 || status=$?
}
converts() { # INPUT EXPECTED
  filter "$1"
  printf '%s' "$2" >"$B/expected"
  check "[$impl${BSD_SED:+, BSD sed}] '$(show "$1")' becomes '$(show "$2")'" cmp -s "$B/out" "$B/expected"
  check "  ... and reports a conversion (status 0)" test "$status" -eq 0
}
unchanged() { # STATUS INPUT WHY
  filter "$2"
  check "[$impl] '$(show "$2")' is left as it is: $3" cmp -s "$B/out" "$B/in"
  check "  ... with status $1" test "$status" -eq "$1"
}

mkdir -p "$B/bsd-sed"
# shellcheck disable=SC2016 # single quotes: this is the shim's own text
{
  echo '#!/bin/bash'
  printf 'out=$(%q "$@"; printf x) || exit\n' "$(command -v sed)"
  printf '%s\n' 'out=${out%x}' 'printf "%s" "$out"' '[[ -z $out || $out == *$'"'"'\n'"'"' ]] || printf "\n"'
} >"$B/bsd-sed/sed"
chmod +x "$B/bsd-sed/sed"

corpus() {
  converts 'Kåñëa' 'Kṛṣṇa'
  converts 'Çré Kåñëa Caitanya Mahäprabhu' 'Śrī Kṛṣṇa Caitanya Mahāprabhu'
  converts 'Bhagavad-gétä, Çrémad-Bhägavatam' 'Bhagavad-gītā, Śrīmad-Bhāgavatam'
  converts 'kñatriya Viñëu saàsära Gaìgä daëòa añöa namaù' 'kṣatriya Viṣṇu saṁsāra Gaṅgā daṇḍa aṣṭa namaḥ'
  converts 'kÿpta pitèn' 'kḷpta pitṝn'
  # ï becomes ñ, and ñ becomes ṣ: an ñ made from ï must not go on to ṣ.
  converts 'jïäna yajïa' 'jñāna yajña'
  converts 'JÏÄNA ÏÑ' 'JÑĀNA ÑṢ'
  # Everything else stays as it is, Windows-1252 punctuation included.
  # shellcheck disable=SC1112 # the curly quotes are the test
  converts 'Bg. 18.65: “man-manä bhava”—Prabhupäda’s purport…' 'Bg. 18.65: “man-manā bhava”—Prabhupāda’s purport…'
  # All 31, in the table's order. Expected: U+00D1 U+00F1 U+0100 U+0101 U+012A
  # U+012B U+015A U+015B U+016A U+016B U+1E0C U+1E0D U+1E24 U+1E25 U+1E36 U+1E37
  # U+1E40 U+1E41 U+1E44 U+1E45 U+1E46 U+1E47 U+1E5A U+1E5B U+1E5C U+1E5D U+1E62
  # U+1E63 U+1E6C U+1E6D, then l U+0310.
  converts 'ÏïÄäÉéÇçÜüÒòÙùßÿÀàÌìËëÅåÈèÑñÖöû' 'ÑñĀāĪīŚśŪūḌḍḤḥḶḷṀṁṄṅṆṇṚṛṜṝṢṣṬṭl̐'

  # Line ends come through exactly.
  converts $'Kåñëa\r\nRäma\r\n' $'Kṛṣṇa\r\nRāma\r\n'
  converts $'Kåñëa\n\n' $'Kṛṣṇa\n\n'
  if [[ $impl == bash* ]]; then
    BSD_SED=1 converts $'Kåñëa\r\nRäma\r\n' $'Kṛṣṇa\r\nRāma\r\n'
    BSD_SED=1 converts 'Kåñëa' 'Kṛṣṇa'
  fi

  # Nothing to convert: status 3, the text as it was.
  unchanged 3 'Hare Krishna' 'no old diacritics in it'
  unchanged 3 'í ó ú Í Ó Ú' 'these draw ordinary accented letters in the VedaBase fonts too'
  unchanged 3 '' 'nothing at all'
  # Already Unicode: converting again would turn ñ into ṣ, so status 4 instead.
  unchanged 4 'Kṛṣṇa' 'it already has Unicode diacritics'
  unchanged 4 'jñāna and Kåñëa' 'part of it is already Unicode'
  unchanged 4 'tal̐ loka' 'l with candrabindu is something only the converter makes'
  check "  ... and it says why" grep -q 'already' "$B/err"
}

# Windows PowerShell 5.1 reads a script without a BOM in the ANSI code page.
check "windows/vedabase-unicode.ps1 is plain ASCII, so Windows PowerShell 5.1 reads it as written" \
  test "$(tr -d '\000-\177' <"$REPO/windows/vedabase-unicode.ps1" | wc -c)" -eq 0

impls=(bash)
if [[ -n $VB_TEST_BASH32 ]]; then impls+=(bash32); else echo "SKIP  bash 3.2 (set VB_TEST_BASH32)"; fi
if [[ -n $VB_TEST_PWSH ]]; then impls+=(pwsh); else echo "SKIP  the PowerShell twin (set VB_TEST_PWSH, or put pwsh on PATH)"; fi
for impl in "${impls[@]}"; do corpus; done

# Agreement, beyond the worked examples: the two converters must give the same
# bytes and the same status on every character Windows-1252 can hold, on every
# legacy letter next to every other (where a conversion running on into the
# next would show), on text Windows-1252 cannot hold, and on each Unicode
# letter the conversion makes (which must stop it).
if [[ -n $VB_TEST_PWSH ]]; then
  mkdir -p "$B/agree"
  python3 -I - "$B/agree" "$REPO/lib/balaram-unicode.tsv" <<'EOF'
import sys
out, table = sys.argv[1], sys.argv[2]
rows = [l.rstrip('\n').split('\t') for l in open(table, encoding='utf-8') if l.strip() and not l.startswith('#')]
legacy = [k for k, _ in rows]
made = [v for _, v in rows if v not in legacy]
def write(name, text):
    with open('%s/%s' % (out, name), 'w', encoding='utf-8', newline='') as f:
        f.write(text)
cp1252 = []
for b in range(256):
    try:
        cp1252.append(bytes([b]).decode('cp1252'))
    except UnicodeDecodeError:
        cp1252.append(chr(b))  # as Windows decodes the five undefined bytes
write('every-cp1252.txt', ''.join(c + ('\r\n' if i % 16 == 15 else '') for i, c in enumerate(cp1252)))
write('pairs.txt', '\n'.join(a + b for a in legacy for b in legacy))
write('beyond-cp1252.txt', 'Kåñëa नमस्ते 🙏 jïäna')
for i, u in enumerate(made):
    write('made-%02d.txt' % i, 'Kåñëa ' + u)
EOF
  for f in "$B"/agree/*.txt; do
    sb=0 sp=0
    run bash "$f" "$f.bash" || sb=$?
    run pwsh "$f" "$f.pwsh" || sp=$?
    name=${f##*/} text=$(<"$f")
    case $name in
      made-*) check "both converters stop at '${text#Kåñëa }' (status $sb, $sp)" test "$sb" -eq 4 -a "$sp" -eq 4 ;;
      *) check "both converters agree on $name (status $sb, $sp)" test "$sb" -eq 0 -a "$sp" -eq 0 ;;
    esac
    check "  ... byte for byte" cmp -s "$f.bash" "$f.pwsh"
  done
fi
finish
