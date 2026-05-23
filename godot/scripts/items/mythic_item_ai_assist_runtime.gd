extends RefCounted

const ITEM_SMARTPHONE := "smartphone"
const ITEM_NEURAL_HELMET := "neural_helmet"
const NEURAL_HELMET_GAUGE_REDUCTION_CAP := 90.0
const NEURAL_HELMET_SPAWN_CAP_PCT := 2000.0


func is_smartphone_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_SMARTPHONE)


func is_smartphone_active(runtime: Object) -> bool:
	return is_smartphone_equipped(runtime)


func get_smartphone_count(runtime: Object) -> int:
	return runtime._count_equipped_item_name(ITEM_SMARTPHONE)


func clear_smartphone_runtime(runtime: Object) -> void:
	runtime.smartphone_cooldown_frames = 0.0
	runtime.smartphone_last_auto_item = ""


func is_neural_helmet_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_NEURAL_HELMET)


func is_neural_helmet_active(runtime: Object) -> bool:
	return is_neural_helmet_equipped(runtime)


func get_neural_helmet_count(runtime: Object) -> int:
	return runtime._count_equipped_item_name(ITEM_NEURAL_HELMET)


func get_neural_helmet_aipill_gauge_reduction(runtime: Object) -> float:
	if not is_neural_helmet_equipped(runtime):
		return 0.0
	return clamp(
		runtime._get_equipped_roll_sum(ITEM_NEURAL_HELMET, "aipill_gauge_reduction"),
		0.0,
		NEURAL_HELMET_GAUGE_REDUCTION_CAP
	)


func get_neural_helmet_aipill_spawn_bonus_pct(runtime: Object) -> float:
	if not is_neural_helmet_equipped(runtime):
		return 0.0
	return clamp(
		runtime._get_equipped_roll_sum(ITEM_NEURAL_HELMET, "aipill_spawn_bonus_pct"),
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
	return is_neural_helmet_equipped(runtime)
