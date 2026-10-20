#!/bin/bash
# Double-click in Finder to install the Bhaktivedanta VedaBase on macOS.
# If macOS will not open it, see README.md ("If macOS will not open the installer").
cd "$(dirname "$0")" || exit 1
bash mac/install.sh "$@"
status=$?
echo
read -r -p 'Press Enter to close this window. ' _
exit "$status"
