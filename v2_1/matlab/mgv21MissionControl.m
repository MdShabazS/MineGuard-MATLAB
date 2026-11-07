function L = mgv21MissionControl(varargin)
%MGV21MISSIONCONTROL MineGuard V2.1: set up a synthetic mission, place private virtual targets, fly, then evaluate. SIMULATION ONLY.
%   L = mgv21MissionControl              opens Mission Setup; LOCK & START opens the V2 dashboard for that scenario
%   L = mgv21MissionControl('RealTime', 0, 'MaxTicksPerRun', 400, 'ExportRoot', folder, 'Visible', "off")
%   L.Setup, L.Controller                the setup window and, after LOCK & START, the run (mgv21.ui.Launcher)
%   From the repository root:  addpath('v2/matlab'); addpath('v2_1/matlab'); mgv21MissionControl
%   The original V2 entry point mgv2MissionControl is unchanged.
%   Targets are private synthetic hypotheses: hidden during the flight, revealed only in the post-run EVALUATION view.
args = varargin;
for k = 1:2:numel(args) - 1, args{k} = char(args{k}); end
L = mgv21.ui.Launcher(args{:});
end
