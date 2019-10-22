<#
.SYNOPSIS
    Get cause of last reboot
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

$DateNow = (Get-date);
$LastWUpdate = Get-EventLog -LogName "System" -After $DateNow.AddHours(-12) | Where-Object {$_.EventID -eq 19} | Select-Object TimeGenerated, Message;
$LastReboot = Get-EventLog -LogName "System" -After $DateNow.AddHours(-12) | Where-Object {$_.EventID -eq 1074} | Select-Object TimeGenerated, Message -Last 1;
$UnexpectedShutdown = Get-EventLog -LogName "System" -After $DateNow.AddHours(-12) | Where-Object {$_.EventID -eq 6008} | Select-Object TimeGenerated, Message -Last 1;
$LastBootUp = Get-EventLog -LogName "System" | Where-Object {$_.EventID -eq 6005} | Select-Object TimeGenerated, Message -First 1;

If($DateNow -gt $LastBootUp.TimeGenerated.AddHours(12)){
    "UptimeInfo";
    Get-WmiObject -Class Win32_OperatingSystem | Select-Object @{n='LastBootTime';e={[Management.ManagementDateTimeConverter]::ToDateTime($_.LastBootUpTime)}};
    "`n/UptimeInfo";
}

ElseIf($UnexpectedShutdown -ne $Null -and $DateNow -lt $UnexpectedShutdown.TimeGenerated.AddHours(1)){
    "UnexpectedShutdownLog";
    $UnexpectedShutdown | FL;
    "`n/UnexpectedShutdownLog";
}


ElseIf($LastWUpdate -eq $Null)
{
    If($LastReboot -ne $Null -or $UnexpectedShutdown -eq $Null){
    "LastRebootLog";
    $LastReboot | FL;
    "`n/LastRebootLog";

    }
    ElseIf($LastReboot -eq $Null -or $UnexpectedShutdown -ne $Null){
    "UnexpectedShutdownLog";
    $UnexpectedShutdown | FL;
    "`n/UnexpectedShutdownLog";  
    }
    Else{
    "No Reboot Logs Found";
    }
}

ElseIf(($LastWUpdate[0].TimeGenerated -lt $LastReboot.TimeGenerated.AddHours(12)) -or ($LastReboot.TimeGenerated -lt $LastWUpdate[0].TimeGenerated.AddHours(12))){
"WindowsUpdateAndRebootLog`n";
"Windows Update: "
$LastWUpdate | FL;
"Reboot: "
$LastReboot | FL;
"`n/WindowsUpdateAndRebootLog";
}

Else
{
"No Reboot Logs Found";
}