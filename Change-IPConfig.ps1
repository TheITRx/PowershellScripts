<#
.SYNOPSIS
    Change IP config in the NIC
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
Get-NetIPAddress | select InterfaceAlias,IPAddress | ? {$_.IPAddress -Like "192.168*"}

$IfAlias = ""
$IP4 = ""
$prefix = "23"
$dgateway = "10.39.50.1"

New-NetIPAddress –InterfaceAlias $IfAlias –IPv4Address $ip4 –PrefixLength $prefix -DefaultGateway $dgateway