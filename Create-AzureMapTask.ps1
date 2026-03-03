param(
    [Parameter(Mandatory)]
    [string]$StorageAccountFQDN,

    [Parameter(Mandatory)]
    [string]$StorageAccountName,

    [Parameter(Mandatory)]
    [string]$ShareName,

    [Parameter(Mandatory)]
    [string]$DriveLetter,

    [Parameter(Mandatory)]
    [string]$StorageKey,

    [string]$TaskName = "Map-AzureFileShare"
)

# Build the logon script dynamically
$scriptPath = "C:\ProgramData\$TaskName.ps1"
cmd.exe /C "cmdkey /add:`"$StorageAccountFQDN`" /user:`"localhost\$StorageAccountName`" /pass:`"$StorageKey`""
$scriptContent = @"
`$connectTestResult = Test-NetConnection -ComputerName $StorageAccountFQDN -Port 445
if (`$connectTestResult.TcpTestSucceeded) {
    New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root "\\$StorageAccountFQDN\$ShareName" -Persist
}
else {
    Write-Error "Unable to reach $StorageAccountFQDN over port 445."
}
"@

# Write the script file
New-Item -ItemType Directory -Path "C:\ProgramData" -Force | Out-Null
Set-Content -Path $scriptPath -Value $scriptContent -Force

# Create scheduled task components
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger -AtLogOn

$principal = New-ScheduledTaskPrincipal `
                -GroupId "Users" `
                -RunLevel Highest

# Register task
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Force


Write-Host "Scheduled task '$TaskName' created successfully."
