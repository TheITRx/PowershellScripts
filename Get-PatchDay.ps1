function Get-PatchDay{
    
    <#
    .SYNOPSIS
        Get patch Tuesday
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>

param( 
[string]$month = (get-date).month, 
[string]$year = (get-date).year,
$WeekAfter = "1",
$Day = "tuesday"
) 

$firstdayofmonth = [datetime] ([string]$month + "/1/" + [string]$year)
(0..30 | % {$firstdayofmonth.adddays($_) } | ? {$_.dayofweek -like "$day"})[$Week]
 
}