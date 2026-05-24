extends RefCounted

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const TREASURE_MAP_SKILL_ID := "downtown_treasure_map"
const LEGENDARY_CHANCE := 0.20
const PASSIVE_REWARD_CHANCE := 0.60
const TREASURE_MAP_LEGENDARY_BONUS_PER_LEVEL := 0.03
const RESULT_EFFECT_MSEC := 2400

var mythic_item_catalog: Object = MythicItemCatalog.new()
var result_started_msec := -1000000
var last_result: Dictionary = {}


func reset() -> void:
	result_started_msec = -1000000
	last_result.clear()


func start(owner: Object, registry: Object) -> Dictionary:
	if owner == null:
		return {"ok": false}
	var result: Dictionary = _roll_result(owner, registry)
	if not bool(result.get("ok", false)):
		return result
	last_result = result.duplicate(true)
	result_started_msec = Time.get_ticks_msec()
	_play_result_audio(registry, str(result.get("result_type", "")))
	return result


func is_effect_active() -> bool:
	return Time.get_ticks_msec() - result_started_msec < RESULT_EFFECT_MSEC and not last_result.is_empty()


func draw_effect(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas == null or not is_effect_active():
		return
	var elapsed: float = float(Time.get_ticks_msec() - result_started_msec)
	var ratio: float = clamp(elapsed / float(RESULT_EFFECT_MSEC), 0.0, 1.0)
	var alpha: float = 1.0
	if ratio < 0.18:
		alpha = ratio / 0.18
	elif ratio > 0.78:
		alpha = 1.0 - ((ratio - 0.78) / 0.22)
	alpha = clamp(alpha, 0.0, 1.0)

	var center := Vector2(view_size.x * 0.5, view_size.y * 0.26)
	var panel_size := Vector2(330.0, 118.0)
	var panel_rect := Rect2(center - panel_size * 0.5, panel_size)
	var result_type: String = str(last_result.get("result_type", "empty"))
	var accent: Color = _get_result_color(result_type)
	canvas.draw_rect(panel_rect, Color(10.0 / 255.0, 16.0 / 255.0, 30.0 / 255.0, 0.86 * alpha))
	canvas.draw_rect(panel_rect, Color(accent.r, accent.g, accent.b, 0.75 * alpha), false, 2.0)
	for grow in [6.0, 12.0]:
		canvas.draw_rect(panel_rect.grow(grow), Color(accent.r, accent.g, accent.b, 0.08 * alpha), false, 1.0)

	var icon_center := panel_rect.position + Vector2(58.0, panel_rect.size.y * 0.52)
	_draw_result_symbol(canvas, icon_center, result_type, accent, alpha)
	_draw_text(canvas, LanguageSettings.translate_text("보물탐색"), panel_rect.position + Vector2(106.0, 40.0), 18, Color(1.0, 215.0 / 255.0, 95.0 / 255.0, alpha))
	_draw_text(canvas, LanguageSettings.translate_text(str(last_result.get("display_text", "아무것도 찾지 못했습니다"))), panel_rect.position + Vector2(106.0, 72.0), 16, Color(235.0 / 255.0, 242.0 / 255.0, 1.0, alpha))


func get_last_result() -> Dictionary:
	return last_result.duplicate(true)


func _roll_result(owner: Object, registry: Object) -> Dictionary:
	var roll: float = randf()
	var legendary_chance: float = _get_legendary_chance(registry)
	var passive_end: float = min(1.0, legendary_chance + PASSIVE_REWARD_CHANCE)
	if roll < legendary_chance:
		var mythic_result: Dictionary = _grant_mythic(owner, registry)
		if bool(mythic_result.get("ok", false)):
			return mythic_result
	if roll < passive_end:
		var passive_result: Dictionary = _grant_passive_reward(owner, registry)
		if bool(passive_result.get("ok", false)):
			return passive_result
	return {
		"ok": true,
		"result_type": "empty",
		"item_name": "",
		"display_text": LanguageSettings.translate_text("아무것도 찾지 못했습니다"),
		"feedback_text": _format_feedback_text(LanguageSettings.translate_text("아무것도 찾지 못했습니다")),
	}


func _grant_mythic(owner: Object, registry: Object) -> Dictionary:
	var pool: Array[String] = _get_mythic_reward_pool(registry)
	if pool.is_empty():
		return {"ok": false}
	return _grant_passive_or_mythic_reward(str(pool[randi() % pool.size()]), "legendary", owner, registry)


func _grant_passive_reward(owner: Object, registry: Object) -> Dictionary:
	var pool: Array[String] = _get_passive_reward_pool(registry)
	if pool.is_empty():
		return {"ok": false}
	return _grant_passive_or_mythic_reward(str(pool[randi() % pool.size()]), "passive", owner, registry)


func _grant_passive_or_mythic_reward(
	item_name: String,
	result_type: String,
	owner: Object,
	registry: Object
) -> Dictionary:
	var mythic_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_runtime == null or not mythic_runtime.has_method("acquire_item"):
		return {"ok": false}
	var index: int = int(mythic_runtime.acquire_item(item_name, owner, registry, {}, true, false))
	if index < 0:
		return {"ok": false}
	var acquired_item: Dictionary = {}
	if mythic_runtime.has_method("get_inventory_item"):
		acquired_item = mythic_runtime.get_inventory_item(index)
	var display_name: String = (
		mythic_item_catalog.format_item_display_name(acquired_item)
		if not acquired_item.is_empty() and mythic_item_catalog.has_method("format_item_display_name")
		else mythic_item_catalog.get_display_name(item_name)
	)
	var result_label := LanguageSettings.translate_text("신화" if result_type == "legendary" else "패시브")
	return {
		"ok": true,
		"result_type": result_type,
		"item_name": item_name,
		"display_text": _format_result_text(result_label, display_name),
		"feedback_text": _format_feedback_text(display_name),
	}


func _format_result_text(result_label: String, display_name: String) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "%s Found: %s" % [result_label, display_name]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "%s encontrado: %s" % [result_label, display_name]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "%s encontrado: %s" % [result_label, display_name]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "%s найдено: %s" % [result_label, display_name]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "发现%s：%s" % [result_label, display_name]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "%s発見：%s" % [result_label, display_name]
	return "%s 발견: %s" % [result_label, display_name]


func _format_feedback_text(display_name: String) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Treasure Hunt: %s" % display_name
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Búsqueda del tesoro: %s" % display_name
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Caça ao Tesouro: %s" % display_name
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Охота за сокровищами: %s" % display_name
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "寻宝：%s" % display_name
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "宝探し：%s" % display_name
	return "보물탐색: %s" % display_name


func _get_legendary_chance(registry: Object) -> float:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_treasure_hunt_legendary_chance"):
		return clamp(float(runtime_perk_state.get_treasure_hunt_legendary_chance(LEGENDARY_CHANCE)), 0.0, 1.0)
	var treasure_map_level: int = _get_treasure_map_level(registry)
	return clamp(LEGENDARY_CHANCE + TREASURE_MAP_LEGENDARY_BONUS_PER_LEVEL * float(treasure_map_level), 0.0, 1.0)


func _get_treasure_map_level(registry: Object) -> int:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null:
		return 0
	if runtime_perk_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_perk_state.get_runtime_skill_level(TREASURE_MAP_SKILL_ID)))
	var levels_value: Variant = runtime_perk_state.get("runtime_skill_levels")
	if levels_value is Dictionary:
		return max(0, int(levels_value.get(TREASURE_MAP_SKILL_ID, 0)))
	return 0


func _get_mythic_reward_pool(registry: Object = null) -> Array[String]:
	return _get_reward_pool(["mythic", "legendary"], registry)


func _get_passive_reward_pool(registry: Object = null) -> Array[String]:
	return _get_reward_pool(["passive"], registry)


func _get_reward_pool(accepted_types: Array[String], registry: Object = null) -> Array[String]:
	var result: Array[String] = []
	for item_value in mythic_item_catalog.get_field_spawn_items():
		var item_data: Dictionary = _get_dict(item_value)
		if item_data.is_empty():
			continue
		var item_name: String = str(item_data.get("name", ""))
		if item_name == "":
			continue
		var item_type: String = str(item_data.get("type", "")).to_lower()
		var rarity: String = str(item_data.get("rarity", "")).to_lower()
		if _should_skip_reward_candidate(item_name, registry):
			continue
		if accepted_types.has(item_type) or accepted_types.has(rarity):
			result.append(item_name)
	return result


func _should_skip_reward_candidate(item_name: String, registry: Object) -> bool:
	var mythic_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_runtime == null or not mythic_runtime.has_method("should_skip_one_time_passive_spawn"):
		return false
	return bool(mythic_runtime.should_skip_one_time_passive_spawn(item_name))


func _play_result_audio(registry: Object, result_type: String) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if result_type == "legendary":
		# Mythic equipment routing already plays its own acquisition/equip cue.
		return
	if result_type == "passive":
		if audio.has_method("play_item_get"):
			audio.play_item_get()
		return
	if audio.has_method("play_active_item"):
		audio.play_active_item()


func _draw_result_symbol(canvas: CanvasItem, center: Vector2, result_type: String, color: Color, alpha: float) -> void:
	var radius := 30.0
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.24 * alpha))
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.82 * alpha), false, 2.0)
	if result_type == "legendary":
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -radius * 0.72),
			center + Vector2(radius * 0.72, 0.0),
			center + Vector2(0.0, radius * 0.72),
			center + Vector2(-radius * 0.72, 0.0),
		])
		canvas.draw_colored_polygon(diamond, Color(1.0, 220.0 / 255.0, 70.0 / 255.0, 0.86 * alpha))
	elif result_type == "passive":
		var box := Rect2(center - Vector2(radius * 0.50, radius * 0.40), Vector2(radius, radius * 0.80))
		canvas.draw_rect(box, Color(color.r, color.g, color.b, 0.78 * alpha))
		canvas.draw_line(box.position + Vector2(0.0, -5.0), box.position + Vector2(box.size.x, -5.0), Color.WHITE, 2.0)
	else:
		canvas.draw_line(center + Vector2(-radius * 0.42, -radius * 0.42), center + Vector2(radius * 0.42, radius * 0.42), Color(180.0 / 255.0, 188.0 / 255.0, 205.0 / 255.0, alpha), 2.0)
		canvas.draw_line(center + Vector2(radius * 0.42, -radius * 0.42), center + Vector2(-radius * 0.42, radius * 0.42), Color(180.0 / 255.0, 188.0 / 255.0, 205.0 / 255.0, alpha), 2.0)


func _get_result_color(result_type: String) -> Color:
	match result_type:
		"legendary":
			return Color(1.0, 215.0 / 255.0, 0.0)
		"passive":
			return Color(90.0 / 255.0, 190.0 / 255.0, 1.0)
	return Color(130.0 / 255.0, 138.0 / 255.0, 154.0 / 255.0)


func _draw_text(canvas: CanvasItem, text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
