function terrain = terrainProvider(world)
%TERRAINPROVIDER Wrap a V2-003 world as a V2-002 terrain provider (struct: id, heightAt).
%   terrain = mgv2.scene.terrainProvider(world)
%   The mission engine then flies over exactly the ground the renderer draws. Only heights are exposed.
terrain = struct('id', world.scene_id + "-seed" + world.seed, 'heightAt', @(x, y) mgv2.scene.heightAt(world, x, y));
end
