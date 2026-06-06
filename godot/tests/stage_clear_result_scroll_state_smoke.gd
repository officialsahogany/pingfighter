extends SceneTree

const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_scroll_phase()
	_verify_direct_visual_values()
	_verify_direct_scroll_geometry()
	_verify_scene_scroll_delegates()
	_verify_scene_scroll_drag()

	if _failures.is_empty():
		print("stage_clear_result_scroll_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_scroll_phase() -> void:
	var scroll_delay: float = StageClearResultScrollState.SCROLL_DELAY
	_expect(
		scroll_delay > StageClearResultBoxData.BOX_REWARD_EMERGE_DURATION,
		"result scroll should wait until the final box reward has emerged"
	)
	var result: Dictionary = StageClearResultScrollState.update_phase("hidden", 0.0, 0.1, false, false, scroll_delay, 0.95)
	_expect(str(result.get("phase", "")) == "hidden", "scroll should stay hidden until every box opens")
	result = StageClearResultScrollState.update_phase("hidden", 0.0, 0.1, false, true, scroll_delay, 0.95)
	_expect(str(result.get("phase", "")) == "delay", "scroll should enter delay after every box opens")
	_expect(float(result.get("timer", -1.0)) == 0.0, "scroll delay should start from zero")
	result = StageClearResultScrollState.update_phase("delay", scroll_delay - 0.18, 0.17, false, true, scroll_delay, 0.95)
	_expect(str(result.get("phase", "")) == "delay", "scroll delay should accumulate before threshold")
	result = StageClearResultScrollState.update_phase("delay", scroll_delay - 0.18, 0.18, false, true, scroll_delay, 0.95)
	_expect(str(result.get("phase", "")) == "unfurling", "scroll should unfurl after the delay threshold")
	result = StageClearResultScrollState.update_phase("unfurling", 0.90, 0.05, false, true, scroll_delay, 0.95)
	_expect(str(result.get("phase", "")) == "visible", "scroll should become visible after unfurl duration")
	_expect(_is_close(float(result.get("timer", 0.0)), 0.95), "visible scroll should clamp timer to unfurl duration")
	result = StageClearResultScrollState.update_phase("delay", 0.2, 0.5, true, true, scroll_delay, 0.95)
	_expect(str(result.get("phase", "")) == "delay" and _is_close(float(result.get("timer", 0.0)), 0.2), "blocked scroll should keep phase and timer")


func _verify_direct_visual_values() -> void:
	_expect(StageClearResultScrollState.get_unfurl_progress("hidden", 0.0, 0.95) == 0.0, "hidden scroll progress should be zero")
	_expect(StageClearResultScrollState.get_unfurl_progress("visible", 0.0, 0.95) == 1.0, "visible scroll progress should be full")
	_expect(_is_close(StageClearResultScrollState.get_unfurl_progress("unfurling", 0.475, 0.95), 0.5), "unfurl progress should smooth at halfway")
	_expect(StageClearResultScrollState.get_box_global_alpha("hidden", 0.0, 0.95) == 1.0, "hidden boxes should stay fully opaque")
	_expect(StageClearResultScrollState.get_box_global_alpha("visible", 0.95, 0.95) == 0.04, "visible scroll should fade boxes to the floor alpha")
	_expect(StageClearResultScrollState.get_box_global_alpha("unfurling", 0.475, 0.95) < 1.0, "unfurling boxes should fade out")


func _verify_direct_scroll_geometry() -> void:
	var base_rect := StageClearResultScrollState.get_base_rect(
		1.0,
		StageClearResultScrollState.SCROLL_REGION_RECT
	)
	_expect(base_rect.position == Vector2(340.0, 96.0), "scroll geometry helper should build the authored base position")
	_expect(base_rect.size == Vector2(1240.0, 904.0), "scroll geometry helper should build the authored scroll size")
	var full_rect := StageClearResultScrollState.get_full_rect(
		1.0,
		Vector2(80.0, -40.0),
		StageClearResultScrollState.SCROLL_REGION_RECT
	)
	_expect(full_rect.position == base_rect.position + Vector2(80.0, -40.0), "scroll full rect should add the live drag offset")
	_expect(
		StageClearResultScrollState.get_region_full_rect(1.0, Vector2(80.0, -40.0)) == full_rect,
		"scroll state region full rect helper should use the authored result scroll region"
	)
	var clamped := StageClearResultScrollState.clamp_offset(
		Vector2(2000.0, -2000.0),
		1.0,
		Vector2(1920.0, 1080.0),
		StageClearResultScrollState.SCROLL_DRAG_VIEW_MARGIN,
		StageClearResultScrollState.SCROLL_REGION_RECT
	)
	_expect(clamped.x < 2000.0 and clamped.y > -2000.0, "scroll offset helper should clamp drags to the visible margin")
	_expect(
		StageClearResultScrollState.clamp_region_offset(Vector2(2000.0, -2000.0), 1.0, Vector2(1920.0, 1080.0)) == clamped,
		"scroll state region clamp helper should use the authored drag margin"
	)
	_expect(
		StageClearResultScrollState.get_region_drag_offset(
			base_rect.position + Vector2(120.0, 120.0) + Vector2(80.0, -40.0),
			Vector2(120.0, 120.0),
			1.0,
			Vector2(1920.0, 1080.0)
		) == Vector2(80.0, -40.0),
		"scroll state should derive region drag offsets from mouse and grab positions"
	)


func _verify_scene_scroll_delegates() -> void:
	var scene := StageClearResultScene.new()
	scene._boxes = [
		{"state": "opened"},
	]
	scene._update_scroll(0.1)
	_expect(str(scene._scroll_phase) == "delay", "scene scroll updater should delegate hidden-to-delay transition")
	scene._update_scroll(StageClearResultScrollState.SCROLL_DELAY)
	_expect(str(scene._scroll_phase) == "unfurling", "scene scroll updater should delegate delay-to-unfurl transition")
	_expect(
		StageClearResultScrollState.get_unfurl_progress(scene._scroll_phase, scene._scroll_timer, StageClearResultScrollState.SCROLL_UNFURL_DURATION) == 0.0,
		"scene scroll fields should remain compatible with the delegated unfurl helper"
	)
	scene._update_scroll(0.95)
	_expect(str(scene._scroll_phase) == "visible", "scene scroll updater should delegate unfurl-to-visible transition")
	_expect(
		StageClearResultScrollState.get_box_global_alpha(scene._scroll_phase, scene._scroll_timer, StageClearResultScrollState.SCROLL_UNFURL_DURATION) == 0.04,
		"scene scroll fields should remain compatible with the delegated box-alpha helper"
	)
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var presenter_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_presenter.gd")
	var update_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_update_handler.gd")
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_state.gd")
	var box_draw_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_draw_helper.gd")
	_expect(
		source.find("StageClearResultScrollUpdateHandler.update_scroll") >= 0
			and update_handler_source.find("StageClearResultScrollState.update_phase") >= 0,
		"scene scroll updates should route through the scroll update handler"
	)
	_expect(
		presenter_source.find("StageClearResultScrollState.get_unfurl_progress") >= 0
			and box_draw_source.find("StageClearResultScrollState.get_box_global_alpha") >= 0,
		"scroll presenter / box draw helper should delegate scroll visual helpers"
	)
	_expect(
		source.find("const SCROLL_REGION_TOP") < 0
			and source.find("const SCROLL_REGION_RECT") < 0
			and source.find("const SCROLL_CONTENT_MARGIN") < 0
			and source.find("const SCROLL_DRAG_VIEW_MARGIN") < 0
			and helper_source.find("const SCROLL_REGION_RECT") >= 0
			and helper_source.find("const SCROLL_CONTENT_MARGIN") >= 0
			and helper_source.find("const SCROLL_DRAG_VIEW_MARGIN") >= 0,
		"scroll state should own authored scroll geometry constants"
	)
	_expect(
		source.find("func _get_scroll_base_rect") < 0
			and source.find("func _get_scroll_full_rect") < 0
			and source.find("func _clamp_scroll_offset") < 0
			and presenter_source.find("StageClearResultScrollState.get_region_full_rect") >= 0
			and presenter_source.find("StageClearResultScrollState.clamp_region_offset") >= 0,
		"result scene should not keep scroll geometry pass-through wrappers; presenter should call the state helpers"
	)
	_expect(
		source.find("func _get_scroll_unfurl_progress") < 0
		and source.find("func _get_box_global_alpha") < 0,
		"result scene should not keep scroll visual pass-through wrappers"
	)
	scene.free()


func _verify_scene_scroll_drag() -> void:
	var scene := StageClearResultScene.new()
	scene.size = Vector2(1920.0, 1080.0)
	scene._scroll_phase = "visible"
	scene._scroll_timer = StageClearResultScrollState.SCROLL_UNFURL_DURATION
	scene._boxes = [{"state": "opened"}]
	var base_rect: Rect2 = StageClearResultScrollState.get_full_rect(
		1.0,
		Vector2.ZERO,
		StageClearResultScrollState.SCROLL_REGION_RECT
	)
	var grab_point: Vector2 = base_rect.position + Vector2(120.0, 120.0)
	_expect(scene._start_scroll_drag(grab_point), "visible scroll body should start drag")
	_expect(bool(scene.get_interaction_status().get("scroll_dragging", false)), "scroll status should expose active drag")

	var drag_to: Vector2 = grab_point + Vector2(80.0, -40.0)
	scene._update_scroll_drag(drag_to)
	var dragged_status: Dictionary = scene.get_interaction_status()
	_expect(dragged_status.get("scroll_position_offset", Vector2.ZERO) == Vector2(80.0, -40.0), "scroll drag should store the dragged offset")
	var dragged_rect: Rect2 = dragged_status.get("scroll_rect", Rect2())
	_expect(dragged_rect.position == base_rect.position + Vector2(80.0, -40.0), "scroll rect should move with the stored offset")

	scene._finish_scroll_drag(drag_to)
	_expect(not bool(scene.get_interaction_status().get("scroll_dragging", true)), "scroll drag should clear on release")
	scene._refresh_scroll_button_rects()
	_expect(not scene._start_scroll_drag(scene._next_stage_button_rect.get_center()), "scroll drag should not steal visible button clicks")
	scene.free()


func _is_close(actual: float, expected: float, tolerance: float = 0.001) -> bool:
	return abs(actual - expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
