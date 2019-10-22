$all_quar =  Get-QuarantineMessage | select *
$stripped = @()

$quar = @()

foreach($id in $all_quar.messageID){
    $res = $id -replace '[<]', ''
    $res = $res -replace '[>]', ''
    $stripped += $res
}

#$stripped

foreach($single in $stripped){
    
    $mess_id = Get-MessageTrace -MessageId $single | select MessageTraceId, RecipientAddress

    foreach($id in $mess_id){
    
    $result_1 =  Get-MessageTraceDetail -MessageTraceId $id.MessageTraceId -RecipientAddress $id.RecipientAddress | ? {$_.detail -like "*Bypassing compromised mailboxes*"} | select @{name="ID";E={$single}}, `
    @{name="Title";E={($_.Detail).trim(25)}}
      
    $quar_id = $result_1.ID

    if ($quar_id -like "*.*"){
    #write-host "releasing $quar_id"
    $result = Get-QuarantineMessage | ? {$_.messageID -like "*$quar_id*"}
    $quar += $result 
    }
    
   }

}
