Function Convert-HashString() {
    <#
    .SYNOPSIS
        Encrypts or decrypts a string to a file.
    .DESCRIPTION
        Encrypts a string and exports it to a file.
        Decrypts the encrypted string from a file and returns it in clear text
        Good for  writing scripts and you want the API keys or any string you want encrypted
            be written to a file for future use.
    .EXAMPLE
        This command exports a string you input to c:\temp\App-ID.txt. If the file is existing,
            it will decrypt it and returns it in clear text
        Convert-HashString -Path c:\temp\App-ID.txt
        
        This command overwrites any existing file. 
        Convert-HashString -Path c:\temp\app-id.txt -Overwrite
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        First Edit: 05.08.19
    #>
    param(
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter()]
        [switch]$Overwrite
    )
    if ($Overwrite) {
        Read-Host "Enter the string you want hashed to $($Path)" -AsSecureString | ConvertFrom-SecureString | Out-File $Path
        $HashedFile = $Path
    }
    else { 
        if (!(Test-Path $Path)) {
            Read-Host "Enter the string you want hashed to $($Path)" -AsSecureString | ConvertFrom-SecureString | Out-File $Path
            $HashedFile = $Path
        }
        else {
            $HashedFile = $Path
        }
    }
    $HashedFile = Get-Content $Path | ConvertTo-SecureString
    $BinString = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($HashedFile)
    $ClearString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BinString)
    return $ClearString
}
