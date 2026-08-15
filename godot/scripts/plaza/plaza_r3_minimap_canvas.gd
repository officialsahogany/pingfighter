extends Control

# Retained draw surface for the R3 two-axis minimap snapshot. It owns only
# presentation; the exact world projection and validation stay in
# PlazaR3MinimapProjection.

const PlazaR3MinimapProjection := preload("res://scripts/plaza/plaza_r3_minimap_projection.gd")

const PANEL_FILL := Color(0.018, 0.022, 0.026, 0.93)
const PANEL_BORDER := Color(0.50, 0.62, 0.58, 0.95)
const PLAYER_COLOR := Color(0.10, 0.94, 1.0, 1.0)
const GUARDIAN_COLOR := Color(0.76, 0.55, 1.0, 1.0)
const EXIT_COLOR := Color(1.0, 0.72, 0.18, 1.0)
const CAMERA_COLOR := Color(0.82, 0.92, 1.0, 0.82)

var _snapshot: Dictionary = {}
var _active := false
var _rejection_reason := "not_synced"
var _successful_sync_count := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func sync_snapshot(snapshot: Dictionary, active: bool = true) -> bool:
	set_active(false)
	if not active:
		return _reject("inactive")
	if not bool(snapshot.get("valid", false)):
		return _reject("invalid_snapshot")
	if str(snapshot.get("schema_version", "")) != PlazaR3MinimapProjection.SCHEMA_VERSION:
		return _reject("schema_mismatch")
	var panel_value: Variant = snapshot.get("panel_rect", null)
	var camera_value: Variant = snapshot.get("camera_screen_rect", null)
	if not (panel_value is Rect2) or not (camera_value is Rect2):
		return _reject("rect_type_invalid")
	var panel := panel_value as Rect2
	var camera := camera_value as Rect2
	if not _finite_rect(panel) or not panel.has_area() or not _finite_rect(camera) or not camera.has_area():
		return _reject("rect_invalid")
	if not _marker_valid(snapshot.get("player_marker", null)):
		return _reject("player_marker_invalid")
	if not _marker_valid(snapshot.get("exit_marker", null)):
		return _reject("exit_marker_invalid")
	var guardian_value: Variant = snapshot.get("guardian_marker", {})
	if not (guardian_value is Dictionary):
		return _reject("guardian_marker_type_invalid")
	if not (guardian_value as Dictionary).is_empty() and not _marker_valid(guardian_value):
		return _reject("guardian_marker_invalid")
	for record in _dictionary_array(snapshot.get("road_records", [])):
		var points_value: Variant = record.get("screen_points", null)
		if not (points_value is PackedVector2Array) or (points_value as PackedVector2Array).size() < 2:
			return _reject("road_record_invalid")
	for record in _dictionary_array(snapshot.get("walkable_hubs", [])):
		var polygon_value: Variant = record.get("screen_polygon", null)
		if not (polygon_value is PackedVector2Array) or (polygon_value as PackedVector2Array).size() < 3:
			return _reject("hub_record_invalid")
	_snapshot = snapshot.duplicate(true)
	_rejection_reason = ""
	_successful_sync_count += 1
	set_active(true)
	return true


func set_active(active: bool) -> void:
	_active = active and not _snapshot.is_empty()
	visible = _active
	set_process(false)
	queue_redraw()


func clear_transient_canvas_items() -> void:
	set_active(false)
	_snapshot.clear()
	_rejection_reason = "cleared"
	queue_redraw()


func get_debug_status() -> Dictionary:
	return {
		"active": _active,
		"visible": visible,
		"rejection_reason": _rejection_reason,
		"successful_sync_count": _successful_sync_count,
		"snapshot": _snapshot.duplicate(true),
	}


func _draw() -> void:
	if not _active:
		return
	var panel := _snapshot.get("panel_rect", Rect2()) as Rect2
	draw_rect(panel, PANEL_FILL, true)
	draw_rect(panel, PANEL_BORDER, false, 2.0)
	for hub in _dictionary_array(_snapshot.get("walkable_hubs", [])):
		var polygon := hub.get("screen_polygon", PackedVector2Array()) as PackedVector2Array
		draw_colored_polygon(polygon, Color(0.13, 0.20, 0.20, 0.72))
	for road in _dictionary_array(_snapshot.get("road_records", [])):
		var points := road.get("screen_points", PackedVector2Array()) as PackedVector2Array
		var kind := str(road.get("kind", ""))
		var color := Color(0.58, 0.52, 0.39, 0.88)
		var width := 1.5
		if kind == "main":
			color = Color(0.86, 0.68, 0.30, 0.96)
			width = 2.6
		elif kind == "secondary":
			color = Color(0.58, 0.63, 0.58, 0.92)
			width = 2.0
		elif kind == "trail":
			color = Color(0.42, 0.31, 0.22, 0.86)
		draw_polyline(points, color, width, true)
	var camera_rect := _snapshot.get("camera_screen_rect", Rect2()) as Rect2
	draw_rect(camera_rect, CAMERA_COLOR, false, 1.5)
	for marker in _dictionary_array(_snapshot.get("building_markers", [])):
		var position := marker.get("position", Vector2.ZERO) as Vector2
		var marker_color := marker.get("marker_color", Color.WHITE) as Color
		draw_circle(position, 4.0, marker_color)
	var exit_marker := _snapshot.get("exit_marker", {}) as Dictionary
	draw_circle(exit_marker.get("position", Vector2.ZERO) as Vector2, 5.0, EXIT_COLOR)
	var guardian_marker := _snapshot.get("guardian_marker", {}) as Dictionary
	if not guardian_marker.is_empty():
		draw_circle(guardian_marker.get("position", Vector2.ZERO) as Vector2, 4.0, GUARDIAN_COLOR)
	var player_marker := _snapshot.get("player_marker", {}) as Dictionary
	draw_circle(player_marker.get("position", Vector2.ZERO) as Vector2, 5.0, PLAYER_COLOR)


func _marker_valid(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var marker := value as Dictionary
	var world_value: Variant = marker.get("world_position", null)
	var screen_value: Variant = marker.get("position", null)
	return (
		world_value is Vector2
		and screen_value is Vector2
		and (world_value as Vector2).is_finite()
		and (screen_value as Vector2).is_finite()
	)


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry in value as Array:
		if entry is Dictionary:
			result.append(entry as Dictionary)
	return result


func _finite_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite()


func _reject(reason: String) -> bool:
	_rejection_reason = reason
	set_active(false)
	return false
