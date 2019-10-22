<#
.SYNOPSIS
    Bulk Disable AD users
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
$csv = Import-Csv .\name.csv
$sourceDN = ""
$destinationDN = ""
foreach($names in $csv){
Disable-ADAccount -identity $names.name 
$namesme = $names.name
Move-ADObject -Identity "CN=$namesme,$sourceDN" -TargetPath "OU=External,OU=Disabled,$destinationDN"
Get-ADUser $namesme | Select-Object Name,DistinguishedName
}