extends RefCounted

# R2 candidate-only full-map projection. This owner is intentionally pure: it
# receives a fixed world and a layout-derived safe rect, and never consults the
# plaza generator, viewport, save store, or asset caches.

const SCHEMA_VERSION := "plaza_map_projection_v1"
const MIN_ZOOM := 0.25
const MAX_ZOOM := 4.0


static func derive_safe_rect(view_size: Vector2, insets: Dictionary) -> Rect2:
	if not view_size.is_finite() or view_size.x <= 0.0 or view_size.y <= 0.0:
		return Rect2()
	var left_value: Variant = insets.get("left", 0.0)
	var top_value: Variant = insets.get("top", 0.0)
	var right_value: Variant = insets.get("right", 0.0)
	var bottom_value: Variant = insets.get("bottom", 0.0)
	if (
		not _is_finite_number(left_value)
		or not _is_finite_number(top_value)
		or not _is_finite_number(right_value)
		or not _is_finite_number(bottom_value)
	):
		return Rect2()
	var left := maxf(0.0, float(left_value))
	var top := maxf(0.0, float(top_value))
	var right := maxf(0.0, float(right_value))
	var bottom := maxf(0.0, float(bottom_value))
	var safe_size := Vector2(
		maxf(0.0, view_size.x - left - right),
		maxf(0.0, view_size.y - top - bottom)
	)
	if safe_size.x <= 0.0 or safe_size.y <= 0.0:
		return Rect2()
	return Rect2(Vector2(left, top), safe_size)


static func build_snapshot(
	world_size: Vector2,
	safe_rect: Rect2,
	requested_camera_center: Vector2 = Vector2.INF,
	requested_zoom: float = 1.0
) -> Dictionary:
	if not world_size.is_finite() or world_size.x <= 0.0 or world_size.y <= 0.0:
		return {}
	if not _is_finite_rect(safe_rect) or safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return {}
	if not is_finite(requested_zoom):
		return {}
	var fit_scale := minf(
		safe_rect.size.x / world_size.x,
		safe_rect.size.y / world_size.y
	)
	if not is_finite(fit_scale) or fit_scale <= 0.0:
		return {}
	var zoom := clampf(requested_zoom, MIN_ZOOM, MAX_ZOOM)
	var projection_scale := fit_scale * zoom
	var visible_world_size := safe_rect.size / projection_scale
	if not is_finite(projection_scale) or projection_scale <= 0.0 or not visible_world_size.is_finite():
		return {}
	var camera_center := requested_camera_center
	if camera_center == Vector2.INF:
		camera_center = world_size * 0.5
	elif not camera_center.is_finite():
		return {}
	camera_center = _clamp_camera_center(camera_center, world_size, visible_world_size)
	var screen_origin := safe_rect.get_center() - camera_center * projection_scale
	var rendered_world_size := world_size * projection_scale
	if not camera_center.is_finite() or not screen_origin.is_finite() or not rendered_world_size.is_finite():
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"world_size": world_size,
		"safe_rect": safe_rect,
		"fit_scale": fit_scale,
		"zoom": zoom,
		"projection_scale": projection_scale,
		"camera_center_world": camera_center,
		"visible_world_rect": Rect2(camera_center - visible_world_size * 0.5, visible_world_size),
		"screen_origin": screen_origin,
		"rendered_world_rect": Rect2(screen_origin, rendered_world_size),
	}


static func is_valid_snapshot(snapshot: Dictionary) -> bool:
	var schema_value: Variant = snapshot.get("schema_version", null)
	if not (schema_value is String) or (schema_value as String) != SCHEMA_VERSION:
		return false
	var world_size_value: Variant = snapshot.get("world_size", null)
	var safe_rect_value: Variant = snapshot.get("safe_rect", null)
	var camera_center_value: Variant = snapshot.get("camera_center_world", null)
	var visible_world_rect_value: Variant = snapshot.get("visible_world_rect", null)
	var screen_origin_value: Variant = snapshot.get("screen_origin", null)
	var rendered_world_rect_value: Variant = snapshot.get("rendered_world_rect", null)
	if not (world_size_value is Vector2) or not (safe_rect_value is Rect2):
		return false
	if not (camera_center_value is Vector2) or not (visible_world_rect_value is Rect2):
		return false
	if not (screen_origin_value is Vector2) or not (rendered_world_rect_value is Rect2):
		return false
	var fit_scale_value: Variant = snapshot.get("fit_scale", null)
	var zoom_value: Variant = snapshot.get("zoom", null)
	var projection_scale_value: Variant = snapshot.get("projection_scale", null)
	if (
		not _is_finite_number(fit_scale_value)
		or not _is_finite_number(zoom_value)
		or not _is_finite_number(projection_scale_value)
	):
		return false

	var world_size := world_size_value as Vector2
	var safe_rect := safe_rect_value as Rect2
	var camera_center := camera_center_value as Vector2
	var visible_world_rect := visible_world_rect_value as Rect2
	var screen_origin := screen_origin_value as Vector2
	var rendered_world_rect := rendered_world_rect_value as Rect2
	var fit_scale := float(fit_scale_value)
	var zoom := float(zoom_value)
	var projection_scale := float(projection_scale_value)
	if not world_size.is_finite() or world_size.x <= 0.0 or world_size.y <= 0.0:
		return false
	if not _is_finite_rect(safe_rect) or safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return false
	if not camera_center.is_finite() or not screen_origin.is_finite():
		return false
	if not _is_finite_rect(visible_world_rect) or not _is_finite_rect(rendered_world_rect):
		return false
	if visible_world_rect.size.x <= 0.0 or visible_world_rect.size.y <= 0.0:
		return false
	if rendered_world_rect.size.x <= 0.0 or rendered_world_rect.size.y <= 0.0:
		return false
	if fit_scale <= 0.0 or projection_scale <= 0.0:
		return false
	if zoom < MIN_ZOOM or zoom > MAX_ZOOM:
		return false

	var expected_fit_scale := minf(
		safe_rect.size.x / world_size.x,
		safe_rect.size.y / world_size.y
	)
	var expected_projection_scale := expected_fit_scale * zoom
	var expected_visible_world_size := safe_rect.size / expected_projection_scale
	var legal_camera_center := _clamp_camera_center(
		camera_center,
		world_size,
		expected_visible_world_size
	)
	var expected_visible_world_rect := Rect2(
		camera_center - expected_visible_world_size * 0.5,
		expected_visible_world_size
	)
	var expected_screen_origin := safe_rect.get_center() - camera_center * expected_projection_scale
	var expected_rendered_world_rect := Rect2(
		expected_screen_origin,
		world_size * expected_projection_scale
	)
	return (
		is_equal_approx(fit_scale, expected_fit_scale)
		and is_equal_approx(projection_scale, expected_projection_scale)
		and camera_center.is_equal_approx(legal_camera_center)
		and _rect_is_equal_approx(visible_world_rect, expected_visible_world_rect)
		and screen_origin.is_equal_approx(expected_screen_origin)
		and _rect_is_equal_approx(rendered_world_rect, expected_rendered_world_rect)
	)


static func world_to_screen(world_position: Vector2, snapshot: Dictionary) -> Vector2:
	if not is_valid_snapshot(snapshot):
		return Vector2.INF
	var screen_origin: Vector2 = snapshot.get("screen_origin", Vector2.ZERO)
	return screen_origin + world_position * float(snapshot.get("projection_scale", 1.0))


static func screen_to_world(screen_position: Vector2, snapshot: Dictionary) -> Vector2:
	if not is_valid_snapshot(snapshot):
		return Vector2.INF
	var projection_scale := float(snapshot.get("projection_scale", 0.0))
	var screen_origin: Vector2 = snapshot.get("screen_origin", Vector2.ZERO)
	return (screen_position - screen_origin) / projection_scale


static func world_rect_to_screen(world_rect: Rect2, snapshot: Dictionary) -> Rect2:
	if not is_valid_snapshot(snapshot):
		return Rect2()
	var projection_scale := float(snapshot.get("projection_scale", 1.0))
	var screen_origin := snapshot.get("screen_origin", Vector2.ZERO) as Vector2
	return Rect2(screen_origin + world_rect.position * projection_scale, world_rect.size * projection_scale)


static func project_polygon(world_polygon: PackedVector2Array, snapshot: Dictionary) -> PackedVector2Array:
	var projected := PackedVector2Array()
	if not is_valid_snapshot(snapshot):
		return projected
	var screen_origin := snapshot.get("screen_origin", Vector2.ZERO) as Vector2
	var projection_scale := float(snapshot.get("projection_scale", 1.0))
	for world_point in world_polygon:
		projected.append(screen_origin + world_point * projection_scale)
	return projected


static func contains_safe_area_point(screen_position: Vector2, snapshot: Dictionary) -> bool:
	if not is_valid_snapshot(snapshot):
		return false
	var safe_rect := snapshot.get("safe_rect", Rect2()) as Rect2
	return safe_rect.has_point(screen_position)


static func get_map_content_screen_rect(snapshot: Dictionary) -> Rect2:
	if not is_valid_snapshot(snapshot):
		return Rect2()
	var safe_rect := snapshot.get("safe_rect", Rect2()) as Rect2
	var rendered_world_rect := snapshot.get("rendered_world_rect", Rect2()) as Rect2
	return safe_rect.intersection(rendered_world_rect)


static func contains_map_content_point(screen_position: Vector2, snapshot: Dictionary) -> bool:
	var map_content_rect := get_map_content_screen_rect(snapshot)
	return map_content_rect.has_area() and map_content_rect.has_point(screen_position)


static func _clamp_camera_center(
	requested_center: Vector2,
	world_size: Vector2,
	visible_world_size: Vector2
) -> Vector2:
	return Vector2(
		_clamp_camera_axis(requested_center.x, world_size.x, visible_world_size.x),
		_clamp_camera_axis(requested_center.y, world_size.y, visible_world_size.y)
	)


static func _clamp_camera_axis(requested: float, world_axis: float, visible_axis: float) -> float:
	if visible_axis >= world_axis:
		return world_axis * 0.5
	var half_visible := visible_axis * 0.5
	return clampf(requested, half_visible, world_axis - half_visible)


static func _is_finite_number(value: Variant) -> bool:
	var value_type := typeof(value)
	return (
		(value_type == TYPE_FLOAT or value_type == TYPE_INT)
		and is_finite(float(value))
	)


static func _is_finite_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite()


static func _rect_is_equal_approx(left: Rect2, right: Rect2) -> bool:
	return left.position.is_equal_approx(right.position) and left.size.is_equal_approx(right.size)
