classdef Launcher < handle
    %LAUNCHER V2.1 application: Mission Setup, then one RunController per LOCK & START (V21-006). SIMULATION ONLY.
    %   L = mgv21.ui.Launcher(Name=Value)   RealTime, MaxTicksPerRun, Visible, ExportRoot (see mgv21MissionControl)
    %   L.Setup        mgv21.ui.MissionSetupApp (SETUP phase)
    %   L.Controller   mgv21.ui.RunController of the launched run, [] before LOCK & START
    %   L.SiteViews    mgv22.ui.SiteViews (V22-T6): optional BITM view buttons in Mission Setup, present only when
    %                  v2_2/matlab is on the path; no view opens until a button is pressed. [] otherwise.
    %   delete(L) closes every window it opened.

    properties (SetAccess = private)
        Setup = []
        Controller = []
        SiteViews = []
        Options
    end

    methods
        function L = Launcher(opts)
            arguments
                opts.RealTime (1,1) double = 1
                opts.MaxTicksPerRun (1,1) double = inf
                opts.Visible (1,1) string = "on"
                opts.ExportRoot (1,1) string = mgv2.ui.MissionControlApp.defaultExportRoot()
                opts.SiteViewsOptions cell = {}     % name/value pairs passed to mgv22.ui.SiteViews (tests: Offline, MetadataReader)
            end
            L.Options = opts;
            L.Setup = mgv21.ui.MissionSetupApp('Visible', opts.Visible, 'OnLaunch', @(pub, world, priv) L.launch(pub, world, priv));
            L.addSiteViews();
        end

        function delete(L)
            if ~isempty(L.SiteViews) && isvalid(L.SiteViews), delete(L.SiteViews); end
            if ~isempty(L.Controller) && isvalid(L.Controller), delete(L.Controller); end
            if ~isempty(L.Setup) && isvalid(L.Setup), delete(L.Setup); end
        end
    end

    methods (Static, Access = private)
        function closeViews(sv)
            if isvalid(sv), sv.closeAll(); end
        end
    end

    methods (Access = private)
        function addSiteViews(L)
            slot = L.Setup.SiteViewsSlot;
            if exist('mgv22.ui.SiteViews', 'class') ~= 8
                uilabel(slot, 'Text', 'Add v2_2/matlab to the path for the BITM satellite views.', 'WordWrap', 'on', 'FontSize', 11);
                return
            end
            L.SiteViews = mgv22.ui.SiteViews('SessionFcn', @() L.session(), 'PubFcn', @() L.currentPub(), ...
                'Visible', L.Options.Visible, L.Options.SiteViewsOptions{:});
            L.SiteViews.addButtons(slot);
            sv = L.SiteViews;                     % closing Mission Setup with its X also closes the BITM views
            addlistener(L.Setup.Figure, 'ObjectBeingDestroyed', @(~, ~) mgv21.ui.Launcher.closeViews(sv));
        end

        function s = session(L)
            s = [];
            c = L.Controller;
            if ~isempty(c) && isvalid(c) && ~isempty(c.App) && isvalid(c.App), s = c.App.Session; end
        end

        function p = currentPub(L)
            %CURRENTPUB Public config of the running scenario, else the valid survey in Mission Setup, else [].
            p = [];
            if ~isempty(L.Controller) && isvalid(L.Controller), p = L.Controller.Pub;
            elseif ~isempty(L.Setup) && isvalid(L.Setup), p = L.Setup.Pub;
            end
        end

        function launch(L, pub, world, priv)
            if ~isempty(L.Controller) && isvalid(L.Controller), delete(L.Controller); end
            o = L.Options;
            L.Controller = mgv21.ui.RunController(pub, world, priv, 'RealTime', o.RealTime, 'MaxTicksPerRun', o.MaxTicksPerRun, ...
                'Visible', o.Visible, 'ExportRoot', o.ExportRoot);
        end
    end
end
