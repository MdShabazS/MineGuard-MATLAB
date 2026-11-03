function L = validateMapLayers(L)
%VALIDATEMAPLAYERS Check V2-006 overlay layers before MapPanel draws them. All geometry is local ENU metres.
%   L = mgv2.ui.validateMapLayers(L)   L: empty or struct array with fields
%     id, display_name, kind, revision, color, x_enu_m, y_enu_m, and for kind "raster" also cdata, alpha.
%     kind: "points" | "polyline" | "polygon" (x/y equal-length vectors) | "raster" (x/y grid vectors).
%     A layer is redrawn only when its revision changes. Unobserved ground must stay absent, not coloured:
%     alpha 0 in a raster. Raster cdata is numel(y)-by-numel(x)-by-3 and alpha numel(y)-by-numel(x), in [0, 1].
id = 'mgv2:InvalidMapLayer';
if isempty(L), L = struct([]); return; end
if ~isstruct(L), error(id, 'Layers must be a struct array.'); end
need = ["id","display_name","kind","revision","color","x_enu_m","y_enu_m"];
miss = setdiff(need, string(fieldnames(L))');
if ~isempty(miss), error(id, 'Layer is missing field "%s".', miss(1)); end
mgv2.sensors.assertPublic(L, "mapLayer");
for k = 1:numel(L)
    if ~ismember(string(L(k).kind), ["points","polyline","polygon","raster"]), error(id, 'Unknown layer kind "%s".', string(L(k).kind)); end
    if ~isempty(regexp(char(L(k).display_name), '\<(SAFE|CLEARED|CONFIRMED|DETECTED|VERIFIED)\>', 'once', 'ignorecase'))
        error(id, 'Layer name "%s" uses a forbidden claim.', string(L(k).display_name));
    end
    if string(L(k).kind) == "raster"
        if ~isfield(L, 'cdata') || ~isfield(L, 'alpha'), error(id, 'Raster layer "%s" needs cdata and alpha.', string(L(k).id)); end
        n = [numel(L(k).y_enu_m) numel(L(k).x_enu_m)]; a = L(k).alpha;
        if ~isequal(size(L(k).cdata), [n 3]) || ~isequal(size(a), n) || any(a(:) < 0 | a(:) > 1 | isnan(a(:)))
            error(id, 'Raster layer "%s": cdata or alpha does not match its grid.', string(L(k).id));
        end
    elseif numel(L(k).x_enu_m) ~= numel(L(k).y_enu_m)
        error(id, 'Layer "%s": x_enu_m and y_enu_m differ in length.', string(L(k).id));
    end
end
end
