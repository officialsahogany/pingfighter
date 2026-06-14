extends SceneTree

const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")
const Stage5HongryunActorRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_actor_renderer.gd")
const Stage5HongryunFireMachineEvent := preload("res://scripts/stages/stage5/stage5_hongryun_fire_machine_event.gd")
const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")

const GAME_OFFSET := Vector2(96.0, 34.0)
const GAME_SIZE := Vector2(760.0, 750.0)
const RENDER_SCALE := 0.78

var _failures: Array[String] = []


class FakeAudio:
	var stop_fireball_calls := 0
	var stop_charge_calls := 0
	var stop_shoot_calls := 0

	func stop_stage5_hongryun_fireball() -> void:
		stop_fireball_calls += 1

	func stop_stage5_hongryun_charge() -> void:
		stop_charge_calls += 1

	func stop_stage5_hongryun_shoot() -> void:
		stop_shoot_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var canvas := Node2D.new()
	get_root().add_child(canvas)

	var actor_renderer := Stage5HongryunActorRenderer.new()
	var playfield_renderer: Object = actor_renderer.get("playfield_renderer")
	playfield_renderer.call("_sync_inferno_charge_fx_host", canvas, _build_charge_context(), Vector2.ZERO, 1.0)
	playfield_renderer.call("_sync_inferno_trail_fx_host", canvas, _build_trail_context(), Vector2.ZERO, 1.0)
	playfield_renderer.call("_sync_inferno_burst_fx_host", canvas, _build_burst_context(), Vector2.ZERO, 1.0)
	await process_frame

	var charge_host: Node = canvas.get_node_or_null("Stage5HongryunInfernoChargeFxHost")
	var trail_host: Node = canvas.get_node_or_null("Stage5HongryunInfernoTrailFxHost")
	var burst_host: Node = canvas.get_node_or_null("Stage5HongryunInfernoBurstFxHost")
	_expect(charge_host != null, "Stage 5 inferno charge draw should attach the FX host")
	if charge_host != null:
		var active_status: Dictionary = charge_host.get_debug_status()
		_expect(bool(active_status.get("active", false)), "Stage 5 inferno charge host should be active before round cleanup")
		_expect(bool(active_status.get("dragon_ring_visible", false)), "Stage 5 inferno charge ring should be visible before round cleanup")
		_expect(charge_host.position.distance_to(_expected_host_pos(Vector2(380.0, 320.0))) <= 0.01, "Stage 5 inferno charge host should apply game offset and render scale")
		_expect(charge_host.scale.distance_to(Vector2(RENDER_SCALE, RENDER_SCALE)) <= 0.001, "Stage 5 inferno charge host should scale with the rendered playfield")
	_expect(trail_host != null, "Stage 5 inferno trail draw should attach the FX host")
	if trail_host != null:
		var trail_status: Dictionary = trail_host.get_debug_status()
		_expect(bool(trail_status.get("active", false)), "Stage 5 inferno trail host should be active before round cleanup")
		_expect(bool(trail_status.get("dragon_ring_visible", false)), "Stage 5 inferno trail ring should be visible before round cleanup")
		_expect(trail_host.position.distance_to(_expected_host_pos(Vector2(380.0, 320.0))) <= 0.01, "Stage 5 inferno trail host should apply game offset and render scale")
		_expect(trail_host.scale.distance_to(Vector2(RENDER_SCALE, RENDER_SCALE)) <= 0.001, "Stage 5 inferno trail host should scale with the rendered playfield")
	_expect(burst_host != null, "Stage 5 inferno burst draw should attach the FX host")
	if burst_host != null:
		var burst_status: Dictionary = burst_host.get_debug_status()
		_expect(bool(burst_status.get("active", false)), "Stage 5 inferno burst host should be active before round cleanup")
		_expect(burst_host.position.distance_to(_expected_host_pos(Vector2(380.0, 320.0))) <= 0.01, "Stage 5 inferno burst host should apply game offset and render scale")
		_expect(burst_host.scale.distance_to(Vector2(RENDER_SCALE, RENDER_SCALE)) <= 0.001, "Stage 5 inferno burst host should scale with the rendered playfield")

	var fire_machine_event := Stage5HongryunFireMachineEvent.new()
	fire_machine_event.active = true
	fire_machine_event.fire_zones = [{
		"pos": Vector2(380.0, 700.0),
		"width": 80.0,
		"height": 32.0,
		"duration": 150.0,
		"spread_timer": 0.0,
		"flames": [],
	}]
	var audio := FakeAudio.new()

	var cleanup := BallRoundActorCleanup.new()
	cleanup.reset_actor_round_state({
		"stage5_hongryun_state": Stage5HongryunState.new(),
		"stage5_hongryun_fire_machine_event": fire_machine_event,
		"stage5_hongryun_actor_renderer": actor_renderer,
		"audio": audio,
	})
	await process_frame

	if charge_host != null and is_instance_valid(charge_host):
		var cleared_status: Dictionary = charge_host.get_debug_status()
		_expect(not bool(cleared_status.get("active", true)), "Round cleanup should deactivate the Stage 5 inferno charge FX host")
		_expect(not charge_host.visible, "Round cleanup should hide the Stage 5 inferno charge FX host")
		_expect(not bool(cleared_status.get("dragon_ring_visible", true)), "Round cleanup should hide the Stage 5 inferno charge ring")
		_expect(not bool(cleared_status.get("ember_emitting", true)), "Round cleanup should stop Stage 5 inferno charge particles")
	if trail_host != null and is_instance_valid(trail_host):
		var cleared_trail_status: Dictionary = trail_host.get_debug_status()
		_expect(not bool(cleared_trail_status.get("active", true)), "Round cleanup should deactivate the Stage 5 inferno trail FX host")
		_expect(not trail_host.visible, "Round cleanup should hide the Stage 5 inferno trail FX host")
		_expect(not bool(cleared_trail_status.get("dragon_ring_visible", true)), "Round cleanup should hide the Stage 5 inferno trail ring")
		_expect(not bool(cleared_trail_status.get("ember_emitting", true)), "Round cleanup should stop Stage 5 inferno trail particles")
	if burst_host != null and is_instance_valid(burst_host):
		var cleared_burst_status: Dictionary = burst_host.get_debug_status()
		_expect(not bool(cleared_burst_status.get("active", true)), "Round cleanup should deactivate the Stage 5 inferno burst FX host")
		_expect(not burst_host.visible, "Round cleanup should hide the Stage 5 inferno burst FX host")
	_expect(not fire_machine_event.is_active(), "Round cleanup should deactivate the Stage 5 fire-machine event")
	_expect(fire_machine_event.fire_zones.is_empty(), "Round cleanup should clear Stage 5 fire-machine zones")
	_expect(audio.stop_charge_calls == 1, "Round cleanup should stop the Stage 5 Hongryun charge cue")
	_expect(audio.stop_fireball_calls == 1, "Round cleanup should stop the Stage 5 Hongryun fireball cue")
	_expect(audio.stop_shoot_calls == 1, "Round cleanup should stop the Stage 5 Hongryun shoot cue")

	canvas.queue_free()
	await process_frame

	var reset_canvas := Node2D.new()
	get_root().add_child(reset_canvas)
	var reset_actor_renderer := Stage5HongryunActorRenderer.new()
	var reset_playfield_renderer: Object = reset_actor_renderer.get("playfield_renderer")
	reset_playfield_renderer.call("_sync_inferno_charge_fx_host", reset_canvas, _build_charge_context(), Vector2.ZERO, 1.0)
	await process_frame
	var reset_charge_host: Node = reset_canvas.get_node_or_null("Stage5HongryunInfernoChargeFxHost")
	_expect(reset_charge_host != null, "Stage 5 reset-stage smoke should attach the FX host")

	MatchResetController.new().reset_stage_state({
		"stage5_hongryun_actor_renderer": reset_actor_renderer,
	})
	await process_frame

	if reset_charge_host != null and is_instance_valid(reset_charge_host):
		var reset_status: Dictionary = reset_charge_host.get_debug_status()
		_expect(not bool(reset_status.get("active", true)), "Stage reset should deactivate the Stage 5 actor FX host")
		_expect(not reset_charge_host.visible, "Stage reset should hide the Stage 5 actor FX host")
	reset_canvas.queue_free()

	if _failures.is_empty():
		print("stage5_hongryun_round_boundary_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_charge_context() -> Dictionary:
	return {
		"current_stage": 5,
		"width": 760.0,
		"height": 750.0,
		"game_size": GAME_SIZE,
		"game_offset": GAME_OFFSET,
		"render_scale": RENDER_SCALE,
		"ball_pos": Vector2(380.0, 320.0),
		"stage5_hongryun_inferno_active": true,
		"stage5_hongryun_inferno_phase": 1,
		"stage5_hongryun_inferno_charge_ratio": 0.65,
		"stage5_hongryun_inferno_enraged": false,
	}


func _build_trail_context() -> Dictionary:
	return {
		"current_stage": 5,
		"width": 760.0,
		"height": 750.0,
		"game_size": GAME_SIZE,
		"game_offset": GAME_OFFSET,
		"render_scale": RENDER_SCALE,
		"stage5_hongryun_inferno_active": true,
		"stage5_hongryun_inferno_phase": 2,
		"stage5_hongryun_inferno_trail": [
			Vector2(340.0, 260.0),
			Vector2(380.0, 320.0),
		],
		"stage5_hongryun_inferno_trail_elapsed_sec": 0.8,
		"stage5_hongryun_inferno_enraged": false,
	}


func _build_burst_context() -> Dictionary:
	return {
		"current_stage": 5,
		"width": 760.0,
		"height": 750.0,
		"game_size": GAME_SIZE,
		"game_offset": GAME_OFFSET,
		"render_scale": RENDER_SCALE,
		"stage5_hongryun_inferno_burst_pending": true,
		"stage5_hongryun_inferno_burst_pos": Vector2(380.0, 320.0),
		"stage5_hongryun_inferno_enraged": false,
	}


func _expected_host_pos(playfield_pos: Vector2) -> Vector2:
	return GAME_OFFSET + playfield_pos * RENDER_SCALE


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
