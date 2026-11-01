function h = checksum(x)
%CHECKSUM Deterministic 64-bit-style content checksum (hex string) of numeric/char/logical/string data.
%   h = mgv2.sensors.checksum(x)
%   Two independent Adler-like sums (mod 65521 and mod 65519) over the raw bytes plus the byte count and
%   class name. Base MATLAB only (no Java, no toolboxes) so it runs identically on Windows and macOS.
%   Used for determinism/RNG-independence tests and provenance; it is NOT a cryptographic hash.
if isstring(x) || iscellstr(x), x = char(strjoin(string(x), char(31))); end
if islogical(x), x = uint8(x); end
b = double(typecast(reshape(x, 1, []), 'uint8'));
if isempty(b), b = 0; end
n = numel(b);
a1 = mod(1 + sum(b), 65521); b1 = mod(n + sum((n:-1:1) .* b), 65521);
w = mod((1:n) * 2654435761, 65519);
a2 = mod(sum(mod(b .* w, 65519)), 65519);
h = string(sprintf('%04x%04x%04x-%d-%s', a1, b1, a2, n, class(x)));
end
