classdef testENH010Storyboard < matlab.unittest.TestCase
    methods (Test)
        function deterministicState(tc)
            first = mgenh010.advanceStoryboard([],"RESET");
            tc.verifyEqual(first,"CITY_CONTEXT");
            tc.verifyEqual(mgenh010.advanceStoryboard(first,"NEXT"),"CAMPUS_CONTEXT");
            tc.verifyEqual(mgenh010.advanceStoryboard(first,"NEXT"),mgenh010.advanceStoryboard(first,"NEXT"));
        end
        function transitionsAreBounded(tc)
            tc.verifyEqual(mgenh010.advanceStoryboard("CITY_CONTEXT","BACK"),"CITY_CONTEXT");
            tc.verifyEqual(mgenh010.advanceStoryboard("CAMPUS_CONTEXT","NEXT"),"SIMULATION_HANDOFF");
            tc.verifyEqual(mgenh010.advanceStoryboard("SIMULATION_HANDOFF","NEXT"),"SIMULATION_HANDOFF");
            tc.verifyEqual(mgenh010.advanceStoryboard("SIMULATION_HANDOFF","BACK"),"CAMPUS_CONTEXT");
            tc.verifyError(@() mgenh010.advanceStoryboard("UNKNOWN","NEXT"),'mgenh010:InvalidStoryboard');
        end
        function labelsAndBoundary(tc)
            stages = ["CITY_CONTEXT","CAMPUS_CONTEXT","SIMULATION_HANDOFF"];
            for stage = stages
                [f,info] = mgenh010.renderStoryboardFrame(stage,'Visible','off');
                cleanup = onCleanup(@() closeIfOpen(f)); %#ok<NASGU>
                tc.verifyFalse(info.georeferenced);
                tc.verifyFalse(info.mission_started);
                tc.verifyTrue(isgraphics(f));
                if stage == "CAMPUS_CONTEXT"
                    tc.verifyEqual(info.kind,"ORIGINAL_SCHEMATIC");
                    tc.verifyTrue(contains(info.label,"NOT SURVEYED"));
                else
                    tc.verifyEqual(info.kind,"ORIGINAL_TITLE_CARD");
                    tc.verifyTrue(strlength(info.label)>0);
                end
                close(f);
            end
        end
        function graphicsCleanup(tc)
            before = numel(findall(groot,'Type','figure'));
            for k = 1:3
                [f,~] = mgenh010.renderStoryboardFrame("CAMPUS_CONTEXT",'Visible','off');
                close(f);
                [f,~] = mgenh010.renderStoryboardFrame("SIMULATION_HANDOFF",'Visible','off');
                close(f);
            end
            tc.verifyEqual(numel(findall(groot,'Type','figure')),before);
        end
        function noOnlineOrMissionDependency(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            source = [fileread(fullfile(root,'+mgenh010','advanceStoryboard.m')) ...
                fileread(fullfile(root,'+mgenh010','renderStoryboardFrame.m'))];
            for name = {'webread(', 'websave(', 'geobasemap(', 'readBasemapImage(', 'MissionEngine(', 'timer('}
                tc.verifyFalse(contains(source,name{1}),name{1});
            end
        end
    end
end
function closeIfOpen(f)
if isgraphics(f), close(f); end
end
