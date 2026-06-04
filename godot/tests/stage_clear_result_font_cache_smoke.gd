extends SceneTree

const StageClearResultFontCache := preload("res://scripts/ui/stage_clear_result_font_cache.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_font_cache()
	_verify_scene_delegates_font_cache()

	if _failures.is_empty():
		print("stage_clear_result_font_cache_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_font_cache() -> void:
	var cache := StageClearResultFontCache.new()
	var font_a: Font = cache.get_font(1.0)
	var font_b: Font = cache.get_font(1.0)
	var font_c: Font = cache.get_font(2.0)
	_expect(font_a != null, "font cache should return a fallback font variation")
	_expect(font_a == font_b, "font cache should reuse the same variation for the same scale")
	_expect(font_c != null, "font cache should rebuild for a different scale")


func _verify_scene_delegates_font_cache() -> void:
	var scene_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_font_cache.gd")
	_expect(scene_source.find("StageClearResultFontCache") >= 0, "result scene should own a font cache helper")
	_expect(scene_source.find("_font_cache.get_font") >= 0, "result scene should request UI fonts from the cache helper")
	_expect(scene_source.find("func _get_ui_font") < 0, "result scene should not keep the UI font cache implementation")
	_expect(helper_source.find("FontVariation.new") >= 0, "font cache should build FontVariation resources")
	_expect(helper_source.find("TextServer.SPACING_GLYPH") >= 0, "font cache should preserve glyph spacing")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
