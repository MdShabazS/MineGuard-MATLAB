function world = buildWorld(pub)
%BUILDWORLD Synthetic world of a PublicMissionConfig (= mgv2.scene.buildWorld(pub.scene_config)).
%   world = mgv21.scenario.buildWorld(pub)
%   The world holds only observable geometry; it never contains V2.1 placement or truth data.
world = mgv2.scene.buildWorld(pub.scene_config);
end
