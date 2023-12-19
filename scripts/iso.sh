#!/usr/bin/env nix-shell
#!nix-shell -i bash -p cdrkit
# Script for creating an ISO image from playlist(s).
set -euo pipefail

function show_help() {
  cat << EOF
Usage: usb_backup.sh [-f|-s|-m|-L|-h] [-l ${LABEL}] [-u ${USERNAME}] -d /dev/sdx

 -h - Show this help message.
 -d - Specify loop device path.
 -l - Specify iso image label.

EOF
}

LOOP_DEVICE="/dev/loop19"
ISO_CHARSET='utf-8'
ISO_LABEL='FIRE'
ISO_PATH="${PWD}/${ISO_LABEL}.iso"
TMP_DIR=$(mktemp -d '/tmp/playlist_iso.XXXXXXX')

# Parse arguments
while getopts "d:s:l:h" opt; do
  case "$opt" in
    d) LOOP_DEVICE="${OPTARG}" ;;
    l) ISO_LABEL="${OPTARG}" ;;
    h) show_help; exit 0 ;;
    *) show_help; exit 1 ;;
  esac
done
[ "${1:-}" = "--" ] && shift

if [[ "${#}" -lt 1 ]]; then
    echo "Usage: ${0} <SIZE> <LABEL> <PLAYLIST1> [PLAYLIST2] [PLAYLIST3] ..." >&2
    exit 1
fi

mkdir -p "${TMP_DIR}"
# Unmount on exit.
function cleanup() { rm -fr "${TMP_DIR}"; }
trap cleanup EXIT ERR INT QUIT

IDX=1
for PLAYLIST in "${@}"; do
    while IFS= read -r FILEPATH; do
        FILENAME=$(basename "../${FILEPATH}")
        DESTINATION="${TMP_DIR}/$(printf "%03d" "${IDX}") - ${FILENAME#[0-9]*[-.) ][-.) ][ -.) ]}"
        echo "Copying: ${DESTINATION}"
        cp "../${FILEPATH}" "${DESTINATION}"
        IDX=$(( IDX + 1 ))
    done < "${PLAYLIST}"
done

du -hsc "${TMP_DIR}"
mkisofs -input-charset "${ISO_CHARSET}" -o "${ISO_PATH}" "${TMP_DIR}"
