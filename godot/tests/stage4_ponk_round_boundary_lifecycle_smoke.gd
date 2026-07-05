extends SceneTree

const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")
const Stage4PonkAwakenAuraFxHost := preload("res://scripts/stages/stage4/stage4_ponk_awaken_aura_fx_host.gd")
const Stage4PonkSkillState := preload("res://scripts/stages/stage4/stage4_ponk_skill_state.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var stop_magnetic_calls := 0

	func stop_stage4_magnetic_loop() -> void:
		stop_magnetic_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var canvas := Node2D.new()
	get_root().add_child(canvas)

	var skill_state := Stage4PonkSkillState.new()
	var audio := FakeAudio.new()
	skill_state.force_spawn_magnetic_projectile(Vector2(380.0, 220.0), 96.0)
	skill_state.set("magnetic_projectile_elapsed_seconds", 0.35)
	skill_state.call("_sync_magnetic_fx_host", canvas, _build_context(), Vector2.ZERO, true)
	await process_frame

	var magnetic_host: Node = canvas.get_node_or_null("PonkMagneticFxHost")
	_expect(magnetic_host != null, "Stage 4 magnetic projectile draw should attach the FX host")
	if magnetic_host != null:
		var active_status: Dictionary = magnetic_host.get_debug_status()
		_expect(bool(active_status.get("active", false)), "Stage 4 magnetic projectile host should be active before round cleanup")
		_expect(bool(active_status.get("projectile_orb_visible", false)), "Stage 4 magnetic projectile orb should be visible before round cleanup")

	var cleanup := BallRoundActorCleanup.new()
	cleanup.reset_actor_round_state({
		"stage4_ponk_skill_state": skill_state,
		"audio": audio,
	})
	await process_frame

	_expect(not bool(skill_state.get("magnetic_projectile_active")), "Round cleanup should clear the Stage 4 magnetic projectile state")
	_expect(is_zero_approx(float(skill_state.get("magnetic_projectile_fade_timer_seconds"))), "Round cleanup should clear the Stage 4 magnetic projectile fade")
	_expect(audio.stop_magnetic_calls == 1, "Round cleanup should stop the Stage 4 magnetic loop audio")
	if magnetic_host != null and is_instance_valid(magnetic_host):
		var cleared_status: Dictionary = magnetic_host.get_debug_status()
		_expect(not bool(cleared_status.get("active", true)), "Round cleanup should deactivate the Stage 4 magnetic FX host")
		_expect(not magnetic_host.visible, "Round cleanup should hide the Stage 4 magnetic FX host")
		_expect(not bool(cleared_status.get("projectile_orb_visible", true)), "Round cleanup should hide the Stage 4 magnetic projectile orb")

	var aura_host := Stage4PonkAwakenAuraFxHost.new()
	aura_host.name = "PonkAwakenAuraFxHost"
	canvas.add_child(aura_host)
	await process_frame
	aura_host.prewarm_runtime_nodes()
	aura_host.sync_state({
		"active": true,
		"intensity": 1.0,
		"boss_center": Vector2(380.0, 96.0),
		"elapsed": 1.25,
		"enraged": false,
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
	}, true)
	await process_frame
	_expect(bool(aura_host.get_debug_status().get("visible", false)), "Setup should leave the Stage 4 awaken aura host visible before stage reset")
	MatchResetController.new().reset_stage_state({})
	await process_frame
	_expect(not bool(aura_host.get_debug_status().get("visible", true)), "Stage reset should hide orphaned Stage 4 awaken aura hosts")
	_expect(not bool(aura_host.get_debug_status().get("mote_emitting", true)), "Stage reset should stop orphaned Stage 4 awaken aura particles")

	canvas.queue_free()

	if _failures.is_empty():
		print("stage4_ponk_round_boundary_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_context() -> Dictionary:
	return {
		"current_stage": 4,
		"width": 760.0,
		"height": 750.0,
		"game_size": Vector2(760.0, 750.0),
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
		"boss_pos": Vector2(330.0, 54.0),
		"boss_paddle_size": Vector2(100.0, 18.0),
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 280.0),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
