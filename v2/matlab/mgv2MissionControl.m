function app = mgv2MissionControl(varargin)
%MGV2MISSIONCONTROL Integrated mission-control dashboard (V2-007 Stage 1 UI). SIMULATION ONLY.
%   Synthetic sensors on a synthetic scene: no real flight, sensor feed, detection or hazard map.
%   app = mgv2MissionControl                 opens the window at tick 0; press START SIMULATION
%   app = mgv2MissionControl('RealTime', 0)  run as fast as possible (default 1 = paced to 1x wall time)
%   app = mgv2MissionControl('RenderEvery', 4, 'MaxTicksPerRun', 200, 'Palette', "WHITE_HOT", 'Visible', "off")
%   app = mgv2MissionControl('SensorConfig', cfg, 'Environment', env, 'AnomalySource', src)
%   delete(app) or closing the window releases everything.
%
%   From the repository root:  addpath('v2/matlab'); mgv2MissionControl
args = varargin;
for k = 1:2:numel(args) - 1, args{k} = char(args{k}); end
app = mgv2.ui.MissionControlApp(args{:});
end
