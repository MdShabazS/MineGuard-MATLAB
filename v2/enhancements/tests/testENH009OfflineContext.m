classdef testENH009OfflineContext < matlab.unittest.TestCase
    methods (Test)
        function noNetworkDependencies(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            source = fileread(fullfile(root, '+mgenh009', 'renderOfflineCampusContext.m'));
            banned = {'webread(', 'websave(', 'urlread(', 'urlwrite(', 'geobasemap(', ...
                'readBasemapImage(', 'imread(', 'system(', 'timer('};
            for k = 1:numel(banned)
                tc.verifyFalse(contains(source, banned{k}), banned{k});
            end
            [f, info] = mgenh009.renderOfflineCampusContext('Visible','off');
            c = onCleanup(@() closeIfOpen(f)); %#ok<NASGU>
            tc.verifyEqual(info.kind, "ORIGINAL_SCHEMATIC");
        end
        function deterministicOutput(tc)
            [a, x] = mgenh009.renderOfflineCampusContext('Visible','off');
            ca = onCleanup(@() closeIfOpen(a)); %#ok<NASGU>
            [b, y] = mgenh009.renderOfflineCampusContext('Visible','off');
            cb = onCleanup(@() closeIfOpen(b)); %#ok<NASGU>
            tc.verifyEqual(x, y);
            tc.verifyEqual(numel(findall(a,'Type','rectangle')), numel(findall(b,'Type','rectangle')));
        end
        function missingAssetFallsBack(tc)
            missing = [tempname '.png'];
            [f, info] = mgenh009.renderOfflineCampusContext('Visible','off','AssetPath',missing);
            c = onCleanup(@() closeIfOpen(f)); %#ok<NASGU>
            tc.verifyEqual(info.asset_status, "MISSING_SCHEMATIC_USED");
            tc.verifyFalse(info.georeferenced);
        end
        function truthfulLabels(tc)
            [f, info] = mgenh009.renderOfflineCampusContext('Visible','off');
            c = onCleanup(@() closeIfOpen(f)); %#ok<NASGU>
            tc.verifyEqual(info.labels, ["ILLUSTRATIVE"; "NOT SURVEYED"; "SIMULATION CONTEXT"]);
            stringsShown = string(get(findall(f,'Type','textboxshape'),'String'));
            tc.verifyTrue(any(contains(stringsShown, "ILLUSTRATIVE / NOT SURVEYED / SIMULATION CONTEXT")));
            tc.verifyEqual(info.coordinate_frame, "ARBITRARY_DIAGRAM_UNITS");
        end
        function figureCleanup(tc)
            before = numel(findall(groot,'Type','figure'));
            [f, ~] = mgenh009.renderOfflineCampusContext('Visible','off');
            tc.verifyEqual(numel(findall(groot,'Type','figure')), before+1);
            close(f);
            tc.verifyEqual(numel(findall(groot,'Type','figure')), before);
        end
    end
end

function closeIfOpen(f)
if isgraphics(f), close(f); end
end
