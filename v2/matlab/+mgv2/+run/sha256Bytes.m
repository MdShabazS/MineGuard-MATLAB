function h = sha256Bytes(b)
%SHA256BYTES Lower-case hex SHA-256 of a byte vector (Java MessageDigest, present in every desktop MATLAB).
%   h = mgv2.run.sha256Bytes(uint8Vector)
md = java.security.MessageDigest.getInstance('SHA-256');
b = reshape(uint8(b), 1, []);
if ~isempty(b), md.update(typecast(b, 'int8')); end
d = typecast(md.digest(), 'uint8');
h = string(lower(reshape(dec2hex(d, 2)', 1, [])));
end
