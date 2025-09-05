###################################################################################################
# The Goal of this script is to Export the Desktop and Laptop Computer Count for One AD Location  #
# Note: Site Codes is manually input                                                              #
###################################################################################################

# Import Active Directory module
Import-Module ActiveDirectory

# Import Excel module
Import-Module ImportExcel

# Request user input for site code
$siteCode = Read-Host "Please enter the site code"

#Upddate Based on your OU setup
# Construct the distinguished names for the desktops and laptops OUs
$desktopsOUDN = "OU=Desktops,OU=Office,OU=Computers,OU=$siteCode,DC=corp,DC=int"
$laptopsOUDN = "OU=Laptops,OU=Office,OU=Computers,OU=$siteCode,DC=corp,DC=int"

# Get the computer objects from the desktops and laptops OUs
$desktops = Get-ADComputer -Filter * -SearchBase $desktopsOUDN
$laptops = Get-ADComputer -Filter * -SearchBase $laptopsOUDN

# Export the list of desktop names to a CSV file
$desktops | Select-Object -Property SamAccountName | Export-Excel -Path "C:\Temp\ComputerNames.xlsx" -WorksheetName "Desktops" -AutoSize

# Export the list of laptop names to the same Excel file, but in a different worksheet
$laptops | Select-Object -Property SamAccountName | Export-Excel -Path "C:\Temp\ComputerNames.xlsx" -WorksheetName "Laptops" -AutoSize -Append

# Display a message to indicate completion
Write-Output "The list of computer names has been exported to C:\Temp\ComputerNames.xlsx"
