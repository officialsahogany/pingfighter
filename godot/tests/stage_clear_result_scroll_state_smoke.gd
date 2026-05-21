extends SceneTree

const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_scroll_phase()
	_verify_direct_visual_values()
	_verify_scene_scroll_delegates()

	if _failures.is_empty():
		print("stage_clear_result_scroll_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_scroll_phase() -> void:
	var result: Dictionary = StageClearResultScrollState.update_phase("hidden", 0.0, 0.1, false, false, 0.38, 0.95)
	_expect(str(result.get("phase", "")) == "hidden", "scroll should stay hidden until every box opens")
	result = StageClearResultScrollState.update_phase("hidden", 0.0, 0.1, false, true, 0.38, 0.95)
	_expect(str(result.get("phase", "")) == "delay", "scroll should enter delay after every box opens")
	_expect(float(result.get("timer", -1.0)) == 0.0, "scroll delay should start from zero")
	result = StageClearResultScrollState.update_phase("delay", 0.2, 0.17, false, true, 0.38, 0.95)
	_expect(str(result.get("phase", "")) == "delay", "scroll delay should accumulate before threshold")
	result = StageClearResultScrollState.update_phase("delay", 0.2, 0.18, false, true, 0.38, 0.95)
	_expect(str(result.get("phase", "")) == "unfurling", "scroll should unfurl after the delay threshold")
	result = StageClearResultScrollState.update_phase("unfurling", 0.90, 0.05, false, true, 0.38, 0.95)
	_expect(str(result.get("phase", "")) == "visible", "scroll should become visible after unfurl duration")
	_expect(_is_close(float(result.get("timer", 0.0)), 0.95), "visible scroll should clamp timer to unfurl duration")
	result = StageClearResultScrollState.update_phase("delay", 0.2, 0.5, true, true, 0.38, 0.95)
	_expect(str(result.get("phase", "")) == "delay" and _is_close(float(result.get("timer", 0.0)), 0.2), "blocked scroll should keep phase and timer")


func _verify_direct_visual_values() -> void:
	_expect(StageClearResultScrollState.get_unfurl_progress("hidden", 0.0, 0.95) == 0.0, "hidden scroll progress should be zero")
	_expect(StageClearResultScrollState.get_unfurl_progress("visible", 0.0, 0.95) == 1.0, "visible scroll progress should be full")
	_expect(_is_close(StageClearResultScrollState.get_unfurl_progress("unfurling", 0.475, 0.95), 0.5), "unfurl progress should smooth at halfway")
	_expect(StageClearResultScrollState.get_box_global_alpha("hidden", 0.0, 0.95) == 1.0, "hidden boxes should stay fully opaque")
	_expect(StageClearResultScrollState.get_box_global_alpha("visible", 0.95, 0.95) == 0.04, "visible scroll should fade boxes to the floor alpha")
	_expect(StageClearResultScrollState.get_box_global_alpha("unfurling", 0.475, 0.95) < 1.0, "unfurling boxes should fade out")


func _verify_scene_scroll_delegates() -> void:
	var scene := StageClearResultScene.new()
	scene._boxes = [
		{"state": "opened"},
	]
	scene._update_scroll(0.1)
	_expect(str(scene._scroll_phase) == "delay", "scene scroll updater should delegate hidden-to-delay transition")
	scene._update_scroll(0.38)
	_expect(str(scene._scroll_phase) == "unfurling", "scene scroll updater should delegate delay-to-unfurl transition")
	_expect(
		StageClearResultScrollState.get_unfurl_progress(scene._scroll_phase, scene._scroll_timer, StageClearResultScene.SCROLL_UNFURL_DURATION) == 0.0,
		"scene scroll fields should remain compatible with the delegated unfurl helper"
	)
	scene._update_scroll(0.95)
	_expect(str(scene._scroll_phase) == "visible", "scene scroll updater should delegate unfurl-to-visible transition")
	_expect(
		StageClearResultScrollState.get_box_global_alpha(scene._scroll_phase, scene._scroll_timer, StageClearResultScene.SCROLL_UNFURL_DURATION) == 0.04,
		"scene scroll fields should remain compatible with the delegated box-alpha helper"
	)
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(
		source.find("StageClearResultScrollState.get_unfurl_progress") >= 0
		and source.find("StageClearResultScrollState.get_box_global_alpha") >= 0,
		"result scene should call scroll visual helpers directly"
	)
	_expect(
		source.find("func _get_scroll_unfurl_progress") < 0
		and source.find("func _get_box_global_alpha") < 0,
		"result scene should not keep scroll visual pass-through wrappers"
	)
	scene.free()


func _is_close(actual: float, expected: float, tolerance: float = 0.001) -> bool:
	return abs(actual - expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
