function terrain = flatTerrain(z0)
%FLATTERRAIN Terrain provider with a constant ground height (metres above the ENU datum).
%   terrain = mgv2.engine.flatTerrain()      ground at z_up = 0
%   terrain = mgv2.engine.flatTerrain(z0)
%   A terrain provider is a struct with fields:
%     id        - string identifier (recorded in provenance)
%     heightAt  - function handle h = heightAt(x_east_m, y_north_m), vectorised, same size as input
%   The engine only reads ground HEIGHT (observable geometry). Hidden scenario truth (targets, labels,
%   materials) is never part of a terrain provider. V2-003 supplies a high-fidelity provider.
if nargin < 1, z0 = 0; end
terrain = struct('id', "flat-" + string(z0), 'heightAt', @(x, y) z0 + zeros(size(x)));
end
