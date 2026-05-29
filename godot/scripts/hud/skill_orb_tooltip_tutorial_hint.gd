extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")

const TARGET_SKILLS := ["drive", "power_smashing"]
const FADE_SECONDS := 0.55
const POINTER_TRAVEL_SECONDS := 1.25
const POINTER_FINISH_SECONDS := 1.45
const POINTER_TRAIL_COUNT := 6
const FONT_SIZE := 23
const MIN_FONT_SIZE := 17
const FOCUS_SHADOW_ALPHA := 0.68
const FOCUS_GROW := 22.0
const PHASE_DIALOGUE := "dialogue"
const PHASE_POINTER := "pointer"
const FINAL_DIALOGUE_INDEX := 2
const POST_DASH_TUTORIAL_DELAY_SECONDS := 5.0
const BETWEEN_SKILL_TUTORIAL_DELAY_SECONDS := 5.0
const QUICK_POINTER_SKILLS := {
	"power_smashing": true,
}

var layout_helper: Object = Stage1PillarUiLayout.new()
var fallback_orb_renderer: Object = SmasherSkillOrbRenderer.new()
var _shown_skills: Dictionary = {}
var _completed_skills: Dictionary = {}
var _active := false
var _elapsed := 0.0
var _target_skill := ""
var _grip_style := ""
var _phase := PHASE_DIALOGUE
var _dialogue_index := 0
var _last_language := ""
var _text_size_cache: Dictionary = {}
var _post_dash_delay_elapsed := 0.0
var _post_completion_delay_elapsed: Dictionary = {}


func update(delta: float, owner: Object, registry: Object, module_getter: Callable = Callable()) -> bool:
	var language_changed: bool = _refresh_language_state()
	if _active:
		var previous_elapsed: float = _elapsed
		_elapsed = min(POINTER_FINISH_SECONDS, _elapsed + max(0.0, delta))
		if _can_complete_from_target_tooltip() and _is_target_tooltip_open(owner, registry):
			_complete_current_hint(owner, registry, true)
			return true
		if _phase == PHASE_POINTER and _elapsed >= POINTER_FINISH_SECONDS:
			_complete_current_hint(owner, registry, false)
			return true
		return language_changed or not is_equal_approx(previous_elapsed, _elapsed)
	if not _should_start(owner, module_getter):
		return false
	_update_start_delays(delta, module_getter)
	var ready_skill: String = _find_ready_target_skill(owner, registry)
	if ready_skill == "":
		return false
	if not _is_start_delay_ready(ready_skill, module_getter):
		return false
	_start(ready_skill, owner)
	return true


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if canvas == null or not _active:
		return
	var alpha: float = get_alpha()
	if alpha <= 0.001:
		return
	var highlight_rect: Rect2 = get_highlight_rect(owner, registry, view_size)
	if highlight_rect.size != Vector2.ZERO:
		_draw_focus_shadow(canvas, view_size, highlight_rect, alpha)
		_draw_orb_highlight(canvas, highlight_rect, alpha)
		if _phase == PHASE_POINTER:
			_draw_guidance_pointer(canvas, view_size, highlight_rect, alpha)
	else:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, FOCUS_SHADOW_ALPHA * alpha))
	_draw_message(canvas, view_size, alpha)


func is_active() -> bool:
	return _active


func blocks_battle_physics() -> bool:
	return _active


func get_alpha() -> float:
	if not _active:
		return 0.0
	if _elapsed < FADE_SECONDS:
		return _smooth_step(_elapsed / FADE_SECONDS)
	if _phase == PHASE_POINTER and _elapsed > POINTER_FINISH_SECONDS - FADE_SECONDS:
		return _smooth_step((POINTER_FINISH_SECONDS - _elapsed) / FADE_SECONDS)
	return 1.0


func handle_input(event: InputEvent, owner: Object, registry: Object, _view_size: Vector2 = Vector2.ZERO) -> bool:
	if not _active:
		return false
	if not _is_advance_event(event):
		return true
	if _phase == PHASE_POINTER:
		return true
	if _dialogue_index < FINAL_DIALOGUE_INDEX:
		_dialogue_index += 1
		_elapsed = 0.0
		return true
	_phase = PHASE_POINTER
	_elapsed = 0.0
	if _is_target_tooltip_open(owner, registry):
		_complete_current_hint(owner, registry, true)
	return true


func get_message() -> String:
	var lines: Array[String] = get_message_lines()
	var message := ""
	for i in range(lines.size()):
		if i > 0:
			message += "\n"
		message += lines[i]
	return message


func get_message_lines() -> Array[String]:
	if _target_skill == "":
		return []
	if _phase == PHASE_POINTER and _is_quick_pointer_skill(_target_skill):
		return [LanguageSettings.translate(
			"tutorial.skill_tooltip.quick.%s" % _target_skill,
			"파워스매싱도 준비되었습니다. 사용법을 확인해보세요!"
		)]
	if _phase != PHASE_DIALOGUE:
		return []
	var skill_label: String = LanguageSettings.translate(
		"tutorial.skill_tooltip.skill.%s" % _target_skill,
		_target_skill
	)
	var headline_template: String = LanguageSettings.translate(
		"tutorial.skill_tooltip.notice.headline",
		"%s 사용 준비 완료!"
	)
	var headline: String = headline_template % skill_label if headline_template.find("%s") >= 0 else headline_template
	var body: String = LanguageSettings.translate(
		"tutorial.skill_tooltip.notice.body",
		"링피아에서는 스킬마다 발동 방법이 다릅니다."
	)
	var instruction_key: String = "tutorial.skill_tooltip.notice.%s" % _grip_style
	var instruction_fallback: String
	match _grip_style:
		"wasd_mouse":
			instruction_fallback = "스킬구슬에 마우스를 올려 발동 방법을 확인하세요."
		"space_arrows":
			instruction_fallback = "Shift로 스킬구슬 설명을 열어 발동 방법을 확인하세요."
		"gamepad":
			instruction_fallback = "View 버튼으로 스킬구슬 설명을 열어 발동 방법을 확인하세요."
		_:
			instruction_fallback = "스킬구슬 설명에서 발동 방법을 확인하세요."
	var instruction: String = LanguageSettings.translate(instruction_key, instruction_fallback)
	var lines: Array[String] = [headline, body, instruction]
	return [lines[clampi(_dialogue_index, 0, FINAL_DIALOGUE_INDEX)]]


func get_snapshot() -> Dictionary:
	return {
		"active": _active,
		"elapsed": _elapsed,
		"alpha": get_alpha(),
		"target_skill": _target_skill,
		"grip_style": _grip_style,
		"phase": _phase,
		"dialogue_index": _dialogue_index,
		"message": get_message(),
		"message_lines": get_message_lines(),
		"pointer_progress": _get_pointer_progress(),
		"shown_skills": _shown_skills.duplicate(),
		"completed_skills": _completed_skills.duplicate(),
		"post_dash_delay_elapsed": _post_dash_delay_elapsed,
		"post_completion_delay_elapsed": _post_completion_delay_elapsed.duplicate(),
		"language": _last_language,
	}


func has_completed_required_tutorials() -> bool:
	for skill_value in TARGET_SKILLS:
		if not bool(_completed_skills.get(str(skill_value), false)):
			return false
	return true


func get_highlight_rect(owner: Object, registry: Object, view_size: Vector2) -> Rect2:
	if _target_skill == "":
		return Rect2()
	var skill_config: Object = _get_instance(registry, "smasher_skill_config")
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return Rect2()
	var snapshot: Dictionary = _get_dict(skill_config.get_snapshot())
	var equipped_skills: Array = _get_array(snapshot.get("equipped_skills", []))
	var target_index := -1
	for i in range(equipped_skills.size()):
		if str(equipped_skills[i]) == _target_skill:
			target_index = i
			break
	if target_index < 0:
		return Rect2()
	var scene_config: Dictionary = _build_scene_config(registry)
	var layout: Dictionary = _build_layout(
		registry,
		view_size,
		float(scene_config.get("width", 760.0)),
		float(scene_config.get("height", 750.0))
	)
	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", Vector2(760.0, 750.0))
	var ui_layout: Dictionary = layout_helper.build_layout(game_offset, game_size, {
		"height": float(scene_config.get("height", 750.0)),
	})
	var scale_factor: float = float(ui_layout.get("scale_factor", 1.0))
	var skill_context: Dictionary = layout_helper.build_skill_orb_context({
		"skill_state": _get_instance(registry, "smasher_skill_state"),
		"selected_character_type": "smasher",
		"skill_config_snapshot": snapshot,
		"special_gauge": BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0),
	}, _get_instance(registry, "pillar_orb_drawer"))
	var orb_renderer: Object = _get_instance(registry, "smasher_skill_orb_renderer")
	if orb_renderer == null or not orb_renderer.has_method("get_slot_positions"):
		orb_renderer = fallback_orb_renderer
	var positions: Array = orb_renderer.get_slot_positions(
		_get_vector2(ui_layout, "left_center", Vector2.ZERO),
		float(ui_layout.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	if target_index >= positions.size():
		return Rect2()
	var icon_radius: float = float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var center: Vector2 = _as_vector2(positions[target_index], Vector2.ZERO)
	return Rect2(center - Vector2(icon_radius, icon_radius), Vector2(icon_radius * 2.0, icon_radius * 2.0))


func _start(skill_name: String, owner: Object) -> void:
	_target_skill = skill_name
	_grip_style = _get_grip_style(owner)
	_elapsed = 0.0
	if _is_quick_pointer_skill(skill_name):
		_phase = PHASE_POINTER
		_dialogue_index = FINAL_DIALOGUE_INDEX
	else:
		_phase = PHASE_DIALOGUE
		_dialogue_index = 0
	_active = true
	_shown_skills[skill_name] = true


func _complete_current_hint(owner: Object, registry: Object, tooltip_is_open: bool) -> void:
	var completed_skill: String = _target_skill
	if _target_skill != "":
		_completed_skills[_target_skill] = true
		_seed_next_skill_delay(completed_skill)
	if tooltip_is_open:
		_queue_target_tooltip_overlay(owner, registry)
	_active = false


func _can_complete_from_target_tooltip() -> bool:
	return _phase == PHASE_POINTER or (_phase == PHASE_DIALOGUE and _dialogue_index >= FINAL_DIALOGUE_INDEX)


func _is_quick_pointer_skill(skill_name: String) -> bool:
	return bool(QUICK_POINTER_SKILLS.get(skill_name, false))


func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		return key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		return joy_event.pressed and joy_event.button_index == JOY_BUTTON_A
	return GamepadInput.is_confirm_event(event)


func _is_target_tooltip_open(owner: Object, registry: Object) -> bool:
	if _target_skill == "":
		return false
	var hover_state: Object = _get_instance(registry, "skill_orb_tooltip_hover_state")
	if hover_state == null or not hover_state.has_method("update_hover_state"):
		return false
	var result: Dictionary = _get_dict(hover_state.update_hover_state(owner, registry))
	return str(result.get("skill_name", "")) == _target_skill


func _queue_target_tooltip_overlay(owner: Object, registry: Object) -> void:
	var tooltip_driver: Object = _get_instance(registry, "battle_scene_skill_tooltip_driver")
	if tooltip_driver != null and tooltip_driver.has_method("queue_tooltip_overlay_redraw"):
		tooltip_driver.queue_tooltip_overlay_redraw(owner, registry)


func _should_start(owner: Object, module_getter: Callable) -> bool:
	if owner == null:
		return false
	if _is_junior_mika_tutorial_blocking(module_getter):
		return false
	return (
		_normalize_league_mode(str(BattleSceneOwnerReader.get_value(owner, "ai_mode", "champion"))) == "junior"
		and _normalize_character_type(BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher")) == "smasher"
		and _get_grip_style(owner) != ""
	)


func _update_start_delays(delta: float, module_getter: Callable) -> void:
	_update_post_dash_delay(delta, module_getter)
	_update_post_completion_delays(delta)


func _update_post_dash_delay(delta: float, module_getter: Callable) -> void:
	if _has_any_skill_started():
		_post_dash_delay_elapsed = POST_DASH_TUTORIAL_DELAY_SECONDS
		return
	var junior_hint: Object = _get_module(module_getter, "junior_mika_tutorial_hint")
	if junior_hint == null or not junior_hint.has_method("has_completed_dash_tutorial"):
		_post_dash_delay_elapsed = POST_DASH_TUTORIAL_DELAY_SECONDS
		return
	if not bool(junior_hint.has_completed_dash_tutorial()):
		_post_dash_delay_elapsed = 0.0
		return
	_post_dash_delay_elapsed = min(
		POST_DASH_TUTORIAL_DELAY_SECONDS,
		_post_dash_delay_elapsed + max(0.0, delta)
	)


func _update_post_completion_delays(delta: float) -> void:
	for i in range(1, TARGET_SKILLS.size()):
		var skill_name := str(TARGET_SKILLS[i])
		var previous_skill := str(TARGET_SKILLS[i - 1])
		if bool(_shown_skills.get(skill_name, false)):
			continue
		if not bool(_completed_skills.get(previous_skill, false)):
			_post_completion_delay_elapsed.erase(skill_name)
			continue
		var elapsed: float = float(_post_completion_delay_elapsed.get(skill_name, 0.0))
		_post_completion_delay_elapsed[skill_name] = min(
			BETWEEN_SKILL_TUTORIAL_DELAY_SECONDS,
			elapsed + max(0.0, delta)
		)


func _is_start_delay_ready(skill_name: String, module_getter: Callable) -> bool:
	if not _is_post_dash_delay_ready(module_getter):
		return false
	var previous_skill: String = _get_previous_target_skill(skill_name)
	if previous_skill == "":
		return true
	return float(_post_completion_delay_elapsed.get(skill_name, 0.0)) >= BETWEEN_SKILL_TUTORIAL_DELAY_SECONDS


func _is_post_dash_delay_ready(module_getter: Callable) -> bool:
	if _has_any_skill_started():
		return true
	var junior_hint: Object = _get_module(module_getter, "junior_mika_tutorial_hint")
	if junior_hint == null or not junior_hint.has_method("has_completed_dash_tutorial"):
		return true
	return _post_dash_delay_elapsed >= POST_DASH_TUTORIAL_DELAY_SECONDS


func _seed_next_skill_delay(completed_skill: String) -> void:
	var completed_index: int = TARGET_SKILLS.find(completed_skill)
	if completed_index < 0 or completed_index + 1 >= TARGET_SKILLS.size():
		return
	var next_skill := str(TARGET_SKILLS[completed_index + 1])
	if not _post_completion_delay_elapsed.has(next_skill):
		_post_completion_delay_elapsed[next_skill] = 0.0


func _get_previous_target_skill(skill_name: String) -> String:
	var index: int = TARGET_SKILLS.find(skill_name)
	if index <= 0:
		return ""
	return str(TARGET_SKILLS[index - 1])


func _has_any_skill_started() -> bool:
	for skill_value in TARGET_SKILLS:
		if bool(_shown_skills.get(str(skill_value), false)):
			return true
	return false


func _find_ready_target_skill(owner: Object, registry: Object) -> String:
	var skill_config: Object = _get_instance(registry, "smasher_skill_config")
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return ""
	var snapshot: Dictionary = _get_dict(skill_config.get_snapshot())
	var equipped_skills: Array = _get_array(snapshot.get("equipped_skills", []))
	var skill_costs: Dictionary = _get_dict(snapshot.get("skill_costs", {}))
	var cooldown_seconds: Dictionary = _get_dict(snapshot.get("cooldown_seconds", {}))
	var skill_state: Object = _get_instance(registry, "smasher_skill_state")
	var gauge: float = float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0))
	var time_now: int = Time.get_ticks_msec()
	for skill_value in TARGET_SKILLS:
		var skill_name := str(skill_value)
		if bool(_shown_skills.get(skill_name, false)):
			continue
		if not equipped_skills.has(skill_name):
			continue
		if gauge + 0.001 < float(skill_costs.get(skill_name, 0.0)):
			continue
		if _is_skill_on_cooldown(skill_state, skill_name, time_now, float(cooldown_seconds.get(skill_name, 0.0))):
			continue
		return skill_name
	return ""


func _is_skill_on_cooldown(skill_state: Object, skill_name: String, time_now: int, cooldown_seconds: float) -> bool:
	if skill_state == null or not skill_state.has_method("get_cooldown_remaining"):
		return false
	return float(skill_state.get_cooldown_remaining(skill_name, time_now, cooldown_seconds)) > 0.0


func _is_junior_mika_tutorial_blocking(module_getter: Callable) -> bool:
	var junior_hint: Object = _get_module(module_getter, "junior_mika_tutorial_hint")
	if junior_hint == null:
		return false
	if junior_hint.has_method("is_active") and bool(junior_hint.is_active()):
		return true
	if junior_hint.has_method("has_completed_dash_tutorial"):
		return not bool(junior_hint.has_completed_dash_tutorial())
	return false


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


func _normalize_league_mode(mode: String) -> String:
	var normalized: String = mode.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized == "junior" or normalized == "juniorleague":
		return "junior"
	if normalized == "mythic" or normalized == "mythicleague":
		return "mythic"
	return "champion"


func _normalize_character_type(value: Variant) -> String:
	var normalized: String = str(value).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	if normalized == "optimus" or normalized == "io":
		return "optimus"
	return "smasher"


func _draw_orb_highlight(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = max(rect.size.x, rect.size.y) * 0.5
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec() % 900) / 900.0 * TAU)
	var outer_radius: float = radius + 10.0 + 5.0 * pulse
	canvas.draw_circle(center, outer_radius + 4.0, Color(0.0, 0.0, 0.0, 0.28 * alpha))
	canvas.draw_circle(center, outer_radius, Color(1.0, 0.92, 0.28, 0.16 * alpha))
	canvas.draw_circle(center, outer_radius, Color(1.0, 0.92, 0.28, 0.92 * alpha), false, 4.0)
	canvas.draw_circle(center, radius + 4.0, Color(1.0, 1.0, 1.0, 0.64 * alpha), false, 2.0)


func _draw_guidance_pointer(canvas: CanvasItem, view_size: Vector2, target_rect: Rect2, alpha: float) -> void:
	if target_rect.size == Vector2.ZERO:
		return
	var start: Vector2 = _get_pointer_start(view_size, target_rect)
	var target: Vector2 = target_rect.get_center() + Vector2(9.0, 8.0)
	var control: Vector2 = Vector2(
		lerpf(start.x, target.x, 0.52),
		min(start.y, target.y) - max(64.0, view_size.y * 0.08)
	)
	var progress: float = _get_pointer_progress()
	for i in range(POINTER_TRAIL_COUNT, 0, -1):
		var trail_progress: float = clampf(progress - float(i) * 0.075, 0.0, 1.0)
		if progress <= 0.02 and trail_progress <= 0.0:
			continue
		var trail_alpha: float = alpha * (1.0 - float(i) / float(POINTER_TRAIL_COUNT + 1)) * 0.34
		_draw_mouse_cursor(canvas, _quadratic_bezier(start, control, target, trail_progress), 0.90, trail_alpha)
	var cursor_pos: Vector2 = _quadratic_bezier(start, control, target, progress)
	_draw_mouse_cursor(canvas, cursor_pos, 1.0, alpha)
	if progress >= 0.96:
		var click_alpha: float = alpha * _smooth_step((progress - 0.96) / 0.04)
		var click_radius: float = target_rect.size.x * 0.46 + 8.0 * sin(float(Time.get_ticks_msec() % 420) / 420.0 * TAU)
		canvas.draw_circle(target_rect.get_center(), click_radius, Color(1.0, 1.0, 1.0, 0.28 * click_alpha), false, 2.0)


func _draw_mouse_cursor(canvas: CanvasItem, position: Vector2, scale: float, alpha: float) -> void:
	if alpha <= 0.001:
		return
	var base_points: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(0.0, 31.0),
		Vector2(8.0, 23.0),
		Vector2(13.0, 36.0),
		Vector2(20.0, 33.0),
		Vector2(15.0, 21.0),
		Vector2(27.0, 21.0),
	]
	var points := PackedVector2Array()
	for point in base_points:
		points.append(position + point * scale)
	canvas.draw_colored_polygon(points, Color(0.95, 0.98, 1.0, 0.88 * alpha))
	canvas.draw_polyline(
		PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[6], points[0]]),
		Color(0.02, 0.04, 0.08, 0.82 * alpha),
		2.0 * scale,
		true
	)
	canvas.draw_line(
		position + Vector2(5.0, 5.0) * scale,
		position + Vector2(15.0, 17.0) * scale,
		Color(0.42, 0.78, 1.0, 0.42 * alpha),
		1.5 * scale
	)


func _draw_focus_shadow(canvas: CanvasItem, view_size: Vector2, rect: Rect2, alpha: float) -> void:
	var screen_rect := Rect2(Vector2.ZERO, view_size)
	var focus_rect: Rect2 = rect.grow(FOCUS_GROW).intersection(screen_rect)
	if focus_rect.size.x <= 0.0 or focus_rect.size.y <= 0.0:
		canvas.draw_rect(screen_rect, Color(0.0, 0.0, 0.0, FOCUS_SHADOW_ALPHA * alpha))
		return
	var shadow_color := Color(0.0, 0.0, 0.0, FOCUS_SHADOW_ALPHA * alpha)
	if focus_rect.position.y > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(view_size.x, focus_rect.position.y)), shadow_color)
	if focus_rect.end.y < view_size.y:
		canvas.draw_rect(Rect2(Vector2(0.0, focus_rect.end.y), Vector2(view_size.x, view_size.y - focus_rect.end.y)), shadow_color)
	if focus_rect.position.x > 0.0:
		canvas.draw_rect(Rect2(Vector2(0.0, focus_rect.position.y), Vector2(focus_rect.position.x, focus_rect.size.y)), shadow_color)
	if focus_rect.end.x < view_size.x:
		canvas.draw_rect(Rect2(Vector2(focus_rect.end.x, focus_rect.position.y), Vector2(view_size.x - focus_rect.end.x, focus_rect.size.y)), shadow_color)


func _draw_message(canvas: CanvasItem, view_size: Vector2, alpha: float) -> void:
	if _phase != PHASE_DIALOGUE and not (_phase == PHASE_POINTER and _is_quick_pointer_skill(_target_skill)):
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var lines: Array[String] = get_message_lines()
	if lines.is_empty():
		return
	var font_size: int = _get_fit_font_size(font, lines, view_size.x)
	var text_size: Vector2 = _get_text_block_size(font, lines, font_size)
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.53)
	var padding := Vector2(24.0, 14.0)
	var panel_rect := Rect2(center - (text_size + padding * 2.0) * 0.5, text_size + padding * 2.0)
	_draw_round_rect(canvas, panel_rect, 9.0, Color(0.02, 0.04, 0.08, 0.68 * alpha))
	canvas.draw_rect(panel_rect, Color(0.88, 0.96, 1.0, 0.18 * alpha), false, 1.5)
	var line_height: float = _get_line_height(font, font_size)
	var line_gap := 5.0
	var y: float = center.y - text_size.y * 0.5 + font.get_ascent(font_size)
	for i in range(lines.size()):
		var line: String = lines[i]
		var line_width: float = _get_text_size(font, line, font_size).x
		var baseline := Vector2(center.x - line_width * 0.5, y)
		var text_color := Color(0.94, 0.98, 1.0, alpha)
		if i == 0:
			text_color = Color(1.0, 0.94, 0.58, alpha)
		canvas.draw_string_outline(font, baseline, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, Color(0.0, 0.0, 0.0, 0.80 * alpha))
		canvas.draw_string(font, baseline, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
		y += line_height + line_gap


func _draw_round_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(radius, 0.0), Vector2(rect.size.x - radius * 2.0, rect.size.y)), color)
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color)
	canvas.draw_circle(rect.position + Vector2(radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, color)
	canvas.draw_circle(rect.position + rect.size - Vector2(radius, radius), radius, color)


func _get_fit_font_size(font: Font, lines: Array[String], max_width: float) -> int:
	var font_size: int = FONT_SIZE
	var available_width: float = max(120.0, max_width - 72.0)
	while font_size > MIN_FONT_SIZE and _get_text_block_size(font, lines, font_size).x > available_width:
		font_size -= 1
	return font_size


func _get_text_block_size(font: Font, lines: Array[String], font_size: int) -> Vector2:
	var max_width := 0.0
	for line in lines:
		max_width = max(max_width, _get_text_size(font, line, font_size).x)
	var line_gap := 5.0
	var height: float = _get_line_height(font, font_size) * float(lines.size())
	if lines.size() > 1:
		height += line_gap * float(lines.size() - 1)
	return Vector2(max_width, height)


func _get_text_size(font: Font, text: String, font_size: int) -> Vector2:
	var cache_key := "%s|%d" % [text, font_size]
	if _text_size_cache.has(cache_key):
		var cached: Variant = _text_size_cache[cache_key]
		if cached is Vector2:
			return cached
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_text_size_cache[cache_key] = text_size
	return text_size


func _get_line_height(font: Font, font_size: int) -> float:
	return max(1.0, font.get_string_size("Ag", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).y)


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


func _refresh_language_state() -> bool:
	var language := LanguageSettings.get_language()
	if language == _last_language:
		return false
	_last_language = language
	return true


func _smooth_step(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _get_pointer_progress() -> float:
	if _phase != PHASE_POINTER:
		return 0.0
	return _smooth_step(clampf(_elapsed / POINTER_TRAVEL_SECONDS, 0.0, 1.0))


func _get_pointer_start(view_size: Vector2, target_rect: Rect2) -> Vector2:
	var side: float = 1.0 if target_rect.get_center().x < view_size.x * 0.5 else -1.0
	return Vector2(
		clampf(view_size.x * 0.5 + view_size.x * 0.18 * side, 72.0, view_size.x - 72.0),
		clampf(view_size.y * 0.56, 96.0, view_size.y - 96.0)
	)


func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return a * inv * inv + b * 2.0 * inv * t + c * t * t


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


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
