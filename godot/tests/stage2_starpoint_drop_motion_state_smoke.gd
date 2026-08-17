extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const StarpointDropMotionState := preload("res://scripts/stages/common/starpoint_drop_motion_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_drop_motion_updates_payload()
	_verify_drop_motion_expires_payload()
	_verify_drop_motion_bounces_at_bounds()
	_verify_drop_motion_culls_at_floor_edge()
	_verify_background_delegates_drop_motion()
	_verify_background_hides_stale_starpoint_host()

	if _failures.is_empty():
		print("stage2_starpoint_drop_motion_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_drop_motion_updates_payload() -> void:
	var drop := {
		"life": 10.0,
		"pos": Vector2(100.0, 100.0),
		"vel": Vector2(2.0, 3.0),
		"size": 12.0,
		"float_timer": 0.0,
		"rotation": 0.0,
		"rotation_speed": 0.5,
		"glow_timer": 0.0,
	}
	var alive := StarpointDropMotionState.update_drop(drop, 1.0, 0.0, 760.0, 750.0, 12.0, 12.0, 0.25, 0.7)
	_expect(alive, "starpoint drop motion should keep live drops")
	_expect(Vector2(drop.get("pos", Vector2.ZERO)).y > 100.0, "starpoint drop motion should advance y position")
	_expect(Vector2(drop.get("vel", Vector2.ZERO)).y > 3.0, "starpoint drop motion should accelerate fall speed")
	_expect(float(drop.get("glow_intensity", 0.0)) > 0.7, "starpoint drop motion should update glow")


func _verify_drop_motion_expires_payload() -> void:
	var drop := {
		"life": 0.5,
		"pos": Vector2(100.0, 100.0),
		"vel": Vector2.ZERO,
	}
	var alive := StarpointDropMotionState.update_drop(drop, 1.0, 0.0, 760.0, 750.0, 12.0, 12.0, 0.25, 0.7)
	_expect(not alive, "starpoint drop motion should expire dead drops")


func _verify_drop_motion_bounces_at_bounds() -> void:
	var drop := {
		"life": 10.0,
		"pos": Vector2(4.0, 100.0),
		"vel": Vector2(-3.0, 0.0),
		"size": 12.0,
	}
	var alive := StarpointDropMotionState.update_drop(drop, 1.0, 0.0, 760.0, 750.0, 12.0, 12.0, 0.25, 0.7)
	_expect(alive, "starpoint drop motion should keep bounced drops alive")
	_expect(is_equal_approx(Vector2(drop.get("pos", Vector2.ZERO)).x, 12.0), "starpoint drop motion should clamp left bound")
	_expect(Vector2(drop.get("vel", Vector2.ZERO)).x > 0.0, "starpoint drop motion should bounce x velocity inward")


func _verify_drop_motion_culls_at_floor_edge() -> void:
	var drop := {
		"life": 10.0,
		"pos": Vector2(100.0, 744.2),
		"vel": Vector2.ZERO,
		"size": 12.0,
	}
	var alive := StarpointDropMotionState.update_drop(drop, 0.0, 0.0, 760.0, 750.0, 12.0, 12.0, 0.25, 0.7)
	_expect(not alive, "starpoint drop motion should cull when the rendered bottom edge reaches the floor")


func _verify_background_delegates_drop_motion() -> void:
	var paths := [
		"res://scripts/stages/stage1/stage1_balloon_starpoint_state.gd",
		"res://scripts/stages/stage2/stage2_starpoint_coordinator.gd",
		"res://scripts/stages/stage3/stage3_starpoint_state.gd",
		"res://scripts/stages/stage4/stage4_bird_starpoint_state.gd",
	]
	for path in paths:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(
			source.find("StarpointDropMotionState.update_drop") >= 0,
			"%s should delegate starpoint drop motion" % path
		)
	var background := Stage2PillarBackground.new()
	background.starpoint_drops = [{
		"life": 10.0,
		"pos": Vector2(100.0, 100.0),
		"vel": Vector2(2.0, 3.0),
		"size": 12.0,
	}]
	background._update_starpoint_drops(1.0, {
		"current_stage": 2,
		"player_pos": Vector2(700.0, 700.0),
		"player_paddle_size": Vector2(20.0, 20.0),
		"play_left": 0.0,
		"play_right": 760.0,
		"height": 750.0,
	}, {})
	_expect(background.starpoint_drops.size() == 1, "Stage 2 background should keep live moving starpoint drops")
	var updated: Dictionary = background.starpoint_drops[0]
	_expect(Vector2(updated.get("pos", Vector2.ZERO)).y > 100.0, "Stage 2 background should use delegated drop motion")


func _verify_background_hides_stale_starpoint_host() -> void:
	var background_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	var coordinator_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_starpoint_coordinator.gd")
	var renderer_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_obstacle_visual_renderer.gd")
	_expect(
		background_source.find("obstacle_visual_renderer.hide_starpoint_drops(canvas)") >= 0,
		"Stage 2 overlay draw should hide stale starpoint host slots when no drops remain"
	)
	_expect(
		coordinator_source.find("obstacle_visual_renderer.hide_all_starpoint_drops()") >= 0,
		"Stage 2 starpoint coordinator should hide stale shared host slots on stage exit"
	)
	_expect(
		renderer_source.find("CommonStarpointVisualHost.hide_on_canvas(canvas)") >= 0,
		"Stage 2 starpoint renderer should expose host hiding for empty-drop frames"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
