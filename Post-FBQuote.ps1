<#

Date:           August 18, 2017 

Description:    Just having  fun with Powershell. This guy uses internet
                Explorer com objects to go to fuckinghomepage.com and grabs a random quote. 
                Then it logs in to facebook and post a status. All programatically and discretely.

                Fuckinghomepage.com is an awesome website. Been a huge fan of it!

Usage:          On first run, it will ask for your facebook password and will hash it 
                locally where the powershell script is saved. This way it won't ask for
                the password anymore. One time ask! You also need to change the 
                $fb_un variable to user Facebook login. Lastly, schedule a task/job to 
                run it periodically. 

Note:           I know, no one would get interested in this code. Well, I'm just having fun!
                For educational purposes only!

#>

$fb_un = "enjoyjocel@gmail.com"

function sleep-me{
        while ($ie.Busy -eq $true){
            # Wait for the page to load
            Start-Sleep -seconds 5;
        }
}

function hash-fbpw{

    if(!(Test-Path ".\fb_pw.txt")){

        Read-Host "Enter Facebook Password" -AsSecureString |  ConvertFrom-SecureString | Out-File ".\fb_pw.txt"
        $fb_pw_file = ".\fb_pw.txt"

    }

    else{

        $fb_pw_file = ".\fb_pw.txt"
    }

    $fb_pw_file  = Get-Content ".\fb_pw.txt" | ConvertTo-SecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($fb_pw_file)
    $fb_pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

function create-intro{
    $good_word = "marvelous","beautiful","lovely","sublime","wonderful"
    $rand = Get-Random -Maximum $good_word.Length
    
    $day = Get-Date -Format dddd
    $intro = "Word of this " + $good_word[$rand] + " " + "$day." 
    $intro

}


Function get-quote{

    $rand = Get-Random -Maximum 1000
    $ie = New-Object -ComObject 'internetExplorer.Application'
    $ie.Visible= $False
    #$ie.Navigate("http://fuckinghomepage.com/page/$rand") 
    $ie.Navigate("http://fuckinghomepage.com/random") 

    sleep-me

    $p_text = $ie.Document.IHTMLDocument3_getElementsByTagName('p')
    $p_text_com = $p_text[2].innertext
    $ie.quit()
    
    $line_one = create-intro
    $quote = $line_one + "`n.`n.`n`"$p_text_com`"" + "`n.`n.`n=)`n`
    This is an automated post. Source Code:`nhttps://1drv(dot)ms/u/s!Ang0s9jKEdGLhKYlZXzvkIHtgeIFlw" 
    $quote

}

get-quote

function login-fb {
 
    param([string]$status)

    $ie = New-Object -ComObject 'internetExplorer.Application'
    $ie.Visible= $true

    $ie.Navigate("https://m.facebook.com") 

    sleep-me

    # Login, provide username and password
    $usernamefield = $ie.Document.IHTMLDocument3_getElementById('email') 

    if($usernamefield -ne $null){

        $usernamefield.value = $fb_un
        $passwordfield = $ie.Document.IHTMLDocument3_getElementById('pass')
        $passwordfield.value = $fb_pw
        ($ie.Document.IHTMLDocument3_getElementsByTagName('input') | ? {$_.value -eq "Log In"}).click()
        
    }

    $ie.Navigate("https://m.facebook.com") 

    sleep-me

    $status_post =  $ie.Document.IHTMLDocument3_getElementById('u_0_0')

    $status_post.value = [string]$status

   ($ie.Document.IHTMLDocument3_getElementsByTagName('input') | ? {$_.value -eq "Post"}).click()

    sleep-me
    $ie.quit()

}


function main {

    hash-fbpw
    $quote_now = get-quote
    $quote_now 
    login-fb -status $quote_now
    
}

main
