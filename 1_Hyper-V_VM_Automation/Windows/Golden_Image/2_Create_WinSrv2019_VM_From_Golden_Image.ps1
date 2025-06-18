# Create_WinSrv2019VM_Unattended.ps1
<#
.SYNOPSIS
Creates a Generation 2 Windows Server 2019 VM using a single unattended ISO with Autounattend.xml embedded.

.DESCRIPTION
This version mounts only one ISO that contains both the Windows installation files and the Autounattend.xml in the root. Avoids boot order issues seen in multi-ISO setups.
#>

param (
    [Parameter(Mandatory)]
    [string]$VMName,

    [string]$UnifiedISO = "C:\\Downloads\\ISO\\WindowsServer2019-Unattend.iso",
    [string]$SwitchName = "Default Switch",
    [int]$MemoryGB = 4,
    [int]$CPUCount = 2,
    [int]$DiskSizeGB = 80
)

# Define paths
$VMBasePath = "C:\\HyperV\\VMs"
$VMPath = Join-Path $VMBasePath $VMName
$VHDPath = Join-Path $VMPath "$VMName.vhdx"

# Ensure VM directory exists
if (!(Test-Path $VMPath)) {
    New-Item -ItemType Directory -Path $VMPath | Out-Null
}

# Create VHD manually
New-VHD -Path $VHDPath -SizeBytes ($DiskSizeGB * 1GB) -Dynamic | Out-Null

# Create VM
New-VM -Name $VMName -MemoryStartupBytes ($MemoryGB * 1GB) -Generation 2 -SwitchName $SwitchName -Path $VMPath | Out-Null

# Attach VHD
Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0 -Path $VHDPath | Out-Null

# Set CPU
Set-VMProcessor -VMName $VMName -Count $CPUCount

# Disable Secure Boot and configure UEFI boot with DVD priority
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off -BootOrder @()

# Remove any existing DVD drives
Get-VMDvdDrive -VMName $VMName | Remove-VMDvdDrive -Confirm:$false

# Attach unified ISO (automatically assigned location)
Add-VMDvdDrive -VMName $VMName -Path $UnifiedISO | Out-Null

# Wait for devices to attach
$bootDVD = $null
$bootVHD = $null
$retry = 0

while ((!$bootDVD -or !$bootVHD) -and $retry -lt 5) {
    Start-Sleep -Seconds 1
    $bootDVD = Get-VMDvdDrive -VMName $VMName | Where-Object { [System.IO.Path]::GetFullPath($_.Path).ToLower() -eq [System.IO.Path]::GetFullPath($UnifiedISO).ToLower() }
    $bootVHD = Get-VMHardDiskDrive -VMName $VMName
    $retry++
}

if ($bootDVD) {
    Set-VMFirmware -VMName $VMName -BootOrder $bootDVD, $bootVHD | Out-Null
    Write-Host "[OK] Boot order set to DVD then VHD."
} else {
    Write-Warning "[!] Could not locate DVD boot media: $UnifiedISO"
    Get-VMDvdDrive -VMName $VMName | Format-List Path
}

# Start VM
Start-VM -Name $VMName

# Log info
$LogPath = "C:\\HyperV\\VMs\\VM-Creation-Log.csv"
$entry = [pscustomobject]@{
    Timestamp    = (Get-Date).ToString("s")
    VMName       = $VMName
    CPUCount     = $CPUCount
    MemoryGB     = $MemoryGB
    DiskSizeGB   = $DiskSizeGB
    ISO          = $UnifiedISO
    Path         = $VMPath
}

if (!(Test-Path $LogPath)) {
    $entry | Export-Csv -Path $LogPath -NoTypeInformation
} else {
    $entry | Export-Csv -Path $LogPath -Append -NoTypeInformation -Force
}

Write-Host "[OK] Unattended Windows VM '$VMName' created and started."
