extends SceneTree

const StageClearResultScrollDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_draw_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_source()
	_verify_scene_delegates_scroll_draw()

	if _failures.is_empty():
		print("stage_clear_result_scroll_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_draw_helper.gd")
	_expect(source.find("static func draw_cyber_scroll_fallback") >= 0, "scroll draw helper should own cyber-scroll fallback drawing")
	_expect(source.find("static func draw_section_group_panel") >= 0, "scroll draw helper should own section group panel drawing")
	_expect(source.find("StageClearResultShapeHelper.draw_panel") >= 0, "scroll fallback drawing should delegate panel drawing")
	_expect(source.find("rod_height") >= 0, "scroll fallback drawing should keep top / bottom rod sizing")
	_expect(StageClearResultScrollDrawHelper != null, "scroll draw helper preload should resolve")

	StageClearResultScrollDrawHelper.draw_cyber_scroll_fallback(
		null,
		Rect2(Vector2(10.0, 20.0), Vector2(300.0, 420.0)),
		1.0,
		1.0
	)


func _verify_scene_delegates_scroll_draw() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultScrollDrawHelper.draw_cyber_scroll_fallback") >= 0, "result scene should delegate cyber-scroll fallback drawing")
	_expect(source.find("StageClearResultScrollDrawHelper.draw_section_group_panel") >= 0, "result scene should delegate section group panel drawing")
	_expect(source.find("func _draw_cyber_scroll_fallback") < 0, "result scene should not keep cyber-scroll fallback drawing wrappers")
	_expect(source.find("func _draw_section_group_panel") < 0, "result scene should not keep section group panel drawing wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
