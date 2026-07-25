extends SceneTree

const PlazaMinimapProjection := preload("res://scripts/plaza/plaza_minimap_projection.gd")
const PlazaMinimapRenderer := preload("res://scripts/plaza/plaza_minimap_renderer.gd")

var failure_count := 0


func _init() -> void:
	var track := PlazaMinimapProjection.get_track_rect()
	_expect(track == Rect2(PlazaMinimapProjection.PANEL_RECT.position + PlazaMinimapProjection.TRACK_INSET, PlazaMinimapProjection.TRACK_SIZE), "track should retain the panel-relative geometry contract")
	_expect(is_equal_approx(PlazaMinimapProjection.world_x_to_minimap_x(-100.0, 1900.0), track.position.x), "negative world X should clamp to track start")
	_expect(is_equal_approx(PlazaMinimapProjection.world_x_to_minimap_x(1900.0, 1900.0), track.end.x), "map-end X should map to track end")
	_expect(is_equal_approx(PlazaMinimapProjection.world_x_to_minimap_x(950.0, 1900.0), track.get_center().x), "half-map X should map to track center")

	var specs: Array[Dictionary] = [
		{"type": "shop", "pivot_pos": Vector2(420.0, 600.0), "identity_emblem": {"id": "shop_bag"}},
		{"type": "bank", "pivot_pos": Vector2(425.0, 600.0), "identity_emblem": {"id": "bank_coin"}},
		{"type": "gacha", "interaction_rect": Rect2(430.0, 560.0, 40.0, 80.0), "identity_emblem": {"id": "gacha_orb"}},
	]
	var state := PlazaMinimapProjection.build(specs, 300.0, 950.0, 760.0, 1900.0, 1810.0)
	_expect(state.get("panel_rect", Rect2()) == PlazaMinimapProjection.PANEL_RECT, "projection should expose the canonical panel rect")
	_expect(state.get("track_rect", Rect2()) == track, "projection should expose the canonical track rect")
	var player_marker: Vector2 = state.get("player_marker", Vector2.ZERO)
	_expect(is_equal_approx(player_marker.x, track.get_center().x), "player marker should use the shared world-X mapping")
	var exit_marker: Vector2 = state.get("exit_marker", Vector2.ZERO)
	_expect(exit_marker.x > player_marker.x and exit_marker.x <= track.end.x, "exit marker should stay near the right track edge")
	var camera_rect: Rect2 = state.get("camera_rect", Rect2())
	_expect(camera_rect.has_area() and camera_rect.position.x >= track.position.x and camera_rect.end.x <= track.end.x, "camera window should remain inside the track")

	var markers: Array = state.get("building_markers", [])
	_expect(markers.size() == specs.size(), "projection should emit one marker per building")
	var previous_icon_x := -INF
	for marker_value in markers:
		var marker: Dictionary = marker_value
		var marker_pos: Vector2 = marker.get("position", Vector2.ZERO)
		var icon_pos: Vector2 = marker.get("icon_position", Vector2.ZERO)
		_expect(marker_pos.x >= track.position.x and marker_pos.x <= track.end.x, "building tick should stay inside the track")
		_expect(icon_pos.x >= track.position.x + PlazaMinimapProjection.ICON_SIZE * 0.5 and icon_pos.x <= track.end.x - PlazaMinimapProjection.ICON_SIZE * 0.5, "building icon should respect horizontal radius bounds")
		if previous_icon_x > -INF:
			_expect(icon_pos.x - previous_icon_x >= PlazaMinimapProjection.ICON_MIN_GAP - 0.001, "clustered building icons should keep the minimum gap")
		previous_icon_x = icon_pos.x
		_expect(str(marker.get("identity_emblem_id", "")) != "", "marker should retain canonical emblem identity")

	var empty_state := PlazaMinimapProjection.build([], 0.0, 0.0, 760.0, 1900.0, 1810.0)
	_expect((empty_state.get("building_markers", []) as Array).is_empty(), "empty building list should produce no markers")
	_expect(PlazaMinimapProjection.get_building_color("bank") != PlazaMinimapProjection.get_building_color("shop"), "building families should retain distinct minimap colors")
	_expect(PlazaMinimapProjection.get_building_color("unknown").a > 0.8, "unknown building should retain a visible fallback color")
	for building_type in ["bank", "shop", "gacha", "lingpet_store", "blacksmith", "tavern", "academy"]:
		_expect(PlazaMinimapRenderer.supports_building_type(building_type), "renderer should retain the %s minimap emblem" % building_type)
	_expect(not PlazaMinimapRenderer.supports_building_type("unknown"), "renderer should keep unknown buildings on its fallback badge path")

	if failure_count > 0:
		quit(1)
		return
	print("plaza_minimap_projection_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
