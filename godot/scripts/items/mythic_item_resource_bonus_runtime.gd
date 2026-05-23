extends RefCounted

const ITEM_FUEL_POUCH := "fuel_pouch"
const ITEM_BLUETOOTH_RING := "bluetooth_ring"
const ITEM_STAR_DETECTOR := "star_detector"
const ITEM_GOLD_DIGGER := "gold_digger"
const ITEM_LUCKY_COIN := "lucky_coin"


func is_fuel_pouch_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_FUEL_POUCH)


func get_fuel_pouch_gauge_bonus(runtime: Object) -> float:
	if not is_fuel_pouch_equipped(runtime):
		return 0.0
	return clamp(runtime._get_equipped_roll_sum(ITEM_FUEL_POUCH, "fuel_bonus_flat"), 0.0, 1000.0)


func get_effective_special_gauge_max(
	runtime: Object,
	base_max: float
) -> float:
	return max(1.0, float(base_max) + get_fuel_pouch_gauge_bonus(runtime))


func is_bluetooth_ring_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_BLUETOOTH_RING)


func is_bluetooth_ring_active(runtime: Object) -> bool:
	return is_bluetooth_ring_equipped(runtime)


func get_bluetooth_ring_gauge_gain_pct(runtime: Object) -> float:
	if not is_bluetooth_ring_equipped(runtime):
		return 0.0
	return clamp(runtime._get_equipped_roll_sum(ITEM_BLUETOOTH_RING, "gauge_gain_pct"), 0.0, 500.0)


func get_bluetooth_ring_gauge_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_bluetooth_ring_gauge_gain_pct(runtime) / 100.0)


func calculate_bluetooth_ring_gauge_charge(runtime: Object, base_charge: float) -> float:
	if not is_bluetooth_ring_equipped(runtime):
		return float(base_charge)
	return floor(max(0.0, float(base_charge)) * get_bluetooth_ring_gauge_multiplier(runtime))


func is_star_detector_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_STAR_DETECTOR)


func is_star_detector_active(runtime: Object) -> bool:
	return is_star_detector_equipped(runtime)


func get_star_detector_star_bonus_pct(runtime: Object) -> float:
	if not is_star_detector_equipped(runtime):
		return 0.0
	return clamp(runtime._get_equipped_roll_sum(ITEM_STAR_DETECTOR, "star_bonus_pct"), 0.0, 100.0)


func get_star_detector_bonus_chance(runtime: Object) -> float:
	return get_star_detector_star_bonus_pct(runtime) / 100.0


func roll_star_detector_bonus_drop_count(runtime: Object) -> int:
	var chance: float = get_star_detector_bonus_chance(runtime)
	if chance <= 0.0:
		return 0
	return 1 if randf() < chance else 0


func is_gold_digger_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_GOLD_DIGGER)


func get_gold_digger_count(runtime: Object) -> int:
	return runtime._count_equipped_item_name(ITEM_GOLD_DIGGER)


func get_gold_digger_gold_bonus_pct(runtime: Object) -> float:
	if not is_gold_digger_equipped(runtime):
		return 0.0
	return clamp(runtime._get_equipped_roll_sum(ITEM_GOLD_DIGGER, "gold_bonus_pct"), 0.0, 2000.0)


func get_gold_digger_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_gold_digger_gold_bonus_pct(runtime) / 100.0)


func apply_gold_digger_gauge_bonus(runtime: Object, gauge_gain: float) -> float:
	if not is_gold_digger_equipped(runtime):
		return float(gauge_gain)
	return floor(max(0.0, float(gauge_gain)) * get_gold_digger_multiplier(runtime))


func apply_gold_digger_gold_bonus(runtime: Object, amount: int) -> int:
	if not is_gold_digger_equipped(runtime):
		return max(0, amount)
	return int(floor(float(max(0, amount)) * get_gold_digger_multiplier(runtime)))


func is_lucky_coin_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_LUCKY_COIN)


func is_lucky_coin_active(runtime: Object) -> bool:
	return is_lucky_coin_equipped(runtime)


func get_lucky_coin_double_spawn_pct(runtime: Object) -> float:
	if not is_lucky_coin_equipped(runtime):
		return 0.0
	return clamp(runtime._get_equipped_roll_sum(ITEM_LUCKY_COIN, "double_spawn_pct"), 0.0, 100.0)


func get_lucky_coin_double_spawn_chance(runtime: Object) -> float:
	return get_lucky_coin_double_spawn_pct(runtime) / 100.0


func should_lucky_coin_double_spawn(runtime: Object) -> bool:
	var chance: float = get_lucky_coin_double_spawn_chance(runtime)
	return chance > 0.0 and randf() < chance
