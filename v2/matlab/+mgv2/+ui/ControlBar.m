classdef ControlBar < matlab.ui.componentcontainer.ComponentContainer
    %CONTROLBAR Mission commands, scenario choice and clock readout. It only emits requests; it never touches the engine.
    %   bar.OnCommand = @(cmd) ...   cmd: "start" | "pause" | "resume" | "abort" | "reset"
    %   bar.OnConfigure = @(scenario, seed) ...   a new scenario or mission seed was chosen; offered only before a start
    %   REPLAY and EXPORT stay disabled: they belong to V2-008 and are not implemented here.
    properties
        OnCommand = []
        OnConfigure = []
    end
    properties (SetAccess = private, Transient, NonCopyable)
        Buttons; Readout; ScenarioDropdown; SeedField; ReplayButton; ExportButton
    end
    methods
        function present(obj, view, running)
            %PRESENT Show phase and clock; enable only the commands valid in the engine's current state.
            p = view.pose; txt = sprintf('%s | t_sim %.2f s | tick %d | run %s | seed %d | scenario: %s', p.phase, p.t_s, p.tick_id, view.mission.run_id, view.mission.seed, view.scenario);
            if ~strcmp(obj.Readout.Text, txt), obj.Readout.Text = txt; end
            s = view.state;
            en = struct('start', s == "READY" && ~running, 'pause', s == "ACTIVE", 'resume', s == "PAUSED" && ~running, ...
                'abort', s == "ACTIVE" || s == "PAUSED", 'reset', ~running && s ~= "READY");
            for f = string(fieldnames(en))'
                st = matlab.lang.OnOffSwitchState(en.(f));
                if obj.Buttons.(f).Enable ~= st, obj.Buttons.(f).Enable = st; end
            end
            st = matlab.lang.OnOffSwitchState(en.start);
            if obj.ScenarioDropdown.Enable ~= st, obj.ScenarioDropdown.Enable = st; obj.SeedField.Enable = st; end
            if obj.SeedField.Value ~= view.mission.seed, obj.SeedField.Value = view.mission.seed; end
            if string(obj.ScenarioDropdown.Value) ~= view.scenario, obj.ScenarioDropdown.Value = view.scenario; end
        end
    end
    methods (Access = protected)
        function setup(obj)
            t = mgv2.ui.theme();
            obj.BackgroundColor = t.bg;
            g = uigridlayout(obj, [2 10], 'ColumnWidth', {112, 70, 76, 70, 70, 150, 32, 60, 100, 100}, 'RowHeight', {'1x', 20}, 'Padding', [4 2 4 2], ...
                'ColumnSpacing', 4, 'RowSpacing', 2, 'BackgroundColor', t.bg);
            names = ["start","pause","resume","abort","reset"]; caps = ["START SIMULATION","PAUSE","RESUME","ABORT","RESET"];
            for k = 1:5
                c = names(k);
                obj.Buttons.(c) = uibutton(g, 'Text', caps(k), 'FontSize', 11, 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) obj.emit(c));
            end
            obj.ScenarioDropdown = uidropdown(g, 'Items', mgv2.ui.MissionSession.Scenarios, 'FontSize', 11, 'Tooltip', 'Scenario, before START', 'ValueChangedFcn', @(~, ~) obj.emitConfigure());
            uilabel(g, 'Text', 'seed', 'FontColor', t.text, 'FontSize', 11, 'HorizontalAlignment', 'right');
            obj.SeedField = uieditfield(g, 'numeric', 'Limits', [0 Inf], 'RoundFractionalValues', 'on', 'ValueDisplayFormat', '%d', 'FontSize', 11, ...
                'Tooltip', 'Mission seed, before START', 'ValueChangedFcn', @(~, ~) obj.emitConfigure());
            obj.ReplayButton = uibutton(g, 'Text', 'REPLAY (V2-008)', 'FontSize', 10, 'Enable', 'off', 'Tooltip', 'Not implemented: pending V2-008');
            obj.ExportButton = uibutton(g, 'Text', 'EXPORT (V2-008)', 'FontSize', 10, 'Enable', 'off', 'Tooltip', 'Not implemented: pending V2-008');
            obj.Readout = uilabel(g, 'Text', '', 'FontColor', t.text, 'FontName', t.mono, 'FontSize', 11, 'FontWeight', 'bold');
            obj.Readout.Layout.Row = 2; obj.Readout.Layout.Column = [1 10];
        end
        function update(~)
        end
    end
    methods (Access = private)
        function emit(obj, cmd)
            if ~isempty(obj.OnCommand), obj.OnCommand(cmd); end
        end
        function emitConfigure(obj)
            if ~isempty(obj.OnConfigure), obj.OnConfigure(string(obj.ScenarioDropdown.Value), obj.SeedField.Value); end
        end
    end
end
