extends SceneTree

const StageClearResultBoxPresenter := preload("res://scripts/ui/stage_clear_result_box_presenter.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_context_builder_contract()
	_verify_presenter_contract()
	_verify_presenter_source()
	_verify_scene_delegates_box_presenter()

	if _failures.is_empty():
		print("stage_clear_result_box_presenter_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_context_builder_contract() -> void:
	var reward_icon_cache := {"gold": "cached"}
	var result: Dictionary = StageClearResultBoxPresenter.get_floating_box_draw_context(
		2.5,
		"visible",
		0.8,
		3,
		null,
		null,
		null,
		reward_icon_cache
	)
	_expect(float(result.get("timer", 0.0)) == 2.5, "floating-box context should include scene timer")
	_expect(str(result.get("scroll_phase", "")) == "visible", "floating-box context should include scroll phase")
	_expect(float(result.get("scroll_timer", 0.0)) == 0.8, "floating-box context should include scroll timer")
	_expect(int(result.get("hovered_box_index", -1)) == 3, "floating-box context should include hovered box index")
	_expect(result.has("result_box_sheet_common"), "floating-box context should include common sheet key")
	_expect(result.has("result_box_sheet_mythic"), "floating-box context should include mythic sheet key")
	_expect(result.has("result_box_sheet_guaranteed_mythic"), "floating-box context should include guaranteed mythic sheet key")
	_expect(result.get("reward_icon_cache", {}) == reward_icon_cache, "floating-box context should preserve reward icon cache")


func _verify_presenter_contract() -> void:
	_expect(StageClearResultBoxPresenter != null, "box presenter preload should resolve")
	StageClearResultBoxPresenter.draw_floating_boxes(null, [], 1.0, {})
	StageClearResultBoxPresenter.draw_floating_boxes(
		null,
		[{"kind": "normal", "state": "idle", "base_pos": Vector2.ZERO}],
		1.0,
		{"hovered_box_index": 0}
	)


func _verify_presenter_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_presenter.gd")
	_expect(source.find("static func get_floating_box_draw_context") >= 0, "box presenter should expose floating-box draw context assembly")
	_expect(source.find("static func draw_floating_boxes") >= 0, "box presenter should expose floating-box draw orchestration")
	_expect(source.find("for i in range(boxes.size())") >= 0, "box presenter should own floating-box iteration")
	_expect(source.find("StageClearResultBoxDrawHelper.build_floating_result_box_draw_context") >= 0, "box presenter should delegate draw context assembly")
	_expect(source.find("StageClearResultBoxDrawHelper.draw_floating_result_box") >= 0, "box presenter should delegate box drawing")
	_expect(source.find("StageClearResultScrollState.SCROLL_UNFURL_DURATION") >= 0, "box presenter should pass the scroll reveal timing")


func _verify_scene_delegates_box_presenter() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
	_expect(source.find("StageClearResultDrawSceneHandler.draw_result_scene") >= 0, "result scene should delegate top-level drawing through the draw scene handler")
	_expect(draw_scene_handler_source.find("StageClearResultBoxSceneHandler.draw_floating_boxes") >= 0, "draw scene handler should delegate floating-box drawing through the box scene handler")
	_expect(source.find("StageClearResultBoxPresenter.") < 0, "result scene should not call the box presenter directly")
	_expect(scene_handler_source.find("StageClearResultBoxPresenter.draw_floating_boxes") >= 0, "box scene handler should delegate floating-box drawing to the presenter")
	_expect(scene_handler_source.find("StageClearResultBoxPresenter.get_floating_box_draw_context") >= 0, "box scene handler should delegate floating-box draw context assembly to the presenter")
	_expect(source.find("_get_floating_box_draw_context") < 0, "result scene should not keep floating-box draw context wrappers")
	_expect(scene_handler_source.find("static func get_floating_box_draw_context") >= 0, "box scene handler should own floating-box draw scene-context glue")
	_expect(source.find("StageClearResultBoxDrawHelper.draw_floating_result_box") < 0, "result scene should not draw floating boxes directly")
	_expect(source.find("StageClearResultBoxDrawHelper.build_floating_result_box_draw_context") < 0, "result scene should not build floating-box draw context directly")
	_expect(source.find("func _draw_floating_box(") < 0, "result scene should not keep a per-box draw wrapper")
	_expect(source.find("func _draw_floating_boxes") < 0, "result scene should not keep floating-box draw fanout wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
