param([int]$ProcessId, [string]$Action)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Q2 { [StructLayout(LayoutKind.Sequential)] public struct S { public uint Version, ControlMask, StateMask; }
 [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint a, bool i, int p);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetProcessInformation(IntPtr h, int c, ref S s, int n); }
"@
$p = Get-Process -Id $ProcessId; $h = [Q2]::OpenProcess(0x1F0FFF, $false, $ProcessId)
$t = New-Object Q2+S; $t.Version = 1
switch ($Action) {
  "highqos" { $t.ControlMask = 1; $t.StateMask = 0; "highqos: $([Q2]::SetProcessInformation($h, 4, [ref]$t, 12))" }
  "pcores"  { $p.ProcessorAffinity = [IntPtr]0x0FFF; "affinity now $((Get-Process -Id $ProcessId).ProcessorAffinity)" }
  "restore" { $t.ControlMask = 0; $t.StateMask = 0; "system-managed: $([Q2]::SetProcessInformation($h, 4, [ref]$t, 12))"; $p.ProcessorAffinity = [IntPtr]0xFFFF; "affinity now $((Get-Process -Id $ProcessId).ProcessorAffinity)" }
}
