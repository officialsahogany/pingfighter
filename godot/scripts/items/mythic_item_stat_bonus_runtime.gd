extends RefCounted

const ITEM_SPEEDBOOTS := "speedboots"
const ITEM_SPEEDGEAR := "speedgear"
const ITEM_GRAVITYBELT := "gravitybelt"
const ITEM_GOLD_BAR := "gold_bar"
const ITEM_DASHGEAR := "dashgear"
const ITEM_BULKUP := "bulkup"
const ITEM_DASHHOLDER := "dashholder"
const SPEEDGEAR_TURN_DECEL_MULTIPLIER := 2.5
const GOLD_BAR_SELL_PRICE := 2000
const GOLD_BAR_SPEED_PENALTY_PCT := 30.0


func is_speedboots_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_SPEEDBOOTS)


func get_speedboots_speed_bonus_pct(runtime: Object) -> float:
	if not runtime.equipped_items.has(ITEM_SPEEDBOOTS):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_SPEEDBOOTS, "speed_bonus_pct"), 0.0, 200.0)


func is_speedgear_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_SPEEDGEAR)


func get_speedgear_turn_decel_multiplier(runtime: Object) -> float:
	if not is_speedgear_equipped(runtime):
		return 1.0
	return max(0.0, SPEEDGEAR_TURN_DECEL_MULTIPLIER)


func get_player_turn_decel_multiplier(runtime: Object) -> float:
	return get_speedgear_turn_decel_multiplier(runtime)


func is_gravitybelt_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_GRAVITYBELT)


func is_gravitybelt_active(runtime: Object) -> bool:
	return is_gravitybelt_equipped(runtime)


func apply_player_movement_config(runtime: Object, config: Dictionary) -> void:
	var active: bool = is_gravitybelt_active(runtime)
	config["gravitybelt_active"] = active
	config["gravitybelt_instant_movement"] = active
	if runtime.is_horn_strawberry_control_locked():
		config["player_skill_input_locked"] = true
		config["horizontal_input_locked"] = true
	elif runtime.is_horn_strawberry_skills_locked():
		config["player_skill_input_locked"] = true
	if runtime.is_odins_eye_control_locked():
		config["player_skill_input_locked"] = true
		config["horizontal_input_locked"] = true
	elif runtime.is_odins_eye_skills_locked():
		config["player_skill_input_locked"] = true
	if runtime.is_horn_strawberry_transformed():
		var move_speed: float = float(runtime.get_horn_strawberry_move_speed())
		config["paddle_speed"] = move_speed
		config["paddle_max_speed"] = move_speed


func get_player_speed_multiplier(runtime: Object, baal_boots_constants: Dictionary) -> float:
	var multiplier: float = max(0.0, 1.0 + get_speedboots_speed_bonus_pct(runtime) / 100.0)
	multiplier *= runtime.get_hermes_shoes_speed_multiplier()
	multiplier *= get_gold_bar_speed_multiplier(runtime)
	multiplier *= runtime.get_sage_ring_speed_multiplier()
	multiplier *= runtime.baal_boots_runtime.get_player_speed_multiplier(runtime, baal_boots_constants)
	multiplier *= runtime.get_odins_eye_move_speed_multiplier()
	return max(0.0, multiplier)


func is_bulkup_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_BULKUP)


func get_bulkup_body_size_pct(runtime: Object) -> float:
	if not is_bulkup_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_BULKUP, "body_size_pct"), 0.0, 500.0)


func get_player_paddle_scale(runtime: Object) -> float:
	var equipment_scale: float = max(
		0.1,
		1.0
		+ get_bulkup_body_size_pct(runtime) / 100.0
		- runtime.get_sage_ring_body_penalty_pct() / 100.0
	)
	var horn_strawberry_scale: float = 1.0 + max(0.0, runtime.get_horn_strawberry_paddle_size_bonus_pct())
	return max(0.1, equipment_scale * horn_strawberry_scale)


func get_player_paddle_width(runtime: Object, base_width: float) -> float:
	return max(1.0, float(base_width) * get_player_paddle_scale(runtime))


func get_player_paddle_height(runtime: Object, base_height: float) -> float:
	return max(1.0, float(base_height) * get_player_paddle_scale(runtime))


func is_gold_bar_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_GOLD_BAR)


func is_gold_bar_owned(runtime: Object) -> bool:
	return get_gold_bar_count(runtime) > 0


func is_gold_bar_active(runtime: Object) -> bool:
	return is_gold_bar_owned(runtime)


func get_gold_bar_count(runtime: Object) -> int:
	return runtime.roll_query.count_owned_item_name(runtime, ITEM_GOLD_BAR)


func get_gold_bar_sell_price(runtime: Object) -> int:
	return GOLD_BAR_SELL_PRICE if is_gold_bar_active(runtime) else 0


func get_gold_bar_total_sell_price(runtime: Object) -> int:
	return get_gold_bar_count(runtime) * GOLD_BAR_SELL_PRICE


func get_gold_bar_speed_penalty_pct(runtime: Object) -> float:
	return GOLD_BAR_SPEED_PENALTY_PCT if is_gold_bar_active(runtime) else 0.0


func get_gold_bar_speed_multiplier(runtime: Object) -> float:
	if not is_gold_bar_active(runtime):
		return 1.0
	return max(0.0, 1.0 - GOLD_BAR_SPEED_PENALTY_PCT / 100.0)


func is_dashgear_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_DASHGEAR)


func get_dashgear_dash_distance_bonus_pct(runtime: Object) -> float:
	if not runtime.equipped_items.has(ITEM_DASHGEAR):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_DASHGEAR, "dash_distance_pct"), 0.0, 200.0)


func get_dashgear_boost_charge_chance_pct(runtime: Object) -> float:
	if not runtime.equipped_items.has(ITEM_DASHGEAR):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_DASHGEAR, "boost_charge_pct"), 0.0, 100.0)


func get_dash_duration_frames(runtime: Object, base_frames: float) -> float:
	return max(1.0, float(base_frames) * (1.0 + get_dashgear_dash_distance_bonus_pct(runtime) / 100.0))


func get_boost_charge_chance_pct(runtime: Object) -> float:
	return max(0.0, get_dashgear_boost_charge_chance_pct(runtime))


func is_dashholder_equipped(runtime: Object) -> bool:
	return get_dashholder_dash_token_bonus(runtime) > 0


func get_dashholder_dash_token_bonus(runtime: Object) -> int:
	return max(0, runtime.roll_query.count_equipped_item_name(runtime, ITEM_DASHHOLDER))


func get_dash_token_capacity(
	runtime: Object,
	base_tokens: int = 1,
	runtime_perk_state: Object = null
) -> int:
	var odins_limit: Variant = runtime.get_odins_eye_dash_token_limit_override()
	if odins_limit != null:
		return max(1, int(odins_limit))
	var capacity: int = max(1, int(base_tokens)) + get_dashholder_dash_token_bonus(runtime)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_bonus"):
		capacity += int(runtime_perk_state.get_runtime_skill_bonus("dash_amplification"))
	return max(1, capacity)
