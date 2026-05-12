extends RefCounted

const CARD_COUNT := 3
const MYTHIC_RATIO := 0.5
const PASSIVE_RATIO := 0.9


func generate_choices(
	active_pool: Array,
	passive_pool: Array,
	mythic_pool: Array,
	quality_bonus: float,
	active_item_korean_names: Dictionary = {},
	card_count: int = CARD_COUNT
) -> Array:
	var all_candidate_names: Dictionary = {}
	for pool in [active_pool, passive_pool, mythic_pool]:
		for item_value in pool:
			var item_data: Dictionary = _get_dict(item_value)
			var item_name: String = str(item_data.get("name", ""))
			if item_name != "":
				all_candidate_names[item_name] = true
	if all_candidate_names.size() < card_count:
		return []

	var selected: Array = []
	var used_names: Dictionary = {}
	for _i in range(card_count):
		var picked: Dictionary = {}
		if randf() < quality_bonus:
			if randf() < quality_bonus * MYTHIC_RATIO:
				picked = _pick_unique(mythic_pool, used_names, quality_bonus, true)
				if _append_choice(selected, used_names, picked, "mythic", active_item_korean_names):
					continue
			if randf() < PASSIVE_RATIO:
				picked = _pick_unique(passive_pool, used_names, quality_bonus, false)
				if _append_choice(selected, used_names, picked, "passive", active_item_korean_names):
					continue
		picked = _pick_unique(active_pool, used_names, quality_bonus, false)
		if _append_choice(selected, used_names, picked, "active", active_item_korean_names):
			continue
		picked = _pick_unique(passive_pool, used_names, quality_bonus, false)
		if _append_choice(selected, used_names, picked, "passive", active_item_korean_names):
			continue
		picked = _pick_unique(mythic_pool, used_names, quality_bonus, true)
		_append_choice(selected, used_names, picked, "mythic", active_item_korean_names)
	return selected


func _append_choice(
	selected: Array,
	used_names: Dictionary,
	item_data: Dictionary,
	source: String,
	active_item_korean_names: Dictionary
) -> bool:
	if item_data.is_empty():
		return false
	selected.append(_normalize_choice(item_data, source, active_item_korean_names))
	used_names[str(item_data.get("name", ""))] = true
	return true


func _choice_weight(item_data: Dictionary, quality_bonus: float, mythic: bool = false) -> float:
	if mythic:
		return 1.0
	var chance: float = max(float(item_data.get("chance", 0.01)), 0.00001)
	var base_weight: float = sqrt(chance)
	if chance < 0.005:
		return base_weight * (1.0 + quality_bonus * 3.0)
	if chance < 0.01:
		return base_weight * (1.0 + quality_bonus * 2.0)
	return base_weight


func _pick_unique(pool: Array, used_names: Dictionary, quality_bonus: float, mythic: bool = false) -> Dictionary:
	var weighted: Array = []
	var total_weight: float = 0.0
	for item_value in pool:
		var item_data: Dictionary = _get_dict(item_value)
		var item_name: String = str(item_data.get("name", ""))
		if item_name == "" or used_names.has(item_name):
			continue
		var weight: float = _choice_weight(item_data, quality_bonus, mythic)
		if weight <= 0.0:
			continue
		weighted.append({"item": item_data, "weight": weight})
		total_weight += weight
	if total_weight <= 0.0:
		return {}
	var roll: float = randf() * total_weight
	for entry_value in weighted:
		var entry: Dictionary = _get_dict(entry_value)
		roll -= float(entry.get("weight", 0.0))
		if roll <= 0.0:
			return _get_dict(entry.get("item", {})).duplicate(true)
	var fallback_entry: Dictionary = _get_dict(weighted.back())
	return _get_dict(fallback_entry.get("item", {})).duplicate(true)


func _normalize_choice(item_data: Dictionary, source: String, active_item_korean_names: Dictionary) -> Dictionary:
	var result: Dictionary = item_data.duplicate(true)
	result["pandora_source"] = source
	match source:
		"active":
			result["type"] = "active"
			var item_name: String = str(result.get("name", ""))
			if active_item_korean_names.has(item_name):
				result["display_name"] = str(active_item_korean_names[item_name])
				result["korean_name"] = str(active_item_korean_names[item_name])
		"passive":
			result["type"] = "passive"
		"mythic":
			result["type"] = "legendary"
	return result


func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
