function src = basemapSource(basemap, metadataReader)
%BASEMAPSOURCE Credits and honest availability status for the selected preview basemap.
%   metadataReader is injectable for offline tests; only satellite requests World Imagery metadata.
%   Metadata reachability never establishes that any map tile loaded.
basemap = string(basemap);
if ~isscalar(basemap) || ~ismember(basemap,["satellite","topographic","streets-light","darkwater"])
    error('mgv2:InvalidBasemap', 'Unsupported preview basemap.');
end
if nargin < 2
    metadataReader = @(url) webread(url,weboptions('Timeout',3,'ContentType','json'));
end
if basemap == "darkwater"
    src = struct('credit',"Basemap: darkwater, created using Natural Earth and installed with MATLAB. A display backdrop, not imagery.", ...
        'status',"Local basemap: no internet needed. Live satellite tiles are not available in this mode.", ...
        'credit_source',"MATHWORKS_DOCUMENTATION",'metadata_status',"NOT_APPLICABLE",'tile_status',"LOCAL_BASEMAP", ...
        'link_text',"MathWorks basemap source information",'url',"https://www.mathworks.com/help/matlab/ref/geobasemap.html");
    return
end
if basemap ~= "satellite"
    src = struct('credit',"Basemap: " + basemap + " | Powered by Esri. Sources vary by area and zoom; retain the map's own source credits.", ...
        'status',"Basemap " + basemap + " selected; metadata not queried; tiles unverified. Check visible map credits; offline: ENU.", ...
        'credit_source',"MAP_NATIVE",'metadata_status',"NOT_QUERIED",'tile_status',"UNVERIFIED", ...
        'link_text',"MathWorks basemap source information",'url',"https://www.mathworks.com/help/matlab/ref/geobasemap.html");
    return
end
service = "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer";
pinned = "Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community";
credit = pinned; creditSource = "PINNED_2026_11_02"; metadataStatus = "UNAVAILABLE";
try
    info = metadataReader(service + "?f=json");
    if isstruct(info) && isfield(info,'copyrightText')
        live = string(info.copyrightText);
        if isscalar(live) && ~ismissing(live) && strlength(strtrim(live)) > 0
            credit = live; creditSource = "LIVE_SERVICE"; metadataStatus = "AVAILABLE";
        end
    end
catch
    % Leave pinned credits and an explicit metadata-unavailable status.
end
src = struct('credit',"Basemap: satellite | Powered by Esri | " + credit, ...
    'status',"World Imagery metadata " + lower(metadataStatus) + "; satellite tile loading unverified. Offline: use ENU map.", ...
    'credit_source',creditSource,'metadata_status',metadataStatus,'tile_status',"UNVERIFIED", ...
    'link_text',"Esri World Imagery service and source credits",'url',service);
end
