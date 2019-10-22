function remove-duplicate{
    [cmdletbinding()]

    param(
        $sourcepath,
        $dupepath
    )

    Write-Debug $sourcepath
    write-debug $dupepath

$holder = @()

    $dupepathconts = Get-ChildItem $dupepath | select *
    $srcconts = Get-ChildItem $sourcepath | select *

    foreach($item in $srcconts){
        $check_presence = $dupepathconts | ? {$_.name -eq $($item.name) -and $_.length -eq $($item.length) -and $_.LastWriteTimeUtc -eq $($item.LastWriteTimeUtc)}

        if($check_presence){
            $holder +=  $check_presence
        }
    }
    
    $holder | % {Remove-Item $_.fullName}
    $holder | select fullname | Export-Csv C:\Temp\deleted1.csv -NoTypeInformation
    Write-output $holder
        
}