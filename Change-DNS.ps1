Function Change-DNS {
    
    <#
    .SYNOPSIS
        Change the DNS settings in your NIC
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

    param(
        [string]$Gateway,
        [string]$PrimaryDNS,
        [String]$SecondaryDNS
    )

    $InterfaceIndex = ((Get-NetIPConfiguration).IPv4DefaultGateway) | ? { $_.NextHop -eq $GateWay } | select * | Select InterfaceIndex
    Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex.InterfaceIndex -ServerAddresses ("$PrimaryDNS", "$SecondaryDNS")
} 
