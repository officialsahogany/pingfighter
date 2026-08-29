extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

const DOWSING_GOGGLES_PERK_ID := "dowsing_goggles"
const DOWSING_GOGGLES_RARE_SLOT_BONUS_KEY := "fusion_rare_slot_bonus_pct"
const DOWSING_GOGGLES_COUNT_SHIFT_KEY := "fusion_byproduct_count_shift_pct"

var _fusion_state: Object = null
var _byproduct_runtime: Object = null
var _offer_planner: Object = null
var _modal_flow: Object = null
var _modal_input: Object = null
var _modal_catalog: Object = null
var _test_offer_roll_override: Array = []


func get_fusion_state() -> Object:
	if _fusion_state == null:
		_fusion_state = load("res://scripts/characters/perk_fusion_state.gd").new()
	return _fusion_state


func commit_fusion(
	source_ids: Array,
	outcome_data: Dictionary,
	catalog: Object,
	runtime_skill_levels: Dictionary
) -> Dictionary:
	return get_fusion_state().commit_fusion(source_ids, outcome_data, catalog, runtime_skill_levels)


func restore_snapshot(snapshot: Dictionary, catalog: Object, runtime_skill_levels: Dictionary) -> Dictionary:
	return get_fusion_state().restore_snapshot(snapshot, catalog, runtime_skill_levels)


func apply_option_value(perk_id: String, option_key: String, base_value: float) -> float:
	return float(get_fusion_state().apply_option_value(perk_id, option_key, base_value))


func get_snapshot() -> Dictionary:
	return get_fusion_state().get_snapshot()


func get_revision() -> int:
	return int(get_fusion_state().get_revision())


func get_next_token_snapshot() -> Dictionary:
	return get_fusion_state().get_next_fusion_token_snapshot()


func get_effective_level_bonus(perk_id: String) -> int:
	return int(get_fusion_state().get_effective_level_bonus(perk_id))


func get_owned_byproduct_ids() -> Array[String]:
	return get_fusion_state().get_owned_byproduct_ids()


func get_slot_reduction() -> int:
	return int(get_fusion_state().get_slot_reduction())


func get_active_item_slot_bonus(dash_amplification_count: int) -> int:
	return int(_get_byproduct_runtime().get_active_item_slot_bonus(
		get_owned_byproduct_ids(),
		dash_amplification_count
	))


func get_active_item_slot_bonus_breakdown(dash_amplification_count: int) -> Dictionary:
	return _get_byproduct_runtime().get_active_item_slot_bonus_breakdown(
		get_owned_byproduct_ids(),
		dash_amplification_count
	).duplicate(true)


func get_fused_source_lookup() -> Dictionary:
	return get_fusion_state().get_fused_source_lookup()


func peek_modal_flow() -> Object:
	return _modal_flow


func get_modal_flow() -> Object:
	if _modal_flow == null:
		_modal_flow = load("res://scripts/characters/perk_fusion_modal_flow.gd").new()
	return _modal_flow


func set_modal_flow(value: Object) -> void:
	_modal_flow = value


func peek_modal_input() -> Object:
	return _modal_input


func get_modal_input() -> Object:
	if _modal_input == null:
		_modal_input = load("res://scripts/characters/perk_fusion_modal_input.gd").new()
	return _modal_input


func set_modal_input(value: Object) -> void:
	_modal_input = value


func get_modal_catalog() -> Object:
	return _modal_catalog


func set_modal_catalog(value: Object) -> void:
	_modal_catalog = value


func is_modal_active() -> bool:
	return _modal_flow != null and bool(_modal_flow.is_active())


func is_boot_animation_active() -> bool:
	return is_modal_active() and str(_modal_flow.get_phase()) == "animation"


func consume_cold_boot_events() -> Array:
	if _modal_flow == null:
		return []
	return _modal_flow.consume_cold_boot_events()


func get_modal_snapshot() -> Dictionary:
	if _modal_flow == null:
		return {}
	return _modal_flow.get_snapshot()


func begin_modal_from_runtime_state(
	runtime_state: Object,
	selected_choice: Dictionary,
	registry: Object,
	entered_via_rt: bool = false
) -> bool:
	if runtime_state == null:
		return false
	var catalog: Object = RuntimePerkRuntimeStateAccess.call_object(
		runtime_state,
		"_get_catalog",
		[registry]
	)
	var candidate_ids: Array = selected_choice.get("eligible_sources", []) as Array
	if candidate_ids.is_empty():
		candidate_ids = build_candidate_ids_from_runtime_state(runtime_state, catalog)
	var flow: Object = get_modal_flow()
	var origin_choices: Array = RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")
	if not bool(flow.start(selected_choice, origin_choices.duplicate(true), candidate_ids)):
		return false
	_modal_catalog = catalog
	_reset_modal_preview_cache(runtime_state)
	var modal_input: Object = get_modal_input()
	modal_input.reset()
	if entered_via_rt:
		modal_input.suppress_confirm_until_release()
	if runtime_state.has_method("_play_perk_select_audio"):
		runtime_state.call("_play_perk_select_audio", registry)
	return true


func build_candidate_ids_from_runtime_state(runtime_state: Object, catalog: Object) -> Array:
	var fused_lookup: Dictionary = get_fused_source_lookup()
	var candidates: Array = []
	var fusion_catalog: Object = load("res://scripts/characters/perk_fusion_catalog.gd").new()
	var runtime_skill_levels: Dictionary = RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels")
	for skill_id_value: Variant in runtime_skill_levels.keys():
		var skill_id := str(skill_id_value)
		var base_level: int = int(runtime_skill_levels[skill_id_value])
		if base_level <= 0:
			continue
		if bool(fusion_catalog.is_candidate(skill_id, base_level, catalog, fused_lookup)):
			candidates.append(skill_id)
	return candidates


func set_test_offer_roll_override(appearance_roll_unit: float, replacement_roll_unit: float) -> void:
	_test_offer_roll_override = [appearance_roll_unit, replacement_roll_unit]


func set_test_offer_roll_override_values(values: Array) -> void:
	_test_offer_roll_override = values.duplicate()


func get_test_offer_roll_override() -> Array:
	return _test_offer_roll_override


func try_inject_offer_from_runtime_state(
	runtime_state: Object,
	catalog: Object,
	appearance_roll_unit: float = -1.0,
	replacement_roll_unit: float = -1.0
) -> Dictionary:
	var choices: Array = RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")
	if choices.is_empty():
		return {"rolled": false}
	var choice_context: Dictionary = RuntimePerkRuntimeStateAccess.get_dict(
		runtime_state,
		"current_choice_context"
	)
	var offer_source := str(choice_context.get("source", ""))
	var eligible_sources: Array = build_candidate_ids_from_runtime_state(runtime_state, catalog)
	if not can_plan_offer(choices, eligible_sources, offer_source):
		return {"rolled": false}
	if appearance_roll_unit < 0.0 and replacement_roll_unit < 0.0 and _test_offer_roll_override.size() >= 2:
		appearance_roll_unit = float(_test_offer_roll_override[0])
		replacement_roll_unit = float(_test_offer_roll_override[1])
		_test_offer_roll_override = []
	var appearance_unit: float = appearance_roll_unit if appearance_roll_unit >= 0.0 else randf()
	var replacement_unit: float = replacement_roll_unit if replacement_roll_unit >= 0.0 else randf()
	var result: Dictionary = plan_offer(
		choices,
		eligible_sources,
		offer_source,
		appearance_unit,
		replacement_unit
	)
	if bool(result.get("appeared", false)):
		runtime_state.set("current_choices", result.get("choices", choices) as Array)
	return result


func handle_modal_input_from_runtime_state(
	runtime_state: Object,
	event: InputEvent,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> bool:
	var snapshot: Dictionary = RuntimePerkRuntimeStateAccess.call_dict(
		runtime_state,
		"get_perk_fusion_modal_snapshot"
	)
	var resolution: Dictionary = get_modal_input().resolve(event, snapshot, view_size)
	var flow: Object = get_modal_flow()
	if resolution.has("move"):
		flow.move_highlight(int(resolution.get("move", 0)))
	if resolution.has("highlight_index") and int(resolution.get("highlight_index", -1)) >= 0:
		flow.set_highlight(int(resolution.get("highlight_index", -1)))
	if resolution.has("select_index"):
		flow.select_source_at(int(resolution.get("select_index", -1)))
	if bool(resolution.get("cancel", false)):
		cancel_modal_from_runtime_state(runtime_state)
	if bool(resolution.get("confirm", false)):
		confirm_modal_from_runtime_state(runtime_state, owner, registry)
	return bool(resolution.get("consumed", true))


func cancel_modal_from_runtime_state(runtime_state: Object) -> Dictionary:
	var result: Dictionary = get_modal_flow().cancel_current()
	if bool(result.get("cancel_to_choices", false)):
		var fallback_choices: Array = RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")
		var restored_choices: Array = (result.get("origin_choices", fallback_choices) as Array).duplicate(true)
		runtime_state.set("current_choices", restored_choices)
		get_modal_input().reset()
		_modal_catalog = null
		_reset_modal_preview_cache(runtime_state)
	return result


func confirm_modal_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	rolls: Dictionary = {}
) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false, "blocked_reason": "missing_runtime_state"}
	var flow: Object = get_modal_flow()
	if str(flow.get_phase()) == "confirm" and not runtime_state.has_method("_finish_successful_choice"):
		return {"accepted": false, "blocked_reason": "missing_choice_finish"}
	var action: Dictionary = flow.confirm_current()
	if bool(action.get("commit_requested", false)):
		var catalog: Object = _modal_catalog
		if catalog == null:
			catalog = RuntimePerkRuntimeStateAccess.call_object(runtime_state, "_get_catalog", [registry])
		var source_ids: Array = action.get("source_ids", []) as Array
		var result: Dictionary = build_commit_result_from_runtime_state(runtime_state, source_ids, catalog, rolls)
		var runtime_skill_levels: Dictionary = RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels")
		var record: Dictionary = commit_fusion(source_ids, result, catalog, runtime_skill_levels)
		if record.is_empty():
			return {"accepted": false, "blocked_reason": "invalid_sources"}
		flow.begin_committed_result(record)
		return {"accepted": true, "record": record}
	if bool(action.get("finish_requested", false)):
		return finish_modal_from_runtime_state(runtime_state, owner, registry, action.get("record", {}) as Dictionary)
	return action


func build_commit_result_from_runtime_state(
	runtime_state: Object,
	source_ids: Array,
	catalog: Object,
	rolls: Dictionary
) -> Dictionary:
	var result_builder: Object = load("res://scripts/characters/perk_fusion_result_builder.gd")
	var lane_builder: Object = load("res://scripts/characters/perk_fusion_penalty_lane_builder.gd").new()
	var byproduct_catalog: Object = load("res://scripts/characters/perk_fusion_byproduct_catalog.gd").new()
	var tokens: Dictionary = get_next_token_snapshot()
	var runtime_skill_levels: Dictionary = RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels")
	var context: Dictionary = build_result_context(source_ids, catalog, runtime_skill_levels)
	context["source_ids"] = source_ids.duplicate()
	var owned_byproducts := get_owned_byproduct_ids()
	if runtime_state != null and runtime_state.has_method("get_perk_fusion_owned_byproduct_ids"):
		var owned_value: Variant = runtime_state.call("get_perk_fusion_owned_byproduct_ids")
		if owned_value is Array:
			owned_byproducts.assign(owned_value as Array)
	context["owned_byproducts"] = owned_byproducts
	context["available_byproducts"] = byproduct_catalog.get_contextual_pool(
		context["owned_byproducts"],
		context.get("limit_break_eligible_sources", []) as Array,
		PerkConversionFlags.is_enabled()
	)
	context["core_stabilize_armed"] = bool(tokens.get("core_stabilize_armed", false))
	context["dual_catalyst_armed"] = bool(tokens.get("dual_catalyst_armed", false))
	context["rare_slot_chance_bonus_percent"] = get_rare_slot_bonus_percent(runtime_state)
	context["byproduct_count_shift_percent"] = get_byproduct_count_shift_percent(runtime_state)
	context["penalty_lanes"] = lane_builder.build(source_ids, runtime_state, catalog)
	var effective_rolls: Dictionary = rolls
	if effective_rolls.is_empty():
		effective_rolls = {
			"outcome": randf(),
			"magnitude": [randf(), randf()],
			"lane_selection": [randf(), randf()],
			"delete": randf(),
			"byproduct_count": randf(),
			# 3번째 선택 롤이 없으면 +3 롤의 희귀 슬롯이 항상 목록 첫 항목으로
			# 고정된다(roll 0.0 폴백). 슬롯 수만큼 공급한다.
			"byproduct_selection": [randf(), randf(), randf()],
			"rare_slot": randf(),
		}
	return result_builder.build_result(context, effective_rolls)


func get_rare_slot_bonus_percent(runtime_state: Object) -> float:
	return _get_dowsing_fusion_value(runtime_state, DOWSING_GOGGLES_RARE_SLOT_BONUS_KEY)


func get_byproduct_count_shift_percent(runtime_state: Object) -> float:
	return _get_dowsing_fusion_value(runtime_state, DOWSING_GOGGLES_COUNT_SHIFT_KEY)


func _get_dowsing_fusion_value(runtime_state: Object, option_key: String) -> float:
	if not PerkConversionFlags.is_enabled() or runtime_state == null:
		return 0.0
	if (
		not runtime_state.has_method("get_converted_perk_effect_level")
		or not runtime_state.has_method("get_converted_perk_option_value")
	):
		return 0.0
	var effective_level := maxi(
		0,
		int(runtime_state.call("get_converted_perk_effect_level", DOWSING_GOGGLES_PERK_ID))
	)
	if effective_level <= 0:
		return 0.0
	return maxf(0.0, float(runtime_state.call(
		"get_converted_perk_option_value",
		DOWSING_GOGGLES_PERK_ID,
		option_key
	)))


func finish_modal_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	record: Dictionary
) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false, "blocked_reason": "missing_runtime_state"}
	if not runtime_state.has_method("_finish_successful_choice"):
		return {"accepted": false, "blocked_reason": "missing_choice_finish"}
	var committed_choice: Dictionary = {
		"id": "perk_fusion",
		"type": "fusion",
		"fusion_record": record.duplicate(true),
		"fusion_revision": get_revision(),
	}
	var finish: Dictionary = {}
	var finish_value: Variant = runtime_state.call(
		"_finish_successful_choice",
		"perk_fusion",
		owner,
		registry,
		null,
		committed_choice
	)
	if finish_value is Dictionary:
		finish = finish_value
	reset_modal(runtime_state)
	var cold_boot_host: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_cold_boot_cinematic_host")
	if (
		cold_boot_host != null
		and is_instance_valid(cold_boot_host)
		and cold_boot_host.has_method("is_boot_active")
		and bool(cold_boot_host.is_boot_active())
		and cold_boot_host.has_method("finish_boot")
	):
		cold_boot_host.finish_boot()
	var merged: Dictionary = {"accepted": true, "record": record.duplicate(true)}
	merged["finish"] = finish
	return merged


func reset_modal(runtime_state: Object = null) -> void:
	if _modal_flow != null:
		_modal_flow.reset()
	if _modal_input != null:
		_modal_input.reset()
	_modal_catalog = null
	if runtime_state != null:
		_reset_modal_preview_cache(runtime_state)


func _reset_modal_preview_cache(runtime_state: Object) -> void:
	if runtime_state != null and runtime_state.has_method("_reset_perk_fusion_modal_preview_cache"):
		runtime_state.call("_reset_perk_fusion_modal_preview_cache")


func build_result_context(source_ids: Array, catalog: Object, runtime_skill_levels: Dictionary) -> Dictionary:
	var eligible: Array[String] = []
	for source_value: Variant in source_ids:
		var perk_id := str(source_value).strip_edges()
		if perk_id.is_empty():
			continue
		var base_level := int(runtime_skill_levels.get(perk_id, 0))
		var max_level := RuntimePerkProgression.get_authored_max_level(perk_id)
		if catalog != null and catalog.has_method("get_perk_data"):
			var data: Dictionary = catalog.get_perk_data(perk_id)
			if not data.is_empty():
				max_level = int(data.get("max_level", max_level))
		if max_level > 0 and base_level > 0 and base_level >= max_level:
			eligible.append(perk_id)
	return {"limit_break_eligible_sources": eligible}


func plan_offer(
	choices: Array,
	eligible_source_ids: Array,
	offer_source: String,
	appearance_roll_unit: float,
	replacement_roll_unit: float
) -> Dictionary:
	var planner: Object = _get_offer_planner()
	if not bool(planner.can_roll(choices, eligible_source_ids, offer_source)):
		return {"rolled": false}
	return planner.plan_offer(
		choices,
		eligible_source_ids,
		offer_source,
		appearance_roll_unit,
		replacement_roll_unit
	)


func can_plan_offer(choices: Array, eligible_source_ids: Array, offer_source: String) -> bool:
	return bool(_get_offer_planner().can_roll(choices, eligible_source_ids, offer_source))


func consume_wall_bounce_gold_award(gold_multiplier: float, ignition_aura_active: bool) -> int:
	var runtime: Object = _get_byproduct_runtime()
	var offer := int(runtime.get_wall_bounce_gold_offer(get_owned_byproduct_ids()))
	if offer <= 0:
		return 0
	var modified := float(offer) * maxf(0.0, gold_multiplier)
	if ignition_aura_active:
		modified *= 2.0
	var actual := mini(int(round(modified)), int(runtime.get_remaining_wall_bounce_gold()))
	if actual <= 0:
		return 0
	runtime.record_wall_bounce_gold(actual)
	return actual


func get_round_golden_trajectory_gold() -> int:
	return int(_get_byproduct_runtime().get_round_golden_trajectory_gold())


func can_trigger_dash_paddle_speed_boost() -> bool:
	return bool(_get_byproduct_runtime().can_trigger_dash_paddle_speed_boost(
		get_owned_byproduct_ids()
	))


func try_trigger_dash_paddle_speed_boost(
	roll_unit: float,
	restore_effective_speed: float
) -> Dictionary:
	return _get_byproduct_runtime().try_trigger_dash_paddle_speed_boost(
		get_owned_byproduct_ids(),
		roll_unit,
		restore_effective_speed
	).duplicate(true)


func consume_boss_guard_restore_effective_speed() -> float:
	return float(_get_byproduct_runtime().consume_boss_guard_restore_effective_speed())


func can_activate_spellbreaker_guard() -> bool:
	return bool(_get_byproduct_runtime().can_activate_spellbreaker_guard(get_owned_byproduct_ids()))


func try_activate_spellbreaker_guard(roll_unit: float, player_center: Vector2) -> Dictionary:
	return _get_byproduct_runtime().try_activate_spellbreaker_guard(
		get_owned_byproduct_ids(),
		roll_unit,
		player_center
	).duplicate(true)


func is_spellbreaker_guard_active() -> bool:
	return bool(_get_byproduct_runtime().is_spellbreaker_guard_active())


func try_parry_boss_skill(skill_id: String, skill_label: String, impact_pos: Vector2) -> Dictionary:
	return _get_byproduct_runtime().try_parry_boss_skill(
		skill_id,
		skill_label,
		impact_pos
	).duplicate(true)


func notify_player_dash() -> void:
	_get_byproduct_runtime().on_player_dash(get_owned_byproduct_ids())


func notify_skill_used() -> void:
	_get_byproduct_runtime().on_skill_used(get_owned_byproduct_ids())


func get_move_speed_multiplier() -> float:
	return float(_get_byproduct_runtime().get_player_move_speed_multiplier())


func update_byproducts(
	delta: float,
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	var dash_state: Object = _get_cached_instance(registry, "smasher_dash_state")
	var player_guard_available := true
	var viper_runtime: Object = _get_cached_instance(registry, "viper_skill_runtime")
	if viper_runtime != null and viper_runtime.has_method("is_player_guard_available"):
		player_guard_available = bool(viper_runtime.is_player_guard_available())
	var result: Dictionary = _get_byproduct_runtime().update(
		delta,
		get_owned_byproduct_ids(),
		owner,
		dash_state,
		player_guard_available
	)
	if bool(result.get("triggered", false)):
		var audio: Object = _get_cached_instance(registry, "game_audio")
		if audio != null and audio.has_method("play_lingpet_ring_dash"):
			audio.play_lingpet_ring_dash()
	return result


func has_byproduct_visible_effects() -> bool:
	return _byproduct_runtime != null and bool(_byproduct_runtime.has_visible_effects())


func draw_byproduct_effects(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if _byproduct_runtime != null:
		_byproduct_runtime.draw(canvas, shake_offset)


func reset_round_byproducts() -> void:
	_get_byproduct_runtime().reset_round()


func queue_player_point_lost(match_finished: bool, recycle_roll_unit: float) -> Dictionary:
	var runtime: Object = _get_byproduct_runtime()
	if match_finished:
		runtime.consume_pending_point_loss_effects()
		return {}
	return runtime.queue_player_point_lost(get_owned_byproduct_ids(), recycle_roll_unit)


func consume_pending_point_loss_effects() -> Dictionary:
	return _get_byproduct_runtime().consume_pending_point_loss_effects()


func reset() -> void:
	if _fusion_state != null:
		_fusion_state.reset()
	if _byproduct_runtime != null:
		_byproduct_runtime.reset()
	_test_offer_roll_override = []
	reset_modal()


func _get_byproduct_runtime() -> Object:
	if _byproduct_runtime == null:
		_byproduct_runtime = load("res://scripts/characters/perk_fusion_byproduct_runtime.gd").new()
	return _byproduct_runtime


func _get_offer_planner() -> Object:
	if _offer_planner == null:
		_offer_planner = load("res://scripts/characters/perk_fusion_offer_planner.gd").new()
	return _offer_planner


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.get_cached_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
