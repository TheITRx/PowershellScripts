<#
.SYNOPSIS
    Storage craft DRAAS Report
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

# Test Variables
$user = $storagecraftcloudusername
$password = $storagecraftcloudpassword

# Prod variables
#$user = $env:storagecraftcloudusername
#$password = $env:storagecraftcloudpassword

$SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $User, $SecurePassword
$InvokeResult = Invoke-RestMethod -Method GEt -Uri "https://api-slc.storagecraft.com:8888/api/v1/machines/" -Credential $cred

$pagenum = 1
$ResObj = @()
While ($null -ne $InvokeResult.next) {

    $InvokeResult = Invoke-RestMethod -Method GEt -Uri "https://api-slc.storagecraft.com:8888/api/v1/machines/?page=$($pagenum)" -Credential $cred
    $pagenum++
    $InvokeResult.results | ? { $_.machine_Name -ne "Unknown" } | % {
        
        $ResObj += [PSCustomObject]@{ 
    
            "MachineName"         = $_.Machine_Name
            "LastREplicationTime" = [DateTime]$_.last_rp_time
            "Created"             = [DateTime]$_.Created
            "Updated"             = [DateTime]$_.Updated
        }
    
    }    
}  
$ResObj | Sort-Object LastREplicationTime -Descending
