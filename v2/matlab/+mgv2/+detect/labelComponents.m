function [L, n] = labelComponents(M)
%LABELCOMPONENTS 8-connected component labels of a logical mask, base MATLAB (no Image Processing Toolbox).
%   [L, n] = mgv2.detect.labelComponents(M)    L(i,j) in 0..n; labels ordered by each component's first
%   pixel in column-major order. Edges join 8-neighbouring true pixels; components = conncomp of that graph.
[H, W] = size(M); L = zeros(H, W); n = 0;
idx = find(M); if isempty(idx), return; end
pos = zeros(H, W); pos(idx) = 1:numel(idx);
[r, c] = ind2sub([H W], idx); e1 = zeros(0, 1); e2 = zeros(0, 1);
for d = [1 0; 0 1; 1 1; -1 1]'                    % down, right, down-right, up-right (each pair once)
    rr = r + d(1); cc = c + d(2); ok = rr >= 1 & rr <= H & cc >= 1 & cc <= W;
    nb = zeros(size(idx)); nb(ok) = pos(rr(ok) + (cc(ok) - 1) * H);
    j = nb > 0; e1 = [e1; find(j)]; e2 = [e2; nb(j)]; %#ok<AGROW>
end
bins = conncomp(graph(e1, e2, [], numel(idx)))';
[~, first] = unique(bins, 'first'); [~, ord] = sort(first); rank = zeros(max(bins), 1); rank(ord) = 1:numel(ord);
L(idx) = rank(bins); n = numel(ord);
end
