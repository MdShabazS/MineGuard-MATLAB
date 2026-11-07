function h = digest(x)
%DIGEST Lower-case hex SHA-256 over a canonical byte form of a MATLAB value (V2-008 run packages).
%   h = mgv2.run.digest(sample)
%   Every element contributes its class, size and raw bytes; struct fields are taken in sorted name order, so the
%   result does not depend on field order. NaN payloads and signed zeros are hashed bit for bit. Strings are UTF-8
%   with a length prefix, a missing string is marked separately. Supported: numeric, logical, char, string, struct,
%   cell and table (its variable names and columns). Anything else raises mgv2:DigestUnsupported.
%   The same value saved to and loaded from a MAT-file gives the same digest.
md = java.security.MessageDigest.getInstance('SHA-256');
feed(md, x);
d = typecast(md.digest(), 'uint8');
h = string(lower(reshape(dec2hex(d, 2)', 1, [])));
end

function feed(md, v)
put(md, sprintf('<%s|%s>', class(v), sprintf('%d,', size(v))));
if isstruct(v)
    names = sort(string(fieldnames(v)))';
    put(md, char(strjoin(names, ',')));
    for k = 1:numel(v)
        for f = names, put(md, char(f)); feed(md, v(k).(f)); end
    end
elseif istable(v)
    put(md, char(strjoin(string(v.Properties.VariableNames), ',')));
    for f = string(v.Properties.VariableNames), feed(md, v.(f)); end
elseif iscell(v)
    for k = 1:numel(v), feed(md, v{k}); end
elseif isstring(v)
    for k = 1:numel(v)
        if ismissing(v(k)), put(md, '<missing>');
        else, b = unicode2native(char(v(k)), 'UTF-8'); put(md, sprintf('%d:', numel(b))); raw(md, b);
        end
    end
elseif ischar(v)
    raw(md, unicode2native(v(:)', 'UTF-8'));
elseif islogical(v)
    raw(md, uint8(v(:)'));
elseif isnumeric(v) && isreal(v)
    raw(md, typecast(v(:)', 'uint8'));
else
    error('mgv2:DigestUnsupported', 'Cannot digest a value of class %s.', class(v));
end
end

function put(md, txt)
raw(md, uint8(txt));
end

function raw(md, b)
if ~isempty(b), md.update(typecast(reshape(uint8(b), 1, []), 'int8')); end
end
