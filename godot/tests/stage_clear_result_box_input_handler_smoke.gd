extends SceneTree

const StageClearResultBoxInputHandler := preload("res://scripts/ui/stage_clear_result_box_input_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_open_next_idle_box()
	_verify_box_click_result()
	_verify_hover_result()
	_verify_open_apply_result()
	_verify_box_state_apply_result()
	_verify_scene_applies_box_state_result()
	_verify_scene_delegates_box_input()

	if _failures.is_empty():
		print("stage_clear_result_box_input_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_open_next_idle_box() -> void:
	var boxes: Array = [
		{"state": "opened", "kind": "normal", "reward": {"type": "active"}},
		{"state": "idle", "kind": "normal", "roll_kind": "advanced", "reward": {}},
	]
	var result: Dictionary = StageClearResultBoxInputHandler.open_next_idle_box(
		boxes,
		Callable(self, "_roll_callback")
	)
	_expect(bool(result.get("started", false)), "box input helper should start the next idle box")
	_expect(bool(result.get("consumed", false)), "box input helper should consume successful open requests")
	_expect(int(result.get("opened_index", -1)) == 1, "box input helper should report opened box index")
	var updated_boxes: Array = result.get("boxes", [])
	var opened_box: Dictionary = updated_boxes[1] if updated_boxes.size() > 1 and updated_boxes[1] is Dictionary else {}
	var reward: Dictionary = opened_box.get("reward", {}) as Dictionary
	_expect(str(opened_box.get("state", "")) == "opening", "box input helper should move opened boxes into opening state")
	_expect(str(reward.get("rolled_kind", "")) == "advanced", "box input helper should preserve roll_kind reward routing")
	_expect(str((boxes[1] as Dictionary).get("state", "")) == "idle", "box input helper should not mutate source boxes")

	var none_result: Dictionary = StageClearResultBoxInputHandler.open_next_idle_box(
		[{"state": "opened", "kind": "normal"}],
		Callable(self, "_roll_callback")
	)
	_expect(not bool(none_result.get("started", true)), "box input helper should report no start when no idle box exists")


func _verify_box_click_result() -> void:
	var boxes: Array = [
		{
			"state": "idle",
			"kind": "normal",
			"roll_kind": "normal",
			"reward": {},
			"base_pos": Vector2(120.0, 140.0),
			"amplitude": 0.0,
			"speed": 0.0,
		},
	]
	var hidden_result: Dictionary = StageClearResultBoxInputHandler.get_box_click_result(
		boxes,
		Vector2(120.0, 140.0),
		"hidden",
		false,
		1.0,
		0.0,
		Callable(self, "_roll_callback")
	)
	_expect(bool(hidden_result.get("started", false)), "box input helper should open clicked idle boxes while scroll is hidden")
	_expect(bool(hidden_result.get("consumed", false)), "box input helper should consume clicked idle boxes")

	var visible_result: Dictionary = StageClearResultBoxInputHandler.get_box_click_result(
		boxes,
		Vector2(120.0, 140.0),
		"visible",
		false,
		1.0,
		0.0,
		Callable(self, "_roll_callback")
	)
	_expect(not bool(visible_result.get("started", true)), "box input helper should not open boxes after scroll is visible")
	_expect(not bool(visible_result.get("consumed", true)), "box input helper should not consume visible-scroll misses")

	var blocked_result: Dictionary = StageClearResultBoxInputHandler.get_box_click_result(
		boxes,
		Vector2(120.0, 140.0),
		"hidden",
		true,
		1.0,
		0.0,
		Callable(self, "_roll_callback")
	)
	_expect(not bool(blocked_result.get("started", true)), "box input helper should not open boxes while blocked")
	_expect(bool(blocked_result.get("consumed", false)), "box input helper should consume blocked box clicks")


func _verify_hover_result() -> void:
	var boxes: Array = [
		{"state": "idle", "base_pos": Vector2(100.0, 120.0), "amplitude": 0.0, "speed": 0.0},
		{"state": "idle", "base_pos": Vector2(180.0, 120.0), "amplitude": 0.0, "speed": 0.0},
	]
	var result: Dictionary = StageClearResultBoxInputHandler.get_hovered_box_result(
		boxes,
		Vector2(180.0, 120.0),
		1.0,
		0.0,
		-1
	)
	_expect(int(result.get("hovered_box_index", -1)) == 1, "box input helper should report hovered box indices")
	_expect(bool(result.get("changed", false)), "box input helper should report hover changes")

	var empty_result: Dictionary = StageClearResultBoxInputHandler.get_hovered_box_result([], Vector2.ZERO, 1.0, 0.0, 3)
	_expect(int(empty_result.get("hovered_box_index", 99)) == -1, "box input helper should clear hover for empty boxes")
	_expect(bool(empty_result.get("changed", false)), "box input helper should report hover clear changes")

	var apply_result: Dictionary = StageClearResultBoxInputHandler.get_hovered_box_apply_result(result, -1)
	_expect(int(apply_result.get("hovered_box_index", -1)) == 1, "hover apply helper should apply hovered box index")
	_expect(bool(apply_result.get("redraw", false)), "hover apply helper should redraw changed hovers")

	var unchanged_apply: Dictionary = StageClearResultBoxInputHandler.get_hovered_box_apply_result(
		{
			"hovered_box_index": 1,
			"changed": false,
		},
		0
	)
	_expect(int(unchanged_apply.get("hovered_box_index", -1)) == 1, "hover apply helper should preserve unchanged hovered index")
	_expect(not bool(unchanged_apply.get("redraw", true)), "hover apply helper should not redraw unchanged hovers")


func _verify_open_apply_result() -> void:
	var current_boxes: Array = [
		{"state": "idle"},
		{"state": "idle"},
	]
	var opened_boxes: Array = [
		{"state": "idle"},
		{"state": "opening"},
	]
	var result: Dictionary = StageClearResultBoxInputHandler.get_box_open_apply_result(
		{
			"started": true,
			"consumed": true,
			"opened_index": 1,
			"boxes": opened_boxes,
		},
		current_boxes,
		1
	)
	_expect(bool(result.get("started", false)), "apply helper should preserve started state")
	_expect(bool(result.get("consumed", false)), "apply helper should preserve consumed state")
	_expect(result.get("boxes", []) == opened_boxes, "apply helper should pass opened boxes to the scene")
	_expect(int(result.get("hovered_box_index", 99)) == -1, "apply helper should clear hover for opened boxes")
	_expect(bool(result.get("play_open_audio", false)), "apply helper should request open audio for started boxes")
	_expect(bool(result.get("redraw", false)), "apply helper should request redraw for started boxes")

	var miss_result: Dictionary = StageClearResultBoxInputHandler.get_box_open_apply_result(
		{"started": false, "consumed": true},
		current_boxes,
		0
	)
	_expect(not bool(miss_result.get("started", true)), "apply helper should preserve missed start state")
	_expect(bool(miss_result.get("consumed", false)), "apply helper should preserve blocked/missed consumption")
	_expect(miss_result.get("boxes", []) == current_boxes, "apply helper should keep current boxes for missed starts")
	_expect(int(miss_result.get("hovered_box_index", -99)) == 0, "apply helper should keep hover for missed starts")
	_expect(not bool(miss_result.get("play_open_audio", true)), "apply helper should not request audio for missed starts")
	_expect(not bool(miss_result.get("redraw", true)), "apply helper should not request redraw for missed starts")


func _verify_box_state_apply_result() -> void:
	var current_boxes: Array = [{"state": "idle"}]
	var updated_boxes: Array = [{"state": "opening"}]
	var result: Dictionary = StageClearResultBoxInputHandler.get_box_state_apply_result(
		{
			"started": true,
			"consumed": true,
			"boxes": updated_boxes,
			"hovered_box_index": -1,
			"play_open_audio": true,
			"redraw": true,
		},
		current_boxes,
		2
	)
	_expect(bool(result.get("started", false)), "box-state apply helper should preserve started state")
	_expect(bool(result.get("consumed", false)), "box-state apply helper should preserve consumed state")
	_expect(result.get("boxes", []) == updated_boxes, "box-state apply helper should apply boxes arrays")
	_expect(int(result.get("hovered_box_index", 99)) == -1, "box-state apply helper should apply hover index")
	_expect(bool(result.get("play_open_audio", false)), "box-state apply helper should preserve audio request")
	_expect(bool(result.get("redraw", false)), "box-state apply helper should preserve redraw request")

	var fallback_result: Dictionary = StageClearResultBoxInputHandler.get_box_state_apply_result(
		{
			"boxes": "invalid",
		},
		current_boxes,
		3
	)
	_expect(not bool(fallback_result.get("started", true)), "missing started should default to false")
	_expect(not bool(fallback_result.get("consumed", true)), "missing consumed should default to false")
	_expect(fallback_result.get("boxes", []) == current_boxes, "invalid boxes payload should keep current boxes")
	_expect(int(fallback_result.get("hovered_box_index", -99)) == 3, "missing hover index should keep current hover")
	_expect(not bool(fallback_result.get("play_open_audio", true)), "missing audio request should default to false")
	_expect(not bool(fallback_result.get("redraw", true)), "missing redraw request should default to false")

	var scene_apply: Dictionary = StageClearResultBoxInputHandler.get_box_state_scene_apply_result(
		{
			"started": true,
			"consumed": true,
			"boxes": updated_boxes,
			"hovered_box_index": -1,
			"play_open_audio": true,
			"redraw": true,
		},
		current_boxes,
		2
	)
	var field_payload_value: Variant = scene_apply.get("field_payload", {})
	_expect(field_payload_value is Dictionary, "box-state scene apply helper should wrap scene fields in a field payload")
	var field_payload: Dictionary = field_payload_value if field_payload_value is Dictionary else {}
	_expect(bool(scene_apply.get("started", false)), "box-state scene apply helper should preserve started state")
	_expect(bool(scene_apply.get("consumed", false)), "box-state scene apply helper should preserve consumed state")
	_expect(bool(scene_apply.get("play_open_audio", false)), "box-state scene apply helper should preserve audio request")
	_expect(bool(scene_apply.get("redraw", false)), "box-state scene apply helper should preserve redraw request")
	_expect(field_payload.get("_boxes", []) == updated_boxes, "box-state scene field payload should write boxes")
	_expect(int(field_payload.get("_hovered_box_index", 99)) == -1, "box-state scene field payload should write hover index")


func _verify_scene_applies_box_state_result() -> void:
	var scene := StageClearResultScene.new()
	var current_boxes: Array = [{"state": "idle"}]
	var updated_boxes: Array = [{"state": "opening"}]
	scene.set("_boxes", current_boxes)
	scene.set("_hovered_box_index", 1)
	var apply_result: Dictionary = scene._apply_box_state_result({
		"boxes": updated_boxes,
		"hovered_box_index": -1,
		"redraw": false,
	})
	_expect(scene.get("_boxes") == updated_boxes, "scene box-state apply should write boxes through helper")
	_expect(int(scene.get("_hovered_box_index")) == -1, "scene box-state apply should write hover through helper")
	_expect(apply_result.get("boxes", []) == updated_boxes, "scene box-state apply should return normalized boxes")
	scene.free()


func _verify_scene_delegates_box_input() -> void:
	var scene_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_input_handler.gd")
	var open_apply_source: String = _slice_function(scene_source, "func _apply_box_open_result", "func _apply_box_state_result")
	var hover_apply_source: String = _slice_function(scene_source, "func _update_hovered_box", "func _handle_player_victory_click")
	_expect(scene_source.find("StageClearResultBoxInputHandler.open_next_idle_box") >= 0, "result scene should delegate next-idle opening")
	_expect(scene_source.find("StageClearResultBoxInputHandler.get_box_click_result") >= 0, "result scene should delegate box click opening")
	_expect(scene_source.find("StageClearResultBoxInputHandler.get_hovered_box_result") >= 0, "result scene should delegate box hover state")
	_expect(scene_source.find("StageClearResultBoxInputHandler.get_hovered_box_apply_result") >= 0, "result scene should delegate box hover apply payloads")
	_expect(scene_source.find("StageClearResultBoxInputHandler.get_box_open_apply_result") >= 0, "result scene should delegate box-open apply payloads")
	_expect(scene_source.find("StageClearResultBoxInputHandler.get_box_state_scene_apply_result") >= 0, "result scene should delegate common box-state scene field payloads")
	_expect(open_apply_source.find("_hovered_box_index = int(apply_result.get") < 0, "box-open apply should not write hover directly")
	_expect(open_apply_source.find("_boxes = apply_result.get") < 0, "box-open apply should not write boxes directly")
	_expect(hover_apply_source.find("_hovered_box_index = int(apply_result.get") < 0, "box-hover apply should not write hover directly")
	_expect(scene_source.find("opened_index") < 0, "result scene should not inspect opened box indices directly")
	_expect(scene_source.find("result.get(\"changed\"") < 0, "result scene should not inspect box hover changes directly")
	_expect(scene_source.find("StageClearResultInteractionState.get_clicked_idle_box_index") < 0, "result scene should not hit-test clicked boxes directly")
	_expect(scene_source.find("StageClearResultInteractionState.get_hovered_box_index") < 0, "result scene should not hit-test hovered boxes directly")
	_expect(helper_source.find("static func get_box_state_apply_result") >= 0, "box input helper should expose common box-state apply payloads")
	_expect(helper_source.find("static func get_box_state_scene_apply_result") >= 0, "box input helper should expose scene field payloads")
	_expect(helper_source.find("StageClearResultBoxData.get_next_idle_box_index") >= 0, "box input helper should use box-data next idle selection")
	_expect(helper_source.find("StageClearResultBoxData.start_opening_box_with_roll") >= 0, "box input helper should use box-data opening setup")


func _roll_callback(kind: String) -> Dictionary:
	return {
		"type": "perk",
		"rolled_kind": kind,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
