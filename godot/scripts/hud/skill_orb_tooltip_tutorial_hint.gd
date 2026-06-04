extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")
const SkillOrbTooltipTutorialHintGeometry := preload("res://scripts/hud/skill_orb_tooltip_tutorial_hint_geometry.gd")
const SkillOrbTooltipTutorialHintRenderer := preload("res://scripts/hud/skill_orb_tooltip_tutorial_hint_renderer.gd")

const TARGET_SKILLS := ["drive", "power_smashing"]
const FADE_SECONDS := 0.55
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
		_elapsed = min(SkillOrbTooltipTutorialHintRenderer.POINTER_FINISH_SECONDS, _elapsed + max(0.0, delta))
		if _can_complete_from_target_tooltip() and _is_target_tooltip_open(owner, registry):
			_complete_current_hint(owner, registry, true)
			return true
		if _phase == PHASE_POINTER and _elapsed >= SkillOrbTooltipTutorialHintRenderer.POINTER_FINISH_SECONDS:
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
	SkillOrbTooltipTutorialHintRenderer.draw_overlay(
		canvas,
		view_size,
		_phase,
		_elapsed,
		highlight_rect,
		get_message_lines(),
		_text_size_cache,
		alpha
	)


func is_active() -> bool:
	return _active


func blocks_battle_physics() -> bool:
	return _active


func get_alpha() -> float:
	if not _active:
		return 0.0
	if _elapsed < FADE_SECONDS:
		return SkillOrbTooltipTutorialHintRenderer.smooth_step(_elapsed / FADE_SECONDS)
	if _phase == PHASE_POINTER and _elapsed > SkillOrbTooltipTutorialHintRenderer.POINTER_FINISH_SECONDS - FADE_SECONDS:
		return SkillOrbTooltipTutorialHintRenderer.smooth_step(
			(SkillOrbTooltipTutorialHintRenderer.POINTER_FINISH_SECONDS - _elapsed) / FADE_SECONDS
		)
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
		"pointer_progress": SkillOrbTooltipTutorialHintRenderer.pointer_progress(_phase, _elapsed),
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
	return SkillOrbTooltipTutorialHintGeometry.get_highlight_rect(
		owner,
		registry,
		view_size,
		_target_skill,
		layout_helper,
		fallback_orb_renderer
	)


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


func _refresh_language_state() -> bool:
	var language := LanguageSettings.get_language()
	if language == _last_language:
		return false
	_last_language = language
	return true


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
