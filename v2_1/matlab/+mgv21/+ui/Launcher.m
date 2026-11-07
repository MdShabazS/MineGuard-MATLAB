classdef Launcher < handle
    %LAUNCHER V2.1 application: Mission Setup, then one RunController per LOCK & START (V21-006). SIMULATION ONLY.
    %   L = mgv21.ui.Launcher(Name=Value)   RealTime, MaxTicksPerRun, Visible, ExportRoot (see mgv21MissionControl)
    %   L.Setup        mgv21.ui.MissionSetupApp (SETUP phase)
    %   L.Controller   mgv21.ui.RunController of the launched run, [] before LOCK & START
    %   delete(L) closes every window it opened.

    properties (SetAccess = private)
        Setup = []
        Controller = []
        Options
    end

    methods
        function L = Launcher(opts)
            arguments
                opts.RealTime (1,1) double = 1
                opts.MaxTicksPerRun (1,1) double = inf
                opts.Visible (1,1) string = "on"
                opts.ExportRoot (1,1) string = mgv2.ui.MissionControlApp.defaultExportRoot()
            end
            L.Options = opts;
            L.Setup = mgv21.ui.MissionSetupApp('Visible', opts.Visible, 'OnLaunch', @(pub, world, priv) L.launch(pub, world, priv));
        end

        function delete(L)
            if ~isempty(L.Controller) && isvalid(L.Controller), delete(L.Controller); end
            if ~isempty(L.Setup) && isvalid(L.Setup), delete(L.Setup); end
        end
    end

    methods (Access = private)
        function launch(L, pub, world, priv)
            if ~isempty(L.Controller) && isvalid(L.Controller), delete(L.Controller); end
            o = L.Options;
            L.Controller = mgv21.ui.RunController(pub, world, priv, 'RealTime', o.RealTime, 'MaxTicksPerRun', o.MaxTicksPerRun, ...
                'Visible', o.Visible, 'ExportRoot', o.ExportRoot);
        end
    end
end
