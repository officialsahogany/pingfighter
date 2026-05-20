extends RefCounted

const GAUGE_MAX := 500.0
const GAUGE_CHARGE_AMOUNT := 200.0
const LIFE_ELIXIR_GAUGE_AMOUNT := 500.0


func build_gauge_charge_result(
	item_data: Dictionary,
	current_gauge: float,
	owner_gauge_max: float,
	mythic_item_runtime: Object = null
) -> Dictionary:
	var base_gauge_gain: float = float(item_data.get("gauge_gain", GAUGE_CHARGE_AMOUNT))
	var gauge_gain: float = _apply_gold_digger_gauge_bonus(base_gauge_gain, mythic_item_runtime)
	var gauge_max: float = max(1.0, owner_gauge_max)
	var next_gauge: float = min(gauge_max, current_gauge + gauge_gain)
	return {
		"special_gauge": next_gauge,
		"current_gauge": current_gauge,
		"gauge_gain": gauge_gain,
		"base_gauge_gain": base_gauge_gain,
		"applied_gain": next_gauge - current_gauge,
		"gauge_max": gauge_max,
	}


func build_life_elixir_item_data(item_data: Dictionary) -> Dictionary:
	var elixir_data: Dictionary = item_data.duplicate(true)
	elixir_data["gauge_gain"] = float(elixir_data.get("gauge_gain", LIFE_ELIXIR_GAUGE_AMOUNT))
	elixir_data["gauge_max"] = float(elixir_data.get("gauge_max", GAUGE_MAX))
	return elixir_data


func get_item_gauge_max(item_data: Dictionary) -> float:
	return max(1.0, float(item_data.get("gauge_max", GAUGE_MAX)))


func _apply_gold_digger_gauge_bonus(gauge_gain: float, mythic_item_runtime: Object) -> float:
	if mythic_item_runtime != null and mythic_item_runtime.has_method("apply_gold_digger_gauge_bonus"):
		return float(mythic_item_runtime.apply_gold_digger_gauge_bonus(gauge_gain))
	return gauge_gain
