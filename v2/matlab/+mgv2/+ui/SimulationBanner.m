classdef SimulationBanner < matlab.ui.componentcontainer.ComponentContainer
    %SIMULATIONBANNER Permanent scientific warning. It sits outside the scrolling content and has no off switch.
    properties (SetAccess = private, Transient, NonCopyable)
        Label
    end
    methods (Access = protected)
        function setup(obj)
            t = mgv2.ui.theme();
            obj.BackgroundColor = t.bannerBg;
            g = uigridlayout(obj, [1 1], 'Padding', [8 2 8 2], 'BackgroundColor', t.bannerBg);
            obj.Label = uilabel(g, 'Text', t.warning, 'FontColor', t.bannerFg, 'FontWeight', 'bold', 'FontSize', 13, ...
                'HorizontalAlignment', 'center', 'WordWrap', 'on');
        end
        function update(~)
        end
    end
end
