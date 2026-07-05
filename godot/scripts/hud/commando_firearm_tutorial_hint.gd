extends RefCounted
# 코만도(테스트/주니어리그) 튜토리얼의 화기 안내. 두 트랙이 독립적으로 동작한다:
#   트랙1 (권총 발사): 대쉬 안내 완료 후 잠깐 있다가 "마우스 좌클릭 - 권총 발사"를
#     시간 기반으로 1회 표시. 이게 스매셔 스킬-오브 자리의 "중간 튜토리얼"이며,
#     완료되면 아이템/캐릭터정보 안내가 열린다(has_completed_required_tutorials).
#   트랙2 (화기 교체): 화기류 퍽이나 물자보급 대여로 두 번째 화기를 실제로 획득해서
#     교체가 의미 있어질 때(weapons.size() > 1) 비로소 "마우스 휠 - 화기 교체"를 1회 표시.
# 공용 키캡/마우스 렌더러로 그린다.

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")

const PISTOL_MESSAGE := "[LMB] - 권총 발사"
const SWAP_MESSAGE := "[WHEEL] ( 마우스 휠 돌리기 ) - 화기 교체"
const PISTOL_MESSAGE_KEY := "tutorial.commando.pistol.keyboard"
const SWAP_MESSAGE_KEY := "tutorial.commando.swap.keyboard"
const PISTOL_GAMEPAD_MESSAGE_KEY := "tutorial.commando.pistol.gamepad"
const SWAP_GAMEPAD_MESSAGE_KEY := "tutorial.commando.swap.gamepad"

const PISTOL_HINT_SECONDS := 4.5
const SWAP_HINT_SECONDS := 5.0
const FADE_SECONDS := 0.65
# 대쉬 튜토리얼 완료 이후 권총 안내 시작까지의 대기(스매셔 스킬-오브 단계와 동일 리듬).
const POST_DASH_DELAY_SECONDS := 5.0
const FONT_SIZE := 24
const MIN_FONT_SIZE := 18

var _character_runtime: Object = PlayerCharacterRuntime.new()
# 트랙1 (권총)
var _pistol_started := false
var _pistol_active := false
var _pistol_completed := false
var _pistol_elapsed := 0.0
var _post_dash_delay_elapsed := 0.0
# 트랙2 (화기 교체)
var _swap_shown := false
var _swap_active := false
var _swap_elapsed := 0.0
# 공통
var _grip_style := ""
var _last_language := ""


func update(delta: float, owner: Object, registry: Object = null, module_getter: Callable = Callable()) -> bool:
	var changed: bool = _refresh_language_state()
	changed = _update_pistol_track(delta, owner, module_getter) or changed
	changed = _update_swap_track(delta, owner, registry, module_getter) or changed
	return changed


func draw(canvas: CanvasItem, _owner: Object, _registry: Object, view_size: Vector2) -> void:
	if canvas == null or not is_active():
		return
	var alpha: float = get_alpha()
	if alpha <= 0.001:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var message: String = get_current_message()
	var font_size: int = TutorialHintKeycapRenderer.fit_font_size(font, message, view_size.x - 48.0, FONT_SIZE, MIN_FONT_SIZE)
	TutorialHintKeycapRenderer.draw_centered_line(canvas, font, message, get_draw_center(view_size), font_size, alpha)


func is_active() -> bool:
	return _pistol_active or _swap_active


# 아이템/캐릭터정보 안내가 기다리는 "중간 튜토리얼" = 권총 트랙만. 화기 교체는 나중에
# 조건부로 뜨는 별도 트랙이라 이 완료 판정에 넣지 않는다(화기를 영영 안 얻어도 무방).
func has_completed_required_tutorials() -> bool:
	return _pistol_completed


func get_draw_center(view_size: Vector2) -> Vector2:
	return Vector2(view_size.x * 0.5, view_size.y * 0.5)


func get_alpha() -> float:
	if _pistol_active:
		return _phase_alpha(_pistol_elapsed, PISTOL_HINT_SECONDS)
	if _swap_active:
		return _phase_alpha(_swap_elapsed, SWAP_HINT_SECONDS)
	return 0.0


func get_current_message() -> String:
	var gamepad: bool = _grip_style == "gamepad"
	if _swap_active:
		return LanguageSettings.translate(SWAP_GAMEPAD_MESSAGE_KEY, "왼쪽 스틱 누르기 - 화기 교체") if gamepad else LanguageSettings.translate(SWAP_MESSAGE_KEY, SWAP_MESSAGE)
	return LanguageSettings.translate(PISTOL_GAMEPAD_MESSAGE_KEY, "A / X - 발사") if gamepad else LanguageSettings.translate(PISTOL_MESSAGE_KEY, PISTOL_MESSAGE)


func get_snapshot() -> Dictionary:
	return {
		"active": is_active(),
		"pistol_active": _pistol_active,
		"pistol_completed": _pistol_completed,
		"pistol_elapsed": _pistol_elapsed,
		"swap_active": _swap_active,
		"swap_shown": _swap_shown,
		"alpha": get_alpha(),
		"message": get_current_message(),
		"grip_style": _grip_style,
		"post_dash_delay_elapsed": _post_dash_delay_elapsed,
	}


func _update_pistol_track(delta: float, owner: Object, module_getter: Callable) -> bool:
	if _pistol_active:
		var previous_elapsed: float = _pistol_elapsed
		_pistol_elapsed = min(PISTOL_HINT_SECONDS + FADE_SECONDS, _pistol_elapsed + max(0.0, delta))
		if _pistol_elapsed >= PISTOL_HINT_SECONDS:
			_pistol_active = false
			_pistol_completed = true
			return true
		return not is_equal_approx(previous_elapsed, _pistol_elapsed)
	if _pistol_started:
		return false
	if not _prerequisites_met(owner):
		_post_dash_delay_elapsed = 0.0
		return false
	if not _is_dash_tutorial_complete(module_getter):
		_post_dash_delay_elapsed = 0.0
		return false
	if _post_dash_delay_elapsed < POST_DASH_DELAY_SECONDS:
		_post_dash_delay_elapsed = min(POST_DASH_DELAY_SECONDS, _post_dash_delay_elapsed + max(0.0, delta))
		return false
	_grip_style = _get_grip_style(owner)
	if _grip_style == "":
		return false
	_pistol_started = true
	_pistol_active = true
	_pistol_elapsed = 0.0
	return true


func _update_swap_track(delta: float, owner: Object, registry: Object, module_getter: Callable) -> bool:
	if _swap_active:
		var previous_elapsed: float = _swap_elapsed
		_swap_elapsed = min(SWAP_HINT_SECONDS + FADE_SECONDS, _swap_elapsed + max(0.0, delta))
		if _swap_elapsed >= SWAP_HINT_SECONDS:
			_swap_active = false
			return true
		return not is_equal_approx(previous_elapsed, _swap_elapsed)
	if _swap_shown:
		return false
	# 화기 교체는 두 번째 화기(퍽/대여)를 실제로 획득했을 때만, 그리고 권총 안내나
	# 다른 튜토리얼 힌트와 겹치지 않을 때만 뜬다.
	if _pistol_active:
		return false
	if not _prerequisites_met(owner):
		return false
	if not _has_extra_firearm(registry):
		return false
	if _sibling_hint_blocking(module_getter):
		return false
	_grip_style = _get_grip_style(owner)
	if _grip_style == "":
		return false
	_swap_shown = true
	_swap_active = true
	_swap_elapsed = 0.0
	return true


func _phase_alpha(elapsed: float, hint_seconds: float) -> float:
	if elapsed < 0.0 or elapsed > hint_seconds:
		return 0.0
	if elapsed < FADE_SECONDS:
		return _smooth_step(elapsed / FADE_SECONDS)
	if elapsed > hint_seconds - FADE_SECONDS:
		return _smooth_step((hint_seconds - elapsed) / FADE_SECONDS)
	return 1.0


func _prerequisites_met(owner: Object) -> bool:
	if owner == null:
		return false
	return (
		BattleSceneConfig.normalize_league_mode(
			str(BattleSceneOwnerReader.get_value(owner, "ai_mode", "champion"))
		) == "junior"
		and _character_runtime.is_commando(BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher"))
		and _get_grip_style(owner) != ""
	)


func _is_dash_tutorial_complete(module_getter: Callable) -> bool:
	var junior_hint: Object = _get_module(module_getter, "junior_mika_tutorial_hint")
	if junior_hint == null or not junior_hint.has_method("has_completed_dash_tutorial"):
		return false
	return bool(junior_hint.has_completed_dash_tutorial())


func _has_extra_firearm(registry: Object) -> bool:
	var weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if weapon_controller == null or not weapon_controller.has_method("get_weapons"):
		return false
	var weapons: Variant = weapon_controller.get_weapons()
	return weapons is Array and (weapons as Array).size() > 1


func _sibling_hint_blocking(module_getter: Callable) -> bool:
	for key in ["junior_mika_tutorial_hint", "skill_orb_tooltip_tutorial_hint", "active_item_use_tutorial_hint", "character_info_tutorial_hint"]:
		var module: Object = _get_module(module_getter, key)
		if module != null and module.has_method("is_active") and bool(module.is_active()):
			return true
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


func _refresh_language_state() -> bool:
	var language := LanguageSettings.get_language()
	if language == _last_language:
		return false
	_last_language = language
	return is_active()


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
