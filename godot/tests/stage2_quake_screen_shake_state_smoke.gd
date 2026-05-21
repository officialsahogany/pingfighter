extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2QuakeScreenShakeState := preload("res://scripts/stages/stage2/stage2_quake_screen_shake_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_quake_screen_offset()
	_verify_background_delegates_quake_screen_offset()

	if _failures.is_empty():
		print("stage2_quake_screen_shake_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_quake_screen_offset() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2204
	_expect(
		Stage2QuakeScreenShakeState.get_offset(0.0, 80.0 / 60.0, rng) == Vector2.ZERO,
		"inactive quake screen shake should return zero offset"
	)
	var active_offset: Vector2 = Stage2QuakeScreenShakeState.get_offset(0.5, 80.0 / 60.0, rng)
	_expect(active_offset.length() > 0.0, "active quake screen shake should return a visible offset")
	var repeat_rng := RandomNumberGenerator.new()
	repeat_rng.seed = 2204
	_expect(
		Stage2QuakeScreenShakeState.get_offset(0.5, 80.0 / 60.0, repeat_rng) == active_offset,
		"quake screen shake should be deterministic for the same timer and RNG seed"
	)


func _verify_background_delegates_quake_screen_offset() -> void:
	var background := Stage2PillarBackground.new()
	background.quake_duration = 80.0 / 60.0
	background.quake_timer = 0.5
	background.quake_motion_rng.seed = 2204
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 2204
	_expect(
		background._get_quake_screen_offset() == Stage2QuakeScreenShakeState.get_offset(0.5, 80.0 / 60.0, expected_rng),
		"Stage 2 background should delegate quake screen offset calculation"
	)

	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2QuakeScreenShakeState.get_offset") >= 0,
		"Stage 2 background source should keep the quake screen offset delegated"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
