<#
.SYNOPSIS
    O365 Help
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
$email_un = ""

if(!(Test-Path ".\o365_pw.txt")){

    Read-Host "Enter Email Password" -AsSecureString |  ConvertFrom-SecureString | Out-File ".\o365_pw.txt"
    $email_pw = ".\o365_pw.txt"

}

else{

    $email_pw = ".\o365_pw.txt"
}

$my_email_cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $email_un, (Get-Content $email_pw | ConvertTo-SecureString)

$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $my_email_cred -Authentication Basic -AllowRedirection
Import-PSSession $Session -AllowClobber

