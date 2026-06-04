extends SceneTree

const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_ellipse_points()
	_verify_radial_points()
	_verify_star_points()
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
	_expect(source.find("StageClearResultShapeHelper.draw_radial_burst") >= 0, "result scene should delegate radial burst drawing")
	_expect(source.find("StageClearResultShapeHelper.draw_filled_ellipse") >= 0, "result scene should delegate filled ellipse drawing")
	_expect(source.find("StageClearResultShapeHelper.draw_ellipse_polyline") >= 0, "result scene should delegate ellipse polyline drawing")
	_expect(source.find("StageClearResultShapeHelper.draw_star_polygon") >= 0, "result scene should delegate star polygon drawing")
	_expect(source.find("StageClearResultShapeHelper.draw_panel") >= 0, "result scene should delegate panel drawing")
	_expect(source.find("StageClearResultShapeHelper.draw_fitted_texture") >= 0, "result scene should delegate fitted texture drawing")
	_expect(source.find("StageClearResultShapeHelper.draw_fallback_reward_icon") >= 0, "result scene should delegate fallback reward icon drawing")
	_expect(source.find("func _draw_radial_burst") < 0, "result scene should not keep radial burst drawing wrappers")
	_expect(source.find("func _draw_shadow_ellipse") < 0, "result scene should not keep shadow ellipse drawing wrappers")
	_expect(source.find("func _draw_filled_ellipse") < 0, "result scene should not keep filled ellipse drawing wrappers")
	_expect(source.find("func _draw_ellipse_polyline") < 0, "result scene should not keep ellipse polyline drawing wrappers")
	_expect(source.find("func _draw_star_polygon") < 0, "result scene should not keep star polygon drawing wrappers")
	_expect(source.find("func _draw_panel") < 0, "result scene should not keep panel drawing wrappers")
	_expect(source.find("func _draw_texture_fit") < 0, "result scene should not keep fitted texture drawing wrappers")
	_expect(source.find("func _draw_fallback_reward_icon") < 0, "result scene should not keep fallback reward icon drawing wrappers")
	_expect(source.find("func _draw_box_corner_braces") < 0, "result scene should not keep unused corner-brace drawing helpers")
	_expect(source.find("func _draw_box_lock") < 0, "result scene should not keep unused box-lock drawing helpers")
	_expect(source.find("StageClearResultShapeHelper.box_hover_glow_layers") >= 0, "result scene should delegate hover glow layer generation")
	_expect(source.find("StageClearResultShapeHelper.box_hover_sparkles") >= 0, "result scene should delegate hover sparkle generation")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_vec(actual: Vector2, expected: Vector2, message: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s got %s" % [message, expected, actual])
