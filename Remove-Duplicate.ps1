
function remove-duplicate($filepath){

    $all_emp_id = Import-Csv $filepath | select EmployeeID

    $dup_holder = @{}
  
    $all_emp_id.EmployeeID | foreach {$dup_holder["$_"] += 1}
    $dup_final = $dup_holder.keys | where {$dup_holder["$_"] -gt 1} 
   

    foreach($duplicate in $dup_final){
        Write-Host "removing duplicate $duplicate"
        $cleaned = Import-Csv -Path $filepath
       $cleaned = $cleaned | ? {-not ($_.EmployeeID -eq $duplicate -and ($_.PositionStatus -ne "Active"))}
        
    } 

    $cleaned | Export-Csv $filepath -NoTypeInformation

}

remove-duplicate -filepath "C:\Users\jsabellano\Downloads\HR.csv"

