#!/bin/bash
set -euo pipefail

LPAR="$1"
SSH_KEY="$2"
MEMBER="$3"
TARGET_LIB="$4"
TARGET_FILE="$5"
SOURCE_FILE="$6"

if [ $# -ne 6 ]; then
    echo "Usage: $0 <lpar-ip> <ssh-key-path> <member-name> <library> <source-file> <local-file>"
    echo ""
    echo "  lpar-ip      IP address or hostname of the IBM i LPAR"
    echo "  ssh-key-path Path to the SSH private key"
    echo "  member-name  Name of the member to create/replace"
    echo "  library      IBM i library containing the source physical file (e.g. MYLIB)"
    echo "  source-file  Source physical file name on IBM i (e.g. QCLSRC, QRPGLESRC)"
    echo "  local-file   Path to the local source file to upload"
    exit 1
fi

[ ! -f "$SSH_KEY" ]     && echo "Error: SSH key not found: $SSH_KEY"         && exit 1
[ ! -f "$SOURCE_FILE" ] && echo "Error: Local source file not found: $SOURCE_FILE" && exit 1

IFS_PATH="/tmp/${MEMBER}.MBR"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new"

# ─── Option 1: SSH ────────────────────────────────────────────────────────────
echo ""
echo "=== Option 1: SSH ==="

echo "Copying source to IFS: ${LPAR}:${IFS_PATH}"
scp $SSH_OPTS "$SOURCE_FILE" "${LPAR}:${IFS_PATH}"

echo "Running CPYFRMSTMF on IBM i..."
ssh $SSH_OPTS "$LPAR" \
    "system \"CPYFRMSTMF FROMSTMF('${IFS_PATH}') TOMBR('/QSYS.LIB/${TARGET_LIB}.LIB/${TARGET_FILE}.FILE/${MEMBER}.MBR') MBROPT(*REPLACE) STMFCCSID(*STMF) DBFCCSID(*FILE)\""

echo "SSH: member ${MEMBER} written to ${TARGET_LIB}/${TARGET_FILE}."

# ─── Option 2: FTP ────────────────────────────────────────────────────────────
echo ""
echo "=== Option 2: FTP ==="
read -rp "FTP Username: " FTP_USER
read -rsp "FTP Password: " FTP_PASS
echo ""

ftp -n "$LPAR" << EOF
user $FTP_USER $FTP_PASS
quote SITE NAMEFMT 0
put $SOURCE_FILE ${TARGET_LIB}/${TARGET_FILE}.${MEMBER}
quit
EOF

echo "FTP: member ${MEMBER} written to ${TARGET_LIB}/${TARGET_FILE}."
