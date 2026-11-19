function site = siteConfig(file)
%SITECONFIG Load and check the V2.2 site file (v2_2/config/bitm_site.json, decided in V22-T3).
%   site = mgv22.siteConfig()          the committed BITM site file
%   site = mgv22.siteConfig(file)      another file with the same schema (tests)
%   Every coordinate, credit and label of the satellite view comes from this file; nothing is hard-coded.
%   The anchor is a PRESENTATION point (altitude 0 = no approved altitude), not a survey point.
if nargin < 1
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % .../v2_2
    file = fullfile(root, 'config', 'bitm_site.json');
end
id = 'mgv22:InvalidSiteConfig';
if ~isfile(file), error(id, 'Site file not found: %s', file); end
s = jsondecode(fileread(file));
need = ["schema","anchor_lla","view_window","basemap","service_url","credit_text","banner","virtual_label", ...
    "offline_fallback","offline_label","commit_imagery_allowed","forbidden_on_imagery"];
missing = need(~isfield(s, need));
if ~isempty(missing), error(id, 'Site file is missing: %s.', strjoin(missing, ', ')); end
if string(s.schema) ~= "mg-v22-site/1.0", error(id, 'Unknown site schema "%s".', string(s.schema)); end
a = double(s.anchor_lla(:)');
if numel(a) ~= 3 || any(~isfinite(a)), error(id, 'anchor_lla must be [lat lon alt].'); end
lat = double(s.view_window.lat(:)'); lon = double(s.view_window.lon(:)');
if numel(lat) ~= 2 || numel(lon) ~= 2 || lat(1) >= lat(2) || lon(1) >= lon(2) || a(1) <= lat(1) || a(1) >= lat(2) || a(2) <= lon(1) || a(2) >= lon(2)
    error(id, 'view_window must be [min max] in lat and lon and contain the anchor.');
end
if ~islogical(s.commit_imagery_allowed) || s.commit_imagery_allowed
    error(id, 'commit_imagery_allowed must be false (V22-T3: no imagery in the public repository).');
end
txt = ["credit_text","banner","virtual_label","service_url","offline_fallback","offline_label","basemap"];
for f = txt
    if strlength(string(s.(f))) == 0, error(id, '%s must not be empty.', f); end
end
site = struct('anchor_lla', a, 'view_window', struct('lat', lat, 'lon', lon), 'basemap', string(s.basemap), ...
    'service_url', string(s.service_url), 'credit_text', string(s.credit_text), 'banner', string(s.banner), ...
    'virtual_label', string(s.virtual_label), 'offline_fallback', string(s.offline_fallback), ...
    'offline_label', string(s.offline_label), 'forbidden_on_imagery', string(s.forbidden_on_imagery(:)'), 'file', string(file));
end
