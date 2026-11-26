classdef SiteViews < handle
    %SITEVIEWS Optional V2.2 BITM views opened from the V2.1 mission-control app (V22-T6). SIMULATION ONLY.
    %   sv = mgv22.ui.SiteViews(SessionFcn=@() session, PubFcn=@() pub, Visible="on", MetadataReader=[], Offline=false)
    %   sv.addButtons(parent)   four buttons in a uigridlayout/panel: Satellite view, Field survey, Cut/fill map, Relief
    %   sv.openSatellite()      T4 preview + T5 VIRTUAL overlay following the running session (reset, new run, replay)
    %   sv.openFieldSurvey()    T11 view (watermark, hollow SUSPECTED symbols, evaluation toggle unchanged)
    %   sv.openCutFill()        T9 view on the simulated survey of the running session's preset
    %   sv.openRelief()         T9 view on the "Relief vs local trend" layer (T12), 0.5 m grid, SYNTHETIC demo features
    %   sv.closeAll(), delete(sv)   close every view and stop the follow timer; nothing is left behind
    %   sv.poll()               one follow step (the timer calls it every 0.25 s while the satellite view is open)
    %   Nothing opens at construction. Before each view the imagery service is checked once (basemapSource); if it
    %   is unreachable, or Offline=true, the ENH-009 schematic opens instead, labelled ILLUSTRATIVE / NOT SURVEYED /
    %   SIMULATION CONTEXT, with a notice: never a blank map presented as imagery.
    %   The overlay reads only the session's public pose (tick_id, position_enu_m) and the public mission config; the
    %   mission loop is never subscribed to, so an open view costs the mission no per-tick work.

    properties (SetAccess = private)
        Satellite = []      % mgv22.sat.SatellitePreview
        Overlay = []        % mgv22.sat.MissionOverlay
        FieldSurvey = []    % mgv22.field.FieldSurveyView
        CutFill = []        % mgv22.cutfill.CutFillView (cut/fill layer)
        Relief = []         % mgv22.cutfill.CutFillView (relief layer)
        Fallback = []       % figure of the ENH-009 schematic
        FallbackNotice = ""
        Buttons = []        % struct of the four uibuttons after addButtons
        Timer = []
        LastStatus = ""
        FollowedEngine = []     % engine object followed; reset, new run and replay each build a new one
        Restarts = 0            % trails restarted because the session's engine changed
        FollowedKey = ""
    end
    properties (Access = private)
        SessionFcn
        PubFcn
        Visible
        MetadataReader
        Offline
    end

    methods
        function obj = SiteViews(opts)
            arguments
                opts.SessionFcn = @() []
                opts.PubFcn = @() []
                opts.Visible (1,1) string {mustBeMember(opts.Visible, ["on","off"])} = "on"
                opts.MetadataReader = []
                opts.Offline (1,1) logical = false
            end
            obj.SessionFcn = opts.SessionFcn; obj.PubFcn = opts.PubFcn; obj.Visible = opts.Visible;
            obj.MetadataReader = opts.MetadataReader; obj.Offline = opts.Offline;
        end

        function addButtons(obj, parent)
            g = uigridlayout(parent, [2 2], 'RowHeight', {26, 26}, 'ColumnWidth', {'1x', '1x'}, 'Padding', 0, ...
                'RowSpacing', 3, 'ColumnSpacing', 4, 'Tag', 'mgv22_site_views');
            if isprop(parent, 'BackgroundColor'), g.BackgroundColor = parent.BackgroundColor; end
            b = struct();
            b.satellite = uibutton(g, 'Text', 'Satellite view (BITM)', 'Tag', 'mgv22_open_satellite', 'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.openSatellite()));
            b.field = uibutton(g, 'Text', 'Field survey (BITM)', 'Tag', 'mgv22_open_field', 'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.openFieldSurvey()));
            b.cutfill = uibutton(g, 'Text', 'Cut/fill map (BITM)', 'Tag', 'mgv22_open_cutfill', 'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.openCutFill()));
            b.relief = uibutton(g, 'Text', 'Relief map (BITM)', 'Tag', 'mgv22_open_relief', 'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.openRelief()));
            obj.Buttons = b;
        end

        function openSatellite(obj)
            if ~isempty(obj.Satellite) && obj.Satellite.isOpen(), figure(obj.Satellite.Figure); return; end
            if obj.goOffline("Satellite view"), return; end
            obj.Satellite = mgv22.sat.SatellitePreview(MetadataReader=obj.MetadataReader);
            obj.Satellite.open(Visible=obj.Visible);
            obj.Satellite.Figure.CloseRequestFcn = @(~, ~) obj.closeSatellite();
            obj.FollowedEngine = []; obj.FollowedKey = "";
            obj.poll();
            obj.Timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.25, 'BusyMode', 'drop', ...
                'Tag', 'mgv22_site_views_follow', 'TimerFcn', @(~, ~) obj.timerStep());
            start(obj.Timer);
            obj.LastStatus = "Satellite view open (VIRTUAL route on real imagery)";
        end

        function openFieldSurvey(obj)
            if ~isempty(obj.FieldSurvey) && isvalid(obj.FieldSurvey) && obj.FieldSurvey.isOpen(), return; end
            if obj.goOffline("Field survey"), return; end
            obj.FieldSurvey = mgv22.field.FieldSurveyView(Visible=obj.Visible, MetadataReader=obj.MetadataReader);
            obj.LastStatus = "Field survey open";
        end

        function openCutFill(obj)
            if ~isempty(obj.CutFill) && isvalid(obj.CutFill) && obj.CutFill.isOpen(), return; end
            if obj.goOffline("Cut/fill map"), return; end
            S = mgv22.cutfill.surveySurface(Preset=obj.presetId());
            obj.CutFill = mgv22.cutfill.CutFillView(S, Visible=obj.Visible, MetadataReader=obj.MetadataReader);
            obj.LastStatus = "Cut/fill map open (" + obj.presetId() + ")";
        end

        function openRelief(obj)
            if ~isempty(obj.Relief) && isvalid(obj.Relief) && obj.Relief.isOpen(), return; end
            if obj.goOffline("Relief map"), return; end
            S = mgv22.cutfill.surveySurface(Preset=obj.presetId(), CellM=0.5);
            [S, ~] = mgv22.relief.injectFeatures(S, mgv22.relief.defaultFeatureSpec());   % answer key discarded
            obj.Relief = mgv22.cutfill.CutFillView(S, Visible=obj.Visible, MetadataReader=obj.MetadataReader);
            obj.Relief.setLayer("Relief vs local trend");
            obj.LastStatus = "Relief map open (" + obj.presetId() + ", SYNTHETIC demo features)";
        end

        function poll(obj)
            %POLL Follow the session: rebuild the overlay for a new mission, restart the trail on reset/new run.
            if isempty(obj.Satellite) || ~obj.Satellite.isOpen(), return; end
            pub = obj.currentPub();
            if isempty(pub)
                if ~isempty(obj.Overlay), delete(obj.Overlay); obj.Overlay = []; end
                obj.FollowedKey = ""; return
            end
            key = string(mgv2.run.digest(pub.mission));
            if key ~= obj.FollowedKey
                if ~isempty(obj.Overlay) && isvalid(obj.Overlay), delete(obj.Overlay); end
                obj.Overlay = mgv22.sat.MissionOverlay(obj.Satellite, pub);
                obj.FollowedKey = key; obj.FollowedEngine = [];
            end
            ses = obj.currentSession();
            if isempty(ses), return; end
            eng = ses.Engine;
            if isempty(obj.FollowedEngine) || ~isvalid(obj.FollowedEngine) || eng ~= obj.FollowedEngine
                if ~isempty(obj.FollowedEngine), obj.Restarts = obj.Restarts + 1; end
                obj.FollowedEngine = eng;                  % reset / new run / replay: start a new trail
                obj.Overlay.restart();
            end
            p = ses.pose();
            pose = struct('tick_id', double(p.tick_id), 'position_enu_m', double(p.position_enu_m(:)'));
            if pose.tick_id ~= obj.Overlay.LastTick, obj.Overlay.update(pose); end
        end

        function closeSatellite(obj)
            obj.stopTimer();
            if ~isempty(obj.Overlay) && isvalid(obj.Overlay), delete(obj.Overlay); end
            obj.Overlay = [];
            if ~isempty(obj.Satellite) && isvalid(obj.Satellite), delete(obj.Satellite); end
            obj.Satellite = [];
        end

        function closeAll(obj)
            obj.closeSatellite();
            for f = ["FieldSurvey", "CutFill", "Relief"]
                v = obj.(f); if ~isempty(v) && isvalid(v), delete(v); end
                obj.(f) = [];
            end
            if ~isempty(obj.Fallback) && isgraphics(obj.Fallback), delete(obj.Fallback); end
            obj.Fallback = [];
        end

        function n = openCount(obj)
            n = double(~isempty(obj.Satellite) && obj.Satellite.isOpen()) + double(~isempty(obj.Fallback) && isgraphics(obj.Fallback));
            for f = ["FieldSurvey", "CutFill", "Relief"]
                v = obj.(f); n = n + double(~isempty(v) && isvalid(v) && v.isOpen());
            end
        end

        function delete(obj)
            obj.closeAll();
        end
    end

    methods (Access = private)
        function tf = goOffline(obj, what)
            %GOOFFLINE If imagery is unreachable (or Offline), show the ENH-009 schematic with a notice instead.
            tf = obj.Offline;
            if ~tf
                src = mgv22.sat.basemapSource("satellite", mgv22.siteConfig(), obj.MetadataReader);
                tf = src.metadata_status == "UNAVAILABLE";
            end
            if ~tf, return; end
            obj.FallbackNotice = what + ": satellite imagery unavailable (no network or service unreachable). " + ...
                "Showing the ILLUSTRATIVE / NOT SURVEYED / SIMULATION CONTEXT schematic instead.";
            if isempty(obj.Fallback) || ~isgraphics(obj.Fallback)
                obj.Fallback = mgenh009.renderOfflineCampusContext('Visible', char(obj.Visible));
                obj.Fallback.Name = 'MineGuard V2.2 - BITM views OFFLINE (illustrative schematic)';
                obj.Fallback.Tag = 'mgv22_offline_fallback';
                annotation(obj.Fallback, 'textbox', [0.03 0.0 0.94 0.1], 'String', char(obj.FallbackNotice), ...
                    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.38 0.16 0.10], ...
                    'Tag', 'mgv22_offline_notice');
            else
                figure(obj.Fallback);
            end
            obj.LastStatus = obj.FallbackNotice;
        end

        function ses = currentSession(obj)
            ses = [];
            try ses = obj.SessionFcn(); catch, ses = []; end
            if ~isempty(ses) && ~(isobject(ses) && isvalid(ses)), ses = []; end
        end

        function pub = currentPub(obj)
            pub = [];
            try pub = obj.PubFcn(); catch, pub = []; end
        end

        function id = presetId(obj)
            pub = obj.currentPub(); id = "TRAINING_FIELD_A";
            if isstruct(pub) && isfield(pub, 'preset_id'), id = string(pub.preset_id); end
        end

        function timerStep(obj)
            if ~isvalid(obj), return; end
            try
                obj.poll();
            catch err
                obj.LastStatus = "Satellite follow stopped: " + string(err.message);
                obj.stopTimer();
            end
        end

        function stopTimer(obj)
            t = obj.Timer; obj.Timer = [];
            if ~isempty(t) && isvalid(t), stop(t); delete(t); end
        end

        function guard(obj, fcn)
            try
                fcn();
            catch err
                obj.LastStatus = "Could not open the view: " + string(err.message);
                uialert(ancestor(obj.Buttons.satellite, 'figure'), char(obj.LastStatus), 'BITM views (V2.2)');
            end
        end
    end
end
