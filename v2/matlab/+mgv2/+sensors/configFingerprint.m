function h = configFingerprint(x)
%CONFIGFINGERPRINT Deterministic fingerprint of a configuration value (FNV-1a-64 over a canonical form).
%   h = mgv2.sensors.configFingerprint(x)     h = "fnv1a64:<16 hex digits>"
%   Canonical serialisation (canonicalText): struct fields sorted by name (field order does not matter),
%   class + size prefixes, numeric values with %.17g (full double precision, so any parameter change
%   changes the text), strings quoted, logicals 0/1, cells element-wise. A field named parameter_hash is
%   excluded so a stored fingerprint never feeds back into itself. FNV-1a-64 is computed exactly with two
%   32-bit limbs in double arithmetic (base MATLAB, identical on Windows and macOS). Not cryptographic.
txt = canonicalText(x);
lo = 2216829733; hi = 3421674724;            % 64-bit offset basis 0xcbf29ce484222325 = hi*2^32 + lo
for b = double(unicode2native(txt, 'UTF-8'))
    lo = double(bitxor(uint32(lo), uint32(b)));
    % multiply by prime 0x100000001b3 = 2^40 + 435 modulo 2^64
    p = lo * 435; carry = floor(p / 2^32);
    nlo = p - carry * 2^32;
    nhi = mod(hi * 435 + carry + mod(lo, 2^24) * 256, 2^32);
    lo = nlo; hi = nhi;
end
h = "fnv1a64:" + string(sprintf('%08x%08x', hi, lo));
end

function t = canonicalText(x)
if isstruct(x)
    f = sort(string(fieldnames(x)))'; f = f(f ~= "parameter_hash");
    parts = strings(1, 0);
    for k = 1:numel(x)
        for g = f, parts(end+1) = g + "=" + canonicalText(x(k).(g)); end %#ok<AGROW>
    end
    t = "struct" + mat2str(size(x)) + "{" + strjoin(parts, ";") + "}";
elseif iscell(x)
    t = "cell" + mat2str(size(x)) + "{" + strjoin(cellfun(@canonicalText, x(:)', 'UniformOutput', true), ",") + "}";
elseif isstring(x) || ischar(x)
    s = string(x); t = "str" + mat2str(size(s)) + "[" + strjoin("""" + s(:)' + """", ",") + "]";
elseif islogical(x)
    t = "logical" + mat2str(size(x)) + "[" + strjoin(string(double(x(:)')), ",") + "]";
elseif isnumeric(x)
    v = double(x(:)'); t = string(class(x)) + mat2str(size(x)) + "[" + strjoin(compose("%.17g", v), ",") + "]";
else
    error('mgv2:InvalidSensorConfig', 'Configuration contains an unsupported value of class %s.', class(x));
end
end
