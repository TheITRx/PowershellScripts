<#
.SYNOPSIS
    Disable some exchange protocols for some users. 
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
Function Disable-Protocols($smtpaddress){

    Set-CASMailbox -Identity $smtpaddress `
    -ImapEnabled $false `
    -PopEnabled $false `
    -MAPIEnabled $false `
    -ActiveSyncEnabled $false `
    -OWAEnabled $false

    Set-User -Identity $smtpaddress -RemotePowerShellEnabled $false
}