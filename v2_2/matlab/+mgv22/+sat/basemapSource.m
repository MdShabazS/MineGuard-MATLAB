function src = basemapSource(basemap, site, metadataReader)
%BASEMAPSOURCE Credits and honest availability status for the satellite view's basemap.
%   src = mgv22.sat.basemapSource(basemap, site)
%   src = mgv22.sat.basemapSource(basemap, site, metadataReader)   injectable reader for offline tests
%   Ported from the retired c3c12af v2/matlab/+mgv2/+geo/basemapSource.m (V22-T4). Credits for "satellite" are
%   read live from the Esri service (copyrightText); if that fails, the pinned text from the site file is used and
%   the status says the service is unavailable. Metadata reachability never proves that any map tile loaded.
basemap = string(basemap);
if ~isscalar(basemap) || ~ismember(basemap, ["satellite","topographic","streets-light","darkwater"])
    error('mgv22:InvalidBasemap', 'Unsupported basemap.');
end
if nargin < 3 || isempty(metadataReader)
    metadataReader = @(url) webread(url, weboptions('Timeout', 3, 'ContentType', 'json'));
end
docs = "https://www.mathworks.com/help/matlab/ref/geobasemap.html";
if basemap == "darkwater"
    src = struct('credit', "Basemap: darkwater, created using Natural Earth and installed with MATLAB. A display backdrop, not imagery.", ...
        'status', "Local basemap: no internet needed. Live satellite tiles are not shown in this mode.", ...
        'credit_source', "MATHWORKS_DOCUMENTATION", 'metadata_status', "NOT_APPLICABLE", 'tile_status', "LOCAL_BASEMAP", ...
        'link_text', "MathWorks basemap source information", 'url', docs);
    return
end
if basemap ~= "satellite"
    src = struct('credit', "Basemap: " + basemap + " | Powered by Esri. Sources vary by area and zoom; keep the map's own source credits.", ...
        'status', "Basemap " + basemap + " selected; metadata not queried; tiles unverified.", ...
        'credit_source', "MAP_NATIVE", 'metadata_status', "NOT_QUERIED", 'tile_status', "UNVERIFIED", ...
        'link_text', "MathWorks basemap source information", 'url', docs);
    return
end
pinned = extractAfter(site.credit_text, "Powered by Esri | ");
if ismissing(pinned) || strlength(pinned) == 0, pinned = site.credit_text; end
credit = pinned; creditSource = "PINNED_SITE_FILE"; metadataStatus = "UNAVAILABLE";
try
    info = metadataReader(site.service_url + "?f=json");
    if isstruct(info) && isscalar(info) && isfield(info, 'copyrightText') && (ischar(info.copyrightText) || isstring(info.copyrightText))
        live = string(info.copyrightText);
        if isscalar(live) && ~ismissing(live) && strlength(strtrim(live)) > 0
            credit = live; creditSource = "LIVE_SERVICE"; metadataStatus = "AVAILABLE";
        end
    end
catch
    % keep the pinned credits and an explicit "unavailable" status
end
if metadataStatus == "AVAILABLE"
    status = "World Imagery service reachable; satellite tile loading unverified.";
else
    status = "Satellite unavailable: the Esri World Imagery service could not be reached. Map tiles may be blank; credits shown from the site file.";
end
src = struct('credit', "Basemap: satellite | Powered by Esri | " + credit, 'status', status, ...
    'credit_source', creditSource, 'metadata_status', metadataStatus, 'tile_status', "UNVERIFIED", ...
    'link_text', "Esri World Imagery service and source credits", 'url', site.service_url);
end
