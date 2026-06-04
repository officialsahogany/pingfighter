extends RefCounted


static func prewarm_active_item_text(
	font: Font,
	active_item_catalog: Object,
	field_spawn_order: Array,
	extra_item_names: Array,
	text_size_callable: Callable,
	trim_label_callable: Callable,
	prewarm_text_block_callable: Callable
) -> void:
	var item_names: Array = []
	item_names.append_array(field_spawn_order)
	item_names.append_array(extra_item_names)
	for item_name_value in item_names:
		var item_name: String = str(item_name_value)
		if item_name == "":
			continue
		var item_data_value: Variant = active_item_catalog.build_item_by_name(item_name)
		var item_data: Dictionary = item_data_value if item_data_value is Dictionary else {}
		if item_data.is_empty():
			continue
		var display_name: String = str(item_data.get("display_name", ""))
		if display_name == "":
			display_name = str(active_item_catalog.get_display_name(item_name))
		text_size_callable.call(font, display_name, 10)
		text_size_callable.call(font, display_name, 13)
		text_size_callable.call(font, trim_label_callable.call(display_name, 10), 10)
		prewarm_text_block_callable.call(font, get_string_fallback(item_data, "description", "desc"), 13, 312.0, 5)


static func prewarm_skill_text(
	font: Font,
	character_runtime: Object,
	current_character_label: String,
	registry: Object,
	module_getter: Callable,
	get_prewarm_instance_callable: Callable,
	text_size_callable: Callable,
	trim_label_callable: Callable,
	prewarm_text_block_callable: Callable
) -> bool:
	var seen: Dictionary = {}
	var warmed := false
	for character_type_value in ["smasher", "viper", "soldier"]:
		var character_type: String = str(character_type_value)
		var config_key := "smasher_skill_config"
		if character_runtime != null and character_runtime.has_method("get_skill_config_key"):
			config_key = str(character_runtime.get_skill_config_key(character_type))
		var skill_config_value: Variant = get_prewarm_instance_callable.call(registry, module_getter, config_key)
		if not (skill_config_value is Object):
			continue
		var skill_config: Object = skill_config_value
		if skill_config == null or not skill_config.has_method("get_snapshot"):
			continue
		var snapshot_value: Variant = skill_config.get_snapshot()
		var snapshot: Dictionary = snapshot_value if snapshot_value is Dictionary else {}
		var skill_data_value: Variant = snapshot.get("skill_data", {})
		var skill_data: Dictionary = skill_data_value if skill_data_value is Dictionary else {}
		for skill_id_value in skill_data.keys():
			var skill_id: String = str(skill_id_value)
			if seen.has(skill_id):
				continue
			seen[skill_id] = true
			var data_value: Variant = skill_data[skill_id_value]
			var data: Dictionary = data_value if data_value is Dictionary else {}
			var name: String = str(data.get("korean", skill_id))
			text_size_callable.call(font, name, 10)
			text_size_callable.call(font, name, 15)
			text_size_callable.call(font, trim_label_callable.call(name, 7), 10)
			prewarm_text_block_callable.call(font, str(data.get("description", "")), 13, 312.0, 5)
			warmed = true
	text_size_callable.call(font, current_character_label, 14)
	return warmed


static func prewarm_perk_text_entry(
	font: Font,
	entry: Dictionary,
	text_size_callable: Callable,
	trim_label_callable: Callable,
	prewarm_text_block_callable: Callable
) -> void:
	if entry.is_empty():
		return
	var skill_id: String = str(entry.get("id", ""))
	var name: String = str(entry.get("name", skill_id))
	text_size_callable.call(font, name, 13)
	text_size_callable.call(font, name, 15)
	text_size_callable.call(font, trim_label_callable.call(name, 7), 10)
	for level in range(1, max(2, min(10, int(entry.get("max_level", 1))) + 1)):
		text_size_callable.call(font, "Lv.%d" % level, 9)
	var detail: String = get_string_fallback(entry, "description", "detail")
	prewarm_text_block_callable.call(font, detail, 13, 312.0, 5)
	var descriptions: Dictionary = get_dict(entry.get("descriptions", {}))
	for description_value in descriptions.values():
		prewarm_text_block_callable.call(font, str(description_value), 13, 312.0, 5)


static func get_string_fallback(data: Dictionary, key: String, fallback_key: String, default_value: String = "") -> String:
	var primary: Variant = data.get(key, null)
	if primary != null:
		var primary_text := str(primary)
		if primary_text != "":
			return primary_text
	var fallback: Variant = data.get(fallback_key, null)
	if fallback != null:
		var fallback_text := str(fallback)
		if fallback_text != "":
			return fallback_text
	return default_value


static func get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
