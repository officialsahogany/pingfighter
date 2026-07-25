extends RefCounted

const MainMenuAudioStreamPolicy := preload("res://scripts/audio/main_menu_audio_stream_policy.gd")

# AudioServer-backed adapter consumed by the shared pause/settings overlay when
# it is hosted from the main menu.

const AUDIO_BGM_BUS_NAME := "BGM"
const AUDIO_SFX_BUS_NAME := "SFX"
const AUDIO_DEFAULT_BGM_VOLUME := 0.4
const AUDIO_DEFAULT_SFX_VOLUME := 0.7


func _init() -> void:
	_ensure_audio_bus(AUDIO_BGM_BUS_NAME, AUDIO_DEFAULT_BGM_VOLUME)
	_ensure_audio_bus(AUDIO_SFX_BUS_NAME, AUDIO_DEFAULT_SFX_VOLUME)


func get_bgm_volume() -> float:
	return _get_bus_volume(AUDIO_BGM_BUS_NAME, AUDIO_DEFAULT_BGM_VOLUME)


func set_bgm_volume(value: float) -> float:
	return _set_bus_volume(AUDIO_BGM_BUS_NAME, value, AUDIO_DEFAULT_BGM_VOLUME)


func get_sfx_volume() -> float:
	return _get_bus_volume(AUDIO_SFX_BUS_NAME, AUDIO_DEFAULT_SFX_VOLUME)


func set_sfx_volume(value: float) -> float:
	return _set_bus_volume(AUDIO_SFX_BUS_NAME, value, AUDIO_DEFAULT_SFX_VOLUME)


func _get_bus_volume(bus_name: String, fallback: float) -> float:
	var bus_index := _ensure_audio_bus(bus_name, fallback)
	if bus_index < 0:
		return fallback
	var volume_db := AudioServer.get_bus_volume_db(bus_index)
	if volume_db <= -79.0:
		return 0.0
	return clampf(db_to_linear(volume_db), 0.0, 1.0)


func _set_bus_volume(bus_name: String, value: float, fallback: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	var bus_index := _ensure_audio_bus(bus_name, fallback)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, _volume_to_db(clamped))
	return clamped


func _ensure_audio_bus(bus_name: String, default_volume: float) -> int:
	return MainMenuAudioStreamPolicy.ensure_bus(bus_name, default_volume)


func _volume_to_db(volume: float) -> float:
	return MainMenuAudioStreamPolicy.volume_to_db(volume)
