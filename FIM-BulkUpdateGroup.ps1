PARAM($GroupName, $ImportCSV, $Delimiter = ";", $LogFilePath)
 
 
if(@(get-pssnapin | where-object {$_.Name -eq "FIMAutomation"} ).count -eq 0) {add-pssnapin FIMAutomation}
$ProgressPreference="SilentlyContinue"
 
 
###
### FIM-BulkUpdateGroup.ps1
###
### Add or remove users from a Portal Group.
###
### USAGE: .\FIM-BulkUpdateGroup.ps1 -GroupName <GroupName> -ImportCSV "<UsersImportFilePath>" [-Delimiter <Delimiter>] [-LogFilePath <LogFile>]
###
###
### Note: Run on FIM Service Server (usalsdur003.corp.duracell.com)
###
###
### Parameters:     GroupName             Display Name or Account ame of group to update
###                 UsersImportFilePath   FileName to import CSV File (see below for format)
###                 Delimiter (optional)  Delimiter used in CSV file. Default to semicolon (;), but may also be comma (,)
###                 LogFile (optional)    If specified, logs are appended to the specified text file
###
### CSV Format:     Header Row            Two columns - "ChangeType;Identifier"
###                 ChangeType            Either "Add" or "Remove"
###                 Identifier            Display Name, Account Name or EMail address of user to add/remove from the group
###
### Additional Notes: The script will not process users if more than one match is found for any Identifier.
###
### Sample CSV:
### ChangeType;Identifier
### Add;"BulkUpload01, Test"
### Add;"BulkUpload02, Test"
### Add;"BulkUpload03, Test"
### Remove;"BulkUpload04, Test"
### Remove;"BulkUpload05, Test"
 
 
$FIMSvcURI = "http://fimservice:5725/ResourceManagementService"
 
 
$GroupIdentifiers = @("AccountName", "DisplayName")
$PersonIdentifiers = @("AccountName", "DisplayName", "Email")
 
 
$LogToFile = $LogFilePath -ne $null;
$ImportOperation = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportOperation]
 
 
Function GetSingleResource
{
    Param($Filter)
    End
    {
        $exportResource = export-fimconfig -uri $FIMSvcURI –onlyBaseResources -customconfig ("$Filter") -ErrorVariable error -ErrorAction SilentlyContinue
        If($error){Throw $error}
        If($exportResource -eq $null) {Throw "Resource not found: $Filter"}
        If(@($exportResource).Count -ne 1) {Throw "More than one resource found: $Filter"}
        $exportResource
    }
}
 
 
Function GetFilterString
{
    Param($ObjectClass, $IdentifierCollection, $SearchValue)
    End
    {
        $filterExpressions = new-object system.collections.arraylist;
         
        foreach ($identifier in $IdentifierCollection)
        {
            $filterExpression = "{0}=""{1}""" -f $identifier,$SearchValue;
            $filterExpressions.Add($filterExpression) > null;

            if ([array]::IndexOf($IdentifierCollection,$identifier) -lt $IdentifierCollection.Count - 1) {
                $filterExpression = " or " 
                $filterExpressions.Add($filterExpression) > null;
            }
        }
         
        "/{0}[{1}]" -f $ObjectClass, [String]$filterExpressions;
    }
}
 
 
Function LogOutput
{
    Param($Message)
    End
    {
        Write-Host $Message;
        if ($LogToFile)
        {
            Add-Content $LogFilePath ((Get-Date).ToString() + " - " + $Message);
        }
    }
}
 
 
## Check Args
if (-not $GroupName)                        {    Write-Host "Must Specify a 'GroupName' value of the group to be updated corresponding to the groups Display Name or Account Name";    exit 1;    }
if (-not $ImportCSV)                        {    Write-Host "Must Specify an 'ImportCSV' file name of users to be processed";    exit 1;    }
 
 
## Load CSV Data
$csvData = Get-Content $ImportCSV | ConvertFrom-Csv -Delimiter $Delimiter
if (-not $csvData)
{
    LogOutput -Message "No users in import CSV file. Exiting";
    exit 1;
}
 
 
## Load Group
$groupFilter = GetFilterString -ObjectClass "Group" -IdentifierCollection $GroupIdentifiers -SearchValue $GroupName;
$groupObject = GetSingleResource -Filter $groupFilter;
 
 
LogOutput -Message ("Successfully found Group with Display Name = '{0}'" -f $GroupName);
LogOutput -Message "Preparing to process user list";
 
 
foreach ($csvEntry in $csvData)
{
    $userObject = $null;
    Try
    {
        $userFilter = GetFilterString -ObjectClass "Person" -IdentifierCollection $PersonIdentifiers -SearchValue $csvEntry.Identifier
        $userObject = GetSingleResource -Filter $userFilter
    }
    Catch
    {
        LogOutput -Message ("Failed to locate an IAM Portal record for '{0}', or more than one entry was found" -f $csvEntry.Identifier);
        Continue;
    }
    Finally
    {
    }
       
    $Operation = $null;
    switch ($csvEntry.ChangeType)
    {
        "Add"      { $Operation = $ImportOperation::Add; }
        "Remove"   { $Operation = $ImportOperation::Delete; }
        Default   
        {
            LogOutput -Message ("Invalid ChangeType for record '{0}'. ChangeType must be either 'Add' or 'Remove'." -f $csvEntry.Identifier);
            Continue;
        }               
    }
 
    $importChange = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportChange;
    $importChange.Operation      = $Operation;
    $importChange.AttributeName  = "ExplicitMember";
    $importChange.AttributeValue = $userObject.ResourceManagementObject.ObjectIdentifier;
    $importChange.FullyResolved  = 0;
    $importChange.Locale         = "Invariant";
  
    $importObject                        = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportObject;
    $importObject.ObjectType             = "Group";
    $importObject.TargetObjectIdentifier = $groupObject.ResourceManagementObject.ObjectIdentifier;
    $importObject.SourceObjectIdentifier = $groupObject.ResourceManagementObject.ObjectIdentifier;
    $importObject.State                  = 1 ;
    $ImportObject.Changes                = (,$ImportChange);
    
    $importObject | Import-FIMConfig -Uri $FIMSvcURI  -ErrorVariable Err -ErrorAction SilentlyContinue | Out-Null;
    If($Err)
    {
        LogOutput -Message ("Failed to update group '{0}' in the IAM Portal to include the user '{1}'" -f $GroupName, $csvEntry.Identifier);
    }
    else
    {
        if ($Operation -eq $ImportOperation::Add)
        {
            LogOutput -Message ("Successfully added to group '{0}' in the IAM Portal the user '{1}'" -f $GroupName, $csvEntry.Identifier);
        }
        else
        {
            LogOutput -Message ("Successfully removed from group '{0}' in the IAM Portal the user '{1}'" -f $GroupName, $csvEntry.Identifier);
        }
    }
}

