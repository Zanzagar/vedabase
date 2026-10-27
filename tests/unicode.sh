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
# And a sed that fails, for the error paths.
mkdir -p "$B/fail-sed"
printf '#!/bin/sh\nexit 1\n' >"$B/fail-sed/sed"
chmod +x "$B/fail-sed/sed"

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
    # A step that fails must not pass for a conversion.
    printf 'Kåñëa' >"$B/in"
    PATH=$B/fail-sed:$PATH run "$impl" "$B/in" "$B/out" && status=0 || status=$?
    check "[$impl] with sed failing: status 1 and no text on stdout" test "$status" -eq 1 -a ! -s "$B/out"
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

# The clipboard on Linux, on a private X display, as the menu entry and
# 'vedabase unicode' use it: xclip reads it and writes it back. xclip comes
# from VB_TEST_TOOLS or PATH, or is fetched here as the installer does.
clipboard() {
  local tools=$B/tools
  export PATH=$VB_TEST_TOOLS/usr/bin:$tools/usr/bin:$PATH
  export LD_LIBRARY_PATH=$VB_TEST_TOOLS/usr/lib/x86_64-linux-gnu:$tools/usr/lib/x86_64-linux-gnu
  if ! command -v xclip >/dev/null; then
    mkdir -p "$B/debs" "$tools"
    (cd "$B/debs" && apt-get download xclip >/dev/null 2>&1) && dpkg-deb -x "$B"/debs/xclip_*.deb "$tools"
  fi
  for t in Xtigervnc xauth xclip; do
    command -v "$t" >/dev/null || { echo "SKIP  the clipboard: no $t (VB_TEST_TOOLS=$VB_TEST_TOOLS)"; return; }
  done
  # A stand-in xclip that publishes, then lingers 2 s.
  mkdir -p "$B/slow-xclip"
  printf '#!/bin/sh\n%s "$@" || exit\ncase " $* " in *" -i "*) sleep 2 ;; esac\n' "$(command -v xclip)" >"$B/slow-xclip/xclip"
  chmod +x "$B/slow-xclip/xclip"
  start_display "$B/x" || { fail "a private X display starts"; return; }
  # No desktop notifications from here, and the remembered result in $B.
  unset WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
  export XDG_RUNTIME_DIR=$B/run XDG_CACHE_HOME=$B/cache
  mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
  put() { printf '%s' "$1" | xclip -selection clipboard -t UTF8_STRING -i >/dev/null 2>&1; }
  got() { xclip -selection clipboard -t UTF8_STRING -o 2>/dev/null; }
  press() { "$REPO/bin/vedabase-unicode" >"$B/press.log" 2>&1 && status=0 || status=$?; }

  put 'Çré Kåñëa'; press
  check "the clipboard's 'Çré Kåñëa' becomes 'Śrī Kṛṣṇa'" test "$(got)" = 'Śrī Kṛṣṇa'
  check "  ... with status 0, and it says so" test "$status" -eq 0 -a -s "$B/press.log"
  press
  check "pressing it again leaves 'Śrī Kṛṣṇa' as it is (status 4)" test "$(got)" = 'Śrī Kṛṣṇa' -a "$status" -eq 4
  # Converted, yajïa holds nothing outside Windows-1252, so only the
  # remembered result stops a second press from making yajṣa of it.
  put 'yajïa'; press
  check "the clipboard's 'yajïa' becomes 'yajña'" test "$(got)" = 'yajña' -a "$status" -eq 0
  press
  check "pressing it again does not make 'yajṣa' of it (status 4)" test "$(got)" = 'yajña' -a "$status" -eq 4
  check "  ... and says it has just converted this text" grep -q 'just converted' "$B/press.log"
  put 'Hare Krishna'; press
  check "text with nothing to convert stays (status 3)" test "$(got)" = 'Hare Krishna' -a "$status" -eq 3
  # Folio's copy as Wine hands it to X (seen 2026-10-26): the word, then a NUL
  # and whatever followed it in Folio's buffer. Windows programs stop at the NUL.
  printf 'kaum\303\244ra\303\240\0\0P\0r\0e\0' | xclip -selection clipboard -t UTF8_STRING -i >/dev/null 2>&1
  press
  got >"$B/got"; printf 'kaumāraṁ' >"$B/want"
  check "Folio's copy, NUL and leftovers included, becomes just 'kaumāraṁ'" cmp -s "$B/got" "$B/want"

  # A step that fails leaves the clipboard alone and says so (status 1).
  put 'Kåñëa'; PATH=$B/fail-sed:$PATH press
  check "with sed failing, the clipboard keeps 'Kåñëa' (status 1, not a false success)" test "$(got)" = 'Kåñëa' -a "$status" -eq 1
  # Converting without remembering the result would let the next press make
  # yajṣa of yajña: with nowhere to remember it, nothing changes (status 1).
  mkdir -p "$B/ro"; chmod 500 "$B/ro"
  put 'yajïa'; XDG_CACHE_HOME=$B/ro/cache press
  check "with the cache unwritable, the clipboard keeps 'yajïa' (status 1)" test "$(got)" = 'yajïa' -a "$status" -eq 1
  chmod 700 "$B/ro"
  # Two presses at once: an xclip that is slow to come back holds the first
  # press between publishing and finishing while the second one runs.
  put 'yajïa'
  PATH=$B/slow-xclip:$PATH press &
  sleep 0.7; press; wait "$!"
  check "two presses at once leave 'yajña', never 'yajṣa'" test "$(got)" = 'yajña'

  # The lock (flock): while one press holds it, the next gives up after 5 s,
  # busy (status 1); once that press has ended, however it ended, the lock
  # goes with it. The holder execs into sleep, so killing it frees the lock.
  local cache=$B/cache-lock lockfile holder
  lockfile=$cache/vedabase/unicode-last.lock
  mkdir -p "${lockfile%/*}"
  (exec 8>>"$lockfile" && flock 8 && exec sleep 60) &
  holder=$!
  sleep 0.5
  put 'Kåñëa'; XDG_CACHE_HOME=$cache press
  check "a lock held by a running press is not taken over: busy, 'Kåñëa' stays (status 1)" test "$(got)" = 'Kåñëa' -a "$status" -eq 1
  kill "$holder"; wait "$holder" 2>/dev/null
  XDG_CACHE_HOME=$cache press
  check "once that press has ended, the next one converts: 'Kåñëa' becomes 'Kṛṣṇa'" test "$(got)" = 'Kṛṣṇa' -a "$status" -eq 0
  check "  ... and leaves the lock free" flock -n "$lockfile" true

  # Failed reads stop it too: a clipboard read that fails after part of the
  # text, and a remembered checksum that cannot be read.
  mkdir -p "$B/broken-xclip"
  printf '#!/bin/sh\ncase " $* " in *" -o "*) printf Kåñ; exit 1 ;; esac\nexec %s "$@"\n' "$(command -v xclip)" >"$B/broken-xclip/xclip"
  chmod +x "$B/broken-xclip/xclip"
  put 'Kåñëa Caitanya'; PATH=$B/broken-xclip:$PATH press
  check "a clipboard read that fails part way changes nothing (status 1)" test "$(got)" = 'Kåñëa Caitanya' -a "$status" -eq 1
  put 'yajïa'; press
  chmod 000 "$XDG_CACHE_HOME/vedabase/unicode-last"
  press
  check "with the remembered checksum unreadable, 'yajña' stays (status 1)" test "$(got)" = 'yajña' -a "$status" -eq 1
  chmod 600 "$XDG_CACHE_HOME/vedabase/unicode-last"
  stop_display
}
clipboard
finish
