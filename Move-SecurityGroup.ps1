
[string]$GroupName = "Agile-Users"
$TempGroupName = $GroupName + "_1"

$GroupCount = (Get-DistributionGroupMember $GroupName -ResultSize Unlimited | measure).count
$GCount = (Get-DistributionGroupMember $TempGroupName -ResultSize Unlimited | measure).count


If((Get-DistributionGroup ag-Coriant-Tellabs-Global-emp)){
"No need to create a temp Distro. It already is existing"
}

Else{
New-DistributionGroup -Name $TempGroupName
}


#$Identities = Get-DistributionGroupMember -Identity $GroupName -ResultSize Unlimited | select Name 
$Identities = Import-Csv -Path .\Agile-Users_lacking.csv


foreach($names in $identities.Name){
$try = 0
    do{
    Add-DistributionGroupMember -Identity $TempGroupName -Member $names
    $try += 1
    }
    while ((Get-DistributionGroupMember -Identity $TempGroupName -ResultSize Unlimited | ? {$_.Name -eq $names}) -eq $null -and ($try -le 2))
    $GCount +=1
    $names + ".... " + $GCount + "/" + $GroupCount + " Done!"
 }

"Number of Members in " + $Groupname + ": " + (Get-DistributionGroupMember $GroupName -ResultSize Unlimited | measure).count
"Number of Members in " + $TempGroupName + ": " + (Get-DistributionGroupMember $TempGroupName -ResultSize Unlimited | measure).count