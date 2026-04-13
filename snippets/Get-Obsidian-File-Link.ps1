# insert in windows $PROFILE file (ie. Microsoft.PowerShell_profile.ps1)
Function Get-Path($file_path)
{
    $outStr = "file:\\" + $(python3 -c 'import sys,os; print(os.path.realpath(sys.argv[1]));' $file_path)
    $outStr = $outStr -replace '\s','%20'
    Write-Output $outStr
}
