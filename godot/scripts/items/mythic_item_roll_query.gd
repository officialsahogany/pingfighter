extends RefCounted

const ITEM_COMMANDO_ARM := "commando_arm"
const COMMANDO_ARM_MAX_STACKS := 2

func get_commando_arm_roll_sum(runtime: Object, option_key: String) -> float:
	var total := 0.0
	for value in get_commando_arm_roll_values(runtime, option_key):
		total += float(value)
	return total


func get_commando_arm_roll_values(runtime: Object, option_key: String) -> Array:
	return get_equipped_roll_values(runtime, ITEM_COMMANDO_ARM, option_key, COMMANDO_ARM_MAX_STACKS)


func get_equipped_roll_values(runtime: Object, item_name: String, option_key: String, limit: int = -1) -> Array:
	var values: Array = []
	for item_value in runtime.inventory_items:
		var item_data: Dictionary = runtime._get_dict(item_value)
		if item_data.is_empty():
			continue
		if str(item_data.get("name", "")) != item_name:
			continue
		if not bool(item_data.get("equipped", false)) and str(item_data.get("_equipped_slot", "")) == "":
			continue
		values.append(get_item_roll_value(runtime, item_data, item_name, option_key))
		if limit > 0 and values.size() >= limit:
			break
	return values


func get_equipped_roll_value(runtime: Object, item_name: String, option_key: String) -> float:
	if not runtime.equipped_items.has(item_name):
		return 0.0
	var item_data: Dictionary = runtime._get_dict(runtime.equipped_items[item_name])
	return get_item_roll_value(runtime, item_data, item_name, option_key)


func get_public_item_roll_value(
	runtime: Object,
	item_data: Dictionary,
	option_key: String,
	apply_polish: bool = true,
	registry: Object = null
) -> float:
	runtime._sync_runtime_perk_state_ref(registry)
	var item_name: String = str(item_data.get("name", item_data.get("effect", "")))
	if item_name == "":
		return 0.0
	return get_item_roll_value(runtime, item_data, item_name, option_key, apply_polish)


func get_item_roll_value(
	runtime: Object,
	item_data: Dictionary,
	item_name: String,
	option_key: String,
	apply_polish: bool = true
) -> float:
	var rolls: Dictionary = runtime._get_dict(item_data.get("rolls", {}))
	var default_value: float = runtime.catalog.get_default_roll_value(item_name, option_key)
	var value: float = float(rolls.get(option_key, default_value))
	var total_multiplier := 1.0
	if apply_polish:
		total_multiplier *= runtime._get_polish_multiplier(item_name)
	var enhancement_bonus_pct: float = max(0.0, float(item_data.get("enhancement_bonus_pct", 0.0)))
	if enhancement_bonus_pct > 0.0:
		total_multiplier *= 1.0 + enhancement_bonus_pct / 100.0
	if total_multiplier > 0.0 and not is_equal_approx(total_multiplier, 1.0):
		var option: Dictionary = find_catalog_roll_option(runtime, item_name, option_key)
		if bool(option.get("reverse", false)):
			value /= total_multiplier
		else:
			value *= total_multiplier
	return value


func get_equipped_roll_sum(runtime: Object, item_name: String, option_key: String) -> float:
	var total := 0.0
	for item_value in runtime.inventory_items:
		var item_data: Dictionary = runtime._get_dict(item_value)
		if item_data.is_empty():
			continue
		if str(item_data.get("name", "")) != item_name:
			continue
		if not bool(item_data.get("equipped", false)) and str(item_data.get("_equipped_slot", "")) == "":
			continue
		total += get_item_roll_value(runtime, item_data, item_name, option_key)
	return total


func get_equipped_roll_max(runtime: Object, item_name: String, option_key: String) -> float:
	var best := 0.0
	for item_value in runtime.inventory_items:
		var item_data: Dictionary = runtime._get_dict(item_value)
		if item_data.is_empty():
			continue
		if str(item_data.get("name", "")) != item_name:
			continue
		if not bool(item_data.get("equipped", false)) and str(item_data.get("_equipped_slot", "")) == "":
			continue
		best = max(best, get_item_roll_value(runtime, item_data, item_name, option_key))
	return best


func has_equipped_item_name(runtime: Object, item_name: String) -> bool:
	return count_equipped_item_name(runtime, item_name) > 0


func count_equipped_item_name(runtime: Object, item_name: String) -> int:
	var count := 0
	for item_value in runtime.inventory_items:
		var item_data: Dictionary = runtime._get_dict(item_value)
		if str(item_data.get("name", "")) != item_name:
			continue
		if bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != "":
			count += 1
	return count


func count_owned_item_name(runtime: Object, item_name: String) -> int:
	var count := 0
	for item_value in runtime.inventory_items:
		var item_data: Dictionary = runtime._get_dict(item_value)
		if str(item_data.get("name", "")) == item_name:
			count += 1
	return count


func find_catalog_roll_option(runtime: Object, item_name: String, option_key: String) -> Dictionary:
	for option_value in runtime.catalog.get_roll_options(item_name):
		var option: Dictionary = runtime._get_dict(option_value)
		if str(option.get("key", "")) == option_key:
			return option
	return {}


func apply_roll_overrides(runtime: Object, index: int, roll_overrides: Dictionary) -> void:
	if index < 0 or index >= runtime.inventory_items.size() or roll_overrides.is_empty():
		return
	var item_data: Dictionary = runtime._get_dict(runtime.inventory_items[index])
	if item_data.is_empty():
		return
	var item_rolls: Dictionary = runtime._get_dict(item_data.get("rolls", {})).duplicate(true)
	for key in roll_overrides.keys():
		item_rolls[str(key)] = roll_overrides[key]
	item_data["rolls"] = item_rolls
	item_data = runtime.catalog.sync_roll_fields(item_data, false, true)
	runtime.inventory_items[index] = item_data


func has_acquired_quality_identity(item_data: Dictionary) -> bool:
	return item_data.has("name_prefix") and str(item_data.get("quality_tier", "")) != ""


func copy_acquired_quality_identity(target: Dictionary, source: Dictionary) -> Dictionary:
	var result: Dictionary = target.duplicate(true)
	for key in ["name_prefix", "quality_tier", "quality_color", "qualified_display_name"]:
		if source.has(key):
			result[key] = source[key]
	return result


func find_roll_option(runtime: Object, item_data: Dictionary, option_key: String) -> Dictionary:
	var options: Array = runtime._get_array(item_data.get("roll_options", []))
	for option_value in options:
		var option: Dictionary = runtime._get_dict(option_value)
		if str(option.get("key", "")) == option_key:
			return option
	return {}
