#!/bin/bash
# Double-click in Finder to install the Bhaktivedanta VedaBase on macOS.
# If macOS will not open it, see README.md ("If macOS will not open the installer").
cd "$(dirname "$0")" || exit 1
if [[ ! -f mac/install.sh || ! -d lib || ! -d manifest ]]; then
  echo "Keep Install-VedaBase-Mac.command inside the unzipped vedabase folder and run it from there."
  read -r -p 'Press Enter to close this window. ' _
  exit 1
fi
bash mac/install.sh "$@"
status=$?
echo
read -r -p 'Press Enter to close this window. ' _
exit "$status"
