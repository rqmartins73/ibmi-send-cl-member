#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$LparIp,
    [Parameter(Mandatory, Position = 1)][string]$User,
    [Parameter(Mandatory, Position = 2)][string]$SshKeyPath,
    [Parameter(Mandatory, Position = 3)][string]$Member,
    [Parameter(Mandatory, Position = 4)][string]$Library,
    [Parameter(Mandatory, Position = 5)][string]$SourceFile,
    [Parameter(Mandatory, Position = 6)][string]$LocalFile,
    [Parameter(Position = 7)][ValidateSet('ssh','ftp','both')][string]$Method = 'ssh'
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
if ($Method -eq 'ssh' -or $Method -eq 'both') {
    Write-Host ""
    Write-Host "=== SSH ==="

    Write-Host "Copying source to IFS: ${User}@${LparIp}:${IfsPath}"
    & scp @SshOpts $LocalFileFull "${User}@${LparIp}:${IfsPath}"

    Write-Host "Running CPYFRMSTMF on IBM i..."
    $CpyCmd = "system `"CPYFRMSTMF FROMSTMF('$IfsPath') TOMBR('/QSYS.LIB/$Library.LIB/$SourceFile.FILE/$Member.MBR') MBROPT(*REPLACE) STMFCCSID(*STMF) DBFCCSID(*FILE)`""
    & ssh @SshOpts "${User}@${LparIp}" $CpyCmd

    Write-Host "SSH: member $Member written to $Library/$SourceFile."
}

# ── Option 2: FTP ─────────────────────────────────────────────────────────────
if ($Method -eq 'ftp' -or $Method -eq 'both') {
    Write-Host ""
    Write-Host "=== FTP ==="

    $FtpPassSecure = Read-Host "FTP Password for $User" -AsSecureString
    $FtpPass       = [System.Net.NetworkCredential]::new('', $FtpPassSecure).Password

    $TempScript = [System.IO.Path]::GetTempFileName()
    try {
        @"
open $LparIp
$User
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
}
