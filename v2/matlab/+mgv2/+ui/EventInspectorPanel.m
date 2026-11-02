classdef EventInspectorPanel < mgv2.ui.PanelBase
    %EVENTINSPECTORPANEL Lists validated V2-006 SuspectedEvents. Until a detector exists it says so and lists none.
    %   Scores are shown as uncalibrated model scores. Evidence frames are a later integration stage.
    properties (SetAccess = private, Transient, NonCopyable)
        Table
    end
    properties (Access = private)
        Shown
    end
    methods
        function present(obj, view)
            if view.source.connected
                obj.setStatus(sprintf("%s | detector %s | %d SUSPECTED event(s)", view.source.status_text, view.source.detector_version, numel(view.events)), "VALID");
            else
                obj.setStatus(view.source.status_text, "INVALID");
            end
            if isequal(obj.Shown, view.events), return; end
            obj.Shown = view.events; ev = view.events; D = cell(numel(ev), 7);
            for k = 1:numel(ev)
                e = ev(k);
                D(k, :) = {char(string(e.event_id)), e.t_s, e.x_est_m, e.y_est_m, e.model_score, e.uncertainty_m, char(string(e.status))};
            end
            obj.Table.Data = D;
        end
        function resetDisplay(obj), obj.Shown = []; obj.Table.Data = cell(0, 7); end
    end
    methods (Access = protected)
        function buildBody(obj)
            obj.TitleLabel.Text = 'EVENT INSPECTOR [SUSPECTED ONLY]';
            obj.StatusLabel.FontWeight = 'bold'; obj.StatusLabel.FontSize = 13;
            obj.Table = uitable(obj.Grid, 'Data', cell(0, 7), 'ColumnName', {'event','t [s]','E est','N est','uncalibrated score','unc. [m]','status'}, ...
                'ColumnWidth', {'1x', 46, 50, 50, 132, 66, '1x'}, 'FontSize', 11, 'RowName', {});
            obj.Table.Layout.Row = 3; obj.Table.Layout.Column = [1 2];
        end
    end
end
