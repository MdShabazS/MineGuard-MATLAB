function h = fileSha256(path)
%FILESHA256 Lower-case hex SHA-256 of a file's bytes.
%   h = mgv2.run.fileSha256(path)
fid = fopen(path, 'r');
if fid < 0, error('mgv2:PackageInvalid', 'Cannot read %s.', path); end
c = onCleanup(@() fclose(fid));
h = mgv2.run.sha256Bytes(fread(fid, inf, '*uint8'));
end
