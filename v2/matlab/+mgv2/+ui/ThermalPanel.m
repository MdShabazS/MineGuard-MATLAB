classdef ThermalPanel < mgv2.ui.PanelBase
    %THERMALPANEL THERMAL_LWIR false colour computed from the numeric Kelvin raster, with a Kelvin legend.
    %   Set Palette before the first frame. The palette changes the display only, never the sample.
    properties
        Palette (1,1) string = "IRONBOW"
    end
    properties (SetAccess = private, Transient, NonCopyable)
        Axes; Image; Colorbar; Overlay
    end
    properties (Access = private)
        LastFrame = ""
    end
    methods
        function present(obj, view)
            st = mgv2.ui.sampleStatus("THERMAL_LWIR", view); s = st.sample;
            obj.setStatus(st.text, st.state);
            if isempty(s) || s.frame_id == obj.LastFrame, return; end
            obj.LastFrame = s.frame_id;
            set(obj.Axes, 'XLim', [0.5 s.image_width + 0.5], 'YLim', [0.5 s.image_height + 0.5]);
            obj.Overlay.Position(1:2) = [s.image_width / 2, s.image_height / 2];
            if any(s.valid_pixel_mask(:))
                [obj.Image.CData, cm, lim] = mgv2.sensors.thermalPalette(s.temperature_K, obj.Palette, [s.display_min_K s.display_max_K]);
                colormap(obj.Axes, cm); clim(obj.Axes, lim); obj.Colorbar.Visible = 'on';
            else
                obj.Image.CData = uint8(64 * ones(s.image_height, s.image_width, 3));   % no numbers invented
                obj.Colorbar.Visible = 'off';                                         % no stale temperature scale
            end
            if s.valid, obj.Overlay.String = ''; else, obj.Overlay.String = "NO VALID TEMPERATURE: " + s.invalid_reason; end
        end
        function resetDisplay(obj), obj.LastFrame = ""; end
    end
    methods (Access = protected)
        function buildBody(obj)
            obj.TitleLabel.Text = 'THERMAL LWIR [SYNTHETIC APPARENT K]';
            obj.Axes = obj.makeAxes();
            obj.Image = image(obj.Axes, zeros(120, 160, 3, 'uint8'), 'Tag', 'thermal_image');
            axis(obj.Axes, 'image', 'off');
            obj.Colorbar = colorbar(obj.Axes, 'Color', 'w', 'Visible', 'off', 'Tag', 'thermal_legend');
            obj.Colorbar.Label.String = 'apparent temperature [K]';
            obj.Overlay = text(obj.Axes, 80, 60, '', 'Color', mgv2.ui.theme().invalid, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Interpreter', 'none');
        end
    end
end
