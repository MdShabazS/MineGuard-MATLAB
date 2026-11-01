classdef RgbPanel < mgv2.ui.PanelBase
    %RGBPANEL RGB_NADIR display of the actual sampled image, with its own timestamp and validity.
    properties (SetAccess = private, Transient, NonCopyable)
        Axes; Image; Overlay
    end
    properties (Access = private)
        LastFrame = ""
    end
    methods
        function present(obj, view)
            st = mgv2.ui.sampleStatus("RGB_NADIR", view); s = st.sample;
            obj.setStatus(st.text, st.state);
            if isempty(s) || s.frame_id == obj.LastFrame, return; end
            obj.LastFrame = s.frame_id;
            obj.Image.CData = s.image_rgb_uint8;
            set(obj.Axes, 'XLim', [0.5 s.image_width + 0.5], 'YLim', [0.5 s.image_height + 0.5]);
            obj.Overlay.Position(1:2) = [s.image_width / 2, s.image_height / 2];
            if s.valid, obj.Overlay.String = ''; else, obj.Overlay.String = "NO VALID IMAGE: " + s.invalid_reason; end
        end
        function resetDisplay(obj), obj.LastFrame = ""; end
    end
    methods (Access = protected)
        function buildBody(obj)
            obj.TitleLabel.Text = 'RGB NADIR [SIMULATED]';
            obj.Axes = obj.makeAxes();
            obj.Image = image(obj.Axes, zeros(240, 320, 3, 'uint8'), 'Tag', 'rgb_image');
            axis(obj.Axes, 'image', 'off');
            obj.Overlay = text(obj.Axes, 160, 120, '', 'Color', mgv2.ui.theme().invalid, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Interpreter', 'none');
        end
    end
end
