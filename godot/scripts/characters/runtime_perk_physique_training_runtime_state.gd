extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const ActiveItemCooldownComposer := preload("res://scripts/items/active_item_cooldown_composer.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const CooldownFloorPolicy := preload("res://scripts/characters/cooldown_floor_policy.gd")
const PhysiqueTrainingCatalog := preload("res://scripts/characters/physique_training_catalog.gd")
const PhysiqueTrainingState := preload("res://scripts/characters/physique_training_state.gd")
const PhysiqueTrainingOfferPlanner := preload("res://scripts/characters/physique_training_offer_planner.gd")

const DEBUG_OFFER_LOG := false
const PROBE_ACTIVE_ITEM_COOLDOWN_BASE_MSEC := 1000

var _catalog: Object = PhysiqueTrainingCatalog.new()
var _state: Object = PhysiqueTrainingState.new()
var _offer_planner: Object = PhysiqueTrainingOfferPlanner.new()
var _bonus_probe_override: Dictionary = {}


func get_catalog() -> Object:
	return _catalog


func set_catalog(value: Object) -> void:
	_catalog = value


func get_state() -> Object:
	return _state


func set_state(value: Object) -> void:
	_state = value


func get_offer_planner() -> Object:
	return _offer_planner


func set_offer_planner(value: Object) -> void:
	_offer_planner = value


func get_snapshot() -> Dictionary:
	return _state.get_snapshot()


func restore(snapshot: Dictionary) -> Dictionary:
	return _state.restore(snapshot, _catalog)


func reset_state() -> void:
	_state.reset()


func get_count(training_id: String) -> int:
	return int(_state.get_count(training_id))


func get_applied_count(training_id: String) -> float:
	return float(_state.get_applied_count(training_id))


func get_bonus(stat_key: String, training_multiplier: float = 1.0) -> float:
	if not PerkConversionFlags.is_enabled():
		return 0.0
	var clean_key := stat_key.strip_edges()
	var bonus := 0.0
	if _bonus_probe_override.has(clean_key):
		bonus = float(_bonus_probe_override[clean_key])
	else:
		bonus = float(_state.get_bonus(clean_key, _catalog))
	if (
		_catalog != null
		and _catalog.has_method("is_training_mastery_amplifiable_stat")
		and bool(_catalog.is_training_mastery_amplifiable_stat(clean_key))
	):
		bonus *= maxf(1.0, training_multiplier)
	return bonus


# Saturation compares final consumer results. Existing Mugong and mythic
# modifiers can make the next acquisition dead before the training-only ceiling.
func is_saturated_from_runtime_state(
	runtime_state: Object,
	training_id: String,
	registry: Object = null
) -> bool:
	if runtime_state == null or not PerkConversionFlags.is_enabled():
		return false
	var clean_id := training_id.strip_edges()
	var stat_key := str(_catalog.get_stat_key(clean_id))
	var amount := float(_catalog.get_amount(clean_id))
	if stat_key == "" or amount <= 0.0:
		return false
	var current_bonus := float(_state.get_bonus(stat_key, _catalog))
	var current_value: Variant = _probe_consumer_value(runtime_state, stat_key, current_bonus, registry)
	if current_value == null:
		return false
	var next_value: Variant = _probe_consumer_value(runtime_state, stat_key, current_bonus + amount, registry)
	return is_equal_approx(float(current_value), float(next_value))


func apply_choice_from_runtime_state(
	runtime_state: Object,
	choice: Dictionary,
	owner: Object,
	registry: Object
) -> bool:
	if (
		runtime_state == null
		or not PerkConversionFlags.is_enabled()
		or not bool(choice.get("is_physique_training", false))
	):
		return false
	var training_id := str(choice.get("id", "")).strip_edges()
	if is_saturated_from_runtime_state(runtime_state, training_id, registry):
		return false
	var effect_multiplier := maxf(1.0, float(choice.get("training_effect_multiplier", 1.0)))
	var accepted := bool(_state.commit(
		training_id,
		_catalog,
		effect_multiplier
	).get("accepted", false))
	if not accepted:
		return false
	if runtime_state.has_method("_sync_runtime_perk_owner_effects"):
		runtime_state.call("_sync_runtime_perk_owner_effects", owner, registry)
	if runtime_state.has_method("_refresh_mythic_runtime_perk_consumers"):
		runtime_state.call("_refresh_mythic_runtime_perk_consumers", owner, registry)
	return true


# Read-only one-acquisition projection. The speculative state uses the same
# PhysiqueTrainingState.commit path as the real choice apply; only its resulting
# raw bonus is exposed through the existing consumer-probe seam while the
# caller rebuilds the production stat row. The live training state and owner
# are never mutated.
func project_next_choice_from_runtime_state(
	runtime_state: Object,
	choice: Dictionary,
	registry: Object,
	projector: Callable
) -> Dictionary:
	if (
		runtime_state == null
		or not PerkConversionFlags.is_enabled()
		or not bool(choice.get("is_physique_training", false))
		or not projector.is_valid()
	):
		return {"accepted": false, "reason": "invalid_request"}
	var training_id := str(choice.get("id", "")).strip_edges()
	var stat_key := str(_catalog.get_stat_key(training_id)).strip_edges()
	if stat_key == "":
		return {"accepted": false, "reason": "missing_stat_key"}
	if is_saturated_from_runtime_state(runtime_state, training_id, registry):
		return {"accepted": false, "reason": "saturated", "stat_key": stat_key}
	var projected_state: Object = PhysiqueTrainingState.new()
	projected_state.restore(_state.get_snapshot(), _catalog)
	var commit_result: Dictionary = projected_state.commit(training_id, _catalog)
	if not bool(commit_result.get("accepted", false)):
		return {
			"accepted": false,
			"reason": str(commit_result.get("reason", "commit_rejected")),
			"stat_key": stat_key,
		}
	var had_previous_override := _bonus_probe_override.has(stat_key)
	var previous_override: Variant = _bonus_probe_override.get(stat_key)
	_bonus_probe_override[stat_key] = float(projected_state.get_bonus(stat_key, _catalog))
	var projection: Variant = projector.call()
	if had_previous_override:
		_bonus_probe_override[stat_key] = previous_override
	else:
		_bonus_probe_override.erase(stat_key)
	return {
		"accepted": true,
		"reason": "projected",
		"training_id": training_id,
		"stat_key": stat_key,
		"projection": projection,
	}


func try_inject_offer_from_runtime_state(
	runtime_state: Object,
	_dice_appeared: bool,
	fusion_appeared: bool = false,
	appearance_roll_unit: float = -1.0,
	selection_roll_unit: float = -1.0,
	replacement_roll_unit: float = -1.0,
	registry: Object = null
) -> Dictionary:
	if runtime_state == null or not PerkConversionFlags.is_enabled():
		return {"rolled": false}
	var current_choices: Array = RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")
	if current_choices.is_empty():
		return {"rolled": false}
	# Fusion owns the screen's one system-replacement budget. This must happen
	# before eligibility metrics and every RNG draw.
	if fusion_appeared:
		return {"rolled": false, "skipped_for_perk_fusion": true}
	var current_choice_context: Dictionary = RuntimePerkRuntimeStateAccess.get_dict(
		runtime_state,
		"current_choice_context"
	)
	var offer_source := str(current_choice_context.get("source", ""))
	var probe_candidates: Array = []
	var probe_replaceable_indices: Array[int] = []
	if not _offer_planner.can_roll(
		current_choices,
		offer_source,
		_state,
		_catalog,
		probe_candidates,
		probe_replaceable_indices,
		runtime_state,
		registry
	):
		return {"rolled": false}
	var metrics: Dictionary = _state.note_eligible_offer_screen(0)
	var appearance_unit := appearance_roll_unit if appearance_roll_unit >= 0.0 else randf()
	# A miss does not consume weighted-selection or replacement RNG streams.
	var selection_unit := 0.0
	var replacement_unit := 0.0
	if appearance_unit < PhysiqueTrainingOfferPlanner.APPEARANCE_CHANCE:
		selection_unit = selection_roll_unit if selection_roll_unit >= 0.0 else randf()
		replacement_unit = replacement_roll_unit if replacement_roll_unit >= 0.0 else randf()
	var result: Dictionary = _offer_planner.plan_offer(
		current_choices,
		offer_source,
		_state,
		_catalog,
		appearance_unit,
		selection_unit,
		replacement_unit,
		runtime_state,
		registry
	)
	if bool(result.get("appeared", false)):
		runtime_state.set("current_choices", result.get("choices", current_choices) as Array)
	if DEBUG_OFFER_LOG:
		print(
			"[PhysiqueTrainingOffer] eligible_total=%d appeared=%s chance=%.2f"
			% [
				int(metrics.get("before_dice_exhaustion", 0))
					+ int(metrics.get("after_dice_exhaustion", 0)),
				str(bool(result.get("appeared", false))),
				PhysiqueTrainingOfferPlanner.APPEARANCE_CHANCE,
			]
		)
	return result


func _probe_consumer_value(
	runtime_state: Object,
	stat_key: String,
	bonus: float,
	registry: Object
) -> Variant:
	_bonus_probe_override[stat_key] = bonus
	var value: Variant = null
	match stat_key:
		"dash_recharge_reduction_pct":
			value = float(SmasherDashState.compute_dash_recharge_frames(runtime_state, registry))
		"dash_recovery_reduction_pct":
			value = float(SmasherDashState.compute_dash_recovery_frames(runtime_state, registry))
		"active_item_cooldown_reduction_pct":
			value = float(ActiveItemCooldownComposer.compose_effective_cooldown_msec(
				PROBE_ACTIVE_ITEM_COOLDOWN_BASE_MSEC,
				runtime_state,
				_get_registry_instance(runtime_state, registry, "mythic_item_runtime")
			))
		"chosik_cooldown_reduction_pct":
			var cooldown_mythic: Object = _get_registry_instance(
				runtime_state,
				registry,
				"mythic_item_runtime"
			)
			var item_multiplier := 1.0
			if (
				cooldown_mythic != null
				and cooldown_mythic.has_method("get_player_skill_cooldown_multiplier")
			):
				item_multiplier = float(cooldown_mythic.get_player_skill_cooldown_multiplier())
			value = CooldownFloorPolicy.floor_final_multiplier(
				RuntimePerkRuntimeStateAccess.call_float(
					runtime_state,
					"get_player_skill_cooldown_multiplier",
					[],
					1.0
				) * item_multiplier
			)
		"posture_correction_pct":
			var mythic: Object = _get_registry_instance(runtime_state, registry, "mythic_item_runtime")
			if mythic != null and mythic.has_method("get_player_posture_correction_pct"):
				value = float(mythic.get_player_posture_correction_pct())
			else:
				value = minf(
					100.0,
					RuntimePerkRuntimeStateAccess.call_float(
						runtime_state,
						"get_converted_perk_option_value",
						["bulletproof_hat", "posture_correction_pct"]
					)
				)
	_bonus_probe_override.erase(stat_key)
	return value


func _get_registry_instance(runtime_state: Object, registry: Object, key: String) -> Object:
	return RuntimePerkRuntimeStateAccess.call_object(
		runtime_state,
		"_get_instance",
		[registry, key]
	)
