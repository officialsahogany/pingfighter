extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LINGPET_FONT_PATH := "res://assets/fonts/LingpetScript-Regular.ttf"
const LINGPET_DISPLAY_FONT_PATH := "res://assets/fonts/LingpetScriptDisplay-Regular.ttf"

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_verify_lingpet_font_loads()
	_verify_lingpet_display_font_loads()

	if _failures.is_empty():
		print("lingpet_font_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lingpet_font_loads() -> void:
	var font := ProjectResourceLoader.load_font(
		LINGPET_FONT_PATH,
		"Missing Lingpet Script font: %s",
		"Failed to load Lingpet Script font: %s"
	)
	_expect(font != null, "Lingpet Script font should load from repo asset path")
	if font == null:
		return
	var sample_size := font.get_string_size("tu toho na langa *", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	_expect(sample_size.x > 0.0, "Lingpet Script font should measure sample glyph width")
	_expect(sample_size.y > 0.0, "Lingpet Script font should measure sample glyph height")


func _verify_lingpet_display_font_loads() -> void:
	# Ornate geometric/circuit display font (AI-glyph-traced) for lore pages/titles.
	var font := ProjectResourceLoader.load_font(
		LINGPET_DISPLAY_FONT_PATH,
		"Missing Lingpet Script Display font: %s",
		"Failed to load Lingpet Script Display font: %s"
	)
	_expect(font != null, "Lingpet Script Display font should load from repo asset path")
	if font == null:
		return
	var sample_size := font.get_string_size("varatha kova *", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	_expect(sample_size.x > 0.0, "Lingpet Script Display font should measure sample glyph width")
	_expect(sample_size.y > 0.0, "Lingpet Script Display font should measure sample glyph height")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
