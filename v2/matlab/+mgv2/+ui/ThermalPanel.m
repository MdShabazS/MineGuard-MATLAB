classdef ThermalPanel < mgv2.ui.PanelBase
    %THERMALPANEL THERMAL_LWIR false colour computed from the numeric Kelvin raster, with a temperature legend.
    %   Palette and unit change the display only, never the sample. The legend and the range readout convert from
    %   Kelvin for showing, and a change applies at once to the frame on screen, also while paused.
    properties (SetAccess = private)
        Palette (1,1) string = "IRONBOW"
        Unit (1,1) string = "K"     % "K" | "degC"
    end
    properties (SetAccess = private, Transient, NonCopyable)
        Axes; Image; Colorbar; Overlay; PaletteDropdown; UnitDropdown
    end
    properties (Access = private)
        LastFrame = ""
        AppliedPalette = ""
        Shown = []            % sample on screen
        LimK = [NaN NaN]      % legend limits [K] of that sample
        RangeK = [NaN NaN]    % its valid-pixel temperature range [K]
    end
    methods
        function present(obj, view)
            st = mgv2.ui.sampleStatus("THERMAL_LWIR", view); s = st.sample;
            if ~isempty(s) && s.frame_id ~= obj.LastFrame
                obj.LastFrame = s.frame_id; obj.Shown = s; obj.draw();
            end
            txt = st.text;
            if all(isfinite(obj.RangeK)) && ~isempty(s), txt = sprintf("%s | %.2f to %.2f %s", txt, obj.toUnit(obj.RangeK), obj.unitText()); end
            obj.setStatus(txt, st.state); obj.showChannelState(obj.Overlay, st, "TEMPERATURE");
        end
        function setPalette(obj, palette)
            palette = upper(string(palette));
            mgv2.sensors.thermalPalette(0, palette, [0 1]);     % refuses an unknown palette
            obj.Palette = palette; obj.PaletteDropdown.Value = palette;
            if ~isempty(obj.Shown), obj.draw(); end
        end
        function setUnit(obj, unit)
            unit = string(unit);
            if ~ismember(unit, ["K", "degC"]), error('mgv2:InvalidCommand', 'Unknown temperature unit "%s".', unit); end
            obj.Unit = unit; obj.UnitDropdown.Value = unit;
            obj.applyLegend();
        end
        function resetDisplay(obj), obj.LastFrame = ""; obj.Shown = []; obj.RangeK = [NaN NaN]; end
    end
    methods (Access = protected)
        function buildBody(obj)
            obj.TitleLabel.Text = 'THERMAL LWIR [SYNTHETIC]';
            obj.PaletteDropdown = uidropdown(obj.Tools, 'Items', ["IRONBOW","WHITE_HOT","BLACK_HOT","TURBO"], 'FontSize', 10, 'Tooltip', 'False-colour palette (display only)', ...
                'ValueChangedFcn', @(src, ~) obj.setPalette(src.Value));
            obj.UnitDropdown = uidropdown(obj.Tools, 'Items', ["K","deg C"], 'ItemsData', ["K","degC"], 'FontSize', 10, 'Tooltip', 'Temperature unit (display only)', ...
                'ValueChangedFcn', @(src, ~) obj.setUnit(src.Value));
            obj.Axes = obj.makeAxes();
            obj.Image = image(obj.Axes, zeros(120, 160, 3, 'uint8'), 'Tag', 'thermal_image');
            axis(obj.Axes, 'image', 'off');
            obj.Colorbar = colorbar(obj.Axes, 'Color', 'w', 'Visible', 'off', 'Tag', 'thermal_legend');
            obj.Colorbar.Label.String = 'apparent temperature [K]';
            obj.Overlay = text(obj.Axes, 80, 60, '', 'Color', mgv2.ui.theme().invalid, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Interpreter', 'none');
        end
    end
    methods (Access = private)
        function draw(obj)
            s = obj.Shown;
            if any(s.valid_pixel_mask(:))
                [obj.Image.CData, cm, lim] = mgv2.sensors.thermalPalette(s.temperature_K, obj.Palette, [s.display_min_K s.display_max_K]);
                if obj.AppliedPalette ~= obj.Palette, colormap(obj.Axes, cm); obj.AppliedPalette = obj.Palette; end
                v = s.temperature_K(s.valid_pixel_mask); obj.RangeK = [min(v) max(v)]; obj.LimK = lim;
                obj.applyLegend();
                if ~obj.Colorbar.Visible, obj.Colorbar.Visible = 'on'; end
            else
                obj.Image.CData = uint8(64 * ones(s.image_height, s.image_width, 3));   % no numbers invented
                obj.RangeK = [NaN NaN];
                if obj.Colorbar.Visible, obj.Colorbar.Visible = 'off'; end            % no stale temperature scale
            end
        end
        function applyLegend(obj)
            %APPLYLEGEND The image is true colour, so these limits move only the legend scale.
            label = sprintf('apparent temperature [%s]', obj.unitText());
            if ~strcmp(obj.Colorbar.Label.String, label), obj.Colorbar.Label.String = label; end
            if all(isfinite(obj.LimK)) && ~isequal(clim(obj.Axes), obj.toUnit(obj.LimK)), clim(obj.Axes, obj.toUnit(obj.LimK)); end
        end
        function v = toUnit(obj, kelvin)
            v = kelvin; if obj.Unit == "degC", v = kelvin - 273.15; end
        end
        function txt = unitText(obj)
            txt = 'K'; if obj.Unit == "degC", txt = 'deg C'; end
        end
    end
end
