extends SceneTree

const MainMenuAudioSettings := preload("res://scripts/ui/main_menu_audio_settings.gd")
const MainMenuSettingsRegistry := preload("res://scripts/ui/main_menu_settings_registry.gd")


class StubService:
	extends RefCounted


var failure_count: int = 0


func _init() -> void:
	var audio := StubService.new()
	var layout := StubService.new()
	var registry := MainMenuSettingsRegistry.new(audio, layout)

	_expect(registry.get_instance("game_audio") == audio, "registry should expose the main-menu audio adapter")
	_expect(registry.get_instance("battle_view_layout") == layout, "registry should expose the battle view layout")
	_expect(registry.get_instance("unknown") == null, "registry should reject unknown service keys")

	registry.clear_runtime_state()
	_expect(registry.audio_settings == null, "registry clear should release the audio adapter")
	_expect(registry.view_layout == null, "registry clear should release the view layout")

	var audio_settings := MainMenuAudioSettings.new()
	_expect(is_equal_approx(audio_settings._volume_to_db(0.0), -80.0), "zero volume should map to the silent floor")
	_expect(is_equal_approx(audio_settings._volume_to_db(-1.0), -80.0), "negative volume should clamp to the silent floor")
	_expect(is_equal_approx(audio_settings._volume_to_db(1.0), 0.0), "full volume should map to zero decibels")
	_expect(is_equal_approx(audio_settings._volume_to_db(2.0), 0.0), "over-range volume should clamp to zero decibels")

	if failure_count > 0:
		quit(1)
		return
	print("main_menu_settings_services_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
