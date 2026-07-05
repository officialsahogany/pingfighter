extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")

const MOVE_MESSAGE := "방향키 ← / → 또는 A / D - 이동"
const DASH_MESSAGE := "← / → 이동 중 ↓ / S - 대쉬"
const MOVE_MESSAGE_KEY := "tutorial.mika.move.default"
const DASH_MESSAGE_KEY := "tutorial.mika.dash.default"
const MOVE_MESSAGE_KEYS := {
	"wasd_mouse": "tutorial.mika.move.wasd_mouse",
	"space_arrows": "tutorial.mika.move.space_arrows",
	"gamepad": "tutorial.mika.move.gamepad",
}
const DASH_MESSAGE_KEYS := {
	"wasd_mouse": "tutorial.mika.dash.wasd_mouse",
	"space_arrows": "tutorial.mika.dash.space_arrows",
	"gamepad": "tutorial.mika.dash.gamepad",
}
const MOVE_START_SECONDS := 0.0
const DASH_START_SECONDS := 6.5
const HINT_SECONDS := 4.2
const FADE_SECONDS := 0.65
const FONT_SIZE := 24
const MIN_FONT_SIZE := 18

var _has_started := false
var _active := false
var _elapsed := 0.0
var _dash_tutorial_completed := false
var _grip_style := ""
var _last_language := ""
var _character_runtime: Object = PlayerCharacterRuntime.new()


func update(delta: float, owner: Object, registry: Object = null) -> bool:
	var language_changed: bool = _refresh_language_state()
	if not _has_started and _should_start(owner):
		_grip_style = _get_grip_style(owner)
		if _grip_style == "":
			return false
		_has_started = true
		_active = true
		_elapsed = 0.0
		return true
	if not _active:
		return false
	if _has_player_dash_started(registry):
		_dash_tutorial_completed = true
		_active = false
		return true
	var previous_elapsed: float = _elapsed
	var next_elapsed: float = _elapsed + max(0.0, delta)
	_elapsed = min(next_elapsed, DASH_START_SECONDS + FADE_SECONDS) if next_elapsed >= DASH_START_SECONDS else next_elapsed
	return language_changed or not is_equal_approx(previous_elapsed, _elapsed)


func draw(canvas: CanvasItem, _owner: Object, view_size: Vector2) -> void:
	if canvas == null or not _active:
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
	return _active


func has_completed_dash_tutorial() -> bool:
	return _dash_tutorial_completed


func get_draw_center(view_size: Vector2) -> Vector2:
	return Vector2(view_size.x * 0.5, view_size.y * 0.5)


func get_alpha() -> float:
	if not _active:
		return 0.0
	var local_elapsed: float = _get_current_hint_elapsed()
	if local_elapsed < 0.0:
		return 0.0
	if _elapsed >= DASH_START_SECONDS:
		if local_elapsed < FADE_SECONDS:
			return _smooth_step(local_elapsed / FADE_SECONDS)
		return 1.0
	if local_elapsed > HINT_SECONDS:
		return 0.0
	if local_elapsed < FADE_SECONDS:
		return _smooth_step(local_elapsed / FADE_SECONDS)
	if local_elapsed > HINT_SECONDS - FADE_SECONDS:
		return _smooth_step((HINT_SECONDS - local_elapsed) / FADE_SECONDS)
	return 1.0


func get_current_message() -> String:
	if _elapsed >= DASH_START_SECONDS:
		return _get_dash_message()
	return _get_move_message()


func get_snapshot() -> Dictionary:
	return {
		"has_started": _has_started,
		"active": _active,
		"elapsed": _elapsed,
		"alpha": get_alpha(),
		"message": get_current_message(),
		"grip_style": _grip_style,
		"dash_tutorial_completed": _dash_tutorial_completed,
	}


func _should_start(owner: Object) -> bool:
	if owner == null:
		return false
	# 이동/대쉬 조작(A/D, S)은 스매셔·코만도가 동일하므로 코만도도 이 안내를 공유한다.
	return (
		BattleSceneConfig.normalize_league_mode(
			str(BattleSceneOwnerReader.get_value(owner, "ai_mode", "champion"))
		) == "junior"
		and _is_starter_tutorial_character(BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher"))
		and _get_grip_style(owner) != ""
	)


func _is_starter_tutorial_character(character_type: Variant) -> bool:
	return (
		_character_runtime.normalize(character_type) == "smasher"
		or _character_runtime.is_commando(character_type)
		or _character_runtime.is_viper(character_type)
	)


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
	if normalized in ["space_arrows", "space_arrow", "arrows", "arrow_keys"]:
		return "space_arrows"
	if normalized in ["gamepad", "xbox", "controller", "pad"]:
		return "gamepad"
	return ""


func _get_move_message() -> String:
	var key := str(MOVE_MESSAGE_KEYS.get(_grip_style, MOVE_MESSAGE_KEY))
	return LanguageSettings.translate(key, MOVE_MESSAGE)


func _get_dash_message() -> String:
	var key := str(DASH_MESSAGE_KEYS.get(_grip_style, DASH_MESSAGE_KEY))
	return LanguageSettings.translate(key, DASH_MESSAGE)


func _refresh_language_state() -> bool:
	var language := LanguageSettings.get_language()
	if language == _last_language:
		return false
	_last_language = language
	return true


# 키캡/텍스트 토큰 분리는 공용 렌더러가 소유한다(회귀 스모크가 이 경로를 통해 봉인).
func _split_render_tokens(message: String) -> Array:
	return TutorialHintKeycapRenderer.split_render_tokens(message)


func _smooth_step(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _get_current_hint_elapsed() -> float:
	if _elapsed >= DASH_START_SECONDS:
		return _elapsed - DASH_START_SECONDS
	return _elapsed - MOVE_START_SECONDS


func _has_player_dash_started(registry: Object) -> bool:
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	if dash_state == null:
		return false
	if dash_state.has_method("get_snapshot"):
		var snapshot_value: Variant = dash_state.get_snapshot()
		if snapshot_value is Dictionary:
			var snapshot: Dictionary = snapshot_value as Dictionary
			return bool(snapshot.get("active", false)) or bool(snapshot.get("recovering", false))
	if dash_state.has_method("is_active") and bool(dash_state.is_active()):
		return true
	if dash_state.has_method("is_recovering") and bool(dash_state.is_recovering()):
		return true
	return false


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
