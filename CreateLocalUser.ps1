[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$PlainPassword
)

$ErrorActionPreference = "Stop"

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
        Write-Verbose "Local user '$Username' already exists. Skipping creation."

        # Ensure RDP access
        try {
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction Stop
            Write-Verbose "Ensured '$Username' is in 'Remote Desktop Users'."
        } catch {
            if ($_.Exception.Message -match "already a member") {
                Write-Verbose "'$Username' is already in 'Remote Desktop Users'."
            } else {
                throw
            }
        }

        return
    }

    # Convert password
    Write-Verbose "Setting password for '$Username' to '$PlainPassword'."
    $securePassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force

    # Create user
    New-LocalUser `
        -Name $Username `
        -Password $securePassword `
        -FullName $FullName `
        -Description "Main regular user for this VM" `
        -PasswordNeverExpires:$true `
        -AccountNeverExpires:$true | Out-Null

    Write-Verbose "Created local user '$Username' (FullName: '$FullName')."

    # Require password change on first login
    #net user $Username /logonpasswordchg:yes | Out-Null
    #Write-Verbose "Set '$Username' to change password on first login."

    # Add to RDP group
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username
    Write-Verbose "Added '$Username' to 'Remote Desktop Users' (RDP enabled)."

    Write-Verbose "Done."
}
catch {
    Write-Verbose $_.Exception.Message
    Write-Verbose "If this failed on password complexity, try a stronger password."
    exit 1
}
