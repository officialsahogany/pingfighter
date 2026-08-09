extends RefCounted

const SOUND_SLIDER_BGM := "bgm"
const SOUND_SLIDER_SFX := "sfx"
const DEFAULT_BGM_VOLUME := 0.4
const DEFAULT_SFX_VOLUME := 0.7


func play_move(registry: Object) -> void:
	play_feedback(registry, "play_ui_move")


func play_confirm(registry: Object) -> void:
	play_feedback(registry, "play_ui_confirm")


func play_back(registry: Object) -> void:
	play_feedback(registry, "play_ui_back")


func play_feedback(registry: Object, method_name: String) -> void:
	var audio := _get_audio(registry)
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


func adjust_focused_volume(options_focus: int, registry: Object, delta: float) -> void:
	if options_focus == 0:
		set_bgm_volume(registry, get_bgm_volume(registry) + delta)
	elif options_focus == 1:
		set_sfx_volume(registry, get_sfx_volume(registry) + delta)


func set_volume_from_slider(slider_key: String, mouse_x: float, slider_rect: Rect2, registry: Object) -> void:
	var value := 0.0
	if slider_rect.size.x > 0.0:
		value = clampf((mouse_x - slider_rect.position.x) / slider_rect.size.x, 0.0, 1.0)
	if slider_key == SOUND_SLIDER_BGM:
		set_bgm_volume(registry, value)
	elif slider_key == SOUND_SLIDER_SFX:
		set_sfx_volume(registry, value)


func get_bgm_volume(registry: Object) -> float:
	var audio := _get_audio(registry)
	if audio != null and audio.has_method("get_bgm_volume"):
		return clampf(float(audio.get_bgm_volume()), 0.0, 1.0)
	return DEFAULT_BGM_VOLUME


func set_bgm_volume(registry: Object, value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	var audio := _get_audio(registry)
	if audio != null and audio.has_method("set_bgm_volume"):
		return clampf(float(audio.set_bgm_volume(clamped)), 0.0, 1.0)
	return clamped


func get_sfx_volume(registry: Object) -> float:
	var audio := _get_audio(registry)
	if audio != null and audio.has_method("get_sfx_volume"):
		return clampf(float(audio.get_sfx_volume()), 0.0, 1.0)
	return DEFAULT_SFX_VOLUME


func set_sfx_volume(registry: Object, value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	var audio := _get_audio(registry)
	if audio != null and audio.has_method("set_sfx_volume"):
		return clampf(float(audio.set_sfx_volume(clamped)), 0.0, 1.0)
	return clamped


func _get_audio(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance("game_audio")
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
