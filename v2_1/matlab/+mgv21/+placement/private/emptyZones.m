function z = emptyZones()
%EMPTYZONES 0x1 exclusion-zone struct array with the contract fields.
z = struct('kind', {}, 'center_enu_m', {}, 'radius_m', {}, 'polygon_enu_m', {});
z = reshape(z, 0, 1);
end
