param([string]$Repo, [string]$Out)
# The launcher starts a separate worker process, so high QoS must go to every MATLAB process started by this run.
$SP = Split-Path $MyInvocation.MyCommand.Path
$s = $SP -replace '\\','/'; $r = $Repo -replace '\\','/'; $o = $Out -replace '\\','/'
$cmd = "try, addpath('$s'); pause(30); bench_stage('$r','$o'); catch ME, disp(getReport(ME)); end; exit"
$before = (Get-Process MATLAB).Id
$p = Start-Process 'C:\Program Files\MATLAB\R2026b\bin\win64\MATLAB.exe' -ArgumentList '-logfile', "`"$Out.log`"", '-r', "`"$cmd`"" -PassThru
Start-Sleep -Seconds 15
foreach ($x in Get-Process MATLAB | Where-Object { $before -notcontains $_.Id }) { "$($x.Id): " + (& "$Repo\v2\evidence\V2-76-performance\qos2.ps1" -ProcessId $x.Id -Action highqos) }
$p.WaitForExit()
Get-Content "$Out.log" | Select-String -Pattern '^\d+ |DONE|Error' | ForEach-Object { $_.Line }
