extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const LEVEL_FEEDBACK_TIMER := 1.1


func build_level_choice_update(choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
	var choice_id: String = str(choice.get("id", ""))
	if choice_id == "":
		return {"accepted": false}
	var old_level: int = int(runtime_skill_levels.get(choice_id, 0))
	var next_level := old_level + 1
	var max_level := int(choice.get("max_level", -1))
	if max_level > 0:
		next_level = mini(next_level, max_level)
	return {
		"accepted": true,
		"choice_id": choice_id,
		"old_level": old_level,
		"next_level": next_level,
		"feedback_text": "%s %s" % [str(choice.get("name", choice_id)), _feedback_rank_text(choice, next_level)],
		"feedback_timer": LEVEL_FEEDBACK_TIMER,
	}


func build_target_level_choice_update(
	choice: Dictionary,
	runtime_skill_levels: Dictionary,
	target_level: int
) -> Dictionary:
	var choice_id: String = str(choice.get("id", "")).strip_edges()
	var old_level: int = int(runtime_skill_levels.get(choice_id, 0))
	var max_level: int = int(choice.get("max_level", -1))
	if choice_id.is_empty() or target_level <= old_level:
		return {"accepted": false, "blocked_reason": "invalid_target_level"}
	if max_level > 0 and target_level > max_level:
		return {"accepted": false, "blocked_reason": "target_level_above_max"}
	return {
		"accepted": true,
		"choice_id": choice_id,
		"old_level": old_level,
		"next_level": target_level,
		"feedback_text": "%s %s" % [
			str(choice.get("name", choice_id)),
			_feedback_rank_text(choice, target_level),
		],
		"feedback_timer": LEVEL_FEEDBACK_TIMER,
	}


func build_unlock_choice_update(choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
	var choice_id: String = str(choice.get("id", ""))
	if choice_id == "" or str(choice.get("unlocks_skill", "")) == "":
		return {"accepted": false}
	var next_level: int = int(runtime_skill_levels.get(choice_id, 0)) + 1
	return {
		"accepted": true,
		"choice_id": choice_id,
		"next_level": next_level,
		"feedback_text": "%s %s" % [str(choice.get("name", choice_id)), _feedback_rank_text(choice, next_level)],
		"feedback_timer": LEVEL_FEEDBACK_TIMER,
	}


func commit_unlock_choice_level(choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
	var update: Dictionary = build_unlock_choice_update(choice, runtime_skill_levels)
	if not bool(update.get("accepted", false)):
		return update
	var choice_id: String = str(update.get("choice_id", choice.get("id", "")))
	if choice_id == "":
		return {"accepted": false}
	runtime_skill_levels[choice_id] = int(update.get("next_level", runtime_skill_levels.get(choice_id, 0)))
	return update


func build_debug_level_update(perk_id: String, target_level: int, perk_data: Dictionary) -> Dictionary:
	var clean_id: String = perk_id.strip_edges()
	if clean_id == "" or perk_data.is_empty():
		return {"accepted": false}
	var max_level: int = max(1, int(perk_data.get("max_level", 1)))
	var next_level: int = clampi(target_level, 1, max_level)
	return {
		"accepted": true,
		"choice_id": clean_id,
		"current_level": max(0, next_level - 1),
		"next_level": next_level,
		"feedback_text": "%s %s" % [str(perk_data.get("name", clean_id)), _feedback_rank_text(perk_data, next_level)],
		"feedback_timer": LEVEL_FEEDBACK_TIMER,
	}


func build_debug_unlock_choice_update(perk_id: String, target_level: int, perk_data: Dictionary) -> Dictionary:
	var clean_id: String = perk_id.strip_edges()
	if clean_id == "" or perk_data.is_empty() or str(perk_data.get("unlocks_skill", "")) == "":
		return {"accepted": false}
	var max_level: int = max(1, int(perk_data.get("max_level", 1)))
	var next_level: int = clampi(target_level, 1, max_level)
	return {
		"accepted": true,
		"choice_id": clean_id,
		"current_level": 0,
		"next_level": next_level,
	}


func _feedback_rank_text(perk_data: Dictionary, level: int) -> String:
	return LanguageSettings.format_mugong_rank(perk_data, level)


func apply_from_runtime_state(
	runtime_state: Object,
	choice: Dictionary,
	owner: Object,
	registry: Object,
	perf_logger: Object = null
) -> void:
	apply(
		choice,
		owner,
		registry,
		runtime_state,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_character_context"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_unlock_swap_flow"),
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance"),
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_sync_runtime_perk_owner_effects"),
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_refresh_mythic_runtime_perk_consumers"),
		perf_logger
	)


func apply(
	choice: Dictionary,
	owner: Object,
	registry: Object,
	runtime_state: Object,
	character_context: Object,
	unlock_swap_flow: Object,
	get_instance: Callable,
	sync_owner_effects: Callable,
	refresh_mythic_consumers: Callable,
	perf_logger: Object = null
) -> void:
	if owner == null:
		return
	var choice_id: String = str(choice.get("id", ""))
	if choice_id == "dash_amplification":
		_apply_dash_amplification(owner, registry, runtime_state, character_context, get_instance, perf_logger)
	var sync_start: int = _perf_begin(perf_logger)
	sync_owner_effects.call(owner, registry, perf_logger)
	_perf_end(perf_logger, "process.runtime_perk.level.sync_owner_effects", sync_start)
	var mythic_refresh_start: int = _perf_begin(perf_logger)
	refresh_mythic_consumers.call(owner, registry)
	_perf_end(perf_logger, "process.runtime_perk.level.mythic_refresh", mythic_refresh_start)
	_apply_unlock_side_effect(choice, owner, registry, character_context, unlock_swap_flow, get_instance)


func _apply_dash_amplification(
	owner: Object,
	registry: Object,
	runtime_state: Object,
	character_context: Object,
	get_instance: Callable,
	perf_logger: Object
) -> void:
	var dash_start: int = _perf_begin(perf_logger)
	var dash_state: Object = get_instance.call(registry, "smasher_dash_state")
	if dash_state != null and dash_state.has_method("reset_full"):
		var base_tokens: int = max(1, int(character_context.get_starting_dash_tokens(owner))) if character_context != null else 1
		var max_tokens: int = base_tokens + int(runtime_state.get_runtime_skill_bonus("dash_amplification")) if runtime_state != null and runtime_state.has_method("get_runtime_skill_bonus") else base_tokens
		var mythic_item_runtime: Object = get_instance.call(registry, "mythic_item_runtime")
		if mythic_item_runtime != null and mythic_item_runtime.has_method("get_dash_token_capacity"):
			max_tokens = int(mythic_item_runtime.get_dash_token_capacity(base_tokens, runtime_state))
		dash_state.reset_full(max_tokens)
	_perf_end(perf_logger, "process.runtime_perk.level.dash_amplification", dash_start)


func _apply_unlock_side_effect(
	choice: Dictionary,
	owner: Object,
	registry: Object,
	character_context: Object,
	unlock_swap_flow: Object,
	get_instance: Callable
) -> void:
	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	if unlocked_skill == "":
		return
	var owner_character_type := "smasher"
	if character_context != null and character_context.has_method("get_owner_character_type"):
		owner_character_type = str(character_context.get_owner_character_type(owner))
	var character_type: String = str(choice.get("character_restriction", owner_character_type))
	var config_key := ""
	if character_context != null and character_context.has_method("get_skill_config_key"):
		config_key = str(character_context.get_skill_config_key(character_type))
	var skill_config: Object = get_instance.call(registry, config_key)
	if skill_config != null and skill_config.has_method("unlock_and_equip_skill"):
		skill_config.unlock_and_equip_skill(unlocked_skill)
	var normalized := character_type
	if character_context != null and character_context.has_method("normalize_character_type"):
		normalized = str(character_context.normalize_character_type(character_type))
	if normalized == "soldier" and unlock_swap_flow != null and unlock_swap_flow.has_method("sync_commando_weapon_controller"):
		unlock_swap_flow.sync_commando_weapon_controller(
			unlocked_skill,
			skill_config,
			registry,
			character_type,
			get_instance
		)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
