extends SceneTree

const Stage1BalloonEvent := preload("res://scripts/stages/stage1/stage1_balloon_event.gd")
const Stage1BalloonRuntimeState := preload("res://scripts/stages/stage1/stage1_balloon_runtime_state.gd")
const Stage1BalloonInteractionCoordinator := preload("res://scripts/stages/stage1/stage1_balloon_interaction_coordinator.gd")


class FeedbackHost:
	var pop_ids: Array[String] = []
	var observed_scene: Dictionary = {}
	var original_ball_velocity := Vector2.ZERO
	var feedback_before_deflect := false

	func _handle_balloon_pop(balloon: Dictionary, _deps: Dictionary, _context: Dictionary = {}) -> void:
		pop_ids.append(str(balloon.get("id", "")))
		if not observed_scene.is_empty():
			feedback_before_deflect = observed_scene.get("ball_vel", Vector2.ZERO) == original_ball_velocity


class MovementStateStub:
	var calls := 0
	var velocity_x := 0.0
	var frames := 0.0

	func start_knockback(next_velocity_x: float, next_frames: float) -> void:
		calls += 1
		velocity_x = next_velocity_x
		frames = next_frames


class CleanseStub:
	var immune := false

	func is_immune() -> bool:
		return immune


class MythicImmunityStub:
	var calls := 0
	var immune := false

	func try_consume_celestial_armor_immunity(_source: String, _effect: String, _deps: Dictionary) -> bool:
		calls += 1
		return immune


class WhipStub:
	var active := false

	func get_draw_context() -> Dictionary:
		return {"boss_whip_active": active}


func _init() -> void:
	_verify_retained_motion_and_geometry()
	_verify_ball_collision_feedback_before_deflection()
	_verify_projectile_and_chaos_routes()
	_verify_paddle_dash_knockback_and_immunity_order()
	_verify_facade_compatibility_and_source_ownership()
	print("stage1_balloon_gameplay_coordinator_smoke: ok")
	quit(0)


func _verify_retained_motion_and_geometry() -> void:
	var state := Stage1BalloonRuntimeState.new()
	state.configure_bounds(0.0, 100.0, 100.0)
	state.balloons = [_make_balloon("wall", Vector2(95.0, 50.0), Vector2(10.0, 0.0), 10.0)]
	state.update_motion(1.0)
	var wall_balloon: Dictionary = state.balloons[0]
	_expect(is_equal_approx(Vector2(wall_balloon.get("pos", Vector2.ZERO)).x, 90.0), "motion owner should clamp the rendered radius at the right wall")
	_expect(is_equal_approx(Vector2(wall_balloon.get("vel", Vector2.ZERO)).x, -10.0), "motion owner should reflect right-wall velocity")
	_expect(is_equal_approx(float(wall_balloon.get("lifetime", 0.0)), 1.0), "motion owner should advance balloon lifetime")

	state.balloons = [_make_balloon("slow", Vector2(20.0, 30.0), Vector2(10.0, 0.0), 5.0)]
	state.balloons[0]["paddle_bounce_cooldown"] = 2.0
	state.balloons[0]["paddle_bounce_slow_timer"] = 2.0
	state.update_motion(1.0)
	var slow_balloon: Dictionary = state.balloons[0]
	_expect(is_equal_approx(Vector2(slow_balloon.get("vel", Vector2.ZERO)).x, 9.65), "motion owner should retain frame-scaled post-paddle drag")
	_expect(is_equal_approx(float(slow_balloon.get("paddle_bounce_cooldown", 0.0)), 1.0), "motion owner should decay paddle cooldown")
	_expect(state.ball_path_hits(Vector2.ZERO, Vector2(100.0, 0.0), Vector2(50.0, 5.0), 6.0), "swept collision should catch a path crossing between frames")
	_expect(not state.ball_path_hits(Vector2.ZERO, Vector2(100.0, 0.0), Vector2(50.0, 8.0), 6.0), "swept collision should reject a separated path")

	var bounce_balloon := _make_balloon("bounce", Vector2(90.0, 100.0), Vector2(0.0, 2.0), 10.0)
	var direction: float = state.bounce_from_paddle(bounce_balloon, Rect2(Vector2(100.0, 90.0), Vector2(40.0, 20.0)))
	_expect(direction > 0.0, "left-side paddle contact should request positive player knockback")
	_expect(float(bounce_balloon.get("paddle_bounce_cooldown", 0.0)) == Stage1BalloonRuntimeState.PADDLE_BOUNCE_COOLDOWN_FRAMES, "paddle bounce should arm the contact cooldown")
	_expect(float(bounce_balloon.get("paddle_bounce_slow_timer", 0.0)) == Stage1BalloonRuntimeState.PADDLE_BOUNCE_SLOW_FRAMES, "paddle bounce should arm the drag timer")


func _verify_ball_collision_feedback_before_deflection() -> void:
	var state := Stage1BalloonRuntimeState.new()
	state.balloons = [_make_balloon("ball", Vector2(100.0, 50.0), Vector2.ZERO, 12.0)]
	var coordinator := Stage1BalloonInteractionCoordinator.new(state)
	var scene := {"ball_pos": Vector2(200.0, 50.0), "ball_vel": Vector2(8.0, 0.0)}
	var host := FeedbackHost.new()
	host.observed_scene = scene
	host.original_ball_velocity = scene["ball_vel"]
	seed(51051)
	_expect(coordinator.resolve_ball_collision(scene, _collision_context(Vector2(0.0, 50.0)), {}, host), "swept ball collision should pop the first hit balloon")
	_expect(state.balloons.is_empty(), "ball collision should remove the popped balloon")
	_expect(host.pop_ids == ["ball"] and host.feedback_before_deflect, "pop feedback should run after removal and before ball deflection")
	_expect(Vector2(scene.get("ball_vel", Vector2.ZERO)) != Vector2(8.0, 0.0), "normal ball collision should deflect velocity")

	state.balloons = [_make_balloon("whip", Vector2(100.0, 50.0), Vector2.ZERO, 12.0)]
	var whip := WhipStub.new()
	whip.active = true
	var whip_scene := {"ball_pos": Vector2(200.0, 50.0), "ball_vel": Vector2(8.0, 0.0)}
	_expect(coordinator.resolve_ball_collision(whip_scene, _collision_context(Vector2(0.0, 50.0)), {"stage1_dalji_whip_skill_state": whip}, FeedbackHost.new()), "Whip-owned ball should still pop the balloon")
	_expect(Vector2(whip_scene.get("ball_vel", Vector2.ZERO)) == Vector2(8.0, 0.0), "Whip-owned ball should preserve its velocity")


func _verify_projectile_and_chaos_routes() -> void:
	var state := Stage1BalloonRuntimeState.new()
	var coordinator := Stage1BalloonInteractionCoordinator.new(state)
	state.balloons = [_make_balloon("bullet", Vector2(80.0, 40.0), Vector2.ZERO, 10.0, true)]
	var rejected: Dictionary = coordinator.resolve_commando_bullet_collision({"kind": "rocket", "weapon_id": "ak47", "pos": Vector2(80.0, 40.0)}, {"current_stage": 1}, {}, FeedbackHost.new())
	_expect(rejected.is_empty() and state.balloons.size() == 1, "non-bullet projectile kinds should not pop balloons")
	var result: Dictionary = coordinator.resolve_commando_bullet_collision({
		"kind": "bullet",
		"weapon_id": "ak47",
		"prev_pos": Vector2(0.0, 40.0),
		"pos": Vector2(160.0, 40.0),
		"radius": 3.0,
	}, {"current_stage": 1}, {}, FeedbackHost.new())
	_expect(bool(result.get("commando_firearm_balloon_popped", false)), "eligible Commando bullets should publish a pop result")
	_expect(bool(result.get("commando_firearm_balloon_special", false)), "projectile result should preserve the special flag")
	_expect(str(result.get("commando_firearm_balloon_weapon_id", "")) == "ak47", "projectile result should preserve weapon identity")

	state.balloons = [
		_make_balloon("left", Vector2(90.0, 50.0), Vector2.ZERO, 10.0),
		_make_balloon("right", Vector2(110.0, 50.0), Vector2.ZERO, 20.0),
	]
	var host := FeedbackHost.new()
	var absorbed: Array = coordinator.absorb_chaos_spear_objects(Vector2(100.0, 50.0), 30.0, {}, host)
	_expect(state.balloons.is_empty(), "Chaos absorption should remove every overlapping balloon in reverse-safe order")
	_expect(host.pop_ids == ["right", "left"], "Chaos absorption should preserve reverse traversal feedback order")
	_expect(absorbed.size() == 2, "Chaos absorption should publish one result per removed balloon")
	_expect(is_equal_approx(float((absorbed[0] as Dictionary).get("strength", 0.0)), 20.0 / 30.0 if 20.0 / 30.0 >= 0.75 else 0.75), "first absorbed result should correspond to the reverse-traversed right balloon")


func _verify_paddle_dash_knockback_and_immunity_order() -> void:
	var state := Stage1BalloonRuntimeState.new()
	var coordinator := Stage1BalloonInteractionCoordinator.new(state)
	var host := FeedbackHost.new()
	state.balloons = [_make_balloon("dash", Vector2(120.0, 110.0), Vector2.ZERO, 12.0)]
	var dash_context := _paddle_context()
	dash_context["dash_snapshot"] = {"active": true}
	coordinator.resolve_paddle_interactions(dash_context, {}, host)
	_expect(state.balloons.is_empty() and host.pop_ids == ["dash"], "dashing player contact should pop and remove the balloon before bounce policy")

	state.balloons = [_make_balloon("knockback", Vector2(110.0, 100.0), Vector2(0.0, 2.0), 12.0)]
	var movement := MovementStateStub.new()
	coordinator.resolve_paddle_interactions(_paddle_context(), {"movement_state": movement}, FeedbackHost.new())
	_expect(state.balloons.size() == 1, "ordinary paddle contact should bounce rather than remove the balloon")
	_expect(movement.calls == 1 and is_equal_approx(movement.frames, 18.0), "ordinary paddle contact should request the shipped knockback duration")

	state.balloons = [_make_balloon("immune", Vector2(110.0, 100.0), Vector2(0.0, 2.0), 12.0)]
	var immune_movement := MovementStateStub.new()
	var cleanse := CleanseStub.new()
	cleanse.immune = true
	var mythic := MythicImmunityStub.new()
	mythic.immune = true
	coordinator.resolve_paddle_interactions(_paddle_context(), {
		"movement_state": immune_movement,
		"smashser_cleanse_state": cleanse,
		"mythic_item_runtime": mythic,
	}, FeedbackHost.new())
	# Use the production key in a second probe; the misspelled dependency above
	# proves that only the canonical key can suppress Celestial Armor fallback.
	_expect(mythic.calls == 1, "missing canonical Cleanse dependency should fall through to Celestial Armor")
	_expect(immune_movement.calls == 0, "Celestial Armor immunity should suppress knockback")

	state.balloons = [_make_balloon("cleanse", Vector2(110.0, 100.0), Vector2(0.0, 2.0), 12.0)]
	var cleanse_movement := MovementStateStub.new()
	var clean_mythic := MythicImmunityStub.new()
	clean_mythic.immune = true
	coordinator.resolve_paddle_interactions(_paddle_context(), {
		"movement_state": cleanse_movement,
		"smasher_cleanse_state": cleanse,
		"mythic_item_runtime": clean_mythic,
	}, FeedbackHost.new())
	_expect(clean_mythic.calls == 0, "Cleanse immunity should short-circuit before Celestial Armor consumption")
	_expect(cleanse_movement.calls == 0, "Cleanse immunity should suppress knockback")


func _verify_facade_compatibility_and_source_ownership() -> void:
	var event := Stage1BalloonEvent.new()
	event.balloons = [_make_balloon("facade", Vector2(20.0, 20.0), Vector2(1.0, 0.0), 5.0)]
	event._update_balloons(1.0)
	_expect(event.balloons.size() == 1 and Vector2(event.balloons[0].get("pos", Vector2.ZERO)).x > 20.0, "legacy facade should advance retained motion state")
	event.reset()
	_expect(event.balloons.is_empty(), "facade reset should clear the retained balloon collection")

	var facade_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_event.gd")
	var state_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_runtime_state.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_interaction_coordinator.gd")
	_expect(facade_source.contains("Stage1BalloonRuntimeState") and facade_source.contains("Stage1BalloonInteractionCoordinator"), "balloon facade should preload both gameplay owners")
	_expect(not facade_source.contains("var balloons: Array[Dictionary] = []"), "balloon facade should not retain a mirrored collection")
	_expect(_method_source(facade_source, "resolve_ball_collision").contains("balloon_interaction_coordinator.resolve_ball_collision"), "ball collision facade should delegate")
	_expect(_method_source(facade_source, "resolve_commando_bullet_collision").contains("balloon_interaction_coordinator.resolve_commando_bullet_collision"), "projectile collision facade should delegate")
	_expect(_method_source(facade_source, "absorb_chaos_spear_objects").contains("balloon_interaction_coordinator.absorb_chaos_spear_objects"), "Chaos absorption facade should delegate")
	_expect(_method_source(facade_source, "_resolve_paddle_interactions").contains("balloon_interaction_coordinator.resolve_paddle_interactions"), "paddle interaction facade should delegate")
	_expect(_method_source(facade_source, "_update_balloons").contains("balloon_state.update_motion"), "motion facade should delegate")
	_expect(not facade_source.contains("func _is_player_status_immune("), "facade should not retain coordinator-owned immunity policy")
	_expect(state_source.contains("func update_motion") and state_source.contains("func deflect_ball_velocity"), "retained state should own motion and deflection math")
	_expect(coordinator_source.contains("StarpointBonusDropPolicy.get_mythic_item_runtime"), "interaction coordinator should own Celestial Armor lookup")


func _collision_context(previous_ball_pos: Vector2) -> Dictionary:
	return {
		"current_stage": 1,
		"ball_pos": previous_ball_pos,
		"ball_size": 10.0,
	}


func _paddle_context() -> Dictionary:
	return {
		"current_stage": 1,
		"player_pos": Vector2(100.0, 90.0),
		"player_paddle_size": Vector2(50.0, 20.0),
		"boss_pos": Vector2(500.0, 500.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"dash_snapshot": {"active": false},
	}


func _make_balloon(
	id: String,
	pos: Vector2,
	vel: Vector2,
	radius: float,
	is_special: bool = false
) -> Dictionary:
	return {
		"id": id,
		"pos": pos,
		"vel": vel,
		"radius": radius,
		"color": Color(0.8, 0.4, 1.0, 1.0),
		"bounce": 0.0,
		"lifetime": 0.0,
		"is_special": is_special,
		"sprite_index": 0,
		"rotation": 0.0,
		"rotation_speed": 1.8,
		"paddle_bounce_cooldown": 0.0,
		"paddle_bounce_slow_timer": 0.0,
	}


func _method_source(source: String, method_name: String) -> String:
	var marker := "func %s" % method_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next_method := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next_method < 0 else source.substr(start, next_method - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
