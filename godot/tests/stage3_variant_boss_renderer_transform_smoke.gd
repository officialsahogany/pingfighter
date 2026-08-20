extends SceneTree

const Stage3VariantBossRenderer := preload(
	"res://scripts/stages/stage3/stage3_variant_boss_renderer.gd"
)

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_transform_safe_source()
	_verify_ellipse_geometry_sweep()
	if failures.is_empty():
		print("stage3_variant_boss_renderer_transform_smoke: ok")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_transform_safe_source() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage3/stage3_variant_boss_renderer.gd"
	)
	var transform_mutator := "draw_set_" + "transform"
	_expect(
		source.find(transform_mutator) < 0,
		"Stage 3 variant boss rendering must never replace its caller-owned transform"
	)
	_expect(
		source.find("draw_colored_polygon(points, color)") >= 0,
		"ellipse fill must use direct playfield-coordinate polygon vertices"
	)
	_expect(
		source.find("Geometry2D.triangulate_polygon(points)") >= 0,
		"ellipse fill must retain the GRT-006 triangulation guard"
	)


func _verify_ellipse_geometry_sweep() -> void:
	var renderer := Stage3VariantBossRenderer.new()
	var radii_cases: Array[Vector2] = [
		Vector2(6.0, 4.0),
		Vector2(42.0, 9.0),
		Vector2(13.0, 27.0),
		Vector2(90.0, 25.0),
	]
	for segments in [24, 32]:
		for radii in radii_cases:
			var points: PackedVector2Array = renderer.build_ellipse_points_for_tests(
				Vector2(380.0, 375.0), radii, segments
			)
			var triangles := Geometry2D.triangulate_polygon(points)
			_expect(
				points.size() == segments,
				"ellipse builder must preserve the declared segment count"
			)
			_expect(
				triangles.size() == (segments - 2) * 3,
				"every Teddy/Alice ellipse must remain fully triangulable"
			)
	var minimum_points: PackedVector2Array = renderer.build_ellipse_points_for_tests(
		Vector2.ZERO, Vector2(12.0, 8.0), 1
	)
	_expect(minimum_points.size() == 3, "ellipse builder must clamp to a valid polygon")
	_expect(
		Geometry2D.triangulate_polygon(minimum_points).size() == 3,
		"minimum ellipse fallback must still triangulate"
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
