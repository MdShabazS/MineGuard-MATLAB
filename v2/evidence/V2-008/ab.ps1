# Alternating paced UI_R100 missions: V2-007 final (rel, 095d7fb) and V2-008 (b8, bddb4c2), one fresh MATLAB each.
$r = 'C:\Users\rahil\Documents\MineGuard-V2-007-close'; $out = "$r\bench8\ab_r100.jsonl"
$w = Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"$r\b8\v2\evidence\V2-76-performance\host_watch.ps1",'-Seconds','3600','-Out',"$r\bench8\ab_r100.host.csv" -WindowStyle Hidden -PassThru
foreach ($k in 1..3) {
  foreach ($t in @(@('rel','v2007_095d7fb'), @('b8','v2008_bddb4c2'))) {
    $before = @(Get-Process MATLAB -ErrorAction SilentlyContinue).Id
    $cmd = "try, addpath('$r'); ab_one('$r\$($t[0])', '$($t[1])', '$out'); catch ME, disp(getReport(ME)); end; exit"
    $p = Start-Process 'C:\Program Files\MATLAB\R2026b\bin\win64\MATLAB.exe' -ArgumentList '-logfile', "`"$r\bench8\ab_$k_$($t[1]).log`"", '-r', "`"$cmd`"" -PassThru
    Start-Sleep -Seconds 15; $p.WaitForExit()
    while (Get-Process MATLAB -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id }) { Start-Sleep -Seconds 10 }
  }
}
Stop-Process -Id $w.Id -Force -ErrorAction SilentlyContinue
"done" | Out-File "$r\bench8\ab_done.txt"
