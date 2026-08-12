extends RefCounted

# R2-B candidate-only 2D minimap projection. Marker positions are exact world
# projections; unlike the legacy strip owner, neither axis is collapsed and no
# overlap resolver is allowed to move markers away from their map positions.

const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaMinimapProjection := preload("res://scripts/plaza/plaza_minimap_projection.gd")

const SCHEMA_VERSION := "plaza_map_minimap_projection_2d_r2b_v1"
const MAP_WORLD_SIZE := Vector2(2400.0, 1500.0)
const SHA256_HEX_LENGTH := 64


static func build(
	layout: Dictionary,
	expected_layout_fingerprint: String,
	minimap_safe_rect: Rect2,
	player_world_position: Vector2,
	camera_world_rect: Rect2 = Rect2()
) -> Dictionary:
	var rejection_reason := _validate_build_contract(
		layout,
		expected_layout_fingerprint,
		minimap_safe_rect,
		player_world_position,
		camera_world_rect
	)
	if rejection_reason != "":
		return _rejected_snapshot(rejection_reason)

	var projection := PlazaMapProjection.build_snapshot(
		MAP_WORLD_SIZE,
		minimap_safe_rect,
		Vector2.INF,
		1.0
	)
	if not PlazaMapProjection.is_valid_snapshot(projection):
		return _rejected_snapshot("projection_snapshot_invalid")

	var markers: Array[Dictionary] = []
	for spec in _dictionary_array(layout.get("building_specs", [])):
		var world_position_value: Variant = spec.get("pivot_pos", null)
		if not (world_position_value is Vector2):
			return _rejected_snapshot("building_marker_position_invalid")
		var world_position := world_position_value as Vector2
		var marker_color := resolve_marker_color(spec)
		markers.append({
			"type": str(spec.get("type", "")),
			"plot_id": str(spec.get("plot_id", "")),
			"world_position": world_position,
			"position": PlazaMapProjection.world_to_screen(world_position, projection),
			"marker_color": marker_color,
			"marker_color_source": "spec" if spec.get("marker_color", null) is Color else "legacy_fallback",
		})

	var exit_zone: Rect2 = layout.get("exit_zone", Rect2())
	var camera_screen_rect := Rect2()
	if camera_world_rect.has_area():
		camera_screen_rect = PlazaMapProjection.world_rect_to_screen(camera_world_rect, projection)
	return {
		"valid": true,
		"schema_version": SCHEMA_VERSION,
		"rejection_reason": "",
		"layout_fingerprint": expected_layout_fingerprint,
		"world_size": MAP_WORLD_SIZE,
		"safe_rect": minimap_safe_rect,
		"map_content_rect": PlazaMapProjection.get_map_content_screen_rect(projection),
		"projection": projection,
		"player_marker": {
			"world_position": player_world_position,
			"position": PlazaMapProjection.world_to_screen(player_world_position, projection),
		},
		"exit_marker": {
			"world_position": exit_zone.get_center(),
			"position": PlazaMapProjection.world_to_screen(exit_zone.get_center(), projection),
		},
		"camera_world_rect": camera_world_rect,
		"camera_screen_rect": camera_screen_rect,
		"building_markers": markers,
	}


static func resolve_marker_color(spec: Dictionary) -> Color:
	var authored_value: Variant = spec.get("marker_color", null)
	if authored_value is Color:
		return authored_value as Color
	return PlazaMinimapProjection.get_building_color(str(spec.get("type", "")))


static func _validate_build_contract(
	layout: Dictionary,
	expected_fingerprint: String,
	minimap_safe_rect: Rect2,
	player_world_position: Vector2,
	camera_world_rect: Rect2
) -> String:
	if not _is_sha256_hex(expected_fingerprint):
		return "invalid_expected_fingerprint"
	var validation := PlazaMapLayoutGenerator.validate_layout(layout)
	if not bool(validation.get("valid", false)):
		return "layout_validation_failed"
	var world_value: Variant = layout.get("world_size", null)
	if not (world_value is Vector2) or not (world_value as Vector2).is_equal_approx(MAP_WORLD_SIZE):
		return "world_size_contract_mismatch"
	var stored_value: Variant = layout.get("fingerprint", null)
	if not (stored_value is String) or not _is_sha256_hex(stored_value as String):
		return "invalid_layout_fingerprint"
	if (stored_value as String) != expected_fingerprint:
		return "expected_fingerprint_mismatch"
	if PlazaMapLayoutGenerator.build_fingerprint(layout) != expected_fingerprint:
		return "layout_fingerprint_mismatch"
	if not _is_finite_rect(minimap_safe_rect) or not minimap_safe_rect.has_area():
		return "minimap_safe_rect_invalid"
	if not player_world_position.is_finite() or not _world_contains_point(player_world_position):
		return "player_world_position_invalid"
	if camera_world_rect != Rect2():
		if not _is_finite_rect(camera_world_rect) or not camera_world_rect.has_area():
			return "camera_world_rect_invalid"
	return ""


static func _world_contains_point(point: Vector2) -> bool:
	return point.x >= 0.0 and point.y >= 0.0 and point.x <= MAP_WORLD_SIZE.x and point.y <= MAP_WORLD_SIZE.y


static func _is_finite_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite()


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	if not (value is Array):
		return typed
	for item in value as Array:
		if item is Dictionary:
			typed.append(item as Dictionary)
	return typed


static func _is_sha256_hex(value: String) -> bool:
	if value.length() != SHA256_HEX_LENGTH:
		return false
	const HEX := "0123456789abcdef"
	for index in range(value.length()):
		if HEX.find(value.substr(index, 1)) < 0:
			return false
	return true


static func _rejected_snapshot(reason: String) -> Dictionary:
	return {
		"valid": false,
		"schema_version": SCHEMA_VERSION,
		"rejection_reason": reason,
	}
