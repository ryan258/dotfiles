#!/bin/zsh
if [ -n "${VSCODE_ENV_REPLACE:-}" ]; then
    IFS=':' read -rA ADDR <<< "$VSCODE_ENV_REPLACE"
    for ITEM in "${ADDR[@]}"; do
        VARNAME="$(echo ${ITEM%%=*})"
        export $VARNAME="$(echo -e ${ITEM#*=})"
    done
    unset VSCODE_ENV_REPLACE
fi
echo "Syntax OK"
