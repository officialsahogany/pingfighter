extends RefCounted

const ACTION_NONE := "none"
const ACTION_START_FLASH := "start_flash"
const ACTION_FINISH := "finish"

var active := false
var character: Dictionary = {}
var elapsed := 0.0
var pending_scene_path := ""
var exit_flash_pending := false
var exit_flash_hold_remaining := 0.0
var exit_flash_started := false


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"character": character.duplicate(true),
		"elapsed": elapsed,
		"pending_scene_path": pending_scene_path,
		"exit_flash_pending": exit_flash_pending,
		"exit_flash_hold_remaining": exit_flash_hold_remaining,
		"exit_flash_started": exit_flash_started,
	}


func begin(selected_character: Dictionary, next_scene_path: String) -> void:
	active = true
	character = selected_character.duplicate(true)
	elapsed = 0.0
	pending_scene_path = next_scene_path
	exit_flash_pending = false
	exit_flash_hold_remaining = 0.0
	exit_flash_started = false


func request_finish() -> String:
	if not active:
		return ACTION_NONE
	if not bool(character.get("confirm_intro_exit_flash_enabled", false)):
		return ACTION_FINISH
	exit_flash_pending = true
	exit_flash_hold_remaining = max(0.0, float(character.get("confirm_intro_exit_flash_hold", 0.0)))
	return ACTION_START_FLASH if exit_flash_hold_remaining <= 0.0 else ACTION_NONE


func advance(delta: float) -> String:
	if not active:
		return ACTION_NONE
	elapsed += delta
	if exit_flash_pending and not exit_flash_started:
		exit_flash_hold_remaining -= delta
		if exit_flash_hold_remaining <= 0.0:
			return ACTION_START_FLASH
	return ACTION_NONE


func mark_flash_started() -> void:
	if not active:
		return
	exit_flash_pending = false
	exit_flash_hold_remaining = 0.0
	exit_flash_started = true


func build_flash_payload(source_rect: Rect2) -> Dictionary:
	var accent := _get_color(
		character,
		"confirm_intro_exit_flash_color",
		_get_color(character, "card_color", Color(0.0, 0.9, 1.0))
	)
	var glow := _get_color(
		character,
		"confirm_intro_exit_flash_glow_color",
		_get_color(character, "glow_color", accent)
	)
	return {
		"duration": float(character.get("confirm_intro_exit_flash_duration", 0.45)),
		"source_rect": source_rect,
		"style": str(character.get("confirm_intro_exit_flash_style", "burst")),
		"accent": accent,
		"glow": glow,
		"secondary": _get_color(character, "confirm_intro_exit_flash_secondary_color", Color.WHITE),
		"field_intensity": float(character.get("confirm_intro_exit_flash_field_intensity", 1.0)),
		"card_intensity": float(character.get("confirm_intro_exit_flash_card_intensity", 1.0)),
		"white_wash_target": float(character.get("confirm_intro_exit_flash_white_wash_target", 0.92)),
		"chroma": float(character.get("confirm_intro_exit_flash_chroma", 0.012)),
		"split_intensity": float(character.get("confirm_intro_exit_flash_split_intensity", 0.85)),
		"split_count": int(character.get("confirm_intro_exit_flash_split_count", 10)),
	}


func finish() -> String:
	var next_scene_path := pending_scene_path
	reset()
	return next_scene_path


func reset() -> void:
	active = false
	character.clear()
	elapsed = 0.0
	pending_scene_path = ""
	exit_flash_pending = false
	exit_flash_hold_remaining = 0.0
	exit_flash_started = false


static func _get_color(source: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = source.get(key, fallback)
	return value if value is Color else fallback
