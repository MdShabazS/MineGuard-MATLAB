function app = openMissionApp(runBundle)
%OPENMISSIONAPP Open the MineGuard mission-replay dashboard (frozen mg-contract/1.0 API, MG-011).
%   app = mineguard.app.openMissionApp(runBundle)
%   runBundle - a REDACTED view bundle, normally built with mineguard.app.makeRunBundle from a
%               real precomputed MG-004/005/007/009 run. It is validated BEFORE any UI is
%               created; invalid input throws mineguard:InvalidRunBundle and no mock UI is shown.
%   app       - mineguard.app.MissionApp handle (a programmatic uifigure app). Methods include
%               play, pause, step, seek, reset, setSpeed, exportRun, viewState and close.
%   SIMULATION ONLY: replays synthetic data. The app controls no hardware and displays only
%   SUSPECTED events.
mineguard.app.validateRunBundle(runBundle);
app = mineguard.app.MissionApp(runBundle);
end
