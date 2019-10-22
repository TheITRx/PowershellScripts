function Check-Memory
{
    [OutputType('ConnectionType:Default')]
    [OutputType('ExecutionType:Multiple')]
    [CmdletBinding(DefaultParameterSetName="Single")]
    [CmdletBinding(SupportsShouldProcess=$false)]
    param(
        [Parameter(ParameterSetName="Single", Mandatory=$false)][Alias("W")][Alias("Warn")]
        [float]$Warning,

        [Parameter(ParameterSetName="Single", Mandatory=$true)][Alias("C")][Alias("Crit")]
        [float]$Critical,

        [Parameter(ParameterSetName="Single", Mandatory=$false)][Alias("P")][Alias("Pct")]
        [switch]$Percent,

        [Parameter(ParameterSetName="Single", Mandatory=$true)][String]$Id,

        [Parameter(ParameterSetName="Multiple", Mandatory=$true)]
        $Info = @{}
    )

    switch($PSCmdlet.ParameterSetName){
        "Multiple"{
            Write-Verbose "Finding Multiple"
            $results = @()
            $info.GetEnumerator() | %{
                $id = $_.Name
                $params = $_.Value
                $params['Id'] = $id
                $result = Get-Memory @params
                $results += $result
            }
            $results
        }
        default {
            Get-Memory @PSBoundParameters
        }
    }
}

function Get-Memory
{
    param(
        [Parameter(Mandatory=$false)][Alias("W")][Alias("Warn")]
        [float]$Warning,

        [Parameter(Mandatory=$true)][Alias("C")][Alias("Crit")]
        [float]$Critical,

        [Parameter(Mandatory=$false)][Alias("P")][Alias("Pct")]
        [switch]$Percent,

        [Parameter(Mandatory=$true)][String]$Id
    )

    $IPmonState     = @{"OK"="0";"WARNING"="1";"CRITICAL"="2";"UNKNOWN"="3"};
    $IPmonResult    = New-Object PSObject -Property @{ StdOut = ""; StdErr = ""; RetCode = ""; Id="" }
    $IPmonResult.Id = $id;

    $counters  = @("\Memory\Available Bytes","\Memory\Available MBytes","\Memory\Cache Bytes")
    $lcounters = @()

    ForEach ($counter in $counters) {
        $perfcounterid = Get-PerformanceCounterID -Name $counter.split('\')[2]
        $perfcountername = Get-PerformanceCounterLocalName -Id $perfcounterid
        $perfobjectid = Get-PerformanceCounterID -Name $counter.split('\')[1]
        $perfobjectname = Get-PerformanceCounterLocalName -Id $perfobjectid
        $lcounters += "\$($perfobjectname)\$($perfcountername)"
    }
    
    $samples   = Get-Counter -Counter $lcounters | Select-Object -Expand CounterSamples | % { $h = @{} } { $h[$_.Path] = $_ } { $h }
    $resultB   = [int64]$samples[$("\\" + $($env:COMPUTERNAME) + $lcounters[0])].CookedValue
    $resultMB  = [int64]$samples[$("\\" + $($env:COMPUTERNAME) + $lcounters[1])].CookedValue
    $cache     = [int64]$samples[$("\\" + $($env:COMPUTERNAME) + $lcounters[2])].CookedValue
    $physical  = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory
    $physicalF = [Math]::Round($physical/1MB,2)

    if ($Percent)
    {
        $resultPct= ($resultMB / $physicalF ) * 100;
        $availableMem= [Math]::Round($resultPct,2)
        $threshold   = " [Warning: $($warning)% Critical: $($critical)%]"
    }
    else{
        $availableMem=$resultMB
        $threshold   = " [Warning: $($warning)MB Critical: $($critical)MB]"
    }


    if($availableMem -le $critical){
        $state = $IPmonState.Critical
        $m     = "CRITICAL:"
    }elseif($availableMem -le $warning){
        $state = $IPmonState.Warning
        $m     = "WARNING:"
     }else{
        $state = $IPmonState.OK
        $m     = "OK:"
    }

    $message   = "$m Available Mbytes: $($resultMB)MB Total:$($physicalF)MB"
    $message  += $threshold


    $perfData  = " | memory_free=$($resultB)B;$warning;$critical"
    $perfData += " memory_total=$($physical)B"
    $perfData += " memory_cached=$($cache)B"

    $message            += $perfData
    $IPmonResult.StdOut  = $message
    $IPmonResult.RetCode = $state
    $IPmonResult
    <#
    .SYNOPSIS
    Checks the current system memory
    .DESCRIPTION
    Checks the current system memory against warning and critical parameters using performance counters
    .PARAMETER Warning
    The warning value in MB  to compare
    .PARAMETER Critical
    The critical value in MB to compare
    .PARAMETER Percent
    warning and critical value in Percent to compare
    .INPUTS
    This check accepts no pipeline input
    .OUTPUTS
    IPmonCheck Status Object
    .EXAMPLE
    check-memory -warning 512 -critical 10
    .COMPONENT
    Windows
    .NOTES
    #>
}


Function Get-PerformanceCounterLocalName
{
    param(
        [UInt32]$ID,
        $ComputerName = $env:COMPUTERNAME
    )

    # If the remote CI has Visual Studio installed it can cause this function to fail due to $env:LIB being set.  To fix this we clear the lib env varible for this specific powershell session
    $env:LIB = ''

    $code = '[DllImport("pdh.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern UInt32 PdhLookupPerfNameByIndex(string szMachineName, uint dwNameIndex, System.Text.StringBuilder szNameBuffer, ref uint pcchNameBufferSize);'
    $t = Add-Type -MemberDefinition $code -PassThru -Name PerfCounter -Namespace Utility

    $Buffer = New-Object System.Text.StringBuilder(1024)
    [UInt32]$BufferSize = $Buffer.Capacity

    $rv = $t::PdhLookupPerfNameByIndex($ComputerName, $id, $Buffer, [Ref]$BufferSize)

    if ($rv -eq 0){
        $Buffer.ToString().Substring(0, $BufferSize-1)
    }else{
        Throw 'Get-PerformanceCounterLocalName : Unable to retrieve localized name. Check computer name and performance counter ID.'
    }
}

function Get-PerformanceCounterID
{
    param(
        [Parameter(Mandatory=$true)]
        $Name
    )

    $key = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\009'
    $counters = (Get-ItemProperty -Path $key -Name Counter -ErrorAction SilentlyContinue).Counter
    
    
    # If we still can't find we'll Throw a error
    if ($counters -eq $null) {
        Throw 'Get-PerformanceCounterID : Unable to retrieve counter ID.'
    }
    
    $CounterID = $counters[$([array]::indexof($counters,$Name)-1)]
    return $CounterID
}

Export-ModuleMember -Function Check-*

