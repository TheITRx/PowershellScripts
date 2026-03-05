param (
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$PlainPassword,

    [switch]$AddToAdministrators
)

# Convert password to SecureString
$SecurePassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force

# Create the local user
New-LocalUser `
    -Name $Username `
    -Password $SecurePassword `
    -FullName $Username `
    -Description "Main regular user for this VM" `
    -PasswordNeverExpires:$true

Write-Host "User $Username created successfully."

# Add to Administrators group if requested
if ($AddToAdministrators) {
    Add-LocalGroupMember -Group "Administrators" -Member $Username
    Write-Host "User $Username added to Administrators group."
}
