extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
	}
	state.choice_active = true
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [
		{"id": "ordinary", "offer_lane": "replaceable", "offer_protected": false},
		{"id": "reserved", "offer_lane": "owned_upgrade_reserved", "offer_protected": true},
		{"id": "convert_to_gold", "offer_lane": "gold", "offer_protected": true},
	]

	var plan: Dictionary = state._try_inject_perk_fusion_offer(catalog, 0.0, 0.0)
	_expect(bool(plan.get("rolled", false)), "eligible battle offer should perform one appearance roll")
	_expect(bool(plan.get("appeared", false)), "forced zero roll should inject the fusion card")
	_expect(str((state.current_choices[0] as Dictionary).get("id", "")) == "perk_fusion", "only replaceable lane should become fusion")
	_expect(str((state.current_choices[1] as Dictionary).get("id", "")) == "reserved", "reserved lane should remain unchanged")
	_expect(str((state.current_choices[2] as Dictionary).get("id", "")) == "convert_to_gold", "gold lane should remain unchanged")

	var denied_state := RuntimePerkState.new()
	denied_state.runtime_skill_levels = state.runtime_skill_levels.duplicate(true)
	denied_state.choice_active = true
	denied_state.current_choice_context = {"source": "plaza_academy"}
	denied_state.current_choices = [
		{"id": "ordinary", "offer_lane": "replaceable", "offer_protected": false},
	]
	var denied: Dictionary = denied_state._try_inject_perk_fusion_offer(catalog, 0.0, 0.0)
	_expect(not bool(denied.get("rolled", true)), "plaza source should fail closed before appearance roll")
	_expect(str((denied_state.current_choices[0] as Dictionary).get("id", "")) == "ordinary", "denied source should preserve its exact offer")

	# 실 open_next_choice 관통(결정적 seam): 오퍼 주입이 실 open 경로에
	# 배선돼 있음을 fallback 없이 봉인한다. seam은 일회성 소비다.
	var real_state := RuntimePerkState.new()
	real_state.runtime_skill_levels = {"item_luck": 5, "common_bulk_up": 5}
	real_state.pending_skill_choices = 1
	real_state.set_test_perk_fusion_offer_roll_override(0.0, 0.0)
	real_state.open_next_choice("smasher", catalog, true, null, null, null, {"source": "battle_starpoint"})
	var real_fusion_found := false
	for real_choice: Variant in real_state.current_choices:
		if real_choice is Dictionary and str((real_choice as Dictionary).get("id", "")) == "perk_fusion":
			real_fusion_found = true
	_expect(real_fusion_found, "the real open_next_choice path should expose the fusion card deterministically through the seam")
	_expect(real_state._test_perk_fusion_offer_roll_override.is_empty(), "the deterministic offer seam must be one-shot")

	var collection_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
	_expect(collection_source.contains("{\"source\": \"battle_starpoint\"}"), "battle starpoint opener should stamp the allowlisted source explicitly")

	if _failures.is_empty():
		print("runtime_perk_fusion_offer_integration_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
