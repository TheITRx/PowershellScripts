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
$scriptDirectory = "C:\ProgramData\InfraTools"
$scriptPath = Join-Path $scriptDirectory "$TaskName.ps1"
$resultPath = Join-Path $scriptDirectory "$TaskName-result.log"

$scriptContent = @"
`$resultPath = "$resultPath"
`$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

try {
    cmd.exe /C "cmdkey /add:``"$StorageAccountFQDN``" /user:``"localhost\$StorageAccountName``" /pass:``"$StorageKey``""
    New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root "\\$StorageAccountFQDN\$ShareName" -Persist

    "[`$timestamp] SUCCESS: Mapped drive $DriveLetter to \\$StorageAccountFQDN\$ShareName." | Out-File -FilePath `$resultPath -Append -Encoding utf8
}
catch {
    `$errorMessage = `$_.Exception.Message
    "[`$timestamp] ERROR: Failed to map drive $DriveLetter to \\$StorageAccountFQDN\$ShareName. Error: `$errorMessage" | Out-File -FilePath `$resultPath -Append -Encoding utf8
    Write-Error "Failed to map drive $DriveLetter. `$errorMessage"
}
"@

# Write the script file
if (-not (Test-Path -Path $scriptDirectory)) {
    New-Item -ItemType Directory -Path $scriptDirectory -Force | Out-Null
}
Set-Content -Path $scriptPath -Value $scriptContent -Force

# Create scheduled task components
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger -AtLogOn

$principal = New-ScheduledTaskPrincipal `
                -GroupId "Users" `
                #-RunLevel Highest

# Register task
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Force

Write-Host "Scheduled task '$TaskName' created successfully."
