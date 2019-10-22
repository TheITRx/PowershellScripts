for /F "tokens=*" %%A in (list.txt) do (
   	PsExec \\%%A hostname
)