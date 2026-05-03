# send_cl_member

Scripts to upload a source member into any source physical file on an IBM i LPAR. Available for **Linux / WSL2** (`send_cl_member.sh`) and **Windows** (`send_cl_member.ps1`). Both support two transfer methods: **SSH** and **FTP**.

---

## Requirements

### Linux / WSL2 — `send_cl_member.sh`
- `bash`, `scp`, `ssh`, and `ftp` installed
- Network access to the LPAR
- A valid SSH private key with its corresponding public key registered on the IBM i

### Windows — `send_cl_member.ps1`
- PowerShell 5.1 or later
- OpenSSH client: `scp` and `ssh` in PATH — included in Windows 10 1809+ and Windows 11 (`Optional Features > OpenSSH Client`)
- `ftp.exe` for the FTP option — included in most Windows versions; verify with `where ftp` in a Command Prompt. Note: removed from Windows 11 24H2+, in which case use the SSH option only
- Network access to the LPAR
- A valid SSH private key with its corresponding public key registered on the IBM i

### On the IBM i LPAR (both scripts)
- **For SSH**: OpenSSH server running (`STRTCPSVR *SSHD`). Your user profile must have the public key listed in `~/.ssh/authorized_keys`. The IFS path `/tmp/` must be writable.
- **For FTP**: FTP server running (`STRTCPSVR *FTP`). The FTP user must have `*CHANGE` authority to the target source physical file.
- The target source physical file must already exist in the target library. If it does not, create it first:
  ```
  CRTSRCPF FILE(<library>/<source-file>) RCDLEN(112)
  ```

---

## Usage

### Bash

```bash
./send_cl_member.sh <lpar-ip> <user> <ssh-key-path> <member-name> <library> <source-file> <local-file>
```

### PowerShell

```powershell
# Named parameters
.\send_cl_member.ps1 -LparIp <lpar-ip> -User <user> -SshKeyPath <ssh-key-path> -Member <member-name> `
    -Library <library> -SourceFile <source-file> -LocalFile <local-file>

# Positional (same order as Bash)
.\send_cl_member.ps1 <lpar-ip> <user> <ssh-key-path> <member-name> <library> <source-file> <local-file>
```

> On Windows, if the execution policy blocks the script, run once:
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

### Parameters

| # | Bash positional | PowerShell named | Description | Example |
|---|-----------------|------------------|-------------|---------|
| 1 | `lpar-ip` | `-LparIp` | IP address or hostname of the IBM i LPAR | `192.168.1.10` |
| 2 | `user` | `-User` | IBM i user profile for SSH and FTP | `RQMARTINS` |
| 3 | `ssh-key-path` | `-SshKeyPath` | Path to the SSH private key | `~/.ssh/id_rsa` |
| 4 | `member-name` | `-Member` | Name of the member to create/replace | `MYPGM` |
| 5 | `library` | `-Library` | IBM i library containing the source physical file | `MYLIB` |
| 6 | `source-file` | `-SourceFile` | Source physical file name on IBM i | `QCLSRC` |
| 7 | `local-file` | `-LocalFile` | Path to the local source file to upload | `/home/user/mypgm.cl` |

### Examples

Send a CL member to `QCLSRC` in library `POWERHA`:

```bash
# Bash
./send_cl_member.sh 192.168.1.10 RQMARTINS ~/.ssh/id_rsa MYPGM POWERHA QCLSRC /home/rqmartins/mypgm.cl
```
```powershell
# PowerShell
.\send_cl_member.ps1 192.168.1.10 RQMARTINS C:\Users\rqmartins\.ssh\id_rsa MYPGM POWERHA QCLSRC C:\src\mypgm.cl
```

Send an RPG member to `QRPGLESRC` in library `BLUEXLIB`:

```bash
./send_cl_member.sh 192.168.1.10 RQMARTINS ~/.ssh/id_rsa SALESRPT BLUEXLIB QRPGLESRC /home/rqmartins/salesrpt.rpgle
```
```powershell
.\send_cl_member.ps1 192.168.1.10 RQMARTINS C:\Users\rqmartins\.ssh\id_rsa SALESRPT BLUEXLIB QRPGLESRC C:\src\salesrpt.rpgle
```

Send a CLLE member to a custom source file in a different library:

```bash
./send_cl_member.sh 192.168.1.10 RQMARTINS ~/.ssh/id_rsa BACKUP PRODLIB CLLESRC /home/rqmartins/backup.clle
```
```powershell
.\send_cl_member.ps1 192.168.1.10 RQMARTINS C:\Users\rqmartins\.ssh\id_rsa BACKUP PRODLIB CLLESRC C:\src\backup.clle
```

---

## What the scripts do

### Validation

Before doing anything, both scripts:
- Check that all 7 arguments are provided, and exit with usage instructions if not.
- Verify the SSH key file exists at the given path.
- Verify the local source file exists at the given path.

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

The PowerShell script uses the same `scp` and `ssh` commands — Windows OpenSSH is fully compatible with IBM i PASE OpenSSH.

---

### Option 2 — FTP

This method uses the classic IBM i FTP interface. Because FTP does not support SSH key authentication, the script prompts for a **username** and **password** interactively. The password input is hidden.

```
ftp -n <lpar-ip>          (Bash)
ftp.exe -s:<script>       (PowerShell)

user <username> <password>
quote SITE NAMEFMT 0
put <local-file> <LIBRARY>/<SOURCE-FILE>.<MEMBER>
quit
```

Key details:

| Command | Purpose |
|---------|---------|
| `ftp -n` / `ftp.exe -s:` | Starts FTP in non-interactive / script mode |
| `quote SITE NAMEFMT 0` | Switches IBM i FTP to library file system mode (`LIB/FILE.MEMBER`) instead of IFS path mode |
| `put` | Uploads the local file directly as a source member |

**PowerShell FTP note:** PowerShell has no heredoc equivalent for piping directly into `ftp.exe`. Instead, the script writes a temporary FTP command file to the user's temp directory, runs `ftp.exe -s:<tempfile>`, then deletes the temp file inside a `finally` block — guaranteeing cleanup even if the transfer fails. The password variable is also nulled out before the temp file is removed.

---

## Behavior on re-run

Both methods use replace semantics:
- **SSH**: `MBROPT(*REPLACE)` overwrites the existing member.
- **FTP**: IBM i FTP replaces the member content if it already exists.

If the member does not exist yet, IBM i will create it automatically in both cases.

---

## Error handling

**Bash:** uses `set -euo pipefail` — the script stops immediately if any command fails, if an undefined variable is referenced, or if a command inside a pipe fails.

**PowerShell:** uses `$ErrorActionPreference = 'Stop'` — any terminating or non-terminating error stops execution. The `finally` block in the FTP section guarantees temp file cleanup regardless of outcome.

---

## Security notes

- The SSH key is never exposed in plain text — it is passed via the `-i` flag to `ssh`/`scp`.
- **Bash:** FTP password is read with `read -s` (silent mode), not echoed to the terminal. The username is taken from the `user` parameter — not prompted.
- **PowerShell:** FTP password is read with `Read-Host -AsSecureString`, stored in memory as a `SecureString`, converted to plain text only to write the temp FTP script, then nulled out immediately after the FTP session ends. The username is taken from `-User` — not prompted.
- The FTP temp script is created in the current user's temp directory; on a properly configured system only that user has read access.
- FTP transmits credentials in plain text over the network. If this is a concern, prefer Option 1 (SSH) exclusively.
- `StrictHostKeyChecking=accept-new` is used for SSH: automatically trusts the host on first connection, refuses if the host key changes later (protection against MITM after initial trust).

---

## Troubleshooting

| Problem | Platform | Likely cause | Fix |
|---------|----------|-------------|-----|
| `Permission denied (publickey)` | Both | Public key not in IBM i `authorized_keys` | Add your public key to `~/.ssh/authorized_keys` on the LPAR |
| `scp: /tmp/MYPGM.MBR: Permission denied` | Both | IFS `/tmp` not writable | Check IFS permissions or use a different IFS staging path |
| `CPYFRMSTMF` error on member | Both | Source physical file does not exist | Run `CRTSRCPF FILE(<library>/<source-file>)` on the IBM i first |
| FTP `530 Login incorrect` | Both | Wrong username or password | Verify the IBM i user profile and password |
| FTP `put` fails | Both | User lacks authority to the target file | Grant `*CHANGE` with `GRTOBJAUT OBJ(<library>/<source-file>) OBJTYPE(*FILE) USER(<user>) AUT(*CHANGE)` |
| `ftp: command not found` | Bash/WSL2 | `ftp` not installed | Run `sudo apt install ftp` |
| `ftp.exe` not found | PowerShell | Removed in Windows 11 24H2+ | Use the SSH option only, or install an FTP client and adjust the script |
| `cannot be loaded because running scripts is disabled` | PowerShell | Execution policy | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| `ssh: command not found` | PowerShell | OpenSSH client not installed | Enable via `Settings > Optional Features > OpenSSH Client` |

---

## Author

Ricardo Martins  
IBM Power Technical Leader @ Blue Chip Portugal  
IBM Champion 2025 | 2026
