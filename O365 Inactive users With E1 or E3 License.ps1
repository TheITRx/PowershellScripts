$list = @()
#get users with e1 or e3 license
$compName = ""
$User_w_e1e3lic = Get-MsolUser -all | ? { $_.isLicensed -EQ "TRUE" } | select DisplayName, UserPrincipalName, LIcenses | ? { ($_.Licenses).AccountSKUID -eq "$($compName):ENTERPRISEPACK" -or ($_.Licenses).AccountSKUID -eq "$($compName):STANDARDPACK" }


foreach ($user in $User_w_e1e3lic) {
    $userlastlogin = Get-MailboxStatistics -Identity $user.UserPrincipalName | select LastLogontime
    if ($userlastlogin.LastLogonTime -lt (get-date).AddDays(-30)) {
        $list += New-Object PSObject -Property @{
            DisplayName       = ($User.Displayname);
            UserPrincipalName = ($User.UserPrincipalName);
            LastLoginTime     = ($userlastlogin.LastLogonTime);
            Licenses          = ($user.Licenses).AccountSKuID;
        }
    }
}

$list | Export-CSV C:\temp\Dur30daysinactivusers.csv -NoTypeInformation

