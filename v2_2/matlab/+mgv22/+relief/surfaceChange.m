function C = surfaceChange(before, after, thresholdM)
%SURFACECHANGE Difference map between two surveys of the same grid: where soil was eroded or deposited (V22-T12).
%   C = mgv22.relief.surfaceChange(before, after)            threshold 0.15 m
%   C = mgv22.relief.surfaceChange(before, after, thresholdM)
%   C.dZ = after.Z - before.Z (NaN where either is NaN); C.eroded = dZ <= -threshold; C.deposited = dZ >= threshold;
%   C.moved = eroded | deposited; C.eroded_area_m2, C.deposited_area_m2, C.moved_area_m2 (cells*cell_m^2);
%   C.threshold_m; C.label. Moved soil is INDIRECT EVIDENCE that mines could have moved, never a location of mines.
%   Grids of different size -> error 'mgv22:InvalidRelief'.
if nargin < 3, thresholdM = 0.15; end
if ~isequal(size(before.Z), size(after.Z)) || numel(before.x) ~= numel(after.x) || numel(before.y) ~= numel(after.y)
    error('mgv22:InvalidRelief', 'Before and after surfaces must share the same grid.');
end
if ~(isscalar(thresholdM) && isfinite(thresholdM) && thresholdM > 0)
    error('mgv22:InvalidRelief', 'thresholdM must be finite and positive.');
end
A = before.cell_m^2;
C.dZ = after.Z - before.Z;
C.eroded = C.dZ <= -thresholdM;
C.deposited = C.dZ >= thresholdM;
C.moved = C.eroded | C.deposited;
C.eroded_area_m2 = nnz(C.eroded)*A;
C.deposited_area_m2 = nnz(C.deposited)*A;
C.moved_area_m2 = nnz(C.moved)*A;
C.threshold_m = thresholdM;
C.label = "INDIRECT EVIDENCE – soil moved, mines could have moved (SIMULATION)";
end
