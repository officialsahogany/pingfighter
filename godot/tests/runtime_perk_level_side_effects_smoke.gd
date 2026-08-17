extends SceneTree

const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")
const RuntimePerkLevelSideEffects := preload("res://scripts/characters/runtime_perk_level_side_effects.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkUnlockSwapFlow := preload("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _sync_calls := 0
var _refresh_calls := 0


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_verify_level_choice_update()
	_verify_unlock_choice_update()
	_verify_debug_level_update()
	_verify_debug_unlock_choice_update()
	_verify_dash_amplification_side_effect()
	_verify_unlock_side_effect_and_commando_sync()
	_verify_runtime_state_facade_side_effects()
	_verify_state_source_contract()
	LanguageSettings.set_test_locale_override("")

	if _failures.is_empty():
		print("runtime_perk_level_side_effects_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_level_choice_update() -> void:
	var helper := RuntimePerkLevelSideEffects.new()
	var update: Dictionary = helper.build_level_choice_update(
		{"id": "common_bulk_up", "name": "Bulk", "max_level": 2},
		{"common_bulk_up": 2}
	)
	_expect(bool(update.get("accepted", false)), "level choice update should accept valid choice ids")
	_expect(str(update.get("choice_id", "")) == "common_bulk_up", "level choice update should expose the choice id")
	_expect(int(update.get("old_level", 0)) == 2, "level choice update should expose old level")
	_expect(int(update.get("next_level", 0)) == 2, "level choice update should respect max-level cap")
	_expect(str(update.get("feedback_text", "")) == "Bulk 극성", "level choice update should own martial-rank feedback text")
	_expect(is_equal_approx(float(update.get("feedback_timer", 0.0)), RuntimePerkLevelSideEffects.LEVEL_FEEDBACK_TIMER), "level choice update should own level feedback timer")

	var state := RuntimePerkState.new()
	_expect(state.apply_choice({"id": "common_bulk_up", "name": "Bulk", "max_level": 2}, null, null), "state should apply ordinary level choices through the level helper")
	_expect(int(state.runtime_skill_levels.get("common_bulk_up", 0)) == 1, "ordinary level choice should write next level")
	_expect(str(state.feedback_text) == "Bulk 1성", "ordinary level choice should apply helper-owned martial-rank feedback text")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var apply_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
	_expect(apply_flow_source.find("build_level_choice_update") >= 0, "apply-flow helper should use helper-owned level choice updates")
	_expect(state_source.find("_choice_apply_flow.apply_choice") >= 0, "state should route ordinary level choices through apply-flow orchestration")
	_expect(state_source.find("var old_level: int = int(runtime_skill_levels.get(choice_id, 0))") < 0, "state should not own old-level lookup for ordinary choices")
	_expect(state_source.find("var max_level := int(choice.get(\"max_level\", -1))") < 0, "state should not own max-level cap for ordinary choices")


func _verify_unlock_choice_update() -> void:
	var helper := RuntimePerkLevelSideEffects.new()
	var update: Dictionary = helper.build_unlock_choice_update(
		{"id": "soldier_unlock_ak47", "name": "AK", "unlocks_skill": "ak47"},
		{"soldier_unlock_ak47": 1}
	)
	_expect(bool(update.get("accepted", false)), "unlock choice update should accept valid unlock choices")
	_expect(str(update.get("choice_id", "")) == "soldier_unlock_ak47", "unlock choice update should expose the choice id")
	_expect(int(update.get("next_level", 0)) == 2, "unlock choice update should increment from current level")
	_expect(str(update.get("feedback_text", "")) == "AK 비급", "unlock choice update should keep the one-off manual tag")
	_expect(is_equal_approx(float(update.get("feedback_timer", 0.0)), RuntimePerkLevelSideEffects.LEVEL_FEEDBACK_TIMER), "unlock choice update should own unlock feedback timer")
	_expect(not bool(helper.build_unlock_choice_update({"id": "not_unlock"}, {}).get("accepted", false)), "unlock choice update should reject non-unlock choices")
	var levels := {"soldier_unlock_ak47": 1}
	var commit: Dictionary = helper.commit_unlock_choice_level(
		{"id": "soldier_unlock_ak47", "name": "AK", "unlocks_skill": "ak47"},
		levels
	)
	_expect(bool(commit.get("accepted", false)), "unlock choice commit should accept valid unlock choices")
	_expect(int(levels.get("soldier_unlock_ak47", 0)) == 2, "unlock choice commit should write the next level")
	_expect(not bool(helper.commit_unlock_choice_level({"id": "not_unlock"}, levels).get("accepted", false)), "unlock choice commit should reject non-unlock choices")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var unlock_apply_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_choice_apply.gd")
	_expect(state_source.find("_unlock_choice_apply.apply_choice") >= 0, "state should route unlock choices through unlock-apply orchestration")
	_expect(unlock_apply_source.find("commit_unlock_choice_level") >= 0, "unlock-apply helper should use helper-owned unlock choice commits")
	_expect(state_source.find("func _commit_unlock_choice_level") < 0, "state should not keep a local unlock commit wrapper")
	_expect(state_source.find("runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1") < 0, "state should not own unlock level increment")
	_expect(state_source.find("feedback_text = \"%s Lv.%d\" % [str(choice.get(\"name\", choice_id)), int(runtime_skill_levels.get(choice_id, 1))]") < 0, "state should not inline unlock feedback text")


func _verify_debug_level_update() -> void:
	var helper := RuntimePerkLevelSideEffects.new()
	var update: Dictionary = helper.build_debug_level_update(
		"common_bulk_up",
		5,
		{"name": "Bulk", "max_level": 2}
	)
	_expect(bool(update.get("accepted", false)), "debug level update should accept valid perk data")
	_expect(str(update.get("choice_id", "")) == "common_bulk_up", "debug level update should expose the choice id")
	_expect(int(update.get("current_level", -1)) == 1, "debug level update should expose previous display level")
	_expect(int(update.get("next_level", 0)) == 2, "debug level update should clamp to max level")
	_expect(str(update.get("feedback_text", "")) == "Bulk 극성", "debug level update should own martial-rank feedback text")
	_expect(is_equal_approx(float(update.get("feedback_timer", 0.0)), RuntimePerkLevelSideEffects.LEVEL_FEEDBACK_TIMER), "debug level update should own debug feedback timer")
	_expect(not bool(helper.build_debug_level_update("", 1, {"name": "Bulk"}).get("accepted", false)), "debug level update should reject blank ids")
	_expect(not bool(helper.build_debug_level_update("common_bulk_up", 1, {}).get("accepted", false)), "debug level update should reject empty perk data")

	var state := RuntimePerkState.new()
	var catalog := FakeCatalog.new({
		"common_bulk_up": {"name": "Bulk", "max_level": 2},
	})
	_expect(state.debug_set_perk_level(" common_bulk_up ", 5, null, FakeRegistry.new(), catalog), "debug state should apply ordinary level grants through the helper")
	_expect(int(state.runtime_skill_levels.get("common_bulk_up", 0)) == 2, "debug state should write helper-clamped level")
	_expect(str(state.feedback_text) == "Bulk 극성", "debug state should apply helper-owned martial-rank feedback")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var debug_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_debug_grants.gd")
	_expect(state_source.find("_debug_grants.apply_debug_grant") >= 0, "state should route debug level grants through debug-grant orchestration")
	_expect(debug_source.find("build_debug_level_update") >= 0, "debug-grant helper should call helper-owned debug level updates")
	_expect(state_source.find("build_debug_level_update") < 0, "state should not call debug level update builders directly")
	_expect(state_source.find("var max_level: int = max(1, int(data.get(\"max_level\", 1)))") < 0, "state should not own debug max-level clamp")
	_expect(state_source.find("feedback_text = \"%s Lv.%d\"") < 0, "state should not inline debug level feedback")


func _verify_debug_unlock_choice_update() -> void:
	var helper := RuntimePerkLevelSideEffects.new()
	var update: Dictionary = helper.build_debug_unlock_choice_update(
		"smasher_unlock_dash",
		5,
		{"name": "Dash", "max_level": 3, "unlocks_skill": "dash_skill"}
	)
	_expect(bool(update.get("accepted", false)), "debug unlock update should accept valid unlock perk data")
	_expect(str(update.get("choice_id", "")) == "smasher_unlock_dash", "debug unlock update should expose the choice id")
	_expect(int(update.get("current_level", -1)) == 0, "debug unlock update should expose zero current level")
	_expect(int(update.get("next_level", 0)) == 3, "debug unlock update should clamp to max level")
	_expect(not bool(helper.build_debug_unlock_choice_update("", 1, {"unlocks_skill": "dash"}).get("accepted", false)), "debug unlock update should reject blank ids")
	_expect(not bool(helper.build_debug_unlock_choice_update("smasher_unlock_dash", 1, {}).get("accepted", false)), "debug unlock update should reject empty perk data")
	_expect(not bool(helper.build_debug_unlock_choice_update("smasher_unlock_dash", 1, {"name": "Dash"}).get("accepted", false)), "debug unlock update should reject non-unlock perk data")

	var state := RuntimePerkState.new()
	var registry := FakeRegistry.new()
	var config := FakeSkillConfig.new()
	registry.instances = {"smasher_skill_config": config}
	var catalog := FakeCatalog.new({
		"smasher_unlock_dash": {"name": "Dash", "max_level": 3, "unlocks_skill": "dash_skill"},
	})
	_expect(state.debug_set_perk_level(" smasher_unlock_dash ", 1, FakeOwner.new({"selected_character_type": "smasher"}), registry, catalog), "debug state should apply unlock grants through the helper payload")
	_expect(config.unlocked == ["dash_skill"], "debug unlock grant should still route through skill config unlock")
	_expect(int(state.runtime_skill_levels.get("smasher_unlock_dash", 0)) == 1, "debug unlock grant should still commit through the normal unlock path")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var debug_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_debug_grants.gd")
	_expect(state_source.find("_debug_grants.apply_debug_grant") >= 0, "state should route debug unlock grants through debug-grant orchestration")
	_expect(debug_source.find("build_debug_unlock_choice_update") >= 0, "debug-grant helper should call helper-owned debug unlock updates")
	_expect(state_source.find("build_debug_unlock_choice_update") < 0, "state should not call debug unlock update builders directly")
	var unlock_branch := state_source.find("if str(data.get(\"unlocks_skill\", \"\"))")
	var general_branch := state_source.find("var debug_update: Dictionary", unlock_branch)
	var inline_current_level := state_source.find("data[\"current_level\"] = 0", unlock_branch)
	_expect(inline_current_level < 0 or inline_current_level > general_branch, "state should not own debug unlock current-level payload")


func _verify_dash_amplification_side_effect() -> void:
	_sync_calls = 0
	_refresh_calls = 0
	var helper := RuntimePerkLevelSideEffects.new()
	var registry := FakeRegistry.new()
	var dash_state := FakeDashState.new()
	var mythic := FakeMythicRuntime.new()
	var runtime_state := FakeRuntimeState.new()
	var owner := FakeOwner.new({"starting_dash_tokens": 2})
	registry.instances = {
		"smasher_dash_state": dash_state,
		"mythic_item_runtime": mythic,
	}
	helper.apply(
		{"id": "dash_amplification"},
		owner,
		registry,
		runtime_state,
		RuntimePerkCharacterContext.new(),
		RuntimePerkUnlockSwapFlow.new(),
		Callable(self, "_get_instance"),
		Callable(self, "_sync_owner_effects"),
		Callable(self, "_refresh_mythic_consumers")
	)
	_expect(dash_state.last_reset_full == 7, "mythic dash token capacity should override base plus perk bonus")
	_expect(mythic.last_base_tokens == 2, "mythic capacity should receive the owner base token count")
	_expect(mythic.last_runtime_state == runtime_state, "mythic capacity should receive the runtime state")
	_expect(_sync_calls == 1, "level side effect should sync owner effects once")
	_expect(_refresh_calls == 1, "level side effect should refresh mythic consumers once")


func _verify_unlock_side_effect_and_commando_sync() -> void:
	_sync_calls = 0
	_refresh_calls = 0
	var helper := RuntimePerkLevelSideEffects.new()
	var registry := FakeRegistry.new()
	var config := FakeSkillConfig.new()
	var weapon_controller := FakeWeaponController.new()
	var audio := FakeAudio.new()
	registry.instances = {
		"commando_skill_config": config,
		"commando_weapon_controller": weapon_controller,
		"game_audio": audio,
	}
	helper.apply(
		{
			"id": "soldier_unlock_ak47",
			"unlocks_skill": "ak47",
			"character_restriction": "commando",
		},
		FakeOwner.new({"selected_character_type": "soldier"}),
		registry,
		FakeRuntimeState.new(),
		RuntimePerkCharacterContext.new(),
		RuntimePerkUnlockSwapFlow.new(),
		Callable(self, "_get_instance"),
		Callable(self, "_sync_owner_effects"),
		Callable(self, "_refresh_mythic_consumers")
	)
	_expect(config.unlocked == ["ak47"], "unlock side effect should unlock and equip the skill")
	_expect(weapon_controller.sync_count == 1, "Commando unlock side effect should sync permanent weapons")
	_expect(weapon_controller.highlighted_weapon == "ak47", "Commando unlock side effect should highlight the new weapon")
	_expect(audio.play_count == 1, "Commando unlock side effect should play the weapon-change cue")


func _verify_runtime_state_facade_side_effects() -> void:
	var helper := RuntimePerkLevelSideEffects.new()
	var runtime_state := FakeRuntimeState.new()
	var registry := FakeRegistry.new()
	var dash_state := FakeDashState.new()
	var mythic := FakeMythicRuntime.new()
	registry.instances = {
		"smasher_dash_state": dash_state,
		"mythic_item_runtime": mythic,
	}
	helper.apply_from_runtime_state(
		runtime_state,
		{"id": "dash_amplification"},
		FakeOwner.new({"starting_dash_tokens": 2}),
		registry
	)
	_expect(dash_state.last_reset_full == 7, "runtime-state facade should apply dash amplification through state helper lookup")
	_expect(runtime_state.sync_calls == 1, "runtime-state facade should build owner-effect sync callback internally")
	_expect(runtime_state.refresh_calls == 1, "runtime-state facade should build mythic refresh callback internally")

	runtime_state = FakeRuntimeState.new()
	registry = FakeRegistry.new()
	var config := FakeSkillConfig.new()
	var weapon_controller := FakeWeaponController.new()
	var audio := FakeAudio.new()
	registry.instances = {
		"commando_skill_config": config,
		"commando_weapon_controller": weapon_controller,
		"game_audio": audio,
	}
	helper.apply_from_runtime_state(
		runtime_state,
		{
			"id": "soldier_unlock_ak47",
			"unlocks_skill": "ak47",
			"character_restriction": "commando",
		},
		FakeOwner.new({"selected_character_type": "soldier"}),
		registry
	)
	_expect(config.unlocked == ["ak47"], "runtime-state facade should route unlock side effects through state helper lookup")
	_expect(weapon_controller.sync_count == 1, "runtime-state facade should sync Commando weapon controller")
	_expect(audio.play_count == 1, "runtime-state facade should play Commando weapon-change cue")
	_expect(runtime_state.sync_calls == 1, "runtime-state facade unlock path should sync owner effects once")
	_expect(runtime_state.refresh_calls == 1, "runtime-state facade unlock path should refresh mythic consumers once")


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_level_side_effects.gd")
	var apply_body: String = _function_body(state_source, "func _apply_level_side_effect(")
	var facade_body: String = _function_body(helper_source, "func apply_from_runtime_state(")
	_expect(apply_body.find("_level_side_effects.apply_from_runtime_state") >= 0, "state level side-effect wrapper should delegate to runtime-state facade")
	_expect(apply_body.find("_level_side_effects.apply(") < 0, "state level side-effect wrapper should not call low-level apply directly")
	_expect(apply_body.find("_character_context") < 0, "state level side-effect wrapper should not pass character-context helper inline")
	_expect(apply_body.find("_unlock_swap_flow") < 0, "state level side-effect wrapper should not pass unlock-swap helper inline")
	_expect(apply_body.find("Callable(self") < 0, "state level side-effect wrapper should not build callbacks inline")
	_expect(helper_source.find("func apply_from_runtime_state(") >= 0, "level-side-effect helper should expose runtime-state facade")
	_expect(facade_body.find("_get_runtime_state_object(runtime_state, \"_character_context\")") >= 0, "level-side-effect facade should own character-context lookup")
	_expect(facade_body.find("_get_runtime_state_object(runtime_state, \"_unlock_swap_flow\")") >= 0, "level-side-effect facade should own unlock-swap lookup")
	_expect(facade_body.find("_build_runtime_state_callable(runtime_state, \"_get_instance\")") >= 0, "level-side-effect facade should own get-instance callback assembly")
	_expect(facade_body.find("_build_runtime_state_callable(runtime_state, \"_sync_runtime_perk_owner_effects\")") >= 0, "level-side-effect facade should own owner-sync callback assembly")
	_expect(facade_body.find("_build_runtime_state_callable(runtime_state, \"_refresh_mythic_runtime_perk_consumers\")") >= 0, "level-side-effect facade should own mythic-refresh callback assembly")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _get_instance(registry: Object, key: String) -> Object:
	return registry.get_instance(key)


func _sync_owner_effects(_owner: Object, _registry: Object, _perf_logger: Object = null) -> void:
	_sync_calls += 1


func _refresh_mythic_consumers(_owner: Object, _registry: Object) -> void:
	_refresh_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeOwner:
	var data: Dictionary = {}

	func _init(source: Dictionary) -> void:
		data = source

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)


class FakeRegistry:
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeCatalog:
	var data: Dictionary = {}

	func _init(source: Dictionary) -> void:
		data = source

	func get_perk_data(perk_id: String) -> Dictionary:
		var value: Variant = data.get(perk_id, {})
		if value is Dictionary:
			return value.duplicate(true)
		return {}


class FakeRuntimeState:
	var _character_context: Object = RuntimePerkCharacterContext.new()
	var _unlock_swap_flow: Object = RuntimePerkUnlockSwapFlow.new()
	var sync_calls := 0
	var refresh_calls := 0

	func get_runtime_skill_bonus(skill_id: String) -> float:
		if skill_id == "dash_amplification":
			return 3.0
		return 0.0

	func _get_instance(registry: Object, key: String) -> Object:
		return registry.get_instance(key)

	func _sync_runtime_perk_owner_effects(_owner: Object, _registry: Object, _perf_logger: Object = null) -> void:
		sync_calls += 1

	func _refresh_mythic_runtime_perk_consumers(_owner: Object, _registry: Object) -> void:
		refresh_calls += 1


class FakeDashState:
	var last_reset_full := -1

	func reset_full(max_tokens: int) -> void:
		last_reset_full = max_tokens


class FakeMythicRuntime:
	var last_base_tokens := 0
	var last_runtime_state: Object = null

	func get_dash_token_capacity(base_tokens: int, runtime_state: Object) -> int:
		last_base_tokens = base_tokens
		last_runtime_state = runtime_state
		return base_tokens + 5


class FakeSkillConfig:
	var unlocked: Array[String] = []

	func unlock_and_equip_skill(skill_name: String) -> bool:
		unlocked.append(skill_name)
		return true


class FakeWeaponController:
	var sync_count := 0
	var highlighted_weapon := ""

	func sync_equipped_permanent(_skill_config: Object) -> void:
		sync_count += 1

	func trigger_hud_highlight(weapon_id: String) -> void:
		highlighted_weapon = weapon_id


class FakeAudio:
	var play_count := 0

	func play_commando_weapon_change() -> void:
		play_count += 1
