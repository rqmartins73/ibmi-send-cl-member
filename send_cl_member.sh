#!/bin/bash
set -euo pipefail

LPAR="$1"
SSH_KEY="$2"
MEMBER="$3"
SOURCE_FILE="$4"

if [ $# -ne 4 ]; then
    echo "Usage: $0 <lpar-ip> <ssh-key-path> <member-name> <cl-source-file>"
    exit 1
fi

[ ! -f "$SSH_KEY" ]     && echo "Error: SSH key not found: $SSH_KEY"     && exit 1
[ ! -f "$SOURCE_FILE" ] && echo "Error: Source file not found: $SOURCE_FILE" && exit 1

IFS_PATH="/tmp/${MEMBER}.CL"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new"

# ─── Option 1: SSH ────────────────────────────────────────────────────────────
echo ""
echo "=== Option 1: SSH ==="

echo "Copying source to IFS: ${LPAR}:${IFS_PATH}"
scp $SSH_OPTS "$SOURCE_FILE" "${LPAR}:${IFS_PATH}"

echo "Running CPYFRMSTMF on IBM i..."
ssh $SSH_OPTS "$LPAR" \
    "system \"CPYFRMSTMF FROMSTMF('${IFS_PATH}') TOMBR('/QSYS.LIB/POWERHA.LIB/QCLSRC.FILE/${MEMBER}.MBR') MBROPT(*REPLACE) STMFCCSID(*STMF) DBFCCSID(*FILE)\""

echo "SSH: member ${MEMBER} written to POWERHA/QCLSRC."

# ─── Option 2: FTP ────────────────────────────────────────────────────────────
echo ""
echo "=== Option 2: FTP ==="
read -rp "FTP Username: " FTP_USER
read -rsp "FTP Password: " FTP_PASS
echo ""

ftp -n "$LPAR" << EOF
user $FTP_USER $FTP_PASS
quote SITE NAMEFMT 0
put $SOURCE_FILE POWERHA/QCLSRC.$MEMBER
quit
EOF

echo "FTP: member ${MEMBER} written to POWERHA/QCLSRC."
