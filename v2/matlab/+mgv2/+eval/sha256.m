function h = sha256(txt)
%SHA256 Lower-case hex SHA-256 of a UTF-8 string (Java MessageDigest, available in every desktop MATLAB).
%   h = mgv2.eval.sha256(txt)
md = java.security.MessageDigest.getInstance('SHA-256');
b = typecast(md.digest(uint8(unicode2native(char(txt), 'UTF-8'))), 'uint8');
h = string(lower(reshape(dec2hex(b, 2)', 1, [])));
end
