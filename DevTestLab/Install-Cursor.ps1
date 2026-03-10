# Install-Cursor.ps1

$ErrorActionPreference = "Stop"

try {
    Write-Host "Downloading Cursor installer..."

    $uri  = "https://cursor.com/install?win32=true"
    $file = "$env:TEMP\cursor-install.ps1"

    Invoke-RestMethod -Uri $uri -OutFile $file

    Write-Host "Download complete. Running installer..."

    & powershell.exe -ExecutionPolicy Bypass -File $file

    Write-Host "Installation script executed successfully."
}
catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
}
finally {
    if (Test-Path $file) {
        Remove-Item $file -Force
    }
}
