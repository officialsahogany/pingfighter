extends RefCounted
# 주니어리그 미카 튜토리얼 5단계: 스킬 툴팁 안내(3단계)와 아이템 사용 안내(4단계)가
# 지나고 잠시 뒤, "TAB - 캐릭터 정보 확인" 안내를 화면 중앙에 한 번 띄운다.
# 앞 단계들과 겹치지 않도록 형제 힌트가 활성 중이면 대기한다.

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")

const HINT_SECONDS := 5.0
const FADE_SECONDS := 0.55
# 스킬 툴팁 튜토리얼 완료 이후 대기 시간. 아이템 사용 안내(스킬 완료 +20s 시작, 5s 표시)가
# 끝난 뒤 자연스럽게 이어지도록 그보다 넉넉히 뒤에 둔다.
const POST_ITEM_TUTORIAL_DELAY_SECONDS := 26.0
const FONT_SIZE := 24
const MIN_FONT_SIZE := 18

var _character_runtime: Object = PlayerCharacterRuntime.new()
var _active := false
var _elapsed := 0.0
var _shown := false
var _grip_style := ""
var _last_language := ""
var _delay_started := false
var _delay_elapsed := 0.0


func update(delta: float, owner: Object, _registry: Object, module_getter: Callable = Callable()) -> bool:
	var language_changed: bool = _refresh_language_state()
	if _active:
		var previous_elapsed: float = _elapsed
		_elapsed = min(HINT_SECONDS, _elapsed + max(0.0, delta))
		if _elapsed >= HINT_SECONDS:
			_active = false
			return true
		return language_changed or not is_equal_approx(previous_elapsed, _elapsed)
	if _shown:
		return false
	if not _prerequisites_met(owner, module_getter):
		_reset_delay_tracking()
		return false

	if not _delay_started:
		_delay_started = true
		_delay_elapsed = min(POST_ITEM_TUTORIAL_DELAY_SECONDS, max(0.0, delta))
		return false
	if _delay_elapsed < POST_ITEM_TUTORIAL_DELAY_SECONDS:
		_delay_elapsed = min(POST_ITEM_TUTORIAL_DELAY_SECONDS, _delay_elapsed + max(0.0, delta))
		return false
	if _display_blocked(module_getter):
		return false
	_start(owner)
	return true


func draw(canvas: CanvasItem, _owner: Object, _registry: Object, view_size: Vector2) -> void:
	if canvas == null or not _active:
		return
	var alpha: float = get_alpha()
	if alpha <= 0.001:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var message: String = get_message()
	if message == "":
		return
	var font_size: int = TutorialHintKeycapRenderer.fit_font_size(font, message, view_size.x - 48.0, FONT_SIZE, MIN_FONT_SIZE)
	TutorialHintKeycapRenderer.draw_centered_line(canvas, font, message, get_draw_center(view_size), font_size, alpha)


func is_active() -> bool:
	return _active


func has_shown() -> bool:
	return _shown


func get_draw_center(view_size: Vector2) -> Vector2:
	return Vector2(view_size.x * 0.5, view_size.y * 0.62)


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
				"tutorial.character_info.gamepad",
				"일시정지 메뉴에서 캐릭터 정보 확인"
			)
		_:
			return LanguageSettings.translate(
				"tutorial.character_info.keyboard",
				"TAB - 캐릭터 정보 확인"
			)


func get_snapshot() -> Dictionary:
	return {
		"active": _active,
		"elapsed": _elapsed,
		"alpha": get_alpha(),
		"shown": _shown,
		"grip_style": _grip_style,
		"message": get_message(),
		"language": _last_language,
		"delay_started": _delay_started,
		"delay_elapsed": _delay_elapsed,
		"delay_ready": _is_delay_ready(),
	}


func _start(owner: Object) -> void:
	_grip_style = _get_grip_style(owner)
	_elapsed = 0.0
	_active = true
	_shown = true


func _prerequisites_met(owner: Object, module_getter: Callable) -> bool:
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


func _is_starter_tutorial_character(character_type: Variant) -> bool:
	return (
		_character_runtime.normalize(character_type) == "smasher"
		or _character_runtime.is_commando(character_type)
		or _character_runtime.is_viper(character_type)
	)


func _display_blocked(module_getter: Callable) -> bool:
	return (
		_is_module_active(module_getter, "junior_mika_tutorial_hint")
		or _is_module_active(module_getter, "skill_orb_tooltip_tutorial_hint")
		or _is_module_active(module_getter, "commando_firearm_tutorial_hint")
		or _is_module_active(module_getter, "viper_practice_mode")
		or _is_module_active(module_getter, "active_item_use_tutorial_hint")
	)


func _reset_delay_tracking() -> void:
	_delay_started = false
	_delay_elapsed = 0.0


func _is_delay_ready() -> bool:
	return _delay_started and _delay_elapsed >= POST_ITEM_TUTORIAL_DELAY_SECONDS


# 캐릭터별 중간 튜토리얼 완료 여부: 스매셔=스킬-오브, 코만도=화기 안내.
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


func _is_module_active(module_getter: Callable, key: String) -> bool:
	var module: Object = _get_module(module_getter, key)
	return module != null and module.has_method("is_active") and bool(module.is_active())


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
