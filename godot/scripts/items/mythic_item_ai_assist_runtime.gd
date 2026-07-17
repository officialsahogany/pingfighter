extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_SMARTPHONE := "smartphone"
const ITEM_NEURAL_HELMET := "neural_helmet"
const NEURAL_HELMET_GAUGE_REDUCTION_CAP := 90.0
const NEURAL_HELMET_SPAWN_CAP_PCT := 2000.0


func is_smartphone_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_SMARTPHONE)


func is_smartphone_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime, ITEM_SMARTPHONE) > 0
	return is_smartphone_equipped(runtime)


func is_smartphone_effect_active(runtime: Object) -> bool:
	return is_smartphone_active(runtime)


func get_smartphone_count(runtime: Object) -> int:
	return runtime.roll_query.count_equipped_item_name(runtime, ITEM_SMARTPHONE)


func clear_smartphone_runtime(runtime: Object) -> void:
	runtime.smartphone_cooldown_frames = 0.0
	runtime.smartphone_last_auto_item = ""


func is_neural_helmet_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_NEURAL_HELMET)


func is_neural_helmet_active(runtime: Object) -> bool:
	return is_neural_helmet_equipped(runtime)


func is_neural_helmet_effect_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime, ITEM_NEURAL_HELMET) > 0
	return is_neural_helmet_equipped(runtime)


func get_neural_helmet_count(runtime: Object) -> int:
	return runtime.roll_query.count_equipped_item_name(runtime, ITEM_NEURAL_HELMET)


func get_neural_helmet_aipill_gauge_reduction(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_NEURAL_HELMET, "aipill_gauge_reduction")
	if not is_neural_helmet_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_NEURAL_HELMET, "aipill_gauge_reduction"),
		0.0,
		NEURAL_HELMET_GAUGE_REDUCTION_CAP
	)


func get_neural_helmet_aipill_spawn_bonus_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_NEURAL_HELMET, "aipill_spawn_bonus_pct")
	if not is_neural_helmet_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_NEURAL_HELMET, "aipill_spawn_bonus_pct"),
		0.0,
		NEURAL_HELMET_SPAWN_CAP_PCT
	)


func get_aipill_gauge_drain(runtime: Object, base_drain: float = 90.0) -> float:
	return max(0.0, float(base_drain) - get_neural_helmet_aipill_gauge_reduction(runtime))


func get_aipill_item_spawn_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_neural_helmet_aipill_spawn_bonus_pct(runtime) / 100.0)


func get_aipill_item_spawn_chance(runtime: Object, base_chance: float) -> float:
	return max(0.0, float(base_chance) * get_aipill_item_spawn_multiplier(runtime))


func should_cancel_aipill_on_direction_key(runtime: Object) -> bool:
	return is_neural_helmet_effect_active(runtime)


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := _get_converted_perk_level(runtime, perk_id)
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level, runtime.runtime_perk_state_ref if runtime != null else null)


func _get_converted_perk_level(runtime: Object, perk_id: String) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	return 0
