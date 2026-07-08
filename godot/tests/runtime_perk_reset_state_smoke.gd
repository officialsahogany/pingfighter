extends SceneTree

const RuntimePerkResetState := preload("res://scripts/characters/runtime_perk_reset_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_payload_application()
	_verify_runtime_state_facade_lifecycle_reset()
	_verify_runtime_state_reset_consumes_helper()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_reset_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_payload_application() -> void:
	var helper := RuntimePerkResetState.new()
	var state := FakeRuntimeState.new()
	var result: Dictionary = helper.apply_state_update(state, helper.build_reset_state_update())
	_expect(bool(result.get("accepted", false)), "reset helper should apply a valid reset payload")
	_assert_reset_fields(state, "helper")
	_expect(not bool(helper.apply_state_update(null, helper.build_reset_state_update()).get("accepted", true)), "reset helper should reject missing state")
	_expect(not bool(helper.apply_state_update(state, {"accepted": false}).get("accepted", true)), "reset helper should reject rejected updates")


func _verify_runtime_state_facade_lifecycle_reset() -> void:
	var helper := RuntimePerkResetState.new()
	var state := FakeRuntimeState.new()
	state._skill_cooldown_pause = FakeNoArgResetHelper.new(state.reset_log, "cooldown_resume", "resume")
	state._starpoint_absorption = FakeNoArgResetHelper.new(state.reset_log, "starpoint_absorption")
	state._active_unlock_flight = FakePayloadResetHelper.new(state.reset_log, "active_unlock_flight")
	state._unlock_showcase_controller = FakePayloadResetHelper.new(state.reset_log, "unlock_showcase")
	state._deferred_instants = FakeNoArgResetHelper.new(state.reset_log, "deferred_instants")
	state._resume_safety = FakeNoArgResetHelper.new(state.reset_log, "resume_safety")
	state.choice_flight_effect = {"active": true}
	state.unlock_showcase = {"active": true}

	var result: Dictionary = helper.reset_from_runtime_state(state)
	_expect(bool(result.get("accepted", false)), "runtime-state reset facade should apply reset payload")
	_assert_reset_fields(state, "runtime-state reset facade")
	_expect(
		state.reset_log == [
			"cooldown_resume",
			"starpoint_absorption",
			"active_unlock_flight",
			"unlock_showcase",
			"deferred_instants",
			"resume_safety",
		],
		"runtime-state reset facade should preserve lifecycle reset order"
	)
	_expect(state.choice_flight_effect.is_empty(), "runtime-state reset facade should reset active unlock flight payload")
	_expect(state.unlock_showcase.is_empty(), "runtime-state reset facade should reset unlock showcase payload")


func _verify_runtime_state_reset_consumes_helper() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {"bulk": 3}
	state.starpoint_for_skills = 4
	state.pending_skill_choices = 2
	state.choice_active = true
	state.current_choices = [{"id": "bulk"}]
	state.selected_index = 5
	state.animation_time = 2.0
	state.particles = [{"life": 1.0}]
	state.gold_from_perks = 90
	state.feedback_text = "old"
	state.feedback_timer = 2.0
	state.last_selected_id = "bulk"
	state.last_selected_choice = {"id": "bulk"}
	state.selected_choice_sequence = 8
	state.item_gold_gain_multiplier = 2.0
	state.item_perk_level_bonus = 3
	state.viper_ignition_aura_active = true
	state.viper_ignition_aura_owner_sync_dirty = true
	state.pending_unlock_swap = {"choice_id": "soldier_unlock_bowling_trap"}
	state.unlock_swap_selected_index = 2
	state.gamepad_choice_horizontal_latch = -1
	state.gamepad_unlock_swap_horizontal_latch = 1
	state.current_choice_context = {"source": "smoke"}
	state.current_perk_slot_status = {"count": 4}

	state.reset()
	_assert_reset_fields(state, "runtime state reset")


func _assert_reset_fields(state: Object, prefix: String) -> void:
	_expect((state.get("runtime_skill_levels") as Dictionary).is_empty(), "%s should clear runtime skill levels" % prefix)
	_expect(int(state.get("starpoint_for_skills")) == 0, "%s should reset starpoints" % prefix)
	_expect(int(state.get("pending_skill_choices")) == 0, "%s should reset pending choices" % prefix)
	_expect(not bool(state.get("choice_active")), "%s should close choice state" % prefix)
	_expect((state.get("current_choices") as Array).is_empty(), "%s should clear current choices" % prefix)
	_expect(int(state.get("selected_index")) == 0, "%s should reset selected index" % prefix)
	_expect(is_equal_approx(float(state.get("animation_time")), 0.0), "%s should reset animation time" % prefix)
	_expect((state.get("particles") as Array).is_empty(), "%s should clear particles" % prefix)
	_expect(int(state.get("gold_from_perks")) == 0, "%s should reset perk gold" % prefix)
	_expect(str(state.get("feedback_text")) == "", "%s should clear feedback text" % prefix)
	_expect(is_equal_approx(float(state.get("feedback_timer")), 0.0), "%s should reset feedback timer" % prefix)
	_expect(str(state.get("last_selected_id")) == "", "%s should clear last selected id" % prefix)
	_expect((state.get("last_selected_choice") as Dictionary).is_empty(), "%s should clear last selected choice" % prefix)
	_expect(int(state.get("selected_choice_sequence")) == 0, "%s should reset selected sequence" % prefix)
	_expect(is_equal_approx(float(state.get("item_gold_gain_multiplier")), 1.0), "%s should reset gold multiplier" % prefix)
	_expect(int(state.get("item_perk_level_bonus")) == 0, "%s should reset item perk bonus" % prefix)
	_expect(not bool(state.get("viper_ignition_aura_active")), "%s should reset Viper aura active flag" % prefix)
	_expect(not bool(state.get("viper_ignition_aura_owner_sync_dirty")), "%s should reset Viper aura dirty flag" % prefix)
	_expect((state.get("pending_unlock_swap") as Dictionary).is_empty(), "%s should clear pending unlock swap" % prefix)
	_expect(int(state.get("unlock_swap_selected_index")) == 0, "%s should reset unlock-swap selection" % prefix)
	_expect(int(state.get("gamepad_choice_horizontal_latch")) == 0, "%s should reset choice gamepad latch" % prefix)
	_expect(int(state.get("gamepad_unlock_swap_horizontal_latch")) == 0, "%s should reset unlock-swap gamepad latch" % prefix)
	_expect((state.get("current_choice_context") as Dictionary).is_empty(), "%s should clear choice context" % prefix)
	_expect((state.get("current_perk_slot_status") as Dictionary).is_empty(), "%s should clear slot status" % prefix)


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_reset_state.gd")
	var reset_body: String = _function_body(state_source, "func reset() -> void:")
	_expect(state_source.find("RuntimePerkResetState") >= 0, "state should preload the reset-state helper")
	_expect(reset_body.find("reset_from_runtime_state") >= 0, "reset should delegate to reset-state runtime facade")
	_expect(reset_body.find("build_reset_state_update") < 0, "reset should not build reset payload inline")
	_expect(reset_body.find("apply_state_update") < 0, "reset should not apply reset fields inline")
	_expect(reset_body.find("runtime_skill_levels.clear()") < 0, "reset should not inline runtime-level clearing")
	_expect(reset_body.find("pending_skill_choices = 0") < 0, "reset should not inline pending-choice reset")
	_expect(reset_body.find("current_choices.clear()") < 0, "reset should not inline current-choice clearing")
	_expect(reset_body.find("feedback_text = \"\"") < 0, "reset should not inline feedback reset")
	_expect(reset_body.find("pending_unlock_swap.clear()") < 0, "reset should not inline pending-swap clearing")
	_expect(reset_body.find("current_choice_context.clear()") < 0, "reset should not inline choice-context clearing")
	_expect(reset_body.find("_starpoint_absorption.reset()") < 0, "reset should not inline starpoint absorption lifecycle reset")
	_expect(reset_body.find("_active_unlock_flight.reset(choice_flight_effect)") < 0, "reset should not inline flight lifecycle reset")
	_expect(reset_body.find("_deferred_instants.reset()") < 0, "reset should not inline deferred instant lifecycle reset")
	_expect(helper_source.find("func reset_from_runtime_state") >= 0, "reset helper should expose runtime-state reset facade")
	_expect(helper_source.find("_resume_skill_cooldowns_for_choice") >= 0, "reset helper should own skill-cooldown resume reset step")
	_expect(helper_source.find("_reset_starpoint_absorption") >= 0, "reset helper should own starpoint absorption reset step")
	_expect(helper_source.find("_reset_active_unlock_flight") >= 0, "reset helper should own active unlock flight reset step")
	_expect(helper_source.find("_reset_unlock_showcase") >= 0, "reset helper should own unlock showcase reset step")
	_expect(helper_source.find("_reset_deferred_instants") >= 0, "reset helper should own deferred instant reset step")
	_expect(helper_source.find("_reset_resume_safety") >= 0, "reset helper should own resume-safety reset step")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRuntimeState:
	var runtime_skill_levels: Dictionary = {"bulk": 2}
	var starpoint_for_skills := 3
	var pending_skill_choices := 2
	var choice_active := true
	var current_choices: Array = [{"id": "bulk"}]
	var selected_index := 4
	var animation_time := 1.5
	var particles: Array = [{"life": 1.0}]
	var gold_from_perks := 20
	var feedback_text := "old"
	var feedback_timer := 1.1
	var last_selected_id := "bulk"
	var last_selected_choice: Dictionary = {"id": "bulk"}
	var selected_choice_sequence := 7
	var item_gold_gain_multiplier := 1.5
	var item_perk_level_bonus := 2
	var viper_ignition_aura_active := true
	var viper_ignition_aura_owner_sync_dirty := true
	var pending_unlock_swap: Dictionary = {"choice_id": "soldier_unlock_bowling_trap"}
	var unlock_swap_selected_index := 1
	var gamepad_choice_horizontal_latch := -1
	var gamepad_unlock_swap_horizontal_latch := 1
	var current_choice_context: Dictionary = {"source": "smoke"}
	var current_perk_slot_status: Dictionary = {"count": 4}
	var choice_flight_effect: Dictionary = {"active": true}
	var unlock_showcase: Dictionary = {"active": true}
	var reset_log: Array = []
	var _skill_cooldown_pause: Object = null
	var _starpoint_absorption: Object = null
	var _active_unlock_flight: Object = null
	var _unlock_showcase_controller: Object = null
	var _deferred_instants: Object = null
	var _resume_safety: Object = null


class FakeNoArgResetHelper:
	var log: Array = []
	var label := ""
	var method_name := "reset"

	func _init(target_log: Array, next_label: String, next_method_name: String = "reset") -> void:
		log = target_log
		label = next_label
		method_name = next_method_name

	func reset() -> void:
		if method_name == "reset":
			log.append(label)

	func resume() -> void:
		if method_name == "resume":
			log.append(label)


class FakePayloadResetHelper:
	var log: Array = []
	var label := ""

	func _init(target_log: Array, next_label: String) -> void:
		log = target_log
		label = next_label

	func reset(payload: Dictionary) -> void:
		log.append(label)
		payload.clear()
