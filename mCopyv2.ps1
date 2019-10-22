
# Editable variables
$errorReportPath = "c:\temp\errorReport.csv" # path to error report
$src = "c:\scripts\test" # source of copy
$dst = "c:\scripts\test2" # destination of copies
$maxThreads = 10 # max number of PS threads.  More means job will complete faster but will consume more local resources.

# non editable variables
$today = get-date -Format "yyMMdd"
$newName = $dst + "-$today"
$fileList = get-childitem $src -Recurse # gather list of files to copy
$dstDriveLetter = ($dst -split "\\")[0]
$totalSize = 0
$diskSize = (get-wmiobject -class win32_logicaldisk | where {$_.deviceid -eq "$dstDriveLetter"}).freespace # get freespace of destination
$fileList | foreach { $totalSize += $_.length } # get total size of copy files
$counter = 0
$threads = 0
$activeThreads = 0
$complete = $false
$errorReport = @{}

if ($totalSize -gt ($diskSize * .8)) { break } # exit script if there is not enough space to copy + 20%

Rename-Item -Path $dst -NewName $newName # rename old desintation folder to append date

function get-threads { # function to get number of current jobs
    $runningState = Get-Job | where {$_.state -eq "Running"}
    return $runningState.count
}

function completed-threads { # function to remove jobs from job list once successfully completed
    $completedState = Get-Job | where {$_.state -eq "Completed"}
    foreach ($completedThread IN $completedState) {
        Remove-Job -Id $completedThread.id
    }
}

function error-threads { # function to gather any errors and output it to a report in CSV format
    $errorState = Get-Job | where {$_.State -eq "Failed"}
    foreach ($erroredThread IN $errorState) {
        $temp = $null
        Receive-Job -Id $erroredThread.id -ErrorVariable temp -ErrorAction SilentlyContinue
        $errorReport[$erroredThread.name] = $temp[0]
    }
    $errorReport.GetEnumerator()|Export-Csv -NoTypeInformation -Path $errorReportPath
}

while ($complete -eq $false) { # while complete status is false
    if (($counter -ge [int]($fileList.Count)) -and ([int]$activeThreads -lt 1)) {$complete = $true;break} # set complete status to true if max file count has been reached and number of active threads is less than 1
    $activeThreads = get-threads
    if (($activeThreads -lt $maxThreads) -and ($counter -lt [int]($fileList.Count))) { # test if there are less than the max set threads and if more files need to be copied
        Start-Job -name $fileList[$counter].FullName -ScriptBlock {Copy-Item -path $args[0] -Destination $args[1]} -ArgumentList $fileList[$counter].FullName,$dst | out-null
        $counter++
    }
    sleep 1 # pause one second before starting next copy
    completed-threads # remove completed threads
}

error-threads # create error report