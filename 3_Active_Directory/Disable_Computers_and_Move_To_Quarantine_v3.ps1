<#
.SYNOPSIS
Checks Active Directory for computers on the list, verifies if they are online, and moves them to the quarantine OU if necessary.

.DESCRIPTION
This script imports a CSV file containing a list of computer names. It then checks if each computer is present in Active Directory (AD) and if it is online. If a computer is found in AD and is online, it checks if it is already in the quarantine OU. If it is not in the quarantine OU, it disables the computer account and moves it to the quarantine OU. If a computer is found in AD but is not online, it checks if it is already in the quarantine OU. If it is not in the quarantine OU, it disables the computer account and moves it to the quarantine OU.

.PARAMETER FilePath
Specifies the path to the CSV file containing the list of computer names.

.EXAMPLE
.\Disable_Computers_and_Move_To_Quarantine_v3.ps1

This example runs the script using the default CSV file path "C:\Scripts\Disable_Computers_and_move_them.csv".

.INPUTS
CSV file containing a list of computer names.

.OUTPUTS
None.

.NOTES
- The script requires the Active Directory module to be imported.
- The quarantine OU must be specified using the $quarantineOU variable.
- The script uses the Test-Connection cmdlet to check if a computer is online.
- The script uses the Get-ADComputer cmdlet to retrieve the computer object from AD.
- The script uses the Disable-ADAccount cmdlet to disable the computer account.
- The script uses the Move-ADObject cmdlet to move the computer object to the quarantine OU.

#>

# Import the Active Directory module
Import-Module ActiveDirectory

# Updated Based on your needs
# Define the quarantine OU
$quarantineOU = "OU=QUARANTINE,DC=CORP,DC=INT"

## Updated Based on your needs
# Import the CSV file
$computers = Import-Csv -Path "C:\Scripts\Disable_Computers_and_move_them.csv"

foreach ($computer in $computers) {
    try {
        # Get the computer object
        $computerObject = Get-ADComputer $computer.Name -ErrorAction Stop
    } catch {
        Write-Host "Computer $($computer.Name) not found in AD."
        continue
    }

    # Check if the computer is online
    $ping = Test-Connection -ComputerName $computer.Name -Count 1 -Quiet -ErrorAction SilentlyContinue

    if ($ping) {
        # Check if the computer is already in the quarantine OU
        if ($computerObject.DistinguishedName -like "*$quarantineOU") {
            Write-Host "Computer $($computer.Name) is found in AD and is already quarantined."
        } else {
            # Disable the computer object
            Disable-ADAccount -Identity $computerObject

            # Move the computer object to the quarantine OU
            Move-ADObject -Identity $computerObject.ObjectGUID -TargetPath $quarantineOU

            Write-Host "Computer $($computer.Name) is found in AD and has been moved to quarantine."
        }
    } else {
        # Check if the computer is already in the quarantine OU
        if ($computerObject.DistinguishedName -like "*$quarantineOU") {
            Write-Host "Computer $($computer.Name) is found in AD but is not online. It is already in quarantine."
        } else {
            # Disable the computer object
            Disable-ADAccount -Identity $computerObject

            # Move the computer object to the quarantine OU
            Move-ADObject -Identity $computerObject.ObjectGUID -TargetPath $quarantineOU

            Write-Host "Computer $($computer.Name) is found in AD but is not online. It has been moved to quarantine."
        }
    }
}
