extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const ActiveItemHudLayout := preload("res://scripts/hud/active_item_hud_layout.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const HINT_SECONDS := 5.0
const FADE_SECONDS := 0.45
const POST_SKILL_TUTORIAL_DELAY_SECONDS := 20.0
const FONT_SIZE := 23
const MIN_FONT_SIZE := 17
const DEFAULT_SLOT_CAPACITY := 3

var layout_helper: Object = ActiveItemHudLayout.new()
var _character_runtime: Object = PlayerCharacterRuntime.new()
var _active := false
var _elapsed := 0.0
var _shown := false
var _target_slot_index := -1
var _grip_style := ""
var _last_language := ""
var _text_size_cache: Dictionary = {}
var _post_skill_delay_started := false
var _post_skill_delay_elapsed := 0.0
var _observed_slot_count := 0
var _pending_new_slot_index := -1


func update(delta: float, owner: Object, registry: Object, module_getter: Callable = Callable()) -> bool:
	var language_changed: bool = _refresh_language_state()
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	var active_item_count: int = active_item_slots.size()
	if _active:
		var previous_elapsed: float = _elapsed
		_elapsed = min(HINT_SECONDS, _elapsed + max(0.0, delta))
		if _elapsed >= HINT_SECONDS:
			_active = false
			return true
		return language_changed or not is_equal_approx(previous_elapsed, _elapsed)
	if _shown:
		return false
	if not _delay_prerequisites_met(owner, module_getter):
		_reset_delay_tracking(active_item_count)
		return false

	if not _post_skill_delay_started:
		_post_skill_delay_started = true
		_post_skill_delay_elapsed = min(POST_SKILL_TUTORIAL_DELAY_SECONDS, max(0.0, delta))
		_observed_slot_count = active_item_count
		return false

	if _post_skill_delay_elapsed < POST_SKILL_TUTORIAL_DELAY_SECONDS:
		_post_skill_delay_elapsed = min(
			POST_SKILL_TUTORIAL_DELAY_SECONDS,
			_post_skill_delay_elapsed + max(0.0, delta)
		)
		_observed_slot_count = active_item_count
		return false

	if active_item_count > _observed_slot_count:
		_pending_new_slot_index = active_item_count - 1
	_observed_slot_count = active_item_count
	if _pending_new_slot_index < 0:
		return false
	if _pending_new_slot_index >= active_item_count:
		_pending_new_slot_index = -1
		return false
	if _display_blocked(owner, registry, module_getter):
		return false
	_start(_pending_new_slot_index, owner)
	_pending_new_slot_index = -1
	return true


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if canvas == null or not _active:
		return
	var alpha: float = get_alpha()
	if alpha <= 0.001:
		return
	var highlight_rect: Rect2 = get_highlight_rect(owner, registry, view_size)
	if highlight_rect.size != Vector2.ZERO:
		_draw_slot_highlight(canvas, highlight_rect, alpha)
	_draw_message(canvas, view_size, highlight_rect, alpha)


func is_active() -> bool:
	return _active


func has_shown() -> bool:
	return _shown


func get_alpha() -> float:
	if not _active:
		return 0.0
	if _elapsed < FADE_SECONDS:
		return _smooth_step(_elapsed / FADE_SECONDS)
	if _elapsed > HINT_SECONDS - FADE_SECONDS:
		return _smooth_step((HINT_SECONDS - _elapsed) / FADE_SECONDS)
	return 1.0


func get_message() -> String:
	match _grip_style:
		"gamepad":
			return LanguageSettings.translate(
				"tutorial.active_item_use.gamepad",
				"아이템 사용: LB/RB 선택, Y 사용"
			)
		_:
			var template: String = LanguageSettings.translate(
				"tutorial.active_item_use.keyboard",
				"획득한 아이템 사용: %d번 키"
			)
			var slot_number: int = max(1, _target_slot_index + 1)
			return template % slot_number if template.find("%d") >= 0 else template


func get_snapshot() -> Dictionary:
	return {
		"active": _active,
		"elapsed": _elapsed,
		"alpha": get_alpha(),
		"shown": _shown,
		"target_slot_index": _target_slot_index,
		"grip_style": _grip_style,
		"message": get_message(),
		"language": _last_language,
		"post_skill_delay_started": _post_skill_delay_started,
		"post_skill_delay_elapsed": _post_skill_delay_elapsed,
		"post_skill_delay_ready": _is_post_skill_delay_ready(),
		"observed_slot_count": _observed_slot_count,
		"pending_new_slot_index": _pending_new_slot_index,
	}


func get_highlight_rect(owner: Object, registry: Object, view_size: Vector2) -> Rect2:
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if active_item_slots.is_empty():
		return Rect2()
	var target_index: int = clampi(_target_slot_index, 0, active_item_slots.size() - 1)
	var scene_config: Dictionary = _build_scene_config(registry)
	var layout: Dictionary = _build_layout(
		registry,
		view_size,
		float(scene_config.get("width", 760.0)),
		float(scene_config.get("height", 750.0))
	)
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", Vector2(760.0, 750.0))
	var slot_capacity: int = _get_active_item_slot_capacity(registry, active_item_slots.size())
	var item_layout: Dictionary = layout_helper.build_layout(
		view_size,
		game_offset,
		game_size,
		float(scene_config.get("width", 760.0)),
		active_item_slots.size(),
		slot_capacity
	)
	if not bool(item_layout.get("visible", false)):
		return Rect2()
	var slot_rects: Array = _get_array(item_layout.get("slot_rects", []))
	if target_index < 0 or target_index >= slot_rects.size():
		return Rect2()
	var slot_rect: Variant = slot_rects[target_index]
	return slot_rect if slot_rect is Rect2 else Rect2()


func _start(slot_index: int, owner: Object) -> void:
	_target_slot_index = max(0, slot_index)
	_grip_style = _get_grip_style(owner)
	_elapsed = 0.0
	_active = true
	_shown = true


func _delay_prerequisites_met(owner: Object, module_getter: Callable) -> bool:
	if owner == null:
		return false
	if not _has_completed_mid_tutorial(owner, module_getter):
		return false
	return (
		BattleSceneConfig.normalize_league_mode(
			str(BattleSceneOwnerReader.get_value(owner, "ai_mode", "champion"))
		) == "junior"
		and _is_starter_tutorial_character(
			BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher")
		)
		and _get_grip_style(owner) != ""
	)


func _display_blocked(owner: Object, registry: Object, module_getter: Callable) -> bool:
	return (
		_is_junior_mika_tutorial_active(module_getter)
		or _is_skill_orb_tooltip_open(owner, registry)
		or _is_module_active(module_getter, "commando_firearm_tutorial_hint")
		or _is_module_active(module_getter, "viper_practice_mode")
	)


func _is_starter_tutorial_character(character_type: Variant) -> bool:
	return (
		_character_runtime.normalize(character_type) == "smasher"
		or _character_runtime.is_commando(character_type)
		or _character_runtime.is_viper(character_type)
	)


func _is_module_active(module_getter: Callable, key: String) -> bool:
	var module: Object = _get_module(module_getter, key)
	return module != null and module.has_method("is_active") and bool(module.is_active())


func _reset_delay_tracking(active_item_count: int) -> void:
	_post_skill_delay_started = false
	_post_skill_delay_elapsed = 0.0
	_observed_slot_count = active_item_count
	_pending_new_slot_index = -1


func _is_post_skill_delay_ready() -> bool:
	return _post_skill_delay_started and _post_skill_delay_elapsed >= POST_SKILL_TUTORIAL_DELAY_SECONDS


# 캐릭터별 중간 튜토리얼 완료 여부: 스매셔=스킬-오브(드라이브/파워스매시),
# 코만도=화기 안내(권총 발사/화기 교체). 이 단계가 끝나야 아이템 사용 안내가 열린다.
func _has_completed_mid_tutorial(owner: Object, module_getter: Callable) -> bool:
	var key: String = _mid_tutorial_module_key(owner)
	var hint: Object = _get_module(module_getter, key)
	if hint == null:
		return false
	if hint.has_method("is_active") and bool(hint.is_active()):
		return false
	if not hint.has_method("has_completed_required_tutorials"):
		return false
	return bool(hint.has_completed_required_tutorials())


func _mid_tutorial_module_key(owner: Object) -> String:
	var character_type: Variant = BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher")
	if _character_runtime.is_commando(character_type):
		return "commando_firearm_tutorial_hint"
	if _character_runtime.is_viper(character_type):
		return "viper_practice_mode"
	return "skill_orb_tooltip_tutorial_hint"


func _is_skill_orb_tooltip_open(owner: Object, registry: Object) -> bool:
	var hover_state: Object = _get_instance(registry, "skill_orb_tooltip_hover_state")
	if hover_state == null or not hover_state.has_method("update_hover_state"):
		return false
	return not _get_dictionary(hover_state.update_hover_state(owner, registry)).is_empty()


func _is_junior_mika_tutorial_active(module_getter: Callable) -> bool:
	var junior_hint: Object = _get_module(module_getter, "junior_mika_tutorial_hint")
	return junior_hint != null and junior_hint.has_method("is_active") and bool(junior_hint.is_active())


func _draw_slot_highlight(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = max(rect.size.x, rect.size.y) * 0.5
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec() % 760) / 760.0 * TAU)
	var outer_radius: float = radius + 8.0 + pulse * 5.0
	canvas.draw_circle(center, outer_radius + 5.0, Color(0.0, 0.0, 0.0, 0.34 * alpha))
	canvas.draw_circle(center, outer_radius, Color(0.28, 0.86, 1.0, 0.20 * alpha))
	canvas.draw_circle(center, outer_radius, Color(0.44, 0.92, 1.0, 0.96 * alpha), false, 4.0)
	canvas.draw_rect(rect.grow(5.0), Color(1.0, 1.0, 1.0, 0.52 * alpha), false, 2.0)


func _draw_message(canvas: CanvasItem, view_size: Vector2, highlight_rect: Rect2, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var message: String = get_message()
	if message == "":
		return
	var font_size: int = _get_fit_font_size(font, message, view_size.x)
	var text_size: Vector2 = _get_text_size(font, message, font_size)
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.68)
	if highlight_rect.size != Vector2.ZERO:
		center.y = max(80.0, highlight_rect.position.y - 38.0)
	var padding := Vector2(22.0, 10.0)
	var panel_rect := Rect2(center - (text_size + padding * 2.0) * 0.5, text_size + padding * 2.0)
	_draw_round_rect(canvas, panel_rect, 9.0, Color(0.02, 0.04, 0.08, 0.76 * alpha))
	canvas.draw_rect(panel_rect, Color(0.58, 0.90, 1.0, 0.24 * alpha), false, 1.5)
	var baseline := Vector2(
		center.x - text_size.x * 0.5,
		center.y - text_size.y * 0.5 + font.get_ascent(font_size)
	)
	canvas.draw_string_outline(font, baseline, message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, Color(0.0, 0.0, 0.0, 0.80 * alpha))
	canvas.draw_string(font, baseline, message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.94, 0.98, 1.0, alpha))


func _draw_round_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(radius, 0.0), Vector2(rect.size.x - radius * 2.0, rect.size.y)), color)
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color)
	canvas.draw_circle(rect.position + Vector2(radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, color)
	canvas.draw_circle(rect.position + rect.size - Vector2(radius, radius), radius, color)


func _get_fit_font_size(font: Font, text: String, max_width: float) -> int:
	var font_size: int = FONT_SIZE
	var available_width: float = max(120.0, max_width - 72.0)
	while font_size > MIN_FONT_SIZE and _get_text_size(font, text, font_size).x > available_width:
		font_size -= 1
	return font_size


func _get_text_size(font: Font, text: String, font_size: int) -> Vector2:
	var cache_key := "%s|%d" % [text, font_size]
	if _text_size_cache.has(cache_key):
		var cached: Variant = _text_size_cache[cache_key]
		if cached is Vector2:
			return cached
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_text_size_cache[cache_key] = text_size
	return text_size


func _build_layout(registry: Object, view_size: Vector2, width: float, height: float) -> Dictionary:
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module != null and layout_module.has_method("build_game_layout"):
		return layout_module.build_game_layout(view_size, width, height)
	return {
		"game_size": Vector2(width, height),
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
	}


func _build_scene_config(registry: Object) -> Dictionary:
	var config: Object = _get_instance(registry, "battle_scene_config")
	if config != null and config.has_method("build_draw_context"):
		return config.build_draw_context()
	return {
		"width": 760.0,
		"height": 750.0,
		"pillar_width": 80.0,
	}


func _get_active_item_slot_capacity(registry: Object, item_count: int) -> int:
	var capacity := DEFAULT_SLOT_CAPACITY
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_slot_capacity"):
		capacity = max(capacity, int(runtime_perk_state.get_active_item_slot_capacity(DEFAULT_SLOT_CAPACITY)))
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_active_item_slot_capacity"):
		capacity = max(capacity, int(mythic_item_runtime.get_active_item_slot_capacity(capacity)))
	return max(capacity, item_count)


func _get_grip_style(owner: Object) -> String:
	if owner == null:
		return ""
	for key in ["tutorial_grip_style", "junior_mika_grip_style"]:
		if owner.has_meta(key):
			var normalized: String = _normalize_grip_style(str(owner.get_meta(key)))
			if normalized != "":
				return normalized
	return ""


func _normalize_grip_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if normalized in ["wasd_mouse", "wasd", "keyboard_mouse"]:
		return "wasd_mouse"
	if normalized in ["space_arrows", "space_arrow", "arrows", "arrow_keys", "arrows_space"]:
		return "space_arrows"
	if normalized in ["gamepad", "xbox", "controller", "pad"]:
		return "gamepad"
	return ""


func _refresh_language_state() -> bool:
	var language := LanguageSettings.get_language()
	if language == _last_language:
		return false
	_last_language = language
	return true


func _smooth_step(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
