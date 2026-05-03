#!/bin/bash
set -euo pipefail

LPAR="${1:-}"
IBMI_USER="${2:-}"
SSH_KEY="${3:-}"
MEMBER="${4:-}"
TARGET_LIB="${5:-}"
TARGET_FILE="${6:-}"
SOURCE_FILE="${7:-}"
METHOD="${8:-ssh}"

[ -z "$LPAR" ]        && read -rp "LPAR IP or hostname:      " LPAR
[ -z "$IBMI_USER" ]   && read -rp "IBM i user profile:       " IBMI_USER
[ -z "$SSH_KEY" ]     && read -rp "SSH key path:             " SSH_KEY
[ -z "$MEMBER" ]      && read -rp "Member name:              " MEMBER
[ -z "$TARGET_LIB" ]  && read -rp "Library:                  " TARGET_LIB
[ -z "$TARGET_FILE" ] && read -rp "Source physical file:     " TARGET_FILE
[ -z "$SOURCE_FILE" ] && read -rp "Local file path:          " SOURCE_FILE

case "$METHOD" in
    ssh|ftp|both) ;;
    *) echo "Error: method must be ssh, ftp, or both (got: $METHOD)"; exit 1 ;;
esac

[ ! -f "$SSH_KEY" ]     && echo "Error: SSH key not found: $SSH_KEY"         && exit 1
[ ! -f "$SOURCE_FILE" ] && echo "Error: Local source file not found: $SOURCE_FILE" && exit 1

IFS_PATH="/tmp/${MEMBER}.MBR"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new"

# ─── Option 1: SSH ────────────────────────────────────────────────────────────
if [ "$METHOD" = "ssh" ] || [ "$METHOD" = "both" ]; then
    echo ""
    echo "=== SSH ==="

    echo "Copying source to IFS: ${IBMI_USER}@${LPAR}:${IFS_PATH}"
    scp $SSH_OPTS "$SOURCE_FILE" "${IBMI_USER}@${LPAR}:${IFS_PATH}"

    echo "Running CPYFRMSTMF on IBM i..."
    ssh $SSH_OPTS "${IBMI_USER}@${LPAR}" \
        "system \"CPYFRMSTMF FROMSTMF('${IFS_PATH}') TOMBR('/QSYS.LIB/${TARGET_LIB}.LIB/${TARGET_FILE}.FILE/${MEMBER}.MBR') MBROPT(*REPLACE) STMFCCSID(*STMF) DBFCCSID(*FILE)\""

    echo "SSH: member ${MEMBER} written to ${TARGET_LIB}/${TARGET_FILE}."
fi

# ─── Option 2: FTP ────────────────────────────────────────────────────────────
if [ "$METHOD" = "ftp" ] || [ "$METHOD" = "both" ]; then
    echo ""
    echo "=== FTP ==="
    read -rsp "FTP Password for ${IBMI_USER}: " FTP_PASS
    echo ""

    ftp -n "$LPAR" << EOF
user $IBMI_USER $FTP_PASS
quote SITE NAMEFMT 0
put $SOURCE_FILE ${TARGET_LIB}/${TARGET_FILE}.${MEMBER}
quit
EOF

    echo "FTP: member ${MEMBER} written to ${TARGET_LIB}/${TARGET_FILE}."
fi
