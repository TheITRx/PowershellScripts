<#
.SYNOPSIS
    Post Comment in Facebook
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
    
$ie = New-Object -ComObject "InternetExplorer.application"
$ie.Visible = $true
$ie.Navigate("https://www.facebook.com/lloyd.e.antonio")



while ($ie.Busy -eq $true) {

    # Wait for the page to load
    Start-Sleep -seconds 5;

}

$start = Get-Date;
$VerticalScroll = 0
While ((Get-Date) -lt $($start + [timespan]::new(0, 0, 3))) {

    $ie.Document.parentWindow.scrollTo(0, $VerticalScroll)
    $VerticalScroll = $VerticalScroll + 100
}

    
$likes = $ie.Document.IHTMLDocument3_getElementsByTagName('a') | ? { $_.classname -eq "comment_link _5yxe" }

$likes[0].click();

 

$comms = $ie.Document.IHTMLDocument3_getElementsByTagName('Input') | ? { $_.Name -eq "add_comment_text" }

$comms[0].click()

($ie.Document.IHTMLDocument3_getElementsByTagName('div') | ? { $_.ClassName -eq "UFIAddCommentInput _1osb _2xww _5yk1" }).click()

$write = $ie.Document.IHTMLDocument3_getElementsByTagName('span') | ? { $_.ClassName -eq "_ttu" }
       
$eh = $ie.Document.IHTMLDocument3_getElementsByTagName('span') | ? { $_.ClassName -eq "_63ey" }
$eh.textContent = "hehehe"


