extends SceneTree

const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")
const StageClearResultScrollUpdateHandler := preload("res://scripts/ui/stage_clear_result_scroll_update_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_update_handler_contract()
	_verify_update_apply_contract()
	_verify_scene_apply_contract()
	_verify_update_handler_source()
	_verify_scene_delegates_scroll_update_handler()

	if _failures.is_empty():
		print("stage_clear_result_scroll_update_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_update_handler_contract() -> void:
	_expect(StageClearResultScrollUpdateHandler != null, "scroll update handler preload should resolve")
	var hidden: Dictionary = StageClearResultScrollUpdateHandler.update_scroll(
		StageClearResultScrollState.PHASE_HIDDEN,
		0.0,
		0.1,
		[{"state": "opened"}],
		false
	)
	_expect(str(hidden.get("phase", "")) == StageClearResultScrollState.PHASE_DELAY, "scroll update handler should reveal after every box opens")
	_expect(float(hidden.get("timer", -1.0)) == 0.0, "scroll update handler should reset delay timer")

	var blocked: Dictionary = StageClearResultScrollUpdateHandler.update_scroll(
		StageClearResultScrollState.PHASE_DELAY,
		0.25,
		0.5,
		[{"state": "opened"}],
		true
	)
	_expect(str(blocked.get("phase", "")) == StageClearResultScrollState.PHASE_DELAY, "blocked scroll updates should preserve phase")
	_expect(abs(float(blocked.get("timer", 0.0)) - 0.25) <= 0.001, "blocked scroll updates should preserve timer")


func _verify_update_apply_contract() -> void:
	var apply_result: Dictionary = StageClearResultScrollUpdateHandler.get_scroll_update_apply_result(
		{
			"phase": StageClearResultScrollState.PHASE_VISIBLE,
			"timer": 1.25,
		},
		StageClearResultScrollState.PHASE_DELAY,
		0.5
	)
	_expect(str(apply_result.get("scroll_phase", "")) == StageClearResultScrollState.PHASE_VISIBLE, "scroll update apply helper should apply phase")
	_expect(abs(float(apply_result.get("scroll_timer", 0.0)) - 1.25) <= 0.001, "scroll update apply helper should apply timer")

	var fallback_result: Dictionary = StageClearResultScrollUpdateHandler.get_scroll_update_apply_result(
		{},
		StageClearResultScrollState.PHASE_UNFURLING,
		0.75
	)
	_expect(str(fallback_result.get("scroll_phase", "")) == StageClearResultScrollState.PHASE_UNFURLING, "scroll update apply helper should keep current phase when missing")
	_expect(abs(float(fallback_result.get("scroll_timer", 0.0)) - 0.75) <= 0.001, "scroll update apply helper should keep current timer when missing")


func _verify_scene_apply_contract() -> void:
	var scene_apply: Dictionary = StageClearResultScrollUpdateHandler.get_scroll_update_scene_apply_result(
		{
			"phase": StageClearResultScrollState.PHASE_VISIBLE,
			"timer": 1.25,
		},
		StageClearResultScrollState.PHASE_DELAY,
		0.5
	)
	var field_payload: Dictionary = scene_apply.get("field_payload", {}) as Dictionary
	_expect(str(field_payload.get("_scroll_phase", "")) == StageClearResultScrollState.PHASE_VISIBLE, "scroll update scene apply helper should map phase to scene field")
	_expect(abs(float(field_payload.get("_scroll_timer", 0.0)) - 1.25) <= 0.001, "scroll update scene apply helper should map timer to scene field")

	var scene := StageClearResultScene.new()
	scene.set("_scroll_phase", StageClearResultScrollState.PHASE_DELAY)
	scene.set("_scroll_timer", 0.5)
	scene._apply_scene_apply_result(scene_apply)
	_expect(str(scene.get("_scroll_phase")) == StageClearResultScrollState.PHASE_VISIBLE, "scene field payload helper should apply scroll phase")
	_expect(abs(float(scene.get("_scroll_timer")) - 1.25) <= 0.001, "scene field payload helper should apply scroll timer")
	scene.free()


func _verify_update_handler_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_update_handler.gd")
	_expect(source.find("static func update_scroll") >= 0, "scroll update handler should expose update_scroll")
	_expect(source.find("static func get_scroll_update_apply_result") >= 0, "scroll update handler should expose update apply payloads")
	_expect(source.find("static func get_scroll_update_scene_apply_result") >= 0, "scroll update handler should expose scene field apply payloads")
	_expect(source.find("StageClearResultInteractionState.all_boxes_opened") >= 0, "scroll update handler should delegate all-boxes-open checks")
	_expect(source.find("StageClearResultScrollState.update_phase") >= 0, "scroll update handler should delegate phase transitions")
	_expect(source.find("StageClearResultScrollState.SCROLL_DELAY") >= 0, "scroll update handler should pass scroll delay policy")
	_expect(source.find("StageClearResultScrollState.SCROLL_UNFURL_DURATION") >= 0, "scroll update handler should pass unfurl timing policy")


func _verify_scene_delegates_scroll_update_handler() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var update_scroll_source: String = _slice_function(source, "func _update_scroll", "func _draw_scroll")
	_expect(source.find("StageClearResultScrollUpdateHandler.update_scroll") >= 0, "result scene should delegate scroll update sequencing")
	_expect(source.find("StageClearResultScrollUpdateHandler.get_scroll_update_scene_apply_result") >= 0, "result scene should delegate scroll update scene field payloads")
	_expect(source.find("func _apply_scene_apply_result") >= 0, "result scene should centralize scene apply-result application")
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep the retired direct field-payload wrapper")
	_expect(update_scroll_source.find("_scroll_phase = str(apply_result.get") < 0, "result scene should not write scroll phase directly during scroll updates")
	_expect(update_scroll_source.find("_scroll_timer = float(apply_result.get") < 0, "result scene should not write scroll timer directly during scroll updates")
	_expect(update_scroll_source.find("result.get(\"phase\"") < 0, "result scene should not inspect scroll update phases directly")
	_expect(update_scroll_source.find("result.get(\"timer\"") < 0, "result scene should not inspect scroll update timers directly")
	_expect(source.find("StageClearResultScrollState.update_phase") < 0, "result scene should not update scroll phases directly")
	_expect(source.find("StageClearResultInteractionState.all_boxes_opened") < 0, "result scene should not check all boxes opened for scroll updates directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
