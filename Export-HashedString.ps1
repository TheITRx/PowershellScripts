<#
.SYNOPSIS
    Encrypts a string and export it to a file
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
Function Export-HashedString($Path) {

    if (!(Test-Path $Path)) {

        Read-Host "Enter the string you want hashed:" -AsSecureString |  ConvertFrom-SecureString | Out-File $Path
        $HashedFile = $Path
    }
    else {

        $HashedFile = $Path
    }
    $HashedFile = Get-Content $Path | ConvertTo-SecureString
    $BinString = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($HashedFile)
    $ClearString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BinString)
    return $ClearString
}

Export-HashedString -Path .\Jocel_PW1.txt