extends SceneTree

const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")


class AudioProbe:
	extends RefCounted

	var calls: Array[String] = []

	func play_stage3_psychoball_loop() -> void:
		calls.append("play_stage3_psychoball_loop")

	func stop_stage3_psychoball_loop() -> void:
		calls.append("stop_stage3_psychoball_loop")

	func sync_stage3_psychoball_loop(active: bool) -> void:
		calls.append("sync_stage3_psychoball_loop:%s" % str(active))

	func play_paddle_hit(_source_x: float = 380.0) -> void:
		calls.append("play_paddle_hit")


class FeedbackProbe:
	extends RefCounted

	var shake_calls: Array[Vector2] = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		shake_calls.append(Vector2(amount, intensity))


class ThrowControllerProbe:
	extends RefCounted

	var zones: Array = []

	func get_tear_gas_zones() -> Array:
		return zones


class ActiveItemRuntimeProbe:
	extends RefCounted

	var throw_controller := ThrowControllerProbe.new()


class FlowCallbacksProbe:
	extends RefCounted

	var calls: Array[String] = []

	func update_effects(_delta: float) -> void:
		calls.append("update_effects")

	func update_ball(_delta: float) -> void:
		calls.append("update_ball")

	func update_player_control(_delta: float) -> void:
		calls.append("update_player_control")

	func update_boss_ai(_delta: float) -> void:
		calls.append("update_boss_ai")

	func queue_redraw() -> void:
		calls.append("queue_redraw")


func _init() -> void:
	_verify_original_duration_audio_and_ball_motion()
	_verify_enraged_duration()
	_verify_dense_smoke_neutralizes_psychoball()
	_verify_active_item_tear_gas_zones_feed_psychoball()
	_verify_frame_flow_blocks_motion_during_psychoball_hitstop()
	_verify_ball_update_freezes_during_psychoball_hitstop()
	print("stage3_psychoball_parity_smoke: ok")
	quit(0)


func _verify_original_duration_audio_and_ball_motion() -> void:
	var state: Object = Stage3BossSkillState.new()
	var audio := AudioProbe.new()
	var feedback := FeedbackProbe.new()
	var context := _stage3_runtime_context()
	state.set("psycho_cooldown", 0.0)
	state.set("tears_cooldown", 10.0)
	state.set("curse_cooldown", 10.0)
	state.update(1.0 / 60.0, context, {"audio": audio, "feedback": feedback})
	_expect(not bool(state.get_snapshot().get("stage3_emotional_overdrive_active", false)), "psycho ball should wait for a boss hit once its cooldown is ready")
	var hit_result: Dictionary = state.register_boss_hit(Vector2(2.0, -8.0), context, {"audio": audio, "feedback": feedback})

	_expect(bool(hit_result.get("stage3_psychoball_hit_triggered", false)), "psycho ball should trigger from a boss hit when ready")
	_expect(bool(state.get_snapshot().get("stage3_emotional_overdrive_active", false)), "psycho ball should activate from the 70-second cooldown card")
	_expect(bool(state.get_snapshot().get("stage3_psychoball_hitstop_active", false)), "psycho ball should start hitstop on hit activation")
	_expect(not feedback.shake_calls.is_empty(), "psycho ball hit activation should request screen-shake feedback")
	_expect(abs(float(state.get("overdrive_timer")) - 5.0) <= 0.001, "normal psycho ball duration should match the original 300-frame timer")
	_expect(audio.calls.has("play_stage3_psychoball_loop"), "psycho ball should start the original looping psychoball.wav cue")
	state.update(1.0 / 60.0, context, {"audio": audio, "feedback": feedback})
	_expect(audio.calls.has("sync_stage3_psychoball_loop:true"), "psycho ball loop should remain synced while active")

	state.set("psychoball_hitstop_timer", 0.0)
	var result: Dictionary = state.update(1.0 / 60.0, context, {"audio": audio})
	_expect(result.has("ball_vel"), "psycho ball should return a modified ball velocity to the runtime")
	_expect(is_equal_approx(_as_vector2(result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).y, -8.0), "psycho ball should preserve the original Y velocity while curving X")
	_expect(float(state.get_snapshot().get("stage3_psycho_bg_timer", 0.0)) > 0.0, "psycho ball should advance the original background flash timer")
	var trails: Array = _as_array(state.get_snapshot().get("stage3_overdrive_trails", []))
	_expect(not trails.is_empty(), "psycho ball should emit boss afterimage trails")
	_expect(abs(float(_as_dict(trails[0]).get("alpha", 0.0)) - (190.0 / 255.0)) <= 0.001, "psycho ball boss trail alpha should fade from the original 200 by 10 each frame")

	state.set("overdrive_timer", 0.001)
	state.update(1.0 / 60.0, context, {"audio": audio})
	_expect(not bool(state.get_snapshot().get("stage3_emotional_overdrive_active", true)), "psycho ball should stop after its original duration expires")
	_expect(audio.calls.has("stop_stage3_psychoball_loop"), "psycho ball should stop its loop on expiry")


func _verify_enraged_duration() -> void:
	var state: Object = Stage3BossSkillState.new()
	var context := _stage3_runtime_context()
	context["enraged_boss_active"] = true
	state.set("psycho_cooldown", 0.0)
	state.set("tears_cooldown", 10.0)
	state.set("curse_cooldown", 10.0)
	state.register_boss_hit(Vector2(2.0, -8.0), context, {"audio": AudioProbe.new()})
	_expect(abs(float(state.get("overdrive_timer")) - 7.5) <= 0.001, "enraged psycho ball duration should match the original 450-frame timer")


func _verify_dense_smoke_neutralizes_psychoball() -> void:
	var state: Object = Stage3BossSkillState.new()
	var audio := AudioProbe.new()
	var context := _stage3_runtime_context()
	state.set("psycho_cooldown", 0.0)
	state.set("tears_cooldown", 10.0)
	state.set("curse_cooldown", 10.0)
	state.register_boss_hit(Vector2(2.0, -8.0), context, {"audio": audio})
	state.set("psychoball_hitstop_timer", 0.0)

	context["stage3_smoke_zones"] = [{
		"position": Vector2(380.0, 360.0),
		"radius": 90.0,
		"radius_x": 120.0,
		"opacity": 0.40,
	}]
	var result: Dictionary = state.update(1.0 / 60.0, context, {"audio": audio})
	var expected_vel: Vector2 = (Vector2(375.0, 45.0) - Vector2(380.0, 360.0)).normalized() * 10.0
	_expect(bool(result.get("stage3_psychoball_smoke_neutralized", false)), "dense smoke should neutralize psycho ball like the Python reference")
	_expect(not bool(state.get_snapshot().get("stage3_emotional_overdrive_active", true)), "smoke neutralization should immediately end psycho ball")
	_expect(_as_vector2(result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).distance_to(expected_vel) <= 0.001, "smoke neutralization should redirect the ball toward the boss at speed 10")
	_expect(_as_array(state.get_snapshot().get("stage3_psychoball_neutralize_particles", [])).size() == 20, "smoke neutralization should spawn the original 20 purple particles")
	_expect(audio.calls.has("stop_stage3_psychoball_loop"), "smoke neutralization should stop the psycho ball loop")
	_expect(audio.calls.has("play_paddle_hit"), "smoke neutralization should fall back to the original paddle cue when smoke_neutralize.wav is absent")


func _verify_active_item_tear_gas_zones_feed_psychoball() -> void:
	var state: Object = Stage3BossSkillState.new()
	var context := _stage3_runtime_context()
	var runtime := ActiveItemRuntimeProbe.new()
	runtime.throw_controller.zones = [{
		"position": Vector2(380.0, 360.0),
		"radius": 80.0,
		"radius_x": 110.0,
		"opacity": 0.40,
	}]
	state.set("psycho_cooldown", 0.0)
	state.set("tears_cooldown", 10.0)
	state.set("curse_cooldown", 10.0)
	state.register_boss_hit(Vector2(2.0, -8.0), context, {"audio": AudioProbe.new(), "active_item_runtime": runtime})
	state.set("psychoball_hitstop_timer", 0.0)
	var result: Dictionary = state.update(1.0 / 60.0, context, {"audio": AudioProbe.new(), "active_item_runtime": runtime})
	_expect(bool(result.get("stage3_psychoball_smoke_neutralized", false)), "live tear-gas zones should feed the Stage 3 psycho ball neutralizer")


func _verify_frame_flow_blocks_motion_during_psychoball_hitstop() -> void:
	var state: Object = Stage3BossSkillState.new()
	state.set("psychoball_hitstop_timer", 0.05)
	var callbacks := FlowCallbacksProbe.new()
	BattleFrameFlowController.new().update(1.0 / 60.0, {
		"current_stage": 3,
		"stage3_boss_skill_state": state,
		"scoreboard_state": null,
		"skill_orb_tooltip_active": false,
		"power_state": null,
		"round_state": null,
		"mythic_item_runtime": null,
	}, {
		"update_effects": Callable(callbacks, "update_effects"),
		"update_ball": Callable(callbacks, "update_ball"),
		"update_player_control": Callable(callbacks, "update_player_control"),
		"update_boss_ai": Callable(callbacks, "update_boss_ai"),
		"queue_redraw": Callable(callbacks, "queue_redraw"),
	})
	_expect(callbacks.calls == ["update_effects", "queue_redraw"], "psycho ball hitstop should freeze motion and only tick effects/redraw")


func _verify_ball_update_freezes_during_psychoball_hitstop() -> void:
	var state: Object = Stage3BossSkillState.new()
	state.set("psychoball_hitstop_timer", 0.05)
	var context := _stage3_runtime_context()
	context["ball_pos"] = Vector2(380.0, 360.0)
	context["ball_vel"] = Vector2(3.0, -9.0)
	var result: Dictionary = BallUpdateController.new().update(1.0 / 60.0, context, {
		"stage3_boss_skill_state": state,
	})
	var snapshot: Dictionary = result.get("snapshot", {})
	_expect(_as_vector2(snapshot.get("ball_pos", Vector2.ZERO), Vector2.ZERO) == Vector2(380.0, 360.0), "direct ball update should hold ball position during psycho ball hitstop")
	_expect(_as_vector2(snapshot.get("ball_vel", Vector2.ZERO), Vector2.ZERO) == Vector2(3.0, -9.0), "direct ball update should preserve ball velocity during psycho ball hitstop")


func _stage3_runtime_context() -> Dictionary:
	return {
		"current_stage": 3,
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(380.0, 360.0),
		"ball_vel": Vector2(2.0, -8.0),
		"boss_pos": Vector2(325.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_score": 0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
