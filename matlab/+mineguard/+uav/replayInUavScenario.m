function [scene, loggedEnu] = replayInUavScenario(poses)
%REPLAYINUAVSCENARIO Drive a UAV Toolbox uavScenario platform with a PoseSample log (MG-005).
%   [scene, loggedEnu] = mineguard.uav.replayInUavScenario(poses)
%
%   Adapter only: ENU poses are converted to the platform's NED frame with enuToNed. The
%   platform is moved sample by sample with move/advance, and the position read back is
%   converted to ENU again. The returned uavScenario can be shown with show3D(scene).
%   Kinematic replay of the simulated poses; not a flight-dynamics or autopilot model.
if ~istable(poses) || height(poses) < 1
    error('mineguard:InvalidNavigationInput', 'MineGuard UAV adapter: poses must be a nonempty PoseSample table.');
end
dts = diff(poses.t_s);
rate = 10;
if ~isempty(dts)
    rate = 1 / median(dts);
end
scene = uavScenario('UpdateRate', rate, 'StopTime', Inf);
platform = uavPlatform('MineGuardUAV', scene);
updateMesh(platform, 'quadrotor', {0.5}, [0 0.4 0.8], eye(4));
setup(scene);

posNed = mineguard.uav.enuToNed([poses.x_east_m poses.y_north_m poses.z_up_m]);
headingNed = pi/2 - poses.yaw_rad;              % ENU yaw (from east, CCW) -> NED heading (from north, CW)
loggedNed = zeros(height(poses), 3);
for k = 1:height(poses)
    q = [cos(headingNed(k)/2) 0 0 sin(headingNed(k)/2)];
    move(platform, [posNed(k,:) zeros(1,6) q zeros(1,3)]);
    m = read(platform);
    loggedNed(k,:) = m(1:3);
    advance(scene);
end
loggedEnu = mineguard.uav.enuToNed(loggedNed);   % self-inverse
end
