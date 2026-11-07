classdef (Abstract) PanelBase < matlab.ui.componentcontainer.ComponentContainer
    %PANELBASE Common frame of a mission-control panel: title, status line and a body cell (row 3).
    %   present(panel, view) draws one mgv2.ui.MissionSession view. Panels hold no simulation state.

    properties (SetAccess = protected, Transient, NonCopyable)
        Grid; TitleLabel; StatusLabel; Tools; ExpandButton
    end
    properties
        OnExpand = []     % fcn() when the operator asks to expand or restore this panel
    end

    methods (Abstract)
        present(obj, view)
    end

    methods
        function resetDisplay(~)
            %RESETDISPLAY Forget accumulated display state after a scenario reset.
        end
        function setExpanded(obj, tf)
            %SETEXPANDED The application has made this panel fill the window, or restored it.
            if tf, obj.ExpandButton.Text = 'Restore'; else, obj.ExpandButton.Text = 'Expand'; end
        end
    end

    methods (Abstract, Access = protected)
        buildBody(obj)
    end

    methods (Access = protected)
        function setup(obj)
            t = mgv2.ui.theme();
            obj.BackgroundColor = t.panel;
            obj.Grid = uigridlayout(obj, [3 2], 'RowHeight', {24, 'fit', '1x'}, 'ColumnWidth', {'1x', 'fit'}, ...
                'Padding', [6 4 6 4], 'RowSpacing', 2, 'ColumnSpacing', 4, 'BackgroundColor', t.panel);
            obj.TitleLabel = uilabel(obj.Grid, 'FontWeight', 'bold', 'FontColor', t.text, 'Text', '');
            obj.TitleLabel.Layout.Row = 1; obj.TitleLabel.Layout.Column = 1;
            obj.StatusLabel = uilabel(obj.Grid, 'FontColor', t.muted, 'FontSize', 11, 'Text', '', 'WordWrap', 'on');
            obj.StatusLabel.Layout.Row = 2; obj.StatusLabel.Layout.Column = [1 2];
            obj.Tools = uigridlayout(obj.Grid, [1 3], 'ColumnWidth', {'fit', 'fit', 'fit'}, 'RowHeight', {'1x'}, 'Padding', 0, 'ColumnSpacing', 4, 'BackgroundColor', t.panel);
            obj.Tools.Layout.Row = 1; obj.Tools.Layout.Column = 2;
            obj.buildBody();
            obj.ExpandButton = uibutton(obj.Tools, 'Text', 'Expand', 'FontSize', 10, 'Tag', 'panel_expand', 'ButtonPushedFcn', @(~, ~) obj.requestExpand());
        end

        function update(~)
        end

        function ax = makeAxes(obj, parent)
            %MAKEAXES uiaxes in the body cell (or in parent), without per-axes tools: panels are display surfaces.
            if nargin < 2, parent = obj.Grid; end
            ax = uiaxes(parent, 'Color', mgv2.ui.theme().panel);
            if parent == obj.Grid, ax.Layout.Row = 3; ax.Layout.Column = [1 2]; end
            ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
        end

        function setOverlay(~, h, txt)
            %SETOVERLAY Change a text object only when its string differs: a text change costs a layout pass.
            c = char(txt);
            if ~strcmp(char(h.String), c), h.String = c; end
        end

        function showChannelState(obj, h, st, noun)
            %SHOWCHANNELSTATE Say on the image why it is absent or old. The last real frame is never re-stamped.
            switch st.state
                case "NONE", txt = "NO SAMPLE YET";
                case "STALE", txt = sprintf("STALE: last frame t=%.2f s", st.sample.t_s);
                case "INVALID", txt = "NO VALID " + noun + ": " + st.sample.invalid_reason;
                otherwise, txt = '';
            end
            obj.setOverlay(h, txt);
        end

        function setStatus(obj, text, state)
            t = mgv2.ui.theme(); txt = char(text);
            if ~strcmp(obj.StatusLabel.Text, txt), obj.StatusLabel.Text = txt; end
            c = t.(char(lower(state)));
            if ~isequal(obj.StatusLabel.FontColor, c), obj.StatusLabel.FontColor = c; end
        end
    end
    methods (Access = private)
        function requestExpand(obj)
            if ~isempty(obj.OnExpand), obj.OnExpand(); end
        end
    end
end
