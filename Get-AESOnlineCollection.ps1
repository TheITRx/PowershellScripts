#Requires -Version 4

<#
	.SYNOPSIS
		Collection for Office 365 AES

	.DESCRIPTION
        Capture script for collecting information from Office 365 Tenancy for Office 365 SOA

        This script is Intellectual Property of Microsoft.
    
    .PARAMETER OutputDir
        Specified the directory where to store the collection resulsts, this directory is used by
        the analysis script.
    
    .PARAMETER GetCalendarSharing
        Switch for retrieving calendar sharing information. This may be possible in smaller tenancies,
        but for time constraints, this defaults to off.
    
    .PARAMETER Connect
        Specifying this parameter will make the script automatically connect to Azure AD Version 1 (MSOL)
        Azure AD Version 2, and Exchange Online MFA Remote PowerShell. Script will ask for credentials for each
        as multifactor authentication is required.

    .PARAMETER ConnectNoMFA
        Specifying this parameter will make the script automatically connect to Azure AD Version 1 (MSOL)
        Azure AD Version 2, and Exchange Online MFA Remote PowerShell. Script will obtain credentials and
        auto-connect as there is no MFA to be used.

    .PARAMETER PrecollectComplete
        In instances where the script is ran multiple times, it may be required to prevent the script from
        re-running the Get-Mailbox and Get-CasMailbox commands (for time savings). This will prevent the re-running
        of the pre-collect function, but may result in the data set being old.

    .PARAMETER NoEXO
        Skips the Exchnage Online collectors. Used only for script debugging.

    .PARAMETER NoSPO
        Skips the SharePoint Online collectors. While generally used for script debugging, it can also be used
        in cases where SharePoint Online is not being used.

    .PARAMETER NoPnP
        Skips  SharePoint Online collectors that rely on the Patterns and Practices (PnP) library. This can be used if
        the PnP library is causing connection problems.

    .PARAMETER SPOAdmin
        The UPN of the user whose credentials are being used to run the script. This is used to temporaily grant the user
        access to SharePoint Online content in order to collect the necessariy configuration data.
        
    .PARAMETER SiteCollectionLimit
        The maxium number of SharePoint site collections to interrogate. Collecting configuration information from site
        collections is expensive and time consuming. The script will limit itself to 50 site collections by default. Less
        or more site collections can be included in the collection by adjusting this value. By setting SiteCollectionLimit
        to 0, all site collections will be examined.

    .PARAMETER SPOTenantName
        The name of the SharePoint Online tenant to use when deriving SPO host names.

    .PARAMETER SPOPermissionOptIn
        Skips SharePoint Online collectors that need to temporarily make the nominated SPOAdmin user a Site Collection
        Administrator on site collections being analysed.

	.NOTES
		Cam Murray
		Field Engineer - Microsoft
		cam.murray@microsoft.com

		Andres Canello
		Field Engineer - Microsoft
		andresc@microsoft.com
		
		Last update: 5 October 2017

	.LINK
		about_functions_advanced

#>

Param(
    [CmdletBinding()]
    [Parameter(Mandatory=$false)]
    [String]$OutputDir,
    [Switch]$GetCalendarSharing,
    [Switch]$Connect,
    [Switch]$ConnectNoMFA,
    [Switch]$PrecollectComplete,
    [Switch]$PrecollectOnlyEXO1,
    [Switch]$PrecollectOnlyEXO2,
    [Switch]$PrecollectOnlyAAD,
    [Switch]$BypassPrereqCheck,
    [Int32]$PrecollectLimit=0,
    [Switch]$NoEXO,
    [Switch]$NoSPO,
    [Switch]$NoPnP,
    [String]$SPOAdmin,
    [Switch]$GetSecureScore,
    [Int32]$SiteCollectionLimit=250,
    [String]$SPOTenantName,
    [Switch]$SPOPermissionOptIn
)

#region Functions

function Get-RoleMembers365 {
    $365RoleMembers = @()

    ForEach($rg in (Get-MsolRole)) {
	    ForEach($rgm in (Get-MsolRoleMember -RoleObjectId $rg.ObjectId)) {
		    $365RoleMembers += New-Object -TypeName psobject -Property @{
			    Role=$($rg.Name)
			    Member=$($rgm.EmailAddress)
			    MFARequirements=$($rgm.StrongAuthenticationRequirements.State)
        	    }
	    }
    }

    return $365RoleMembers

}

function Get-AzureSKUs {

    # Gets the Azure SKU's (Licenses)
    $skus = @()

    ForEach($sku in (Get-AzureADSubscribedSku)) {
        $skus += New-Object -TypeName psobject -Property @{
            SkuPartNumber=$($sku.SkuPartNumber)
            Consumed=$($sku.ConsumedUnits)
            Enabled=$($sku.PrepaidUnits.Enabled)
            Suspended=$($sku.PrepaidUnits.Suspended)
            Warning=$($sku.PrepaidUnits.Warning)   
        }
    }

    return $skus
}

function Get-RoleMembersEXO {
    $EXORoleMembers = @()

    ForEach($rg in (Get-RoleGroup)) {
                  ForEach($rgm in (Get-RoleGroupMember -Identity $rg.Identity)) {
                               $EXORoleMembers += New-Object -TypeName psobject -Property @{
                                             Role=$($rg.Identity)
                                             Member=$($rgm.Name)
                                             Type=$($rgm.RecipientType)
                  }
                  }
    }

    Return $EXORoleMembers
}

function Get-ProtocolEnablement {
    Param(
    [System.Array]$CASMailboxes
    )

    return New-Object psobject -Property @{
        ActiveSync=($CASMailboxes | Where-Object {$_.ActiveSyncEnabled -eq "True"}).Count
        OWA=($CASMailboxes | Where-Object {$_.OWAEnabled -eq "True"}).Count
        POP=($CASMailboxes | Where-Object {$_.PopEnabled -eq "True"}).Count
        IMAP=($CASMailboxes | Where-Object {$_.ImapEnabled -eq "True"}).Count
        MAPI=($CASMailboxes | Where-Object {$_.MapiEnabled -eq "True"}).Count
        UniversalOutlook=($CASMailboxes | Where-Object {$_.UniversalOutlookEnabled -eq "True"}).Count
        EWS=($CASMailboxes | Where-Object {$_.EWSEnabled -eq "True"}).Count
        EWSOutlook=($CASMailboxes | Where-Object {$_.EWSAlloutOutlook -eq "True"}).Count
        EWSMacOutlook=($CASMailboxes | Where-Object {$_.EwsAllowMacOutlook -eq "True"}).Count
        EWSEntourage=($CASMailboxes | Where-Object {$_.EwsAllowEntourage -eq "True"}).Count
        Total=$CASMailboxes.Count
    }

}

function Get-MailboxAuditSettings {
    Param(
    [System.Array]$Mailboxes
    )

    $MailboxLogin = 0

    ForEach($mb in $Mailboxes) {
        #Since moving to 
        if($mb.AuditOwner -like "*MailboxLogin*") {$MailboxLogin++}
    }

    Return New-Object PsObject -Property @{
        Total=$Mailboxes.Count
        AuditEnabled=($Mailboxes | Where-Object {$_.AuditEnabled -eq $true}).Count
        AuditOwnerLogin=$MailboxLogin
    }
}

function Get-CalendarSharing {
    Param(
        [System.Array]$Mailboxes
    )
    ForEach($mailbox in $Mailboxes) {

    Write-Verbose "Checking $($mailbox.Identity)"

    # Get users calendar folder settings for their default Calendar folder

    $cf=Get-MailboxCalendarFolder -Identity "$($mailbox.Identity):\Calendar" 

    # If publishing is turned on, add to the result set

    if($cf.PublishEnabled -eq $true) {

        $cfs += New-Object -TypeName psobject -Property @{

            UserPrincipalName=$mailbox.UserPrincipalName
            PublishEnabled=$cf.PublishEnabled
            DetailLevel=$cf.DetailLevel
            PublishedCalendarUrl=$cf.PublishedCalendarUrl
            PublishedICalUrl=$cf.PublishedICalUrl

        }

    }

    }

    return $cfs
}

function Get-RoleAssignmentPoliciesAndEntries {

    $return = @()

    ForEach($ra in (Get-RoleAssignmentPolicy)) {

        $re = @()

        ForEach($role in $ra.AssignedRoles) {
            $re += (Get-ManagementRoleEntry "$role\*")
        }

        $return += New-Object psobject -Property @{
            Name=$($ra.Name)
            IsDefault=$($ra.IsDefault)
            Description=$($ra.Description)
            RoleAssignments=$($ra.RoleAssignments)
            AssignedRoles=$($ra.AssignedRoles)
            RoleEntries=$re
        } 
    }

    return $return

}

function Get-MailboxForwardDomains  {
    Param(
    [System.Array]$Mailboxes
    )

    $return = @()

    $AutoFMailboxes = $Mailboxes | Where-Object {$_.ForwardingSmtpAddress -ne $null}

    ForEach($AutoF in $AutoFMailboxes) {

        $return += New-Object psobject -Property @{
            Domain=$AutoF.ForwardingSmtpAddress.Split("@")[1]
        } 
    }

    return $return

}

function Get-AUserSummary {
    Param(
        [System.Array]$AUsers
    )

    $MFA_Enforced = 0
    $MFA_Enabled = 0
    $PW_GT30 = 0
    $PW_GT182 = 0
    $PW_GT365 = 0

    $CurrentDate = Get-Date

    ForEach($a in $AUsers) {
        if($a.StrongAuthenticationRequirements.State -eq "Enabled") {
            $MFA_Enabled++
        }
        if($a.StrongAuthenticationRequirements.State -eq "Enforced") {
            $MFA_Enforced++
        }
        if(($CurrentDate - $a.LastPasswordChangeTimestamp).Days -gt 30) {
            $PW_GT30++
        }
        if(($CurrentDate - $a.LastPasswordChangeTimestamp).Days -gt 182) {
            $PW_GT182++
        }
        if(($CurrentDate - $a.LastPasswordChangeTimestamp).Days -gt 365) {
            $PW_GT365++
        }
    }

    Return New-Object PSObject -Property @{
        Count=$($AUsers.Count)
        MFAEnforced=$($MFA_Enforced)
        MFAEnabled=$($MFA_Enabled)
        PWGT30=$PW_GT30
        PWGT182=$PW_GT182
        PWGT365=$PW_GT365
    }

}

function Get-SPOTenantName
{
    if ($SPOTenantName)
    {
        return $SPOTenantName
    }
    else {
        $sku = (Get-MsolAccountSku)[0]
        return $sku.AccountName
    }
}
function Get-SharePointAdminUrl
{
    $tenantName = Get-SPOTenantName
    
    $url = "https://" + $tenantName + "-admin.sharepoint.com"
    return $url
}

function Get-SharePointDefaultUrl
{
    $tenantName = Get-SPOTenantName

    $url = "https://" + $tenantName + ".sharepoint.com"
    return $url
}

function Get-PnPConnection
{
    Param(
        [Parameter(Mandatory=$True)]
        [string]$Url
    )

    if ($ConnectNoMFA)
    {
        Connect-PnPOnline -Url $Url -Credentials $SPOCredential
    }
    else {
        Connect-PnPOnline -Url $Url -UseWebLogin
    }
}

function Get-SPOTenantProperties
{
    $return = Get-SPOTenant
    
    return $return
}

Add-Type -TypeDefinition @"
   public enum SiteCollectionAdminState
   {
        Needed,
        NotNeeded,
        Skip
   }
"@

function Grant-SiteCollectionAdmin
{
    Param(
        [Parameter(Mandatory=$True)]
        [Microsoft.Online.SharePoint.PowerShell.SPOSite]$Site
    )

    [SiteCollectionAdminState]$adminState = [SiteCollectionAdminState]::NotNeeded

    # Determine if admin rights need to be granted
    try {
        $adminUser = Get-SPOUser -site $Site -LoginName $SPOAdmin
        $needsAdmin = ($false -eq $adminUser.IsSiteAdmin)
    }
    catch {
        $needsAdmin = $true
    }

    # Skip this site collection if the current user does not have permissions and
    # permission changes should not be made ($SPOPermissionOptOut)
    if ($needsAdmin -and $SPOPermissionOptIn -eq $false)
    {
        Write-Verbose "$(Get-Date) Grant-SiteCollectionAdmin Skipping $($Site.URL) Needs Admin $needsAdmin PermissionOptIn $SPOPermissionOptIn"
        [SiteCollectionAdminState]$adminState = [SiteCollectionAdminState]::Skip
    }
    # Grant access to the site collection, if required
    elseif ($needsAdmin)
    {
        Write-Verbose "$(Get-Date) Grant-SiteCollectionAdmin Adding $($SPOAdmin) $($Site.URL) Needs Admin $needsAdmin PermissionOptIn $SPOPermissionOptIn"
        Set-SPOUser -site $Site -LoginName $SPOAdmin -IsSiteCollectionAdmin $True | Out-Null

        # Workaround for a race condition that has PnP connect to SPO before the permission access is committed
        Start-Sleep -Seconds 1

        [SiteCollectionAdminState]$adminState = [SiteCollectionAdminState]::Needed
    }

    return $adminState
}

function Revoke-SiteCollectionAdmin
{
    Param(
        [Parameter(Mandatory=$True)]
        [Microsoft.Online.SharePoint.PowerShell.SPOSite]$Site,
        [Parameter(Mandatory=$True)]
        [SiteCollectionAdminState]$AdminState
    )

    # Cleanup permission changes, if any
    if ($AdminState -eq [SiteCollectionAdminState]::Needed)
    {
        Set-SPOUser -site $Site -LoginName $SPOAdmin -IsSiteCollectionAdmin $False | Out-Null
    }
}

function Get-SPOPersonalSiteProperties {

    $return = @()

    # Get all Site Collections, including personal sites
    Write-Verbose "$(Get-Date) Getting SPO Sites with Personal Sites"
    $sites = Get-SPOSite -Limit ALL -IncludePersonalSite:$true
    Write-Verbose "$(Get-Date) Getting SPO Sites Complete. Count $($sites.count)"

    # Isolate the personal sites
    $personalSites = $sites | Where-Object { $_.Url -match '/personal'}

    # Determine the number of site collections to iterate
    $maxSites = $personalSites.Count
    if (($maxSites -gt $siteCollectionLimit) -and ($siteCollectionLimit -ne 0))
    { 
        $maxSites = $siteCollectionLimit 
    }

    # Process each site collection
    for ($i=0; $i -lt $maxSites; $i++)
    {
        $site = $personalSites[$i]

        Write-Verbose "Processing $($site.Url)"

        # Grant access to the site collection, if needed AND allowed
        [SiteCollectionAdminState]$adminState = Grant-SiteCollectionAdmin -Site $site

        # Skip this site collection if permission is not granted
        if ($adminState -eq [SiteCollectionAdminState]::Skip)
        {
            continue
        }

        # Locate the OD4B library
        $list = $null
        $enableVersioning = "Unknown"
        if ($false -eq $NoPnP)
        {
            Get-PnPConnection -Url $site.Url
            $list = Get-PnPList 'Documents'
        }

        # Collect the versioning status
        if ($list)
        {
            $enableVersioning = $list.EnableVersioning
        }

        $return += New-Object psobject -Property @{
            Url=$($site.Url)
            EnableVersioning=$($enableVersioning)
        } 

        # Cleanup permission changes, if any
        Revoke-SiteCollectionAdmin -Site $site -AdminState $adminState
    }

    return $return
}

function Get-SPOSiteCollectionProperties {

    $return = @()

    # Get all Site Collections, excluding personal sites
    Write-Verbose "$(Get-Date) Getting SPO Sites without Personal Sites"
    $sites = Get-SPOSite -Limit ALL
    Write-Verbose "$(Get-Date) Getting SPO Sites Complete. Count $($sites.count)"

    # Determine the number of site collections to iterate
    $maxSites = $sites.Count
    if (($maxSites -gt $siteCollectionLimit) -and ($siteCollectionLimit -ne 0))
    { 
        $maxSites = $siteCollectionLimit 
    }

    # Process each site collection
    for ($i=0; $i -lt $maxSites; $i++)
    {
        $site = $sites[$i]

        Write-Verbose "$(Get-Date) Processing $($site.Url)"
        # Grant permission to the site collection, if needed AND allowed
        [SiteCollectionAdminState]$adminState = Grant-SiteCollectionAdmin -Site $site

        # Skip this site collection if permission is not granted
        if ($adminState -eq [SiteCollectionAdminState]::Skip)
        {
            continue
        }

        # Count the admins
        $siteAdmins = Get-SPOUser -Site $site -Limit ALL | Where-Object { $_.IsSiteAdmin -eq $true}

        $return += New-Object psobject -Property @{
            Url=$($site.Url)
            AdminCount=$($siteAdmins.Count)
        } 

        # Cleanup permission changes, if any
        Revoke-SiteCollectionAdmin -Site $site -AdminState $adminState
    }

    return $return
}

#endregion

#region Start

if(!$OutputDir) {
    # Use default output directory
    $OutputDir = $PSScriptRoot + "\Collection\"
    if(!(Test-Path($OutputDir))) { 
        try { md $OutputDir  -ErrorAction:Stop | Out-Null } catch { Write-Error "Cannot create output directory $OutputDir"; exit; }
    }
} else {
    if(!(Test-Path($OutputDir))) {
        Write-Error "Output directory $OutputDir does not exist and must be created first"; exit;
    }
}

Start-Transcript -Path "$OutputDir\Collection-Transcript.txt" -Append


#region ModuleCheck
Function Check-ModuleExists {
    Param($ModuleName)
    If(!(Get-Module -ListAvailable | Where-Object {$_.Name -eq $ModuleName})) {
        Write-Error "Required Module $($ModuleName) does not appear to be installed. Ensure pre-requisites are followed."
        return $false
    } else {
        return $true
    }
}

# Show options
Write-Host "$(Get-Date) Collection Options..."
Write-Host ""
Write-Host "Collection Directory: $($OutputDir)" -ForegroundColor Green
Write-Host "SharePoint:  $(if(!$NoSPO) { "Yes" } else { "No"} )"  -ForegroundColor Green
Write-Host "SharePoint PnP:  $(if(!$NoPnP) { "Yes" } else { "No"} )"  -ForegroundColor Green
Write-Host "Exchange:  $(if(!$NoEXO) { "Yes" } else { "No"} )"  -ForegroundColor Green
Write-Host "SharePoint Site Collection Limit: $($SiteCollectionLimit)"  -ForegroundColor Green
Write-Host "SharePoint Permissions Opt-In: $($SPOPermissionOptIn)" -ForegroundColor Green
Write-Host "SharePoint Admin: $($SPOAdmin)"  -ForegroundColor Green
Write-Host "SharePoint Tenant (Auto if blank): $($SPOTenantName)"  -ForegroundColor Green
Write-Host "Exchange Calendar Sharing: $($GetCalendarSharing)"  -ForegroundColor Green
Write-Host "Precollect Limit: $($PrecollectLimit)"  -ForegroundColor Green
Write-Host "Get Secure Score: $($GetSecureScore)" -ForegroundColor Green
Write-Host ""

If(!$SPOPermissionOptIn) {
    Write-Host "$(Get-Date) [INFO] Engineer has not opted-IN to Site-Level checks that require the addition of Site Collection Administrator permissions. Check the Delivery Guide for more information!" -ForegroundColor Yellow
}

If(!$BypassPrereqCheck) {
    Write-Host "$(Get-Date) Checking pre-requisites..."

    $RequiredModulesExist = (Check-ModuleExists -ModuleName "AzureADPreview")
    $RequiredModulesExist = (Check-ModuleExists -ModuleName "MSOnline")
    $RequiredModulesExist = (Check-ModuleExists -ModuleName "SharePointPnPPowerShellOnline")
    $RequiredModulesExist = (Check-ModuleExists -ModuleName "Microsoft.Online.SharePoint.PowerShell")

    If($RequiredModulesExist -eq $false) { Exit; }
}

#endregion

# Determine if SPOAdmin is mandatory
#if (-Not ($SPOPermissionOptOut -or $SPOAdmin)) {Write-Error "SPOAdmin is a mandatory argument if SPOPermissionOptOut is not specified"; Exit}
If($SPOPermissionOptIn -and -Not $SPOAdmin)  {Write-Error "SPOAdmin is a mandatory argument if SPOPermissionOptOut is not specified"; Exit}
If($GetSecureScore -and $NoPnP) {Write-Error "Secure Score requires PnP checks"; Exit}

# Check if required to connect

if($Connect) {

    If(!(Get-Command "Connect-EXOPSSession" -ErrorAction:SilentlyContinue)) {
        Write-Host "$(Get-Date) Not ran from an EXO PowerShell Module window - attempt to autoload starting"
        # Attempt to load automatically
        $modules = @(Get-ChildItem -Path "$($env:LOCALAPPDATA)\Apps\2.0" -Filter "Microsoft.Exchange.Management.ExoPowershellModule.manifest" -Recurse )
        $moduleName =  Join-Path $modules[0].Directory.FullName "Microsoft.Exchange.Management.ExoPowershellModule.dll"
        Import-Module -FullyQualifiedName $moduleName -Force
        $scriptName =  Join-Path $modules[0].Directory.FullName "CreateExoPSSession.ps1"
        . $scriptName
        If(!(Get-Command "Connect-EXOPSSession" -ErrorAction:SilentlyContinue)) {
            Write-Error "Run from a Exchange Online MFA Enabled PowerShell window to auto connect. Attempt to automatically load failed. http://aka.ms/exopspreview"
            Exit
        }
    }

    Write-Host "$(Get-Date) Connecting..."
    
    Write-Host "$(Get-Date) Connecting to Azure AD PowerShell 1.."
    Connect-MsolService

    Write-Host "$(Get-Date) Connecting to Azure AD PowerShell 2.."
    Connect-AzureAD

    Write-Host "$(Get-Date) Connecting to Exchange Online.."
    Connect-EXOPSSession | Out-Null

    Write-Host "$(Get-Date) Connecting to SharePoint Online.."
    $adminUrl = Get-SharePointAdminUrl
    Connect-SPOService -Url $adminUrl | Out-Null

    if($true -eq $GetSecureScore)
    {
        Write-Host "$(Get-Date) Connecting to PnP for Reports.."
        Connect-PnPOnline -Scopes "Reports.Read.All" | Out-Null
        $PnPReportsToken = Get-PnPAccessToken
    }

    if ($false -eq $NoPnP)
    {
        Write-Host "$(Get-Date) Connecting to SharePoint Online via PnP.."
        $defaultUrl = Get-SharePointDefaultUrl
        Connect-PnPOnline -Url $defaultUrl -UseWebLogin | Out-Null
    }
}

if($ConnectNoMFA) {
    
        If(!(Get-Command "Connect-EXOPSSession" -ErrorAction:SilentlyContinue)) {
            Write-Error "Run from a Exchange Online MFA Enabled PowerShell window to auto connect. http://aka.ms/exopspreview"
            Exit
        }
    
        Write-Host "$(Get-Date) Connecting..."
        $Credential = Get-Credential -Message "Customer Office 365 Global Administrator Account"
        
        Write-Host "$(Get-Date) Connecting to Azure AD PowerShell 1.."
        Connect-MsolService -Credential $Credential
    
        Write-Host "$(Get-Date) Connecting to Azure AD PowerShell 2.."
        Connect-AzureAD -Credential $Credential

        Write-Host "$(Get-Date) Connecting to Exchange Online..."
        Connect-EXOPSSession -UserPrincipalName $Credential.UserName | Out-Null

        # Workaround - Connect-AzureAD clears the password in $Credential
        $SPOCredential = Get-Credential -UserName $Credential.UserName -Message "SharePoint Online or Global Administrator Account"

        if($true -eq $GetSecureScore)
        {
            Write-Host "$(Get-Date) Connecting to PnP for Reports.."
            Connect-PnPOnline -Scopes "Reports.Read.All" -Credentials $SPOCredential | Out-Null
            $PnPReportsToken = Get-PnPAccessToken 
        }    

        Write-Host "$(Get-Date) Connecting to SharePoint Online..."
        $adminUrl = Get-SharePointAdminUrl
        Connect-SPOService -Url $adminUrl  -Credential $SPOCredential | Out-Null

        if ($false -eq $NoPnP)
        {
            Write-Host "$(Get-Date) Connecting to SharePoint Online via PnP..."
            $defaultUrl = Get-SharePointDefaultUrl
            Connect-PnPOnline -Url $defaultUrl -Credentials $SPOCredential | Out-Null
        }
    
    }
    
Function Precollect-EXO1 {
    Param($OutputDir,$PrecollectLimit)
    If($PrecollectLimit -eq 0) {
        Invoke-Command -Session (Get-PSSession) -ScriptBlock {Get-Mailbox -ResultSize:Unlimited | Select-Object -Property ForwardingSmtpAddress,AuditEnabled,AuditOwner} | Export-CSV $OutputDir\EXO-Mailboxes.csv -NoTypeInformation
    } else {
        Invoke-Command -Session (Get-PSSession) -ScriptBlock {param($PrecollectLimit) Get-Mailbox -ResultSize:$PrecollectLimit | Select-Object -Property ForwardingSmtpAddress,AuditEnabled,AuditOwner} -ArgumentList $PrecollectLimit | Export-CSV $OutputDir\EXO-Mailboxes.csv -NoTypeInformation
    }
}

Function Precollect-EXO2 {
    Param($OutputDir,$PrecollectLimit)
    If($PrecollectLimit -eq 0) {
        Invoke-Command -Session (Get-PSSession) -ScriptBlock {Get-CasMailbox -ResultSize:Unlimited | Select-Object -Property ActiveSyncEnabled,OWAEnabled,OWAforDevicesEnabled,ECPEnabled,PopEnabled,ImapEnabled,MAPIEnabled,UniversalOutlookEnabled,EwsEnabled,EwsAllowOutlook} | Export-CSV $OutputDir\EXO-CasMailbox.csv -NoTypeInformation
    } else {
        Invoke-Command -Session (Get-PSSession) -ScriptBlock {param($PrecollectLimit) Get-CasMailbox -ResultSize:$PrecollectLimit | Select-Object -Property ActiveSyncEnabled,OWAEnabled,OWAforDevicesEnabled,ECPEnabled,PopEnabled,ImapEnabled,MAPIEnabled,UniversalOutlookEnabled,EwsEnabled,EwsAllowOutlook} -ArgumentList $PrecollectLimit | Export-CSV $OutputDir\EXO-CasMailbox.csv -NoTypeInformation
    }
   
}

Function Precollect-AAD {
    Param($OutputDir,$PrecollectLimit)
    If($PrecollectLimit -eq 0) {
        Get-MsolUser -All | Select-Object StrongAuthenticationRequirements,StrongAuthenticationMethods,LastPasswordChangeTimestamp | Export-Clixml $OutputDir\AAD-User.xml
    } else {
        Get-MsolUser -MaxResults $PrecollectLimit | Select-Object StrongAuthenticationRequirements,StrongAuthenticationMethods,LastPasswordChangeTimestamp | Export-Clixml $OutputDir\AAD-User.xml
    }
}

# Perform precollect only, for speeding up larger deployments by splitting the precollect
If($PrecollectOnlyEXO1) {
    Write-Host "$(Get-Date) Pre-collection of EXO1 will only be conducted, then the script will exit"
    Precollect-EXO1 -OutputDir $OutputDir -PrecollectLimit $PrecollectLimit
    Write-Host "$(Get-Date) Pre-collect of EXO1 complete"
    exit
}

If($PrecollectOnlyEXO2) {
    Write-Host "$(Get-Date) Pre-collection of EXO2 will only be conducted, then the script will exit"
    Precollect-EXO2 -OutputDir $OutputDir -PrecollectLimit $PrecollectLimit
    Write-Host "$(Get-Date) Pre-collect of EXO2 complete"
    exit
}

If($PrecollectOnlyAAD) {
    Write-Host "$(Get-Date) Pre-collection of AAD will only be conducted, then the script will exit"
    Precollect-AAD -OutputDir $OutputDir -PrecollectLimit $PrecollectLimit
    Write-Host "$(Get-Date) Pre-collect of AAD complete"
    exit
}

# Check connected
try {Get-MsolCompanyInformation -ErrorAction:stop | Out-Null} catch {Write-Error "This script requires you to be connected to MSOL v1 as a Global Administrator. Run Connect-MsolService first"; Exit}
try {Get-AzureADTenantDetail -ErrorAction:stop | Out-Null} catch {Write-Error "This script requires you to be connected to Azure AD PowerShell v2.0 as a Global Administrator. Run Connect-AzureAD first";  Exit}
try {Get-Command Set-Mailbox -ErrorAction:stop | Out-Null} catch {Write-Error "This script requires you to be connected to Exchange Online Remote PowerShell. Run Connect-EXOPSSession (for new PowerShell EXO module) or connect using a PSSession.";Exit}
try {Get-SPOTenant -ErrorAction:stop | Out-Null} catch {Write-Error "This script requires you to be connected to SPO as a SharePoint Online Administrator. Run Connect-SPOService first"; Exit}
#endregion

#region SecureScore
# This gets done first because I fear the bearer token may expire before precollection is complete
if($true -eq $GetSecureScore -and $PnPReportsToken)
{
    Write-Host "$(Get-Date) Collecting Secure Score"
    $SecScoreHeaders = @{"Content-Type" = "application/json" ; "Authorization" = "Bearer " + $PnPReportsToken}
    $SecScoreURI = "https://graph.microsoft.com/stagingBeta/reports/getTenantSecureScores(period=1)/content"
    Invoke-RestMethod -Uri $SecScoreURI -Headers $SecScoreHeaders -Method Get -OutFile "$OutputDir\365-SecureScore.json"
}
#endregion

#region Precollect
# If precollect is not complete (default) obtain the precollect first
If(!$PrecollectComplete) {
    Write-Host "$(Get-Date) Running pre-collection"
    Precollect-EXO1 -OutputDir $OutputDir  -PrecollectLimit $PrecollectLimit
    Precollect-EXO2 -OutputDir $OutputDir -PrecollectLimit $PrecollectLimit
    Precollect-AAD -OutputDir $OutputDir -PrecollectLimit $PrecollectLimit
}

$Mailboxes = Import-CSV $OutputDir\EXO-Mailboxes.csv
$CASMailboxes = Import-CSV $OutputDir\EXO-CasMailbox.csv
$AUsers = Import-Clixml $OutputDir\AAD-User.xml

#endregion

#region Collect

#region Misc
Write-Host "$(Get-Date) Getting Misc Information"
Get-MsolCompanyInformation | Select-Object UsersPermissionToUserConsentToAppEnabled | Export-Clixml "$OutputDir\AAD-CompanyInformation.xml"
#endregion

#region EXO

if ($false -eq $NoEXO)
{
#region Collect - Organisational Config...
Write-Host "$(Get-Date) Getting Organisational Configuration"
Get-OrganizationConfig | Export-Clixml "$OutputDir\EXO-OrganizationConfig.xml"
#endregion
#region Collect - Role Group Members
Write-Host "$(Get-Date) Getting Exchange Online and Office 365 Role Group Members"
Get-RoleMembers365 | Export-CSV "$OutputDir\O365-RoleGroupMembers.CSV" -NoTypeInformation
Get-RoleMembersEXO | Export-CSV "$OutputDir\EXO-RoleGroupMembers.CSV" -NoTypeInformation
#endregion
#region Collect - Protocol Enablement
Write-Host "$(Get-Date) Getting Protocol Enablement Settings"
Get-ProtocolEnablement -CASMailboxes $CASMailboxes | Export-CSV "$OutputDir\EXO-ProtocolEnablement.csv" -NoTypeInformation
#endregion
#region Collect - Mailbox Forwarding
Write-Host "$(Get-Date) Getting Mailbox Forward Domains"
Get-MailboxForwardDomains -Mailboxes $mailboxes | Export-CSV "$OutputDir\EXO-MailboxAutoForwards.csv" -NoTypeInformation
#endregion
#region Collect - Transport Config
Write-Host "$(Get-Date) Getting Transport Configuration"
Get-TransportConfig | Export-Clixml "$OutputDir\EXO-TransportConfig.xml"
#endregion
#region Collect - ATP Settings
Write-Host "$(Get-Date) Getting Advanced Threat Protection Settings"
Get-SafeAttachmentPolicy | Export-Clixml "$OutputDir\EXO-SafeAttachmentsPolicy.xml"
Get-SafeAttachmentRule | Export-Clixml "$OutputDir\EXO-SafeAttachmentsRules.xml"
Get-SafeLinksPolicy | Export-Clixml "$OutputDir\EXO-SafeLinksPolicy.xml"
Get-SafeLinksRule | Export-Clixml "$OutputDir\EXO-SafeLinksRules.xml"
Get-AtpPolicyForO365 | Export-Clixml "$OutputDir\365-AtpPolicy.xml"
#endregion
#region Collect - Domains
Write-Host "$(Get-Date) Getting Accepted Domains"
Get-AcceptedDomain | Export-Clixml "$OutputDir\EXO-AcceptedDomains.xml"
#endregion
#region Collect - Antispam Settings
Write-Host "$(Get-Date) Getting Anti-Spam Settings"
Get-HostedConnectionFilterPolicy | Export-Clixml "$OutputDir\EXO-HostedConnectionFilterPolicy.xml"
Get-HostedContentFilterPolicy | Export-Clixml "$OutputDir\EXO-HostedContentFilterPolicy.xml"
Get-HostedContentFilterRule | Export-Clixml "$OutputDir\EXO-HostedContentFilterRule.xml"
Get-HostedOutboundSpamFilterPolicy | Export-Clixml "$OutputDir\EXO-HostedOutboundSpamFilterPolicy.xml"
#endregion
#region Collect - Antimalware Settings
Write-Host "$(Get-Date) Getting Anti-Malware Settings"
Get-MalwareFilterPolicy | Export-Clixml "$OutputDir\EXO-MalwareFilterPolicy.xml"
Get-MalwareFilterRule | Export-Clixml "$OutputDir\EXO-MalwareFilterRule.xml"
#endregion
#region Collect - Connector Settings
Write-Host "$(Get-Date) Getting Connector Settings"
Get-InboundConnector | Export-Clixml "$OutputDir\EXO-InboundConnector.xml"
Get-OutboundConnector | Export-Clixml "$OutputDir\EXO-OutboundConnector.xml"
#endregion
#region Collect - Transport Rules
Write-Host "$(Get-Date) Getting Transport Rules"
Get-TransportRule | Export-Clixml "$OutputDir\EXO-TransportRules.xml"
#endregion
#region Collect - Remote Domains
Write-Host "$(Get-Date) Getting Remote Domains"
Get-RemoteDomain | Export-Clixml "$OutputDir\EXO-RemoteDomain.xml"
#endregion
#region Collect - Organisation Sharing
Write-Host "$(Get-Date) Getting Organisation Sharing"
Get-SharingPolicy | Export-Clixml "$OutputDir\EXO-SharingPolicy.xml"
#endregion
#region Collect - Auditing
Write-Host "$(Get-Date) Getting Auditing Settings"
Get-AdminAuditLogConfig | Export-Clixml "$OutputDir\EXO-AdminAuditLogConfig.xml"
Get-MailboxAuditSettings -Mailboxes $mailboxes | Export-CSV "$OutputDir\EXO-MailboxAuditSettings.csv" -NoTypeInformation
#endregion
#region Collect - EAS Policies
Write-Host "$(Get-Date) Getting EAS Policies"
Get-MobileDeviceMailboxPolicy  | Export-Clixml "$OutputDir\EXO-MobileDeviceMailboxPolicy.xml"
#endregion
#region Collect - Role Assignment Policy and Entries
Write-Host "$(Get-Date) Getting Role Assignment Policies and Entries"
Get-RoleAssignmentPoliciesAndEntries | Export-CliXml "$OutputDir\EXO-RoleAssignmentPoliciesEntries.xml"
#endregion
#region Collect - DKIM Signing Configuration
Write-Host "$(Get-Date) Getting DKIM Signing Configuration"
Get-DkimSigningConfig | Export-CliXml "$OutputDir\EXO-DKIMSigningConfig.xml"
#endregion
#region Collect - Azure/Office 365 SKUs
Write-Host "$(Get-Date) Getting Azure AD SKUs"
Get-AzureSKUs | Export-CSV "$OutputDir\AAD-SKUs.csv"
#endregion
#region Collect - Report Schedule...
Write-Host "$(Get-Date) Getting Report Schedule List"
Get-ReportScheduleList | Export-CliXml "$OutputDir\EXO-ReportScheduleList.xml"
#endregion
#region Collect - Calendar Sharing
if($GetCalendarSharing) {
Write-Host "$(Get-Date) Getting calendar sharing"
Get-CalendarSharing | Export-CSV "$OutputDir\EXO-CalendarShares.csv" -NoTypeInformation
}
#endregion
#region Collect - Azure user
Write-Host "$(Get-Date) Getting Azure User Summary"
Get-AUserSummary -AUsers $AUsers | Export-CSV "$OutputDir\AAD-AUserSummary.csv" -NoTypeInformation
#endregion
}
#endregion

#region SPO

    if ($false -eq $NoSPO)
    {
        #region Collect - Get-SPOTenant
        Write-Host "$(Get-Date) Getting SPO Tenant Properties"
        Get-SPOTenantProperties | Export-Clixml "$OutputDir\SPO-TenantProperties.xml"
        #endregion

        #region Collect - Site Collection Properties
        Write-Host "$(Get-Date) Getting Site Collection Properties"
        Get-SPOSiteCollectionProperties | Export-Clixml "$OutputDir\SPO-SiteCollectionProperties.xml"
        #endregion

        #region Collect - Personal Site Properties
        Write-Host "$(Get-Date) Getting Personal Site Properties"
        Get-SPOPersonalSiteProperties | Export-Clixml "$OutputDir\SPO-PersonalSiteProperties.xml"
        #endregion
    }

#endregion

#region Collect - Manifest
$files = @{}
$ignoredfiles = "Collection-Transcript.txt"
ForEach($File in (Get-ChildItem $OutputDir)) {
    If($ignoredfiles -notcontains $File.Name) {
    $files.Add($File.Name.ToString(),(Get-FileHash($File.FullName)).Hash)
    }
}
$Files | Export-Clixml "$OutputDir\Manifest.xml"
#endregion

#endregion

Write-Host ("")

Stop-Transcript
