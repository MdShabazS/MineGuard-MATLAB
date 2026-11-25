function v = mgv22CutFillMap(opts)
%MGV22CUTFILLMAP Open the cut/fill map over BITM on a SIMULATED drone LiDAR survey (V22-T9).
%   From the repository root:  mineguard_setup; addpath('v2_2/matlab'); v = mgv22CutFillMap();
%   v = mgv22CutFillMap(Outline=polyENU, MaxTicks=n, Theme="light", DemoFeatures=true, CellM=0.5)
%   DemoFeatures=true adds SYNTHETIC craters, foxhole-size pits and a trench (mgv22.relief.injectFeatures) so the
%   Relief vs local trend layer has something to show. CellM is the survey grid (default 1 m; 0.5 m with DemoFeatures,
%   because a 1.2 m foxhole or a 1 m wide trench cannot be resolved on a 1 m grid).
%   The first call flies the simulated survey (about a minute) and caches the surface in tempdir.
%   Elevations are SIMULATED TERRAIN of the virtual field placed at the BITM anchor, not BITM's real ground.
arguments
    opts.Outline double = zeros(0, 2)
    opts.MaxTicks (1,1) double {mustBePositive} = inf
    opts.Theme (1,1) string {mustBeMember(opts.Theme, ["dark","light"])} = "dark"
    opts.Visible (1,1) string {mustBeMember(opts.Visible, ["on","off"])} = "on"
    opts.DemoFeatures (1,1) logical = false
    opts.CellM double {mustBeScalarOrEmpty, mustBePositive} = []
end
cell_m = opts.CellM;
if isempty(cell_m), cell_m = 1 - 0.5 * opts.DemoFeatures; end
S = mgv22.cutfill.surveySurface(MaxTicks=opts.MaxTicks, CellM=cell_m);
if opts.DemoFeatures
    [S, ~] = mgv22.relief.injectFeatures(S, mgv22.relief.defaultFeatureSpec());
end
v = mgv22.cutfill.CutFillView(S, Theme=opts.Theme, Visible=opts.Visible);
if ~isempty(opts.Outline), v.setOutline(opts.Outline); end
end
