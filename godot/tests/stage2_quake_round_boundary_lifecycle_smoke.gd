extends SceneTree

const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var quake_start_count := 0
	var quake_stop_count := 0

	func play_stage2_quake_loop() -> void:
		quake_start_count += 1

	func stop_stage2_quake_loop() -> void:
		quake_stop_count += 1


func _init() -> void:
	var stage2_background := Stage2PillarBackground.new()
	var audio := FakeAudio.new()
	stage2_background.activate_quake(1.0, 0, false, true, {"audio": audio})
	_expect(stage2_background.is_quake_active(), "Stage 2 quake should be active before round cleanup")
	_expect(audio.quake_start_count == 1, "Stage 2 quake activation should start loop audio")

	var quake_scene := {
		"ball_pos": Vector2(330.0, 52.0),
		"ball_vel": Vector2(2.0, -5.0),
	}
	var quake_context := _build_quake_context()
	_expect(
		stage2_background.apply_quake_ball_motion(quake_scene, quake_context, {}, 1.0),
		"Stage 2 quake should perturb active rally ball motion before cleanup"
	)

	BallRoundActorCleanup.new().reset_actor_round_state({
		"stage2_pillar_background": stage2_background,
		"audio": audio,
	})
	_expect(not stage2_background.is_quake_active(), "Round cleanup should end active Stage 2 quake timing")
	_expect(audio.quake_stop_count >= 1, "Round cleanup should stop the Stage 2 quake loop")

	var serve_scene := {
		"ball_pos": Vector2(380.0, 670.0),
		"ball_vel": Vector2(0.0, -8.0),
	}
	var serve_velocity: Vector2 = _as_vector2(serve_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	_expect(
		not stage2_background.apply_quake_ball_motion(serve_scene, quake_context, {}, 1.0),
		"Round cleanup should prevent leftover quake motion from touching the next serve"
	)
	_expect(
		_as_vector2(serve_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO).is_equal_approx(serve_velocity),
		"Next serve velocity should stay unchanged after Stage 2 quake cleanup"
	)

	if _failures.is_empty():
		print("stage2_quake_round_boundary_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_quake_context() -> Dictionary:
	return {
		"current_stage": 2,
		"base_ball_speed": 8.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(320.0, 25.0),
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
