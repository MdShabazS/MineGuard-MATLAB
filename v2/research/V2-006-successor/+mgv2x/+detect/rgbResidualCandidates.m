function C = rgbResidualCandidates(I, m, variant)
%RGBRESIDUALCANDIDATES EXPERIMENTAL RGB candidate components. NOT the frozen detector and not used by any application.
%   C = mgv2x.detect.rgbResidualCandidates(I, m, variant)    identity "MGV2X-RGB-RESIDUAL/0.1-exploratory"
%   I        H-by-W-by-3 double image in [0, 1]; m  H-by-W logical valid mask
%   variant  "FROZEN_FORM"    same residual, scale, threshold and labelling form as mgv2.detect.frameCandidates
%            "POLARITY_SPLIT" same residual; pixels brighter and darker than the background are labelled separately
%            "CLIPPED"        two passes: candidate pixels of pass 1, grown by 2 px, leave the background of pass 2
%   C        struct of column vectors u_px, v_px, area_px, peak_z, polarity
%   Constants match the frozen configuration (window 31 px, z 4, support 0.6) so that only the stated form changes.
%   Nothing here has been tuned or evaluated. A difference on an exploratory fixture says nothing about accuracy.
arguments
    I (:,:,3) double
    m (:,:) logical
    variant (1,1) string {mustBeMember(variant, ["FROZEN_FORM","POLARITY_SPLIT","CLIPPED"])}
end
w = 31; zThr = 4; minSup = 0.6;
[z, lum, sup] = residual(I, m, m, w);
cand = m & sup >= minSup & z > zThr;
if variant == "CLIPPED"
    k = ones(5); grown = conv2(double(cand), k, 'same') > 0;
    [z, lum] = residual(I, m, m & ~grown, w, sup);     % support stays that of the sample: masking is not missing data
    cand = m & sup >= minSup & z > zThr;
end
if variant == "POLARITY_SPLIT"
    C = merge(components(cand & lum > 0, z, 1), components(cand & lum <= 0, z, -1));
else
    C = components(cand, z, 0, lum);
end
end

function [z, lum, sup] = residual(I, m, bg, w, supIn)
k = ones(1, w) / w; den = conv2(k, k, double(bg), 'same'); sup = den; [H, W, ~] = size(I);
if nargin > 4, sup = supIn; end
z2 = zeros(H, W); lum = zeros(H, W); lw = [0.2126 0.7152 0.0722];
for c = 1:3
    a = I(:,:,c); b = a; b(~bg) = 0; mu = conv2(k, k, b, 'same') ./ max(den, eps);
    if nargin > 4, r0 = a(bg); mu(den < 1e-9) = median(r0(:)); end      % a window with no background left: frame median
    r = a - mu;
    v = r(m & sup >= 0.6); v = v(1:4:end);
    s = max(1.4826 * median(abs(v - median(v))), 2 / 255);
    z2 = z2 + (r / s) .^ 2; lum = lum + lw(c) * r;
end
z = sqrt(z2 / 3);
end

function C = components(cand, z, pol, lum)
[L, n] = mgv2.detect.labelComponents(cand);
C = struct('u_px', zeros(0, 1), 'v_px', zeros(0, 1), 'area_px', zeros(0, 1), 'peak_z', zeros(0, 1), 'polarity', zeros(0, 1));
if n == 0, return; end
idx = find(L); lab = L(idx); w = z(idx); [v, u] = ind2sub(size(L), idx); sw = accumarray(lab, w);
C.u_px = accumarray(lab, w .* u) ./ sw; C.v_px = accumarray(lab, w .* v) ./ sw; C.area_px = accumarray(lab, 1);
C.peak_z = accumarray(lab, w, [], @max);
if nargin > 3, C.polarity = sign(accumarray(lab, sign(lum(idx)) .* w)); else, C.polarity = pol * ones(n, 1); end
end

function C = merge(A, B)
C = A; for f = string(fieldnames(A))', C.(f) = [A.(f); B.(f)]; end
end
