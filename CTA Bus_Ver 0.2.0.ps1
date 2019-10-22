﻿$callx = $false     # Call Flag
$wutime = "08"        # wake up hour, what hour you need to wake up
$apprtime = "08"
                    # This hour, it will only call you if bus is approaching. 
$stopid = 7613      # which stop
$callafter = 1      # number of minutes after each call
$callsnumber = 2    # How many times it will call you
$bushowfar = 20     # How far the bus needs to be before it will start calling you
                    # Cta APIKey
$ctaapikey = ""
$iftttapikey = ""


#Function to Call mobile number
function iffpost {

    param($minsaway_json)
    $json = $minsaway_json | ConvertTo-Json
    Invoke-RestMethod -Method POST -Uri "https://maker.ifttt.com/trigger/CheckBus/with/key/$iftttapikey"  -Body $json -ContentType 'application/json'

    "Hey! The next bus is " + $minsaway + " mins away."
    "I'm calling you now and I'll check again after $callafter minute/s."
    sleep -Seconds ($callafter * 60)
           
    } #Iffpost


while($true){

    $hournow = get-date -Format HH
    $res = Invoke-RestMethod -Method Get -Uri "http://ctabustracker.com/bustime/api/v2/getpredictions?key=$ctaapikey&stpid=$stopid&top=1"
    $predtm = $res.'bustime-response'.prd.prdctdn

    # set $minsaway value. equals 1 if it is approaching. 
    if($predtm -ne "DUE"){[int]$minsaway = [convert]::ToInt32($predtm)} else{[int]$minsaway = 1}

        
        if($hournow -ne $wutime -and $hournow -ne $apprtime){
            
            $callx = $false
            "It's not yet time to wake up. We'll check again 5 minuts..ZzzZZzz"
            sleep -Seconds 10

        }

        # All the work is done here.
        Else {


            # bus is approaching, make a phone call
            if($minsaway -eq 1){
            
                $minsaway_json = @{value1="$minsaway"}
                iffpost -minsaway_json $minsaway_json
            
            }

            # Bus is is how far specified in the variable
            elseif(($minsaway -lt $bushowfar) -and ($hournow -ne $apprtime) -and ($callx -ne $true)){

                $minsaway_json = @{value1="$minsaway"}
                iffpost -minsaway_json $minsaway_json
                $callx = $true
            }

            
            else {

                "Not yet time for a ring. The bus is " + $minsaway + " mins away. I'll cheack again after 20 seconds" ;
                sleep 20
            } 
        }


} #while loop