$Get5136_arr = @();
$yesdate = (Get-Date).AddDays(-1).ToString('M/d/yyyy'); 

$Get5136 = Get-EventLog Security -After $yesdate | Where-Object {$_.EventID -eq 5136} | select @{Name="TimeWritten";Expression={ Get-Date $_.TimeWritten }},@{Name="AccountName";Expression={$_.ReplacementStrings[3]}}, @{Name="SecurityID";Expression={$_.ReplacementStrings[2]}}, @{Name="Object";Expression={$_.ReplacementStrings[8]}}, @{Name="GUID";Expression={$_.ReplacementStrings[9]}}, @{Name="Class";Expression={$_.ReplacementStrings[10]}}, @{Name="Attribute";Expression={$_.ReplacementStrings[11]}},@{Name="Operation";Expression={$_.ReplacementStrings[14]}}, @{Name="AttributeValue";Expression={$_.ReplacementStrings[13]}} -First 4 

Foreach($op in $Get5136){

if($op.Operation -like "%%14674") {
        
        $Get5136_arr += @{TimeWritten = $op.TimeWritten; AccountName = $op.AccountName; Attribute=$op.Attribute; Object = $op.Object; Class = $op.Class; Operation = "Value Added"; AttributeValue=$op.AttributeValue};
    }

ElseIf($op.Operation -like "%%14675"){
     
     $Get5136_arr += @{TimeWritten = $op.TimeWritten; AccountName = $op.AccountName; Attribute=$op.Attribute; Object = $op.Object; Class = $op.Class; Operation = "Value Removed"; AttributeValue=$op.AttributeValue}
}
    
Else{
    
     $Get5136_arr += @{TimeWritten = $op.TimeWritten; AccountName = $op.AccountName; Attribute=$op.Attribute; Object = $op.Object; Class = $op.Class; Operation = $op.Operation; AttributeValue=$op.AttributeValue}
}

}

$Get5136_arr | % { new-object PSObject -Property $_}