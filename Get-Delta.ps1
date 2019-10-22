$source = import-csv C:\temp\Book1.csv

$catch = @()
$notcatch = @{}

foreach($ent in $list){

    $res = $source | ? {$_.ip -eq $ent} | Select-Object -First 1
    
    if($res){
        $catch += $res
    }
    
}

$catch | Export-Csv .\res2.csv -NoTypeInformation

#$notcatch