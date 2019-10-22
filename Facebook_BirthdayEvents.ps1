<#
.SYNOPSIS
    Get birthday events in Facebook
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

$ie = New-Object -ComObject "InternetExplorer.application"
$ie.Visible = $true
$ie.Navigate("https://www.facebook.com/events/birthdays/")



while ($ie.Busy -eq $true){

    # Wait for the page to load
    Start-Sleep -seconds 5;

}


$inner = ($ie.Document.IHTMLDocument3_getElementsByTagName('div') | ? {$_.ClassName -eq "_4-u2 _tzh _fbBirthdays__todayCard _4-u8"}).innerHTML 

$bdaylinks = $inner | Select-String -Pattern "https:\/\/www\.facebook\.com\/[a-zA-Z0-9_.-]*" -AllMatches | ForEach-Object { $_.Matches.Value } | ? {$_ -ne "https://www.facebook.com/friendship"}

 $bdaylinks    
