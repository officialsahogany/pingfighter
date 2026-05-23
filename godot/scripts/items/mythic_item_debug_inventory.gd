extends RefCounted


func debug_toggle_megingjord(runtime: Object, owner: Object, registry: Object, constants: Dictionary) -> bool:
	var item_megingjord: String = str(constants.get("item_megingjord", "megingjord"))
	var index: int = runtime._find_inventory_index_by_name(item_megingjord)
	if index < 0:
		return runtime.acquire_item(item_megingjord, owner, registry, {}, true, true) >= 0
	return runtime.toggle_inventory_item(index, owner, registry)


func debug_toggle_item(runtime: Object, item_name: String, owner: Object, registry: Object) -> bool:
	if item_name == "":
		return false
	var index: int = runtime._find_inventory_index_by_name(item_name)
	if index < 0:
		return runtime.acquire_item(item_name, owner, registry, {}, true, true) >= 0
	return runtime.toggle_inventory_item(index, owner, registry)


func debug_add_item_to_inventory(
	runtime: Object,
	item_name: String,
	owner: Object,
	registry: Object,
	roll_overrides: Dictionary = {}
) -> bool:
	if item_name == "":
		return false
	return runtime.acquire_item(item_name, owner, registry, roll_overrides, true, true) >= 0


func debug_build_roll_editor_item(runtime: Object, item_name: String, roll_overrides: Dictionary = {}) -> Dictionary:
	if item_name == "":
		return {}
	var item_data: Dictionary = runtime.catalog.build_item_by_name(item_name)
	if item_data.is_empty():
		return {}
	var rolls: Dictionary = runtime._get_dict(item_data.get("rolls", {})).duplicate(true)
	if rolls.is_empty():
		rolls = runtime.catalog.build_default_rolls(item_name)
	for key in roll_overrides.keys():
		rolls[str(key)] = roll_overrides[key]
	item_data["rolls"] = rolls
	return runtime.catalog.sync_roll_fields(item_data, false, true)


func get_debug_item_counts(runtime: Object) -> Dictionary:
	var counts: Dictionary = {}
	for item_value in runtime.inventory_items:
		var item_data: Dictionary = runtime._get_dict(item_value)
		var item_name: String = str(item_data.get("name", ""))
		if item_name == "":
			continue
		counts[item_name] = int(counts.get(item_name, 0)) + 1
	return counts


func debug_ensure_item_for_roll_editor(runtime: Object, item_name: String, owner: Object, registry: Object) -> int:
	if item_name == "":
		return -1
	var index: int = runtime._find_inventory_index_by_name(item_name)
	if index >= 0:
		return index
	return runtime.acquire_item(item_name, owner, registry, {}, true, true)


func debug_get_inventory_item(runtime: Object, index: int) -> Dictionary:
	return runtime.get_inventory_item(index)


func debug_adjust_inventory_roll(
	runtime: Object,
	index: int,
	option_key: String,
	delta_steps: int,
	owner: Object,
	registry: Object,
	constants: Dictionary,
	baal_boots_constants: Dictionary
) -> bool:
	if index < 0 or index >= runtime.inventory_items.size() or option_key == "" or delta_steps == 0:
		return false
	var item_data: Dictionary = runtime._get_dict(runtime.inventory_items[index]).duplicate(true)
	if item_data.is_empty():
		return false
	var option: Dictionary = runtime.roll_query.find_roll_option(runtime, item_data, option_key)
	if option.is_empty():
		return false

	var minimum: float = float(option.get("min", option.get("default", 0.0)))
	var maximum: float = float(option.get("max", minimum))
	if maximum < minimum:
		var tmp: float = minimum
		minimum = maximum
		maximum = tmp
	var step: float = max(0.0001, float(option.get("step", 1.0)))
	var rolls: Dictionary = runtime._get_dict(item_data.get("rolls", {})).duplicate(true)
	var current: float = float(rolls.get(option_key, option.get("value", option.get("default", minimum))))
	var next_value: float = clamp(current + step * float(delta_steps), minimum, maximum)
	next_value = minimum + round((next_value - minimum) / step) * step
	next_value = clamp(next_value, minimum, maximum)
	if step >= 1.0:
		next_value = round(next_value)
	if is_equal_approx(current, next_value):
		return false

	rolls[option_key] = next_value
	item_data["rolls"] = rolls
	item_data = runtime.catalog.sync_roll_fields(item_data, false, true)
	runtime.inventory_items[index] = item_data
	runtime._rebuild_equipped_items()
	_reset_item_runtime_after_roll_adjustment(runtime, item_data, owner, registry, constants, baal_boots_constants)
	return true


func get_debug_item_entries(runtime: Object) -> Array:
	if runtime.catalog != null and runtime.catalog.has_method("get_debug_items"):
		return runtime.catalog.get_debug_items()
	return []


func _reset_item_runtime_after_roll_adjustment(
	runtime: Object,
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	constants: Dictionary,
	baal_boots_constants: Dictionary
) -> void:
	var item_name: String = str(item_data.get("name", ""))
	if item_name == str(constants.get("item_megingjord", "megingjord")):
		runtime.megingjord_extra_pick_count = 0
	if item_name == str(constants.get("item_dowsing_goggles", "dowsing_goggles")):
		runtime.dowsing_goggles_bonus_triggered = false
	if item_name == str(constants.get("item_ragnarok_hammer", "ragnarok_hammer")):
		runtime.ragnarok_runtime.clear_runtime(runtime, null)
	if item_name == str(constants.get("item_poseidon_trident", "poseidon_trident")):
		runtime.poseidon_runtime.clear_runtime(runtime)
	if item_name == str(constants.get("item_celestial_armor", "celestial_armor")):
		runtime.celestial_armor_runtime.clear_round_state(runtime)
	if item_name == str(constants.get("item_hermes_shoes", "hermes_shoes")):
		runtime.hermes_shoes_runtime.clear_round_state(runtime)
	if item_name == str(constants.get("item_baal_boots", "baal_boots")):
		runtime.baal_boots_runtime.clear_round_state(runtime, registry, baal_boots_constants)
		runtime.baal_boots_runtime.try_arm_from_weather(runtime, owner, registry, "", baal_boots_constants)
	runtime._sync_owner(owner, registry)
