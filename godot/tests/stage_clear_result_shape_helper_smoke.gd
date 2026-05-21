extends SceneTree

const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_ellipse_points()
	_verify_radial_points()
	_verify_star_points()
	_verify_corner_braces()
	_verify_box_lock_points()
	_verify_box_hover_effects()
	_verify_scene_delegates_shape_points()

	if _failures.is_empty():
		print("stage_clear_result_shape_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_ellipse_points() -> void:
	var ellipse: PackedVector2Array = StageClearResultShapeHelper.ellipse_polygon_points(Vector2(10.0, 20.0), 4.0, 2.0, 4)
	_expect(ellipse.size() == 4, "ellipse polygon should honor the requested segment count")
	_expect_vec(ellipse[0], Vector2(14.0, 20.0), "ellipse polygon should start at the right-most point")
	_expect_vec(ellipse[1], Vector2(10.0, 22.0), "ellipse polygon should advance counter-clockwise")
	_expect(StageClearResultShapeHelper.ellipse_polygon_points(Vector2.ZERO, -1.0, 2.0, 4).is_empty(), "invalid ellipse radii should return no polygon points")

	var polyline: PackedVector2Array = StageClearResultShapeHelper.ellipse_polyline_points(Vector2.ZERO, 5.0, 3.0, 4)
	_expect(polyline.size() == 5, "ellipse polyline should include a closing endpoint")
	_expect_vec(polyline[0], polyline[polyline.size() - 1], "ellipse polyline endpoint should close on the first point")


func _verify_radial_points() -> void:
	var radial: PackedVector2Array = StageClearResultShapeHelper.radial_polygon_points(Vector2(2.0, 3.0), 6.0, 2)
	_expect(radial.size() == 3, "radial polygon should clamp tiny segment counts")
	_expect_vec(radial[0], Vector2(8.0, 3.0), "radial polygon should start at the right-most point")
	_expect(StageClearResultShapeHelper.radial_polygon_points(Vector2.ZERO, 0.0, 8).is_empty(), "invalid radial radius should return no points")


func _verify_star_points() -> void:
	var star: PackedVector2Array = StageClearResultShapeHelper.star_polygon_points(Vector2.ZERO, 10.0, 5.0, 1.0)
	_expect(star.size() == 10, "star polygon should build alternating outer and inner points")
	_expect_vec(star[0], Vector2(0.0, -10.0), "star polygon should start at the top outer point")
	var squashed: PackedVector2Array = StageClearResultShapeHelper.star_polygon_points(Vector2.ZERO, 10.0, 5.0, 0.0)
	_expect(absf(squashed[1].x) > 0.01, "star polygon should clamp a zero x-scale instead of collapsing fully")
	var closed: PackedVector2Array = StageClearResultShapeHelper.closed_polyline_points(star)
	_expect(closed.size() == star.size() + 1, "closed polyline should append one point")
	_expect_vec(closed[0], closed[closed.size() - 1], "closed polyline should end at its first point")


func _verify_corner_braces() -> void:
	var segments: Array = StageClearResultShapeHelper.corner_brace_segments(
		Vector2.ZERO,
		Vector2(20.0, 0.0),
		Vector2(20.0, 20.0),
		Vector2(0.0, 20.0),
		1.0
	)
	_expect(segments.size() == 8, "corner braces should expose two segments per corner")
	var first_segment: Dictionary = segments[0]
	_expect_vec(first_segment.get("start", Vector2.INF), Vector2.ZERO, "corner brace should start at the first corner")
	_expect_vec(first_segment.get("end", Vector2.INF), Vector2(14.0, 0.0), "corner brace should use the scaled brace length")


func _verify_box_lock_points() -> void:
	_expect(is_equal_approx(StageClearResultShapeHelper.get_box_lock_size(2.0, 0.0), 44.0), "lock size should use the default scale when box height is absent")
	_expect(is_equal_approx(StageClearResultShapeHelper.get_box_lock_size(1.0, 80.0), 24.0), "lock size should use box height when available")
	_expect_vec(
		StageClearResultShapeHelper.get_box_lock_center(Vector2(100.0, 100.0), 20.0, 0.0),
		Vector2(100.0, 120.0),
		"lock center should apply the local vertical offset"
	)
	_expect_vec(
		StageClearResultShapeHelper.get_box_lock_center(Vector2(100.0, 100.0), 20.0, PI * 0.5),
		Vector2(80.0, 100.0),
		"lock center should rotate the local offset with the box"
	)
	var face_points: PackedVector2Array = StageClearResultShapeHelper.get_box_lock_face_points(
		Vector2(100.0, 100.0),
		20.0,
		10.0,
		0.0
	)
	_expect(face_points.size() == 4, "lock face should be a diamond")
	_expect_vec(face_points[0], Vector2(100.0, 110.0), "lock face top should preserve local offset")
	_expect_vec(face_points[1], Vector2(107.2, 120.0), "lock face side should use the 0.72 width factor")


func _verify_box_hover_effects() -> void:
	var glow_layers: Array = StageClearResultShapeHelper.box_hover_glow_layers(10.0, 20.0, 1.0, 0.0)
	_expect(glow_layers.size() == 4, "box hover glow should expose four default layers")
	var first_layer: Dictionary = glow_layers[0]
	_expect(is_equal_approx(float(first_layer.get("radius_x", 0.0)), 19.5), "first glow layer should use the widest x radius")
	_expect(is_equal_approx(float(first_layer.get("radius_y", 0.0)), 36.0), "first glow layer should use the tallest y radius")
	_expect(is_equal_approx(float(first_layer.get("alpha", 0.0)), 0.04675), "first glow layer should apply the base alpha multiplier")

	var ring: Dictionary = StageClearResultShapeHelper.box_hover_glow_ring(10.0, 20.0, 2.0, 1.0, 1.0)
	_expect(is_equal_approx(float(ring.get("radius_x", 0.0)), 12.8), "hover glow ring should scale x radius")
	_expect(is_equal_approx(float(ring.get("radius_y", 0.0)), 22.8), "hover glow ring should scale y radius")
	_expect(is_equal_approx(float(ring.get("alpha", 0.0)), 0.36), "hover glow ring should combine pulse and alpha")
	_expect(is_equal_approx(float(ring.get("width", 0.0)), 4.4), "hover glow ring should scale line width")

	var sparkles: Array = StageClearResultShapeHelper.box_hover_sparkles(Vector2.ZERO, 10.0, 20.0, 1.0, 1.0, 0.0, 0.0)
	_expect(sparkles.size() == 6, "box hover sparkles should expose the default sparkle count")
	var first_sparkle: Dictionary = sparkles[0]
	_expect_vec(first_sparkle.get("position", Vector2.INF), Vector2(11.8, 0.0), "first sparkle should start at the right orbit point")
	_expect(is_equal_approx(float(first_sparkle.get("alpha", 0.0)), 0.425), "first sparkle should apply the alpha wave")
	_expect(is_equal_approx(float(first_sparkle.get("size", 0.0)), 3.6), "first sparkle should apply the size wave")


func _verify_scene_delegates_shape_points() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultShapeHelper.ellipse_polygon_points") >= 0, "result scene should delegate filled ellipse point generation")
	_expect(source.find("StageClearResultShapeHelper.ellipse_polyline_points") >= 0, "result scene should delegate ellipse polyline point generation")
	_expect(source.find("StageClearResultShapeHelper.radial_polygon_points") >= 0, "result scene should delegate radial burst point generation")
	_expect(source.find("StageClearResultShapeHelper.star_polygon_points") >= 0, "result scene should delegate star point generation")
	_expect(source.find("StageClearResultShapeHelper.corner_brace_segments") >= 0, "result scene should delegate corner brace segment generation")
	_expect(source.find("StageClearResultShapeHelper.get_box_lock_face_points") >= 0, "result scene should delegate lock face point generation")
	_expect(source.find("StageClearResultShapeHelper.box_hover_glow_layers") >= 0, "result scene should delegate hover glow layer generation")
	_expect(source.find("StageClearResultShapeHelper.box_hover_sparkles") >= 0, "result scene should delegate hover sparkle generation")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_vec(actual: Vector2, expected: Vector2, message: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s got %s" % [message, expected, actual])
