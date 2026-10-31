function report = mineguard_environment_check()
% MINEGUARD_ENVIRONMENT_CHECK Inspect MATLAB installation without changing it.
% Run from MATLAB Command Window after cloning the GitHub repo:
%   addpath(fullfile(pwd,'matlab')); report = mineguard_environment_check;
% Copy sanitized output into GitHub tasks/evidence/MG-002.md. No licences or secrets.
fprintf('\n================ MineGuard MATLAB Environment Check ================\n');
report = struct();
report.release = version('-release');
report.platform = computer;
report.timestampUTC = char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss Z'));
fprintf('MATLAB release: %s\n',report.release);
fprintf('Platform: %s\n',report.platform);
fprintf('Checked (UTC): %s\n',report.timestampUTC);
products=ver;
required = {'MATLAB','Simulink','UAV Toolbox','Reinforcement Learning Toolbox', ...
    'Sensor Fusion and Tracking Toolbox','Deep Learning Toolbox','Stateflow'};
report.products = struct('name',{},'installed',{},'version',{});
fprintf('\nProduct inventory (installation only; licence access is a separate check):\n');
for i=1:numel(required)
    name=required{i};
    index=find(strcmpi({products.Name},name),1);
    found=~isempty(index);
    if found
        productVersion=products(index).Version;
        fprintf('  FOUND   %-36s %s\n',name,productVersion);
    else
        productVersion='';
        fprintf('  MISSING %-36s\n',name);
    end
    report.products(end+1)=struct('name',name,'installed',found,'version',productVersion); %#ok<AGROW>
end
functions={'uavScenario','waypointTrajectory','rlPPOAgent','uifigure','sim','trainNetwork'};
report.functions=struct('name',{},'available',{});
fprintf('\nKey function availability:\n');
for i=1:numel(functions)
    functionName=functions{i};
    available=~isempty(which(functionName));
    fprintf('  %-7s %s\n',ternary(available,'FOUND','MISSING'),functionName);
    report.functions(end+1)=struct('name',functionName,'available',available); %#ok<AGROW>
end
report.matlabSmokeTest=false;
try
    rng(2026,'twister');
    x=sum([1 2 3]);
    assert(x==6);
    report.matlabSmokeTest=true;
    fprintf('\nMATLAB computation smoke test: PASS\n');
catch ME
    fprintf('\nMATLAB computation smoke test: FAIL (%s)\n',ME.message);
end
fprintf('NOTE: An installed toolbox may still be unusable without an active licence.\n');
fprintf('NOTE: This check does not run Simulink/UAV/RL or train a model.\n');
fprintf('NEXT: Verify missing products with student account and installer; then test Claude Code MCP.\n');
fprintf('====================================================================\n\n');
end
function output=ternary(condition,yes,no)
if condition
    output=yes;
else
    output=no;
end
end
