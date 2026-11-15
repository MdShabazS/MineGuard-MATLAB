function report = mineguard_setup()
%MINEGUARD_SETUP Add the MineGuard MATLAB folders to the path and report missing toolboxes (docs/SETUP.md).
%   mineguard_setup              run from anywhere; uses the folder this file is in as the repository root
%   report = mineguard_setup()   struct: root, release, missing_required, missing_optional
%   Adds matlab/, v2/matlab and v2_1/matlab. It installs nothing and changes no saved path.
root = fileparts(mfilename('fullpath'));
for p = ["matlab", fullfile("v2", "matlab"), fullfile("v2_1", "matlab")]
    addpath(fullfile(root, p));
end
v = ver; installed = string({v.Name});
required = "UAV Toolbox";
optional = ["Reinforcement Learning Toolbox", "Deep Learning Toolbox"];
report = struct('root', string(root), 'release', string(version('-release')), ...
    'missing_required', setdiff(required, installed), 'missing_optional', setdiff(optional, installed));
fprintf('MineGuard root: %s\nMATLAB release: R%s (tested: R2026b)\n', report.root, report.release);
if isempty(report.missing_required)
    fprintf('Required toolboxes: OK\n');
else
    fprintf('MISSING required: %s\n', strjoin(report.missing_required, ', '));
end
if ~isempty(report.missing_optional)
    fprintf('Optional (V1 PPO demo only), not installed: %s\n', strjoin(report.missing_optional, ', '));
end
end
