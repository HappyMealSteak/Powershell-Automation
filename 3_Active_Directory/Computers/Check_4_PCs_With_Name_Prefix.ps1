# Import the Active Directory module
Import-Module ActiveDirectory

# Prompt the user to enter the prefix for the computer search
$prefix = Read-Host -Prompt "Enter the computer prefix to search"

# Check if the prefix is empty
if (-not $prefix) {
    Write-Host "No prefix entered. Exiting script."
    exit
}

# Search in Active Directory for computers with the specified prefix
try {
    # Using -Filter and the 'Name' attribute to search for computer names starting with the prefix
    $computers = Get-ADComputer -Filter "Name -like '$prefix*'"

    # Check if any computers were found
    if ($computers) {
        # Output the names of the computers found
        Write-Host "Computers found with prefix '$prefix':"
        foreach ($computer in $computers) {
            Write-Host $computer.Name
        }
    } else {
        Write-Host "No computers found with the prefix '$prefix'."
    }
} catch {
    Write-Host "Error accessing Active Directory. Please ensure you have the required permissions."
}