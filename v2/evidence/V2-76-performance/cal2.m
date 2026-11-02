function r = cal2()
%CAL2 Fixed project-free workloads, median of 5. Separates numeric, interpreted, table, class and graphics-free string speed.
r = struct('blas_ms', med(@blas), 'loop_ms', med(@loopwork), 'struct_ms', med(@structwork), 'table_ms', med(@tablework), 'string_ms', med(@stringwork), 'handle_ms', med(@handlework));
end
function m = med(f), t = zeros(5, 1); for k = 1:5, t0 = tic; f(); t(k) = 1e3 * toc(t0); end, m = median(t); end
function blas(), r = RandStream('mrg32k3a', 'Seed', 1); A = rand(r, 700); x = A' * A; s = svd(A(1:300, 1:300)); x(1) = s(1); end
function loopwork(), s = 0; for k = 1:2e6, s = s + mod(k, 7) * 0.5; end, if s < 0, disp(s); end, end
function structwork(), a = struct('x', 0, 'y', "a", 'z', zeros(1, 3)); for k = 1:2e4, a.x = a.x + 1; b = a; b.z(2) = k; a.z = b.z; end, end
function tablework(), T = table('Size', [0 3], 'VariableTypes', ["string","double","double"], 'VariableNames', ["a","b","c"]); for k = 1:300, T(end+1, :) = {"x", k, k}; end, end %#ok<AGROW>
function stringwork(), s = strings(0); for k = 1:2e3, s(end+1) = sprintf("OBS-%d", k); end, t = strjoin(s, ","); if isempty(regexp(t, 'OBS-5\>', 'once')), disp('x'); end, end %#ok<AGROW>
function handlework(), m = containers.Map('KeyType', 'double', 'ValueType', 'any'); for k = 1:1e4, m(k) = k; end, for k = 1:1e4, if isKey(m, k), v = m(k); if v < 0, disp(v); end, end, end, end
