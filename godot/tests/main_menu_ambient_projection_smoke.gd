extends SceneTree

const MainMenuAmbient := preload("res://scripts/ui/main_menu_ambient.gd")
const MainMenuAmbientProjection := preload("res://scripts/ui/main_menu_ambient_projection.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_source_screen_projection()
	_verify_rect_and_line_clipping()
	_verify_sweep_fade_and_hash_math()
	_verify_mask_classification()
	_verify_ambient_boundary_contract()
	if _failures.is_empty():
		print("main_menu_ambient_projection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_source_screen_projection() -> void:
	var source_size := MainMenuAmbientProjection.BACKGROUND_SOURCE_SIZE
	_expect(MainMenuAmbientProjection.background_source_scale(source_size) == Vector2.ONE, "native-size background should use unit scale")
	var half_view := source_size * 0.5
	_expect(MainMenuAmbientProjection.background_source_scale(half_view).is_equal_approx(Vector2(0.5, 0.5)), "half-size view should use half source scale")
	var source_point := Vector2(560.0, 382.0)
	var screen_point := MainMenuAmbientProjection.source_to_screen(source_point, half_view)
	_expect(screen_point.is_equal_approx(source_point * 0.5), "source point should scale into the view")
	_expect(MainMenuAmbientProjection.screen_to_source(screen_point, half_view).is_equal_approx(source_point), "source/screen transforms should roundtrip")
	var logo_rect := MainMenuAmbientProjection.source_rect_to_screen(MainMenuAmbientProjection.LOGO_GLINT_SOURCE_RECT, half_view)
	_expect(logo_rect.position.is_equal_approx(MainMenuAmbientProjection.LOGO_GLINT_SOURCE_RECT.position * 0.5), "logo rect position should use source scale")
	_expect(logo_rect.size.is_equal_approx(MainMenuAmbientProjection.LOGO_GLINT_SOURCE_RECT.size * 0.5), "logo rect size should use source scale")
	_expect(MainMenuAmbientProjection.source_rect_to_screen(MainMenuAmbientProjection.LOGO_GLINT_SOURCE_RECT, Vector2.ONE) == Rect2(), "degenerate view should reject source projection")


func _verify_rect_and_line_clipping() -> void:
	var bounds := Rect2(10.0, 20.0, 100.0, 60.0)
	_expect(MainMenuAmbientProjection.intersect_rect(bounds, Rect2(60.0, 40.0, 100.0, 60.0)) == Rect2(60.0, 40.0, 50.0, 40.0), "rect intersection should preserve the shared area")
	_expect(MainMenuAmbientProjection.intersect_rect(bounds, Rect2(200.0, 200.0, 10.0, 10.0)) == Rect2(), "disjoint rects should return empty")
	var horizontal := MainMenuAmbientProjection.clipped_line_to_rect(Vector2(0.0, 50.0), Vector2(140.0, 50.0), bounds)
	_expect(horizontal.size() == 2, "crossing line should produce two clipped endpoints")
	if horizontal.size() == 2:
		_expect(horizontal[0].is_equal_approx(Vector2(10.0, 50.0)) and horizontal[1].is_equal_approx(Vector2(110.0, 50.0)), "horizontal line should clip at left/right bounds")
	_expect(MainMenuAmbientProjection.clipped_line_to_rect(Vector2(0.0, 5.0), Vector2(140.0, 5.0), bounds).is_empty(), "parallel outside line should be rejected")


func _verify_sweep_fade_and_hash_math() -> void:
	var rect := Rect2(20.0, 40.0, 200.0, 100.0)
	_expect(is_equal_approx(MainMenuAmbientProjection.sweep_x_at_y(40.0, rect, 80.0, 30.0), 80.0), "sweep top should start at center x")
	_expect(is_equal_approx(MainMenuAmbientProjection.sweep_x_at_y(140.0, rect, 80.0, 30.0), 110.0), "sweep bottom should include full tilt")
	_expect(is_zero_approx(MainMenuAmbientProjection.sparkle_fade_curve(-1.0)), "fade curve should clamp below zero")
	_expect(is_equal_approx(MainMenuAmbientProjection.sparkle_fade_curve(0.5), 0.5), "smootherstep midpoint should remain 0.5")
	_expect(is_equal_approx(MainMenuAmbientProjection.sparkle_fade_curve(2.0), 1.0), "fade curve should clamp above one")
	var hash_value := MainMenuAmbientProjection.hash01(12.345)
	_expect(hash_value >= 0.0 and hash_value < 1.0, "ambient hash should stay in [0, 1)")
	_expect(is_equal_approx(hash_value, MainMenuAmbientProjection.hash01(12.345)), "ambient hash should be deterministic")


func _verify_mask_classification() -> void:
	_expect(MainMenuAmbientProjection.is_source_point_inside_logo_word(Vector2(100.0, 340.0)), "first logo word rect should classify inside")
	_expect(not MainMenuAmbientProjection.is_source_point_inside_logo_word(Vector2(500.0, 340.0)), "gap between logo words should classify outside")
	_expect(MainMenuAmbientProjection.is_logo_letter_color(Color.WHITE, Color.BLACK), "bright neutral changed pixel should classify as logo lettering")
	_expect(not MainMenuAmbientProjection.is_logo_letter_color(Color(0.1, 0.1, 0.1), Color.BLACK), "dark changed pixel should fail the lettering luma gate")
	_expect(not MainMenuAmbientProjection.is_logo_letter_color(Color(1.0, 1.0, 0.0), Color.BLACK), "high-chroma pixel should fail the lettering neutrality gate")
	_expect(MainMenuAmbientProjection.is_logo_orb_effect_color(Color.WHITE, Color.BLACK, MainMenuAmbientProjection.LOGO_ORB_SOURCE_CENTER), "bright changed orb-core pixel should classify")
	_expect(not MainMenuAmbientProjection.is_logo_orb_effect_color(Color.WHITE, Color.WHITE, MainMenuAmbientProjection.LOGO_ORB_SOURCE_CENTER), "unchanged orb pixel should fail the difference gate")


func _verify_ambient_boundary_contract() -> void:
	var ambient_source := FileAccess.get_file_as_string("res://scripts/ui/main_menu_ambient.gd")
	var projection_source := FileAccess.get_file_as_string("res://scripts/ui/main_menu_ambient_projection.gd")
	_expect(_function_body(ambient_source, "func _clipped_line_to_rect(").find("MainMenuAmbientProjection.clipped_line_to_rect") >= 0, "ambient line-clipping facade should delegate")
	_expect(_function_body(ambient_source, "func _source_to_screen(").find("MainMenuAmbientProjection.source_to_screen") >= 0, "ambient source projection facade should delegate")
	_expect(_function_body(ambient_source, "func _is_logo_letter_color(").find("MainMenuAmbientProjection.is_logo_letter_color") >= 0, "ambient letter classifier facade should delegate")
	_expect(_function_body(ambient_source, "func _hash01(").find("MainMenuAmbientProjection.hash01") >= 0, "ambient hash facade should delegate")
	_expect(projection_source.find("CanvasItem") < 0 and projection_source.find("FileAccess") < 0 and projection_source.find("Image") < 0, "ambient projection should remain draw-, I/O-, and image-free")
	var ambient := MainMenuAmbient.new()
	_expect(ambient._source_to_screen(Vector2(100.0, 50.0), Vector2(1456.0, 816.0)).is_equal_approx(MainMenuAmbientProjection.source_to_screen(Vector2(100.0, 50.0), Vector2(1456.0, 816.0))), "ambient compatibility facade should preserve projection output")
	ambient.free()


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
