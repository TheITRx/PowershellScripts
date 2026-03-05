<#
.SYNOPSIS
Minimizes a Windows 11 install by removing removable packages/apps and applying anti-reinstall policies.

.DESCRIPTION
Runs in elevated PowerShell, removes installed/provisioned Appx packages, targets common Win32 bloat,
attempts Edge/WebView2 removal, disables update channels that can restore them, and logs every action.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$LogDirectory = 'C:\ProgramData\InfraScripts',
    [switch]$KeepMicrosoftStore
)

# Fail fast and keep strict handling so partial cleanup does not silently continue.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# Returns $true when the script is running elevated.
function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Standard info logger for consistent script output.
function Write-Info {
    param([string]$Message)
    Write-Host ("[INFO] {0}" -f $Message)
}

# Standard warning logger for non-fatal issues.
function Write-Warn {
    param([string]$Message)
    Write-Host ("[WARN] {0}" -f $Message)
}

# Adds one structured row to the final CSV results log.
function Add-RemovalRecord {
    param(
        [string]$Type,
        [string]$Name,
        [string]$Status,
        [string]$Details
    )

    $script:RemovalRecords.Add([pscustomobject]@{
        TimeStamp = (Get-Date).ToString('s')
        Type = $Type
        Name = $Name
        Status = $Status
        Details = $Details
    }) | Out-Null
}

# Safely reads optional object properties (strict mode compatible).
function Get-SafePropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    return $null
}

# Ensures a registry key exists and writes a DWORD value with result logging.
function Set-RegistryDword {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [int]$Value,
        [string]$Type = 'Policy'
    )

    try {
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        if ($PSCmdlet.ShouldProcess(("{0}\\{1}" -f $Path, $Name), 'Set registry value')) {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
            Add-RemovalRecord -Type $Type -Name ("{0}\\{1}" -f $Path, $Name) -Status 'Set' -Details ("Value={0}" -f $Value)
        }
    } catch {
        Add-RemovalRecord -Type $Type -Name ("{0}\\{1}" -f $Path, $Name) -Status 'Failed' -Details $_.Exception.Message
    }
}

# Checks whether a value matches at least one wildcard pattern.
function Test-WildcardMatch {
    param(
        [string]$Value,
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Value -like $pattern) {
            return $true
        }
    }

    return $false
}

# Disables ContentDeliveryManager features that repopulate consumer/suggested content.
function Set-ContentDeliveryRestrictions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [string]$RecordType = 'Policy'
    )

    $values = @{
        'ContentDeliveryAllowed'            = 0
        'FeatureManagementEnabled'          = 0
        'OemPreInstalledAppsEnabled'        = 0
        'PreInstalledAppsEnabled'           = 0
        'PreInstalledAppsEverEnabled'       = 0
        'SilentInstalledAppsEnabled'        = 0
        'SoftLandingEnabled'                = 0
        'SubscribedContentEnabled'          = 0
        'SubscribedContent-338387Enabled'   = 0
        'SubscribedContent-338388Enabled'   = 0
        'SubscribedContent-338389Enabled'   = 0
        'SubscribedContent-338393Enabled'   = 0
        'SubscribedContent-353694Enabled'   = 0
        'SubscribedContent-353696Enabled'   = 0
        'SystemPaneSuggestionsEnabled'      = 0
        'RotatingLockScreenEnabled'         = 0
        'RotatingLockScreenOverlayEnabled'  = 0
    }

    $valueNames = @($values.Keys | Sort-Object)
    $valueTotal = [math]::Max($valueNames.Count, 1)
    $valueIndex = 0
    foreach ($name in $valueNames) {
        $valueIndex++
        $percent = [int](($valueIndex / $valueTotal) * 100)
        Write-Progress -Id 90 -Activity ("Applying content delivery restrictions ({0})" -f $RecordType) -Status ("[{0}/{1}] {2}" -f $valueIndex, $valueTotal, $name) -PercentComplete $percent
        Set-RegistryDword -Path $RootPath -Name $name -Value $values[$name] -Type $RecordType
    }
    Write-Progress -Id 90 -Activity ("Applying content delivery restrictions ({0})" -f $RecordType) -Completed
}

# Force-removes targeted Appx families (installed + provisioned), even if they were missed by generic filters.
function Remove-AppxByPattern {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns,
        [string]$RecordType = 'AppxTargeted'
    )

    $patternTotal = [math]::Max($Patterns.Count, 1)
    $patternIndex = 0
    foreach ($pattern in $Patterns) {
        $patternIndex++
        $patternPercent = [int](($patternIndex / $patternTotal) * 100)
        Write-Progress -Id 91 -Activity 'Force-removing targeted Appx packages' -Status ("[{0}/{1}] Pattern: {2}" -f $patternIndex, $patternTotal, $pattern) -PercentComplete $patternPercent

        $installedMatches = @(Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue |
            Sort-Object PackageFullName -Unique)
        $installedTotal = [math]::Max($installedMatches.Count, 1)
        $installedIndex = 0
        foreach ($pkg in $installedMatches) {
            $installedIndex++
            $installedPercent = [int](($installedIndex / $installedTotal) * 100)
            Write-Progress -Id 92 -ParentId 91 -Activity 'Removing installed targeted Appx packages' -Status ("[{0}/{1}] {2}" -f $installedIndex, $installedTotal, $pkg.PackageFullName) -PercentComplete $installedPercent

            try {
                if ($PSCmdlet.ShouldProcess($pkg.PackageFullName, 'Force Remove-AppxPackage')) {
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                    } catch {
                        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                    }
                    Add-RemovalRecord -Type $RecordType -Name $pkg.Name -Status 'Removed' -Details $pkg.PackageFullName
                }
            } catch {
                Add-RemovalRecord -Type $RecordType -Name $pkg.Name -Status 'Failed' -Details $_.Exception.Message
            }
        }
        Write-Progress -Id 92 -Activity 'Removing installed targeted Appx packages' -Completed

        $provisionedMatches = @(Get-AppxProvisionedPackage -Online |
            Where-Object { ($_.DisplayName -like $pattern) -or ($_.PackageName -like $pattern) } |
            Sort-Object PackageName -Unique)
        $provisionedTotal = [math]::Max($provisionedMatches.Count, 1)
        $provisionedIndex = 0
        foreach ($prov in $provisionedMatches) {
            $provisionedIndex++
            $provisionedPercent = [int](($provisionedIndex / $provisionedTotal) * 100)
            Write-Progress -Id 93 -ParentId 91 -Activity 'Removing provisioned targeted Appx packages' -Status ("[{0}/{1}] {2}" -f $provisionedIndex, $provisionedTotal, $prov.PackageName) -PercentComplete $provisionedPercent

            try {
                if ($PSCmdlet.ShouldProcess($prov.PackageName, 'Force Remove-AppxProvisionedPackage')) {
                    Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
                    Add-RemovalRecord -Type ("{0}Provisioned" -f $RecordType) -Name $prov.DisplayName -Status 'Removed' -Details $prov.PackageName
                }
            } catch {
                Add-RemovalRecord -Type ("{0}Provisioned" -f $RecordType) -Name $prov.DisplayName -Status 'Failed' -Details $_.Exception.Message
            }
        }
        Write-Progress -Id 93 -Activity 'Removing provisioned targeted Appx packages' -Completed
    }
    Write-Progress -Id 91 -Activity 'Force-removing targeted Appx packages' -Completed
}

# Removes matching Start Menu shortcuts that can still show "ghost" entries after package uninstall.
function Remove-ShortcutByPattern {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    $shortcutRoots = @(
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
        'C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs'
    )

    $existingRoots = @($shortcutRoots | Where-Object { Test-Path -Path $_ })
    if ($existingRoots.Count -eq 0) {
        Add-RemovalRecord -Type 'Shortcut' -Name '<none>' -Status 'Skipped' -Details 'No Start Menu roots found.'
        return
    }

    $rootTotal = [math]::Max($existingRoots.Count, 1)
    $rootIndex = 0
    foreach ($root in $existingRoots) {
        $rootIndex++
        $rootPercent = [int](($rootIndex / $rootTotal) * 100)
        Write-Progress -Id 94 -Activity 'Removing targeted Start Menu shortcuts' -Status ("[{0}/{1}] Root: {2}" -f $rootIndex, $rootTotal, $root) -PercentComplete $rootPercent

        $files = @(Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.Extension -eq '.lnk' -or $_.Extension -eq '.url') -and
                (Test-WildcardMatch -Value $_.Name -Patterns $Patterns)
            })

        $fileTotal = [math]::Max($files.Count, 1)
        $fileIndex = 0
        foreach ($file in $files) {
            $fileIndex++
            $filePercent = [int](($fileIndex / $fileTotal) * 100)
            Write-Progress -Id 95 -ParentId 94 -Activity 'Deleting targeted shortcuts' -Status ("[{0}/{1}] {2}" -f $fileIndex, $fileTotal, $file.Name) -PercentComplete $filePercent
            try {
                if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove shortcut')) {
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                    Add-RemovalRecord -Type 'Shortcut' -Name $file.Name -Status 'Removed' -Details $file.FullName
                }
            } catch {
                Add-RemovalRecord -Type 'Shortcut' -Name $file.Name -Status 'Failed' -Details $_.Exception.Message
            }
        }

        Write-Progress -Id 95 -Activity 'Deleting targeted shortcuts' -Completed
    }

    Write-Progress -Id 94 -Activity 'Removing targeted Start Menu shortcuts' -Completed
}

# Splits an uninstall command string into executable path and arguments.
function Split-UninstallString {
    param([string]$UninstallString)

    if ([string]::IsNullOrWhiteSpace($UninstallString)) {
        return $null
    }

    $trimmed = $UninstallString.Trim()
    if ($trimmed.StartsWith('"')) {
        $closingQuote = $trimmed.IndexOf('"', 1)
        if ($closingQuote -lt 1) {
            return $null
        }

        $filePath = $trimmed.Substring(1, $closingQuote - 1)
        $arguments = $trimmed.Substring($closingQuote + 1).Trim()
    } else {
        $parts = $trimmed.Split(' ', 2)
        $filePath = $parts[0]
        $arguments = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    }

    return [pscustomobject]@{
        FilePath = $filePath
        Arguments = $arguments
    }
}

# Runs a Win32 uninstall entry and normalizes silent/no-restart arguments where possible.
function Invoke-UninstallEntry {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry
    )

    $parsed = Split-UninstallString -UninstallString $Entry.UninstallString
    if (-not $parsed) {
        Add-RemovalRecord -Type 'Win32' -Name $Entry.DisplayName -Status 'Skipped' -Details 'Invalid uninstall string.'
        return
    }

    $exePath = $parsed.FilePath
    $arguments = $parsed.Arguments

    if (-not (Test-Path -Path $exePath)) {
        Add-RemovalRecord -Type 'Win32' -Name $Entry.DisplayName -Status 'Skipped' -Details ("Uninstall executable not found: {0}" -f $exePath)
        return
    }

    # Normalize MSI uninstall commands to use /X and run quietly.
    if ($exePath -match 'msiexec(\.exe)?$') {
        if ($arguments -match '/I\{') {
            $arguments = $arguments -replace '/I\{', '/X{'
        } elseif ($arguments -notmatch '/X\{') {
            $arguments = "/X $arguments"
        }

        if ($arguments -notmatch '/qn') {
            $arguments = "$arguments /qn"
        }
        if ($arguments -notmatch '/norestart') {
            $arguments = "$arguments /norestart"
        }
    } else {
        # For non-MSI installers, append quiet flags only when not already present.
        if ($arguments -notmatch '(?i)(/quiet|/qn|/s|/silent)') {
            $arguments = "$arguments /quiet"
        }
        if ($arguments -notmatch '(?i)(/norestart)') {
            $arguments = "$arguments /norestart"
        }
    }

    try {
        if ($PSCmdlet.ShouldProcess($Entry.DisplayName, 'Uninstall Win32 application')) {
            $process = Start-Process -FilePath $exePath -ArgumentList $arguments -PassThru -Wait -WindowStyle Hidden
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                Add-RemovalRecord -Type 'Win32' -Name $Entry.DisplayName -Status 'Removed' -Details ("ExitCode={0}" -f $process.ExitCode)
            } else {
                Add-RemovalRecord -Type 'Win32' -Name $Entry.DisplayName -Status 'Failed' -Details ("ExitCode={0}" -f $process.ExitCode)
            }
        }
    } catch {
        Add-RemovalRecord -Type 'Win32' -Name $Entry.DisplayName -Status 'Failed' -Details $_.Exception.Message
    }
}

# Uses Edge setup.exe to remove system-level Edge/WebView2 components.
function Uninstall-EdgeComponent {
    param(
        [string]$ComponentRoot,
        [string]$FriendlyName,
        [string]$ExtraArguments = ''
    )

    $setupPaths = @(
        (Join-Path $ComponentRoot 'Application\*\Installer\setup.exe')
    )

    $setupExe = Get-ChildItem -Path $setupPaths -File -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1

    if (-not $setupExe) {
        Add-RemovalRecord -Type 'Win32' -Name $FriendlyName -Status 'Skipped' -Details 'Setup executable not found.'
        return
    }

    $args = "--uninstall --system-level --force-uninstall --verbose-logging $ExtraArguments".Trim()
    try {
        if ($PSCmdlet.ShouldProcess($FriendlyName, 'Uninstall Edge component')) {
            $proc = Start-Process -FilePath $setupExe.FullName -ArgumentList $args -PassThru -Wait -WindowStyle Hidden
            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                Add-RemovalRecord -Type 'Win32' -Name $FriendlyName -Status 'Removed' -Details ("ExitCode={0}" -f $proc.ExitCode)
            } else {
                Add-RemovalRecord -Type 'Win32' -Name $FriendlyName -Status 'Failed' -Details ("ExitCode={0}" -f $proc.ExitCode)
            }
        }
    } catch {
        Add-RemovalRecord -Type 'Win32' -Name $FriendlyName -Status 'Failed' -Details $_.Exception.Message
    }
}

# Guardrail: this script must run as admin to remove system packages and set machine policies.
if (-not (Test-IsAdministrator)) {
    throw 'Run this script from an elevated PowerShell session (Run as Administrator).'
}

# Prepare output folder and runtime log file paths.
if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
}

$TimeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$RemovalLogPath = Join-Path $LogDirectory ("remove-bloat-results-{0}.csv" -f $TimeStamp)
$TranscriptPath = Join-Path $LogDirectory ("remove-bloat-transcript-{0}.log" -f $TimeStamp)
$script:RemovalRecords = New-Object System.Collections.Generic.List[object]
$transcriptStarted = $false

try {
    # Transcript is best-effort; the script still runs if transcript startup fails.
    Start-Transcript -Path $TranscriptPath -Force | Out-Null
    $transcriptStarted = $true
} catch {
    Write-Warn ("Could not start transcript logging: {0}" -f $_.Exception.Message)
}

try {
    Write-Info 'Starting Windows 11 debloat process.'

    # Keep list for core shell/runtime components that should not be stripped.
    $keepPackagePatterns = @(
        'Microsoft.AAD.BrokerPlugin*',
        'Microsoft.AccountsControl*',
        'Microsoft.AsyncTextService*',
        'Microsoft.BioEnrollment*',
        'Microsoft.CredDialogHost*',
        'Microsoft.ECApp*',
        'Microsoft.LockApp*',
        'Microsoft.NET.Native.Framework*',
        'Microsoft.NET.Native.Runtime*',
        'Microsoft.SecHealthUI*',
        'Microsoft.UI.Xaml*',
        'Microsoft.VCLibs*',
        'Microsoft.Windows.Apprep.ChxApp*',
        'Microsoft.Windows.CBS*',
        'Microsoft.Windows.CloudExperienceHost*',
        'Microsoft.Windows.OOBENetworkConnectionFlow*',
        'Microsoft.Windows.ShellExperienceHost*',
        'Microsoft.Windows.StartMenuExperienceHost*',
        'MicrosoftWindows.Client.CBS*',
        'windows.immersivecontrolpanel*'
    )

    # Optional: keep Store/App Installer for environments that still need package acquisition.
    if ($KeepMicrosoftStore) {
        $keepPackagePatterns += 'Microsoft.DesktopAppInstaller*'
        $keepPackagePatterns += 'Microsoft.WindowsStore*'
    }

    Write-Info 'Removing removable Appx packages from all users.'
    $installedCandidates = @(Get-AppxPackage -AllUsers |
        Where-Object {
            $_.Name -and
            $_.NonRemovable -eq $false -and
            -not (Test-WildcardMatch -Value $_.Name -Patterns $keepPackagePatterns)
        } |
        Sort-Object IsFramework, Name, PackageFullName -Unique)

    $installedTotal = [math]::Max($installedCandidates.Count, 1)
    $installedIndex = 0
    foreach ($package in $installedCandidates) {
        $installedIndex++
        $installedPercent = [int](($installedIndex / $installedTotal) * 100)
        Write-Progress -Id 10 -Activity 'Removing installed Appx packages' -Status ("[{0}/{1}] {2}" -f $installedIndex, $installedTotal, $package.Name) -PercentComplete $installedPercent
        try {
            if ($PSCmdlet.ShouldProcess($package.PackageFullName, 'Remove-AppxPackage')) {
                # Try all-users removal first; fall back to package-scoped removal if unavailable.
                try {
                    Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
                } catch {
                    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                }
                Add-RemovalRecord -Type 'AppxInstalled' -Name $package.Name -Status 'Removed' -Details $package.PackageFullName
            }
        } catch {
            Add-RemovalRecord -Type 'AppxInstalled' -Name $package.Name -Status 'Failed' -Details $_.Exception.Message
        }
    }
    Write-Progress -Id 10 -Activity 'Removing installed Appx packages' -Completed

    Write-Info 'Removing provisioned Appx packages so new users do not get them.'
    $provisionedCandidates = @(Get-AppxProvisionedPackage -Online |
        Where-Object {
            $_.DisplayName -and
            -not (Test-WildcardMatch -Value $_.DisplayName -Patterns $keepPackagePatterns)
        })

    $provisionedTotal = [math]::Max($provisionedCandidates.Count, 1)
    $provisionedIndex = 0
    foreach ($package in $provisionedCandidates) {
        $provisionedIndex++
        $provisionedPercent = [int](($provisionedIndex / $provisionedTotal) * 100)
        Write-Progress -Id 20 -Activity 'Removing provisioned Appx packages' -Status ("[{0}/{1}] {2}" -f $provisionedIndex, $provisionedTotal, $package.DisplayName) -PercentComplete $provisionedPercent
        try {
            if ($PSCmdlet.ShouldProcess($package.DisplayName, 'Remove-AppxProvisionedPackage')) {
                Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop | Out-Null
                Add-RemovalRecord -Type 'AppxProvisioned' -Name $package.DisplayName -Status 'Removed' -Details $package.PackageName
            }
        } catch {
            Add-RemovalRecord -Type 'AppxProvisioned' -Name $package.DisplayName -Status 'Failed' -Details $_.Exception.Message
        }
    }
    Write-Progress -Id 20 -Activity 'Removing provisioned Appx packages' -Completed

    Write-Info 'Force-removing Xbox and LinkedIn Appx families.'
    $targetedAppxPatterns = @(
        'Microsoft.Xbox*',
        'Microsoft.GamingApp*',
        'Microsoft.GamingServices*',
        '7EE7776C.LinkedInforWindows*',
        'Microsoft.LinkedIn*',
        '*LinkedIn*'
    )
    Remove-AppxByPattern -Patterns $targetedAppxPatterns -RecordType 'AppxTargeted'

    Write-Info 'Removing Win32 applications (Office, Outlook, Teams, OneDrive, Edge-related components).'
    $uninstallNamePatterns = @(
        '*Microsoft 365*',
        '*Microsoft Office*',
        '*Office 16 Click-to-Run*',
        '*LinkedIn*',
        '*Outlook*',
        '*Microsoft Teams*',
        '*Teams Machine-Wide Installer*',
        '*OneDrive*',
        '*Copilot*',
        '*Clipchamp*',
        '*Xbox*'
    )

    $uninstallRegistryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $registryPathTotal = [math]::Max($uninstallRegistryPaths.Count, 1)
    $registryPathIndex = 0
    $win32Entries = foreach ($path in $uninstallRegistryPaths) {
        $registryPathIndex++
        $pathPercent = [int](($registryPathIndex / $registryPathTotal) * 100)
        Write-Progress -Id 30 -Activity 'Scanning uninstall registry keys' -Status ("[{0}/{1}] {2}" -f $registryPathIndex, $registryPathTotal, $path) -PercentComplete $pathPercent
        if (Test-Path -Path $path) {
            foreach ($item in (Get-ItemProperty -Path $path -ErrorAction SilentlyContinue)) {
                $displayName = Get-SafePropertyValue -InputObject $item -Name 'DisplayName'
                $uninstallString = Get-SafePropertyValue -InputObject $item -Name 'UninstallString'
                $psChildName = Get-SafePropertyValue -InputObject $item -Name 'PSChildName'

                if (-not [string]::IsNullOrWhiteSpace([string]$displayName) -and -not [string]::IsNullOrWhiteSpace([string]$uninstallString)) {
                    [pscustomobject]@{
                        DisplayName = [string]$displayName
                        UninstallString = [string]$uninstallString
                        PSChildName = [string]$psChildName
                    }
                }
            }
        }
    }
    Write-Progress -Id 30 -Activity 'Scanning uninstall registry keys' -Completed
    $win32Entries = @($win32Entries | Sort-Object DisplayName, UninstallString -Unique)

    $win32Total = [math]::Max($win32Entries.Count, 1)
    $win32Index = 0
    foreach ($entry in $win32Entries) {
        $win32Index++
        $win32Percent = [int](($win32Index / $win32Total) * 100)
        Write-Progress -Id 31 -Activity 'Evaluating Win32 uninstall entries' -Status ("[{0}/{1}] {2}" -f $win32Index, $win32Total, $entry.DisplayName) -PercentComplete $win32Percent
        if (Test-WildcardMatch -Value $entry.DisplayName -Patterns $uninstallNamePatterns) {
            Invoke-UninstallEntry -Entry $entry
        }
    }
    Write-Progress -Id 31 -Activity 'Evaluating Win32 uninstall entries' -Completed

    Write-Info 'Attempting hard uninstall of Microsoft Edge and WebView2.'
    # Stop running processes first to reduce uninstall failures/locks.
    Get-Process -Name msedge, msedgewebview2, Widgets -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Uninstall-EdgeComponent -ComponentRoot "${env:ProgramFiles(x86)}\Microsoft\Edge" -FriendlyName 'Microsoft Edge'
    Uninstall-EdgeComponent -ComponentRoot "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView" -FriendlyName 'Microsoft Edge WebView2 Runtime' -ExtraArguments '--msedgewebview'

    Write-Info 'Disabling Edge Update services/tasks.'
    $edgeServiceNames = @('edgeupdate', 'edgeupdatem')
    $edgeServiceTotal = [math]::Max($edgeServiceNames.Count, 1)
    $edgeServiceIndex = 0
    foreach ($serviceName in $edgeServiceNames) {
        $edgeServiceIndex++
        $edgeServicePercent = [int](($edgeServiceIndex / $edgeServiceTotal) * 100)
        Write-Progress -Id 40 -Activity 'Disabling Edge update services' -Status ("[{0}/{1}] {2}" -f $edgeServiceIndex, $edgeServiceTotal, $serviceName) -PercentComplete $edgeServicePercent
        try {
            $svc = Get-Service -Name $serviceName -ErrorAction Stop
            if ($PSCmdlet.ShouldProcess($serviceName, 'Disable service')) {
                if ($svc.Status -ne 'Stopped') {
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                }
                Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                Add-RemovalRecord -Type 'Service' -Name $serviceName -Status 'Disabled' -Details ''
            }
        } catch {
            Add-RemovalRecord -Type 'Service' -Name $serviceName -Status 'Skipped' -Details $_.Exception.Message
        }
    }
    Write-Progress -Id 40 -Activity 'Disabling Edge update services' -Completed

    $edgeTaskNames = @('MicrosoftEdgeUpdateTaskMachineCore', 'MicrosoftEdgeUpdateTaskMachineUA')
    $edgeTaskTotal = [math]::Max($edgeTaskNames.Count, 1)
    $edgeTaskIndex = 0
    foreach ($taskName in $edgeTaskNames) {
        $edgeTaskIndex++
        $edgeTaskPercent = [int](($edgeTaskIndex / $edgeTaskTotal) * 100)
        Write-Progress -Id 41 -Activity 'Disabling Edge update tasks' -Status ("[{0}/{1}] {2}" -f $edgeTaskIndex, $edgeTaskTotal, $taskName) -PercentComplete $edgeTaskPercent
        try {
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
            if ($PSCmdlet.ShouldProcess($taskName, 'Disable scheduled task')) {
                Disable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
                Add-RemovalRecord -Type 'ScheduledTask' -Name $taskName -Status 'Disabled' -Details ''
            }
        } catch {
            Add-RemovalRecord -Type 'ScheduledTask' -Name $taskName -Status 'Skipped' -Details $_.Exception.Message
        }
    }
    Write-Progress -Id 41 -Activity 'Disabling Edge update tasks' -Completed

    Write-Info 'Disabling Xbox/Gaming services.'
    $xboxServiceNames = @('XblAuthManager', 'XblGameSave', 'XboxGipSvc', 'XboxNetApiSvc', 'GamingServices', 'GamingServicesNet')
    $xboxServiceTotal = [math]::Max($xboxServiceNames.Count, 1)
    $xboxServiceIndex = 0
    foreach ($serviceName in $xboxServiceNames) {
        $xboxServiceIndex++
        $xboxServicePercent = [int](($xboxServiceIndex / $xboxServiceTotal) * 100)
        Write-Progress -Id 42 -Activity 'Disabling Xbox/Gaming services' -Status ("[{0}/{1}] {2}" -f $xboxServiceIndex, $xboxServiceTotal, $serviceName) -PercentComplete $xboxServicePercent
        try {
            $svc = Get-Service -Name $serviceName -ErrorAction Stop
            if ($PSCmdlet.ShouldProcess($serviceName, 'Disable service')) {
                if ($svc.Status -ne 'Stopped') {
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                }
                Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                Add-RemovalRecord -Type 'Service' -Name $serviceName -Status 'Disabled' -Details ''
            }
        } catch {
            Add-RemovalRecord -Type 'Service' -Name $serviceName -Status 'Skipped' -Details $_.Exception.Message
        }
    }
    Write-Progress -Id 42 -Activity 'Disabling Xbox/Gaming services' -Completed

    Write-Info 'Uninstalling OneDrive.'
    $oneDriveSetupCandidates = @(
        (Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe'),
        (Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe')
    )
    $oneDriveSetup = $oneDriveSetupCandidates | Where-Object { Test-Path -Path $_ } | Select-Object -First 1
    if ($oneDriveSetup) {
        try {
            if ($PSCmdlet.ShouldProcess('OneDrive', 'Uninstall OneDrive')) {
                $proc = Start-Process -FilePath $oneDriveSetup -ArgumentList '/uninstall' -PassThru -Wait -WindowStyle Hidden
                if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                    Add-RemovalRecord -Type 'Win32' -Name 'OneDrive' -Status 'Removed' -Details ("ExitCode={0}" -f $proc.ExitCode)
                } else {
                    Add-RemovalRecord -Type 'Win32' -Name 'OneDrive' -Status 'Failed' -Details ("ExitCode={0}" -f $proc.ExitCode)
                }
            }
        } catch {
            Add-RemovalRecord -Type 'Win32' -Name 'OneDrive' -Status 'Failed' -Details $_.Exception.Message
        }
    } else {
        Add-RemovalRecord -Type 'Win32' -Name 'OneDrive' -Status 'Skipped' -Details 'OneDrive setup executable not found.'
    }

    Write-Info 'Removing optional Windows capabilities (Paint/QuickAssist/etc).'
    $capabilityPatterns = @(
        'Microsoft.Windows.MSPaint*',
        'Microsoft.Windows.Notepad*',
        'App.Support.QuickAssist*',
        'MathRecognizer*',
        'Media.WindowsMediaPlayer*',
        'Browser.InternetExplorer*'
    )

    $capabilities = @(Get-WindowsCapability -Online |
        Where-Object { $_.State -eq 'Installed' -and (Test-WildcardMatch -Value $_.Name -Patterns $capabilityPatterns) })

    $capabilityTotal = [math]::Max($capabilities.Count, 1)
    $capabilityIndex = 0
    foreach ($capability in $capabilities) {
        $capabilityIndex++
        $capabilityPercent = [int](($capabilityIndex / $capabilityTotal) * 100)
        Write-Progress -Id 50 -Activity 'Removing optional Windows capabilities' -Status ("[{0}/{1}] {2}" -f $capabilityIndex, $capabilityTotal, $capability.Name) -PercentComplete $capabilityPercent
        try {
            if ($PSCmdlet.ShouldProcess($capability.Name, 'Remove-WindowsCapability')) {
                Remove-WindowsCapability -Online -Name $capability.Name -ErrorAction Stop | Out-Null
                Add-RemovalRecord -Type 'Capability' -Name $capability.Name -Status 'Removed' -Details ''
            }
        } catch {
            Add-RemovalRecord -Type 'Capability' -Name $capability.Name -Status 'Failed' -Details $_.Exception.Message
        }
    }
    Write-Progress -Id 50 -Activity 'Removing optional Windows capabilities' -Completed

    Write-Info 'Setting policies to reduce app reinstallation and re-enablement.'
    $policySettings = @(
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
            Name = 'DisableWindowsConsumerFeatures'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
            Name = 'DisableConsumerAccountStateContent'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
            Name = 'DisableCloudOptimizedContent'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
            Name = 'DisableSoftLanding'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
            Name = 'DisableTailoredExperiencesWithDiagnosticData'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
            Name = 'DisableWindowsSpotlightFeatures'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
            Name = 'DisableThirdPartySuggestions'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
            Name = 'DisableFileSyncNGSC'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
            Name = 'TurnOffWindowsCopilot'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
            Name = 'AllowNewsAndInterests'
            Value = 0
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
            Name = 'AllowWidgetService'
            Value = 0
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
            Name = 'DisableSearchBoxSuggestions'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
            Name = 'HideRecommendedSection'
            Value = 1
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
            Name = 'AllowGameDVR'
            Value = 0
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'
            Name = 'AutoDownload'
            Value = 2
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'
            Name = 'InstallDefault'
            Value = 0
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'
            Name = 'UpdateDefault'
            Value = 0
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'
            Name = 'Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
            Value = 0
        },
        @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'
            Name = 'Update{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
            Value = 0
        }
    )

    # If Store is not being kept, explicitly block Store access via policy.
    if (-not $KeepMicrosoftStore) {
        $policySettings += @{
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'
            Name = 'RemoveWindowsStore'
            Value = 1
        }
    }

    $policyTotal = [math]::Max($policySettings.Count, 1)
    $policyIndex = 0
    foreach ($setting in $policySettings) {
        $policyIndex++
        $policyPercent = [int](($policyIndex / $policyTotal) * 100)
        Write-Progress -Id 60 -Activity 'Applying machine policies' -Status ("[{0}/{1}] {2}\\{3}" -f $policyIndex, $policyTotal, $setting.Path, $setting.Name) -PercentComplete $policyPercent
        Set-RegistryDword -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type 'Policy'
    }
    Write-Progress -Id 60 -Activity 'Applying machine policies' -Completed

    Write-Info 'Applying content-delivery restrictions for current and default users.'
    # Current user settings prevent repopulation for the account executing this script.
    Set-ContentDeliveryRestrictions -RootPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -RecordType 'UserPolicy'

    # Default profile settings make new local profiles inherit the same restrictions.
    $defaultHiveMount = 'HKU\DebloatDefaultUser'
    $defaultHiveFile = 'C:\Users\Default\NTUSER.DAT'
    $defaultHiveLoaded = $false
    if (Test-Path -Path $defaultHiveFile) {
        try {
            $loadResult = & reg.exe load $defaultHiveMount $defaultHiveFile 2>&1
            if ($LASTEXITCODE -eq 0) {
                $defaultHiveLoaded = $true
                Set-ContentDeliveryRestrictions -RootPath 'Registry::HKEY_USERS\DebloatDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -RecordType 'DefaultUserPolicy'
            } else {
                Add-RemovalRecord -Type 'DefaultUserPolicy' -Name $defaultHiveFile -Status 'Failed' -Details ($loadResult -join ' ')
            }
        } catch {
            Add-RemovalRecord -Type 'DefaultUserPolicy' -Name $defaultHiveFile -Status 'Failed' -Details $_.Exception.Message
        } finally {
            if ($defaultHiveLoaded) {
                $unloadResult = & reg.exe unload $defaultHiveMount 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Add-RemovalRecord -Type 'DefaultUserPolicy' -Name $defaultHiveMount -Status 'Failed' -Details ("Failed to unload hive: {0}" -f ($unloadResult -join ' '))
                }
            }
        }
    } else {
        Add-RemovalRecord -Type 'DefaultUserPolicy' -Name $defaultHiveFile -Status 'Skipped' -Details 'Default user hive not found.'
    }

    Write-Info 'Removing Xbox/LinkedIn Start Menu shortcuts.'
    Remove-ShortcutByPattern -Patterns @('*xbox*', '*linkedin*')
}
finally {
    # Always emit a log file, even if no removals were necessary.
    if ($script:RemovalRecords.Count -eq 0) {
        Add-RemovalRecord -Type 'Summary' -Name 'NoActions' -Status 'None' -Details 'No matching components were removed.'
    }

    $script:RemovalRecords | Export-Csv -Path $RemovalLogPath -NoTypeInformation -Encoding UTF8
    Write-Info ("Debloat complete. Results: {0}" -f $RemovalLogPath)
    Write-Info ("Transcript: {0}" -f $TranscriptPath)
    Write-Host '[INFO] Restart the machine to finalize component removal.'
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}
