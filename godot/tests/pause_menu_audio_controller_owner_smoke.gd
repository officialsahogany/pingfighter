extends SceneTree

const PauseMenuAudioController := preload("res://scripts/hud/pause_menu_audio_controller.gd")


class FakeAudio:
	var bgm_volume := 0.4
	var sfx_volume := 0.7
	var move_count := 0
	var confirm_count := 0
	var back_count := 0

	func get_bgm_volume() -> float:
		return bgm_volume

	func set_bgm_volume(value: float) -> float:
		bgm_volume = value
		return bgm_volume

	func get_sfx_volume() -> float:
		return sfx_volume

	func set_sfx_volume(value: float) -> float:
		sfx_volume = value
		return sfx_volume

	func play_ui_move() -> void:
		move_count += 1

	func play_ui_confirm() -> void:
		confirm_count += 1

	func play_ui_back() -> void:
		back_count += 1


class FakeRegistry:
	var audio := FakeAudio.new()

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		return null


var _failures: Array[String] = []


func _init() -> void:
	_verify_audio_controller()
	_verify_overlay_delegation()
	if _failures.is_empty():
		print("pause_menu_audio_controller_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_audio_controller() -> void:
	var controller := PauseMenuAudioController.new()
	var registry := FakeRegistry.new()
	_expect(is_equal_approx(controller.get_bgm_volume(registry), 0.4), "controller should read BGM volume from game_audio")
	_expect(is_equal_approx(controller.get_sfx_volume(registry), 0.7), "controller should read SFX volume from game_audio")
	_expect(is_equal_approx(controller.get_bgm_volume(null), PauseMenuAudioController.DEFAULT_BGM_VOLUME), "missing audio should use BGM fallback")
	_expect(is_equal_approx(controller.get_sfx_volume(null), PauseMenuAudioController.DEFAULT_SFX_VOLUME), "missing audio should use SFX fallback")

	_expect(is_equal_approx(controller.set_bgm_volume(registry, 1.5), 1.0), "BGM writes should clamp high values")
	_expect(is_equal_approx(controller.set_sfx_volume(registry, -0.5), 0.0), "SFX writes should clamp low values")
	controller.adjust_focused_volume(0, registry, -0.25)
	controller.adjust_focused_volume(1, registry, 0.35)
	_expect(is_equal_approx(registry.audio.bgm_volume, 0.75), "focus zero should adjust BGM")
	_expect(is_equal_approx(registry.audio.sfx_volume, 0.35), "focus one should adjust SFX")
	controller.adjust_focused_volume(2, registry, 0.5)
	_expect(is_equal_approx(registry.audio.bgm_volume, 0.75) and is_equal_approx(registry.audio.sfx_volume, 0.35), "non-slider focus should not change volume")

	var slider_rect := Rect2(Vector2(100.0, 20.0), Vector2(400.0, 10.0))
	controller.set_volume_from_slider(PauseMenuAudioController.SOUND_SLIDER_BGM, 300.0, slider_rect, registry)
	_expect(is_equal_approx(registry.audio.bgm_volume, 0.5), "slider midpoint should project to 0.5 BGM")
	controller.set_volume_from_slider(PauseMenuAudioController.SOUND_SLIDER_SFX, 900.0, slider_rect, registry)
	_expect(is_equal_approx(registry.audio.sfx_volume, 1.0), "slider projection should clamp past the right edge")

	controller.play_move(registry)
	controller.play_confirm(registry)
	controller.play_back(registry)
	_expect(registry.audio.move_count == 1, "move cue should route through game_audio")
	_expect(registry.audio.confirm_count == 1, "confirm cue should route through game_audio")
	_expect(registry.audio.back_count == 1, "back cue should route through game_audio")


func _verify_overlay_delegation() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_audio_controller.gd")
	_expect(overlay_source.find("PauseMenuAudioController") >= 0, "overlay should preload the audio controller")
	for delegation in [
		"_audio_controller.play_move(registry)",
		"_audio_controller.play_confirm(registry)",
		"_audio_controller.play_back(registry)",
		"_audio_controller.adjust_focused_volume(options_focus, registry, delta)",
		"_audio_controller.get_bgm_volume(registry)",
		"_audio_controller.set_bgm_volume(registry, value)",
		"_audio_controller.get_sfx_volume(registry)",
		"_audio_controller.set_sfx_volume(registry, value)",
	]:
		_expect(overlay_source.find(delegation) >= 0, "overlay should delegate pause audio operation: %s" % delegation)
	_expect(controller_source.find("get_instance(\"game_audio\")") >= 0, "audio controller should own game_audio discovery")
	_expect(controller_source.find("clampf") >= 0, "audio controller should own volume clamping")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
