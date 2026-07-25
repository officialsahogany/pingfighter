extends SceneTree

const PlazaShopStrewnVisualSpec := preload("res://scripts/plaza/plaza_shop_strewn_visual_spec.gd")

var _failures: Array[String] = []


func _init() -> void:
	var meta := PlazaShopStrewnVisualSpec.get_animation_meta("coin_pile")
	_expect(str(meta.get("texture_key", "")) == "coin_pile_anim", "coin animation texture key")
	_expect(int(meta.get("cols", 0)) == 5 and int(meta.get("rows", 0)) == 5, "coin animation grid")
	_expect(int(meta.get("frames", 0)) == 25, "coin animation frame count")
	_expect_close(float(meta.get("duration", 0.0)), 0.72, "coin animation duration")
	_expect(PlazaShopStrewnVisualSpec.get_animation_meta("unknown").is_empty(), "unknown animation meta")

	_expect_vec(PlazaShopStrewnVisualSpec.get_texture_draw_size("coin_pile", Vector2.ONE), Vector2(108.0, 88.0), "coin texture size")
	_expect_vec(PlazaShopStrewnVisualSpec.get_texture_draw_size("wrench_tool", Vector2.ONE), Vector2(100.0, 66.0), "wrench texture size")
	_expect_vec(PlazaShopStrewnVisualSpec.get_texture_draw_size("unknown", Vector2(31.0, 47.0)), Vector2(31.0, 47.0), "fallback texture size")
	_expect_color(PlazaShopStrewnVisualSpec.get_color("money_bundle", Color.BLACK), Color(0.42, 1.0, 0.62, 1.0), "money color")
	_expect_color(PlazaShopStrewnVisualSpec.get_color("unknown", Color(0.2, 0.3, 0.4, 1.0)), Color(0.2, 0.3, 0.4, 1.0), "fallback color")

	_expect(PlazaShopStrewnVisualSpec.get_sheet_frame_rect(null, 5, 5, 0) == Rect2(), "null texture frame")
	var image := Image.create(100, 50, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	_expect_rect(PlazaShopStrewnVisualSpec.get_sheet_frame_rect(texture, 5, 5, -1), Rect2(0.0, 0.0, 20.0, 10.0), "negative frame clamp")
	_expect_rect(PlazaShopStrewnVisualSpec.get_sheet_frame_rect(texture, 5, 5, 7), Rect2(40.0, 10.0, 20.0, 10.0), "middle frame")
	_expect_rect(PlazaShopStrewnVisualSpec.get_sheet_frame_rect(texture, 5, 5, 99), Rect2(80.0, 40.0, 20.0, 10.0), "row clamp")
	_expect(PlazaShopStrewnVisualSpec.get_sheet_frame_rect(texture, 0, 5, 0) == Rect2(), "invalid grid")

	if _failures.is_empty():
		print("plaza_shop_strewn_visual_spec_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.4f, got %.4f" % [label, expected, actual])


func _expect_vec(actual: Vector2, expected: Vector2, label: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect_rect(actual: Rect2, expected: Rect2, label: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect_color(actual: Color, expected: Color, label: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
