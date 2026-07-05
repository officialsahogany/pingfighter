extends SceneTree

const StageClearResultSummaryDrawHelper := preload("res://scripts/ui/stage_clear_result_summary_draw_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_source()
	_verify_scene_delegates_summary_draw()

	if _failures.is_empty():
		print("stage_clear_result_summary_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_summary_draw_helper.gd")
	_expect(source.find("static func draw_result_summary_strip") >= 0, "summary draw helper should own summary strip drawing")
	_expect(source.find("static func draw_metric_tile") >= 0, "summary draw helper should own metric tile drawing")
	_expect(source.find("static func draw_rating_tile") >= 0, "summary draw helper should own rating tile drawing")
	_expect(source.find("draw_metric_tile(canvas") >= 0, "summary strip drawing should use metric tile helpers")
	_expect(source.find("draw_rating_tile(canvas") >= 0, "summary strip drawing should use rating tile helpers")
	_expect(source.find("StageClearResultShapeHelper.draw_panel") >= 0, "summary draw helper should delegate panel drawing")
	_expect(source.find("StageClearResultShapeHelper.draw_star_polygon") >= 0, "summary draw helper should delegate star drawing")
	_expect(source.find("StageClearResultTextLayoutHelper.draw_text") >= 0, "summary draw helper should delegate text drawing")
	_expect(StageClearResultSummaryDrawHelper != null, "summary draw helper preload should resolve")


func _verify_scene_delegates_summary_draw() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var scroll_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_scene_handler.gd")
	var presenter_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_presenter.gd")
	var content_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd")
	_expect(
		source.find("StageClearResultDrawSceneHandler.draw_result_scene") >= 0
		and draw_scene_handler_source.find("StageClearResultScrollSceneHandler.draw_scroll") >= 0
		and scroll_scene_handler_source.find("StageClearResultScrollPresenter.draw_scroll") >= 0
		and presenter_source.find("StageClearResultScrollContentDrawHelper.draw_scroll_contents") >= 0,
		"result scene should delegate opened-scroll content drawing through draw / scroll scene handlers and the scroll presenter"
	)
	_expect(source.find("StageClearResultScrollPresenter.draw_scroll") < 0, "result scene should not delegate opened-scroll content drawing directly through the scroll presenter")
	_expect(content_source.find("StageClearResultSummaryDrawHelper.draw_result_summary_strip") >= 0, "scroll content helper should delegate summary strip drawing")
	_expect(source.find("func _draw_result_summary_strip") < 0, "result scene should not keep summary strip drawing wrappers")
	_expect(source.find("func _draw_metric_tile") < 0, "result scene should not keep metric tile wrappers")
	_expect(source.find("func _draw_rating_tile") < 0, "result scene should not keep rating tile wrappers")
	_expect(content_source.find("StageClearResultSummaryBuilder.resolve_display_gold") >= 0, "scroll content helper should keep summary metric calculation in summary builder")
	_expect(content_source.find("StageClearResultSummaryBuilder.calculate_score_rating") >= 0, "scroll content helper should keep rating calculation in summary builder")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
