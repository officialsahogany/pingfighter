extends SceneTree

const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const Stage5HongryunActorRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_actor_renderer.gd")
const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var canvas := Node2D.new()
	get_root().add_child(canvas)

	var actor_renderer := Stage5HongryunActorRenderer.new()
	var playfield_renderer: Object = actor_renderer.get("playfield_renderer")
	playfield_renderer.call("_sync_inferno_charge_fx_host", canvas, _build_charge_context(), Vector2.ZERO, 1.0)
	await process_frame

	var charge_host: Node = canvas.get_node_or_null("Stage5HongryunInfernoChargeFxHost")
	_expect(charge_host != null, "Stage 5 inferno charge draw should attach the FX host")
	if charge_host != null:
		var active_status: Dictionary = charge_host.get_debug_status()
		_expect(bool(active_status.get("active", false)), "Stage 5 inferno charge host should be active before round cleanup")
		_expect(bool(active_status.get("dragon_ring_visible", false)), "Stage 5 inferno charge ring should be visible before round cleanup")

	var cleanup := BallRoundActorCleanup.new()
	cleanup.reset_actor_round_state({
		"stage5_hongryun_state": Stage5HongryunState.new(),
		"stage5_hongryun_actor_renderer": actor_renderer,
	})
	await process_frame

	if charge_host != null and is_instance_valid(charge_host):
		var cleared_status: Dictionary = charge_host.get_debug_status()
		_expect(not bool(cleared_status.get("active", true)), "Round cleanup should deactivate the Stage 5 inferno charge FX host")
		_expect(not charge_host.visible, "Round cleanup should hide the Stage 5 inferno charge FX host")
		_expect(not bool(cleared_status.get("dragon_ring_visible", true)), "Round cleanup should hide the Stage 5 inferno charge ring")
		_expect(not bool(cleared_status.get("ember_emitting", true)), "Round cleanup should stop Stage 5 inferno charge particles")

	canvas.queue_free()

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
		"game_size": Vector2(760.0, 750.0),
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
		"ball_pos": Vector2(380.0, 320.0),
		"stage5_hongryun_inferno_active": true,
		"stage5_hongryun_inferno_phase": 1,
		"stage5_hongryun_inferno_charge_ratio": 0.65,
		"stage5_hongryun_inferno_enraged": false,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
