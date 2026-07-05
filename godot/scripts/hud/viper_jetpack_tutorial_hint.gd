extends RefCounted
# 바이퍼(테스트/주니어리그) 체공(제트팩) 안내: 대쉬 안내 완료 후 잠깐 있다가
# "좌클릭/SPACE 홀드 - 체공"을 표시하고, 플레이어가 실제로 체공할 때까지 유지한다
# (대쉬 안내와 같은 행동 기반 종료). 연습모드(쉐백→마샬)는 이 안내 완료를 게이트로
# 시작한다. 바이퍼 스킬 절반(블레이드 러쉬/다이브 스트라이크 등)이 체공 전제라
# 기본 조작 단계에서 가르친다.

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")

const MESSAGE := "[LMB] 또는 SPACE 홀드 - 체공"
const MESSAGE_KEY := "tutorial.viper.jetpack.keyboard"
const GAMEPAD_MESSAGE_KEY := "tutorial.viper.jetpack.gamepad"

# 대쉬 안내 완료 후 체공 안내 시작까지의 여유.
const POST_DASH_DELAY_SECONDS := 2.5
const FADE_SECONDS := 0.65
const FONT_SIZE := 24
const MIN_FONT_SIZE := 18

var _character_runtime: Object = PlayerCharacterRuntime.new()
var _has_started := false
var _active := false
var _completed := false
var _elapsed := 0.0
var _grip_style := ""
var _last_language := ""
var _post_dash_delay_elapsed := 0.0


func update(delta: float, owner: Object, registry: Object = null, module_getter: Callable = Callable()) -> bool:
	var language_changed: bool = _refresh_language_state()
	if _active:
		var previous_elapsed: float = _elapsed
		_elapsed += max(0.0, delta)
		if _has_player_jetpacked(registry):
			_active = false
			_completed = true
			return true
		return language_changed or not is_equal_approx(previous_elapsed, _elapsed)
	if _has_started:
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
	_has_started = true
	_active = true
	_elapsed = 0.0
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
	var font_size: int = TutorialHintKeycapRenderer.fit_font_size(font, message, view_size.x - 48.0, FONT_SIZE, MIN_FONT_SIZE)
	TutorialHintKeycapRenderer.draw_centered_line(canvas, font, message, get_draw_center(view_size), font_size, alpha)


func is_active() -> bool:
	return _active


# 연습모드가 시작 게이트로 소비: 플레이어가 실제로 체공해 봤는가.
func has_completed_jetpack_tutorial() -> bool:
	return _completed


func get_draw_center(view_size: Vector2) -> Vector2:
	return Vector2(view_size.x * 0.5, view_size.y * 0.5)


func get_alpha() -> float:
	if not _active:
		return 0.0
	# 체공할 때까지 유지되는 안내라 페이드아웃은 없다.
	if _elapsed < FADE_SECONDS:
		return _smooth_step(_elapsed / FADE_SECONDS)
	return 1.0


func get_message() -> String:
	if _grip_style == "gamepad":
		return LanguageSettings.translate(GAMEPAD_MESSAGE_KEY, "A / X 홀드 - 체공")
	return LanguageSettings.translate(MESSAGE_KEY, MESSAGE)


func get_snapshot() -> Dictionary:
	return {
		"has_started": _has_started,
		"active": _active,
		"completed": _completed,
		"elapsed": _elapsed,
		"alpha": get_alpha(),
		"message": get_message(),
		"grip_style": _grip_style,
		"post_dash_delay_elapsed": _post_dash_delay_elapsed,
	}


func _has_player_jetpacked(registry: Object) -> bool:
	if registry == null or not registry.has_method("get_instance"):
		return false
	var jetpack: Variant = registry.get_instance("viper_jetpack_state")
	if typeof(jetpack) != TYPE_OBJECT or not is_instance_valid(jetpack):
		return false
	var jetpack_object: Object = jetpack as Object
	if jetpack_object.has_method("is_airborne") and bool(jetpack_object.is_airborne()):
		return true
	var active_value: Variant = jetpack_object.get("active")
	return active_value != null and bool(active_value)


func _prerequisites_met(owner: Object) -> bool:
	if owner == null:
		return false
	return (
		BattleSceneConfig.normalize_league_mode(
			str(BattleSceneOwnerReader.get_value(owner, "ai_mode", "champion"))
		) == "junior"
		and _character_runtime.is_viper(BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher"))
		and _get_grip_style(owner) != ""
	)


func _is_dash_tutorial_complete(module_getter: Callable) -> bool:
	var junior_hint: Object = _get_module(module_getter, "junior_mika_tutorial_hint")
	if junior_hint == null or not junior_hint.has_method("has_completed_dash_tutorial"):
		return false
	return bool(junior_hint.has_completed_dash_tutorial())


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
	return _active


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
