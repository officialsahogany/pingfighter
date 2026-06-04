extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SmasherDriveActivationFeedbackController := preload("res://scripts/characters/smasher_drive_activation_feedback_controller.gd")

const DRIVE_VOICE_PATH := "res://assets/sounds/mika_drive.mp3"

var _failures: Array[String] = []


class FakeDriveAudio:
	extends RefCounted

	var drive_count := 0

	func play_drive() -> void:
		drive_count += 1


func _init() -> void:
	_test_drive_voice_asset_loads()
	_test_setup_wires_drive_voice_player()
	_test_drive_activation_triggers_audio()

	if _failures.is_empty():
		print("smasher_drive_voice_smoke: ok")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		quit(1)


func _test_drive_voice_asset_loads() -> void:
	var stream: AudioStream = ProjectResourceLoader.load_audio_stream(DRIVE_VOICE_PATH)
	_expect(stream != null, "Mika drive voice should load from %s" % DRIVE_VOICE_PATH)
	if stream != null:
		_expect(stream.get_length() > 0.0, "Mika drive voice should have a positive duration")


func _test_setup_wires_drive_voice_player() -> void:
	var audio := GameAudio.new()
	audio.setup(get_root())
	_expect(audio.mika_drive_voice_sfx != null, "setup should create the Mika drive voice player")
	if audio.mika_drive_voice_sfx != null:
		_expect(audio.mika_drive_voice_sfx.stream != null, "Mika drive voice player should hold a loaded stream")
	_expect(audio._get_sfx_players().has(audio.mika_drive_voice_sfx), "drive voice player should join the SFX volume set")


func _test_drive_activation_triggers_audio() -> void:
	# Drive activation must route through audio.play_drive(), which now also
	# fires the Mika voice line alongside the mechanical drive SFX.
	var controller := SmasherDriveActivationFeedbackController.new()
	var audio := FakeDriveAudio.new()
	controller.apply_feedback({}, {"audio": audio}, {}, null, null)
	_expect(audio.drive_count == 1, "drive activation feedback should call audio.play_drive() once")


func _expect(condition: bool, message: String = "") -> void:
	if not condition:
		_failures.append(message if message != "" else "assertion failed")
