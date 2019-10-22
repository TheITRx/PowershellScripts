$FuckingPage = "http://fuckinghomepage.com/"
$FuckingHtml = Invoke-WebRequest -Uri $FuckingPage
($FuckingHtml.ParsedHtml.getElementsByTagName(‘div’) | Where{ $_.className -eq ‘PostBody’ } ).innerText > .\Result.txt
[regex]$RegEx = "(?<=WORDS OF WISDOM OF THE FUCKING DAY:).*(?=PERSON OF THE FUCKING DAY)"
#$Final = ($Result -replace "`n|`r")

Get-Content result.txt | select -index 1,2
<#
Select-String -InputObject $Final -Pattern $RegEx -AllMatches | % {$_.Matches} | %{$_.Value}
#>