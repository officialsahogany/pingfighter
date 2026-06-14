extends SceneTree

const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")
const WallBounceController := preload("res://scripts/ball/wall_bounce_controller.gd")

const BASE_ARC := 0.68
const WALL_REPOINT_SCALE := 0.25

var _failures: Array[String] = []


class FakeWallMotionStepper:
	extends RefCounted

	var side: String

	func _init(new_side: String) -> void:
		side = new_side

	func step(_ball_pos: Vector2, _delta: Vector2, _ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		var impact_x: float = 14.3 if side == "left" else 745.7
		return {
			"event": "wall",
			"side": side,
			"ball_pos": Vector2(impact_x, 330.0),
			"impact_pos": Vector2(impact_x, 330.0),
		}


func _init() -> void:
	_verify_first_wall_repoint_shrinks_and_flips_left_arc()
	_verify_repointed_arc_pushes_away_after_next_motion_frame()
	_verify_ghost_shot_wall_bounce_does_not_repoint_arc()
	_verify_straight_power_smash_wall_repoint_is_noop()
	_verify_repeated_wall_repoints_preserve_reduced_magnitude()
	_verify_wall_event_processor_notifies_power_smash_state()
	_verify_wall_event_processor_is_null_safe_without_power_state()

	if _failures.is_empty():
		print("smasher_power_smash_wall_arc_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_first_wall_repoint_shrinks_and_flips_left_arc() -> void:
	var power_state: Object = _start_power_state(-1, -BASE_ARC)
	power_state.notify_wall_bounce("left")

	var arc: float = float(power_state.get_arc_strength())
	_expect(arc > 0.0, "left wall bounce should repoint power-smash arc away from the left wall")
	_expect(
		is_equal_approx(arc, BASE_ARC * WALL_REPOINT_SCALE),
		"first wall bounce should shrink power-smash arc to the designed repoint scale"
	)


func _verify_repointed_arc_pushes_away_after_next_motion_frame() -> void:
	var power_state: Object = _start_power_state(-1, -BASE_ARC)
	power_state.notify_wall_bounce("left")

	var after_motion: Vector2 = power_state.apply_motion(Vector2(0.02, -8.0), 1.0, 0.0, 0.0)
	_expect(after_motion.x > 0.02, "repointed left-wall arc should accelerate the next frame away from the wall")


func _verify_ghost_shot_wall_bounce_does_not_repoint_arc() -> void:
	var power_state: Object = _start_power_state(-1, -BASE_ARC, true)
	_expect(power_state.is_ghost_shot_motion_active(), "test setup should start ghost-shot motion")

	power_state.notify_wall_bounce("left")
	_expect(
		is_equal_approx(float(power_state.get_arc_strength()), -BASE_ARC),
		"ghost-shot motion should ignore power-smash wall arc repointing"
	)


func _verify_straight_power_smash_wall_repoint_is_noop() -> void:
	var power_state: Object = _start_power_state(0, 0.0)
	power_state.notify_wall_bounce("left")
	_expect(is_equal_approx(float(power_state.get_arc_strength()), 0.0), "straight power smash should keep zero arc after a wall bounce")


func _verify_repeated_wall_repoints_preserve_reduced_magnitude() -> void:
	var power_state: Object = _start_power_state(-1, -BASE_ARC)
	power_state.notify_wall_bounce("left")
	var first_arc: float = float(power_state.get_arc_strength())

	power_state.notify_wall_bounce("left")
	var repeated_arc: float = float(power_state.get_arc_strength())
	_expect(is_equal_approx(repeated_arc, first_arc), "same-wall repoint should not shrink the arc a second time")

	power_state.notify_wall_bounce("right")
	var opposite_arc: float = float(power_state.get_arc_strength())
	_expect(opposite_arc < 0.0, "opposite wall should reorient the already-shrunk arc")
	_expect(
		is_equal_approx(abs(opposite_arc), abs(first_arc)),
		"opposite-wall repoint should preserve the reduced arc magnitude"
	)


func _verify_wall_event_processor_notifies_power_smash_state() -> void:
	var power_state: Object = _start_power_state(-1, -BASE_ARC)
	var scene: Dictionary = _wall_scene(Vector2(-12.0, -2.0))
	var deps: Dictionary = {
		"motion_stepper": FakeWallMotionStepper.new("left"),
		"wall_bounce_controller": WallBounceController.new(),
		"power_state": power_state,
	}

	var event: String = BallMotionEventProcessor.new().step_motion(scene, 1.0, _wall_context(), deps, {})
	_expect(event == "", "normal wall bounce should not request a score/rematch event")
	_expect(_get_vector2(scene, "ball_vel", Vector2.ZERO).x > 0.0, "real wall controller should reflect the ball from the left wall")
	_expect(float(power_state.get_arc_strength()) > 0.0, "wall event processor should notify power smash to repoint away from the left wall")


func _verify_wall_event_processor_is_null_safe_without_power_state() -> void:
	var scene: Dictionary = _wall_scene(Vector2(-12.0, -2.0))
	var deps: Dictionary = {
		"motion_stepper": FakeWallMotionStepper.new("left"),
		"wall_bounce_controller": WallBounceController.new(),
	}

	var event: String = BallMotionEventProcessor.new().step_motion(scene, 1.0, _wall_context(), deps, {})
	_expect(event == "", "wall event processor should stay null-safe when power_state is absent")
	_expect(_get_vector2(scene, "ball_vel", Vector2.ZERO).x > 0.0, "wall bounce should still resolve without power_state")


func _start_power_state(direction: int, arc_strength: float, ghost_shot: bool = false) -> Object:
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(direction, arc_strength, 0, 30.0, ghost_shot, 1000, 0.0)
	var started: bool = bool(power_state.update_freeze(0.0, 0.0))
	_expect(started, "test setup should release power-smash freeze immediately")
	_expect(power_state.is_parabola_active(), "test setup should start power-smash parabola motion")
	return power_state


func _wall_scene(ball_vel: Vector2) -> Dictionary:
	return {
		"ball_pos": Vector2(14.3, 330.0),
		"ball_vel": ball_vel,
		"ball_impact_boost": 1.0,
	}


func _wall_context() -> Dictionary:
	return {
		"ball_size": 28.6,
		"width": 760.0,
		"height": 750.0,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
