function assertPublic(x, where)
%ASSERTPUBLIC V2 truth firewall plus the V2.1 private names. Throws mgv2:TruthLeak.
%   mgv21.scenario.assertPublic(x)
%   mgv21.scenario.assertPublic(x, where)
%   Runs mgv2.sensors.assertPublic (V2 forbidden names, objects rejected), then rejects any field or table
%   column named in mgv21.contract().private_names (placement spec, PrivateTargetTruth, surface features ...).
if nargin < 2, where = "record"; end
mgv2.sensors.assertPublic(x, where);
bad = mgv21.contract().private_names;
scan(x, string(where));
    function scan(v, path)
        if isstruct(v)
            f = string(fieldnames(v))';
            hit = f(ismember(lower(f), bad));
            if ~isempty(hit), error('mgv2:TruthLeak', '%s: V2.1 private field "%s" in a public record.', path, hit(1)); end
            for k = 1:numel(v)
                for g = f
                    scan(v(k).(g), path + "." + g);
                end
            end
        elseif istable(v)
            f = string(v.Properties.VariableNames);
            hit = f(ismember(lower(f), bad));
            if ~isempty(hit), error('mgv2:TruthLeak', '%s: V2.1 private column "%s" in a public record.', path, hit(1)); end
        elseif iscell(v)
            for k = 1:numel(v), scan(v{k}, path + "{" + k + "}"); end
        end
    end
end
