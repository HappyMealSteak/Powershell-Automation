# Create-WindowsVM.ps1
<#
.SYNOPSIS
Creates a Generation 2 Windows Server 2019 VM on a Hyper-V host.

.DESCRIPTION
Automates the provisioning of a Windows Server VM using Hyper-V cmdlets. This base version does not use unattend.xml or prebuilt VHDs.
#>

param (
    [Parameter(Mandatory)]
    [string]$VMName,

    [string]$ISO = 'C:\Downloads\ISO\WindowsServer2019.iso',

    [string]$SwitchName = 'Default Switch',

    [int]$MemoryGB = 4,

    [int]$CPUCount = 2,

    [int]$DiskSizeGB = 80
)

# Ensure script is run as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "You must run this script as an Administrator."
}

# Define base paths
$VMBasePath = "C:\HyperV\VMs"
$VMPath = Join-Path $VMBasePath $VMName
$VHDPath = Join-Path $VMPath "$VMName.vhdx"
$LogPath = "C:\HyperV\VMs\VM-Creation-Log.csv"

# Ensure paths exist
if (!(Test-Path $VMBasePath)) {
    New-Item -ItemType Directory -Path $VMBasePath | Out-Null
}

if (!(Test-Path $VMPath)) {
    New-Item -ItemType Directory -Path $VMPath | Out-Null
}

if (!(Test-Path $ISO)) {
    throw "ISO file not found at path: $ISO"
}

# Create VM without attaching VHD
New-VM -Name $VMName `
       -MemoryStartupBytes ($MemoryGB * 1GB) `
       -Generation 2 `
       -SwitchName $SwitchName `
       -Path $VMPath | Out-Null

# Create and attach VHD manually
New-VHD -Path $VHDPath -SizeBytes ($DiskSizeGB * 1GB) -Dynamic | Out-Null
Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0

# Configure CPU
Set-VMProcessor -VMName $VMName -Count $CPUCount

# Add DVD drive using available controller slot
$vm = Get-VM -Name $VMName
$dvdDrive = Get-VMScsiController -VMName $VMName | ForEach-Object {
    try {
        Add-VMDvdDrive -VMName $VMName -ControllerNumber $_.ControllerNumber -ControllerLocation 1 -Path $ISO -ErrorAction Stop
        return Get-VMDvdDrive -VMName $VMName
    } catch {
        $null
    }
} | Where-Object { $_ -ne $null } | Select-Object -First 1

if (-not $dvdDrive) {
    throw "Failed to add DVD drive. All controller slots may be in use."
}

# Enable Secure Boot and set DVD as first boot device
Set-VMFirmware -VMName $VMName -EnableSecureBoot On
Set-VMFirmware -VMName $VMName -FirstBootDevice $dvdDrive

# Start VM
Start-VM -Name $VMName

# Display VM Specs
Write-Host "[*] Windows VM '$VMName' created with the following specs:" -ForegroundColor Cyan
Write-Host "    - CPU Cores   : $CPUCount"
Write-Host "    - Memory (GB) : $MemoryGB"
Write-Host "    - Disk Size   : $DiskSizeGB GB"
Write-Host "    - ISO         : $ISO"
Write-Host "    - Switch      : $SwitchName"
Write-Host "    - Path        : $($VMPath -replace '\\', '\')"

# Log creation
$logEntry = [pscustomobject]@{
    Timestamp   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    VMName      = $VMName
    CPUCount    = $CPUCount
    MemoryGB    = $MemoryGB
    DiskSizeGB  = $DiskSizeGB
    ISO         = $ISO
    Switch      = $SwitchName
    Path        = ($VMPath -replace '\\', '\')
}

if (!(Test-Path $LogPath)) {
    $logEntry | Export-Csv -Path $LogPath -NoTypeInformation
} else {
    $logEntry | Export-Csv -Path $LogPath -NoTypeInformation -Append
}

Write-Host "[*] VM details logged to: $($LogPath -replace '\\', '\')" -ForegroundColor Green
