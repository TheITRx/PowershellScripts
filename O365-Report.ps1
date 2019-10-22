Get-MsolUser -All | ? {(!($_.LastDirSyncTime))} | select UserPrincipalName, `
                                                         DisplayName, `
                                                         ISlicensed, `
                                                         whencreated, `
                                                         @{Name="LastLogin";E={Get-MailboxStatistics $_.UserPrincipalName | select -ExpandProperty Lastlogontime -ErrorAction SilentlyContinue}}, `
                                                         @{Name="LoginBlocked";E={Get-MsolUser -UserPrincipalName $_.UserPrincipalName | select -ExpandProperty BlockCredential -ErrorAction SilentlyContinue}} `
                                                         | Export-Csv C:\Temp\Cloud-Only-Accounts_1.csv -NoTypeInformation