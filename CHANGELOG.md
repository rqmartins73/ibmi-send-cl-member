# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-05-01

### Added
- Initial release of `send_cl_member.sh`
- SSH transfer method: SCP to IFS + `CPYFRMSTMF` to `QCLSRC`
- FTP transfer method: direct `put` using IBM i `NAMEFMT 0`
- Input validation for all 4 parameters
- `set -euo pipefail` for safe error handling
- Full README with usage, troubleshooting, and security notes
