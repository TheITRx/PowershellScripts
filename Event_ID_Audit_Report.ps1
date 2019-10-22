
<#
.SYNOPSIS
    Grabs the information on certain Event IDs and send out an email to an ITSM. 
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
    Needs to be scheduled on a task scheduler
#>

$temp = $env:temp;
$logEntry = @();
$hostname = hostname;
$yesdate = (Get-Date).AddDays(-1).ToString('M/d/yyyy');
$datestring = (Get-Date).AddDays(-1).ToString('yyMMdd');
$datestring = $hostname+ "-" + $datestring + ".csv";
$filepath = ($temp + "\" + $datestring);
$events = @(5136, 5137, 5141, 4740, 4767, 4720, 4726);
$smtpServer = ""
$toAdd = ""
$fromAdd = ""
$queuname = ""
$clientName = ""

$loopEntry = foreach ($event in $events) { 
    if ((Get-EventLog Security -After $yesdate | Where-Object { $_.EventID -eq $event }).count -gt 0) {
        $logEntry += (Get-EventLog Security -After $yesdate | Where-Object { $_.EventID -eq $event } | Select-Object EventID, @{
            Name    = "TimeWritten";
            Expression = {
                    Get-Date $_.TimeWritten
                }},@{
                    Name       = "Account Name";
                    Expression = {
                        $_.ReplacementStrings[3]
                }},@{
                    Name       = "Object";
                    Expression = {
                        $_.ReplacementStrings[8]
                }}, @{
                    Name       = "Class";
                    Expression = {
                        $_.ReplacementStrings[10]
                }}, @{
                    Name       = "Attribute";
                    Expression = {
                        $_.ReplacementStrings[11]
                }}, @{
                Name       = "Attribute Value";
                Expression={
                    $_.ReplacementStrings[13]
                }})
            }};



if ($logEntry.Length -ne 0) {
        $logEntry | Where-Object {$_} | Export-Csv ($filepath) -NoTypeInformation; 

        ###Convert to CSV
    $Header = @"
    <style>
    h1, h5, th { text-align: center; }
    table { margin: auto; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
    th { background: #0046c3; color: #fff; max-width: 400px; padding: 5px 10px; }
    td { font-size: 11px; padding: 5px 20px; color: #000; }
    tr { background: #b8d1f3; }
    tr:nth-child(even) { background: #dae5f4; }
    tr:nth-child(odd) { background: #b8d1f3; }
    </style>
    <title>
    Audit Report
    </title>
"@
    $logfile_path = $filepath;
    # Environment Variables
        $HTMLReport = "$logfile_path.html";
        $ReportTitle = "Audit Report for $hostname";
    # Collect Data
        $ResultSet = Import-Csv $logfile_path | Sort-Object Status | ConvertTo-Html -Head $Header -Title $ReportTitle -Body "<h1>$ReportTitle</h1>`n<h5>Updated: on $(Get-Date) UTC</h5>";
    # Write Content to Report.
        Add-Content $HTMLReport $ResultSet;

    ###End Convert to CSV

    Send-MailMessage -SmtpServer $smtpServer -From $fromAdd -To $toAdd -Cc ${emailList} -Attachments ($HTMLReport) -Subject ("[$queuname #${ticket_id_2008}]($($clientName)-windows) " + $yesdate + " AD Auditing for " + $hostname) -Body ($yesdate + " AD Auditing for " + $hostname + ".`n`nPlease pend this ticket out accordingly.  An automation is running on this ticket that is generating a report for several hosts."); 

    } 

else
    { 
        $logEntry = "No Data Returned from host";
        $logEntry;
    }; 

           # Remove-Item $filepath;
           # Remove-Item $HTMLReport;