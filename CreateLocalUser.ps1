param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$PlainPassword
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Msg) { Write-Host "[INFO]  $Msg" }
function Write-Warn([string]$Msg) { Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Err ([string]$Msg) { Write-Host "[ERROR] $Msg" -ForegroundColor Red }

try {
    # Convert username to proper Full Name
    # Replace '.' with space, lowercase everything, then Title Case
    $nameWithSpaces = ($Username -replace '\.', ' ').ToLower()
    $textInfo = (Get-Culture).TextInfo
    $FullName = $textInfo.ToTitleCase($nameWithSpaces)

    # Check if user exists
    $existingUser = $null
    try {
        $existingUser = Get-LocalUser -Name $Username -ErrorAction Stop
    } catch {
        $existingUser = $null
    }

    if ($null -ne $existingUser) {
        Write-Info "Local user '$Username' already exists. Skipping creation."

        # Ensure RDP access
        try {
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction Stop
            Write-Info "Ensured '$Username' is in 'Remote Desktop Users'."
        } catch {
            if ($_.Exception.Message -match "already a member") {
                Write-Info "'$Username' is already in 'Remote Desktop Users'."
            } else {
                throw
            }
        }

        return
    }

    # Convert password
    $securePassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force

    # Create user
    New-LocalUser `
        -Name $Username `
        -Password $securePassword `
        -FullName $FullName `
        -Description "Main regular user for this VM" `
        -PasswordNeverExpires:$true `
        -AccountNeverExpires:$true | Out-Null

    Write-Info "Created local user '$Username' (FullName: '$FullName')."

    # Add to RDP group
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username
    Write-Info "Added '$Username' to 'Remote Desktop Users' (RDP enabled)."

    Write-Info "Done."
}
catch {
    Write-Err $_.Exception.Message
    Write-Warn "If this failed on password complexity, try a stronger password."
    exit 1
}
