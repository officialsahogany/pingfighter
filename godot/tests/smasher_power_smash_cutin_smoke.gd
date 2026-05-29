extends SceneTree

const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")
const SkillCutinOverlayHost := preload("res://scripts/hud/skill_cutin_overlay_host.gd")
const PowerSmashCutinState := preload("res://scripts/characters/smasher_power_smash_cutin_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")

const CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/smasher_power_smashing_cutin_sheet.png"
const FREEZE_DURATION := 1.65

var _failures: Array[String] = []


func _init() -> void:
	_test_power_smashing_starts_cutin()
	_test_ghost_shot_skips_cutin()
	_test_cutin_ends_after_duration()
	_test_cutin_progress_tracks_freeze()
	_test_cutin_phases()
	_test_reset_clears_cutin()
	_test_clear_effects_preserves_cutin()
	_test_cutin_host_draw_guards()
	_test_cutin_host_prewarms_sheet()
	_test_power_smash_freeze_config_is_extended()
	_test_zero_freeze_duration_skips_cutin()

	if _failures.is_empty():
		print("smasher_power_smash_cutin_smoke: ok")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		quit(1)


func _test_power_smashing_starts_cutin() -> void:
	var state := SmasherPowerSmashState.new()
	state.begin_activation(1, 0.5, 0, 48.0, false, 1000, FREEZE_DURATION)
	_expect(state.is_cutin_active(), "power_smashing should start cutin")
	_expect(state.get_cutin_progress() == 0.0, "cutin progress should start at 0")


func _test_ghost_shot_skips_cutin() -> void:
	var state := SmasherPowerSmashState.new()
	state.begin_activation(1, 0.5, 0, 48.0, true, 1000, FREEZE_DURATION)
	_expect(not state.is_cutin_active(), "ghost_shot should NOT start cutin")


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
		_expect(texture.get_width() == 4096, "cutin sheet width should be 4096")
		_expect(texture.get_height() == 4096, "cutin sheet height should be 4096")


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
