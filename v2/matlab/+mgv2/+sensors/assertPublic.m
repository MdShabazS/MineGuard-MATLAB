function assertPublic(x, where)
%ASSERTPUBLIC Throw mgv2:TruthLeak if any field name, at any nesting depth, is a forbidden truth name.
%   mgv2.sensors.assertPublic(x)            x: struct / struct array / cell / table / object
%   mgv2.sensors.assertPublic(x, where)     where: label used in the error message
%   Forbidden names (case-insensitive) are listed in mgv2.sensors.contract().forbidden (V2-004 §3).
%   Objects (e.g. a handle carrying truth) are rejected outright: public records must be plain data.
if nargin < 2, where = "record"; end
bad = mgv2.sensors.contract().forbidden;
scan(x, string(where));
    function scan(v, path)
        if isobject(v) && ~isstring(v) && ~istable(v) && ~isdatetime(v) && ~iscategorical(v)
            error('mgv2:TruthLeak', '%s: objects are not allowed in public records (class %s).', path, class(v));
        end
        if isstruct(v)
            f = string(fieldnames(v))';
            hit = f(ismember(lower(f), bad));
            if ~isempty(hit), error('mgv2:TruthLeak', '%s: forbidden field "%s".', path, hit(1)); end
            for k = 1:numel(v)
                for g = f
                    scan(v(k).(g), path + "." + g);
                end
            end
        elseif istable(v)
            f = string(v.Properties.VariableNames);
            hit = f(ismember(lower(f), bad));
            if ~isempty(hit), error('mgv2:TruthLeak', '%s: forbidden column "%s".', path, hit(1)); end
        elseif iscell(v)
            for k = 1:numel(v), scan(v{k}, path + "{" + k + "}"); end
        end
    end
end
