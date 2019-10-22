$holder = @()

Get-Mailbox -ResultSize Unlimited -Filter {RecipientTypeDetails -eq "UserMailbox"}  | select *audit*, name | % {

    $prop = [ordered]@{
            "Name" = $_.Name
            "AuditEnabled" = $_.AuditEnabled
            "AuditAdmin" = $_.AuditAdmin -join ','
            "AuditDelegate" = $_.AuditDelegate -join ','
            "AuditOwner" = $_.AuditOwner -join ','
            
        }


        $obj = New-Object -TypeName PSObject -Property $prop
        

        $holder += $obj
}

$holder | export-csv c:\temp\auditreportF2.csv -NoTypeInformation
