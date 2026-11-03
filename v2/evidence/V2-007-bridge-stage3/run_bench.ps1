param([string]$Repo, [string]$Out, [ValidateSet('paced','diag')][string]$Plan = 'paced', [ValidateSet('normal','highqos')][string]$Priority = 'normal')
# Starts one fresh MATLAB for one plan and logs host load beside the results. Priority is applied and recorded, never assumed.
# The launcher starts a separate worker process, so high QoS must go to every MATLAB process started by this run.
$SP = Split-Path $MyInvocation.MyCommand.Path
$s = $SP -replace '\\','/'; $r = $Repo -replace '\\','/'; $o = $Out -replace '\\','/'
$cmd = "try, addpath('$s'); pause(30); bench_stage('$r','$o','$Plan','$Priority'); catch ME, disp(getReport(ME)); end; exit"
$before = @(Get-Process MATLAB -ErrorAction SilentlyContinue).Id
$w = Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$Repo\v2\evidence\V2-76-performance\host_watch.ps1`"",'-Seconds','7200','-Out',"`"$Out.host.csv`"" -WindowStyle Hidden -PassThru
$p = Start-Process 'C:\Program Files\MATLAB\R2026b\bin\win64\MATLAB.exe' -ArgumentList '-logfile', "`"$Out.log`"", '-r', "`"$cmd`"" -PassThru
Start-Sleep -Seconds 15
foreach ($x in Get-Process MATLAB | Where-Object { $before -notcontains $_.Id }) {
  if ($Priority -eq 'highqos') { "$($x.Id): " + (& "$Repo\v2\evidence\V2-76-performance\qos2.ps1" -ProcessId $x.Id -Action highqos) }
  "$($x.Id) priority class: $($x.PriorityClass) requested: $Priority" | Add-Content "$Out.priority.txt"
}
# The launcher can exit before its worker, so wait until every MATLAB started by this run has gone.
$p.WaitForExit()
while (Get-Process MATLAB -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id }) { Start-Sleep -Seconds 10 }
Stop-Process -Id $w.Id -Force -ErrorAction SilentlyContinue
Get-Content "$Out.log" | Select-String -Pattern '^\d+ |DONE|Error' | ForEach-Object { $_.Line }
