#!/usr/bin/env bash
set -euo pipefail

# Colors
export YLW='\033[1;33m'
export RED='\033[0;31m'
export GRN='\033[0;32m'
export BLU='\033[0;34m'
export BLD='\033[1m'
export RST='\033[0m'

[[ ! -n "${1}" ]] && { echo "No playlist name given!" >&2; exit 1; }
[[ ! -f "${1}" ]] && { echo "No such playlist: ${1}"  >&2; exit 1; }

# Search for filename by gradually removing words.
function smart_find() {
    #echo "smart_find('${1}')" >&2
    SEARCH="${1}"
    TRIMPREFIX="${2:-0}"
    TRIMSUFFIX="${3:-0}"
    SRESULT=$(find ../ -type f -iname "*${SEARCH}*")
    if [[ -n "${SRESULT}" ]]; then
        echo "${SRESULT}"
        return
    fi
    # Continue searching recursively.
    [[ "${TRIMSUFFIX}" ]] && SEARCH=${SEARCH%[ .-]*}
    [[ "${TRIMPREFIX}" ]] && SEARCH=${SEARCH#*[ .-]}
    # If nothing changed no point in searching.
    [[ "${1}" == "${SEARCH}" ]] && return
    # If we've went too far give up.
    [[ "${#SEARCH}" -lt 5 ]] && return
    # Search with shorter pattern.
    smart_find "${SEARCH}"
}

function drop_trailing_newlines() {
    sed -i 's/ *$//' "${1}"
}

NEWLINE=$'\n'

FOUND=()
MISSING=()
INDEX=0
while IFS= read -r FILEPATH; do
    INDEX=$((INDEX + 1))
    [[ -f "../${FILEPATH}" ]] && continue
    FILENAME=$(basename "${FILEPATH}")
    # Attempt search using multiple trimming methods.
    SRESULT=$(smart_find "${FILENAME}" 0 0)
    [[ -z "${SRESULT}" ]] && SRESULT=$(smart_find "${FILENAME}" 0 1)
    [[ -z "${SRESULT}" ]] && SRESULT=$(smart_find "${FILENAME}" 1 1)
    [[ -z "${SRESULT}" ]] && SRESULT=$(smart_find "${FILENAME}" 1 0)
    if [[ -z "${SRESULT}" ]]; then
        MISSING+=("${FILENAME}")
    elif [[ "${SRESULT}" =~ "${NEWLINE}" ]]; then
        echo -e "${RED}${BLD}MULTIPLE MATCHES:${RST} ${FILEPATH}" >&2
        echo "${SRESULT}"
        exit 1
    elif [[ "${FILEPATH}" != "${SRESULT#../}" ]]; then
        SRESULT=$(realpath --relative-to ../ "${SRESULT}")
        # Update file with correct path.
        echo -e "${YLW}FIXING FROM:${RST} '${BLU}${FILEPATH}${RST}'" >&2
        echo -e "${YLW}FIXING INTO:${RST} '${GRN}${SRESULT}${RST}'" >&2
        # Update by line number since sed doesn't support literal strings.
        sed -i -e "${INDEX}s:^.*$:${SRESULT//&/\\&}:" "${1}"
    fi
done < "${1}"

drop_trailing_newlines "${1}"

for MISSINGPATH in "${MISSING[@]}"; do
    echo -e "${RED}${BLD}MISSING:${RST} ${BLD}${MISSINGPATH}${RST}" >&2
done
