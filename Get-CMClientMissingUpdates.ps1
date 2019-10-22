Function Get-CMClientMissingUpdates{

$MissingUpdates = @();

Try{
    $MissingUpdatesQuery = Get-WmiObject -Query "SELECT * FROM CCM_SoftwareUpdate" -Namespace "ROOT\ccm\ClientSDK" -ErrorAction STOP;
    
    If(($MissingUpdatesQuery | Measure-Object | Select-Object -ExpandProperty Count) -ne 0){
        
        foreach($item in $MissingUpdatesQuery){
            $DObject = New-Object PSObject;
            $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName;
            $DObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $item.Name;
            $DObject | Add-Member -MemberType NoteProperty -Name "ArticleID" -Value $item.ArticleID;
            $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "OK";
            $MissingUpdates += $DObject;}
            }
    }
    
    Catch{
        $DObject = New-Object PSObject;
        $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName;
        $DObject | Add-Member -MemberType NoteProperty -Name "Name" -Value "N/A";
        $DObject | Add-Member -MemberType NoteProperty -Name "ArticleID" -Value "N/A";
        $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception.Message;
        $MissingUpdates += $DObject;
        };
        
    $MissingUpdates;
    
    };

[array]$missingupdates = Get-CMClientMissingUpdates;
$missingupdates.Length;