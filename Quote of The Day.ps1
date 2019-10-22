$loginUrl = "http://fuckinghomepage.com/random";
$ie = New-Object -com internetexplorer.application;
$ie.visible = $true;
$ie.navigate($loginUrl);
while ($ie.Busy -eq $true) { Start-Sleep -Seconds 1; }  

$word = $ie.Document.body.getElementsByTagName('p') | select OuterText
$p2 = $word[2] | select -ExpandProperty outerText;

$ie.Quit()
$qotd = "`nWORDS OF THE FUCKING HOUR: " + $p2;

$TextEncoding = [System.Text.Encoding]::UTF8
$EmailBody = "Wakup Bro";
$GUserName = ""
#"passhere" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File "C:\Users\enjoy\Syncplicity Folders\Ipsoft\PSScripts\gmailpass2.txt"
$File = "C:\Users\enjoy\Syncplicity Folders\Ipsoft\PSScripts\gmailpass2.txt"
$GmailLogin = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $GUserName, (Get-Content $File | ConvertTo-SecureString);
Send-MailMessage -To "xx@tmomail.net","xx@gmail.com" -Body $EmailBody -SmtpServer "xx@gmail.com" -From "" -UseSsl -Subject "..."`
-Encoding $TextEncoding -Port 587 -Credential $GmailLogin