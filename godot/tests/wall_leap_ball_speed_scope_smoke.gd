extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BossContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")

class MotionProbe:
	extends RefCounted
	var displacement := Vector2.ZERO
	func step(_pos: Vector2, next_displacement: Vector2, _base_vel: Vector2, _context: Dictionary) -> Dictionary:
		displacement = next_displacement
		return {"event": "boss_paddle", "ball_pos": Vector2(377.5, 65.0), "paddle_x": 327.5, "paddle_w": 100.0, "is_player": false}

class BounceProbe:
	extends RefCounted
	func bounce(_x: float, _w: float, _is_player: bool, context: Dictionary, _deps: Dictionary, _callbacks: Dictionary) -> Dictionary:
		var incoming: Vector2 = context.get("ball_vel", Vector2.ZERO)
		return {"ball_vel": Vector2(incoming.x, absf(incoming.y)), "normal_boss_bounce_committed": true}

var _failures: Array[String] = []


func _init() -> void:
	var processor := BallMotionEventProcessor.new()
	var motion := MotionProbe.new()
	var scene := {"ball_pos": Vector2(377.5, 65.0), "ball_vel": Vector2(6.0, -8.0), "ball_impact_boost": 1.0}
	var deps := {"motion_stepper": motion, "paddle_bounce_controller": BounceProbe.new()}
	for _index in range(3):
		processor.step_motion(scene, 1.0, {"ball_motion_step_multiplier": 0.70, "boss_pos": Vector2(327.5, 25.0), "boss_hitbox_height": 40.0, "ball_size": 28.6}, deps, {})
		_expect(is_equal_approx(motion.displacement.length(), 7.0), "infiltration must slow each movement step to 70 percent")
		_expect(is_equal_approx((scene["ball_vel"] as Vector2).length(), 10.0), "boss reflection must preserve canonical rally magnitude")
	processor.step_motion(scene, 1.0, {"ball_motion_step_multiplier": 1.0}, deps, {})
	_expect(is_equal_approx(motion.displacement.length(), 10.0), "return scope must remove movement multiplier")

	var support := Support.new()
	var fixture: Dictionary = support.make_fixture()
	support.enter(fixture)
	support.advance_to_infiltrating(fixture)
	fixture["owner"].values["current_stage"] = 1
	fixture["owner"].values["ai_mode"] = "champion"
	fixture["owner"].values["ball_vel"] = Vector2(6.0, -8.0)
	var ai_context: Dictionary = BossContextBuilder.new().build_context(fixture["owner"], fixture["registry"])
	_expect(is_equal_approx((ai_context.get("ball_vel", Vector2.ZERO) as Vector2).length(), 7.0), "boss prediction must consume the same 0.7 motion multiplier")
	_expect(is_equal_approx((fixture["owner"].values["ball_vel"] as Vector2).length(), 10.0), "prediction must not mutate owner ball velocity")
	fixture["runtime"].wall_leap_state.force_return("seal", fixture["deps"])
	var return_context: Dictionary = BossContextBuilder.new().build_context(fixture["owner"], fixture["registry"])
	_expect(is_equal_approx((return_context.get("ball_vel", Vector2.ZERO) as Vector2).length(), 10.0), "prediction multiplier must disappear on return frame")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_ball_speed_scope_smoke: ok")
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)
