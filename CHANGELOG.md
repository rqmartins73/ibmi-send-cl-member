# Changelog

All notable changes to this project will be documented in this file.

## [1.3.0] - 2026-05-03

### Changed
- Added `user` parameter (position 2 in both scripts, `-User` in PowerShell)
- SSH and SCP now connect as `user@lpar` instead of relying on the local username
- FTP no longer prompts for username — uses the `user` parameter; only the password is prompted
- Parameter count increased from 6 to 7; local file path moves to position 7

## [1.2.0] - 2026-05-03

### Added
- `send_cl_member.ps1`: PowerShell equivalent of the Bash script for Windows
  - Same 6 parameters, same logic, compatible with Windows OpenSSH (`scp`/`ssh`)
  - FTP option writes a temporary script file and runs `ftp.exe -s:<file>`; temp file is deleted in a `finally` block regardless of outcome
  - Password handled as `SecureString` (`Read-Host -AsSecureString`), nulled after use
  - `#Requires -Version 5.1` guard; named and positional parameter binding
- README: Windows requirements, PowerShell usage, named parameter table, Windows-specific troubleshooting entries, PowerShell FTP security notes

## [1.1.0] - 2026-05-03

### Changed
- Added two new required parameters: `library` (parameter 4) and `source-file` (parameter 5)
- Local file path moved to parameter 6 (was parameter 4)
- `POWERHA` and `QCLSRC` are no longer hardcoded — any IBM i library and source physical file can be specified
- IFS staging file renamed from `/tmp/<MEMBER>.CL` to `/tmp/<MEMBER>.MBR` (type-agnostic)
- Usage message now includes parameter descriptions inline

## [1.0.0] - 2026-05-01

### Added
- Initial release of `send_cl_member.sh`
- SSH transfer method: SCP to IFS + `CPYFRMSTMF` to `QCLSRC`
- FTP transfer method: direct `put` using IBM i `NAMEFMT 0`
- Input validation for all 4 parameters
- `set -euo pipefail` for safe error handling
- Full README with usage, troubleshooting, and security notes
