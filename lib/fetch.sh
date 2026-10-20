# shellcheck shell=bash
# The VedaBase files: a mirror of the two Google Drive folders, checked against
# manifest/drive-files.tsv (size and SHA-256) on every run.

VB_DRIVE_URL='https://drive.usercontent.google.com/download?export=download&confirm=t&id='

vb_manifest_size() { # REL
  awk -F'\t' -v rel="$1" '$2 == rel {print $3; exit}' "$VB_REPO/manifest/drive-files.tsv"
}

vb_file_ok() { # PATH SIZE SHA256
  [[ -f $1 && $(vb_size "$1") == "$2" ]] || return 1
  [[ $(vb_sha256 <"$1") == "$3" ]]
}

# Retry flags this curl understands: --retry-all-errors needs 7.71 or newer
# (macOS 10.15 and 11 ship 7.64).
vb_curl_retry_flags() {
  local v major minor re='^curl ([0-9]+)\.([0-9]+)'
  v=$(curl --version 2>/dev/null | head -n1) || true
  printf '%s\n' --retry 5 --retry-delay 3 --speed-limit 1024 --speed-time 120
  if [[ $v =~ $re ]]; then
    major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]}
    if ((major > 7 || (major == 7 && minor >= 71))); then printf '%s\n' --retry-all-errors; fi
  fi
}

# VEDABASE_SOURCE is a local directory, or host:dir reached over ssh.
vb_source_is_remote() {
  local re='^[^/:]+:'
  [[ ${VEDABASE_SOURCE:-} =~ $re ]]
}

# Copy one file from VEDABASE_SOURCE or download it from Drive. A partial
# download (.part) is resumed on the next attempt.
vb_fetch_one() { # ID REL OUT
  local id=$1 rel=$2 out=$3 progress=-sS rc flags=()
  if [[ -n ${VEDABASE_SOURCE:-} ]]; then
    if vb_source_is_remote; then
      # -n: ssh must not read the manifest this loop is reading on stdin.
      ssh -n -- "${VEDABASE_SOURCE%%:*}" "cat -- $(printf '%q' "${VEDABASE_SOURCE#*:}/$rel")" >"$out"
    else
      cp -f -- "$VEDABASE_SOURCE/$rel" "$out"
    fi
    return
  fi
  vb_say "Downloading $rel"
  [[ -t 2 ]] && progress=-#
  while IFS= read -r f; do flags+=("$f"); done < <(vb_curl_retry_flags)
  rc=0
  curl -fL "$progress" "${flags[@]}" -C - -o "$out.part" "$VB_DRIVE_URL$id" || rc=$?
  if ((rc == 33)); then # the server would not resume; start over
    rm -f -- "$out.part"
    rc=0
    curl -fL "$progress" "${flags[@]}" -o "$out.part" "$VB_DRIVE_URL$id" || rc=$?
  fi
  ((rc == 0)) && mv -f -- "$out.part" "$out"
}

# vb_fetch_files [ONLY_PREFIX] [SKIP_PREFIX]: the manifest entries under
# ONLY_PREFIX (default: all) except those under SKIP_PREFIX. The two documents
# at the top of the Drive folder are never needed to install.
vb_fetch_files() {
  local only=${1:-} skip=${2:-} id rel size sha out try
  while IFS=$'\t' read -r id rel size sha; do
    [[ -z $id || $id == \#* ]] && continue
    [[ $rel == */* || $rel == Install.exe ]] || continue
    [[ $rel == "$only"* ]] || continue
    [[ -n $skip && $rel == "$skip"* ]] && continue
    out=$VB_DOWNLOADS/$rel
    vb_file_ok "$out" "$size" "$sha" && continue
    mkdir -p -- "$(dirname -- "$out")"
    for try in 1 2 3; do
      vb_fetch_one "$id" "$rel" "$out" && vb_file_ok "$out" "$size" "$sha" && break
      rm -f -- "$out" # a complete but wrong file starts over; a .part is resumed
      if ((try < 3)); then
        vb_warn "$rel did not arrive intact, retrying"
        sleep 5
      fi
    done
    vb_file_ok "$out" "$size" "$sha" ||
      vb_die "$rel did not arrive intact. Usually Google Drive is limiting downloads for a while: wait a few hours and run the installer again. Check the connection and free disk space too; if the files themselves changed, see 'If the download breaks' in README.md."
  done <"$VB_REPO/manifest/drive-files.tsv"
}
