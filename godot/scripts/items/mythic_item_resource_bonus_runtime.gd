extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_FUEL_POUCH := "fuel_pouch"
const ITEM_BLUETOOTH_RING := "bluetooth_ring"
const ITEM_STAR_DETECTOR := "star_detector"
const ITEM_GOLD_DIGGER := "gold_digger"
const ITEM_LUCKY_COIN := "lucky_coin"


func is_fuel_pouch_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_FUEL_POUCH)


func get_fuel_pouch_gauge_bonus(
	runtime: Object,
	runtime_perk_state_override: Object = null
) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(
			runtime,
			ITEM_FUEL_POUCH,
			"fuel_bonus_flat",
			runtime_perk_state_override
		)
	if not is_fuel_pouch_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_FUEL_POUCH, "fuel_bonus_flat"), 0.0, 1000.0)


func get_effective_special_gauge_max(
	runtime: Object,
	base_max: float,
	runtime_perk_state_override: Object = null
) -> float:
	return max(
		1.0,
		float(base_max) + get_fuel_pouch_gauge_bonus(runtime, runtime_perk_state_override)
	)


func is_bluetooth_ring_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_BLUETOOTH_RING)


func is_bluetooth_ring_active(runtime: Object) -> bool:
	return is_bluetooth_ring_equipped(runtime)


func get_bluetooth_ring_gauge_gain_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_BLUETOOTH_RING, "gauge_gain_pct")
	if not is_bluetooth_ring_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_BLUETOOTH_RING, "gauge_gain_pct"), 0.0, 500.0)


func get_bluetooth_ring_gauge_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_bluetooth_ring_gauge_gain_pct(runtime) / 100.0)


func calculate_bluetooth_ring_gauge_charge(runtime: Object, base_charge: float) -> float:
	var gain_pct: float = get_bluetooth_ring_gauge_gain_pct(runtime)
	if gain_pct <= 0.0:
		return float(base_charge)
	return floor(max(0.0, float(base_charge)) * max(0.0, 1.0 + gain_pct / 100.0))


func is_star_detector_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_STAR_DETECTOR)


func is_star_detector_active(runtime: Object) -> bool:
	return is_star_detector_equipped(runtime)


func get_star_detector_star_bonus_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_STAR_DETECTOR, "star_bonus_pct")
	if not is_star_detector_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_STAR_DETECTOR, "star_bonus_pct"), 0.0, 100.0)


func get_star_detector_bonus_chance(runtime: Object) -> float:
	return get_star_detector_star_bonus_pct(runtime) / 100.0


func roll_star_detector_bonus_drop_count(runtime: Object) -> int:
	var chance: float = get_star_detector_bonus_chance(runtime)
	if chance <= 0.0:
		return 0
	return 1 if randf() < chance else 0


func is_gold_digger_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_GOLD_DIGGER)


func get_gold_digger_count(runtime: Object) -> int:
	return runtime.roll_query.count_equipped_item_name(runtime, ITEM_GOLD_DIGGER)


func get_gold_digger_gold_bonus_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_GOLD_DIGGER, "gold_bonus_pct")
	if not is_gold_digger_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_GOLD_DIGGER, "gold_bonus_pct"), 0.0, 2000.0)


func get_gold_digger_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_gold_digger_gold_bonus_pct(runtime) / 100.0)


func apply_gold_digger_gold_bonus(runtime: Object, amount: int) -> int:
	var bonus_pct: float = get_gold_digger_gold_bonus_pct(runtime)
	if bonus_pct <= 0.0:
		return max(0, amount)
	return int(floor(float(max(0, amount)) * max(0.0, 1.0 + bonus_pct / 100.0)))


func is_lucky_coin_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_LUCKY_COIN)


func is_lucky_coin_active(runtime: Object) -> bool:
	return is_lucky_coin_equipped(runtime)


func get_lucky_coin_double_spawn_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_LUCKY_COIN, "double_spawn_pct")
	if not is_lucky_coin_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_LUCKY_COIN, "double_spawn_pct"), 0.0, 100.0)


func get_lucky_coin_double_spawn_chance(runtime: Object) -> float:
	return get_lucky_coin_double_spawn_pct(runtime) / 100.0


func should_lucky_coin_double_spawn(runtime: Object) -> bool:
	var chance: float = get_lucky_coin_double_spawn_chance(runtime)
	return chance > 0.0 and randf() < chance


func _get_converted_perk_value(
	runtime: Object,
	perk_id: String,
	key: String,
	runtime_perk_state_override: Object = null
) -> float:
	var runtime_state: Object = runtime_perk_state_override
	if runtime_state == null or not is_instance_valid(runtime_state):
		runtime_state = runtime.runtime_perk_state_ref if runtime != null else null
	if runtime_state != null and runtime_state.has_method("get_converted_perk_option_value"):
		return float(runtime_state.get_converted_perk_option_value(perk_id, key))
	var level := 0
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		level = max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level, runtime_state)
