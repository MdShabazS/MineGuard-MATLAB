function h = configChecksum(config)
%CONFIGCHECKSUM FNV-1a 32-bit checksum (hex string) of jsonencode(config).
%   Used to tie generated data to the exact configuration. It is an identity check, not
%   a security hash.
bytes = uint32(unicode2native(jsonencode(config), 'UTF-8'));
h = uint32(2166136261);
for k = 1:numel(bytes)
    h = bitxor(h, bytes(k));
    h = uint32(mod(double(h) * 16777619, 2^32));
end
h = string(lower(dec2hex(h, 8)));
end
