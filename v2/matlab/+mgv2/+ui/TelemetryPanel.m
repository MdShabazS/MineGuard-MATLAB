classdef TelemetryPanel < mgv2.ui.PanelBase
    %TELEMETRYPANEL Flight state, reported virtual navigation and channel health. All values come from the view.
    %   Battery stays NOT MODELLED until a genuine model exists.
    properties (SetAccess = private, Transient, NonCopyable)
        FlightLabel; NavLabel; HealthLabel
    end
    methods
        function present(obj, view)
            p = view.pose;
            fault = "none"; if strlength(p.fault_code) > 0, fault = p.fault_code + " " + view.fault_message; end
            obj.setText(obj.FlightLabel, sprintf(['Phase: %s\nt_sim: %.2f s   tick %d\nPosition ENU: %.1f %.1f %.1f m\nAGL: %.2f m\n', ...
                'Speed: %.2f m/s\nHeading: %03.0f deg\nBattery: NOT MODELLED\nFault: %s'], p.phase, p.t_s, p.tick_id, p.position_enu_m, p.altitude_agl_m, ...
                norm(p.velocity_enu_mps), p.heading_deg, fault));
            n = view.samples.VIRTUAL_GNSS_INS;
            if isempty(n)
                nav = "Virtual GNSS/INS: NO SAMPLE";
            elseif ~n.valid
                nav = sprintf("Virtual GNSS/INS t=%.2f s\nINVALID %s", n.t_s, n.invalid_reason);
            else
                nav = sprintf(['Virtual GNSS/INS t=%.2f s\nReported ENU: %.1f %.1f %.1f m\nVirtual lat: %.6f deg\nVirtual lon: %.6f deg\n', ...
                    'Fix: %s\nHeading: %03.0f deg\nSigma (assumed): %.2f m'], n.t_s, n.reported_position_enu_m, n.virtual_lat_deg, n.virtual_lon_deg, ...
                    n.fix_type, n.reported_heading_deg, n.quality.horizontal_sigma_m);
            end
            obj.setText(obj.NavLabel, nav);
            lines = "Sensor channels";
            for id = ["RGB_NADIR","THERMAL_LWIR","LIDAR_TERRAIN","VIRTUAL_GNSS_INS"]
                st = mgv2.ui.sampleStatus(id, view); lines = lines + newline + sprintf("%-16s %s", id, st.text);
            end
            if isfield(view, 'perf') && isfinite(view.perf.sim_to_wall)
                lines = lines + newline + sprintf("Measured sim/wall this run: %.2f", view.perf.sim_to_wall);
            end
            obj.setText(obj.HealthLabel, lines);
            obj.setStatus(sprintf("t=%.2f s | state %s", p.t_s, view.state), "NONE");
        end
    end
    methods (Access = protected)
        function buildBody(obj)
            t = mgv2.ui.theme();
            obj.TitleLabel.Text = 'TELEMETRY [VIRTUAL]';
            g = uigridlayout(obj.Grid, [1 3], 'ColumnWidth', {'1x', '1x', '1.7x'}, 'Padding', 0, 'BackgroundColor', t.panel);
            g.Layout.Row = 3; g.Layout.Column = [1 2];
            mk = @() uilabel(g, 'Text', '', 'FontColor', t.text, 'FontName', t.mono, 'FontSize', 12, 'VerticalAlignment', 'top', 'WordWrap', 'on');
            obj.FlightLabel = mk(); obj.NavLabel = mk(); obj.HealthLabel = mk();
        end
    end
    methods (Static, Access = private)
        function setText(h, txt)
            c = char(txt);
            if ~strcmp(h.Text, c), h.Text = c; end
        end
    end
end
