# shellcheck shell=bash
# The VedaBase files: a mirror of the two Google Drive folders, checked against
# manifest/drive-files.tsv (size and SHA-256) on every run.

VB_DRIVE_URL='https://drive.usercontent.google.com/download?export=download&confirm=t&id='

vb_file_ok() { # PATH SIZE SHA256
  [[ -f $1 && $(vb_size "$1") == "$2" ]] || return 1
  [[ $(vb_sha256 <"$1") == "$3" ]]
}

# Copy one file from VEDABASE_SOURCE (a directory, or host:dir over ssh) or
# download it from Drive.
vb_fetch_one() { # ID REL OUT
  local id=$1 rel=$2 out=$3 src=${VEDABASE_SOURCE:-}
  if [[ -n $src && -d $src ]]; then
    cp -f -- "$src/$rel" "$out"
  elif [[ -n $src ]]; then
    # host:dir. ssh + cat, quoted for the remote shell: macOS's rsync is too old for -s.
    ssh -- "${src%%:*}" "cat -- $(printf '%q' "${src#*:}/$rel")" >"$out"
  else
    vb_say "Downloading $rel"
    local progress=-sS
    [[ -t 2 ]] && progress=-#
    curl -fL "$progress" --retry 5 --retry-delay 3 -o "$out.part" "$VB_DRIVE_URL$id" &&
      mv -f -- "$out.part" "$out"
  fi
}

vb_fetch_files() { # [PATH_PREFIX]: only the manifest entries under it
  local only=${1:-} id rel size sha out try
  while IFS=$'\t' read -r id rel size sha; do
    [[ -z $id || $id == \#* ]] && continue
    [[ $rel == "$only"* ]] || continue
    out=$VB_DOWNLOADS/$rel
    vb_file_ok "$out" "$size" "$sha" && continue
    mkdir -p -- "$(dirname -- "$out")"
    for try in 1 2 3; do
      vb_fetch_one "$id" "$rel" "$out" && vb_file_ok "$out" "$size" "$sha" && break
      rm -f -- "$out" "$out.part"
      ((try < 3)) && vb_warn "$rel did not arrive intact, retrying" && sleep 5
    done
    vb_file_ok "$out" "$size" "$sha" ||
      vb_die "$rel does not match the manifest. If the Drive share changed, see 'If the download breaks' in README.md."
  done <"$VB_REPO/manifest/drive-files.tsv"
}
