Function Install-ShadowControlAgent {

    <#
    .SYNOPSIS
        Install-ShadowControlAgent
    .DESCRIPTION
        Downloads the Shadowcontrolagent from your the ShadowControlServer and install and subscribes it. 
    .EXAMPLE
        PS C:\> Install-ShadowControlAgent -SHadowControlServer scserver.TheITRx.com
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>

    # Parameter help description
    [Parameter(Mandatory)]
    [String]$SHadowControlServer

    # Force to run as admin

    If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
        
        $arguments = "& '" + $myinvocation.mycommand.definition + "'"
        Start-Process powershell -Verb runAs -ArgumentList $arguments
        Break
    }

    
    #Logging
    $SN = $MyInvocation.MyCommand.Name; Function WL($LE) { $LN = (Get-Date -Format "MMddyy:HHmmss") + " - $LE"; $LN | Out-File -FilePath "$PSScriptRoot\$SN-log.txt" -Append -NoClobber -Encoding "Default"; $LN }
    #Ignore SSL
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

    Function Start-SCService { 

        WL "Starting Service"
        Start-Service stc_endpt_svc
        Set-Location "C:\Program Files (x86)\StorageCraft\CMD"
        WL "Subscribing"
        $OutEx = .\stccmd subscribe $SHadowControlServer
        WL $OutEx
    }

    $Check_CLDir = Test-Path "C:\Program Files (x86)\StorageCraft\CMD\stccmd.EXE"
    if (!$Check_CLDir) {

        while ((Test-Path "$($PSScriptRoot)\ShadowControl_Installer.msi") -eq $false) { 
                
            WL "Downloading File"
            $Res = Invoke-WebRequest "https://$SHadowControlServer/api/installer/msi/download/" -OutFile "$($PSScriptRoot)\ShadowControl_Installer.msi"
        }

        WL "Download finished. Installing now."
        Set-Location "$($PSScriptRoot)"
        Start-Process msiexec.exe -Wait -ArgumentList "/i ShadowControl_Installer.msi /quiet"
        WL "Install Finished"

        while ((Test-Path "C:\Program Files (x86)\StorageCraft\CMD\stccmd.exe") -eq $false) {
            WL "Still installing"
            Start-Sleep -Seconds 5
        }
        
        try { 
            Start-SCService 
        }

        Catch { 
            WL "fail to start service."
        }
    }

    Else { 

        try { 
            WL "Current install is present. Will the start the service and re-checkin"
            Start-SCService
        }

        Catch { 
            WL "fail to start service."
        }
    }
}