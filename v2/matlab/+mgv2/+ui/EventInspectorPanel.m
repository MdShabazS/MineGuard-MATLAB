classdef EventInspectorPanel < mgv2.ui.PanelBase
    %EVENTINSPECTORPANEL Lists validated SuspectedEvents and shows verified evidence of the selected one.
    %   Until a detector exists it says so and lists none. Scores are shown as uncalibrated model scores.
    %   Selecting a row calls OnSelect(event_id). Evidence comes only from showInspection; on any failure the panel
    %   shows the error and no image. A selected event can leave the list because tracks merge, and it then says so.
    properties (Constant)
        MaxEventAge_s = 5     % events older than this on the simulation clock are flagged
    end
    properties
        OnSelect = []
    end
    properties (SetAccess = private, Transient, NonCopyable)
        Table; Body; Detail; DetailText; RgbAxes; ThermalAxes
    end
    properties (SetAccess = private)
        SelectedId = ""
    end
    properties (Access = private)
        Shown; ShownKey = NaN; Expanded = false
    end
    methods
        function present(obj, view)
            n = numel(view.events);
            if strlength(view.overlay_error) > 0
                obj.setStatus("ANOMALY OUTPUT REJECTED, NOT SHOWN: " + view.overlay_error, "INVALID");
            elseif view.source.connected
                txt = sprintf("%s | detector %s | %d SUSPECTED event(s)", view.source.status_text, view.source.detector_version, n); state = "VALID";
                if isfield(view.source, 'events_as_of_t_s') && isfinite(view.source.events_as_of_t_s)
                    age = view.pose.t_s - view.source.events_as_of_t_s; txt = sprintf("%s | age %.1f s", txt, age);
                    if age > obj.MaxEventAge_s, state = "STALE"; end
                end
                obj.setStatus(txt, state);
            else
                obj.setStatus(view.source.status_text, "INVALID");
            end
            k = view.overlay_key;
            if ~isnan(k) && isequal(k, obj.ShownKey), return; end       % the source says nothing changed
            obj.ShownKey = k;
            if isequal(obj.Shown, view.events), return; end
            obj.Shown = view.events; ev = view.events; D = cell(n, 7);
            for j = 1:n
                e = ev(j);
                D(j, :) = {char(string(e.event_id)), e.t_s, e.x_est_m, e.y_est_m, e.model_score, e.uncertainty_m, char(string(e.status))};
            end
            obj.Table.Data = D;
            if strlength(obj.SelectedId) > 0
                r = []; if n > 0, r = find(string({ev.event_id}) == obj.SelectedId); end
                if isscalar(r), obj.Table.Selection = r; else, obj.Table.Selection = []; obj.setDetail(obj.SelectedId + " is no longer in the current detector output. Tracks can merge, which removes an event id. Select another event."); obj.clearCrops(); end
            end
        end
        function resetDisplay(obj)
            obj.Shown = []; obj.ShownKey = NaN; obj.Table.Data = cell(0, 7); obj.clearSelection();
        end
        function setExpanded(obj, tf)
            setExpanded@mgv2.ui.PanelBase(obj, tf); obj.Expanded = tf;
            if tf, obj.Body.ColumnWidth = {'1x', '1.3x'}; obj.Detail.Visible = 'on'; else, obj.Body.ColumnWidth = {'1x', 0}; obj.Detail.Visible = 'off'; end
        end
        function clearSelection(obj)
            obj.SelectedId = ""; obj.Table.Selection = []; obj.setDetail("Select an event to see its evidence."); obj.clearCrops();
        end
        function select(obj, eventId)
            %SELECT Mark one event as selected, by its public id.
            obj.SelectedId = string(eventId); r = [];
            if ~isempty(obj.Shown), r = find(string({obj.Shown.event_id}) == obj.SelectedId); end
            obj.Table.Selection = r;
        end
        function showInspection(obj, ins)
            it = ins.items; u = ins.uncertainty_m;
            lines = [sprintf("%s | %s | SIMULATED", ins.event_id, ins.status)
                sprintf("Sighted t = %.2f to %.2f s", ins.time_window_s)
                sprintf("Estimated ENU: %.2f, %.2f m", ins.estimated_enu_m(1:2))
                sprintf("Uncertainty (uncalibrated): %.2f m", u)
                "Model score: " + ins.score_text + ", not a probability"
                "Sensors with evidence: " + strjoin(string(ins.sensors_used), ", ")
                "Missing or invalid: " + strjoin([string(ins.missing_modalities(:)); repmat("none", isempty(ins.missing_modalities), 1)], "; ")
                sprintf("%d evidence record(s), checksums verified against the sensor log", numel(it))];
            obj.setDetail(strjoin(lines, newline));
            obj.drawCrop(obj.RgbAxes, it, "RGB_NADIR"); obj.drawCrop(obj.ThermalAxes, it, "THERMAL_LWIR");
        end
        function showInspectionError(obj, eventId, message)
            obj.setDetail(sprintf("EVIDENCE NOT AVAILABLE for %s\n%s\nNo other frame is shown in its place.", string(eventId), message)); obj.clearCrops();
        end
    end
    methods (Access = protected)
        function buildBody(obj)
            t = mgv2.ui.theme();
            obj.TitleLabel.Text = 'EVENT INSPECTOR [SUSPECTED ONLY]';
            obj.StatusLabel.FontWeight = 'bold'; obj.StatusLabel.FontSize = 13;
            obj.Body = uigridlayout(obj.Grid, [1 2], 'ColumnWidth', {'1x', 0}, 'RowHeight', {'1x'}, 'Padding', 0, 'BackgroundColor', t.panel);
            obj.Body.Layout.Row = 3; obj.Body.Layout.Column = [1 2];
            obj.Table = uitable(obj.Body, 'Data', cell(0, 7), 'ColumnName', {'event','t [s]','E est','N est',sprintf('uncalibrated\nscore'),sprintf('unc.\n[m]'),'status'}, ...
                'ColumnWidth', {74, 44, 50, 50, 100, 44, '1x'}, 'ColumnFormat', {'char', 'bank', 'bank', 'bank', 'bank', 'bank', 'char'}, 'FontSize', 10, 'RowName', {}, 'SelectionType', 'row', 'CellSelectionCallback', @(~, e) obj.rowChosen(e));
            obj.Detail = uigridlayout(obj.Body, [2 2], 'RowHeight', {'fit', '1x'}, 'ColumnWidth', {'1x', '1x'}, 'Padding', 0, 'BackgroundColor', t.panel, 'Visible', 'off');
            obj.DetailText = uilabel(obj.Detail, 'Text', 'Select an event to see its evidence.', 'FontColor', t.text, 'FontName', t.mono, 'FontSize', 12, 'WordWrap', 'on', 'VerticalAlignment', 'top', 'Tag', 'event_detail');
            obj.DetailText.Layout.Row = 1; obj.DetailText.Layout.Column = [1 2];
            obj.RgbAxes = obj.cropAxes('RGB evidence'); obj.ThermalAxes = obj.cropAxes('Thermal evidence');
        end
    end
    methods (Access = private)
        function rowChosen(obj, e)
            if isempty(e.Indices) || isempty(obj.Table.Data), return; end
            id = string(obj.Table.Data{e.Indices(1, 1), 1}); obj.SelectedId = id;
            if ~isempty(obj.OnSelect), obj.OnSelect(id); end
        end
        function setDetail(obj, txt)
            c = char(txt); if ~strcmp(obj.DetailText.Text, c), obj.DetailText.Text = c; end
        end
        function ax = cropAxes(obj, name)
            ax = obj.makeAxes(obj.Detail); ax.Layout.Row = 2; axis(ax, 'image', 'off'); ax.UserData = name;
            title(ax, name, 'Color', 'w', 'FontSize', 10, 'Interpreter', 'none', 'FontWeight', 'normal');
        end
        function clearCrops(obj)
            for ax = [obj.RgbAxes obj.ThermalAxes]
                delete(findobj(ax, 'Type', 'image')); ax.Title.String = ax.UserData + ": none";
            end
        end
        function drawCrop(~, ax, items, sensor)
            %DRAWCROP The first evidence record of this sensor, exactly as retained, labelled with its own frame and time.
            delete(findobj(ax, 'Type', 'image')); r = items(string({items.sensor_id}) == sensor);
            if isempty(r), ax.Title.String = ax.UserData + ": none"; return; end
            c = r(1).crop; s = "";
            if ndims(c) ~= 3
                v = c(isfinite(c)); s = ""; if ~isempty(v), s = sprintf(" | %.2f to %.2f K", min(v), max(v)); end
                c = mgv2.sensors.thermalPalette(c, "IRONBOW");
            end
            image(ax, c, 'Tag', 'event_crop'); axis(ax, 'image', 'off'); ax.YDir = 'reverse';
            ax.Title.String = sprintf("%s t=%.2f s tick %d%s", r(1).sensor_id, r(1).t_s, r(1).tick_id, s);
        end
    end
end
