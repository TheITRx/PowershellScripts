Function Get-DistributionGroupMemberOf {
    
    [cmdletbinding()]
    Param(
    [parameter(mandatory=$true)]
    $Identity
    )

    $holder = @()

    write-verbose "Scanning for groups that $Identity is a member of. This may take a couple of minutes depending on the number of Groups. "
    Get-DistributionGroup -ResultSize Unlimited | % {

        Write-Verbose "Checking on $_"
        [array]$members = Get-DistributionGroupMember $_.Name -ResultSize Unlimited

         if($members.name.Contains($Identity)){
            $holder += $_
         }   
    }

    Write-Output $holder

}



