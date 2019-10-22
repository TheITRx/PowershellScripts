
function start-serviceifstopped {

    param([string]$servicename)
    $try = 0

    while ($try -le 3){

        $serv_status = get-service $servicename | select status

        if ($serv_status.status -ne "Running"){

            Start-Service -Name $servicename -ErrorAction SilentlyContinue
            $try += 1

        }

        else{
            $try = 4
        }
        
    }

    get-service $servicename | select -ExpandProperty status

}

start-serviceifstopped -servicename fax
