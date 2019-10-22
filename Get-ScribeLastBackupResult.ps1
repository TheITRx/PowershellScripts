<#
.SYNOPSIS
    generate Scribe backup report
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

$OrgID = ""
$SolutionID = ""

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

$API_PW = Export-HashedString .\ScribeAPI_PW.txt

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "scribe@invenergyllc.com", $API_PW)))

$CRMBackupHistory = Invoke-RestMethod -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo)} -Uri "https://api.scribesoft.com/v1/orgs/$orgid/solutions/$solutionid/history" | select -last 10

$Lastresult = $CRMBackupHistory | select -Last 1

if ($Lastresult.result -eq "CompletedWithErrors") {

    $LastResInfo = Invoke-RestMethod -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo)} -Uri "https://api.scribesoft.com/v1/orgs/$orgid/solutions/$solutionID/history/$($Lastresult.ID)/errors"

    $LastResObj = [Ordered]@{

        "Start"        = $Lastresult.start
        "Stop"         = $Lastresult.Stop
        "Result"       = $Lastresult.Result
        "errorDetail"   = $LastResInfo.errorDetail
        "SourceEntity" = $LastResInfo.sourceEntity
        "ErrorMessage" = $LastResInfo.ErrorMessage
    }
    $Result = New-Object -TypeName PSobject -Property $LastResObj
}

else {

    $LastResObj = [Ordered]@{

            "Start"        = $Lastresult.start
            "Stop"         = $Lastresult.Stop
            "Result"       = $Lastresult.Result
        }
        $Result = New-Object -TypeName PSobject -Property $LastResObj
}

$ScribeResult = $Result


























