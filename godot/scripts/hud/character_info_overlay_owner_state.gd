extends RefCounted


static func get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


static func owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


static func owner_dict(owner: Object, key: String) -> Dictionary:
	var value: Variant = owner_value(owner, key, {})
	return value if value is Dictionary else {}


static func prewarm_instance(registry: Object, module_getter: Callable, key: String) -> Object:
	var registry_instance: Object = get_instance(registry, key)
	if registry_instance != null:
		return registry_instance
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


static func skill_config_key(character_type: String, character_runtime: Object) -> String:
	var key := "smasher_skill_config"
	if character_runtime != null and character_runtime.has_method("get_skill_config_key"):
		key = str(character_runtime.get_skill_config_key(character_type))
	elif character_type == "viper":
		key = "viper_skill_config"
	elif character_type == "soldier":
		key = "commando_skill_config"
	return key


static func skill_config(registry: Object, character_type: String, character_runtime: Object) -> Object:
	return get_instance(registry, skill_config_key(character_type, character_runtime))


static func prewarm_skill_config(registry: Object, module_getter: Callable, character_type: String, character_runtime: Object) -> Object:
	var config: Object = skill_config(registry, character_type, character_runtime)
	return config if config != null else prewarm_instance(registry, module_getter, skill_config_key(character_type, character_runtime))


static func normalize_character_type(value: Variant, character_runtime: Object) -> String:
	if character_runtime != null and character_runtime.has_method("normalize"):
		return str(character_runtime.normalize(value))
	var normalized := str(value).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	return "smasher"


static func character_type_from_owner(owner: Object, character_runtime: Object) -> String:
	return normalize_character_type(owner_value(owner, "selected_character_type", "smasher"), character_runtime)


static func character_display_name(raw_name: String, character_type: String) -> String:
	if raw_name != "" and raw_name.find("?") < 0:
		return raw_name
	if character_type == "viper":
		return "바이퍼"
	if character_type == "soldier":
		return "코만도"
	return "스매셔"


static func character_display_name_from_owner(owner: Object, character_type: String) -> String:
	return character_display_name(str(owner_value(owner, "selected_character_name", "")), character_type)


static func equipment_state(direct: Dictionary, passive_slots: Dictionary, equipped_passives: Dictionary) -> Dictionary:
	if not direct.is_empty():
		return direct
	if not passive_slots.is_empty():
		return passive_slots
	if not equipped_passives.is_empty():
		return equipped_passives
	return {}


static func equipment_state_from_owner(owner: Object) -> Dictionary:
	return equipment_state(
		owner_dict(owner, "equipment_slots"),
		owner_dict(owner, "passive_item_slots"),
		owner_dict(owner, "equipped_passive_items")
	)


static func equipment_item_or_empty(slot_state: Dictionary, slot_key: String, empty_equipment_item: Dictionary) -> Dictionary:
	var value: Variant = slot_state.get(slot_key, null)
	if value is Dictionary:
		return value
	if value is Array:
		var items: Array = value
		if not items.is_empty() and items[0] is Dictionary:
			return items[0]
	return empty_equipment_item


static func equipment_slot_accessory_number(slot_key: String) -> int:
	if not slot_key.begins_with("accessory"):
		return 0
	return int(slot_key.substr("accessory".length(), 1))


static func accessory_slot_count(explicit_count: int, runtime_bonus: int, levels: Dictionary, base_count: int) -> int:
	if explicit_count > 0:
		return clamp(explicit_count, 1, 4)
	runtime_bonus = max(runtime_bonus, int(levels.get("common_expansion", 0)))
	return clamp(base_count + runtime_bonus, 1, 4)


static func accessory_slot_count_from_owner(owner: Object, base_count: int) -> int:
	return accessory_slot_count(
		int(owner_value(owner, "accessory_slot_count", 0)),
		int(owner_value(owner, "runtime_accessory_slot_bonus", 0)),
		owner_dict(owner, "runtime_perk_levels"),
		base_count
	)


static func active_item_slot_capacity(runtime_perk_state: Object, mythic_item_runtime: Object, base_count: int) -> int:
	var capacity := base_count
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_slot_capacity"):
		capacity = int(runtime_perk_state.get_active_item_slot_capacity(capacity))
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_active_item_slot_capacity"):
		capacity = int(mythic_item_runtime.get_active_item_slot_capacity(capacity))
	return max(1, capacity)


static func stat_sources(registry: Object) -> Array:
	return [
		get_instance(registry, "runtime_perk_state"),
		get_instance(registry, "active_item_runtime"),
		get_instance(registry, "mythic_item_runtime"),
		get_instance(registry, "lingpet_egg_runtime"),
	]


static func active_item_slot_capacity_from_registry(registry: Object, base_count: int) -> int:
	return active_item_slot_capacity(
		get_instance(registry, "runtime_perk_state"),
		get_instance(registry, "mythic_item_runtime"),
		base_count
	)


static func active_item_slot_count(active_item_slots_override: Variant, active_item_slots: Array) -> int:
	if active_item_slots_override is Array:
		return (active_item_slots_override as Array).size()
	return active_item_slots.size()


static func active_item_slot_count_from_owner(owner: Object, active_item_slots_override: Variant) -> int:
	var active_item_slots: Variant = owner_value(owner, "active_item_slots", [])
	return active_item_slot_count(active_item_slots_override, active_item_slots if active_item_slots is Array else [])


static func smasher_dash_snapshot(registry: Object) -> Dictionary:
	var dash_state: Object = get_instance(registry, "smasher_dash_state")
	return dash_state.get_snapshot() if dash_state != null and dash_state.has_method("get_snapshot") else {}


static func active_item_cooldown_from_base(base_cooldown_msec: int, sources: Array, stat_chain_callable: Callable) -> int:
	return max(0, int(round(stat_chain_callable.call(
		float(base_cooldown_msec),
		sources,
		"get_active_item_cooldown_msec"
	))))


static func passive_item_roll_polish_multiplier(registry: Object, runtime_state_override: Object) -> float:
	var runtime_state: Object = runtime_state_override
	if runtime_state == null:
		runtime_state = get_instance(registry, "runtime_perk_state")
	return float(runtime_state.get_effective_polish_multiplier()) if runtime_state != null and runtime_state.has_method("get_effective_polish_multiplier") else 1.0


static func apply_stat_chain(base_value: float, sources: Array, method_name: String) -> float:
	var current: float = base_value
	for source_value in sources:
		if not (source_value is Object):
			continue
		var source: Object = source_value
		if source == null or not source.has_method(method_name):
			continue
		var result: Variant = source.call(method_name, current)
		if result is int or result is float:
			current = float(result)
	return current


static func call_numeric_multiplier(source: Object, method_name: String) -> float:
	if source == null or not source.has_method(method_name):
		return 1.0
	var result: Variant = source.call(method_name)
	if result is int or result is float:
		return max(0.0, float(result))
	return 1.0
