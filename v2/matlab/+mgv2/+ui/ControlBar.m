classdef ControlBar < matlab.ui.componentcontainer.ComponentContainer
    %CONTROLBAR Mission commands and clock readout. It only emits commands; it never touches the engine.
    %   bar.OnCommand = @(cmd) ...   cmd: "start" | "pause" | "resume" | "abort" | "reset"
    properties
        OnCommand = []
    end
    properties (SetAccess = private, Transient, NonCopyable)
        Buttons; Readout
    end
    methods
        function present(obj, view, running)
            %PRESENT Show phase and clock; enable only the commands valid in the engine's current state.
            p = view.pose; txt = sprintf('%s | t_sim %.2f s | tick %d | run %s | seed %d', p.phase, p.t_s, p.tick_id, view.mission.run_id, view.mission.seed);
            if ~strcmp(obj.Readout.Text, txt), obj.Readout.Text = txt; end
            s = view.state;
            en = struct('start', s == "READY" && ~running, 'pause', s == "ACTIVE", 'resume', s == "PAUSED" && ~running, ...
                'abort', s == "ACTIVE" || s == "PAUSED", 'reset', ~running && s ~= "READY");
            for f = string(fieldnames(en))'
                st = matlab.lang.OnOffSwitchState(en.(f));
                if obj.Buttons.(f).Enable ~= st, obj.Buttons.(f).Enable = st; end
            end
        end
    end
    methods (Access = protected)
        function setup(obj)
            t = mgv2.ui.theme();
            obj.BackgroundColor = t.bg;
            g = uigridlayout(obj, [1 6], 'ColumnWidth', {112, 70, 76, 70, 70, '1x'}, 'RowHeight', {'1x'}, 'Padding', [4 2 4 2], ...
                'ColumnSpacing', 4, 'BackgroundColor', t.bg);
            names = ["start","pause","resume","abort","reset"]; caps = ["START SIMULATION","PAUSE","RESUME","ABORT","RESET"];
            for k = 1:5
                c = names(k);
                obj.Buttons.(c) = uibutton(g, 'Text', caps(k), 'FontSize', 11, 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) obj.emit(c));
            end
            obj.Readout = uilabel(g, 'Text', '', 'FontColor', t.text, 'FontName', t.mono, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
        end
        function update(~)
        end
    end
    methods (Access = private)
        function emit(obj, cmd)
            if ~isempty(obj.OnCommand), obj.OnCommand(cmd); end
        end
    end
end
