extends SceneTree

const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_wrapping()
	_verify_font_fit()
	_verify_centered_baseline()
	_verify_scene_wrappers()

	if _failures.is_empty():
		print("stage_clear_result_text_layout_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_wrapping() -> void:
	var font: Font = ThemeDB.fallback_font
	var lines: Array[String] = StageClearResultTextLayoutHelper.wrap_words_to_width(
		font,
		"alpha beta gamma delta",
		18,
		font.get_string_size("alpha beta", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18).x + 1.0,
		3
	)
	_expect(lines.size() >= 2, "text layout helper should wrap words when the candidate line exceeds the max width")
	_expect(lines.size() <= 3, "text layout helper should respect max_lines")
	_expect(StageClearResultTextLayoutHelper.wrap_words_to_width(font, "one two three four", 18, 1.0, 1).size() == 1, "text layout helper should stop at max_lines")


func _verify_font_fit() -> void:
	var font: Font = ThemeDB.fallback_font
	var fitted: int = StageClearResultTextLayoutHelper.fit_font_size(font, "very very wide text", 48.0, 24, 10)
	_expect(fitted >= 10 and fitted <= 24, "text layout helper should keep fitted size inside bounds")
	_expect(StageClearResultTextLayoutHelper.fit_font_size(font, "short", 1000.0, 24, 10) == 24, "text layout helper should keep preferred size when text fits")


func _verify_centered_baseline() -> void:
	var font: Font = ThemeDB.fallback_font
	var rect := Rect2(Vector2(100.0, 200.0), Vector2(300.0, 80.0))
	var baseline: Vector2 = StageClearResultTextLayoutHelper.get_centered_baseline(font, "center", rect, 20)
	_expect(baseline.x >= rect.position.x and baseline.x <= rect.end.x, "centered baseline should stay horizontally inside the rect")
	_expect(baseline.y >= rect.position.y and baseline.y <= rect.end.y + 20.0, "centered baseline should stay near the rect vertical center")


func _verify_scene_wrappers() -> void:
	var scene := StageClearResultScene.new()
	var font: Font = ThemeDB.fallback_font
	_expect(scene._wrap_words_to_width(font, "alpha beta gamma delta", 18, 80.0, 2).size() <= 2, "result scene wrap wrapper should delegate")
	_expect(scene._fit_font_size(font, "wide text", 30.0, 22, 9) <= 22, "result scene font-fit wrapper should delegate")
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
