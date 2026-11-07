function T = d1_haloSweep()
%D1_HALOSWEEP Exploratory synthetic frames only. Frozen detector measurement against experimental background forms.
base = uint8(120 * ones(240, 320, 3)) + uint8(randi(RandStream('mrg32k3a', 'Seed', 1), [0 4], [240 320 3]));
[U, V] = meshgrid(1:320, 1:240); m = true(240, 320); gsd = 0.0747;   % gsd of the d26 frame: 0.60 m / 8 px
rows = {}; 
for dn = [100 80 40]
    for r = [3 4 5 6 8 10 12 15]
        d = hypot(U - 200, V - 120) <= r; I = base;
        for c = 1:3, ch = I(:,:,c); ch(d) = dn; I(:,:,c) = ch; end
        contrast = (122 - dn) / 255; ringPred = contrast * nnz(d) / 961; ctr = struct();
        for vv = ["FROZEN_FORM","POLARITY_SPLIT","CLIPPED"]
            C = mgv2x.detect.rgbResidualCandidates(double(I) / 255, m, vv);
            near = hypot(C.u_px - 200, C.v_px - 120) <= r + 3;
            if any(near), a = max(C.area_px(near)); else, a = 0; end
            ctr.(vv) = 2 * sqrt(a / pi) * gsd; ctr.(vv + "_n") = numel(C.u_px);
        end
        rows(end+1, :) = {dn, r, 2 * sqrt(nnz(d) / pi) * gsd, ringPred * 255, ctr.FROZEN_FORM, ctr.POLARITY_SPLIT, ctr.CLIPPED, ctr.FROZEN_FORM_n, ctr.POLARITY_SPLIT_n, ctr.CLIPPED_n}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', ["disc_dn","radius_px","true_d_m","halo_dn_predicted","frozen_d_m","polsplit_d_m","clipped_d_m","frozen_n","polsplit_n","clipped_n"]);
% smooth-background negative control: no object at all
g = uint8(repmat(reshape(linspace(90, 150, 320), 1, []), 240, 1, 3)) + uint8(randi(RandStream('mrg32k3a', 'Seed', 2), [0 4], [240 320 3]));
for vv = ["FROZEN_FORM","POLARITY_SPLIT","CLIPPED"]
    fprintf('negative control, ramp and noise, %s: %d candidates\n', vv, numel(mgv2x.detect.rgbResidualCandidates(double(g) / 255, m, vv).u_px));
end
% two nearby discs: does the clipped form still separate them
I = base; d = hypot(U - 200, V - 120) <= 6 | hypot(U - 225, V - 120) <= 6; for c = 1:3, ch = I(:,:,c); ch(d) = 40; I(:,:,c) = ch; end
for vv = ["FROZEN_FORM","POLARITY_SPLIT","CLIPPED"]
    C = mgv2x.detect.rgbResidualCandidates(double(I) / 255, m, vv); fprintf('two 6 px discs 25 px apart, %s: %d components, largest %d px (one disc is %d px)\n', vv, numel(C.u_px), max([C.area_px; 0]), nnz(hypot(U - 200, V - 120) <= 6));
end
end
