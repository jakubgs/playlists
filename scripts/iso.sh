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
MUSIC_DIR="${TMP_DIR}"
CONVERT_MP3=0
REMOVE_DUPLICATES=0

function show_help() {
  cat << EOF
Usage: iso.sh [-h|-c|-u] [-C ${ISO_CHARSET}] [-l ${ISO_LABEL}] [-o $(basename ${ISO_PATH})] <PLAYLIST> [PLAYLIST] ...

Creates ISO image from a provided list of playlists. Supports conversion to OGG and deduplication.

 -h - Show this help message.
 -c - Convert OGG files to MP3.
 -u - Remove duplicate files.
 -C - ISO image character set.
 -d - Specify dir for music files.
 -l - Specify ISO image label.

EOF
}

# Parse arguments
while getopts "h?c?u?d:C:l:o:" opt; do
  case "$opt" in
    C) ISO_CHARSET="${OPTARG}" ;;
    l) ISO_LABEL="${OPTARG}" ;;
    o) ISO_PATH="${OPTARG}" ;;
    d) MUSIC_DIR="${OPTARG}" ;;
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

mkdir -p "${MUSIC_DIR}"
# Unmount on exit.
function cleanup() { rm -fr "${MUSIC_DIR}"; }
if [[ "${MUSIC_DIR}" == "${TMP_DIR}" ]]; then
    trap cleanup EXIT ERR INT QUIT
fi

function file_exists() {
    find "${MUSIC_DIR}" -name "${1}" 2>/dev/null | grep -q .
}

IDX=0
for PLAYLIST in "${@}"; do
    while read -r -u99 SRC; do
        IDX=$(( IDX + 1 ))
        NAME="$(basename "../${SRC}")"
        NO_IDX_NAME="$(echo "${NAME}" | sed -e 's/^[0-9]*[ -.)]*//')"
        NAME="$(printf "%03d" "${IDX}") - ${NO_IDX_NAME}"
        # Avoid copying and converting again the same files
        if [[ -f "${MUSIC_DIR}/${NAME%.[mp3ogg]*}.mp3" ]] ||
           [[ -f "${MUSIC_DIR}/${NAME%.[mp3ogg]*}.ogg" ]]; then
            echo -e "${GRN}SKIPPED:${RST} ${BLD}${NAME}${RST}"
            continue
        elif [[ "${REMOVE_DUPLICATES}" -eq 1 ]] && file_exists "* - ${NO_IDX_NAME}"; then
            echo -e "${RED}SKIPDUP:${RST} ${BLD}${NAME}${RST}"
            IDX=$(( IDX - 1 ))
            continue
        fi
        if [[ "${CONVERT_MP3}" -eq 1 ]] && [[ "${NAME}" =~ .ogg$ ]]; then
            NAME="${NAME%.ogg}.mp3"
            echo -e "${YLW}CONVERT:${RST} ${BLD}${NAME}${RST}"
            # Some players do not support OGG.
            ffmpeg -loglevel error -i "../${SRC}" "${MUSIC_DIR}/${NAME}"
        else
            echo -e "${GRN}COPYING:${RST} ${BLD}${NAME}${RST}"
            cp "../${SRC}" "${MUSIC_DIR}/${NAME}"
        fi
    done 99< "${PLAYLIST}"
done

echo
if [[ "${REMOVE_DUPLICATES}" -eq 0 ]]; then
    echo -e "${BLD}Checking for duplicates.." >&2
    echo
    if fdupes -r "${MUSIC_DIR}"; then
        echo -e "${YLW}WARNING:${RST} Duplicates present!" >&2
        echo
    fi
fi


echo -e "${BLD}Music folder size:${RST}"
echo
sync
du -hs "${MUSIC_DIR}"
echo
echo -e "${BLD}Creating ISO image...${RST}"

mkisofs -quiet \
    -output="${ISO_PATH}" \
    -volid="${ISO_LABEL}" \
    -input-charset="${ISO_CHARSET}" \
    "${MUSIC_DIR}"

echo
sync
du -h "${ISO_PATH}"
echo
echo -e "${GRN}SUCCESS!${RST}"
