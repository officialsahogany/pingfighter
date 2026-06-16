extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

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
var _text_size_cache: Dictionary = {}
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
	var font_size: int = _get_fit_font_size(font, view_size.x)
	var message: String = get_current_message()
	var text_size: Vector2 = _get_text_size(font, message, font_size)
	var center: Vector2 = get_draw_center(view_size)
	var baseline := Vector2(
		center.x - text_size.x * 0.5,
		center.y - text_size.y * 0.5 + font.get_ascent(font_size)
	)
	var glow_alpha: float = 0.24 * alpha
	canvas.draw_string_outline(
		font,
		baseline + Vector2(0.0, 1.0),
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		5,
		Color(0.02, 0.04, 0.08, 0.82 * alpha)
	)
	canvas.draw_string_outline(
		font,
		baseline,
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		2,
		Color(0.15, 0.45, 0.80, glow_alpha)
	)
	canvas.draw_string(
		font,
		baseline,
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(0.92, 0.98, 1.0, alpha)
	)


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
	return (
		_normalize_league_mode(str(BattleSceneOwnerReader.get_value(owner, "ai_mode", "champion"))) == "junior"
		and _character_runtime.normalize(BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher")) == "smasher"
		and _get_grip_style(owner) != ""
	)


func _normalize_league_mode(mode: String) -> String:
	var normalized: String = mode.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized == "junior" or normalized == "juniorleague":
		return "junior"
	if normalized == "mythic" or normalized == "mythicleague":
		return "mythic"
	return "champion"


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


func _get_fit_font_size(font: Font, max_width: float) -> int:
	var font_size: int = FONT_SIZE
	var available_width: float = max(80.0, max_width - 48.0)
	while font_size > MIN_FONT_SIZE and _get_text_size(font, get_current_message(), font_size).x > available_width:
		font_size -= 1
	return font_size


func _get_text_size(font: Font, text: String, font_size: int) -> Vector2:
	var cache_key := "%s|%d" % [text, font_size]
	if _text_size_cache.has(cache_key):
		return _text_size_cache[cache_key]
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_text_size_cache[cache_key] = text_size
	return text_size


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
