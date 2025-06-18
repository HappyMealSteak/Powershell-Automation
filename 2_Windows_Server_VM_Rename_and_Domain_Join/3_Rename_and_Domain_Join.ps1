<#
.SYNOPSIS
  Interactive script to rename computer, set DNS, join domain with retry logic and ESC cancellation.
.NOTES
  Must be run as Administrator.
#>

# Prompt user for input
$ComputerName = Read-Host "Enter desired computer name"
$Domain       = Read-Host "Enter domain to join (e.g. corp.local)"
$DNS          = Read-Host "Enter DNS server IP (or Domain Controller IP)"

# Get domain credentials
$Cred = Get-Credential -Message "Enter credentials for domain '$Domain'"

function Write-Log {
    param([string]$msg)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
}

function Set-Dns {
    param([string[]]$ServerAddresses)
    Write-Log "Configuring DNS servers: $($ServerAddresses -join ', ')"
    # Target physical, up, IPv4 adapters
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and -not $_.Virtual }
    foreach ($adapter in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex `
            -ServerAddresses $ServerAddresses -ErrorAction Stop
        $applied = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4).ServerAddresses
        Write-Host "Interface '$($adapter.Name)' DNS now: $($applied -join ', ')"
    }
}

function Try-DomainJoin {
    Write-Log "Attempting to join domain '$Domain'..."
    try {
        Add-Computer -DomainName $Domain -Credential $Cred `
            -NewName $ComputerName -Force -Restart:$false -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "Domain join failed: $($_.Exception.Message)"
        return $false
    }
}

# Start process
Write-Log "Starting domain join process..."

# Rename and set initial DNS
Set-Dns -ServerAddresses @($DNS)
Write-Log "Renaming machine to '$ComputerName'..."
Rename-Computer -NewName $ComputerName -Force -ErrorAction Stop

# Loop for domain join attempts
while (-not (Try-DomainJoin)) {
    Write-Host "Press ESC to cancel or any other key to retry."
    $key = [System.Console]::ReadKey($true)
    if ($key.Key -eq 'Escape') {
        Write-Log "Operation cancelled by user."
        exit 1
    }

    $DNS = Read-Host "Enter alternate DNS/DC IP"
    Set-Dns -ServerAddresses @($DNS)
}

# Success: reboot
Write-Log "Domain join successful. Rebooting now..."
Restart-Computer -Force
