# send_cl_member.sh

A Bash script that uploads any source member into a source physical file on an IBM i LPAR. The target library and source physical file are passed as parameters, so the script is not limited to `QCLSRC` or any specific library. It supports two transfer methods: **SSH** and **FTP**.

---

## Requirements

### On your local machine (WSL2 / Linux)
- `bash`, `scp`, `ssh`, and `ftp` installed
- Network access to the LPAR
- A valid SSH private key with its corresponding public key already registered on the IBM i

### On the IBM i LPAR
- **For SSH**: OpenSSH server running (`STRTCPSVR *SSHD`). Your user profile must have the public key listed in `~/.ssh/authorized_keys`. The IFS path `/tmp/` must be writable.
- **For FTP**: FTP server running (`STRTCPSVR *FTP`). The FTP user must have `*CHANGE` authority to the target source physical file.
- The target source physical file must already exist in the target library. If it does not, create it first with:
  ```
  CRTSRCPF FILE(<library>/<source-file>) RCDLEN(112)
  ```

---

## Usage

```bash
./send_cl_member.sh <lpar-ip> <ssh-key-path> <member-name> <library> <source-file> <local-file>
```

### Parameters

| # | Parameter | Description | Example |
|---|-----------|-------------|---------|
| 1 | `lpar-ip` | IP address or hostname of the IBM i LPAR | `192.168.1.10` |
| 2 | `ssh-key-path` | Path to your SSH private key file | `~/.ssh/id_rsa` |
| 3 | `member-name` | Name of the member to create/replace | `MYPGM` |
| 4 | `library` | IBM i library containing the source physical file | `MYLIB` |
| 5 | `source-file` | Source physical file name on IBM i | `QCLSRC` |
| 6 | `local-file` | Path to the local source file to upload | `/home/user/mypgm.cl` |

### Examples

Send a CL member to `QCLSRC` in library `POWERHA`:
```bash
./send_cl_member.sh 192.168.1.10 ~/.ssh/id_rsa MYPGM POWERHA QCLSRC /home/rqmartins/mypgm.cl
```

Send an RPG member to `QRPGLESRC` in library `BLUEXLIB`:
```bash
./send_cl_member.sh 192.168.1.10 ~/.ssh/id_rsa SALESRPT BLUEXLIB QRPGLESRC /home/rqmartins/salesrpt.rpgle
```

Send a CLLE member to a custom source file in a different library:
```bash
./send_cl_member.sh 192.168.1.10 ~/.ssh/id_rsa BACKUP PRODLIB CLLESRC /home/rqmartins/backup.clle
```

---

## What the script does

### Validation
Before doing anything, the script:
- Checks that exactly 6 arguments were provided, and exits with usage instructions if not.
- Verifies the SSH key file exists at the given path.
- Verifies the local source file exists at the given path.

---

### Option 1 — SSH

This method uses SSH and SCP to transfer the file without exposing a password.

**Step 1 — SCP upload to IFS**

```bash
scp -i <ssh-key> <local-file> <lpar-ip>:/tmp/<MEMBER>.MBR
```

The source file is copied to the IBM i Integrated File System (IFS) under `/tmp/`. The IFS is a UNIX-like file system on IBM i that acts as a staging area before moving data into native DB2 objects like source physical files.

**Step 2 — CPYFRMSTMF**

```bash
ssh -i <ssh-key> <lpar-ip> \
  "system \"CPYFRMSTMF FROMSTMF('/tmp/MYPGM.MBR') TOMBR('/QSYS.LIB/MYLIB.LIB/QCLSRC.FILE/MYPGM.MBR') MBROPT(*REPLACE) STMFCCSID(*STMF) DBFCCSID(*FILE)\""
```

Once in the IFS, the IBM i command `CPYFRMSTMF` (Copy From Stream File) is executed remotely over SSH. It moves the file from the IFS into the source physical file member. Key parameters:

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `FROMSTMF` | `/tmp/MYPGM.MBR` | Source stream file in the IFS |
| `TOMBR` | `/QSYS.LIB/MYLIB.LIB/QCLSRC.FILE/MYPGM.MBR` | Target member in DB2 native path notation |
| `MBROPT` | `*REPLACE` | Overwrites the member if it already exists |
| `STMFCCSID` | `*STMF` | Uses the encoding declared in the stream file |
| `DBFCCSID` | `*FILE` | Uses the encoding declared in the target source file |

---

### Option 2 — FTP

This method uses the classic IBM i FTP interface. Because FTP does not support SSH key authentication, the script prompts you for a **username** and **password** interactively. The password input is hidden.

```
ftp -n <lpar-ip>
user <username> <password>
quote SITE NAMEFMT 0
put <local-file> <LIBRARY>/<SOURCE-FILE>.<MEMBER>
quit
```

Key details:

| Command | Purpose |
|---------|---------|
| `ftp -n` | Starts FTP without auto-login (allows manual `user` command) |
| `quote SITE NAMEFMT 0` | Switches IBM i FTP to library file system mode (`LIB/FILE.MEMBER`) instead of IFS path mode |
| `put` | Uploads the local file directly as a source member |

---

## Behavior on re-run

Both methods use replace semantics:
- **SSH**: `MBROPT(*REPLACE)` overwrites the existing member.
- **FTP**: IBM i FTP replaces the member content if it already exists.

If the member does not exist yet, IBM i will create it automatically in both cases.

---

## Error handling

The script uses `set -euo pipefail`, which means:
- `set -e`: the script stops immediately if any command fails.
- `set -u`: the script stops if an undefined variable is referenced.
- `set -o pipefail`: the script catches failures inside piped commands.

This prevents silent failures — if the SCP, SSH, or FTP step fails, the script exits immediately with an error.

---

## Security notes

- The SSH key is never exposed in plain text — it is passed via the `-i` flag to `ssh`/`scp`.
- The FTP password is read with `read -s` (silent mode), so it is not echoed to the terminal.
- FTP transmits credentials in plain text over the network. If this is a concern, prefer Option 1 (SSH) exclusively.
- `StrictHostKeyChecking=accept-new` is used for SSH, which automatically trusts the host on first connection but will refuse if the host key changes later (protection against MITM after initial trust).

---

## Troubleshooting

| Problem | Likely cause | Fix |
|---------|-------------|-----|
| `Permission denied (publickey)` | Public key not in IBM i `authorized_keys` | Add your public key to `~/.ssh/authorized_keys` on the LPAR |
| `scp: /tmp/MYPGM.MBR: Permission denied` | IFS `/tmp` not writable | Check IFS permissions or use a different IFS staging path |
| `CPYFRMSTMF` error on member | Source physical file does not exist | Run `CRTSRCPF FILE(<library>/<source-file>)` on the IBM i first |
| FTP `530 Login incorrect` | Wrong username or password | Verify the IBM i user profile and password |
| FTP `put` fails | User lacks authority to the target file | Grant `*CHANGE` with `GRTOBJAUT OBJ(<library>/<source-file>) OBJTYPE(*FILE) USER(<user>) AUT(*CHANGE)` |
| `ftp: command not found` | `ftp` not installed on WSL2 | Run `sudo apt install ftp` |

---

## Author

Ricardo Martins  
IBM Power Technical Leader @ Blue Chip Portugal  
IBM Champion 2025 | 2026
