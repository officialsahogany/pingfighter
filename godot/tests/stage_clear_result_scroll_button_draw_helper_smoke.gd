extends SceneTree

const StageClearResultScrollButtonDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_button_draw_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_contract()
	_verify_scene_delegates_scroll_button_draw()

	if _failures.is_empty():
		print("stage_clear_result_scroll_button_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_button_draw_helper.gd")
	_expect(source.find("static func draw_scroll_buttons") >= 0, "scroll button draw helper should own scroll button drawing")
	_expect(source.find("StageClearResultInteractionState.get_scroll_button_layout") >= 0, "scroll button drawing should use interaction-state layout")
	_expect(source.find("StageClearResultShapeHelper.draw_panel") >= 0, "scroll button drawing should delegate panel drawing")
	_expect(source.find("StageClearResultTextLayoutHelper.draw_centered_text") >= 0, "scroll button drawing should delegate text drawing")
	_expect(StageClearResultScrollButtonDrawHelper != null, "scroll button draw helper preload should resolve")

	var layout: Dictionary = StageClearResultScrollButtonDrawHelper.draw_scroll_buttons(
		null,
		null,
		Rect2(Vector2(100.0, 200.0), Vector2(420.0, 360.0)),
		1.0,
		1.0,
		"visible",
		"next_stage",
		"Next",
		"Exit"
	)
	_expect(layout.has("next_stage_rect"), "helper should return next-stage button rect")
	_expect(layout.has("exit_rect"), "helper should return exit button rect")


func _verify_scene_delegates_scroll_button_draw() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var presenter_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_presenter.gd")
	var content_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd")
	var input_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_input_handler.gd")
	_expect(
		source.find("StageClearResultScrollPresenter.draw_scroll") >= 0
		and presenter_source.find("StageClearResultScrollContentDrawHelper.draw_scroll_contents") >= 0,
		"result scene should delegate opened-scroll content drawing through the scroll presenter"
	)
	_expect(content_source.find("StageClearResultScrollButtonDrawHelper.draw_scroll_buttons") >= 0, "scroll content helper should delegate scroll button drawing")
	_expect(source.find("func _draw_scroll_buttons") < 0, "result scene should not keep scroll button drawing wrappers")
	_expect(
		source.find("StageClearResultScrollPresenter.get_scroll_draw_apply_result") >= 0
		and source.find("StageClearResultScrollInputHandler.get_scroll_state_scene_apply_result") >= 0
		and input_source.find("\"_next_stage_button_rect\"") >= 0,
		"result scene should still store next-stage button rect through scroll apply payloads"
	)
	_expect(
		source.find("StageClearResultScrollInputHandler.get_scroll_state_scene_apply_result") >= 0
		and input_source.find("\"_exit_button_rect\"") >= 0,
		"result scene should still store exit button rect through scroll apply payloads"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
