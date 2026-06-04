extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")


static func prewarm_static_text(font: Font, owner: Object, equipment_slot_keys: Array[String], equipment_slot_labels: Array[String], measure_text_callable: Callable) -> void:
	for text in ["퍽", "Lv.1", "Lv.2", "Lv.3", "Lv.4", "Lv.5", "0 / 1", "0 / 2", "0 / 3", "0 / 5", "-", "E"]:
		for size in [8, 9, 10, 11, 12, 13, 14, 15]:
			measure_text_callable.call(font, str(text), int(size))
	for i in range(equipment_slot_keys.size()):
		measure_text_callable.call(font, equipment_slot_labels[i], 10)
		measure_text_callable.call(font, equipment_slot_labels[i], 13)
		measure_text_callable.call(font, CharacterInfoOverlayFormatter.slot_display_label(equipment_slot_keys[i]), 12)
	for character_type in ["smasher", "viper", "soldier"]:
		measure_text_callable.call(font, CharacterInfoOverlayFormatter.character_type_label(str(character_type)), 14)
		measure_text_callable.call(font, CharacterInfoOverlayOwnerState.character_display_name_from_owner(owner, str(character_type)), 20)


static func get_indexed_width(
	font: Font,
	index: int,
	text: String,
	size: int,
	width_cache: Array,
	text_cache: Array,
	size_cache: Array,
	font_id_cache: Array,
	measure_text_callable: Callable
) -> float:
	var font_id := _font_id(font)
	if text_cache[index] == text and size_cache[index] == size and font_id_cache[index] == font_id:
		return float(width_cache[index])
	var width := _measure_width(font, text, size, measure_text_callable)
	text_cache[index] = text
	size_cache[index] = size
	font_id_cache[index] = font_id
	width_cache[index] = width
	return width


static func get_single_width_state(
	font: Font,
	text: String,
	size: int,
	cached_text: String,
	cached_size: int,
	cached_font_id: int,
	cached_width: float,
	measure_text_callable: Callable
) -> Dictionary:
	var font_id := _font_id(font)
	if cached_text == text and cached_size == size and cached_font_id == font_id:
		return {
			"text": cached_text,
			"size": cached_size,
			"font_id": cached_font_id,
			"width": cached_width,
		}
	var width := _measure_width(font, text, size, measure_text_callable)
	return {
		"text": text,
		"size": size,
		"font_id": font_id,
		"width": width,
	}


static func get_overlay_single_width(target: Object, cache_property: String, font: Font, text: String, size: int, measure_text_callable: Callable, current_cache: Dictionary = {}) -> float:
	var cache_value: Variant = target.get(cache_property)
	var cache: Dictionary = current_cache if not current_cache.is_empty() else cache_value if cache_value is Dictionary else {}
	cache = get_single_width_state(font, text, size, str(cache.get("text", "")), int(cache.get("size", 0)), int(cache.get("font_id", 0)), float(cache.get("width", 0.0)), measure_text_callable)
	target.set(cache_property, cache)
	return float(cache.get("width", 0.0))


static func get_indexed_size(
	font: Font,
	text: String,
	size: int,
	font_id: int,
	text_cache: Array[String],
	size_cache: Array[int],
	font_id_cache: Array[int],
	value_cache: Array[Vector2],
	measure_text_callable: Callable,
	clear_limit: int = 0
) -> Vector2:
	for i in range(text_cache.size()):
		if text_cache[i] == text and size_cache[i] == size and font_id_cache[i] == font_id:
			return value_cache[i]
	var text_size_value: Variant = measure_text_callable.call(font, text, size)
	var text_size: Vector2 = text_size_value if text_size_value is Vector2 else Vector2.ZERO
	if clear_limit > 0 and text_cache.size() >= clear_limit:
		text_cache.clear()
		size_cache.clear()
		font_id_cache.clear()
		value_cache.clear()
	text_cache.append(text)
	size_cache.append(size)
	font_id_cache.append(font_id)
	value_cache.append(text_size)
	return text_size


static func get_overlay_indexed_size(
	target: Object,
	font: Font,
	text: String,
	size: int,
	fast_text: String,
	fast_size: int,
	fast_font_id: int,
	fast_value: Vector2,
	fast_text_property: String,
	fast_size_property: String,
	fast_font_id_property: String,
	fast_value_property: String,
	text_cache: Array[String],
	size_cache: Array[int],
	font_id_cache: Array[int],
	value_cache: Array[Vector2],
	measure_text_callable: Callable,
	clear_limit: int = 0
) -> Vector2:
	var font_id: int = _font_id(font)
	if text == fast_text and size == fast_size and font_id == fast_font_id:
		return fast_value
	var text_size: Vector2 = get_indexed_size(font, text, size, font_id, text_cache, size_cache, font_id_cache, value_cache, measure_text_callable, clear_limit)
	target.set(fast_text_property, text)
	target.set(fast_size_property, size)
	target.set(fast_font_id_property, font_id)
	target.set(fast_value_property, text_size)
	return text_size


static func get_text_size(
	font: Font,
	text: String,
	ui_size: int,
	cache: Dictionary,
	cache_limit: int
) -> Vector2:
	var cache_key := "%d:%s" % [ui_size, text]
	if cache.has(cache_key):
		var cached_size: Variant = cache[cache_key]
		if cached_size is Vector2:
			return cached_size
		cache.erase(cache_key)
	var measured_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ui_size)
	if cache.size() >= cache_limit:
		cache.clear()
	cache[cache_key] = measured_size
	return measured_size


static func get_overlay_text_size(
	target: Object,
	font: Font,
	text: String,
	ui_size: int,
	fast_text: String,
	fast_ui_size: int,
	fast_value: Vector2,
	cache: Dictionary,
	cache_limit: int
) -> Vector2:
	if text == fast_text and ui_size == fast_ui_size:
		return fast_value
	var measured_size: Vector2 = get_text_size(font, text, ui_size, cache, cache_limit)
	target.set("_text_size_fast_text", text)
	target.set("_text_size_fast_ui_size", ui_size)
	target.set("_text_size_fast_value", measured_size)
	return measured_size


static func _font_id(font: Font) -> int:
	return int(font.get_instance_id()) if font != null else 0


static func _measure_width(font: Font, text: String, size: int, measure_text_callable: Callable) -> float:
	var measured_value: Variant = measure_text_callable.call(font, text, size)
	if measured_value is Vector2:
		var measured_size: Vector2 = measured_value
		return float(measured_size.x)
	return 0.0
