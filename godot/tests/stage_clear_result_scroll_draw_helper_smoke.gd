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
	_expect(source.find("static func draw_cyber_scroll_frame") >= 0, "scroll draw helper should own cyber-scroll frame drawing")
	_expect(source.find("static func draw_cyber_scroll_texture") >= 0, "scroll draw helper should own authored cyber-scroll texture drawing")
	_expect(source.find("canvas.draw_texture_rect_region") >= 0, "scroll draw helper should render authored scroll texture through a source region")
	_expect(source.find("static func draw_cyber_scroll_fallback") >= 0, "scroll draw helper should own cyber-scroll fallback drawing")
	_expect(source.find("static func draw_section_group_panel") >= 0, "scroll draw helper should own section group panel drawing")
	_expect(source.find("StageClearResultShapeHelper.draw_panel") >= 0, "scroll fallback drawing should delegate panel drawing")
	_expect(source.find("rod_height") >= 0, "scroll fallback drawing should keep top / bottom rod sizing")
	_expect(StageClearResultScrollDrawHelper != null, "scroll draw helper preload should resolve")

	_expect(
		not StageClearResultScrollDrawHelper.draw_cyber_scroll_texture(
			null,
			null,
			Rect2(Vector2(10.0, 20.0), Vector2(300.0, 420.0)),
			1.0
		),
		"scroll draw helper should reject null canvas / texture requests"
	)

	StageClearResultScrollDrawHelper.draw_cyber_scroll_fallback(
		null,
		Rect2(Vector2(10.0, 20.0), Vector2(300.0, 420.0)),
		1.0,
		1.0
	)
	StageClearResultScrollDrawHelper.draw_cyber_scroll_frame(
		null,
		null,
		Rect2(Vector2(10.0, 20.0), Vector2(300.0, 420.0)),
		Rect2(Vector2(10.0, 20.0), Vector2(300.0, 120.0)),
		1.0,
		0.5
	)


func _verify_scene_delegates_scroll_draw() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var scroll_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_scene_handler.gd")
	var presenter_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_presenter.gd")
	var content_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd")
	_expect(source.find("StageClearResultDrawSceneHandler.draw_result_scene") >= 0, "result scene should delegate top-level drawing through the draw scene handler")
	_expect(draw_scene_handler_source.find("StageClearResultScrollSceneHandler.draw_scroll") >= 0, "draw scene handler should delegate cyber-scroll scene drawing")
	_expect(scroll_scene_handler_source.find("StageClearResultScrollPresenter.draw_scroll") >= 0, "scroll scene handler should delegate cyber-scroll presentation")
	_expect(source.find("StageClearResultScrollPresenter.draw_scroll") < 0, "result scene should not call the scroll presenter directly")
	_expect(presenter_source.find("StageClearResultScrollDrawHelper.draw_cyber_scroll_frame") >= 0, "scroll presenter should delegate cyber-scroll frame drawing")
	_expect(content_source.find("StageClearResultScrollDrawHelper.draw_section_group_panel") >= 0, "scroll content helper should delegate section group panel drawing")
	_expect(source.find("StageClearResultShapeHelper.draw_filled_ellipse") < 0, "result scene should not keep cyber-scroll shadow drawing")
	_expect(source.find("draw_texture_rect_region(_scroll_texture") < 0, "result scene should not keep authored scroll texture-region drawing")
	_expect(source.find("func _draw_cyber_scroll_fallback") < 0, "result scene should not keep cyber-scroll fallback drawing wrappers")
	_expect(source.find("func _draw_section_group_panel") < 0, "result scene should not keep section group panel drawing wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
