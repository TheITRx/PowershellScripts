<#
.SYNOPSIS
    Script to block idle time in your computer. There are instances where you don't want it to sleep or lock (Setting that was pushed by GPO).
    This thing simulates the period or dot . button being pressed in your keyboard. 
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

param($minutes = 60)

$myshell = New-Object -com "Wscript.Shell"

for ($i = 0; $i -lt $minutes; $i++) {
    Start-Sleep -Seconds 60
    $myshell.sendkeys(".")
}