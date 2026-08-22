extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")
const WallBounceController := preload("res://scripts/ball/wall_bounce_controller.gd")

var _failures: Array[String] = []


class FakeActiveItemRuntime:
	extends RefCounted

	var paused := false

	func get_boss_ai_context() -> Dictionary:
		return {
			"active_item_boss_skill_cooldown_paused": paused,
			"active_item_tear_gas_cooldown_pause_active": paused,
		}


class FakeBallIntensity:
	extends RefCounted

	var last_hit_by := ""
	var contact_calls := 0
	var last_actor := ""
	var last_side := ""
	var last_tags: Dictionary = {}

	func get_last_hit_by() -> String:
		return last_hit_by

	func register_contact(actor_id: String, side: String, tags: Dictionary = {}) -> void:
		contact_calls += 1
		last_actor = actor_id
		last_side = side
		last_tags = tags.duplicate(true)
		last_hit_by = side


class FakeAuxiliaryBounceController:
	extends RefCounted

	var calls := 0
	var seen_rect := Rect2()
	var seen_context: Dictionary = {}

	func bounce_auxiliary_boss_paddle(
		paddle_rect: Rect2,
		context: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		calls += 1
		seen_rect = paddle_rect
		seen_context = context.duplicate(true)
		var ball_pos: Vector2 = context.get("ball_pos", Vector2.ZERO)
		var radius: float = float(context.get("ball_size", 20.0)) * 0.5
		ball_pos.y = paddle_rect.end.y + radius + 1.0
		return {
			"ball_pos": ball_pos,
			"ball_vel": Vector2(4.0, 12.0),
			"ball_impact_boost": 1.1,
			"ball_boost_decay_rate": 0.975,
			"ball_min_boost": 0.70,
			"ball_serve_origin": "",
			"vertical_bounce_count": 1,
			"ball_spin_strength": 0.0,
			"ball_spin_direction": 0,
			"drive_speed_increase": 0.0,
			# These stale/boss-only fields must never be merged by the Stage 7 owner.
			"special_gauge": -999.0,
			"player_speed": -999.0,
			"boss_vel": -999.0,
		}


class FakeNormalBossBounceController:
	extends RefCounted

	var calls := 0

	func bounce(
		_paddle_x: float,
		_paddle_w: float,
		_is_player: bool,
		context: Dictionary,
		_deps: Dictionary,
		_callbacks: Dictionary = {}
	) -> Dictionary:
		calls += 1
		return {
			"ball_pos": context.get("ball_pos", Vector2.ZERO),
			"ball_vel": Vector2(0.0, 12.0),
			"boss_collision_cooldown": 10.0,
			"normal_boss_bounce_committed": true,
		}


class FakePostHitStep:
	extends RefCounted

	var calls := 0

	func apply() -> Dictionary:
		calls += 1
		return {}


func _init() -> void:
	_verify_normal_and_awakened_cast_contract()
	_verify_paid_cast_cancels_if_external_drain_breaks_commit()
	_verify_clone_trigger_roll_and_cast_arbitration()
	_verify_clone_motion_is_fps_invariant_and_wall_bounded()
	_verify_pause_freezes_cast_and_cooldown_but_not_live_clone()
	_verify_composite_intangibility_window()
	_verify_real_cast_intangibility_reaches_pre_detector()
	_verify_player_upward_swept_hit_reflects_only_one_clone()
	_verify_swept_hit_uses_first_contact_point()
	_verify_direction_and_owner_guards()
	_verify_auxiliary_bounce_fallback()
	_verify_shared_auxiliary_bounce_skips_real_boss_post_hit()
	_verify_auxiliary_bounce_consumes_boosts_and_progresses_rally()
	_verify_clone_entity_cap_is_hard()
	_verify_natural_expiry_and_hit_dying_lifetimes()
	_verify_hud_pause_states_match_runtime()
	_verify_hud_render_payload_and_cleanup()

	if _failures.is_empty():
		print("stage7_akamu_slice3_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_normal_and_awakened_cast_contract() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_seed_rng(73001)
	state.debug_set_gauge(100.0)
	var context: Dictionary = _base_context()
	_expect(state.debug_start_clone_cast(context, false, true), "paid shadow clone cast should start with 100 gauge")
	_expect(state.is_boss_ball_intangible(), "boss should become ball-intangible immediately when clone cast starts")
	_expect(bool(state.get_boss_ai_context().get("stage7_akamu_scripted_motion_active", false)), "clone cast should authoritatively hold the boss")
	_expect_vector(
		state.get_boss_ai_context().get("stage7_akamu_scripted_boss_pos", Vector2.ZERO),
		context.get("boss_pos", Vector2.ZERO),
		"clone cast should hold the captured boss position"
	)
	_advance(state, 0.49, context)
	var snapshot: Dictionary = state.debug_get_clone_snapshot()
	_expect(bool(snapshot.get("casting", false)), "clone should not release before 500ms")
	_expect_close(state.debug_get_gauge(), 100.0, "clone cost should remain reserved until cast completion")
	_expect(int(snapshot.get("live_count", -1)) == 0, "clone entities should not exist before cast completion")
	state.update(0.01, context)
	snapshot = state.debug_get_clone_snapshot()
	_expect(not bool(snapshot.get("casting", true)), "clone cast should complete at 500ms")
	_expect_close(state.debug_get_gauge(), 0.0, "paid clone cast should deduct 100 exactly once at completion")
	_expect(int(snapshot.get("live_count", 0)) == 2, "normal clone cast should spawn two clones")
	_expect_close(float(snapshot.get("cooldown_remaining_sec", 0.0)), 8.0, "clone spawn should arm the real eight-second cooldown")
	_expect(state.is_boss_ball_intangible(), "post-cast 600ms intangibility buffer should start at completion")
	var clones: Array = state.get_actor_draw_context().get("stage7_akamu_clones", [])
	_expect(clones.size() == 2, "actor payload should publish two normal clones")
	for clone_value in clones:
		var clone: Dictionary = clone_value
		_expect_close((_vector(clone.get("center", Vector2.ZERO))).y, 45.0, "live Python behavior keeps clone Y at the cast center")
	state.update(0.1, context)
	clones = state.get_actor_draw_context().get("stage7_akamu_clones", [])
	_expect(absf((_vector((clones[0] as Dictionary).get("center", Vector2.ZERO))).x - 380.0) > 1.0, "emerging clones should spread horizontally from the cast center")

	var awakened_state: Object = Stage7AkamuState.new()
	awakened_state.debug_seed_rng(73002)
	awakened_state.debug_set_awakened(true)
	awakened_state.debug_set_gauge(100.0)
	_expect(awakened_state.debug_start_clone_cast(context, false, true), "awakened paid clone cast should start")
	_advance(awakened_state, 0.5, context)
	_expect(int(awakened_state.debug_get_clone_snapshot().get("live_count", 0)) == 4, "awakened clone cast should spawn four clones")
	_advance(awakened_state, 0.5, context)
	_expect_close(awakened_state.debug_get_gauge(), 0.0, "clone cost must not repeat after the completion frame")


func _verify_paid_cast_cancels_if_external_drain_breaks_commit() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(100.0)
	state.debug_set_clone_cooldown_remaining(0.0)
	var context: Dictionary = _base_context()
	_expect(state.debug_start_clone_cast(context), "drain regression precondition should start a paid cast")
	state.drain_boss_special_gauge(60.0)
	_advance(state, 0.5, context)
	var snapshot: Dictionary = state.debug_get_clone_snapshot()
	_expect(not bool(snapshot.get("casting", true)), "underfunded cast should cancel at commit")
	_expect(int(snapshot.get("live_count", -1)) == 0, "underfunded cast must not reproduce the legacy free-clone bug")
	_expect_close(state.debug_get_gauge(), 40.0, "cancelled clone cast should not apply a second partial deduction")
	_expect_close(float(snapshot.get("cooldown_remaining_sec", -1.0)), 0.0, "cancelled cast should not arm cooldown")
	_expect(not state.is_boss_ball_intangible(), "cancelled cast should clear its intangibility contributor")


func _verify_clone_trigger_roll_and_cast_arbitration() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_seed_rng(73003)
	state.debug_set_gauge(500.0)
	state.debug_set_clone_cooldown_remaining(0.0)
	var context: Dictionary = _base_context()
	var scene := {"ball_pos": Vector2(380.0, 80.0), "ball_vel": Vector2(0.0, 12.0)}
	for _attempt in range(128):
		state.handle_boss_paddle_hit(scene, context)
		if bool(state.debug_get_clone_snapshot().get("casting", false)):
			break
	_expect(bool(state.debug_get_clone_snapshot().get("casting", false)), "normal boss-hit hook should expose its 25% clone trigger")
	_expect_close(float(state.debug_get_clone_snapshot().get("trigger_chance", 0.0)), 0.25, "clone trigger chance should remain 25%")

	var shuriken_state: Object = Stage7AkamuState.new()
	shuriken_state.debug_set_gauge(200.0)
	shuriken_state.debug_set_shuriken_cooldown_remaining(0.0, 8.0)
	shuriken_state.update(1.0 / 60.0, context)
	_expect(bool(shuriken_state.debug_get_shuriken_snapshot().get("casting", false)), "precondition should start shuriken cast")
	_expect(not shuriken_state.debug_start_clone_cast(context, false, true), "clone cast should not overlap the shuriken scripted-position owner")

	var live_clone_state: Object = Stage7AkamuState.new()
	live_clone_state.debug_set_gauge(200.0)
	live_clone_state.debug_spawn_shadow_clones(Vector2(380.0, 160.0))
	live_clone_state.debug_set_shuriken_cooldown_remaining(0.0, 8.0)
	live_clone_state.update(0.1, context)
	_expect(not bool(live_clone_state.debug_get_shuriken_snapshot().get("casting", false)), "shuriken scheduler should wait until live clones leave")


func _verify_clone_motion_is_fps_invariant_and_wall_bounded() -> void:
	var endpoint_sets: Array = []
	for fps in [30.0, 60.0, 120.0]:
		var state: Object = Stage7AkamuState.new()
		state.debug_seed_rng(73004)
		state.debug_spawn_shadow_clones(Vector2(380.0, 200.0), true)
		var context: Dictionary = _base_context()
		for _frame in range(int(round(4.0 * fps))):
			state.update(1.0 / fps, context)
		var endpoints: Array = []
		for clone_value in state.get_actor_draw_context().get("stage7_akamu_clones", []):
			var center: Vector2 = _vector((clone_value as Dictionary).get("center", Vector2.ZERO))
			endpoints.append(center)
			_expect(center.x >= 65.0 and center.x <= 695.0, "clone center should remain inside the 10px wall margin at %d FPS" % int(fps))
		endpoint_sets.append(endpoints)
	for clone_index in range(4):
		_expect_vector(endpoint_sets[0][clone_index], endpoint_sets[1][clone_index], "30 and 60 FPS clone endpoints should match", 0.01)
		_expect_vector(endpoint_sets[1][clone_index], endpoint_sets[2][clone_index], "60 and 120 FPS clone endpoints should match", 0.01)


func _verify_pause_freezes_cast_and_cooldown_but_not_live_clone() -> void:
	var state: Object = Stage7AkamuState.new()
	var runtime := FakeActiveItemRuntime.new()
	runtime.paused = true
	var context: Dictionary = _base_context()
	state.debug_set_gauge(100.0)
	_expect(state.debug_start_clone_cast(context, false, true), "pause regression precondition should start clone cast")
	state.update(0.1, context, {"active_item_runtime": runtime})
	_expect_close(float(state.debug_get_clone_snapshot().get("cast_elapsed_sec", -1.0)), 0.0, "boss-skill pause should freeze the 500ms clone cast")
	_expect(state.is_boss_ball_intangible(), "paused clone cast should retain its intangibility")
	runtime.paused = false
	_advance(state, 0.5, context, {"active_item_runtime": runtime})
	var before: Dictionary = (state.get_actor_draw_context().get("stage7_akamu_clones", []) as Array)[0]
	var before_center: Vector2 = _vector(before.get("center", Vector2.ZERO))
	var cooldown_before: float = float(state.debug_get_clone_snapshot().get("cooldown_remaining_sec", 0.0))
	runtime.paused = true
	state.update(0.1, context, {"active_item_runtime": runtime})
	var after: Dictionary = (state.get_actor_draw_context().get("stage7_akamu_clones", []) as Array)[0]
	_expect(_vector(after.get("center", Vector2.ZERO)).distance_to(before_center) > 0.1, "already-spawned clone should keep emerging/moving during boss-skill pause")
	_expect_close(float(state.debug_get_clone_snapshot().get("cooldown_remaining_sec", 0.0)), cooldown_before, "boss-skill pause should freeze clone cooldown")
	_expect(float(state.debug_get_clone_snapshot().get("invuln_buffer_remaining_sec", 1.0)) < 0.6, "post-cast intangibility buffer should keep expiring during boss-skill pause")


func _verify_composite_intangibility_window() -> void:
	var state: Object = Stage7AkamuState.new()
	var context: Dictionary = _base_context()
	state.debug_set_gauge(100.0)
	state.set_boss_ball_intangible_source("cloud", true)
	_expect(state.debug_start_clone_cast(context, false, true), "composite intangibility precondition should start clone cast")
	_advance(state, 0.5, context)
	_advance(state, 0.6, context)
	_expect(state.is_boss_ball_intangible(), "external cloud contributor should keep boss intangible after shadow buffer ends")
	state.set_boss_ball_intangible_source("cloud", false)
	_expect(not state.is_boss_ball_intangible(), "boss should become tangible only after every contributor clears")

	var cancel_state: Object = Stage7AkamuState.new()
	cancel_state.debug_set_gauge(100.0)
	cancel_state.set_boss_ball_intangible_source("escape", true)
	_expect(cancel_state.debug_start_clone_cast(context, false, true), "external-source cancel precondition should start clone cast")
	cancel_state.drain_boss_special_gauge(100.0)
	_advance(cancel_state, 0.5, context)
	_expect(cancel_state.is_boss_ball_intangible(), "cancelled shadow cast must preserve an independent escape contributor")
	cancel_state.set_boss_ball_intangible_source("escape", false)
	_expect(not cancel_state.is_boss_ball_intangible(), "clearing the final external contributor should restore tangibility")

	var cleanup_state: Object = Stage7AkamuState.new()
	cleanup_state.set_boss_ball_intangible_source("cloud", true)
	cleanup_state.set_boss_ball_intangible_source("escape", true)
	cleanup_state.clear_round_transients()
	_expect(not cleanup_state.is_boss_ball_intangible(), "round cleanup should clear every composite intangibility contributor")


func _verify_real_cast_intangibility_reaches_pre_detector() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(100.0)
	var state_context: Dictionary = _base_context()
	_expect(state.debug_start_clone_cast(state_context, false, true), "pre-detector integration precondition should start clone cast")
	var processor: Object = BallMotionEventProcessor.new()
	var bounce := FakeNormalBossBounceController.new()
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"paddle_bounce_controller": bounce,
			"stage7_akamu_state": state,
		},
		{}
	)
	_expect(bounce.calls == 0, "real clone-cast intangibility should suppress shared boss-paddle detection")

	_advance(state, 0.5, state_context)
	_advance(state, 0.3, state_context)
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"paddle_bounce_controller": bounce,
			"stage7_akamu_state": state,
		},
		{}
	)
	_expect(bounce.calls == 0, "real 600ms post-cast buffer should remain visible to the pre-detector gate")
	_advance(state, 0.31, state_context)
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"paddle_bounce_controller": bounce,
			"stage7_akamu_state": state,
		},
		{}
	)
	_expect(bounce.calls == 1, "normal boss-paddle detection should resume after every intangibility contributor expires")


func _verify_player_upward_swept_hit_reflects_only_one_clone() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var bounce := FakeAuxiliaryBounceController.new()
	var intensity := FakeBallIntensity.new()
	var wall_controller: Object = WallBounceController.new()
	wall_controller.wall_bounce_state.resolve(Vector2(-20.0, 0.2), 1.0, "left")
	wall_controller.wall_bounce_state.resolve(Vector2(20.0, 0.2), 1.0, "right")
	wall_controller.wall_bounce_state.resolve(Vector2(-20.0, 0.2), 1.0, "left")
	_expect(int(wall_controller.wall_bounce_state.get("wall_bounce_count")) == 2, "wall-stall reset precondition should accumulate two alternating wall hits")
	intensity.last_hit_by = "player"
	var scene := {
		"previous_ball_pos": Vector2(380.0, 310.0),
		"ball_pos": Vector2(380.0, 130.0),
		"ball_vel": Vector2(0.0, -12.0),
		"special_gauge": 77.0,
		"player_speed": 5.0,
		"boss_vel": 3.0,
	}
	var context: Dictionary = _base_context()
	context["last_hit_by"] = "player"
	_expect(state.resolve_ball_collision(scene, context, {
		"paddle_bounce_controller": bounce,
		"ball_intensity": intensity,
		"wall_bounce_controller": wall_controller,
	}), "upward player-owned swept segment should hit a clone")
	_expect(bounce.calls == 1, "one clone collision should call the auxiliary bounce exactly once")
	_expect(scene.get("ball_vel", Vector2.ZERO).y > 0.0, "clone should reflect the ball downward")
	_expect_close(float(scene.get("special_gauge", 0.0)), 77.0, "auxiliary bounce must not merge stale player gauge")
	_expect_close(float(scene.get("player_speed", 0.0)), 5.0, "auxiliary bounce must not merge stale player speed")
	_expect_close(float(scene.get("boss_vel", 0.0)), 3.0, "auxiliary bounce must not knock back the real boss")
	var snapshot: Dictionary = state.debug_get_clone_snapshot()
	_expect(int(snapshot.get("dying_count", 0)) == 1, "one overlapping clone should enter dying phase")
	_expect(int(snapshot.get("live_count", 0)) == 1, "overlap guard should leave the second clone alive")
	_expect(intensity.contact_calls == 1 and intensity.last_side == "boss", "clone reflection should register boss ownership once")
	_expect(bool(intensity.last_tags.get("auxiliary_paddle", false)), "clone contact should be tagged as an auxiliary paddle")
	_expect(int(wall_controller.wall_bounce_state.get("wall_bounce_count")) == 0, "auxiliary clone paddle contact should reset the shared alternating-wall stall counter")
	_expect(not state.resolve_ball_collision(scene, context, {
		"paddle_bounce_controller": bounce,
		"ball_intensity": intensity,
	}), "downward result from the first clone must not double-reflect on the overlap")
	_expect(bounce.calls == 1, "overlapping clones must not bounce twice in one frame")


func _verify_swept_hit_uses_first_contact_point() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var bounce := FakeAuxiliaryBounceController.new()
	var context: Dictionary = _base_context()
	context["last_hit_by"] = "player"
	var scene := {
		"previous_ball_pos": Vector2(250.0, 300.0),
		"ball_pos": Vector2(520.0, 100.0),
		"ball_vel": Vector2(13.5, -10.0),
	}
	_expect(state.resolve_ball_collision(scene, context, {
		"paddle_bounce_controller": bounce,
	}), "diagonal swept segment should intersect the expanded clone rect")
	var seen_contact: Vector2 = _vector(bounce.seen_context.get("ball_pos", Vector2.ZERO))
	_expect_vector(seen_contact, Vector2(315.0, 251.85185), "auxiliary bounce should calculate its angle from first contact", 0.01)
	_expect(seen_contact.distance_to(Vector2(520.0, 100.0)) > 100.0, "swept collision must not reuse the frame endpoint as its hit point")
	_expect_close((_vector(scene.get("ball_pos", Vector2.ZERO))).x, seen_contact.x, "post-bounce separation should preserve contact-point X")

	var inside_state: Object = Stage7AkamuState.new()
	inside_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var inside_bounce := FakeAuxiliaryBounceController.new()
	var inside_scene := {
		"previous_ball_pos": Vector2(250.0, 300.0),
		"ball_pos": Vector2(380.0, 200.0),
		"ball_vel": Vector2(13.0, -10.0),
	}
	_expect(inside_state.resolve_ball_collision(inside_scene, context, {
		"paddle_bounce_controller": inside_bounce,
	}), "outside-to-inside swept endpoint should still collide")
	var inside_contact: Vector2 = _vector(inside_bounce.seen_context.get("ball_pos", Vector2.ZERO))
	_expect_vector(inside_contact, Vector2(315.0, 250.0), "outside-to-inside sweep should use the boundary entry point before its interior endpoint", 0.01)
	_expect(inside_contact.distance_to(Vector2(380.0, 200.0)) > 50.0, "interior endpoint must not replace the first boundary contact")


func _verify_direction_and_owner_guards() -> void:
	var downward_state: Object = Stage7AkamuState.new()
	downward_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var downward_scene := _clone_collision_scene(Vector2(0.0, 12.0))
	var empty_context: Dictionary = _base_context()
	empty_context["last_hit_by"] = ""
	_expect(not downward_state.resolve_ball_collision(downward_scene, empty_context, {
		"paddle_bounce_controller": FakeAuxiliaryBounceController.new(),
	}), "unowned downward boss serve/return should pass through clones")
	_expect(int(downward_state.debug_get_clone_snapshot().get("live_count", 0)) == 2, "direction guard should preserve clones")

	var boss_owned_state: Object = Stage7AkamuState.new()
	boss_owned_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var boss_context: Dictionary = _base_context()
	boss_context["last_hit_by"] = "boss"
	_expect(not boss_owned_state.resolve_ball_collision(_clone_collision_scene(Vector2(0.0, -12.0)), boss_context, {
		"paddle_bounce_controller": FakeAuxiliaryBounceController.new(),
	}), "boss-owned upward ball should not be re-reflected by its own clone")

	var empty_upward_state: Object = Stage7AkamuState.new()
	empty_upward_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	_expect(empty_upward_state.resolve_ball_collision(_clone_collision_scene(Vector2(0.0, -12.0)), empty_context, {
		"paddle_bounce_controller": FakeAuxiliaryBounceController.new(),
	}), "empty-owner upward threat should still be defended")

	var waiting_state: Object = Stage7AkamuState.new()
	waiting_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var waiting_context: Dictionary = _base_context()
	waiting_context["waiting_for_serve"] = true
	_expect(not waiting_state.resolve_ball_collision(_clone_collision_scene(Vector2(0.0, -12.0)), waiting_context, {
		"paddle_bounce_controller": FakeAuxiliaryBounceController.new(),
	}), "serve-wait boundary should disable clone collision")


func _verify_auxiliary_bounce_fallback() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var context: Dictionary = _base_context()
	context["last_hit_by"] = "player"
	var scene := _clone_collision_scene(Vector2(1.0, -12.0))
	_expect(state.resolve_ball_collision(scene, context), "missing shared helper should use the safe legacy fallback")
	_expect(scene.get("ball_vel", Vector2.ZERO).y > 0.0, "fallback reflection should guarantee a downward velocity")
	_expect(int(state.debug_get_clone_snapshot().get("dying_count", 0)) == 1, "fallback hit should still consume exactly one clone")


func _verify_shared_auxiliary_bounce_skips_real_boss_post_hit() -> void:
	var controller: Object = PaddleBounceController.new()
	var forbidden_post := FakePostHitStep.new()
	controller.set("post_hit_step", forbidden_post)
	var context: Dictionary = _base_context()
	context["ball_pos"] = Vector2(380.0, 180.0)
	context["ball_vel"] = Vector2(3.0, -12.0)
	context["special_gauge"] = 88.0
	context["player_speed"] = 5.0
	context["boss_vel"] = 4.0
	var clone_rect := Rect2(Vector2(325.0, 152.0), Vector2(110.0, 96.0))
	var result: Dictionary = controller.bounce_auxiliary_boss_paddle(clone_rect, context, {
		"paddle_bounce_state": PaddleBounceState.new(),
	})
	_expect(not result.is_empty(), "shared auxiliary bounce should resolve with the normal velocity rules")
	_expect(result.get("ball_vel", Vector2.ZERO).y > 0.0, "shared auxiliary bounce should launch toward the player")
	_expect(forbidden_post.calls == 0, "auxiliary bounce must not enter actual-boss post-hit processing")
	_expect(not result.has("special_gauge") and not result.has("player_speed") and not result.has("boss_vel"), "auxiliary result should contain only safe ball-physics fields")
	_expect(float((result.get("ball_pos", Vector2.ZERO) as Vector2).y) >= clone_rect.end.y + 11.0, "auxiliary bounce should separate the ball below the clone")


func _verify_auxiliary_bounce_consumes_boosts_and_progresses_rally() -> void:
	var controller: Object = PaddleBounceController.new()
	var context: Dictionary = _base_context()
	context.merge({
		"ball_pos": Vector2(380.0, 180.0),
		"ball_vel": Vector2(0.0, -27.0),
		"commando_suicide_drone_ball_boost_active": true,
		"commando_suicide_drone_ball_restore_speed": 9.0,
		"commando_suicide_drone_ball_boosted_speed": 27.0,
		"commando_suicide_drone_speed_limit_disabled": true,
		"speed_limit_disabled": true,
		"rally_speed_cap_bonus": 1.0,
		"rally_speed_cap_increase_per_hit": 0.5,
		"rally_speed_cap_bonus_max": 10.0,
		"max_ball_speed": 20.0,
		"impact_boost_max_ball_speed": 26.0,
		"fire_weather_speed_cap_active": true,
		"fire_weather_max_ball_speed": 35.0,
	}, true)
	var clone_rect := Rect2(Vector2(325.0, 152.0), Vector2(110.0, 96.0))
	var result: Dictionary = controller.bounce_auxiliary_boss_paddle(clone_rect, context, {
		"paddle_bounce_state": PaddleBounceState.new(),
	})
	_expect_close((_vector(result.get("ball_vel", Vector2.ZERO))).length(), 9.0, "auxiliary boss bounce should consume and restore the suicide-drone ball speed")
	_expect(not bool(result.get("commando_suicide_drone_ball_boost_active", true)), "auxiliary bounce should clear the suicide-drone boost owner flag")
	_expect(bool(result.get("commando_suicide_drone_ball_boost_consumed", false)), "auxiliary bounce should emit the suicide-drone consumption edge")
	_expect(not bool(result.get("speed_limit_disabled", true)), "auxiliary bounce should restore the shared speed-limit gate")
	_expect_close(float(result.get("rally_speed_cap_bonus", 0.0)), 1.5, "auxiliary bounce should advance the shared rally cap bonus")
	_expect_close(float(result.get("max_ball_speed", 0.0)), 20.5, "auxiliary bounce should raise the normal speed cap")
	_expect_close(float(result.get("impact_boost_max_ball_speed", 0.0)), 26.5, "auxiliary bounce should raise the impact speed cap")
	_expect_close(float(result.get("fire_weather_max_ball_speed", 0.0)), 35.5, "auxiliary bounce should raise the active fire-weather cap")

	var state: Object = Stage7AkamuState.new()
	state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var scene := _clone_collision_scene(Vector2(0.0, -27.0))
	_expect(state.resolve_ball_collision(scene, context, {
		"paddle_bounce_controller": controller,
		"paddle_bounce_state": PaddleBounceState.new(),
	}), "real auxiliary controller should resolve through the Stage 7 clone owner")
	_expect(not bool(scene.get("commando_suicide_drone_ball_boost_active", true)), "Stage 7 safe merge should publish the cleared suicide-drone flag")
	_expect(bool(scene.get("commando_suicide_drone_ball_boost_consumed", false)), "Stage 7 safe merge should preserve the boost consumption edge")
	_expect_close(float(scene.get("rally_speed_cap_bonus", 0.0)), 1.5, "Stage 7 safe merge should preserve rally progression")
	_expect_close(float(scene.get("max_ball_speed", 0.0)), 20.5, "Stage 7 safe merge should preserve raised speed caps")


func _verify_clone_entity_cap_is_hard() -> void:
	var state: Object = Stage7AkamuState.new()
	for _spawn_index in range(5):
		state.debug_spawn_shadow_clones(Vector2(380.0, 200.0), true)
	var snapshot: Dictionary = state.debug_get_clone_snapshot()
	_expect(int(snapshot.get("entity_count", 0)) == 8, "repeated debug/free spawns must stop at the hard eight-clone cap")
	_expect(int(snapshot.get("live_count", 0)) == 8, "hard cap should not silently replace still-live clones")


func _verify_natural_expiry_and_hit_dying_lifetimes() -> void:
	var natural_state: Object = Stage7AkamuState.new()
	natural_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	_advance(natural_state, 8.6, _base_context())
	var fading_clone: Dictionary = (natural_state.get_actor_draw_context().get("stage7_akamu_clones", []) as Array)[0]
	var fading_alpha: float = float(fading_clone.get("alpha", 0.0))
	_expect(fading_alpha > 0.0 and fading_alpha < 0.78, "natural clone alpha should visibly fade during its final 1.5 seconds")
	_advance(natural_state, 1.5, _base_context())
	_expect(int(natural_state.debug_get_clone_snapshot().get("entity_count", -1)) == 0, "natural 10-second expiry should remove clones without entering dying")

	var hit_state: Object = Stage7AkamuState.new()
	hit_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var context: Dictionary = _base_context()
	context["last_hit_by"] = "player"
	_expect(hit_state.resolve_ball_collision(_clone_collision_scene(Vector2(0.0, -12.0)), context, {
		"paddle_bounce_controller": FakeAuxiliaryBounceController.new(),
	}), "hit-dying lifetime precondition should destroy one clone")
	_advance(hit_state, 0.6, context)
	_expect(int(hit_state.debug_get_clone_snapshot().get("dying_count", 0)) == 1, "hit clone should remain visible during its 700ms dying phase")
	var dying_clone: Dictionary = (hit_state.get_actor_draw_context().get("stage7_akamu_clones", []) as Array)[0]
	_expect_close(float(dying_clone.get("death_progress", 0.0)), 0.6 / 0.7, "dying payload should expose normalized dissolve progress", 0.001)
	_expect(float(dying_clone.get("alpha", 1.0)) < 0.20, "dying clone alpha should visibly collapse before removal")
	_advance(hit_state, 0.11, context)
	_expect(int(hit_state.debug_get_clone_snapshot().get("dying_count", 0)) == 0, "hit clone should leave after 700ms")


func _verify_hud_pause_states_match_runtime() -> void:
	var runtime := FakeActiveItemRuntime.new()
	runtime.paused = true
	var context: Dictionary = _base_context()

	var clone_cast_state: Object = Stage7AkamuState.new()
	clone_cast_state.debug_set_gauge(100.0)
	_expect(clone_cast_state.debug_start_clone_cast(context, false, true), "clone HUD pause precondition should start a cast")
	clone_cast_state.update(0.1, context, {"active_item_runtime": runtime})
	var clone_card: Dictionary = _find_skill(clone_cast_state.get_hud_context().get("stage7_boss_skill_hud_skills", []), "stage7_clone")
	_expect(str(clone_card.get("status", "")) == "paused", "paused clone cast should render as paused")
	_expect(not bool(clone_card.get("ready", true)) and not bool(clone_card.get("active", true)), "paused clone cast must not expose ready or active card flags")

	var live_clone_state: Object = Stage7AkamuState.new()
	live_clone_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	live_clone_state.update(0.1, context, {"active_item_runtime": runtime})
	clone_card = _find_skill(live_clone_state.get_hud_context().get("stage7_boss_skill_hud_skills", []), "stage7_clone")
	_expect(str(clone_card.get("status", "")) == "active" and bool(clone_card.get("active", false)), "live clones should stay visibly active because their motion/lifetime continue during pause")

	var shuriken_state: Object = Stage7AkamuState.new()
	shuriken_state.debug_set_gauge(200.0)
	shuriken_state.debug_set_shuriken_cooldown_remaining(0.0, 8.0)
	shuriken_state.update(0.1, context, {"active_item_runtime": runtime})
	var shuriken_card: Dictionary = _find_skill(shuriken_state.get_hud_context().get("stage7_boss_skill_hud_skills", []), "stage7_shuriken")
	_expect(str(shuriken_card.get("status", "")) == "paused", "paused shuriken scheduler should not appear ready")
	_expect(not bool(shuriken_card.get("ready", true)) and not bool(shuriken_card.get("active", true)), "paused shuriken card should expose neither ready nor active")

	shuriken_state.debug_spawn_shuriken(Vector2(200.0, 150.0), Vector2(300.0, 650.0))
	shuriken_state.update(0.01, context, {"active_item_runtime": runtime})
	shuriken_card = _find_skill(shuriken_state.get_hud_context().get("stage7_boss_skill_hud_skills", []), "stage7_shuriken")
	_expect(str(shuriken_card.get("status", "")) == "active" and bool(shuriken_card.get("active", false)), "in-flight shuriken should stay visibly active because projectile motion continues during pause")


func _verify_hud_render_payload_and_cleanup() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(200.0)
	state.debug_set_awakened(true)
	state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var clone_card: Dictionary = _find_skill(state.get_hud_context().get("stage7_boss_skill_hud_skills", []), "stage7_clone")
	_expect(bool(clone_card.get("implemented", false)), "clone HUD card should leave placeholder mode")
	_expect(int(clone_card.get("active_count", 0)) == 2, "clone HUD should expose the live clone count")
	_expect_close(float(clone_card.get("cooldown_total", 0.0)), 8.0, "clone HUD should expose the real cooldown")
	_expect(str(clone_card.get("status", "")) == "active", "clone HUD should report active state while clones live")
	var actor_context: Dictionary = state.get_actor_draw_context()
	_expect(actor_context.has("stage7_akamu_clone_cast_progress"), "actor payload should expose clone cast progress")
	_expect(actor_context.get("stage7_akamu_clones", []).size() == 2, "playfield payload should publish bounded clone entities")

	var clone_cooldown_before: float = float(state.debug_get_clone_snapshot().get("cooldown_remaining_sec", 0.0))
	_expect(clone_cooldown_before > 0.0, "spawning clones should arm the clone cooldown for the persistence check")
	state.clear_round_transients()
	var snapshot: Dictionary = state.debug_get_clone_snapshot()
	_expect(int(snapshot.get("entity_count", -1)) == 0, "round cleanup should clear live and dying clone entities")
	_expect(not bool(snapshot.get("casting", true)), "round cleanup should cancel clone casting")
	# 원본 파리티(2026-07-12): 스킬 쿨타임은 라운드 경계를 넘어 유지된다.
	_expect_close(
		float(snapshot.get("cooldown_remaining_sec", -1.0)),
		clone_cooldown_before,
		"skill cooldown must PERSIST across the round boundary (not reset)"
	)
	_expect(not state.is_boss_ball_intangible(), "round cleanup should clear every boss-intangibility contributor")
	_expect(not bool(state.get_boss_ai_context().get("stage7_akamu_scripted_motion_active", true)), "round cleanup should release scripted boss motion")
	_expect_close(state.debug_get_gauge(), 200.0, "transient cleanup should preserve Stage 7 gauge")
	_expect(state.debug_is_awakened(), "transient cleanup should preserve awakening")
	state.reset_for_result()
	_expect_close(state.debug_get_gauge(), 0.0, "result reset should clear Stage 7 gauge")
	_expect(not state.debug_is_awakened(), "result reset should clear awakening")
	_expect_close(
		float(state.debug_get_clone_snapshot().get("cooldown_remaining_sec", -1.0)),
		8.0,
		"full result reset should restore the explicit fresh-match initial cooldown"
	)

	var actor_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_boss_actor_renderer.gd")
	_expect(actor_source.find("stage7_akamu_boss_ball_intangible") >= 0, "boss renderer should consume composite intangibility")
	_expect(actor_source.find("stage7_akamu_clone_casting") >= 0, "boss renderer should consume the clone-cast pose")
	var hud_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd")
	_expect(hud_source.find("0.5초 시전") >= 0 and hud_source.find("8초") >= 0, "clone tooltip should describe implemented timing instead of placeholder copy")
	_expect(hud_source.find("var paused :=") >= 0 and hud_source.find("not paused and") >= 0, "HUD renderer should prevent paused casts from overriding the paused border with active styling")
	var playfield_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd")
	_expect(playfield_source.find("CLONE_VISUAL_CENTER_Y_OFFSET := 12.0") >= 0, "clone placeholder should share the boss renderer's 12px visual center offset")


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"selected_character_type": "smasher",
		"ball_active": true,
		"waiting_for_serve": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_size": 20.0,
		"max_bounce_angle": 60.0,
		"min_ball_speed": 3.0,
		"max_ball_speed": 20.0,
		"special_gauge": 100.0,
		"player_speed": 5.0,
		"boss_vel": 0.0,
		"last_hit_by": "player",
	}


func _clone_collision_scene(velocity: Vector2) -> Dictionary:
	return {
		"previous_ball_pos": Vector2(380.0, 310.0),
		"ball_pos": Vector2(380.0, 130.0),
		"ball_vel": velocity,
	}


func _boss_collision_scene() -> Dictionary:
	return {
		"ball_pos": Vector2(380.0, 80.0),
		"ball_vel": Vector2(0.0, -20.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}


func _boss_collision_context() -> Dictionary:
	return {
		"current_stage": 7,
		"selected_character_type": "smasher",
		"ball_size": 20.0,
		"width": 760.0,
		"height": 750.0,
		"max_step_distance": 12.0,
		"hitbox_padding": 5.0,
		"player_pos": Vector2(300.0, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}


func _advance(
	state: Object,
	duration_sec: float,
	context: Dictionary,
	deps: Dictionary = {}
) -> void:
	var remaining: float = duration_sec
	while remaining > 0.000001:
		var step: float = minf(0.1, remaining)
		state.update(step, context, deps)
		remaining -= step


func _find_skill(value: Variant, skill_id: String) -> Dictionary:
	if not (value is Array):
		return {}
	for entry_value in value:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == skill_id:
			return entry_value
	return {}


func _vector(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _expect_vector(
	actual_value: Variant,
	expected_value: Variant,
	message: String,
	tolerance: float = 0.0001
) -> void:
	var actual: Vector2 = _vector(actual_value)
	var expected: Vector2 = _vector(expected_value)
	_expect(actual.distance_to(expected) <= tolerance, "%s (expected %s, got %s)" % [message, expected, actual])


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (expected %.5f, got %.5f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
