extends SceneTree

const BallSpinState := preload("res://scripts/ball/ball_spin_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_drive_spin_bends_faster_than_plain_spin()
	_verify_drive_spin_keeps_decay_and_direction()

	if _failures.is_empty():
		print("smasher_drive_curve_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_drive_spin_bends_faster_than_plain_spin() -> void:
	var spin_state := BallSpinState.new()
	var plain: Dictionary = spin_state.apply_spin(Vector2(0.0, -12.0), 0.20, 1, 1.0, false)
	var drive: Dictionary = spin_state.apply_spin(Vector2(0.0, -12.0), 0.20, 1, 1.0, true)
	var plain_vel: Vector2 = plain.get("ball_vel", Vector2.ZERO)
	var drive_vel: Vector2 = drive.get("ball_vel", Vector2.ZERO)

	_expect(is_equal_approx(plain_vel.x, 0.20 * BallSpinState.DRIVE_SPIN_FORCE), "plain spin should keep the legacy curve force")
	_expect(
		is_equal_approx(drive_vel.x, 0.20 * BallSpinState.DRIVE_SPIN_FORCE * BallSpinState.DRIVE_ACTIVE_SPIN_FORCE_MULT),
		"active Mika Drive spin should use the faster drive curve force"
	)
	_expect(absf(drive_vel.x) > absf(plain_vel.x), "active Mika Drive should bend faster immediately after launch")


func _verify_drive_spin_keeps_decay_and_direction() -> void:
	var spin_state := BallSpinState.new()
	var left_drive: Dictionary = spin_state.apply_spin(Vector2(3.0, -12.0), 0.30, -1, 0.5, true)
	var next_vel: Vector2 = left_drive.get("ball_vel", Vector2.ZERO)
	var expected_x: float = 3.0 - 0.30 * BallSpinState.DRIVE_SPIN_FORCE * BallSpinState.DRIVE_ACTIVE_SPIN_FORCE_MULT * 0.5
	var expected_strength: float = 0.30 * pow(BallSpinState.DEFAULT_SPIN_DECAY, 0.5)

	_expect(is_equal_approx(next_vel.x, expected_x), "drive curve boost should respect spin direction and fps scale")
	_expect(is_equal_approx(float(left_drive.get("ball_spin_strength", 0.0)), expected_strength), "drive curve boost should not change spin decay")
	_expect(int(left_drive.get("ball_spin_direction", 0)) == -1, "drive curve boost should preserve spin direction")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
