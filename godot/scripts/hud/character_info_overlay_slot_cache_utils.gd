extends RefCounted


static func active_item_label_state(slot_value: Variant, active_item_catalog: Object) -> Dictionary:
	var item_name := ""
	var raw_display_name := ""
	if slot_value is Dictionary:
		var item_data: Dictionary = slot_value
		item_name = str(item_data.get("name", ""))
		raw_display_name = str(item_data.get("display_name", ""))
	var display_name := raw_display_name
	if display_name == "" and active_item_catalog != null and active_item_catalog.has_method("get_display_name"):
		display_name = str(active_item_catalog.get_display_name(item_name))
	if display_name == "":
		display_name = item_name
	return {
		"name": item_name,
		"raw_display_name": raw_display_name,
		"display_name": display_name,
	}


static func refresh_active_item_label_cache(
	slots: Array,
	active_item_catalog: Object,
	name_cache: Array[String],
	raw_display_name_cache: Array[String],
	display_name_cache: Array[String],
	trimmed_label_cache: Array[String],
	trim_label_callable: Callable
) -> void:
	var slot_count := slots.size()
	if name_cache.size() != slot_count:
		_resize_arrays([name_cache, raw_display_name_cache, display_name_cache, trimmed_label_cache], slot_count)
	for i in range(slot_count):
		var label_state: Dictionary = active_item_label_state(slots[i], active_item_catalog)
		var item_name: String = str(label_state.get("name", ""))
		var raw_display_name: String = str(label_state.get("raw_display_name", ""))
		if name_cache[i] == item_name and raw_display_name_cache[i] == raw_display_name:
			continue
		var display_name: String = str(label_state.get("display_name", ""))
		name_cache[i] = item_name
		raw_display_name_cache[i] = raw_display_name
		display_name_cache[i] = display_name
		trimmed_label_cache[i] = str(trim_label_callable.call(display_name, 10))


static func refresh_active_slot_draw_cache(
	slots: Array,
	max_slots: int,
	visuals: Object,
	should_cache_colors: bool,
	has_item_cache: Array[bool],
	item_cache: Array[Dictionary],
	fallback_color_cache: Array[Color],
	has_fallback_color_cache: Array[bool],
	item_color_callable: Callable
) -> void:
	_resize_arrays([has_item_cache, item_cache, fallback_color_cache, has_fallback_color_cache], max_slots)
	var default_color := Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)
	for i in range(max_slots):
		if i < slots.size() and slots[i] is Dictionary:
			var item_data: Dictionary = slots[i]
			has_item_cache[i] = true
			item_cache[i] = item_data
			if should_cache_colors:
				var color_value: Variant = item_color_callable.call(item_data, visuals, default_color)
				fallback_color_cache[i] = color_value if color_value is Color else default_color
				has_fallback_color_cache[i] = true
			else:
				fallback_color_cache[i] = Color.WHITE
				has_fallback_color_cache[i] = false
		else:
			has_item_cache[i] = false
			item_cache[i] = {}
			fallback_color_cache[i] = Color.WHITE
			has_fallback_color_cache[i] = false


static func refresh_skill_slot_draw_cache(
	equipped: Array,
	skill_data: Dictionary,
	fallback_skill_color: Color,
	slot_fill_color: Color,
	id_cache: Array[String],
	data_cache: Array[Dictionary],
	label_cache: Array[String],
	color_cache: Array[Color],
	fill_color_cache: Array[Color],
	border_color_cache: Array[Color],
	short_skill_name_callable: Callable
) -> void:
	_resize_arrays([id_cache, data_cache, label_cache, color_cache, fill_color_cache, border_color_cache], equipped.size())
	for i in range(equipped.size()):
		var skill_id: String = str(equipped[i])
		var data: Dictionary = _get_dict(skill_data.get(skill_id, {}))
		var color: Color = _get_color(data.get("color", fallback_skill_color))
		id_cache[i] = skill_id
		data_cache[i] = data
		label_cache[i] = str(short_skill_name_callable.call(data, skill_id))
		color_cache[i] = color
		fill_color_cache[i] = Color(
			slot_fill_color.r * 0.88 + color.r * 0.12,
			slot_fill_color.g * 0.88 + color.g * 0.12,
			slot_fill_color.b * 0.88 + color.b * 0.12,
			slot_fill_color.a
		)
		border_color_cache[i] = Color(color.r, color.g, color.b, 0.72)


static func _resize_arrays(arrays: Array, size: int) -> void:
	for values: Array in arrays:
		values.resize(size)


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE
