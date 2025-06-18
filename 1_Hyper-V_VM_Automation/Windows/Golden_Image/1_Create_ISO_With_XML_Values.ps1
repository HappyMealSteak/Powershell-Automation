# Build_Unattended_WinISO.ps1
<#
.SYNOPSIS
Creates a new bootable Windows Server ISO with Autounattend.xml embedded in the root.

.DESCRIPTION
This script mounts the original ISO, stages the contents, injects Autounattend.xml, and rebuilds a single ISO.
Automatically locates or downloads oscdimg.exe if not provided. Ensures UEFI boot compatibility.
#>

param (
    [string]$OriginalISO = "C:\\Downloads\\ISO\\WindowsServer2019.iso",
    [string]$AutounattendXML = "C:\\Unattend\\Autounattend.xml",
    [string]$OutputISO = "C:\\Downloads\\ISO\\WindowsServer2019-Unattend.iso",
    [string]$OscdimgPath = ""
)

# Check for admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "You must run this script as Administrator."
}

# Auto-detect or download oscdimg.exe if not provided
function Get-Oscdimg {
    param([string]$DefaultPath)

    $oscdimg = Get-ChildItem -Path $DefaultPath -Recurse -Filter oscdimg.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($oscdimg) {
        return $oscdimg.FullName
    }

    Write-Host "[*] oscdimg.exe not found. Attempting to download and extract..."
    $adkUrl = "https://go.microsoft.com/fwlink/?linkid=2196127"
    $adkInstaller = "$env:TEMP\\adksetup.exe"

    Invoke-WebRequest -Uri $adkUrl -OutFile $adkInstaller -UseBasicParsing
    $extractPath = "$env:TEMP\\ADKTools"
    Start-Process -FilePath $adkInstaller -ArgumentList "/quiet /norestart /features OptionId.DeploymentTools /installpath $extractPath" -Wait

    $downloaded = Get-ChildItem -Path $extractPath -Recurse -Filter oscdimg.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($downloaded) {
        return $downloaded.FullName
    } else {
        throw "oscdimg.exe could not be found or downloaded. Please install Windows ADK manually."
    }
}

if (-not $OscdimgPath) {
    $OscdimgPath = Get-Oscdimg -DefaultPath "C:\\Program Files (x86)\\Windows Kits"
}

# Validate XML
if (!(Test-Path $AutounattendXML)) {
    throw "Autounattend.xml not found at: $AutounattendXML"
}

# Mount the original ISO
$mountResult = Mount-DiskImage -ImagePath $OriginalISO -PassThru
$driveLetter = ($mountResult | Get-Volume).DriveLetter + ":"

# Prepare staging folder
$StagingPath = "$env:TEMP\\ISOStaging_Full"
if (Test-Path $StagingPath) {
    Remove-Item -Path $StagingPath -Recurse -Force
}
New-Item -Path $StagingPath -ItemType Directory | Out-Null

# Copy Windows setup files
Write-Host "[*] Copying Windows setup files to staging area..."
Copy-Item -Path "$driveLetter\\*" -Destination $StagingPath -Recurse

# Dismount ISO
Dismount-DiskImage -ImagePath $OriginalISO

# Inject XML
Copy-Item -Path $AutounattendXML -Destination (Join-Path $StagingPath "Autounattend.xml") -Force

# Ensure output directory exists
$outputFolder = Split-Path -Path $OutputISO -Parent
if (!(Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
}

# Rebuild bootable ISO with both BIOS and UEFI boot compatibility
Write-Host "[*] Creating new bootable ISO with embedded Autounattend.xml..."
$efiBootFile = Join-Path $StagingPath 'efi\microsoft\boot\efisys_noprompt.bin'
if (!(Test-Path $efiBootFile)) {
    Write-Warning "[!] efisys_noprompt.bin not found. Falling back to efisys.bin"
    $efiBootFile = Join-Path $StagingPath 'efi\microsoft\boot\efisys.bin'
}

& $OscdimgPath -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$StagingPath\boot\etfsboot.com"#pEF,e,b"$efiBootFile" $StagingPath $OutputISO

if (Test-Path $OutputISO) {
    Write-Host "[OK] New unattended ISO created at: $OutputISO" -ForegroundColor Green
} else {
    throw "ISO creation failed."
}
