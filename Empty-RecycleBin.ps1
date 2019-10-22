<#
.SYNOPSIS
    Empty Recyle Bin
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
$Shell = New-Object -ComObject Shell.Application
$RecBin = $Shell.Namespace(0xA)
$RecBin.Items() | %{Remove-Item $_.Path -Recurse -Confirm:$false}