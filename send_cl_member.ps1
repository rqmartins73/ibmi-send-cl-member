#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$LparIp,
    [Parameter(Mandatory, Position = 1)][string]$SshKeyPath,
    [Parameter(Mandatory, Position = 2)][string]$Member,
    [Parameter(Mandatory, Position = 3)][string]$Library,
    [Parameter(Mandatory, Position = 4)][string]$SourceFile,
    [Parameter(Mandatory, Position = 5)][string]$LocalFile
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SshKeyPath)) {
    Write-Error "SSH key not found: $SshKeyPath"
    exit 1
}
if (-not (Test-Path $LocalFile)) {
    Write-Error "Local source file not found: $LocalFile"
    exit 1
}

$LocalFileFull = (Resolve-Path $LocalFile).Path
$IfsPath       = "/tmp/$Member.MBR"
$SshOpts       = @("-i", $SshKeyPath, "-o", "StrictHostKeyChecking=accept-new")

# ── Option 1: SSH ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Option 1: SSH ==="

Write-Host "Copying source to IFS: ${LparIp}:${IfsPath}"
& scp @SshOpts $LocalFileFull "${LparIp}:${IfsPath}"

Write-Host "Running CPYFRMSTMF on IBM i..."
$CpyCmd = "system `"CPYFRMSTMF FROMSTMF('$IfsPath') TOMBR('/QSYS.LIB/$Library.LIB/$SourceFile.FILE/$Member.MBR') MBROPT(*REPLACE) STMFCCSID(*STMF) DBFCCSID(*FILE)`""
& ssh @SshOpts $LparIp $CpyCmd

Write-Host "SSH: member $Member written to $Library/$SourceFile."

# ── Option 2: FTP ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Option 2: FTP ==="

$FtpUser       = Read-Host "FTP Username"
$FtpPassSecure = Read-Host "FTP Password" -AsSecureString
$FtpPass       = [System.Net.NetworkCredential]::new('', $FtpPassSecure).Password

$TempScript = [System.IO.Path]::GetTempFileName()
try {
    @"
open $LparIp
$FtpUser
$FtpPass
quote SITE NAMEFMT 0
put $LocalFileFull $Library/$SourceFile.$Member
quit
"@ | Set-Content -Path $TempScript -Encoding Ascii

    & ftp.exe -s:$TempScript
}
finally {
    $FtpPass = $null
    Remove-Item $TempScript -Force -ErrorAction SilentlyContinue
}

Write-Host "FTP: member $Member written to $Library/$SourceFile."
