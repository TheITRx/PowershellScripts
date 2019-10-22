$max_jobs = 3


 foreach($hostname in $list){  
 
 write-host "`ntime for $hostname"
 $job_done = 0

    while($job_done -eq 0){    

            $running_job_count = (Get-Job | ? {$_.State -eq "Running"}).length;

            write-host "current job count is $running_job_count"

            if($running_job_count -eq $max_jobs){
                
                write-host "Max JOb reached, waiting for 5 seconds"    
                sleep 5
                $job_done = 0
            }

            else{
                
                write-host "Executing Job for $hostname"
                $job = start-job -ScriptBlock {
                param($hostname)
                $res = psexec.exe \\$hostname hostname
                $res | select -Index 5 | out-file C:\temp\hn.txt -Append 
        
                } -ArgumentList (,$hostname)

                $job_done = 1
                write-host "Done job for $hostname"

            }
    }    
} 

write-host "All jobs have been executed. Waiting for all jobs to finish..."

while ($running_job_count -gt 0){

    $running_job_count = (Get-Job | ? {$_.State -eq "Running"}).length;
    sleep 1

}

Get-Job



