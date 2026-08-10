extends SceneTree

const PlazaInteriorDrawPrimitives := preload("res://scripts/plaza/plaza_interior_draw_primitives.gd")

var _failures: Array[String] = []


func _init() -> void:
	var font := ThemeDB.fallback_font
	_expect(font != null, "fallback font should exist")
	if font != null:
		var lines := PlazaInteriorDrawPrimitives.wrap_text(font, "하나 둘 셋 넷 다섯", 42.0, 12, 3)
		_expect(not lines.is_empty(), "wrapped text should produce lines")
		_expect(lines.size() <= 3, "wrapped text should honor max lines")
		_expect(" ".join(lines).begins_with("하나"), "wrapped text should preserve word order")
		_expect(PlazaInteriorDrawPrimitives.wrap_text(font, "text", 0.0, 12, 3).is_empty(), "zero width should reject wrapping")
		_expect(PlazaInteriorDrawPrimitives.wrap_text(font, "text", 42.0, 0, 3).is_empty(), "zero font size should reject wrapping")
		_expect(PlazaInteriorDrawPrimitives.wrap_text(font, "text", 42.0, 12, 0).is_empty(), "zero line count should reject wrapping")
	if _failures.is_empty():
		print("plaza_interior_draw_primitives_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
