# Changelog

All notable changes to this project will be documented in this file.

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
