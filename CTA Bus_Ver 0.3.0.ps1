$wutime = "17:00:00"      # wake up hour, what hour you need to wake up - 24hour - format
$stopid = 7613            # which stop
$bushowfar = 20           # How far the bus needs to be before it will start calling you
$preptime = 90            # how much time you need to prep. Bus keeps on calling within X minutes after wake up time ($wutime).
                    
$ctaapikey = ""        # Cta APIKey
$iftttapikey = ""         #ifttt APIkey
$apiliokey = "" # apilio APIkey

# write log to file. Creates a file in local directory to your powershell session. 
Function write-log {
    param($logentry)
    $lognote = (Get-Date -Format "MM/dd/yy HH:mm:ss") + " - $logentry"
    Out-File -FilePath ".\CtaBusCall.txt" -Append -NoClobber -Encoding "Default" -InputObject $lognote
    $lognote
} #write-log

#Function to Call mobile number
function iffpost {

    param($currenteta,$evalurl)
    # Set current bus ETA
    $set_apiletaval = Invoke-WebRequest "https://apilio.herokuapp.com/string_variables/ctaminsaway/set_value/with_key/$($apiliokey)?value=$currenteta" | select @{name="PushEvalResult";E={$_.statuscode}} | select -expandproperty pushevalresult

    write-log "Setting APIL Eta value. Result: $set_apiletaval"
    # apilio evaulate, will trigger phone call

    write-log "Bus is $minsaway mins away. sending wake up signal."
    $res_eval = (((Invoke-WebRequest "$evalurl" | select -expandproperty content) -split "\n" | Select-String "result") | out-string).Substring(111,8)

    if($res_eval -eq "Positive"){
        write-log "$res_eval - Call is being made. User is still asleep"
    }

    else{
        write-log "$res_eval - No Call is being made. User is already up"
    }
    
} #Iffpost

$appr_count = 0

while($true){

    # set the apilio variables back to original so it would ring again in the morning. 

    if((get-date -Format HH) -eq 00){
        $set_apil_var_res = Invoke-WebRequest -Uri "https://apilio.herokuapp.com/boolean_variables/cta_stillsleep/set_true/with_key/$apiliokey" | select @{name="SetAPiilVarResult";E={$_.statuscode}} | select -expandproperty SetAPiilVarResult
        write-log "Set APIL var to true result: $set_apil_var_res"

    }

    $hournow  = get-date -Format HH
    write-log "Gathering bus arrival information"
    $api_info_res = Invoke-RestMethod -Method Get -Uri "http://ctabustracker.com/bustime/api/v2/getpredictions?key=$ctaapikey&stpid=$stopid&top=1" 
    $predtm = $api_info_res.'bustime-response'.prd.prdctdn

    # set $minsaway value. equals 1 if it is approaching. 
    if(($predtm -ne "DUE") -and ($predtm -ne "DLY")){[int]$minsaway = [convert]::ToInt32($predtm)} else{[int]$minsaway = 1}

        
        if(((get-date) -gt ([datetime]$wutime).AddMinutes(90) -or ((get-date) -lt ([datetime]$wutime)))){
            
            write-log "It's not yet time to wake up. We'll check again 5 minuts..ZzzZZzz"
            sleep -Seconds 10

        }

        # All the work is done here.
        Else {

            # Bus is less than how far specified in the variable
            if(($minsaway -lt $bushowfar) -and ($minsaway -ne 1)){

                iffpost -currenteta $minsaway -evalurl "https://apilio.herokuapp.com/logicblocks/cta_wake_up/evaluate/with_key/$apiliokey" 
                write-log "waiting for 60 sec. sleeping"
                sleep 60
                $appr_count = 0
            }

            elseif(($minsaway -eq 1) -and ($appr_count -le 3)){

                write-log "Bus is approaching. Calling your phone."

                #Invoke-WebRequest -uri "https://apilio.herokuapp.com/logicblocks/cta_call_approaching/evaluate/with_key/$apiliokey" | select @{name="PushEvalResult";E={$_.statuscode}}
               
                $res_eval = (((Invoke-WebRequest "https://apilio.herokuapp.com/logicblocks/cta_call_approaching/evaluate/with_key/$apiliokey" | select -expandproperty content) -split "\n" | Select-String "result") | out-string).Substring(111,8)

                if($res_eval -eq "Positive"){
                    write-log "$res_eval - Call is being made. User is still asleep"
                }

                else{
                    write-log "$res_eval - No Call is being made. User is already up"
                }
                                   
                write-log "wake up signal sent. sleeping for 60 seconds."
                sleep 120
                $appr_count++
                
            }
            
            else {

                write-log "Not yet time for a ring. The bus is $minsaway mins away."
                sleep 20
            } 
        }


} #while loop