extends RefCounted

# R3-B candidate-only full-map minimap projection. The R2 minimap validates the
# R2 fingerprint owner and therefore must fail on an R3 layout. This adapter
# keeps the same exact two-axis projection while adding R3 road, walkable-hub,
# guardian, camera, and portal evidence without duplicating map generation.

const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")
const PlazaMinimapProjection := preload("res://scripts/plaza/plaza_minimap_projection.gd")

const SCHEMA_VERSION := "plaza_r3_minimap_projection_v1"
const COMPILED_SCHEMA_VERSION := "plaza_r3_minimap_compiled_layout_v1"
const MAP_WORLD_SIZE := Vector2(2400.0, 1500.0)


static func build(
	layout: Dictionary,
	expected_layout_fingerprint: String,
	panel_rect: Rect2,
	player_world_position: Vector2,
	guardian_world_position: Variant,
	camera_world_rect: Rect2
) -> Dictionary:
	var compiled := compile_layout(layout, expected_layout_fingerprint)
	if not bool(compiled.get("valid", false)):
		return _rejected(str(compiled.get("rejection_reason", "compiled_layout_invalid")))
	return project_compiled(
		compiled,
		panel_rect,
		player_world_position,
		guardian_world_position,
		camera_world_rect
	)


static func compile_layout(layout: Dictionary, expected_layout_fingerprint: String) -> Dictionary:
	var validation := PlazaMapRoadSkeletonR3.validate_layout(layout)
	if not bool(validation.get("valid", false)):
		return _compiled_rejected("r3_layout_validation_failed")
	if str(layout.get("fingerprint", "")) != expected_layout_fingerprint:
		return _compiled_rejected("expected_layout_fingerprint_mismatch")
	if PlazaMapRoadSkeletonR3.build_fingerprint(layout) != expected_layout_fingerprint:
		return _compiled_rejected("stale_r3_layout_fingerprint")
	var road_world_records: Array[Dictionary] = []
	var road_graph := layout.get("road_graph", {}) as Dictionary
	for edge in _dictionary_array(road_graph.get("edges", [])):
		var points := _vector2_array(edge.get("polyline_world", []))
		if points.size() < 2:
			return _compiled_rejected("road_world_record_invalid")
		road_world_records.append({
			"id": str(edge.get("id", "")),
			"kind": str(edge.get("kind", "")),
			"world_points": PackedVector2Array(points),
		})
	var hub_world_records: Array[Dictionary] = []
	for hub in _dictionary_array(layout.get("walkable_hub_polygons", [])):
		var polygon := PackedVector2Array(_vector2_array(hub.get("polygon_world", [])))
		if polygon.size() < 3:
			return _compiled_rejected("hub_world_record_invalid")
		hub_world_records.append({
			"id": str(hub.get("id", "")),
			"world_polygon": polygon,
		})
	if hub_world_records.is_empty():
		return _compiled_rejected("hub_world_records_empty")
	var building_world_records: Array[Dictionary] = []
	for spec in _dictionary_array(layout.get("building_specs", [])):
		var world_position := spec.get("pivot_pos", Vector2.INF) as Vector2
		var marker_color := _resolve_marker_color(spec)
		if not world_position.is_finite() or not Rect2(Vector2.ZERO, MAP_WORLD_SIZE).has_point(world_position):
			return _compiled_rejected("building_world_record_invalid")
		if not _finite_color(marker_color):
			return _compiled_rejected("building_marker_color_invalid")
		building_world_records.append({
			"type": str(spec.get("type", "")),
			"plot_id": str(spec.get("plot_id", "")),
			"world_position": world_position,
			"marker_color": marker_color,
		})
	var exit_zone := layout.get("exit_zone", Rect2()) as Rect2
	if not _finite_rect(exit_zone) or not exit_zone.has_area():
		return _compiled_rejected("exit_zone_invalid")
	return {
		"valid": true,
		"schema_version": COMPILED_SCHEMA_VERSION,
		"rejection_reason": "",
		"layout_fingerprint": expected_layout_fingerprint,
		"world_size": MAP_WORLD_SIZE,
		"road_world_records": road_world_records,
		"hub_world_records": hub_world_records,
		"building_world_records": building_world_records,
		"exit_world_position": exit_zone.get_center(),
	}


static func project_compiled(
	compiled: Dictionary,
	panel_rect: Rect2,
	player_world_position: Vector2,
	guardian_world_position: Variant,
	camera_world_rect: Rect2
) -> Dictionary:
	var rejection_reason := _validate_dynamic_contract(
		compiled,
		panel_rect,
		player_world_position,
		guardian_world_position,
		camera_world_rect
	)
	if rejection_reason != "":
		return _rejected(rejection_reason)

	var projection := PlazaMapProjection.build_snapshot(MAP_WORLD_SIZE, panel_rect)
	if not PlazaMapProjection.is_valid_snapshot(projection):
		return _rejected("projection_snapshot_invalid")
	var road_records: Array[Dictionary] = []
	for record in _dictionary_array(compiled.get("road_world_records", [])):
		var world_points := record.get("world_points", PackedVector2Array()) as PackedVector2Array
		var screen_points := PlazaMapProjection.project_polygon(world_points, projection)
		if screen_points.size() < 2:
			return _rejected("road_projection_invalid")
		road_records.append({
			"id": str(record.get("id", "")),
			"kind": str(record.get("kind", "")),
			"world_points": world_points,
			"screen_points": screen_points,
		})
	var hub_records: Array[Dictionary] = []
	for hub in _dictionary_array(compiled.get("hub_world_records", [])):
		var polygon := hub.get("world_polygon", PackedVector2Array()) as PackedVector2Array
		if polygon.size() < 3:
			return _rejected("hub_projection_invalid")
		hub_records.append({
			"id": str(hub.get("id", "")),
			"world_polygon": polygon,
			"screen_polygon": PlazaMapProjection.project_polygon(polygon, projection),
		})
	var building_markers: Array[Dictionary] = []
	for record in _dictionary_array(compiled.get("building_world_records", [])):
		var world_position := record.get("world_position", Vector2.INF) as Vector2
		building_markers.append({
			"type": str(record.get("type", "")),
			"plot_id": str(record.get("plot_id", "")),
			"world_position": world_position,
			"position": PlazaMapProjection.world_to_screen(world_position, projection),
			"marker_color": record.get("marker_color", Color.WHITE) as Color,
		})
	var exit_world := compiled.get("exit_world_position", Vector2.INF) as Vector2
	var guardian_marker: Dictionary = {}
	if guardian_world_position is Vector2:
		var guardian_world := guardian_world_position as Vector2
		guardian_marker = {
			"world_position": guardian_world,
			"position": PlazaMapProjection.world_to_screen(guardian_world, projection),
		}
	return {
		"valid": true,
		"schema_version": SCHEMA_VERSION,
		"rejection_reason": "",
		"layout_fingerprint": str(compiled.get("layout_fingerprint", "")),
		"projection": projection,
		"panel_rect": panel_rect,
		"map_content_rect": PlazaMapProjection.get_map_content_screen_rect(projection),
		"road_records": road_records,
		"walkable_hubs": hub_records,
		"building_markers": building_markers,
		"player_marker": {
			"world_position": player_world_position,
			"position": PlazaMapProjection.world_to_screen(player_world_position, projection),
		},
		"guardian_marker": guardian_marker,
		"exit_marker": {
			"world_position": exit_world,
			"position": PlazaMapProjection.world_to_screen(exit_world, projection),
		},
		"camera_world_rect": camera_world_rect,
		"camera_screen_rect": PlazaMapProjection.world_rect_to_screen(camera_world_rect, projection),
	}


static func _validate_dynamic_contract(
	compiled: Dictionary,
	panel_rect: Rect2,
	player_world_position: Vector2,
	guardian_world_position: Variant,
	camera_world_rect: Rect2
) -> String:
	if not bool(compiled.get("valid", false)) or str(compiled.get("schema_version", "")) != COMPILED_SCHEMA_VERSION:
		return "compiled_layout_invalid"
	if str(compiled.get("layout_fingerprint", "")).length() != 64:
		return "compiled_layout_fingerprint_invalid"
	if compiled.get("world_size", Vector2.ZERO) != MAP_WORLD_SIZE:
		return "compiled_world_size_invalid"
	if not _finite_rect(panel_rect) or not panel_rect.has_area():
		return "panel_rect_invalid"
	if not player_world_position.is_finite() or not Rect2(Vector2.ZERO, MAP_WORLD_SIZE).has_point(player_world_position):
		return "player_world_position_invalid"
	if guardian_world_position != null:
		if not (guardian_world_position is Vector2):
			return "guardian_world_position_type_invalid"
		var guardian_world := guardian_world_position as Vector2
		if not guardian_world.is_finite() or not Rect2(Vector2.ZERO, MAP_WORLD_SIZE).has_point(guardian_world):
			return "guardian_world_position_invalid"
	if not _finite_rect(camera_world_rect) or not camera_world_rect.has_area():
		return "camera_world_rect_invalid"
	if not (compiled.get("road_world_records", null) is Array) or not (compiled.get("hub_world_records", null) is Array):
		return "compiled_geometry_type_invalid"
	if not (compiled.get("building_world_records", null) is Array):
		return "compiled_buildings_type_invalid"
	var exit_value: Variant = compiled.get("exit_world_position", null)
	if not (exit_value is Vector2) or not (exit_value as Vector2).is_finite():
		return "compiled_exit_invalid"
	return ""


static func _resolve_marker_color(spec: Dictionary) -> Color:
	var value: Variant = spec.get("marker_color", null)
	if value is Color:
		return value as Color
	return PlazaMinimapProjection.get_building_color(str(spec.get("type", "")))


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry in value as Array:
		if entry is Dictionary:
			result.append(entry as Dictionary)
	return result


static func _vector2_array(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if value is PackedVector2Array:
		for point in value as PackedVector2Array:
			result.append(point)
		return result
	if not (value is Array):
		return result
	for entry in value as Array:
		if not (entry is Vector2):
			return []
		result.append(entry as Vector2)
	return result


static func _finite_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite()


static func _finite_color(color: Color) -> bool:
	return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)


static func _rejected(reason: String) -> Dictionary:
	return {
		"valid": false,
		"schema_version": SCHEMA_VERSION,
		"rejection_reason": reason,
	}


static func _compiled_rejected(reason: String) -> Dictionary:
	return {
		"valid": false,
		"schema_version": COMPILED_SCHEMA_VERSION,
		"rejection_reason": reason,
	}
