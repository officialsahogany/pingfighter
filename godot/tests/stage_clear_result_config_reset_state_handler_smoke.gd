extends SceneTree

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultConfigResetStateHandler := preload("res://scripts/ui/stage_clear_result_config_reset_state_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultSceneFieldApplier := preload("res://scripts/ui/stage_clear_result_scene_field_applier.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_reset_state_payload()
	_verify_reset_apply_payload()
	_verify_reset_scene_apply_payload()
	_verify_scene_applies_reset_state()
	_verify_scene_field_guard()
	_verify_scene_delegates_config_reset_state()

	if _failures.is_empty():
		print("stage_clear_result_config_reset_state_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_reset_state_payload() -> void:
	var result: Dictionary = StageClearResultConfigResetStateHandler.get_config_reset_state()
	_expect(int(result.get("lid_open_counter", -1)) == 0, "reset state should reset lid counter")
	_expect(not bool(result.get("starpoint_choice_gate_active", true)), "reset state should clear starpoint gate")
	_expect(int(result.get("starpoint_choice_gate_box_index", 99)) == -1, "reset state should clear starpoint gate box index")
	_expect(int(result.get("hovered_box_index", 99)) == -1, "reset state should clear hovered box")
	_expect(str(result.get("hovered_button", "")) == "none", "reset state should clear hovered button")
	_expect(result.get("next_stage_button_rect", null) is Rect2, "reset state should include next button rect")
	_expect(result.get("plaza_button_rect", null) is Rect2, "reset state should include plaza button rect")
	_expect(result.get("exit_button_rect", null) is Rect2, "reset state should include exit button rect")
	_expect(str(result.get("scroll_phase", "")) == "hidden", "reset state should hide scroll")
	_expect(float(result.get("scroll_timer", -1.0)) == 0.0, "reset state should clear scroll timer")
	_expect(result.get("scroll_position_offset", null) == Vector2.ZERO, "reset state should clear scroll offset")
	_expect(not bool(result.get("scroll_dragging", true)), "reset state should clear scroll dragging")
	_expect(result.get("scroll_drag_grab_offset", null) == Vector2.ZERO, "reset state should clear scroll grab offset")
	_expect(float(result.get("timer", -1.0)) == 0.0, "reset state should clear scene timer")
	_expect(float(result.get("dalji_base_timer", -1.0)) == 0.0, "reset state should clear Dalji base timer")
	_expect(
		float(result.get("dalji_click_reaction_timer", -1.0)) == StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION,
		"reset state should park Dalji click reaction at inactive duration"
	)
	_expect(
		float(result.get("player_victory_click_reaction_timer", -1.0)) == StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION,
		"reset state should park player victory reaction at inactive duration"
	)
	_expect(
		float(result.get("stage2_boss_defeat_click_reaction_timer", -1.0)) == StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"reset state should park Stage 2 boss reaction at inactive duration"
	)
	_expect(
		float(result.get("stage3_boss_defeat_click_reaction_timer", -1.0)) == StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"reset state should park Stage 3 boss reaction at inactive duration"
	)
	_expect(float(result.get("dalji_dialogue_timer", -1.0)) == 0.0, "reset state should clear Dalji dialogue timer")


func _verify_reset_apply_payload() -> void:
	var full_payload: Dictionary = StageClearResultConfigResetStateHandler.get_config_reset_scene_apply_result(
		StageClearResultConfigResetStateHandler.get_config_reset_state(),
		_get_non_reset_current_state()
	).get("field_payload", {}) as Dictionary
	_expect(int(full_payload.get("_lid_open_counter", -1)) == 0, "reset apply should reset lid counter")
	_expect(not bool(full_payload.get("_starpoint_choice_gate_active", true)), "reset apply should clear starpoint gate")
	_expect(int(full_payload.get("_hovered_box_index", 99)) == -1, "reset apply should clear hovered box")
	_expect(str(full_payload.get("_hovered_button", "")) == "none", "reset apply should clear hovered button")
	_expect(str(full_payload.get("_scroll_phase", "")) == "hidden", "reset apply should hide scroll")
	_expect(full_payload.get("_scroll_position_offset", null) == Vector2.ZERO, "reset apply should clear scroll offset")
	_expect(float(full_payload.get("_dalji_dialogue_timer", -1.0)) == 0.0, "reset apply should clear dialogue timer")

	var current_state: Dictionary = _get_non_reset_current_state()
	var partial_payload: Dictionary = StageClearResultConfigResetStateHandler.get_config_reset_scene_apply_result(
		{
			"hovered_button": "exit",
			"next_stage_button_rect": "invalid",
			"plaza_button_rect": "invalid",
			"scroll_position_offset": "invalid",
		},
		current_state
	).get("field_payload", {}) as Dictionary
	_expect(int(partial_payload.get("_lid_open_counter", -1)) == 5, "partial reset apply should keep current lid counter")
	_expect(str(partial_payload.get("_hovered_button", "")) == "exit", "partial reset apply should apply provided hovered button")
	_expect(partial_payload.get("_next_stage_button_rect", null) == current_state.get("next_stage_button_rect"), "invalid next button rect should keep current rect")
	_expect(partial_payload.get("_plaza_button_rect", null) == current_state.get("plaza_button_rect"), "invalid plaza button rect should keep current rect")
	_expect(partial_payload.get("_scroll_position_offset", null) == current_state.get("scroll_position_offset"), "invalid scroll offset should keep current offset")
	_expect(float(partial_payload.get("timer", -1.0)) == 12.0, "partial reset apply should keep current scene timer")


func _verify_reset_scene_apply_payload() -> void:
	var scene_apply: Dictionary = StageClearResultConfigResetStateHandler.get_config_reset_scene_apply_result(
		StageClearResultConfigResetStateHandler.get_config_reset_state(),
		_get_non_reset_current_state()
	)
	var field_payload: Dictionary = scene_apply.get("field_payload", {}) as Dictionary
	_expect(int(field_payload.get("_lid_open_counter", -1)) == 0, "reset scene apply should map lid counter")
	_expect(not bool(field_payload.get("_starpoint_choice_gate_active", true)), "reset scene apply should map starpoint gate")
	_expect(int(field_payload.get("_starpoint_choice_gate_box_index", 99)) == -1, "reset scene apply should map gate index")
	_expect(int(field_payload.get("_hovered_box_index", 99)) == -1, "reset scene apply should map hovered box")
	_expect(str(field_payload.get("_hovered_button", "")) == "none", "reset scene apply should map hovered button")
	_expect(field_payload.get("_next_stage_button_rect", null) is Rect2, "reset scene apply should map next button rect")
	_expect(field_payload.get("_plaza_button_rect", null) is Rect2, "reset scene apply should map plaza button rect")
	_expect(field_payload.get("_exit_button_rect", null) is Rect2, "reset scene apply should map exit button rect")
	_expect(str(field_payload.get("_scroll_phase", "")) == "hidden", "reset scene apply should map scroll phase")
	_expect(float(field_payload.get("_scroll_timer", -1.0)) == 0.0, "reset scene apply should map scroll timer")
	_expect(field_payload.get("_scroll_position_offset", null) == Vector2.ZERO, "reset scene apply should map scroll offset")
	_expect(not bool(field_payload.get("_scroll_dragging", true)), "reset scene apply should map scroll dragging")
	_expect(field_payload.get("_scroll_drag_grab_offset", null) == Vector2.ZERO, "reset scene apply should map scroll grab offset")
	_expect(float(field_payload.get("timer", -1.0)) == 0.0, "reset scene apply should map scene timer")
	_expect(float(field_payload.get("_dalji_base_timer", -1.0)) == 0.0, "reset scene apply should map Dalji base timer")
	_expect(float(field_payload.get("_dalji_dialogue_timer", -1.0)) == 0.0, "reset scene apply should map Dalji dialogue timer")

	var scene := StageClearResultScene.new()
	scene._apply_scene_apply_result(scene_apply)
	_expect(int(scene.get("_lid_open_counter")) == 0, "scene field payload helper should apply reset lid counter")
	_expect(not bool(scene.get("_starpoint_choice_gate_active")), "scene field payload helper should apply reset starpoint gate")
	_expect(int(scene.get("_starpoint_choice_gate_box_index")) == -1, "scene field payload helper should apply reset gate index")
	_expect(int(scene.get("_hovered_box_index")) == -1, "scene field payload helper should apply reset hovered box")
	_expect(str(scene.get("_hovered_button")) == "none", "scene field payload helper should apply reset hovered button")
	_expect(str(scene.get("_scroll_phase")) == "hidden", "scene field payload helper should apply reset scroll phase")
	_expect(scene.get("_scroll_position_offset") == Vector2.ZERO, "scene field payload helper should apply reset scroll offset")
	_expect(float(scene.get("timer")) == 0.0, "scene field payload helper should apply reset timer")
	_expect(float(scene.get("_dalji_dialogue_timer")) == 0.0, "scene field payload helper should apply reset dialogue timer")
	scene.free()


func _verify_scene_applies_reset_state() -> void:
	var scene := StageClearResultScene.new()
	scene.set("_lid_open_counter", 5)
	scene.set("_starpoint_choice_gate_active", true)
	scene.set("_starpoint_choice_gate_box_index", 4)
	scene.set("_hovered_box_index", 3)
	scene.set("_hovered_button", "exit")
	scene.set("_next_stage_button_rect", Rect2(Vector2(1.0, 2.0), Vector2(3.0, 4.0)))
	scene.set("_plaza_button_rect", Rect2(Vector2(3.0, 4.0), Vector2(5.0, 6.0)))
	scene.set("_exit_button_rect", Rect2(Vector2(5.0, 6.0), Vector2(7.0, 8.0)))
	scene.set("_scroll_phase", "visible")
	scene.set("_scroll_timer", 2.5)
	scene.set("_scroll_position_offset", Vector2(25.0, 35.0))
	scene.set("_scroll_dragging", true)
	scene.set("_scroll_drag_grab_offset", Vector2(9.0, 10.0))
	scene.set("timer", 12.0)
	scene.set("_dalji_base_timer", 7.0)
	scene.set("_dalji_dialogue_timer", 1.0)
	scene._apply_config_reset_state(StageClearResultConfigResetStateHandler.get_config_reset_state())
	_expect(int(scene.get("_lid_open_counter")) == 0, "scene reset apply should reset lid counter")
	_expect(not bool(scene.get("_starpoint_choice_gate_active")), "scene reset apply should clear starpoint gate")
	_expect(int(scene.get("_starpoint_choice_gate_box_index")) == -1, "scene reset apply should clear gate index")
	_expect(int(scene.get("_hovered_box_index")) == -1, "scene reset apply should clear hovered box")
	_expect(str(scene.get("_hovered_button")) == "none", "scene reset apply should clear hovered button")
	_expect(str(scene.get("_scroll_phase")) == "hidden", "scene reset apply should hide scroll")
	_expect(float(scene.get("_scroll_timer")) == 0.0, "scene reset apply should clear scroll timer")
	_expect(scene.get("_scroll_position_offset") == Vector2.ZERO, "scene reset apply should clear scroll offset")
	_expect(not bool(scene.get("_scroll_dragging")), "scene reset apply should clear dragging")
	_expect(scene.get("_scroll_drag_grab_offset") == Vector2.ZERO, "scene reset apply should clear drag grab offset")
	_expect(float(scene.get("timer")) == 0.0, "scene reset apply should clear scene timer")
	_expect(float(scene.get("_dalji_base_timer")) == 0.0, "scene reset apply should clear Dalji base timer")
	_expect(float(scene.get("_dalji_dialogue_timer")) == 0.0, "scene reset apply should clear dialogue timer")
	scene.free()


func _verify_scene_field_guard() -> void:
	var scene := StageClearResultScene.new()
	var lookup: Dictionary = {}
	_expect(StageClearResultSceneFieldApplier.is_valid_field(scene, lookup, "_lid_open_counter"), "field guard should accept a real private member name")
	_expect(StageClearResultSceneFieldApplier.is_valid_field(scene, lookup, "timer"), "field guard should accept a public member name")
	_expect(not StageClearResultSceneFieldApplier.is_valid_field(scene, lookup, "_definitely_not_a_real_field"), "field guard should reject an unknown payload key so typos cannot silently no-op")
	scene.set("_lid_open_counter", 7)
	scene._apply_scene_apply_result({"field_payload": {"_lid_open_counter": 3}})
	_expect(int(scene.get("_lid_open_counter")) == 3, "guarded applier should still apply valid payload keys")
	scene.free()


func _verify_scene_delegates_config_reset_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var configure_start: int = source.find("func configure(")
	var configure_end: int = source.find("func _apply_character_asset_state")
	var configure_source: String = source.substr(configure_start, configure_end - configure_start) if configure_start >= 0 and configure_end > configure_start else source
	var apply_source: String = _slice_function(source, "func _apply_config_reset_state", "func _get_config_reset_current_state")
	_expect(source.find("StageClearResultConfigResetStateHandler.get_config_reset_state") >= 0, "result scene should delegate configure reset-state creation")
	_expect(source.find("StageClearResultConfigResetStateHandler.get_config_reset_scene_apply_result") >= 0, "result scene should delegate config reset scene field apply payloads")
	_expect(source.find("func _apply_scene_apply_result") >= 0, "result scene should centralize scene apply-result application")
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep the retired direct field-payload wrapper")
	_expect(source.find("func _is_valid_scene_field") < 0, "result scene should leave field validation ownership in the helper")
	_expect(source.find("apply_result.get(property_name, null) as Object") < 0, "runtime object state should route through the guarded field payload applier, not a bespoke set loop")
	_expect(source.find("func _get_field_payload_from_apply_result") < 0, "result scene should not keep the retired payload-unwrapping wrapper")
	_expect(source.find("func _apply_config_reset_state") >= 0, "result scene should keep a focused reset-state applier")
	_expect(apply_source.find("_lid_open_counter = int(result.get") < 0, "reset-state applier should not inspect lid counter directly")
	_expect(apply_source.find("_starpoint_choice_gate_active = bool(result.get") < 0, "reset-state applier should not inspect starpoint gate directly")
	_expect(apply_source.find("_hovered_box_index = int(result.get") < 0, "reset-state applier should not inspect hovered box directly")
	_expect(apply_source.find("_scroll_phase = str(result.get") < 0, "reset-state applier should not inspect scroll phase directly")
	_expect(apply_source.find("_dalji_dialogue_timer = float(result.get") < 0, "reset-state applier should not inspect dialogue timer directly")
	_expect(apply_source.find("_lid_open_counter = int(apply_result.get") < 0, "reset-state applier should not write lid counter directly")
	_expect(apply_source.find("_starpoint_choice_gate_active = bool(apply_result.get") < 0, "reset-state applier should not write starpoint gate directly")
	_expect(apply_source.find("_hovered_box_index = int(apply_result.get") < 0, "reset-state applier should not write hovered box directly")
	_expect(apply_source.find("_scroll_phase = str(apply_result.get") < 0, "reset-state applier should not write scroll phase directly")
	_expect(apply_source.find("_dalji_dialogue_timer = float(apply_result.get") < 0, "reset-state applier should not write dialogue timer directly")
	_expect(configure_source.find("set_starpoint_choice_gate_active(false, -1)") < 0, "result scene should not clear starpoint gate inline during configure")
	_expect(configure_source.find("_scroll_phase = \"hidden\"") < 0, "result scene should not reset scroll phase inline during configure")
	_expect(configure_source.find("_lid_open_counter = 0") < 0, "result scene should not reset lid counter inline during configure")


func _get_non_reset_current_state() -> Dictionary:
	return {
		"lid_open_counter": 5,
		"starpoint_choice_gate_active": true,
		"starpoint_choice_gate_box_index": 4,
		"hovered_box_index": 3,
		"hovered_button": "next",
		"next_stage_button_rect": Rect2(Vector2(1.0, 2.0), Vector2(3.0, 4.0)),
		"plaza_button_rect": Rect2(Vector2(3.0, 4.0), Vector2(5.0, 6.0)),
		"exit_button_rect": Rect2(Vector2(5.0, 6.0), Vector2(7.0, 8.0)),
		"scroll_phase": "visible",
		"scroll_timer": 2.5,
		"scroll_position_offset": Vector2(25.0, 35.0),
		"scroll_dragging": true,
		"scroll_drag_grab_offset": Vector2(9.0, 10.0),
		"timer": 12.0,
		"dalji_base_timer": 7.0,
		"dalji_click_reaction_timer": 0.2,
		"player_victory_click_reaction_timer": 0.3,
		"stage2_boss_defeat_click_reaction_timer": 0.4,
		"stage3_boss_defeat_click_reaction_timer": 0.5,
		"dalji_dialogue_timer": 1.0,
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
