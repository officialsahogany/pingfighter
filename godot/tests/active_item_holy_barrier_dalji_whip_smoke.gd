extends SceneTree

const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const Stage1DaljiWhipSkillState := preload("res://scripts/stages/stage1/stage1_dalji_whip_skill_state.gd")

var _failures: Array[String] = []


class FakeActiveItemRuntime:
	extends RefCounted

	var hit_count := 0
	var last_hit_pos := Vector2.ZERO

	func get_ball_collision_context() -> Dictionary:
		return {
			"holy_barrier_active": true,
			"holy_barrier_y": 725.0,
			"holy_barrier_height": 20.0,
		}

	func notify_holy_barrier_hit(impact_pos: Vector2) -> void:
		hit_count += 1
		last_hit_pos = impact_pos


class FakeAudio:
	extends RefCounted

	var wall_hit_count := 0

	func play_wall_hit(_speed: float = 0.0, _source_x: float = 380.0) -> void:
		wall_hit_count += 1


func _init() -> void:
	_verify_holy_barrier_releases_dalji_whip_control()

	if _failures.is_empty():
		print("active_item_holy_barrier_dalji_whip_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_holy_barrier_releases_dalji_whip_control() -> void:
	var whip: Object = Stage1DaljiWhipSkillState.new()
	whip.active = true
	whip.timer_frames = 120.0
	whip.original_ball_y_speed = 9.0

	var active_item_runtime := FakeActiveItemRuntime.new()
	var audio := FakeAudio.new()
	var scene := {
		"ball_pos": Vector2(380.0, 710.0),
		"ball_vel": Vector2(2.0, 9.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
		"stage1_dalji_whip_controls_speed": true,
	}
	var context := {
		"current_stage": 1,
		"ball_size": 28.6,
		"width": 760.0,
		"height": 750.0,
		"max_step_distance": 12.0,
		"player_pos": Vector2(-400.0, -400.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(-400.0, -400.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"hitbox_padding": 5.0,
	}
	var deps := {
		"motion_stepper": BallMotionStepper.new(),
		"active_item_runtime": active_item_runtime,
		"stage1_dalji_whip_skill_state": whip,
		"audio": audio,
	}

	var score_event: String = BallMotionEventProcessor.new().step_motion(scene, 1.0, context, deps, {})
	_expect(score_event == "", "Holy Barrier reflection during Dalji whip should not score")
	_expect(active_item_runtime.hit_count == 1, "Holy Barrier should still receive its hit notification")
	_expect(audio.wall_hit_count == 1, "Holy Barrier reflection should keep the wall-hit audio cue")
	_expect(_get_vector2(scene, "ball_vel", Vector2.ZERO).y < 0.0, "Holy Barrier should reflect the whip-driven ball upward")
	_expect(not bool(whip.is_active()), "Holy Barrier guard hit should deactivate Dalji whip ball control")
	_expect(not bool(scene.get("stage1_dalji_whip_controls_speed", true)), "released whip should stop owning speed control")

	var followup: Dictionary = whip.update_ball_motion(1.0, _get_vector2(scene, "ball_vel", Vector2.ZERO), context)
	_expect(
		not bool(followup.get("stage1_dalji_whip_controls_speed", false)),
		"released whip should not force the reflected ball downward on the next frame"
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
