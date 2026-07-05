extends SceneTree

const StageClearResultScrollContentDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_source()
	_verify_scene_delegates_scroll_content_draw()

	if _failures.is_empty():
		print("stage_clear_result_scroll_content_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd")
	_expect(source.find("static func draw_scroll_contents") >= 0, "scroll content helper should own opened-scroll content drawing")
	_expect(source.find("StageClearResultSummaryDrawHelper.draw_result_summary_strip") >= 0, "scroll content helper should draw the result summary strip")
	_expect(source.find("StageClearResultRewardCardDrawHelper.draw_reward_section_stack") >= 0, "scroll content helper should draw reward sections")
	_expect(source.find("StageClearResultScrollButtonDrawHelper.draw_scroll_buttons") >= 0, "scroll content helper should draw scroll buttons")
	_expect(source.find("static func _build_reward_sections") >= 0, "scroll content helper should assemble reward sections")
	_expect(StageClearResultScrollContentDrawHelper != null, "scroll content helper preload should resolve")
	_expect(
		StageClearResultScrollContentDrawHelper.draw_scroll_contents(
			null,
			null,
			Rect2(Vector2(10.0, 20.0), Vector2(300.0, 420.0)),
			1.0,
			1.0,
			{}
		).is_empty(),
		"scroll content helper should ignore null canvas draw requests"
	)


func _verify_scene_delegates_scroll_content_draw() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var scroll_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_scene_handler.gd")
	var presenter_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_presenter.gd")
	_expect(source.find("StageClearResultDrawSceneHandler.draw_result_scene") >= 0, "result scene should delegate draw fanout through the draw scene handler")
	_expect(draw_scene_handler_source.find("StageClearResultScrollSceneHandler.draw_scroll") >= 0, "draw scene handler should route opened-scroll presentation through the scroll scene handler")
	_expect(scroll_scene_handler_source.find("StageClearResultScrollPresenter.draw_scroll") >= 0, "scroll scene handler should delegate opened-scroll presentation")
	_expect(source.find("StageClearResultScrollPresenter.draw_scroll") < 0, "result scene should not delegate opened-scroll presentation directly")
	_expect(presenter_source.find("StageClearResultScrollContentDrawHelper.draw_scroll_contents") >= 0, "scroll presenter should delegate opened-scroll content drawing")
	_expect(source.find("StageClearResultSummaryDrawHelper") < 0, "result scene should not directly draw result summary strip")
	_expect(source.find("StageClearResultRewardCardDrawHelper") < 0, "result scene should not directly draw reward sections")
	_expect(source.find("StageClearResultScrollButtonDrawHelper") < 0, "result scene should not directly draw scroll buttons")
	_expect(source.find("StageClearResultTextLayoutHelper.draw_centered_text") < 0, "result scene should not directly draw opened-scroll content text")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
