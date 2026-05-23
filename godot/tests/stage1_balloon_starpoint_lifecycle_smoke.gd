extends SceneTree

const Stage1BalloonEvent := preload("res://scripts/stages/stage1/stage1_balloon_event.gd")


func _init() -> void:
	seed(13579)

	_verify_stage_exit_clears_mid_flight_starpoints()
	_verify_starpoint_floor_cull_uses_spawn_clamp_boundary()
	_verify_draw_paths_hide_stale_starpoint_host()

	print("stage1_balloon_starpoint_lifecycle_smoke: ok")
	quit(0)


func _verify_stage_exit_clears_mid_flight_starpoints() -> void:
	var event := Stage1BalloonEvent.new()
	event.spawn_starpoint_drop(Vector2(320.0, 320.0))
	_expect(event.starpoint_drops.size() == 1, "Stage 1 balloon event should spawn one base starpoint drop")
	_expect(event.starpoint_particles.size() > 0, "starpoint spawn should create decorative particles")

	event.update(1.0 / 60.0, {"current_stage": 2, "width": 760.0, "height": 750.0}, {})
	_expect(event.starpoint_drops.is_empty(), "leaving Stage 1 should clear mid-flight starpoint drops")
	_expect(event.starpoint_particles.is_empty(), "leaving Stage 1 should clear starpoint particles")


func _verify_starpoint_floor_cull_uses_spawn_clamp_boundary() -> void:
	var event := Stage1BalloonEvent.new()
	var size: float = Stage1BalloonEvent.STARPOINT_DROP_SIZE
	var context := {
		"current_stage": 1,
		"width": 760.0,
		"height": 750.0,
		"player_pos": Vector2(-5000.0, -5000.0),
		"player_paddle_size": Vector2(1.0, 1.0),
	}

	event.starpoint_drops.append(_make_drop(Vector2(320.0, Stage1BalloonEvent.HEIGHT - size - 0.1), size))
	event.update(0.0, context, {})
	_expect(event.starpoint_drops.size() == 1, "starpoint just above the floor clamp should remain visible")

	event.starpoint_drops.clear()
	event.starpoint_drops.append(_make_drop(Vector2(320.0, Stage1BalloonEvent.HEIGHT - size + 0.1), size))
	event.update(0.0, context, {})
	_expect(event.starpoint_drops.is_empty(), "starpoint past the floor clamp should be culled")


func _verify_draw_paths_hide_stale_starpoint_host() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_event.gd")
	_expect(
		source.find("CommonStarpointVisualHost.hide_on_canvas(canvas)") >= 0,
		"Stage 1 draw paths should hide the shared starpoint host when drops are gone"
	)
	_expect(
		source.find("CommonStarpointVisualHost.hide_all_existing_hosts()") >= 0,
		"Stage 1 reset/stage-exit cleanup should hide stale shared starpoint host slots"
	)


func _make_drop(pos: Vector2, size: float) -> Dictionary:
	return {
		"pos": pos,
		"vel": Vector2.ZERO,
		"size": size,
		"rotation": 0.0,
		"rotation_speed": 0.0,
		"glow_intensity": 1.0,
		"glow_timer": 0.0,
		"life": Stage1BalloonEvent.STARPOINT_DROP_LIFETIME,
		"float_timer": 0.0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
