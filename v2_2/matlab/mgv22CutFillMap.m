function v = mgv22CutFillMap(opts)
%MGV22CUTFILLMAP Open the cut/fill map over BITM on a SIMULATED drone LiDAR survey (V22-T9).
%   From the repository root:  mineguard_setup; addpath('v2_2/matlab'); v = mgv22CutFillMap();
%   v = mgv22CutFillMap(Outline=polyENU, MaxTicks=n, Theme="light")
%   The first call flies the simulated survey (about a minute) and caches the surface in tempdir.
%   Elevations are SIMULATED TERRAIN of the virtual field placed at the BITM anchor, not BITM's real ground.
arguments
    opts.Outline double = zeros(0, 2)
    opts.MaxTicks (1,1) double {mustBePositive} = inf
    opts.Theme (1,1) string {mustBeMember(opts.Theme, ["dark","light"])} = "dark"
    opts.Visible (1,1) string {mustBeMember(opts.Visible, ["on","off"])} = "on"
end
S = mgv22.cutfill.surveySurface(MaxTicks=opts.MaxTicks);
v = mgv22.cutfill.CutFillView(S, Theme=opts.Theme, Visible=opts.Visible);
if ~isempty(opts.Outline), v.setOutline(opts.Outline); end
end
