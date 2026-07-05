extends SceneTree

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultBoxImmediateRewardData := preload("res://scripts/ui/stage_clear_result_box_immediate_reward_data.gd")
const StageClearResultBoxOpeningData := preload("res://scripts/ui/stage_clear_result_box_opening_data.gd")
const StageClearResultBoxPlanData := preload("res://scripts/ui/stage_clear_result_box_plan_data.gd")
const StageClearResultBoxResolvedRewardData := preload("res://scripts/ui/stage_clear_result_box_resolved_reward_data.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_standalone_preview_defaults()
	_verify_resolved_rewards()
	_verify_box_opening_state()
	_verify_box_opening_with_roll()
	_verify_resolved_perk_append()
	_verify_immediate_reward_payload()
	_verify_immediate_reward_grant_attempt()
	_verify_scene_delegates_box_data()

	if _failures.is_empty():
		print("stage_clear_result_box_data_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_standalone_preview_defaults() -> void:
	var defaults: Dictionary = StageClearResultBoxData.build_standalone_preview_defaults(5)
	_expect(int(defaults.get("player_score", 0)) == 5, "box data preview defaults should mirror reward count as player score")
	_expect(int(defaults.get("boss_score", -1)) == 0, "box data preview defaults should start boss score at zero")
	_expect(int(defaults.get("current_stage", 0)) == 1, "box data preview defaults should target Stage 1")
	var plan: Dictionary = defaults.get("reward_plan", {}) as Dictionary
	var boxes: Array = plan.get("boxes", []) as Array
	_expect(str(plan.get("summary", "")) != "", "box data preview defaults should build a visible summary text")
	_expect(int(plan.get("reward_count", 0)) == 5, "box data preview defaults should expose reward count")
	_expect(boxes.size() == 5, "box data preview defaults should create one normal box per reward")
	_expect(str((boxes[0] as Dictionary).get("kind", "")) == StageClearResultBoxData.BOX_KIND_NORMAL, "box data preview defaults should use normal boxes")
	_expect(StageClearResultBoxData.get_box_display_label("normal") == "일반 상자", "box data should expose Korean normal box labels")
	_expect(StageClearResultBoxData.get_box_display_label("advanced") == "고급 상자", "box data should expose Korean advanced box labels")
	_expect(StageClearResultBoxData.get_box_display_label("guaranteed_mythic") == "신화 확정 상자", "box data should expose Korean guaranteed mythic box labels")


func _verify_resolved_rewards() -> void:
	var boxes: Array = [
		{"kind": "normal", "state": "opened", "reward": {"type": "active", "id": "drive"}},
		{"kind": "advanced", "state": "opening", "reward": {}},
		{"kind": "guaranteed_mythic", "state": "opened", "reward": {"type": "mythic", "id": "star"}},
	]
	var rewards: Array = StageClearResultBoxData.get_resolved_rewards(boxes)
	_expect(rewards.size() == 2, "box data should collect only non-empty resolved rewards")
	_expect(str((rewards[0] as Dictionary).get("box_kind", "")) == "normal", "resolved reward should include source box kind")
	_expect(str((rewards[0] as Dictionary).get("box_state", "")) == "opened", "resolved reward should include source box state")
	_expect(str((rewards[1] as Dictionary).get("box_kind", "")) == "guaranteed_mythic", "resolved reward should preserve guaranteed mythic kind")
	(rewards[0] as Dictionary)["id"] = "mutated"
	_expect(str(((boxes[0] as Dictionary).get("reward", {}) as Dictionary).get("id", "")) == "drive", "resolved reward copies should not mutate source rewards")


func _verify_box_opening_state() -> void:
	var callback_reward := {"type": "perk", "id": "callback_reward"}
	var reward: Dictionary = StageClearResultBoxData.roll_reward(
		"normal",
		Callable(self, "_roll_callback").bind(callback_reward),
		1.0,
		2,
		3
	)
	_expect(str(reward.get("id", "")) == "callback_reward", "box data should prefer reward callback results")
	var mythic_reward: Dictionary = StageClearResultBoxData.roll_reward(
		"guaranteed_mythic",
		Callable(),
		1.0,
		2,
		3
	)
	_expect(str(mythic_reward.get("type", "")) == "mythic", "guaranteed mythic boxes should fall back to mythic rewards")

	var boxes: Array = [
		{"kind": "normal", "roll_kind": "normal", "state": "idle", "reward": {}},
		{"kind": "advanced", "state": "opened", "reward": {"type": "active"}, "reward_emerge": 0.2},
	]
	_expect(StageClearResultBoxData.get_next_idle_box_index(boxes) == 0, "box data should find the first idle box")
	_expect(StageClearResultBoxData.get_next_idle_box_index([{"state": "opened"}]) == -1, "box data should report no idle boxes")
	var start_result: Dictionary = StageClearResultBoxData.start_opening_box(boxes, 0, {"type": "active", "id": "drive"})
	_expect(bool(start_result.get("started", false)), "box data should start idle boxes")
	var started_boxes: Array = start_result.get("boxes", [])
	var opening_box: Dictionary = started_boxes[0] if started_boxes[0] is Dictionary else {}
	_expect(str(opening_box.get("state", "")) == "opening", "started box should enter opening state")
	_expect(str((opening_box.get("reward", {}) as Dictionary).get("id", "")) == "drive", "started box should store the rolled reward")

	var update_result: Dictionary = StageClearResultBoxData.update_box_opening_state(
		started_boxes,
		0.6,
		0
	)
	var updated_boxes: Array = update_result.get("boxes", [])
	var opened_box: Dictionary = updated_boxes[0] if updated_boxes[0] is Dictionary else {}
	var emerged_box: Dictionary = updated_boxes[1] if updated_boxes[1] is Dictionary else {}
	var opened_indices: Array = update_result.get("opened_indices", [])
	_expect(str(opened_box.get("state", "")) == "opened", "box data should transition completed opening boxes to opened")
	_expect(bool(opened_box.get("lid_open_fired", false)), "box data should fire lid-open state when threshold is crossed")
	_expect(int(opened_box.get("lid_open_id", 0)) == 1, "box data should assign lid-open ids")
	_expect(int(update_result.get("lid_open_counter", 0)) == 1, "box data should return updated lid-open counter")
	_expect(opened_indices == [0], "box data should report boxes that just opened")
	_expect(float(emerged_box.get("reward_emerge", 0.0)) > 0.2, "opened boxes should advance reward emerge progress")


func _roll_callback(_kind: String, reward: Dictionary) -> Dictionary:
	return reward


func _verify_box_opening_with_roll() -> void:
	var boxes: Array = [
		{"kind": "normal", "roll_kind": "advanced", "state": "idle", "reward": {}},
	]
	var result: Dictionary = StageClearResultBoxData.start_opening_box_with_roll(
		boxes,
		0,
		Callable(self, "_roll_kind_callback"),
		1.0,
		1,
		2
	)
	_expect(bool(result.get("started", false)), "box data should start opening boxes with an inline roll")
	var opened_boxes: Array = result.get("boxes", [])
	var box: Dictionary = opened_boxes[0] if opened_boxes[0] is Dictionary else {}
	var reward: Dictionary = box.get("reward", {}) as Dictionary
	_expect(str(reward.get("rolled_kind", "")) == "advanced", "box data should roll rewards from roll_kind when present")


func _roll_kind_callback(kind: String) -> Dictionary:
	return {"type": "perk", "rolled_kind": kind}


func _verify_resolved_perk_append() -> void:
	var boxes: Array = [
		{"kind": "normal", "state": "opened", "reward": {"type": "starpoint", "amount": 2}},
		{"kind": "normal", "state": "opened", "reward": {"type": "active", "id": "drive"}},
	]
	var result: Dictionary = StageClearResultBoxData.append_resolved_perk_reward(boxes, 0, {"perk_id": "dash"})
	_expect(bool(result.get("updated", false)), "box data should append resolved perk rewards to starpoint boxes")
	var updated_boxes: Array = result.get("boxes", [])
	var reward: Dictionary = (updated_boxes[0] as Dictionary).get("reward", {}) as Dictionary
	var resolved: Array = reward.get("resolved_perk_rewards", []) as Array
	_expect(resolved.size() == 1, "box data should add one resolved perk reward")
	_expect(str((resolved[0] as Dictionary).get("source", "")) == "box_starpoint_choice", "box data should tag box starpoint choices")
	_expect(int(reward.get("resolved_perk_count", 0)) == 1, "box data should maintain resolved perk count")
	_expect(not bool(StageClearResultBoxData.append_resolved_perk_reward(boxes, 1, {"perk_id": "dash"}).get("updated", true)), "box data should ignore non-starpoint rewards")
	_expect(not bool(StageClearResultBoxData.append_resolved_perk_reward(boxes, 0, {}).get("updated", true)), "box data should ignore empty resolved perk rewards")

	var apply_result: Dictionary = StageClearResultBoxData.get_append_resolved_perk_reward_apply_result(
		result,
		boxes
	)
	_expect(bool(apply_result.get("updated", false)), "box data append apply helper should preserve updated state")
	_expect(apply_result.get("boxes", []) == updated_boxes, "box data append apply helper should apply updated boxes")
	_expect(bool(apply_result.get("redraw", false)), "box data append apply helper should request redraw for updates")

	var missed_apply: Dictionary = StageClearResultBoxData.get_append_resolved_perk_reward_apply_result(
		{"updated": false, "boxes": updated_boxes},
		boxes
	)
	_expect(not bool(missed_apply.get("updated", true)), "box data append apply helper should preserve missed state")
	_expect(missed_apply.get("boxes", []) == boxes, "box data append apply helper should keep current boxes for misses")
	_expect(not bool(missed_apply.get("redraw", true)), "box data append apply helper should not redraw misses")

	var scene_apply: Dictionary = StageClearResultBoxData.get_append_resolved_perk_reward_scene_apply_result(
		result,
		boxes
	)
	var field_payload_value: Variant = scene_apply.get("field_payload", {})
	_expect(field_payload_value is Dictionary, "box data append scene apply helper should wrap scene fields in a field payload")
	var field_payload: Dictionary = field_payload_value if field_payload_value is Dictionary else {}
	_expect(bool(scene_apply.get("updated", false)), "box data append scene apply helper should preserve updated state")
	_expect(bool(scene_apply.get("redraw", false)), "box data append scene apply helper should preserve redraw requests")
	_expect(field_payload.get("_boxes", []) == updated_boxes, "box data append scene field payload should write boxes")


func _verify_immediate_reward_payload() -> void:
	var box: Dictionary = {
		"kind": "advanced",
		"state": "opened",
		"reward": {"type": "mythic", "id": "meteor"},
	}
	var payload: Dictionary = StageClearResultBoxData.build_immediate_reward_payload(
		box,
		{
			"pickup_position": Vector2(120.0, 240.0),
			"target_player_center": Vector2(620.0, 300.0),
		}
	)
	_expect(str(payload.get("id", "")) == "meteor", "immediate payload should copy the opened reward")
	_expect(str(payload.get("box_kind", "")) == "advanced", "immediate payload should include source box kind")
	_expect(str(payload.get("box_state", "")) == "opened", "immediate payload should include source box state")
	_expect(payload.get("pickup_position", null) is Vector2, "immediate payload should include pickup position")
	_expect(payload.get("target_player_center", null) is Vector2, "immediate payload should include target position")
	payload["id"] = "mutated"
	_expect(str((box.get("reward", {}) as Dictionary).get("id", "")) == "meteor", "immediate payload should not mutate source reward")

	var boxes: Array = [box]
	var marked: Array = StageClearResultBoxData.mark_immediate_reward_granted(boxes, 0)
	var marked_box: Dictionary = marked[0] if marked[0] is Dictionary else {}
	var marked_reward: Dictionary = marked_box.get("reward", {}) as Dictionary
	_expect(bool(marked_box.get("reward_immediate_granted", false)), "box data should mark immediate rewards as granted")
	_expect(bool(marked_reward.get("immediate_granted", false)), "box data should mark stored reward immediate_granted")
	_expect(not bool(box.get("reward_immediate_granted", false)), "box data should not mutate source boxes while marking grants")


func _verify_immediate_reward_grant_attempt() -> void:
	var boxes: Array = [
		{"kind": "advanced", "state": "opened", "reward": {"type": "mythic", "id": "meteor"}},
	]
	var result: Dictionary = StageClearResultBoxData.try_grant_immediate_reward(
		boxes,
		0,
		Callable(self, "_grant_callback"),
		{
			"pickup_position": Vector2(120.0, 240.0),
			"target_player_center": Vector2(620.0, 300.0),
		}
	)
	_expect(bool(result.get("granted", false)), "box data should report successful immediate grants")
	var updated_boxes: Array = result.get("boxes", [])
	var box: Dictionary = updated_boxes[0] if updated_boxes[0] is Dictionary else {}
	_expect(bool(box.get("reward_immediate_granted", false)), "box data should mark boxes after successful immediate grants")
	var payload: Dictionary = result.get("reward", {}) as Dictionary
	_expect(str(payload.get("grant_seen_id", "")) == "meteor", "box data should expose the callback-mutated payload")


func _grant_callback(reward: Dictionary, _index: int) -> bool:
	reward["grant_seen_id"] = str(reward.get("id", ""))
	return true


func _verify_scene_delegates_box_data() -> void:
	var box_data_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_data.gd")
	var box_immediate_reward_data_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_immediate_reward_data.gd")
	var box_opening_data_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_opening_data.gd")
	var box_plan_data_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_plan_data.gd")
	var box_resolved_reward_data_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_resolved_reward_data.gd")
	var scene_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var box_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
	var config_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
	var navigation_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_navigation_scene_handler.gd")
	var input_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_input_scene_handler.gd")
	var update_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_update_scene_handler.gd")
	var immediate_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_immediate_reward_helper.gd")
	var box_input_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_input_handler.gd")
	var box_update_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_update_handler.gd")
	var preview_defaults_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_preview_defaults_handler.gd")
	var starpoint_choice_handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_starpoint_choice_handler.gd")
	var starpoint_choice_state_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_starpoint_choice_state.gd")
	var reward_grant_handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_reward_grant_handler.gd")
	_expect(StageClearResultBoxPlanData != null, "box plan data helper should load")
	_expect(box_plan_data_source.find("static func build_standalone_preview_defaults") >= 0, "box plan data should own standalone preview defaults")
	_expect(box_plan_data_source.find("static func build_boxes_from_plan") >= 0, "box plan data should own reward-plan box materialization")
	_expect(box_plan_data_source.find("static func normalize_box_kind") >= 0, "box plan data should own box kind normalization")
	_expect(box_plan_data_source.find("static func get_box_display_label") >= 0, "box plan data should own box display labels")
	_expect(box_plan_data_source.find("일반 상자") >= 0, "box plan data should keep Korean normal box fallback label")
	_expect(box_plan_data_source.find("고급 상자") >= 0, "box plan data should keep Korean advanced box fallback label")
	_expect(box_plan_data_source.find("신화 확정 상자") >= 0, "box plan data should keep Korean guaranteed mythic fallback label")
	_expect(box_data_source.find("StageClearResultBoxPlanData.build_standalone_preview_defaults") >= 0, "box data should delegate standalone preview defaults")
	_expect(box_data_source.find("StageClearResultBoxPlanData.build_boxes_from_plan") >= 0, "box data should delegate reward-plan box materialization")
	_expect(box_data_source.find("StageClearResultBoxPlanData.normalize_box_kind") >= 0, "box data should delegate box kind normalization")
	_expect(box_data_source.find("StageClearResultBoxPlanData.get_box_display_label") >= 0, "box data should delegate box display labels")
	_expect(StageClearResultBoxResolvedRewardData != null, "box resolved reward data helper should load")
	_expect(box_resolved_reward_data_source.find("static func get_resolved_rewards") >= 0, "box resolved reward data should own resolved reward extraction")
	_expect(box_resolved_reward_data_source.find("static func append_resolved_perk_reward") >= 0, "box resolved reward data should own resolved perk appends")
	_expect(box_resolved_reward_data_source.find("static func get_append_resolved_perk_reward_apply_result") >= 0, "box resolved reward data should own resolved perk append apply payloads")
	_expect(box_resolved_reward_data_source.find("static func get_append_resolved_perk_reward_scene_apply_result") >= 0, "box resolved reward data should own resolved perk append scene field payloads")
	_expect(box_data_source.find("static func get_resolved_rewards") >= 0, "box data should expose resolved reward extraction")
	_expect(box_data_source.find("static func get_append_resolved_perk_reward_apply_result") >= 0, "box data should expose resolved perk append apply payloads")
	_expect(box_data_source.find("static func get_append_resolved_perk_reward_scene_apply_result") >= 0, "box data should expose resolved perk append scene field payloads")
	_expect(box_data_source.find("StageClearResultBoxResolvedRewardData.get_resolved_rewards") >= 0, "box data should delegate resolved reward extraction")
	_expect(box_data_source.find("StageClearResultBoxResolvedRewardData.append_resolved_perk_reward") >= 0, "box data should delegate resolved perk appends")
	_expect(box_data_source.find("StageClearResultBoxResolvedRewardData.get_append_resolved_perk_reward_apply_result") >= 0, "box data should delegate resolved perk append apply payloads")
	_expect(box_data_source.find("StageClearResultBoxResolvedRewardData.get_append_resolved_perk_reward_scene_apply_result") >= 0, "box data should delegate resolved perk append scene field payloads")
	_expect(screen_source.find("StageClearResultBoxSceneHandler.get_resolved_rewards(_scene_node)") < 0, "result screen should not collect resolved rewards directly")
	_expect(reward_grant_handler_source.find("StageClearResultBoxSceneHandler.get_resolved_rewards(scene)") >= 0, "reward grant handler should collect resolved rewards through the box scene handler")
	_expect(scene_source.find("func get_resolved_rewards") < 0, "result scene should not keep a resolved reward facade")
	_expect(box_scene_handler_source.find("StageClearResultBoxData.get_resolved_rewards") >= 0, "box scene handler should delegate resolved reward extraction")
	_expect(box_input_helper_source.find("StageClearResultBoxData.start_opening_box_with_roll") >= 0, "box input helper should delegate rolled opening box setup")
	_expect(box_input_helper_source.find("StageClearResultBoxData.get_next_idle_box_index") >= 0, "box input helper should delegate next idle box selection")
	_expect(navigation_scene_handler_source.find("StageClearResultBoxSceneHandler.open_next_idle_box") >= 0, "navigation scene handler should delegate next idle box opening through the box scene handler")
	_expect(input_scene_handler_source.find("StageClearResultBoxSceneHandler.handle_box_click") >= 0, "input scene handler should delegate clicked box opening through the box scene handler")
	_expect(update_scene_handler_source.find("StageClearResultBoxSceneHandler.update_boxes") >= 0, "update scene handler should delegate box update sequencing through the box scene handler")
	_expect(scene_source.find("func _open_next_idle_box") < 0, "result scene should not keep next-idle box wrappers")
	_expect(scene_source.find("func _handle_box_click") < 0, "result scene should not keep box-click wrappers")
	_expect(scene_source.find("func _update_boxes") < 0, "result scene should not keep box update wrappers")
	_expect(box_scene_handler_source.find("StageClearResultBoxInputHandler.open_next_idle_box") >= 0, "box scene handler should delegate next idle box opening through the input helper")
	_expect(box_scene_handler_source.find("StageClearResultBoxUpdateHandler.update_boxes") >= 0, "box scene handler should delegate box update sequencing through the update handler")
	_expect(StageClearResultBoxOpeningData != null, "box opening data helper should load")
	_expect(box_opening_data_source.find("static func roll_reward") >= 0, "box opening data should own reward rolling")
	_expect(box_opening_data_source.find("static func start_opening_box") >= 0, "box opening data should own opening setup")
	_expect(box_opening_data_source.find("static func start_opening_box_with_roll") >= 0, "box opening data should own rolled opening setup")
	_expect(box_opening_data_source.find("static func get_next_idle_box_index") >= 0, "box opening data should own next-idle selection")
	_expect(box_opening_data_source.find("static func update_box_opening_state") >= 0, "box opening data should own opening animation state")
	_expect(box_data_source.find("StageClearResultBoxOpeningData.roll_reward") >= 0, "box data should delegate reward rolling")
	_expect(box_data_source.find("StageClearResultBoxOpeningData.start_opening_box") >= 0, "box data should delegate opening setup")
	_expect(box_data_source.find("StageClearResultBoxOpeningData.start_opening_box_with_roll") >= 0, "box data should delegate rolled opening setup")
	_expect(box_data_source.find("StageClearResultBoxOpeningData.get_next_idle_box_index") >= 0, "box data should delegate next-idle selection")
	_expect(box_data_source.find("StageClearResultBoxOpeningData.update_box_opening_state") >= 0, "box data should delegate opening animation state")
	_expect(box_update_helper_source.find("StageClearResultBoxData.update_box_opening_state") >= 0, "box update handler should delegate box opening animation state")
	_expect(screen_source.find("StageClearResultBoxSceneHandler.append_box_resolved_perk_reward(_scene_node") < 0, "result screen should not append box resolved perk rewards directly")
	_expect(starpoint_choice_handler_source.find("StageClearResultBoxSceneHandler.append_box_resolved_perk_reward") < 0, "starpoint choice handler should delegate box resolved perk reward appends")
	_expect(starpoint_choice_state_source.find("StageClearResultBoxSceneHandler.append_box_resolved_perk_reward") >= 0, "starpoint choice state should append box resolved perk rewards through the box scene handler")
	_expect(scene_source.find("func append_box_resolved_perk_reward") < 0, "result scene should not keep a resolved perk append facade")
	_expect(scene_source.find("StageClearResultBoxData.append_resolved_perk_reward") < 0, "result scene should not call box data append directly")
	_expect(scene_source.find("StageClearResultBoxData.get_append_resolved_perk_reward_scene_apply_result") < 0, "result scene should not call box data append scene payloads directly")
	_expect(box_scene_handler_source.find("StageClearResultBoxData.append_resolved_perk_reward") >= 0, "box scene handler should delegate box resolved perk appends")
	_expect(box_scene_handler_source.find("StageClearResultBoxData.get_append_resolved_perk_reward_scene_apply_result") >= 0, "box scene handler should delegate box resolved perk append scene field payloads")
	_expect(scene_source.find("result.get(\"updated\"") < 0, "result scene should not inspect append updated state directly")
	_expect(config_scene_handler_source.find("static func apply_standalone_preview_defaults") >= 0, "config scene handler should own standalone preview reward plan defaults scene glue")
	_expect(scene_source.find("StageClearResultConfigSceneHandler.apply_standalone_preview_defaults") < 0, "result scene should not keep standalone preview reward plan defaults pass-through glue")
	_expect(config_scene_handler_source.find("StageClearResultPreviewDefaultsHandler.get_standalone_preview_defaults") >= 0, "config scene handler should delegate standalone preview reward plan defaults through the preview handler")
	_expect(preview_defaults_source.find("StageClearResultBoxData.build_standalone_preview_defaults") >= 0, "preview defaults handler should delegate standalone reward plan data assembly")
	_expect(scene_source.find("StageClearResultBoxData.build_standalone_preview_defaults") < 0, "result scene should not build standalone preview defaults directly")
	_expect(StageClearResultBoxImmediateRewardData != null, "box immediate reward data helper should load")
	_expect(box_immediate_reward_data_source.find("static func build_immediate_reward_payload") >= 0, "box immediate reward data should own immediate reward payload assembly")
	_expect(box_immediate_reward_data_source.find("static func mark_immediate_reward_granted") >= 0, "box immediate reward data should own immediate reward grant marking")
	_expect(box_immediate_reward_data_source.find("static func try_grant_immediate_reward") >= 0, "box immediate reward data should own immediate reward grant attempts")
	_expect(box_data_source.find("static func build_immediate_reward_payload") >= 0, "box data should expose immediate reward payload assembly")
	_expect(box_data_source.find("static func mark_immediate_reward_granted") >= 0, "box data should expose immediate reward grant marking")
	_expect(box_data_source.find("StageClearResultBoxImmediateRewardData.build_immediate_reward_payload") >= 0, "box data should delegate immediate reward payload assembly")
	_expect(box_data_source.find("StageClearResultBoxImmediateRewardData.mark_immediate_reward_granted") >= 0, "box data should delegate immediate reward grant marking")
	_expect(box_data_source.find("StageClearResultBoxImmediateRewardData.try_grant_immediate_reward") >= 0, "box data should delegate immediate reward grant attempts")
	_expect(immediate_helper_source.find("StageClearResultBoxData.try_grant_immediate_reward") >= 0, "immediate helper should delegate immediate reward grant attempts")
	_expect(box_update_helper_source.find("StageClearResultImmediateRewardHelper.try_grant_opened_indices") >= 0, "box update handler should delegate immediate opened-index grants")
	_expect(scene_source.find("StageClearResultImmediateRewardHelper.try_grant_opened_indices") < 0, "result scene should not grant immediate opened-index rewards directly")
	_expect(scene_source.find("func _roll_reward") < 0, "result scene should not keep local reward rolling")
	_expect(scene_source.find("reward_copy[\"box_kind\"]") < 0, "result scene should not keep resolved reward copy assembly")
	_expect(scene_source.find("reward[\"pickup_position\"]") < 0, "result scene should not keep immediate reward payload position assembly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
