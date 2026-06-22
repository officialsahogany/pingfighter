extends SceneTree

# Seals the predictive-braking behavior of the boss turn-inertia resolver: after a
# large horizontal displacement (banana slip / knockback slam to a wall) the boss
# must SETTLE on its predicted target, not enter a sustained overshoot limit-cycle.
# Reverse-verified: removing the predictive brake in _approach_target turns the
# large-displacement peak-to-peak from ~0px into ~155px and fails this smoke.

const Resolver := preload("res://scripts/ai/boss_ai_turn_inertia_resolver.gd")

var _failures: Array[String] = []


func _drive(start_center: float, target: float, frames: int) -> Dictionary:
	var resolver := Resolver.new()
	var center := start_center
	var vel := 0.0
	var fps := 1.0
	var mn := 1.0e9
	var mx := -1.0e9
	for frame in range(frames):
		# ball_approaching_boss = true mirrors the descending-defense case.
		vel = resolver.update_velocity(target, center, vel, fps, true, 1.0, 1.0, {})
		center = clampf(center + vel * fps, 0.0, 760.0)
		if frame >= frames / 2:
			mn = minf(mn, center)
			mx = maxf(mx, center)
	return {"pp": mx - mn, "end": center}


func _init() -> void:
	# Large displacement (wall -> mid-field target): must converge and settle.
	var big := _drive(0.0, 380.0, 360)
	_expect(float(big.pp) < 6.0, "large displacement should settle (peak-to-peak=%.1f, expected <6)" % float(big.pp))
	_expect(absf(float(big.end) - 380.0) < 8.0, "large displacement should end on target (ended %.1f, target 380)" % float(big.end))

	# Moderate displacement should also settle (this size oscillated 155px before the fix).
	var mid := _drive(300.0, 380.0, 360)
	_expect(float(mid.pp) < 6.0, "moderate displacement should settle (peak-to-peak=%.1f)" % float(mid.pp))

	# Already on the target: stay put (no spurious jitter introduced by braking).
	var none := _drive(380.0, 380.0, 180)
	_expect(float(none.pp) < 1.0, "boss already on target should stay put (peak-to-peak=%.1f)" % float(none.pp))

	# Opposite direction (slam to the right wall): also settles.
	var right := _drive(660.0, 380.0, 360)
	_expect(float(right.pp) < 6.0, "right-side displacement should settle (peak-to-peak=%.1f)" % float(right.pp))

	if _failures.is_empty():
		print("boss_ai_turn_inertia_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
