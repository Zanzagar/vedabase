#!/usr/bin/env bash
# The exit trap's rollback of a restore, driven directly: install.sh's own
# on_exit and force_remove, extracted verbatim, against fake prefixes in a
# temporary folder. Needs no install; takes seconds.
# The checks are single-quoted on purpose: ok() evaluates them afterwards.
# shellcheck disable=SC2016
set -euo pipefail
WT=$(dirname -- "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)")
T=$(mktemp -d)
src=$(awk '/^force_remove\(\)/ {print; next} /^on_exit\(\) \{/ {f = 1} f {print} f && /^}$/ {f = 0}' "$WT/install.sh")
[[ $src == *'on_exit()'* && $src == *'force_remove()'* ]] || { echo "could not extract the functions"; exit 2; }
vb_warn() { echo "    [warn] $*"; }
vb_display_stop() { :; }
wineserver() { :; }
eval "$src"
in_wizard=0 VB_LOGS=$T/logs
fails=0; ok() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fails=$((fails + 1)); fi; }

echo "case 1: the restored prefix was rejected (it holds an unwritable folder)"
VB_PREFIX=$T/c1/prefix old_prefix=$T/c1/prefix.before-restore-1 stage=$T/c1/restore.aaa
mkdir -p "$old_prefix" "$VB_PREFIX/locked" "$stage/prefix/locked"
echo OLD >"$old_prefix/marker"; echo NEW >"$VB_PREFIX/marker"
: >"$VB_PREFIX/locked/f"; chmod 555 "$VB_PREFIX/locked"; : >"$stage/prefix/locked/f"; chmod 555 "$stage/prefix/locked"
false || on_exit
ok "the old prefix is back in place" '[[ $(cat "$VB_PREFIX/marker") == OLD ]]'
ok "nothing is left under its set-aside name" '[[ ! -e $old_prefix ]]'
ok "the rejected prefix is gone, unwritable folder and all" '[[ -z $(compgen -G "$T/c1/prefix.rejected-*") ]]'
ok "the staging folder is gone" '[[ ! -e $stage ]]'

echo "case 2: cut short between the two renames (no prefix in place)"
VB_PREFIX=$T/c2/prefix old_prefix=$T/c2/prefix.before-restore-2 stage=''
mkdir -p "$old_prefix"; echo OLD >"$old_prefix/marker"
false || on_exit
ok "the old prefix is back in place" '[[ $(cat "$VB_PREFIX/marker") == OLD ]]'

echo "case 3: the rename back is impossible (folder not writable)"
VB_PREFIX=$T/c3/prefix old_prefix=$T/c3/prefix.before-restore-3 stage=''
mkdir -p "$old_prefix" "$VB_PREFIX"; echo OLD >"$old_prefix/marker"; chmod 555 "$T/c3"
out=$(false || on_exit 2>&1) && rc=0 || rc=$?
echo "$out"
ok "on_exit finishes without aborting" '[[ $rc -eq 0 ]]'
ok "it tells where the previous prefix is" '[[ $out == *"previous prefix is in $old_prefix"* ]]'
ok "the previous prefix is untouched" '[[ $(cat "$old_prefix/marker") == OLD ]]'
chmod 755 "$T/c3"

echo "case 4: a successful run (status 0) touches nothing"
VB_PREFIX=$T/c4/prefix old_prefix=$T/c4/prefix.before-restore-4 stage=''
mkdir -p "$old_prefix" "$VB_PREFIX"; echo OLD >"$old_prefix/marker"; echo NEW >"$VB_PREFIX/marker"
true && on_exit
ok "both prefixes are as they were" '[[ $(cat "$VB_PREFIX/marker") == NEW && $(cat "$old_prefix/marker") == OLD ]]'

chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"
if ((fails)); then echo "$fails failed"; exit 1; fi
echo "all rollback checks passed"
