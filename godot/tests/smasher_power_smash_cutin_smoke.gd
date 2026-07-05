extends SceneTree

const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")
const SmasherPowerSmashActivationController := preload("res://scripts/characters/smasher_power_smash_activation_controller.gd")
const SkillCutinOverlayHost := preload("res://scripts/hud/skill_cutin_overlay_host.gd")
const PowerSmashCutinState := preload("res://scripts/characters/smasher_power_smash_cutin_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")

const CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/smasher_power_smashing_cutin_sheet.png"
const GHOST_CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/smasher_ghost_smashing_cutin_sheet.png"
const VIPER_CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/viper_phantom_kick_cutin_sheet.png"
const CUTIN_VOICE_PATHS := [
	"res://assets/sounds/voice/mika_power_smashing_cutin_v1.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v2.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v3.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v4.mp3",
]
const GHOST_CUTIN_VOICE_PATHS := [
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v1.mp3",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v2.wav",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v3.mp3",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v4.wav",
]
const CUTIN_SHEET_SIZE := 4096
const GHOST_CUTIN_SHEET_SIZE := 4096
const FREEZE_DURATION := 1.65

var _failures: Array[String] = []


class FakePowerSmashInputReader:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"action_pressed": true,
			"power_smash_direction": 0,
		}


class FakeActiveRoundState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false


class FakePowerSmashAudio:
	extends RefCounted

	var power_smash_count := 0
	var cutin_voice_count := 0
	var ghost_cutin_voice_count := 0

	func play_power_smash() -> void:
		power_smash_count += 1

	func play_power_smashing_cutin_voice() -> void:
		cutin_voice_count += 1

	func play_ghost_smashing_cutin_voice() -> void:
		ghost_cutin_voice_count += 1


class FakeGhostShotSkillConfig:
	extends RefCounted

	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "ghost_shot"

	func get_skill_cost(skill_name: String) -> float:
		if skill_name == "ghost_shot":
			return 420.0
		return 300.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_power_smashing_starts_cutin()
	_test_power_smashing_activation_plays_cutin_voice()
	_test_ghost_shot_starts_cutin()
	_test_ghost_shot_activation_starts_cutin_without_power_voice()
	_test_cutin_ends_after_duration()
	_test_cutin_progress_tracks_freeze()
	_test_cutin_phases()
	_test_reset_clears_cutin()
	_test_clear_effects_preserves_cutin()
	_test_cutin_host_draw_guards()
	_test_cutin_host_prewarms_sheet()
	_test_ghost_cutin_host_prewarms_sheet()
	_test_blocking_prewarm_uses_direct_loads()
	_test_cutin_sheets_use_vram_compression()
	_test_cutin_voice_asset_loads()
	_test_ghost_cutin_voice_asset_loads()
	_test_power_smash_freeze_config_is_extended()
	_test_zero_freeze_duration_skips_cutin()

	ProjectResourceLoader.clear_caches()
	await _drain_frames(24)
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("smasher_power_smash_cutin_smoke: ok")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		quit(1)


func _drain_frames(frame_count: int) -> void:
	for i in frame_count:
		await process_frame


func _test_power_smashing_starts_cutin() -> void:
	var state := SmasherPowerSmashState.new()
	state.begin_activation(1, 0.5, 0, 48.0, false, 1000, FREEZE_DURATION)
	_expect(state.is_cutin_active(), "power_smashing should start cutin")
	_expect(state.get_cutin_progress() == 0.0, "cutin progress should start at 0")
	_expect(state.cutin_state.get_skill_name() == "power_smashing", "power_smashing cutin should keep power profile")


func _test_power_smashing_activation_plays_cutin_voice() -> void:
	var controller := SmasherPowerSmashActivationController.new()
	var state := SmasherPowerSmashState.new()
	var audio := FakePowerSmashAudio.new()
	var result: Dictionary = controller.try_activate(
		{
			"ball_active": true,
			"special_gauge": 500.0,
			"gauge_cost": 300.0,
			"text_duration_frames": 48.0,
			"perfect_cooldown_frames": 0.0,
			"global_cooldown_frames": 0.0,
			"combo_min_count": 2,
			"current_msec": 1000,
			"power_smash_freeze_duration": FREEZE_DURATION,
		},
		{
			"input_reader": FakePowerSmashInputReader.new(),
			"power_state": state,
			"round_state": FakeActiveRoundState.new(),
			"audio": audio,
		},
		{}
	)
	_expect(bool(result.get("activated", false)), "power_smashing activation should succeed")
	_expect(state.is_cutin_active(), "power_smashing activation should start cutin")
	_expect(audio.cutin_voice_count == 1, "power_smashing activation should play Mika cutin voice once")
	_expect(audio.power_smash_count == 1, "power_smashing activation should still play base power smash SFX")


func _test_ghost_shot_starts_cutin() -> void:
	var state := SmasherPowerSmashState.new()
	state.begin_activation(1, 0.5, 0, 48.0, true, 1000, FREEZE_DURATION)
	_expect(state.is_cutin_active(), "ghost_shot should start cutin")
	_expect(state.cutin_state.get_skill_name() == "ghost_shot", "ghost_shot cutin should keep ghost profile")


func _test_ghost_shot_activation_starts_cutin_without_power_voice() -> void:
	var controller := SmasherPowerSmashActivationController.new()
	var state := SmasherPowerSmashState.new()
	var audio := FakePowerSmashAudio.new()
	var result: Dictionary = controller.try_activate(
		{
			"ball_active": true,
			"special_gauge": 500.0,
			"gauge_cost": 300.0,
			"text_duration_frames": 48.0,
			"perfect_cooldown_frames": 0.0,
			"global_cooldown_frames": 0.0,
			"combo_min_count": 2,
			"current_msec": 1000,
			"power_smash_freeze_duration": FREEZE_DURATION,
		},
		{
			"input_reader": FakePowerSmashInputReader.new(),
			"power_state": state,
			"round_state": FakeActiveRoundState.new(),
			"skill_config": FakeGhostShotSkillConfig.new(),
			"audio": audio,
		},
		{}
	)
	_expect(bool(result.get("activated", false)), "ghost_shot activation should succeed")
	_expect(str(result.get("activated_skill", "")) == "ghost_shot", "ghost_shot should keep priority over power_smashing")
	_expect(state.is_cutin_active(), "ghost_shot activation should start cutin")
	_expect(state.cutin_state.get_skill_name() == "ghost_shot", "ghost_shot activation should use ghost cutin profile")
	_expect(audio.cutin_voice_count == 0, "ghost_shot should not play the power_smashing voice line")
	_expect(audio.ghost_cutin_voice_count == 1, "ghost_shot activation should play the ghost-smashing voice line once")
	_expect(audio.power_smash_count == 1, "ghost_shot activation should still play base power smash SFX")


func _test_cutin_ends_after_duration() -> void:
	var state := SmasherPowerSmashState.new()
	var freeze_dur := FREEZE_DURATION
	state.begin_activation(1, 0.5, 0, 48.0, false, 1000, freeze_dur)
	_expect(state.is_cutin_active(), "cutin should be active after begin")

	var cutin: Object = state.cutin_state
	var steps := 60
	var dt := freeze_dur / float(steps)
	for i in steps + 2:
		cutin.update(dt)
	_expect(not state.is_cutin_active(), "cutin should end after freeze duration elapsed")


func _test_cutin_progress_tracks_freeze() -> void:
	var cutin := PowerSmashCutinState.new()
	cutin.begin(1.0)
	cutin.update(0.5)
	var p := cutin.get_progress()
	_expect(absf(p - 0.5) < 0.01, "progress should be ~0.5 at half duration, got %f" % p)


func _test_cutin_phases() -> void:
	var cutin := PowerSmashCutinState.new()
	cutin.begin(1.0)
	_expect(cutin.get_phase() == "wipe", "phase at 0 should be wipe")

	cutin.update(0.15)
	_expect(cutin.get_phase() == "main", "phase at 0.15 should be main")

	cutin.update(0.60)
	_expect(cutin.get_phase() == "text", "phase at 0.75 should be text, got %s" % cutin.get_phase())

	cutin.update(0.10)
	_expect(cutin.get_phase() == "flash", "phase at 0.85 should be flash, got %s" % cutin.get_phase())

	cutin.update(0.20)
	_expect(cutin.get_phase() == "done", "phase at 1.05 should be done")


func _test_reset_clears_cutin() -> void:
	var state := SmasherPowerSmashState.new()
	state.begin_activation(1, 0.5, 0, 48.0, false, 1000, FREEZE_DURATION)
	_expect(state.is_cutin_active(), "cutin should be active before reset")
	state.reset()
	_expect(not state.is_cutin_active(), "cutin should be inactive after reset")


func _test_clear_effects_preserves_cutin() -> void:
	var state := SmasherPowerSmashState.new()
	state.begin_activation(1, 0.5, 0, 48.0, false, 1000, FREEZE_DURATION)
	state.clear_effects()
	_expect(state.is_cutin_active(), "cutin should survive clear_effects (only reset() clears it)")


func _test_cutin_host_draw_guards() -> void:
	var host := SkillCutinOverlayHost.new()
	var cutin := PowerSmashCutinState.new()
	host.draw(null, cutin, Vector2(760, 750))
	host.draw(null, null, Vector2(760, 750))


func _test_cutin_host_prewarms_sheet() -> void:
	var host := SkillCutinOverlayHost.new()
	host.prewarm_assets()
	var texture := ProjectResourceLoader.get_cached_texture(CUTIN_SHEET_PATH)
	_expect(texture != null, "cutin sheet should prewarm into ProjectResourceLoader cache")
	if texture != null:
		_expect(texture.get_width() == CUTIN_SHEET_SIZE, "cutin sheet width should be %d" % CUTIN_SHEET_SIZE)
		_expect(texture.get_height() == CUTIN_SHEET_SIZE, "cutin sheet height should be %d" % CUTIN_SHEET_SIZE)


func _test_ghost_cutin_host_prewarms_sheet() -> void:
	var host := SkillCutinOverlayHost.new()
	host.prewarm_assets()
	var texture := ProjectResourceLoader.get_cached_texture(GHOST_CUTIN_SHEET_PATH)
	_expect(texture != null, "ghost cutin sheet should prewarm into ProjectResourceLoader cache")
	if texture != null:
		_expect(texture.get_width() == GHOST_CUTIN_SHEET_SIZE, "ghost cutin sheet width should be %d" % GHOST_CUTIN_SHEET_SIZE)
		_expect(texture.get_height() == GHOST_CUTIN_SHEET_SIZE, "ghost cutin sheet height should be %d" % GHOST_CUTIN_SHEET_SIZE)


func _test_blocking_prewarm_uses_direct_loads() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/skill_cutin_overlay_host.gd")
	_expect(
		source.find("while not prewarm_assets_for_character_step") == -1,
		"blocking cut-in prewarm should not spin the staged threaded prewarm step"
	)
	_expect(
		source.find("_run_asset_prewarm_step_blocking") >= 0,
		"blocking cut-in prewarm should keep a direct-load prewarm path"
	)


func _test_cutin_sheets_use_vram_compression() -> void:
	for sheet_path in [CUTIN_SHEET_PATH, GHOST_CUTIN_SHEET_PATH, VIPER_CUTIN_SHEET_PATH]:
		var import_config := ConfigFile.new()
		var import_path := "%s.import" % sheet_path
		_expect(import_config.load(import_path) == OK, "cut-in sheet should have an import sidecar: %s" % import_path)
		var metadata_value: Variant = import_config.get_value("remap", "metadata", {})
		var vram_texture := false
		if metadata_value is Dictionary:
			vram_texture = bool((metadata_value as Dictionary).get("vram_texture", false))
		_expect(vram_texture, "cut-in sheet should be marked as a VRAM texture: %s" % sheet_path)
		_expect(
			int(import_config.get_value("params", "compress/mode", -1)) == 2,
			"cut-in sheet should import as VRAM Compressed: %s" % sheet_path
		)
		_expect(
			bool(import_config.get_value("params", "compress/high_quality", false)),
			"cut-in sheet should use high-quality BPTC/ASTC VRAM compression: %s" % sheet_path
		)


func _test_cutin_voice_asset_loads() -> void:
	for voice_path in CUTIN_VOICE_PATHS:
		var stream: AudioStream = ProjectResourceLoader.load_audio_stream(str(voice_path))
		_expect(stream != null, "Mika power-smashing cutin voice should load: %s" % voice_path)
		if stream != null:
			_expect(stream.get_length() > 0.0, "Mika power-smashing cutin voice should have duration: %s" % voice_path)
			_expect(stream.get_length() <= FREEZE_DURATION + 0.05, "Mika power-smashing cutin voice should finish within cutin freeze: %s" % voice_path)


func _test_ghost_cutin_voice_asset_loads() -> void:
	for voice_path in GHOST_CUTIN_VOICE_PATHS:
		var stream: AudioStream = ProjectResourceLoader.load_audio_stream(str(voice_path))
		_expect(stream != null, "Mika ghost-smashing cutin voice should load: %s" % voice_path)
		if stream != null:
			_expect(stream.get_length() > 0.0, "Mika ghost-smashing cutin voice should have duration: %s" % voice_path)
			# Ghost lines may intentionally tail past the 1.65s freeze. Bound them
			# loosely so a wrong/oversized asset is still caught.
			_expect(stream.get_length() <= 2.5, "Mika ghost-smashing cutin voice should stay under 2.5s: %s" % voice_path)


func _test_power_smash_freeze_config_is_extended() -> void:
	var config := BallUpdateStaticConfig.new().build_update_config()
	var freeze_duration: float = float(config.get("power_smash_freeze_duration", 0.0))
	_expect(absf(freeze_duration - FREEZE_DURATION) < 0.001, "power smash freeze should be 1.65 seconds")


func _test_zero_freeze_duration_skips_cutin() -> void:
	var state := SmasherPowerSmashState.new()
	state.begin_activation(1, 0.5, 0, 48.0, false, 1000, 0.0)
	_expect(not state.is_cutin_active(), "zero freeze duration should skip cutin")


func _expect(condition: bool, message: String = "") -> void:
	if not condition:
		_failures.append(message if message != "" else "assertion failed")
