#!/usr/bin/env nix-shell
#!nix-shell -i bash -p cdrkit -p ffmpeg -p fdupes
# Script for creating an ISO image from playlist(s).
set -euo pipefail

# Colors
export BLD='\033[1m'
export RST='\033[0m'
export YLW="\033[1;33m${BLD}"
export RED="\033[0;31m${BLD}"
export GRN="\033[0;32m${BLD}"
export BLU="\033[0;34m${BLD}"

ISO_CHARSET='utf-8'
ISO_LABEL='FIRE'
ISO_PATH="${PWD}/${ISO_LABEL}.iso"
TMP_DIR=$(mktemp -d '/tmp/playlist_iso.XXXXXXX')
CONVERT_MP3=0
REMOVE_DUPLICATES=0

function show_help() {
  cat << EOF
Usage: usb_backup.sh [-h|-c|-u] [-C ${ISO_CHARSET}] [-l ${ISO_LABEL}] [-o $(basename ${ISO_PATH})] <PLAYLIST> [PLAYLIST] ...

 -h - Show this help message.
 -c - Convert OGG files to MP3.
 -u - Remove duplicate files.
 -C - ISO image character set.
 -d - Specify loop device path.
 -l - Specify iso image label.

EOF
}

# Parse arguments
while getopts "h?c?u?C:l:o:" opt; do
  case "$opt" in
    C) ISO_CHARSET="${OPTARG}" ;;
    l) ISO_LABEL="${OPTARG}" ;;
    o) ISO_PATH="${OPTARG}" ;;
    c) CONVERT_MP3=1 ;;
    u) REMOVE_DUPLICATES=1 ;;
    h) show_help; exit 0 ;;
    *) show_help; exit 1 ;;
  esac
done
shift $((OPTIND-1))

if [[ "${#}" -eq 0 ]]; then
    show_help
    exit 1
fi

mkdir -p "${TMP_DIR}"
# Unmount on exit.
function cleanup() { rm -fr "${TMP_DIR}"; }
trap cleanup EXIT ERR INT QUIT

IDX=1
for PLAYLIST in "${@}"; do
    while read -r -u99 SRC; do
        NAME="$(basename "../${SRC}")"
        NO_IDX_NAME="$(echo "${NAME}" | sed -e 's/^[0-9]*[ -.)]*//')"
        NAME="$(printf "%03d" "${IDX}") - ${NO_IDX_NAME}"
        if [[ "${REMOVE_DUPLICATES}" -eq 1 ]]; then
            if find "${TMP_DIR}" -name "* - ${NO_IDX_NAME}" 2>/dev/null | grep -q .; then
                echo -e "${RED}SKIPDUP:${RST} ${BLD}${NAME}${RST}"
                continue
            fi
        fi
        if [[ "${CONVERT_MP3}" -eq 1 ]] && [[ "${NAME}" =~ .ogg$ ]]; then
            NAME="${NAME%.ogg}.mp3"
            echo -e "${YLW}CONVERT:${RST} ${BLD}${NAME}${RST}"
            # Some players do not support OGG.
            ffmpeg -loglevel error -i "../${SRC}" "${TMP_DIR}/${NAME}"
        else
            echo -e "${GRN}COPYING:${RST} ${BLD}${NAME}${RST}"
            cp "../${SRC}" "${TMP_DIR}/${NAME}"
        fi
        IDX=$(( IDX + 1 ))
    done 99< "${PLAYLIST}"
done

echo
if [[ "${REMOVE_DUPLICATES}" -eq 0 ]]; then
    echo -e "${BLD}Checking for duplicates.." >&2
    echo
    if fdupes -r "${TMP_DIR}"; then
        echo -e "${YLW}WARNING:${RST} Duplicates present!" >&2
        echo
    fi
fi

echo -e "${BLD}Creating ISO image...${RST}"
mkisofs -quiet \
    -output="${ISO_PATH}" \
    -volid="${ISO_LABEL}" \
    -input-charset="${ISO_CHARSET}" \
    "${TMP_DIR}"

echo
du -hs "${ISO_PATH}"
echo
echo -e "${GRN}SUCCESS!${RST}"
