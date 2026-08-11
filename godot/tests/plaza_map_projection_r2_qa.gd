extends SceneTree

const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")

const WORLD_SIZE := Vector2(2400.0, 1500.0)
const REFERENCE_VIEW_SIZE := Vector2(2020.0, 1246.0)
const REFERENCE_SAFE_RECT := Rect2(72.0, 72.0, 1588.0, 1054.0)
const REFERENCE_FIT_SCALE := 1588.0 / 2400.0
const REFERENCE_RENDERED_RECT := Rect2(72.0, 102.75, 1588.0, 992.5)

var _failed := false


func _init() -> void:
	_verify_safe_rect_derivation()
	var reference_snapshot := PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT)
	_verify_reference_projection(reference_snapshot)
	_verify_resize_projection(reference_snapshot)
	_verify_camera_and_zoom_boundaries()
	_verify_rect_polygon_and_input_projection(reference_snapshot)
	_verify_invalid_inputs_and_snapshots(reference_snapshot)
	if _failed:
		quit(1)
		return
	print("plaza_map_projection_r2_qa: ok")
	quit(0)


func _verify_safe_rect_derivation() -> void:
	var reference_insets := _reference_insets()
	var reference_safe_rect := PlazaMapProjection.derive_safe_rect(REFERENCE_VIEW_SIZE, reference_insets)
	_expect_rect(reference_safe_rect, REFERENCE_SAFE_RECT, "explicit left inset should derive the documented 1588-wide reference rect")
	var zero_left_safe_rect := PlazaMapProjection.derive_safe_rect(REFERENCE_VIEW_SIZE, {
		"left": 0.0,
		"top": 72.0,
		"right": 360.0,
		"bottom": 120.0,
	})
	_expect_rect(zero_left_safe_rect, Rect2(0.0, 72.0, 1660.0, 1054.0), "left=0 must derive 1660 width instead of silently reusing 1588")
	_expect_rect(
		PlazaMapProjection.derive_safe_rect(Vector2(100.0, 80.0), {
			"left": -8.0,
			"top": -4.0,
			"right": 10.0,
			"bottom": 12.0,
		}),
		Rect2(0.0, 0.0, 90.0, 68.0),
		"negative insets should clamp independently to zero"
	)
	_expect(
		PlazaMapProjection.derive_safe_rect(Vector2(100.0, 80.0), {"left": 50.0, "right": 50.0}).has_area() == false,
		"insets that consume an axis exactly should fail closed"
	)
	_expect(
		PlazaMapProjection.derive_safe_rect(Vector2(100.0, 80.0), {"left": 80.0, "right": 30.0}).has_area() == false,
		"oversubscribed insets should fail closed"
	)
	_expect(PlazaMapProjection.derive_safe_rect(Vector2.ZERO, reference_insets) == Rect2(), "degenerate view should fail closed")
	_expect(PlazaMapProjection.derive_safe_rect(Vector2(NAN, 100.0), reference_insets) == Rect2(), "non-finite view should fail closed")
	_expect(PlazaMapProjection.derive_safe_rect(REFERENCE_VIEW_SIZE, {"left": "bad"}) == Rect2(), "non-numeric inset should fail closed")
	_expect(PlazaMapProjection.derive_safe_rect(REFERENCE_VIEW_SIZE, {"top": NAN}) == Rect2(), "non-finite inset should fail closed")


func _verify_reference_projection(snapshot: Dictionary) -> void:
	_expect(PlazaMapProjection.is_valid_snapshot(snapshot), "reference projection snapshot should be valid")
	_expect_close(float(snapshot.get("fit_scale", 0.0)), REFERENCE_FIT_SCALE, "wide map should fit by safe-rect width")
	_expect_vec(snapshot.get("camera_center_world", Vector2.ZERO), WORLD_SIZE * 0.5, "fit snapshot should lock to world center")
	_expect_rect(snapshot.get("rendered_world_rect", Rect2()), REFERENCE_RENDERED_RECT, "reference rendered map should preserve exact symmetric vertical parchment margins")
	_expect_vec(PlazaMapProjection.world_to_screen(Vector2.ZERO, snapshot), REFERENCE_RENDERED_RECT.position, "world origin should map to rendered-map origin")
	_expect_vec(PlazaMapProjection.world_to_screen(WORLD_SIZE * 0.5, snapshot), REFERENCE_SAFE_RECT.get_center(), "world center should map to safe-rect center")
	_expect_vec(PlazaMapProjection.world_to_screen(WORLD_SIZE, snapshot), REFERENCE_RENDERED_RECT.end, "world far corner should map to rendered-map far corner")

	var probes: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(120.0, 666.0),
		Vector2(1200.0, 750.0),
		Vector2(2250.0, 642.0),
		WORLD_SIZE,
	]
	for probe in probes:
		var screen_point := PlazaMapProjection.world_to_screen(probe, snapshot)
		var round_trip := PlazaMapProjection.screen_to_world(screen_point, snapshot)
		_expect_vec(round_trip, probe, "world/screen round-trip should preserve %s" % probe)


func _verify_resize_projection(reference_snapshot: Dictionary) -> void:
	var wide_safe_rect := PlazaMapProjection.derive_safe_rect(Vector2(2560.0, 1080.0), _reference_insets())
	_expect_rect(wide_safe_rect, Rect2(72.0, 72.0, 2128.0, 888.0), "wide resize should derive its own safe rect")
	var wide_snapshot := PlazaMapProjection.build_snapshot(WORLD_SIZE, wide_safe_rect)
	_expect(PlazaMapProjection.is_valid_snapshot(wide_snapshot), "wide resize projection should remain valid")
	_expect_close(float(wide_snapshot.get("fit_scale", 0.0)), 0.592, "wide resize should switch to exact height-fit scale")
	_expect_rect(wide_snapshot.get("rendered_world_rect", Rect2()), Rect2(425.6, 72.0, 1420.8, 888.0), "height-fit map should preserve exact symmetric horizontal parchment margins")
	_expect_vec(PlazaMapProjection.world_to_screen(Vector2.ZERO, wide_snapshot), Vector2(425.6, 72.0), "wide world origin should use the resized height-fit projection")
	_expect_vec(PlazaMapProjection.world_to_screen(WORLD_SIZE * 0.5, wide_snapshot), Vector2(1136.0, 516.0), "wide world center should map to resized safe center")
	_expect_vec(PlazaMapProjection.world_to_screen(WORLD_SIZE, wide_snapshot), Vector2(1846.4, 960.0), "wide world far corner should use the resized height-fit projection")
	_expect(not wide_safe_rect.is_equal_approx(REFERENCE_SAFE_RECT), "resize should change the projection safe rect")
	_expect(wide_snapshot.get("world_size", Vector2.ZERO) == reference_snapshot.get("world_size", Vector2.ONE), "resize must not mutate fixed generation world size")
	_expect(wide_snapshot.get("schema_version", "") == reference_snapshot.get("schema_version", "mismatch"), "resize must preserve the projection contract version")


func _verify_camera_and_zoom_boundaries() -> void:
	var near_snapshot := PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT, Vector2(80.0, 80.0), 2.0)
	var far_snapshot := PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT, Vector2(2390.0, 1490.0), 2.0)
	var mid_snapshot := PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT, Vector2(1200.0, 750.0), 2.0)
	_expect_vec(near_snapshot.get("camera_center_world", Vector2.ZERO), Vector2(600.0, 398.2368), "near camera should clamp exactly to visible half extents")
	_expect_vec(far_snapshot.get("camera_center_world", Vector2.ZERO), Vector2(1800.0, 1101.7632), "far camera should clamp exactly to world minus visible half extents")
	_expect_vec(mid_snapshot.get("camera_center_world", Vector2.ZERO), Vector2(1200.0, 750.0), "legal mid-world camera request should remain unchanged")
	_expect_rect(near_snapshot.get("visible_world_rect", Rect2()), Rect2(0.0, 0.0, 1200.0, 796.4736), "near clamp should place the visible rect exactly on the near world edges")
	_expect_rect(far_snapshot.get("visible_world_rect", Rect2()), Rect2(1200.0, 703.5264, 1200.0, 796.4736), "far clamp should place the visible rect exactly on the far world edges")

	var min_zoom_snapshot := PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT, Vector2(80.0, 80.0), -10.0)
	_expect_close(float(min_zoom_snapshot.get("zoom", 0.0)), PlazaMapProjection.MIN_ZOOM, "zoom below minimum should clamp to MIN_ZOOM")
	_expect_vec(min_zoom_snapshot.get("camera_center_world", Vector2.ZERO), WORLD_SIZE * 0.5, "zoomed-out view larger than the world should lock both camera axes to center")
	var max_zoom_snapshot := PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT, Vector2(80.0, 80.0), 99.0)
	_expect_close(float(max_zoom_snapshot.get("zoom", 0.0)), PlazaMapProjection.MAX_ZOOM, "zoom above maximum should clamp to MAX_ZOOM")
	_expect_vec(max_zoom_snapshot.get("camera_center_world", Vector2.ZERO), Vector2(300.0, 199.1184), "MAX_ZOOM near request should clamp using its exact visible half extents")
	_expect_close(
		float(PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT, Vector2.INF, PlazaMapProjection.MIN_ZOOM).get("zoom", 0.0)),
		PlazaMapProjection.MIN_ZOOM,
		"exact MIN_ZOOM should remain unchanged"
	)
	_expect_close(
		float(PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT, Vector2.INF, PlazaMapProjection.MAX_ZOOM).get("zoom", 0.0)),
		PlazaMapProjection.MAX_ZOOM,
		"exact MAX_ZOOM should remain unchanged"
	)


func _verify_rect_polygon_and_input_projection(snapshot: Dictionary) -> void:
	var projected_rect := PlazaMapProjection.world_rect_to_screen(Rect2(100.0, 200.0, 300.0, 400.0), snapshot)
	_expect_rect(projected_rect, Rect2(138.1667, 235.0833, 198.5, 264.6667), "world rect should project both origin and size")
	var world_polygon := PackedVector2Array([Vector2.ZERO, WORLD_SIZE * 0.5, WORLD_SIZE])
	var projected_polygon := PlazaMapProjection.project_polygon(world_polygon, snapshot)
	_expect(projected_polygon.size() == world_polygon.size(), "polygon projection should preserve vertex count")
	if projected_polygon.size() == world_polygon.size():
		_expect_vec(projected_polygon[0], REFERENCE_RENDERED_RECT.position, "polygon origin vertex projection")
		_expect_vec(projected_polygon[1], REFERENCE_SAFE_RECT.get_center(), "polygon center vertex projection")
		_expect_vec(projected_polygon[2], REFERENCE_RENDERED_RECT.end, "polygon far vertex projection")

	var map_content_rect := PlazaMapProjection.get_map_content_screen_rect(snapshot)
	_expect_rect(map_content_rect, REFERENCE_RENDERED_RECT, "width-fit map content should exclude top and bottom parchment margins")
	var parchment_margin_point := Vector2(REFERENCE_SAFE_RECT.get_center().x, 80.0)
	_expect(PlazaMapProjection.contains_safe_area_point(parchment_margin_point, snapshot), "parchment margin should remain part of the UI safe area")
	_expect(not PlazaMapProjection.contains_map_content_point(parchment_margin_point, snapshot), "parchment margin must not be accepted as map content")
	_expect(PlazaMapProjection.contains_safe_area_point(REFERENCE_SAFE_RECT.position, snapshot), "safe-area near edge should be inclusive")
	_expect(not PlazaMapProjection.contains_safe_area_point(REFERENCE_SAFE_RECT.end, snapshot), "safe-area far edge should be exclusive")
	_expect(PlazaMapProjection.contains_map_content_point(REFERENCE_RENDERED_RECT.position, snapshot), "map-content near edge should be inclusive")
	_expect(not PlazaMapProjection.contains_map_content_point(REFERENCE_RENDERED_RECT.end, snapshot), "map-content far edge should be exclusive")
	_expect(PlazaMapProjection.contains_map_content_point(REFERENCE_SAFE_RECT.get_center(), snapshot), "map center should be accepted as map content")


func _verify_invalid_inputs_and_snapshots(reference_snapshot: Dictionary) -> void:
	_expect(PlazaMapProjection.build_snapshot(Vector2.ZERO, REFERENCE_SAFE_RECT).is_empty(), "degenerate world should fail closed")
	_expect(PlazaMapProjection.build_snapshot(Vector2(NAN, 1500.0), REFERENCE_SAFE_RECT).is_empty(), "non-finite world should fail closed")
	_expect(PlazaMapProjection.build_snapshot(WORLD_SIZE, Rect2(Vector2(INF, 0.0), Vector2.ONE)).is_empty(), "non-finite safe rect should fail closed")
	_expect(PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT, Vector2(NAN, 0.0), 1.0).is_empty(), "non-finite requested camera should fail closed")
	_expect(PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT, Vector2.INF, NAN).is_empty(), "NaN zoom should fail closed")
	_expect(PlazaMapProjection.build_snapshot(WORLD_SIZE, REFERENCE_SAFE_RECT, Vector2.INF, INF).is_empty(), "infinite zoom should fail closed")

	var wrong_type_snapshot := reference_snapshot.duplicate(true)
	wrong_type_snapshot["world_size"] = "bad"
	_expect(not PlazaMapProjection.is_valid_snapshot(wrong_type_snapshot), "wrong-typed snapshot field should return false instead of raising a typed assignment error")
	var wrong_schema_snapshot := reference_snapshot.duplicate(true)
	wrong_schema_snapshot["schema_version"] = "wrong"
	_expect(not PlazaMapProjection.is_valid_snapshot(wrong_schema_snapshot), "wrong schema should invalidate a snapshot")
	var corrupt_origin_snapshot := reference_snapshot.duplicate(true)
	corrupt_origin_snapshot["screen_origin"] = (corrupt_origin_snapshot.get("screen_origin") as Vector2) + Vector2(0.0, 9999.0)
	_expect(not PlazaMapProjection.is_valid_snapshot(corrupt_origin_snapshot), "shared forward/inverse origin corruption must not remain a valid snapshot")
	var corrupt_scale_snapshot := reference_snapshot.duplicate(true)
	corrupt_scale_snapshot["projection_scale"] = float(corrupt_scale_snapshot.get("projection_scale")) * 2.0
	_expect(not PlazaMapProjection.is_valid_snapshot(corrupt_scale_snapshot), "projection scale must retain its fit-times-zoom relationship")
	var corrupt_camera_snapshot := reference_snapshot.duplicate(true)
	corrupt_camera_snapshot["camera_center_world"] = Vector2(80.0, 80.0)
	_expect(not PlazaMapProjection.is_valid_snapshot(corrupt_camera_snapshot), "unclamped camera center must invalidate a snapshot")
	var corrupt_visible_rect_snapshot := reference_snapshot.duplicate(true)
	corrupt_visible_rect_snapshot["visible_world_rect"] = Rect2(Vector2.ZERO, Vector2.ONE)
	_expect(not PlazaMapProjection.is_valid_snapshot(corrupt_visible_rect_snapshot), "visible rect must retain its camera and scale relationship")
	var corrupt_rendered_rect_snapshot := reference_snapshot.duplicate(true)
	corrupt_rendered_rect_snapshot["rendered_world_rect"] = Rect2(REFERENCE_RENDERED_RECT.position, Vector2.ONE)
	_expect(not PlazaMapProjection.is_valid_snapshot(corrupt_rendered_rect_snapshot), "rendered rect must retain its origin and scale relationship")
	_expect(not PlazaMapProjection.is_valid_snapshot({}), "empty snapshot should be invalid")

	_expect(not PlazaMapProjection.world_to_screen(Vector2.ZERO, wrong_type_snapshot).is_finite(), "invalid world-to-screen projection should return a non-finite sentinel")
	_expect(not PlazaMapProjection.screen_to_world(Vector2.ZERO, wrong_type_snapshot).is_finite(), "invalid screen-to-world projection should return a non-finite sentinel")
	_expect(PlazaMapProjection.world_rect_to_screen(Rect2(Vector2.ZERO, Vector2.ONE), wrong_type_snapshot) == Rect2(), "invalid world-rect projection should fail closed")
	_expect(PlazaMapProjection.project_polygon(PackedVector2Array([Vector2.ZERO]), wrong_type_snapshot).is_empty(), "invalid polygon projection should fail closed")
	_expect(not PlazaMapProjection.contains_safe_area_point(Vector2.ZERO, wrong_type_snapshot), "invalid safe-area query should fail closed")
	_expect(not PlazaMapProjection.contains_map_content_point(Vector2.ZERO, wrong_type_snapshot), "invalid map-content query should fail closed")


func _reference_insets() -> Dictionary:
	return {
		"left": 72.0,
		"top": 72.0,
		"right": 360.0,
		"bottom": 120.0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s: expected %.6f, got %.6f" % [message, expected, actual])


func _expect_vec(actual: Vector2, expected: Vector2, message: String) -> void:
	_expect(actual.is_equal_approx(expected), "%s: expected %s, got %s" % [message, expected, actual])


func _expect_rect(actual: Rect2, expected: Rect2, message: String) -> void:
	_expect(
		actual.position.is_equal_approx(expected.position) and actual.size.is_equal_approx(expected.size),
		"%s: expected %s, got %s" % [message, expected, actual]
	)
