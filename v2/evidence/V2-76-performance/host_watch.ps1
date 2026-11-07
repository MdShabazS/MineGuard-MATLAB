param([int]$Seconds = 240, [string]$Out)
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class W { [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int p); }
"@
"t_utc,perf_pct,freq_mhz,cpu_busy_pct,fg_process,matlab_cpu_s,ac,power_scheme" | Set-Content $Out
$end = (Get-Date).AddSeconds($Seconds)
$scheme = (powercfg /getactivescheme) -replace '.*\((.*)\).*','$1'
while ((Get-Date) -lt $end) {
  $c = Get-Counter -ErrorAction SilentlyContinue '\Processor Information(_Total)\% Processor Performance','\Processor Information(_Total)\Processor Frequency','\Processor Information(_Total)\% Processor Time'
  $v = $c.CounterSamples | ForEach-Object { [math]::Round($_.CookedValue, 1) }
  $p = 0; [void][W]::GetWindowThreadProcessId([W]::GetForegroundWindow(), [ref]$p); $n = (Get-Process -Id $p -ErrorAction SilentlyContinue).ProcessName
  $m = (Get-Process MATLAB -ErrorAction SilentlyContinue | Measure-Object CPU -Sum).Sum
  $b = (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue).BatteryStatus
  "$((Get-Date).ToUniversalTime().ToString('HH:mm:ss')),$($v[0]),$($v[1]),$($v[2]),$n,$([int]$m),$b,$scheme" | Add-Content $Out
  Start-Sleep -Seconds 3
}
