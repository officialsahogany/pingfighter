extends SceneTree

# Seals the 40-deg side-smash angle ceiling. A wide incoming ball used to launch
# at a steep side angle, and the per-frame parabola arc then widened the path to a
# felt 50-65 deg from vertical, so the ball drifted into the side wall (lost speed
# to the 0.95 wall damping) and was trivial to guard. Two caps now hold the path
# at <= 40 deg from vertical: a launch ceiling in the hit-direction resolver and an
# in-flight lateral clamp in the motion resolver. The existing 25-deg MIN floor and
# straight-smash behaviour must be preserved.

const PowerSmashHitDirectionResolver := preload("res://scripts/characters/smasher_power_smash_hit_direction_resolver.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")

const ANGLE_CEILING_DEG := 40.0
const ANGLE_FLOOR_DEG := 25.0
const BASE_SPEED := 7.65
const GRAVITY := 0.035
const BOOST_DURATION := 0.50
const ARC_STRENGTH := 0.68

var _failures: Array[String] = []


func _init() -> void:
	_verify_wide_side_launch_is_capped_to_ceiling()
	_verify_min_turn_floor_is_preserved()
	_verify_moderate_launch_passes_through_unchanged()
	_verify_inflight_arc_never_widens_past_ceiling()
	_verify_left_smash_inflight_is_capped()
	_verify_straight_smash_is_not_forced_to_ceiling()

	if _failures.is_empty():
		print("smasher_power_smash_angle_cap_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_wide_side_launch_is_capped_to_ceiling() -> void:
	var resolver: Object = PowerSmashHitDirectionResolver.new()
	# Nearly-horizontal incoming ball -> would launch far past 40 deg without a cap.
	var launched: Vector2 = resolver.apply_side_direction(Vector2(20.0, -6.0), 1, BASE_SPEED, null)
	var angle: float = _angle_from_vertical_deg(launched)
	_expect(angle <= ANGLE_CEILING_DEG + 0.5, "wide right side smash launch should cap at 40 deg, got %.1f" % angle)
	_expect(launched.x > 0.0, "right smash should still launch toward +x")
	_expect(launched.y < 0.0, "side smash should still launch upward")


func _verify_min_turn_floor_is_preserved() -> void:
	var resolver: Object = PowerSmashHitDirectionResolver.new()
	# Nearly-vertical incoming ball -> the MIN floor must still widen it to ~25 deg.
	var launched: Vector2 = resolver.apply_side_direction(Vector2(1.0, -20.0), -1, BASE_SPEED, null)
	var angle: float = _angle_from_vertical_deg(launched)
	_expect(abs(angle - ANGLE_FLOOR_DEG) < 1.0, "narrow left smash should still floor to ~25 deg, got %.1f" % angle)
	_expect(launched.x < 0.0, "left smash should launch toward -x")


func _verify_moderate_launch_passes_through_unchanged() -> void:
	var resolver: Object = PowerSmashHitDirectionResolver.new()
	# ~30 deg incoming (inside [25, 40]) -> neither floor nor ceiling should retarget it.
	var launched: Vector2 = resolver.apply_side_direction(Vector2(10.0, -17.3), 1, BASE_SPEED, null)
	var angle: float = _angle_from_vertical_deg(launched)
	_expect(
		angle > ANGLE_FLOOR_DEG and angle < ANGLE_CEILING_DEG,
		"moderate smash should stay within (25, 40), got %.1f" % angle
	)


func _verify_inflight_arc_never_widens_past_ceiling() -> void:
	var power_state: Object = _start_side_power_state(1, ARC_STRENGTH)
	# Launch ~32 deg; uncapped the arc would push the peak to ~53 deg over flight.
	var velocity: Vector2 = Vector2(10.0, -16.0)
	var peak: float = _angle_from_vertical_deg(velocity)
	for _i in range(45):
		velocity = power_state.apply_motion(velocity, 1.0, GRAVITY, BOOST_DURATION)
		peak = max(peak, _angle_from_vertical_deg(velocity))
	_expect(peak <= ANGLE_CEILING_DEG + 0.5, "right in-flight arc must not widen past 40 deg, peak %.1f" % peak)


func _verify_left_smash_inflight_is_capped() -> void:
	var power_state: Object = _start_side_power_state(-1, -ARC_STRENGTH)
	var velocity: Vector2 = Vector2(-10.0, -16.0)
	var peak: float = _angle_from_vertical_deg(velocity)
	for _i in range(45):
		velocity = power_state.apply_motion(velocity, 1.0, GRAVITY, BOOST_DURATION)
		peak = max(peak, _angle_from_vertical_deg(velocity))
		_expect(velocity.x <= 0.001, "left smash should keep travelling toward -x")
	_expect(peak <= ANGLE_CEILING_DEG + 0.5, "left in-flight arc must not widen past 40 deg, peak %.1f" % peak)


func _verify_straight_smash_is_not_forced_to_ceiling() -> void:
	# Straight smash (direction 0, arc 0) must remain near-vertical: the clamp is
	# gated to side smashes, so it must never push a straight shot UP toward 40 deg.
	var power_state: Object = _start_side_power_state(0, 0.0)
	var velocity: Vector2 = Vector2(2.0, -18.0)
	for _i in range(30):
		velocity = power_state.apply_motion(velocity, 1.0, GRAVITY, BOOST_DURATION)
	var angle: float = _angle_from_vertical_deg(velocity)
	_expect(angle < 20.0, "straight smash should stay narrow (no clamp toward ceiling), got %.1f" % angle)


func _start_side_power_state(direction: int, arc_strength: float) -> Object:
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(direction, arc_strength, 0, 30.0, false, 1000, 0.0)
	var started: bool = bool(power_state.update_freeze(0.0, 0.0))
	_expect(started, "test setup should release power-smash freeze immediately")
	_expect(power_state.is_parabola_active(), "test setup should start power-smash parabola motion")
	return power_state


func _angle_from_vertical_deg(velocity: Vector2) -> float:
	return rad_to_deg(atan2(abs(velocity.x), abs(velocity.y)))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
