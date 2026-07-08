extends SceneTree

const RuntimePerkOwnerProjection := preload("res://scripts/characters/runtime_perk_owner_projection.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_projection_state_builder()
	_verify_direct_owner_projection()
	_verify_state_owner_sync_wrapper()

	if _failures.is_empty():
		print("runtime_perk_owner_projection_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_projection_state_builder() -> void:
	var helper := RuntimePerkOwnerProjection.new()
	var source_levels := {"dash_lightweight": 2}
	var source_effective := {"dash_lightweight": 4}
	var state: Dictionary = helper.build_state(
		source_levels,
		source_effective,
		-3,
		-1,
		77,
		true,
		2,
		true
	)
	_expect(int(state.get("pending_skill_choices", -1)) == 0, "projection state builder should clamp pending choices")
	_expect(int(state.get("starpoint_for_skills", -1)) == 0, "projection state builder should clamp starpoint remainder")
	_expect(int(state.get("gold_from_perks", 0)) == 77, "projection state builder should preserve perk gold")
	_expect(bool(state.get("choice_active", false)), "projection state builder should preserve choice-active state")
	var built_levels: Dictionary = state.get("runtime_skill_levels", {}) as Dictionary
	var built_effective: Dictionary = state.get("effective_runtime_skill_levels", {}) as Dictionary
	built_levels["dash_lightweight"] = 99
	built_effective["dash_lightweight"] = 99
	_expect(int(source_levels.get("dash_lightweight", 0)) == 2, "projection state builder should deep-copy runtime levels")
	_expect(int(source_effective.get("dash_lightweight", 0)) == 4, "projection state builder should deep-copy effective levels")


func _verify_direct_owner_projection() -> void:
	var helper := RuntimePerkOwnerProjection.new()
	var owner := FakeOwner.new()
	var source_levels := {"dash_lightweight": 2}
	var source_effective := {"dash_lightweight": 4}
	helper.sync_owner(owner, {
		"runtime_skill_levels": source_levels,
		"effective_runtime_skill_levels": source_effective,
		"pending_skill_choices": 3,
		"starpoint_for_skills": 1,
		"gold_from_perks": 77,
		"choice_active": true,
		"item_perk_level_bonus": 2,
		"viper_ignition_aura_active": true,
	})
	_expect(int(owner.runtime_perk_levels.get("dash_lightweight", 0)) == 2, "owner should receive runtime perk levels")
	_expect(int(owner.runtime_perk_effective_levels.get("dash_lightweight", 0)) == 4, "owner should receive effective runtime perk levels")
	_expect(owner.runtime_perk_pending_choices == 3, "owner should receive pending choice count")
	_expect(owner.runtime_perk_starpoints == 1, "owner should receive starpoint remainder")
	_expect(owner.runtime_perk_gold == 77, "owner should receive perk gold total")
	_expect(owner.runtime_perk_choice_active, "owner should receive choice-active state")
	_expect(owner.item_perk_level_bonus == 2, "owner should receive item perk level bonus")
	_expect(owner.viper_ignition_aura_active, "owner should receive Viper Ignition Aura state")

	owner.runtime_perk_levels["dash_lightweight"] = 99
	owner.runtime_perk_effective_levels["dash_lightweight"] = 99
	_expect(int(source_levels.get("dash_lightweight", 0)) == 2, "runtime level projection should be deep-copied")
	_expect(int(source_effective.get("dash_lightweight", 0)) == 4, "effective level projection should be deep-copied")


func _verify_state_owner_sync_wrapper() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	state.runtime_skill_levels = {"dash_lightweight": 1}
	state.pending_skill_choices = 2
	state.starpoint_for_skills = 1
	state.gold_from_perks = 5
	state.item_perk_level_bonus = 1
	state.viper_ignition_aura_active = true
	state._sync_owner(owner)
	_expect(int(owner.runtime_perk_levels.get("dash_lightweight", 0)) == 1, "state wrapper should project runtime levels")
	_expect(owner.runtime_perk_pending_choices == 2, "state wrapper should project pending choices")
	_expect(owner.runtime_perk_starpoints == 1, "state wrapper should project starpoints")
	_expect(owner.runtime_perk_gold == 5, "state wrapper should project perk gold")
	_expect(owner.item_perk_level_bonus == 1, "state wrapper should project item perk level bonus")
	_expect(owner.viper_ignition_aura_active, "state wrapper should project Viper Ignition Aura state")
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_owner_sync_flow.gd")
	_expect(state_source.find("_owner_sync_flow.sync_owner") >= 0, "state wrapper should delegate owner projection through owner-sync flow")
	_expect(flow_source.find("owner_projection.build_state") >= 0, "owner-sync flow should use helper-owned projection state assembly")
	_expect(state_source.find("\"runtime_skill_levels\": runtime_skill_levels") < 0, "state wrapper should not inline owner projection runtime-level keys")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeOwner:
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
