extends RefCounted

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const TREASURE_MAP_SKILL_ID := "downtown_treasure_map"
const LEGENDARY_CHANCE := 0.20
const PASSIVE_REWARD_CHANCE := 0.60
const TREASURE_MAP_LEGENDARY_BONUS_PER_LEVEL := 0.03
const MINING_DURATION_MSEC := 3000
const RESULT_EFFECT_MSEC := 2400
const EFFECT_PHASE_IDLE := "idle"
const EFFECT_PHASE_MINING := "mining"
const EFFECT_PHASE_RESULT := "result"
const MINING_SHEET_PATH := "res://assets/sprites/perks/instant_treasure_hunt_mining_sheet_autosprite_v1.png"
const MINING_SHEET_FRAME_COUNT := 32
const MINING_SHEET_COLUMNS := 8
const MINING_SHEET_ROWS := 4
const MINING_SWING_INTERVAL_MSEC := 360
const MINING_SWING_FRAME_COUNT := 16
const MINING_HIT_OFFSET_MSEC := 90

var mythic_item_catalog: Object = MythicItemCatalog.new()
var effect_phase := EFFECT_PHASE_IDLE
var effect_started_msec := -1000000
var result_started_msec := -1000000
var last_result: Dictionary = {}
var _pending_owner: Object = null
var _pending_registry: Object = null
var _mining_last_swing_index := -1
var _mining_sheet_texture: Texture2D = null
var _item_icon_texture_cache: Dictionary = {}


func reset() -> void:
	effect_phase = EFFECT_PHASE_IDLE
	effect_started_msec = -1000000
	result_started_msec = -1000000
	last_result.clear()
	_pending_owner = null
	_pending_registry = null
	_mining_last_swing_index = -1


func prewarm_assets() -> void:
	_get_mining_sheet_texture()


func prewarm_assets_step() -> bool:
	prewarm_assets()
	return true


func start(owner: Object, registry: Object) -> Dictionary:
	if owner == null:
		return {"ok": false}
	_pending_owner = owner
	_pending_registry = registry
	last_result.clear()
	effect_phase = EFFECT_PHASE_MINING
	effect_started_msec = Time.get_ticks_msec()
	result_started_msec = -1000000
	_mining_last_swing_index = -1
	return {
		"ok": true,
		"result_type": "pending",
		"display_text": LanguageSettings.translate_text("보물탐색중..."),
		"feedback_text": LanguageSettings.translate_text("보물탐색중..."),
	}


func is_effect_active() -> bool:
	_advance_effect_if_needed()
	if effect_phase == EFFECT_PHASE_MINING:
		return true
	return effect_phase == EFFECT_PHASE_RESULT and not last_result.is_empty()


func draw_effect(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas == null:
		return
	_advance_effect_if_needed()
	if effect_phase == EFFECT_PHASE_MINING:
		_draw_mining_effect(canvas, view_size)
		return
	if effect_phase == EFFECT_PHASE_RESULT:
		_draw_result_effect(canvas, view_size)
		return
	if not is_effect_active():
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


func get_effect_phase() -> String:
	_advance_effect_if_needed()
	return effect_phase


func get_mining_progress() -> float:
	if effect_phase == EFFECT_PHASE_RESULT:
		return 1.0
	if effect_phase != EFFECT_PHASE_MINING:
		return 0.0
	return clamp(float(Time.get_ticks_msec() - effect_started_msec) / float(MINING_DURATION_MSEC), 0.0, 1.0)


func _advance_effect_if_needed() -> void:
	if effect_phase == EFFECT_PHASE_MINING:
		var now_msec: int = Time.get_ticks_msec()
		_maybe_play_mining_hit_audio(now_msec)
		if now_msec - effect_started_msec >= MINING_DURATION_MSEC:
			_reveal_result(now_msec)
	elif effect_phase == EFFECT_PHASE_RESULT:
		if Time.get_ticks_msec() - result_started_msec >= RESULT_EFFECT_MSEC:
			effect_phase = EFFECT_PHASE_IDLE


func _reveal_result(now_msec: int) -> void:
	var owner: Object = _pending_owner
	var registry: Object = _pending_registry
	_pending_owner = null
	_pending_registry = null
	if owner == null:
		effect_phase = EFFECT_PHASE_IDLE
		return
	var result: Dictionary = _roll_result(owner, registry)
	if not bool(result.get("ok", false)):
		result = _empty_result()
	last_result = result.duplicate(true)
	result_started_msec = now_msec
	effect_phase = EFFECT_PHASE_RESULT
	_play_first_audio(registry, ["play_stage2_stonebreak"])
	_play_result_audio(registry, str(result.get("result_type", "")))


func _maybe_play_mining_hit_audio(now_msec: int) -> void:
	var elapsed_msec: int = now_msec - effect_started_msec
	if elapsed_msec < MINING_HIT_OFFSET_MSEC:
		return
	var swing_index: int = int(floor(float(elapsed_msec - MINING_HIT_OFFSET_MSEC) / float(MINING_SWING_INTERVAL_MSEC)))
	if swing_index == _mining_last_swing_index:
		return
	_mining_last_swing_index = swing_index
	_play_first_audio(_pending_registry, ["play_treasure_hunt_mining", "play_stage2_rockhit"])


func _roll_result(owner: Object, registry: Object, roll_override: float = -1.0) -> Dictionary:
	var roll: float = randf() if roll_override < 0.0 else roll_override
	var legendary_chance: float = _get_legendary_chance(registry)
	var passive_end: float = min(1.0, legendary_chance + PASSIVE_REWARD_CHANCE)
	if roll < legendary_chance:
		var mythic_result: Dictionary = _grant_mythic(owner, registry)
		if bool(mythic_result.get("ok", false)):
			return mythic_result
	if roll < passive_end:
		if PerkConversionFlags.is_enabled():
			var starpoint_result: Dictionary = _grant_starpoint_reward(owner, registry, 1)
			if bool(starpoint_result.get("ok", false)):
				return starpoint_result
			return starpoint_result
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


func _empty_result() -> Dictionary:
	return {
		"ok": true,
		"result_type": "empty",
		"item_name": "",
		"display_text": LanguageSettings.translate_text("아무것도 찾지 못했습니다..."),
		"feedback_text": _format_feedback_text(LanguageSettings.translate_text("아무것도 찾지 못했습니다...")),
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


func _grant_starpoint_reward(owner: Object, registry: Object, amount: int = 1) -> Dictionary:
	amount = max(1, amount)
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null or not runtime_perk_state.has_method("collect_star_points"):
		return {"ok": false}
	var runtime_perk_catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	runtime_perk_state.collect_star_points(amount, _get_selected_character_type(owner), runtime_perk_catalog, owner, registry)
	var label := "★%d" % amount
	return {
		"ok": true,
		"result_type": "starpoint",
		"item_name": "",
		"amount": amount,
		"display_text": _format_result_text(LanguageSettings.translate_text("스타포인트"), label),
		"feedback_text": _format_feedback_text(label),
	}


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
	var icon_path: String = mythic_item_catalog.get_icon_path(item_name)
	var result_label := LanguageSettings.translate_text("신화" if result_type == "legendary" else "패시브")
	return {
		"ok": true,
		"result_type": result_type,
		"item_name": item_name,
		"icon_path": icon_path,
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


func _get_selected_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null or str(value) == "":
		return "smasher"
	return str(value)


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


func _play_first_audio(registry: Object, method_names: Array) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	for method_value in method_names:
		var method_name: String = str(method_value)
		if method_name != "" and audio.has_method(method_name):
			audio.call(method_name)
			return


func _draw_mining_effect(canvas: CanvasItem, view_size: Vector2) -> void:
	var progress: float = get_mining_progress()
	var elapsed: float = float(Time.get_ticks_msec() - effect_started_msec)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.78))
	_draw_cave_wash(canvas, view_size, elapsed, 1.0)
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.48)
	if not _draw_mining_sheet(canvas, center, view_size, elapsed):
		_draw_fallback_mining(canvas, center, elapsed)
	var dots := ".".repeat(int(floor(elapsed / 250.0)) % 4)
	_draw_centered_text(
		canvas,
		LanguageSettings.translate_text("보물탐색중%s" % dots),
		center + Vector2(0.0, 150.0),
		30,
		Color(1.0, 0.84, 0.25, 1.0)
	)
	_draw_progress_bar(canvas, center + Vector2(0.0, 190.0), progress)


func _draw_cave_wash(canvas: CanvasItem, view_size: Vector2, elapsed: float, alpha: float) -> void:
	var height: int = max(0, int(view_size.y))
	for y in range(0, height, 18):
		var wave: float = sin(float(y) * 0.035 + elapsed * 0.004)
		var line_alpha: float = (0.05 + 0.025 * wave) * alpha
		canvas.draw_line(
			Vector2(0.0, float(y)),
			Vector2(view_size.x, float(y)),
			Color(0.22, 0.18, 0.12, line_alpha),
			3.0
		)


func _draw_mining_sheet(canvas: CanvasItem, center: Vector2, view_size: Vector2, elapsed: float) -> bool:
	var texture: Texture2D = _get_mining_sheet_texture()
	if texture == null:
		return false
	var frame_width: float = float(texture.get_width()) / float(MINING_SHEET_COLUMNS)
	var frame_height: float = float(texture.get_height()) / float(MINING_SHEET_ROWS)
	if frame_width <= 0.0 or frame_height <= 0.0:
		return false
	var cycle_ratio: float = fmod(max(0.0, elapsed), float(MINING_SWING_INTERVAL_MSEC)) / float(MINING_SWING_INTERVAL_MSEC)
	var frame_index: int = clamp(int(floor(cycle_ratio * float(MINING_SWING_FRAME_COUNT))), 0, MINING_SWING_FRAME_COUNT - 1)
	var column: int = frame_index % MINING_SHEET_COLUMNS
	var row: int = int(floor(float(frame_index) / float(MINING_SHEET_COLUMNS)))
	var source := Rect2(Vector2(float(column) * frame_width, float(row) * frame_height), Vector2(frame_width, frame_height))
	var draw_size: float = clamp(min(view_size.x * 0.44, view_size.y * 0.42), 210.0, 330.0)
	var target := Rect2(center - Vector2(draw_size, draw_size) * 0.5 + Vector2(0.0, -18.0), Vector2(draw_size, draw_size))
	canvas.draw_texture_rect_region(texture, target, source)
	return true


func _draw_fallback_mining(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	var rock_center := center + Vector2(0.0, 18.0)
	var rock_points := PackedVector2Array([
		rock_center + Vector2(-78.0, 36.0),
		rock_center + Vector2(-84.0, -8.0),
		rock_center + Vector2(-54.0, -54.0),
		rock_center + Vector2(-8.0, -74.0),
		rock_center + Vector2(42.0, -62.0),
		rock_center + Vector2(78.0, -26.0),
		rock_center + Vector2(86.0, 24.0),
		rock_center + Vector2(50.0, 58.0),
		rock_center + Vector2(-34.0, 52.0),
	])
	canvas.draw_colored_polygon(rock_points, Color(0.31, 0.30, 0.28, 1.0))
	canvas.draw_polyline(rock_points, Color(0.55, 0.53, 0.48, 1.0), 3.0, true)
	for gem in [
		[Vector2(-36.0, -24.0), Color(1.0, 0.82, 0.12, 1.0)],
		[Vector2(24.0, -34.0), Color(0.1, 0.78, 1.0, 1.0)],
		[Vector2(48.0, -4.0), Color(1.0, 0.2, 0.46, 1.0)],
		[Vector2(-18.0, 18.0), Color(0.35, 1.0, 0.55, 1.0)],
	]:
		var gem_center: Vector2 = rock_center + gem[0]
		var gem_color: Color = gem[1]
		var diamond := PackedVector2Array([
			gem_center + Vector2(0.0, -8.0),
			gem_center + Vector2(8.0, 0.0),
			gem_center + Vector2(0.0, 8.0),
			gem_center + Vector2(-8.0, 0.0),
		])
		canvas.draw_colored_polygon(diamond, gem_color)
	var swing_phase: float = fmod(elapsed / float(MINING_SWING_INTERVAL_MSEC), 1.0)
	var angle_deg: float = -58.0 + 92.0 * clamp((swing_phase - 0.35) / 0.25, 0.0, 1.0)
	if swing_phase > 0.60:
		angle_deg = 30.0 * (1.0 - clamp((swing_phase - 0.60) / 0.40, 0.0, 1.0))
	var angle: float = deg_to_rad(angle_deg)
	var pivot := rock_center + Vector2(92.0, -84.0)
	var handle_end := pivot + Vector2(54.0, 118.0).rotated(angle)
	var head_left := pivot + Vector2(-62.0, 22.0).rotated(angle)
	var head_right := pivot + Vector2(60.0, -42.0).rotated(angle)
	canvas.draw_line(pivot, handle_end, Color(0.50, 0.31, 0.12, 1.0), 13.0)
	canvas.draw_line(pivot, handle_end, Color(0.82, 0.58, 0.28, 1.0), 8.0)
	canvas.draw_line(head_left, head_right, Color(0.08, 0.09, 0.10, 1.0), 13.0)
	canvas.draw_line(head_left, head_right, Color(0.62, 0.66, 0.68, 1.0), 8.0)
	if swing_phase >= 0.48 and swing_phase < 0.68:
		var impact := rock_center + Vector2(28.0, -28.0)
		var impact_ratio: float = clamp((swing_phase - 0.48) / 0.20, 0.0, 1.0)
		canvas.draw_circle(impact, 26.0 + impact_ratio * 45.0, Color(1.0, 0.92, 0.45, 0.24 * (1.0 - impact_ratio)))
		for i in range(8):
			var dir := Vector2.RIGHT.rotated(float(i) * TAU / 8.0 + elapsed * 0.01)
			canvas.draw_circle(impact + dir * (20.0 + 45.0 * impact_ratio), 3.0, Color(1.0, 0.72, 0.18, 1.0 - impact_ratio))


func _draw_progress_bar(canvas: CanvasItem, center: Vector2, progress: float) -> void:
	var bar_size := Vector2(300.0, 16.0)
	var rect := Rect2(center - bar_size * 0.5, bar_size)
	canvas.draw_rect(rect.grow(3.0), Color(0.18, 0.16, 0.13, 1.0))
	canvas.draw_rect(rect, Color(0.08, 0.075, 0.065, 1.0))
	var fill_rect := Rect2(rect.position, Vector2(rect.size.x * clamp(progress, 0.0, 1.0), rect.size.y))
	canvas.draw_rect(fill_rect, Color(1.0, 0.70, 0.16, 1.0))
	canvas.draw_line(rect.position + Vector2(2.0, 3.0), rect.position + Vector2(max(2.0, fill_rect.size.x - 2.0), 3.0), Color(1.0, 0.95, 0.56, 0.8), 2.0)
	canvas.draw_rect(rect, Color(0.72, 0.62, 0.34, 1.0), false, 2.0)


func _draw_result_effect(canvas: CanvasItem, view_size: Vector2) -> void:
	if last_result.is_empty():
		return
	var elapsed: float = float(Time.get_ticks_msec() - result_started_msec)
	var ratio: float = clamp(elapsed / float(RESULT_EFFECT_MSEC), 0.0, 1.0)
	var alpha: float = 1.0
	if ratio < 0.18:
		alpha = ratio / 0.18
	elif ratio > 0.78:
		alpha = 1.0 - ((ratio - 0.78) / 0.22)
	alpha = clamp(alpha, 0.0, 1.0)
	var result_type: String = str(last_result.get("result_type", "empty"))
	var accent: Color = _get_result_color(result_type)
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.46)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.72 * alpha))
	_draw_cave_wash(canvas, view_size, float(Time.get_ticks_msec() - effect_started_msec), alpha)
	if result_type == "empty":
		_draw_empty_result(canvas, center, alpha)
	else:
		_draw_found_result(canvas, center, result_type, accent, alpha)


func _draw_found_result(canvas: CanvasItem, center: Vector2, result_type: String, accent: Color, alpha: float) -> void:
	var pulse: float = 1.0 + 0.08 * sin(float(Time.get_ticks_msec() - result_started_msec) * 0.006)
	var icon_center := center + Vector2(0.0, -58.0 + sin(float(Time.get_ticks_msec() - result_started_msec) * 0.004) * 10.0)
	for i in range(8):
		var radius: float = (66.0 + float(i) * 8.0) * pulse
		canvas.draw_circle(icon_center, radius, Color(accent.r, accent.g, accent.b, (0.11 - float(i) * 0.011) * alpha))
	var icon_texture: Texture2D = _get_result_icon_texture()
	if icon_texture != null:
		var icon_size := Vector2(112.0, 112.0)
		canvas.draw_texture_rect(icon_texture, Rect2(icon_center - icon_size * 0.5, icon_size), false, Color(1.0, 1.0, 1.0, alpha))
	else:
		_draw_result_symbol(canvas, icon_center, result_type, accent, alpha)
	var title: String = "★ 신화 아이템 발견! ★" if result_type == "legendary" else "아이템을 발견했습니다!"
	_draw_centered_text(canvas, LanguageSettings.translate_text(title), center + Vector2(0.0, 72.0), 30, Color(accent.r, accent.g, accent.b, alpha))
	_draw_centered_text(
		canvas,
		LanguageSettings.translate_text(str(last_result.get("display_text", ""))),
		center + Vector2(0.0, 120.0),
		22,
		Color(0.92, 0.96, 1.0, alpha)
	)


func _draw_empty_result(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	var shake := Vector2(sin(float(Time.get_ticks_msec()) * 0.016) * 5.0, cos(float(Time.get_ticks_msec()) * 0.014) * 3.0)
	_draw_centered_text(canvas, "?", center + Vector2(0.0, -54.0) + shake, 92, Color(0.70, 0.72, 0.78, alpha))
	_draw_centered_text(
		canvas,
		LanguageSettings.translate_text("아무것도 찾지 못했습니다..."),
		center + Vector2(0.0, 54.0),
		30,
		Color(0.66, 0.68, 0.74, alpha)
	)


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


func _draw_centered_text(canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.35)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_mining_sheet_texture() -> Texture2D:
	if _mining_sheet_texture != null:
		return _mining_sheet_texture
	_mining_sheet_texture = ProjectResourceLoader.load_texture(
		MINING_SHEET_PATH,
		"",
		"Failed to load treasure hunt mining sheet"
	)
	return _mining_sheet_texture


func _get_result_icon_texture() -> Texture2D:
	var icon_path: String = str(last_result.get("icon_path", ""))
	if icon_path == "":
		return null
	if _item_icon_texture_cache.has(icon_path):
		var cached: Variant = _item_icon_texture_cache[icon_path]
		if cached is Texture2D:
			return cached
		_item_icon_texture_cache.erase(icon_path)
	var texture: Texture2D = ProjectResourceLoader.load_texture(icon_path, "", "")
	if texture != null:
		_item_icon_texture_cache[icon_path] = texture
	return texture


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
