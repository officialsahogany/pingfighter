extends SceneTree

const RuntimePerkGoldAwardFlow := preload("res://scripts/characters/runtime_perk_gold_award_flow.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeRuntimeState:
	extends RefCounted

	var gold_from_perks := 0
	var feedback_text := "old"
	var feedback_timer := 0.25
	var item_gold_gain_multiplier := 1.0
	var viper_ignition_aura_active := false
	var _choice_feedback: Object = null
	var sync_owner_count := 0

	func _get_instance(registry: Object, key: String) -> Object:
		if registry != null and registry.has_method("get_instance"):
			return registry.get_instance(key)
		return null

	func _sync_owner(_owner: Object) -> void:
		sync_owner_count += 1


class FakeChoiceFeedback:
	extends RefCounted

	var apply_count := 0

	func apply_feedback_state_update(runtime_state: Object, update: Dictionary, fallback_timer: float = 0.0) -> Dictionary:
		apply_count += 1
		if runtime_state == null:
			return {"accepted": false}
		runtime_state.set("feedback_text", str(update.get("feedback_text", "")))
		runtime_state.set("feedback_timer", float(update.get("feedback_timer", fallback_timer)))
		return {
			"accepted": true,
			"feedback_text": str(runtime_state.get("feedback_text")),
			"feedback_timer": float(runtime_state.get("feedback_timer")),
		}


class FakeRegistry:
	extends RefCounted

	var instances := {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var enraged_boss_active := true


class FakeSmasherComboState:
	extends RefCounted

	var combo_count := 2

	func get_combo_count() -> int:
		return combo_count


func _init() -> void:
	_verify_flow_applies_awards_with_feedback()
	_verify_flow_runtime_state_wrappers_assemble_dependencies()
	_verify_flow_handles_store_and_rejected_results()
	_verify_state_public_wrappers_delegate_to_flow()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_gold_award_flow_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_flow_applies_awards_with_feedback() -> void:
	var flow: Object = RuntimePerkGoldAwardFlow.new()
	var state := FakeRuntimeState.new()
	var feedback := FakeChoiceFeedback.new()
	state.item_gold_gain_multiplier = 1.5
	state.viper_ignition_aura_active = true

	var total: int = flow.award_gold(
		10,
		{
			"selected_character_type": "smasher",
			"enraged_boss_active": true,
			"smasher_combo_count": 2,
		},
		{},
		state,
		feedback
	)
	_expect(total == 112, "flow should preserve gold modifier order while applying to runtime state")
	_expect(state.gold_from_perks == 112, "flow should write the returned gold total to runtime state")
	_expect(feedback.apply_count == 1, "flow should route gold award feedback through the feedback helper")
	_expect(state.feedback_text.find("+112") >= 0, "flow should keep the helper-built gold feedback text")
	_expect(is_equal_approx(state.feedback_timer, 1.0), "flow should keep the default gold feedback duration")


func _verify_flow_runtime_state_wrappers_assemble_dependencies() -> void:
	var flow: Object = RuntimePerkGoldAwardFlow.new()
	var state := FakeRuntimeState.new()
	var feedback := FakeChoiceFeedback.new()
	var registry := FakeRegistry.new()
	var combo_state := FakeSmasherComboState.new()
	state._choice_feedback = feedback
	state.item_gold_gain_multiplier = 1.5
	state.viper_ignition_aura_active = true
	registry.instances["smasher_combo_state"] = combo_state

	var accepted: bool = flow.apply_convert_to_gold_choice_from_runtime_state(
		state,
		{"id": "convert_to_gold", "gold_amount": 10},
		FakeOwner.new(),
		registry
	)
	_expect(accepted, "runtime-state convert wrapper should keep the state wrapper boolean contract")
	_expect(state.gold_from_perks == 112, "runtime-state convert wrapper should assemble owner/combo/feedback dependencies")
	_expect(state.sync_owner_count == 1, "runtime-state convert wrapper should sync the owner after applying gold")
	_expect(feedback.apply_count == 1, "runtime-state convert wrapper should use the runtime state's feedback helper")
	_expect(state.feedback_text.find("+112") >= 0, "runtime-state convert wrapper should keep conversion feedback text")

	var stored_total: int = flow.store_gold_gain_from_runtime_state(state, 4, 0.2)
	_expect(stored_total == 116, "runtime-state store wrapper should reuse the runtime state's feedback helper")
	_expect(is_equal_approx(state.feedback_timer, 0.2), "runtime-state store wrapper should preserve explicit feedback duration")

	var rejected_total: int = flow.apply_gold_award_result_from_runtime_state(state, {"accepted": false})
	_expect(rejected_total == 116, "runtime-state award-result wrapper should return current gold when rejected")

	var multiplier_update: Dictionary = flow.set_item_gold_gain_multiplier_from_runtime_state(state, -2.0)
	_expect(bool(multiplier_update.get("accepted", false)), "runtime-state multiplier setter should accept valid runtime states")
	_expect(is_equal_approx(state.item_gold_gain_multiplier, 0.0), "runtime-state multiplier setter should clamp negative item gold multipliers")
	_expect(is_equal_approx(flow.get_item_gold_gain_multiplier_from_runtime_state(state), 0.0), "runtime-state multiplier getter should read the live item gold multiplier")
	_expect(is_equal_approx(flow.get_item_gold_gain_multiplier_from_runtime_state(null), 1.0), "runtime-state multiplier getter should use the neutral null fallback")
	state.viper_ignition_aura_active = true
	_expect(flow.get_viper_ignition_aura_gold_bonus_from_runtime_state(state) == 50, "runtime-state gold bonus getter should read active Ignition Aura state")
	state.viper_ignition_aura_active = false
	_expect(flow.get_viper_ignition_aura_gold_bonus_from_runtime_state(state) == 0, "runtime-state gold bonus getter should return zero when Ignition Aura is inactive")
	_expect(flow.calculate_rally_gold_from_runtime_state(state, Vector2(22.0, 0.0)) == 12, "runtime-state rally-gold calculator should preserve speed tiers")
	_expect(flow.calculate_rally_gold_from_runtime_state(null, Vector2(7.0, 0.0)) == 4, "runtime-state rally-gold calculator should keep the pure null-state fallback")


func _verify_flow_handles_store_and_rejected_results() -> void:
	var flow: Object = RuntimePerkGoldAwardFlow.new()
	var state := FakeRuntimeState.new()
	var feedback := FakeChoiceFeedback.new()
	state.gold_from_perks = 5

	var stored_total: int = flow.store_gold_gain(7, 0.4, state, feedback)
	_expect(stored_total == 12, "flow should store already-boosted gold without reapplying modifiers")
	_expect(state.gold_from_perks == 12, "flow should apply stored gold totals to runtime state")
	_expect(is_equal_approx(state.feedback_timer, 0.4), "flow should keep explicit stored-gold feedback duration")

	var fallback_total: int = flow.apply_gold_award_result({"accepted": false}, state, feedback)
	_expect(fallback_total == 12, "flow should return the current total when award-result application is rejected")
	_expect(state.gold_from_perks == 12, "rejected award-result application should not lose current stored gold")


func _verify_state_public_wrappers_delegate_to_flow() -> void:
	var perk_state: Object = RuntimePerkState.new()
	perk_state.set_viper_ignition_aura_active(true)
	perk_state.set_item_gold_gain_multiplier(1.5)
	_expect(is_equal_approx(perk_state.get_item_gold_gain_multiplier(), 1.5), "state item gold multiplier getter should delegate through gold award flow")
	_expect(perk_state.get_viper_ignition_aura_gold_bonus() == 50, "state Ignition Aura gold bonus getter should delegate through gold award flow")

	var awarded: int = perk_state.award_gold(
		10,
		{
			"selected_character_type": "smasher",
			"enraged_boss_active": true,
			"smasher_combo_count": 2,
		},
		{}
	)
	_expect(awarded == 112, "state award_gold wrapper should delegate through gold award flow")
	_expect(perk_state.gold_from_perks == 112, "state wrapper delegation should still update stored gold")
	_expect(perk_state.calculate_rally_gold(Vector2(22.0, 0.0)) == 12, "state rally-gold calculator wrapper should delegate through gold award flow")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_gold_award_flow.gd")
	_expect(state_source.find("RuntimePerkGoldAwardFlow") >= 0, "state should preload the gold award flow helper")
	_expect(flow_source.find("func calculate_rally_gold_from_runtime_state(") >= 0, "gold award flow should expose runtime-state rally-gold calculator facade")
	_expect(flow_source.find("RuntimePerkGoldAwards.apply_award_result_to_runtime_state") >= 0, "gold award flow should own award-result state/feedback application")
	_expect(flow_source.find("Callable(choice_feedback, \"apply_feedback_state_update\")") >= 0, "gold award flow should own feedback callback wiring")

	var convert_body: String = _function_body(state_source, "func _apply_convert_to_gold_choice(")
	_expect(convert_body.find("_gold_award_flow.apply_convert_to_gold_choice_from_runtime_state") >= 0, "convert-to-gold wrapper should delegate runtime-state assembly to gold award flow")
	_expect(convert_body.find("RuntimePerkGoldAwards.award_convert_to_gold_choice") < 0, "state should not build convert-to-gold award payloads inline")
	_expect(convert_body.find("_get_instance(registry, \"smasher_combo_state\")") < 0, "state convert wrapper should not resolve combo-state dependencies inline")
	_expect(convert_body.find("_sync_owner(owner)") < 0, "state convert wrapper should not sync owner inline")
	_expect(convert_body.find("_choice_feedback") < 0, "state convert wrapper should not pass the feedback helper inline")

	var rally_body: String = _function_body(state_source, "func award_rally_gold(")
	_expect(rally_body.find("_gold_award_flow.award_rally_gold_from_runtime_state") >= 0, "rally-gold wrapper should delegate runtime-state assembly to gold award flow")
	_expect(rally_body.find("RuntimePerkGoldAwards.award_rally_gold") < 0, "state should not build rally-gold award payloads inline")
	_expect(rally_body.find("_choice_feedback") < 0, "rally-gold wrapper should not pass the feedback helper inline")

	var calculate_body: String = _function_body(state_source, "func calculate_rally_gold(")
	_expect(calculate_body.find("_gold_award_flow.calculate_rally_gold_from_runtime_state") >= 0, "rally-gold calculator wrapper should delegate through runtime-state facade")
	_expect(calculate_body.find("_gold_award_flow.calculate_rally_gold(ball_vel)") < 0, "state should not call the pure rally-gold calculator directly")

	var award_body: String = _function_body(state_source, "func award_gold(")
	_expect(award_body.find("_gold_award_flow.award_gold_from_runtime_state") >= 0, "skill-gold wrapper should delegate runtime-state assembly to gold award flow")
	_expect(award_body.find("RuntimePerkGoldAwards.award_gold") < 0, "state should not build skill-gold award payloads inline")
	_expect(award_body.find("_choice_feedback") < 0, "skill-gold wrapper should not pass the feedback helper inline")

	var store_body: String = _function_body(state_source, "func _store_gold_gain(")
	_expect(store_body.find("_gold_award_flow.store_gold_gain_from_runtime_state") >= 0, "stored-gold wrapper should delegate runtime-state assembly to gold award flow")
	_expect(store_body.find("RuntimePerkGoldAwards.store_gold_gain") < 0, "state should not build stored-gold payloads inline")
	_expect(store_body.find("_choice_feedback") < 0, "stored-gold wrapper should not pass the feedback helper inline")

	var apply_body: String = _function_body(state_source, "func _apply_gold_award_result(")
	_expect(apply_body.find("_gold_award_flow.apply_gold_award_result_from_runtime_state") >= 0, "award-result wrapper should delegate runtime-state assembly to gold award flow")
	_expect(apply_body.find("RuntimePerkGoldAwards.apply_award_result_to_runtime_state") < 0, "state should not apply gold award results inline")
	_expect(apply_body.find("_choice_feedback") < 0, "award-result wrapper should not pass the feedback helper inline")

	var multiplier_set_body: String = _function_body(state_source, "func set_item_gold_gain_multiplier(")
	_expect(multiplier_set_body.find("_gold_award_flow.set_item_gold_gain_multiplier_from_runtime_state") >= 0, "item gold multiplier setter should delegate runtime-state policy to gold award flow")
	_expect(multiplier_set_body.find("RuntimePerkGoldAwards.build_item_gold_gain_multiplier_update") < 0, "state should not build item gold multiplier updates inline")

	var multiplier_get_body: String = _function_body(state_source, "func get_item_gold_gain_multiplier(")
	_expect(multiplier_get_body.find("_gold_award_flow.get_item_gold_gain_multiplier_from_runtime_state") >= 0, "item gold multiplier getter should delegate runtime-state reads to gold award flow")
	_expect(multiplier_get_body.find("return item_gold_gain_multiplier") < 0, "state should not read item gold multiplier inline")

	var ignition_gold_body: String = _function_body(state_source, "func get_viper_ignition_aura_gold_bonus(")
	_expect(ignition_gold_body.find("_gold_award_flow.get_viper_ignition_aura_gold_bonus_from_runtime_state") >= 0, "Ignition Aura gold bonus getter should delegate runtime-state reads to gold award flow")
	_expect(ignition_gold_body.find("RuntimePerkGoldAwards.get_viper_ignition_aura_gold_bonus") < 0, "state should not read Ignition Aura gold bonus policy inline")
	_expect(state_source.find("const RuntimePerkGoldAwards") < 0, "state should not preload gold award payload helpers directly")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)
