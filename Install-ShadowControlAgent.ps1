$Check_CLDir = Test-Path "C:\Program Files (x86)\StorageCraft\CMD\stccmd"
$shadowControlServer = ""

# Force to run as admin
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

$SN = $MyInvocation.MyCommand.Name; Function WL($LE) {$LN = (Get-Date -Format "MMddyy:HHmmss") + " - $LE"; $LN | Out-File -FilePath "$PSScriptRoot\$SN-log.txt" -Append -NoClobber -Encoding "Default"; $LN }
Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

if (!$Check_CLDir) {

    while ((Test-Path "$($env:Appdata)\Shadow_Controll_Installer.msi") -eq $false) { 
        
        WL "Downloading File"
        $Res = Invoke-WebRequest "https://$shadowControlServer/api/installer/msi/download/" -OutFile "$($env:Appdata)\Shadow_Controll_Installer.msi"
    }

    WL "Download finished. Installing now."
    Set-Location "$($env:Appdata)"

    If((Test-Path "C:\Program Files (x86)\StorageCraft\CMD\stccmd.exe") -eq $false) {

        Start-process msiexec.exe -Wait -ArgumentList "/i Shadow_Controll_Installer.msi /quiet"
        WL "Install Finished"
    }

    else{
        WL "Current installation is present"
    }

    while ((Test-Path "C:\Program Files (x86)\StorageCraft\CMD\stccmd.exe") -eq $false) {
        WL "Still installing"
        Start-Sleep -Seconds 5
    }

    get-service stc_endpt_svc | start-service 
	
	if(!($?)) {
		WL "Error Starting Service"
	}

    ELSE{
        WL "Service started"
    }
	
    Set-Location "C:\Program Files (x86)\StorageCraft\CMD"
    WL "Subscribing $($env:COMPUTERNAME)"
    $OutEx = .\stccmd subscribe $shadowControlServer

    WL $OutEx
}