function scene = toUavScenario(world, updateRate)
%TOUAVSCENARIO Export the world's terrain and objects as UAV Toolbox static meshes (for V2-005 sensors).
%   scene = mgv2.scene.toUavScenario(world)
%   scene = mgv2.scene.toUavScenario(world, updateRate)     default 20 Hz
%   Requires UAV Toolbox. The terrain triangles (world.V/world.F, identical to the rendered ones) and
%   every object mesh are added with addMesh(scene, "custom", {V, F}, color) in the default ENU frame,
%   so uavLidarPointCloudGenerator and other scenario sensors see exactly the drawn geometry.
%   Platforms are NOT added here; use mgv2.frames.poseEnuToNed for a NED uavPlatform.
if nargin < 2, updateRate = 20; end
if isempty(which('uavScenario'))
    error('mgv2:MissingToolbox', 'toUavScenario requires UAV Toolbox (uavScenario not found).');
end
scene = uavScenario("UpdateRate", updateRate, "StopTime", Inf);
addMesh(scene, "custom", {world.V, world.F}, [0.45 0.42 0.30]);
O = world.objects;
for kind = ["rock","bush","marker"]
    rows = find(O.kind == kind); Vs = zeros(0, 3); Fs = zeros(0, 3);
    for k = rows'
        [V, F] = mgv2.scene.objectMesh(O(k, :));
        Fs = [Fs; F + size(Vs, 1)]; Vs = [Vs; V]; %#ok<AGROW>
    end
    if ~isempty(Vs), addMesh(scene, "custom", {Vs, Fs}, mean(O.rgb(rows,:), 1)); end
end
end
