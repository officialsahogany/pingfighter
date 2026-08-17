extends SceneTree

const RuntimePerkUnlockChoiceApply := preload("res://scripts/characters/runtime_perk_unlock_choice_apply.gd")

var _failures: Array[String] = []
var _pending_swap_apply_calls := 0
var _owner_effect_sync_calls := 0
var _feedback_calls := 0
var _last_pending_swap: Dictionary = {}


func _init() -> void:
	_verify_direct_unlock_apply()
	_verify_slot_full_swap_start()
	_verify_runtime_state_facade_owns_deps_and_callbacks()
	_verify_failure_paths()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_unlock_choice_apply_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_unlock_apply() -> void:
	_reset_calls()
	var helper := RuntimePerkUnlockChoiceApply.new()
	var skill_config := FakeSkillConfig.new(false)
	var weapon_controller := FakeWeaponController.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"commando_skill_config": skill_config,
		"commando_weapon_controller": weapon_controller,
		"game_audio": audio,
	})
	var levels: Dictionary = {}
	var result: Dictionary = helper.apply_choice(
		_choice("soldier"),
		FakeOwner.new("soldier"),
		registry,
		levels,
		FakeCharacterContext.new(),
		FakeUnlockSwapFlow.new(),
		FakeLevelSideEffects.new(),
		_callbacks(),
		null
	)
	_expect(bool(result.get("accepted", false)), "direct unlock apply should accept a valid unlock choice")
	_expect(skill_config.unlocked == ["bowling_trap"], "direct unlock apply should call skill config unlock/equip")
	_expect(int(levels.get("soldier_unlock_bowling_trap", 0)) == 1, "direct unlock apply should commit runtime unlock level")
	_expect(_owner_effect_sync_calls == 1, "direct unlock apply should sync owner effects once")
	_expect(_feedback_calls == 1, "direct unlock apply should apply unlock feedback once")
	_expect(weapon_controller.sync_count == 1, "direct Commando unlock should sync weapon controller")
	_expect(audio.play_count == 1, "direct Commando unlock should play weapon-change audio")


func _verify_slot_full_swap_start() -> void:
	_reset_calls()
	var helper := RuntimePerkUnlockChoiceApply.new()
	var skill_config := FakeSkillConfig.new(true)
	var registry := FakeRegistry.new({"commando_skill_config": skill_config})
	var levels: Dictionary = {}
	var result: Dictionary = helper.apply_choice(
		_choice("soldier"),
		FakeOwner.new("soldier"),
		registry,
		levels,
		FakeCharacterContext.new(),
		FakeUnlockSwapFlow.new(),
		FakeLevelSideEffects.new(),
		_callbacks(),
		null
	)
	_expect(not bool(result.get("accepted", true)), "slot-full unlock should not complete until swap confirm")
	_expect(bool(result.get("pending_swap_started", false)), "slot-full unlock should start the pending swap")
	_expect(_pending_swap_apply_calls == 1, "slot-full unlock should apply pending swap state once")
	_expect(str(_last_pending_swap.get("choice_id", "")) == "soldier_unlock_bowling_trap", "slot-full unlock should preserve pending choice id")
	_expect(skill_config.unlocked.is_empty(), "slot-full unlock should not mutate skill config before swap confirm")
	_expect(levels.is_empty(), "slot-full unlock should not commit runtime level before swap confirm")


func _verify_runtime_state_facade_owns_deps_and_callbacks() -> void:
	var helper := RuntimePerkUnlockChoiceApply.new()
	var state := FakeRuntimeState.new()
	var skill_config := FakeSkillConfig.new(false)
	var registry := FakeRegistry.new({"commando_skill_config": skill_config})
	var result: Dictionary = helper.apply_choice_from_runtime_state(
		state,
		_choice("soldier"),
		FakeOwner.new("soldier"),
		registry
	)
	_expect(bool(result.get("accepted", false)), "unlock facade should accept valid direct unlock choices")
	_expect(skill_config.unlocked == ["bowling_trap"], "unlock facade should route skill config unlock/equip")
	_expect(
		int(state.runtime_skill_levels.get("soldier_unlock_bowling_trap", 0)) == 1,
		"unlock facade should pass live runtime_skill_levels into unlock level commit"
	)
	_expect(state.owner_effect_sync_calls == 1, "unlock facade should build owner sync callback internally")
	_expect(state.feedback_calls == 1, "unlock facade should build feedback callback internally")

	state = FakeRuntimeState.new()
	skill_config = FakeSkillConfig.new(true)
	registry = FakeRegistry.new({"commando_skill_config": skill_config})
	var pending_result: Dictionary = helper.apply_choice_from_runtime_state(
		state,
		_choice("soldier"),
		FakeOwner.new("soldier"),
		registry
	)
	_expect(not bool(pending_result.get("accepted", true)), "unlock facade slot-full path should wait for swap confirm")
	_expect(bool(pending_result.get("pending_swap_started", false)), "unlock facade should start pending swap via state callback")
	_expect(state.pending_swap_apply_calls == 1, "unlock facade should build pending-swap callback internally")
	_expect(
		str(state.last_pending_swap.get("choice_id", "")) == "soldier_unlock_bowling_trap",
		"unlock facade pending swap should preserve choice id"
	)
	_expect(skill_config.unlocked.is_empty(), "unlock facade slot-full path should not mutate skill config before swap confirm")
	_expect(state.runtime_skill_levels.is_empty(), "unlock facade slot-full path should not commit runtime level before swap confirm")


func _verify_failure_paths() -> void:
	var helper := RuntimePerkUnlockChoiceApply.new()
	_expect(not bool(helper.apply_choice({}, FakeOwner.new("smasher"), FakeRegistry.new({}), {}, FakeCharacterContext.new(), FakeUnlockSwapFlow.new(), FakeLevelSideEffects.new(), _callbacks()).get("accepted", true)), "unlock apply should reject missing choice data")
	_expect(not bool(helper.apply_choice(_choice("smasher"), FakeOwner.new("smasher"), FakeRegistry.new({}), {}, FakeCharacterContext.new(), FakeUnlockSwapFlow.new(), FakeLevelSideEffects.new(), _callbacks()).get("accepted", true)), "unlock apply should reject missing skill config")
	_expect(not bool(helper.apply_choice(_choice("smasher"), FakeOwner.new("smasher"), FakeRegistry.new({"smasher_skill_config": FakeFailingSkillConfig.new()}), {}, FakeCharacterContext.new(), FakeUnlockSwapFlow.new(), FakeLevelSideEffects.new(), _callbacks()).get("accepted", true)), "unlock apply should reject failed skill config unlock")


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_choice_apply.gd")
	var unlock_body: String = _function_body(state_source, "func _apply_unlock_choice(")
	var facade_body: String = _function_body(helper_source, "func apply_choice_from_runtime_state(")
	_expect(state_source.find("RuntimePerkUnlockChoiceApply") >= 0, "state should preload unlock-choice apply helper")
	_expect(unlock_body.find("_unlock_choice_apply.apply_choice_from_runtime_state") >= 0, "state unlock apply should delegate to helper facade")
	_expect(unlock_body.find("unlock_and_equip_skill") < 0, "state unlock apply should not call skill config unlock/equip directly")
	_expect(unlock_body.find("commit_unlock_choice_level") < 0, "state unlock apply should not commit unlock levels directly")
	_expect(unlock_body.find("sync_commando_weapon_controller") < 0, "state unlock apply should not sync Commando weapons directly")
	_expect(unlock_body.find("_sync_runtime_perk_owner_effects(owner, registry") < 0, "state unlock apply should not sync owner effects inline")
	_expect(unlock_body.find("_apply_choice_feedback_result") < 0, "state unlock apply should not apply feedback inline")
	_expect(unlock_body.find("runtime_skill_levels") < 0, "state unlock apply should not pass runtime levels inline")
	_expect(unlock_body.find("_character_context") < 0, "state unlock apply should not pass character-context helper inline")
	_expect(unlock_body.find("_unlock_swap_flow") < 0, "state unlock apply should not pass unlock-swap helper inline")
	_expect(unlock_body.find("_level_side_effects") < 0, "state unlock apply should not pass level-side-effect helper inline")
	_expect(unlock_body.find("build_state_callbacks(self)") < 0, "state unlock apply should not build callback map inline")
	_expect(state_source.find("func _should_start_unlock_swap(") < 0, "state should not keep an unlock-swap start gate wrapper")
	_expect(state_source.find("func _start_pending_unlock_swap(") < 0, "state should not keep a pending unlock-swap start wrapper")
	_expect(helper_source.find("func apply_choice_from_runtime_state(") >= 0, "unlock helper should expose a runtime-state facade")
	_expect(facade_body.find("RuntimePerkRuntimeStateAccess.get_dict(runtime_state, \"runtime_skill_levels\")") >= 0, "unlock facade should own runtime-level lookup")
	_expect(facade_body.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_character_context\")") >= 0, "unlock facade should own character-context lookup")
	_expect(facade_body.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_unlock_swap_flow\")") >= 0, "unlock facade should own unlock-swap lookup")
	_expect(facade_body.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_level_side_effects\")") >= 0, "unlock facade should own level-side-effect lookup")
	_expect(facade_body.find("build_state_callbacks(runtime_state)") >= 0, "unlock facade should build callback map internally")
	_expect(helper_source.find("unlock_and_equip_skill") >= 0, "unlock helper should own skill config unlock/equip")
	_expect(helper_source.find("commit_unlock_choice_level") >= 0, "unlock helper should own unlock level commit sequencing")
	_expect(helper_source.find("sync_commando_weapon_controller") >= 0, "unlock helper should own Commando sync sequencing")


func _callbacks() -> Dictionary:
	return {
		RuntimePerkUnlockChoiceApply.CALLBACK_GET_INSTANCE: Callable(self, "_get_instance"),
		RuntimePerkUnlockChoiceApply.CALLBACK_APPLY_UNLOCK_SWAP_STATE_UPDATE: Callable(self, "_apply_unlock_swap_state_update"),
		RuntimePerkUnlockChoiceApply.CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS: Callable(self, "_sync_runtime_perk_owner_effects"),
		RuntimePerkUnlockChoiceApply.CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT: Callable(self, "_apply_choice_feedback_result"),
	}


func _choice(character_type: String) -> Dictionary:
	return {
		"id": "%s_unlock_bowling_trap" % character_type,
		"name": "Bowling Trap",
		"unlocks_skill": "bowling_trap",
		"character_restriction": character_type,
	}


func _reset_calls() -> void:
	_pending_swap_apply_calls = 0
	_owner_effect_sync_calls = 0
	_feedback_calls = 0
	_last_pending_swap.clear()


func _get_instance(registry: Object, key: String) -> Object:
	return registry.get_instance(key)


func _apply_unlock_swap_state_update(update: Dictionary, _owner: Object = null) -> bool:
	_pending_swap_apply_calls += 1
	_last_pending_swap = _get_dict(update.get("pending_unlock_swap", {})).duplicate(true)
	return bool(update.get("accepted", false))


func _sync_runtime_perk_owner_effects(_owner: Object, _registry: Object, _perf_logger: Object = null) -> void:
	_owner_effect_sync_calls += 1


func _apply_choice_feedback_result(_result: Dictionary, _choice: Dictionary, _fallback_timer: float) -> bool:
	_feedback_calls += 1
	return true


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRuntimeState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var _character_context: Object = FakeCharacterContext.new()
	var _unlock_swap_flow: Object = FakeUnlockSwapFlow.new()
	var _level_side_effects: Object = FakeLevelSideEffects.new()
	var pending_swap_apply_calls := 0
	var owner_effect_sync_calls := 0
	var feedback_calls := 0
	var last_pending_swap: Dictionary = {}

	func _get_instance(registry: Object, key: String) -> Object:
		return registry.get_instance(key)

	func _apply_unlock_swap_state_update(update: Dictionary, _owner: Object = null) -> bool:
		pending_swap_apply_calls += 1
		var pending_value: Variant = update.get("pending_unlock_swap", {})
		last_pending_swap = pending_value.duplicate(true) if pending_value is Dictionary else {}
		return bool(update.get("accepted", false))

	func _sync_runtime_perk_owner_effects(_owner: Object, _registry: Object, _perf_logger: Object = null) -> void:
		owner_effect_sync_calls += 1

	func _apply_choice_feedback_result(_result: Dictionary, _choice: Dictionary, _fallback_timer: float) -> bool:
		feedback_calls += 1
		return true


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"

	func _init(character_type: String) -> void:
		selected_character_type = character_type


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(initial_instances: Dictionary) -> void:
		instances = initial_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeCharacterContext:
	extends RefCounted

	func get_owner_character_type(owner: Object) -> String:
		return str(owner.selected_character_type)

	func get_skill_config_key(character_type: String) -> String:
		if character_type == "soldier":
			return "commando_skill_config"
		return "smasher_skill_config"


class FakeUnlockSwapFlow:
	extends RefCounted

	func should_start_swap(skill_config: Object, unlocked_skill: String, character_type: String) -> bool:
		return character_type == "soldier" and skill_config.is_shared_slot_full() and not skill_config.is_skill_equipped(unlocked_skill)

	func build_pending_swap(choice: Dictionary, skill_config: Object) -> Dictionary:
		var candidates: Array = []
		for skill_id in skill_config.get_shared_slot_swap_candidates(str(choice.get("unlocks_skill", ""))):
			candidates.append({"skill_id": str(skill_id), "name": str(skill_id)})
		return {
			"choice": choice.duplicate(true),
			"choice_id": str(choice.get("id", "")),
			"unlocks_skill": str(choice.get("unlocks_skill", "")),
			"candidates": candidates,
		}

	func build_start_state_update(swap: Dictionary) -> Dictionary:
		return {
			"accepted": not swap.is_empty(),
			"pending_unlock_swap": swap.duplicate(true),
		}

	func sync_commando_weapon_controller(unlocked_skill: String, skill_config: Object, registry: Object, character_type: String, get_instance: Callable) -> bool:
		if character_type != "soldier":
			return false
		var weapon_controller: Object = get_instance.call(registry, "commando_weapon_controller")
		if weapon_controller != null:
			weapon_controller.sync_equipped_permanent(skill_config, unlocked_skill)
		var game_audio: Object = get_instance.call(registry, "game_audio")
		if game_audio != null:
			game_audio.play_commando_weapon_change()
		return true


class FakeLevelSideEffects:
	extends RefCounted

	const LEVEL_FEEDBACK_TIMER := 1.1

	func commit_unlock_choice_level(choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
		var choice_id := str(choice.get("id", ""))
		runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1
		return {
			"accepted": true,
			"choice_id": choice_id,
			"next_level": int(runtime_skill_levels.get(choice_id, 0)),
		}


class FakeSkillConfig:
	extends RefCounted

	var shared_slot_full := false
	var equipped: Array = ["net_gun", "bazooka", "ak47"]
	var unlocked: Array = []

	func _init(is_full: bool) -> void:
		shared_slot_full = is_full

	func unlock_and_equip_skill(skill_id: String) -> bool:
		unlocked.append(skill_id)
		if not equipped.has(skill_id):
			equipped.append(skill_id)
		return true

	func is_shared_slot_full() -> bool:
		return shared_slot_full

	func is_skill_equipped(skill_id: String) -> bool:
		return equipped.has(skill_id)

	func get_shared_slot_swap_candidates(_skill_id: String) -> Array:
		return equipped.duplicate()


class FakeFailingSkillConfig:
	extends RefCounted

	func unlock_and_equip_skill(_skill_id: String) -> bool:
		return false


class FakeWeaponController:
	extends RefCounted

	var sync_count := 0

	func sync_equipped_permanent(_skill_config: Object, _highlight: String) -> void:
		sync_count += 1


class FakeAudio:
	extends RefCounted

	var play_count := 0

	func play_commando_weapon_change() -> void:
		play_count += 1
