extends RefCounted

const PassiveItemQuality := preload("res://scripts/items/passive_item_quality.gd")

const MythicItemCatalogRollDefinitions := preload("res://scripts/items/mythic_item_catalog_roll_definitions.gd")


func get_roll_options(item_name: String) -> Array:
	return MythicItemCatalogRollDefinitions.get_roll_options(item_name)


func build_default_rolls(catalog: Object, item_name: String) -> Dictionary:
	return _build_rolls(catalog, item_name, false)


func build_random_rolls(catalog: Object, item_name: String) -> Dictionary:
	return _build_rolls(catalog, item_name, true)


func build_rolled_options(catalog: Object, item_name: String, rolls: Dictionary) -> Array:
	var result: Array = []
	for option_value in catalog.get_roll_options(item_name):
		var option: Dictionary = option_value
		var key: String = str(option.get("key", ""))
		if key == "":
			continue
		var entry: Dictionary = option.duplicate(true)
		entry["value"] = float(rolls.get(key, option.get("default", option.get("min", 0.0))))
		entry = PassiveItemQuality.decorate_roll_option(entry)
		result.append(entry)
	return result


func sync_roll_fields(
	catalog: Object,
	item_data: Dictionary,
	randomize_missing: bool = false,
	force_quality: bool = false
) -> Dictionary:
	var result: Dictionary = item_data.duplicate(true)
	var item_name: String = str(result.get("name", ""))
	var roll_options: Array = catalog.get_roll_options(item_name)
	result["roll_options"] = roll_options
	var rolls: Dictionary = _get_dict(result.get("rolls", {})).duplicate(true)
	if rolls.is_empty() and not roll_options.is_empty():
		rolls = _build_rolls(catalog, item_name, randomize_missing)
	else:
		for option_value in roll_options:
			var option: Dictionary = option_value
			var key: String = str(option.get("key", ""))
			if key == "":
				continue
			if not rolls.has(key):
				rolls[key] = (
					_roll_option_value(option)
					if randomize_missing
					else float(option.get("default", option.get("min", 0.0)))
				)
	result["rolls"] = rolls
	result["rolled_options"] = build_rolled_options(catalog, item_name, rolls)
	result = PassiveItemQuality.assign_item_prefix(result, force_quality)
	return result


func get_default_roll_value(catalog: Object, item_name: String, option_key: String) -> float:
	for option_value in catalog.get_roll_options(item_name):
		var option: Dictionary = option_value
		if str(option.get("key", "")) == option_key:
			return float(option.get("default", option.get("min", 0.0)))
	return 0.0


func _build_rolls(catalog: Object, item_name: String, use_random_values: bool) -> Dictionary:
	var rolls: Dictionary = {}
	for option_value in catalog.get_roll_options(item_name):
		var option: Dictionary = option_value
		var key: String = str(option.get("key", ""))
		if key == "":
			continue
		rolls[key] = (
			_roll_option_value(option)
			if use_random_values
			else float(option.get("default", option.get("min", 0.0)))
		)
	return rolls


func _roll_option_value(option: Dictionary) -> float:
	var minimum: float = float(option.get("min", 0.0))
	var maximum: float = float(option.get("max", minimum))
	if maximum <= minimum:
		return minimum
	var step: float = max(0.0001, float(option.get("step", 1.0)))
	var step_count: int = max(0, int(floor((maximum - minimum) / step + 0.0001)))
	var value: float = minimum + float(randi() % (step_count + 1)) * step
	if step >= 1.0:
		value = round(value)
	return clamp(value, minimum, maximum)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
