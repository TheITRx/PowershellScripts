
Function Export-AuditLogs {

    <#
    .SYNOPSIS
        Exports Logs
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
        $FileOutputLocation,
        $Today = (get-date -format "MM.dd.yy"),
        $ID = 5145,
        $Source = "Microsoft-Windows-Security-Auditing",
        $LocationPattern
    )
    $PMentryObj = @()
    Get-EventLog -LogName Security -After (Get-date).AddMinutes(-30) -Source $source -InstanceId $ID -Message "*$($LocationPattern)*" -Newest 5 | % {
        
        $Mess = $_.Message -split "\n"
        $entryObj += New-Object -TypeName PSobject -Property @{
            "Time"          = $_.TimeGenerated
            "SourceAddress" = $Mess[10].Substring(18)
            "AccountName"   = $Mess[4].Substring(16)
            "ObjectType"    = $Mess[9].Substring(15)
            "ShareName"     = $Mess[14].Substring(18)
            "SharePath"     = $Mess[15].Substring(18) 
            "Target"        = $Mess[16].Substring(23)
        }
    }

    $PMentryObj | Export-Csv -Path "$($FileOutputLocation)$($LocationPattern -replace "\\",".")-Audit$($Today).csv" -NoTypeInformation -Append
}

Export-AuditLogs -LocationPattern "Shared\Portfolio "




