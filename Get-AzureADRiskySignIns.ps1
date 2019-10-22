Function Get-AzureADRiskySignins{

    param(
    $ClientID       = "391faa8a-0668-40a0-a767-3b2a48c6614c",           # Insert your application's Client ID, a Globally Unique ID (registered by Global Admin)
    $ClientSecret   = "YyfrpgEcYCESmB12QZHjTqoBPTiQIe5nxBO/A6d+MBA=",   # Insert your application's Client Key/Secret string
    $tenantdomain   = "duracell.onmicrosoft.com",  
    $Report         = "compromisedCredentials"                                                    # AAD Tenant; for example, contoso.onmicrosoft.com
    )

    $loginURL       = "https://login.microsoftonline.com"              # AAD Instance; for example https://login.microsoftonline.com
    $resource       = "https://graph.windows.net"                      # Azure AD Graph API resource URI
    $7daysago       = "{0:s}" -f (get-date).AddDays(-7) + "Z"          # Use 'AddMinutes(-5)' to decrement minutes, for example

    # Create HTTP header, get an OAuth2 access token based on client id, secret and tenant domain
    $body       = @{grant_type="client_credentials";resource=$resource;client_id=$ClientID;client_secret=$ClientSecret}
    $oauth      = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body
    $headerParams = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}
    $reportingurl = 'https://graph.windows.net/' + $tenantdomain + '/reports?api-version=beta'
    $Reports= (Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $reportingurl).content

    $urlreport= 'https://graph.windows.net/' + $tenantdomain + '/reports/'+$Report +'?api-version=beta&`$filter=eventTime gt ' + $7daysago

    $ReportOutput = (Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $urlreport).content|ConvertFrom-Json

    #Write-host `n

   # Write-host "Report Name: " $Report -ForegroundColor Yellow

    $ReportOutput.value 

    # Parse audit report items, save output to file(s): auditX.json, where X = 0 thru n for number of nextLink pages
    if ($oauth.access_token -ne $null) {   
        $i=0
      

        # loop through each query page (1 through n)
        Do{
            # display each event on the console window
            Write-Output "Fetching data using Uri: $urlreport"
            $myReport = (Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $urlreport)
            foreach ($event in ($myReport.Content | ConvertFrom-Json).value) {
                Write-Output ($event | ConvertTo-Json)
            }

            # save the query page to an output file
            #Write-Output "Save the output to a file audit$i.json"
            #$myReport.Content | Out-File -FilePath audit$i.json -Force
            $url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'
            $i = $i+1
        } while($urlreport -ne $null)
    } else {
        Write-Host "ERROR: No Access Token"
        }

    Write-Host "Press any key to continue ..."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


}

Get-AzureADRiskySignins -Report compromisedCredentials


