extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectRouter := preload("res://scripts/items/active_item_effect_router.gd")
const ActiveItemTrampolineRuntime := preload("res://scripts/items/active_item_trampoline_runtime.gd")
const ActiveItemTrampolineRenderer := preload("res://scripts/items/active_item_trampoline_renderer.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")

const BALL_SIZE := 28.6
const FRAME_DELTA := 1.0 / 60.0

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0


func _init() -> void:
	_verify_catalog_entry()
	_verify_router_dispatches_activation()
	_verify_activation_places_trampoline_at_player_center()
	_verify_slingshot_capture_then_launch()
	_verify_stepper_full_path_collision_priority()
	_verify_rising_ball_is_ignored()
	_verify_bounce_speed_floor_and_cap()
	_verify_launch_overspeed_survives_frame_speed_cap()
	_verify_capture_watchdog_releases_on_lost_contact()
	_verify_trampoline_expires_after_three_bounces()
	_verify_bounce_anim_timer_ticks_down_on_update()
	_verify_mat_body_polygon_stays_triangulable()
	_verify_reset_clears_trampoline_state()

	if _failures.is_empty():
		print("active_item_trampoline_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_entry() -> void:
	var catalog: Object = ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("trampoline")
	_expect(not item_data.is_empty(), "catalog should build trampoline item data")
	_expect(str(item_data.get("type", "")) == "active", "trampoline should be an active item")
	_expect(str(item_data.get("effect", "")) == "trampoline", "trampoline effect id should match")
	_expect(
		ActiveItemCatalog.FIELD_SPAWN_ORDER.has("trampoline"),
		"trampoline should be in FIELD_SPAWN_ORDER so field spawn / HUD prewarm / pandora pools include it"
	)
	_expect(
		float(item_data.get("chance", 0.0)) > 0.0,
		"trampoline should have a positive field spawn chance"
	)
	_expect(
		FileAccess.file_exists(str(item_data.get("icon_path", ""))),
		"trampoline icon PNG should exist at the catalog icon_path"
	)
	_expect(
		ActiveItemDebugSpawnMenu.DEBUG_ENTRY_ORDER.has("trampoline"),
		"trampoline should be in the F2 debug spawn menu DEBUG_ENTRY_ORDER (separate hardcoded list, not catalog-driven)"
	)


func _verify_router_dispatches_activation() -> void:
	var router: Object = ActiveItemEffectRouter.new()
	var controller: Object = ActiveItemEffectController.new()
	var catalog: Object = ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("trampoline")
	var consumed: bool = router.apply_item_effect(item_data, FakeOwner.new(), null, controller, null)
	_expect(consumed, "router should dispatch trampoline activation and report success")
	_expect(controller.trampolines.size() == 1, "router dispatch should leave one placed trampoline")


func _verify_activation_places_trampoline_at_player_center() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	_expect(not controller.activate_trampoline(null, null), "activation without owner should fail")
	_expect(controller.activate_trampoline(owner, null), "activation with owner should succeed")
	_expect(controller.trampolines.size() == 1, "one trampoline should be placed")

	var rect: Rect2 = controller.trampolines[0].get("rect", Rect2())
	var expected_center_x: float = owner.player_pos.x + owner.player_paddle_width * 0.5
	_expect(
		abs(rect.get_center().x - expected_center_x) < 0.01,
		"trampoline should be centered on the player paddle center x"
	)
	_expect(
		abs(rect.position.y - ActiveItemTrampolineRuntime.TRAMPOLINE_MAT_TOP_Y) < 0.01,
		"trampoline mat should sit at the elevated mat band"
	)
	_expect(
		rect.position.y < owner.player_pos.y - 5.0,
		"trampoline mat top must stay above the player paddle hitbox top (player_pos.y - hitbox_padding), or check_paddles eats the bounce"
	)
	_expect(
		not controller.trampoline_particles.is_empty(),
		"placement should spawn install particles"
	)


func _verify_slingshot_capture_then_launch() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.activate_trampoline(FakeOwner.new(), null)
	var rect: Rect2 = controller.trampolines[0].get("rect", Rect2())

	var cycle: Dictionary = _run_capture_cycle(controller, Vector2(rect.get_center().x, 600.0), Vector2(2.0, 8.0))
	_expect(bool(cycle.get("launched", false)), "descending ball should be captured and then launched")
	_expect(
		int(cycle.get("capture_frames", 0)) >= 5,
		"the slingshot draw should span multiple frames, not an instant reflection (got %d)" % int(cycle.get("capture_frames", 0))
	)
	_expect(
		float(cycle.get("max_depth", 0.0)) > 12.0,
		"the ball should actually sink into the mat while the spring loads (got %.1f)" % float(cycle.get("max_depth", 0.0))
	)
	_expect(
		float(cycle.get("max_depth", 0.0)) <= ActiveItemTrampolineRuntime.CAPTURE_MAX_SINK_DEPTH + 6.0,
		"the sink depth should stay bounded by the capture cap"
	)

	var launch_velocity: Vector2 = cycle.get("launch_velocity", Vector2.ZERO)
	_expect(launch_velocity.y < 0.0, "the launch should actually send the ball upward")
	_expect(
		launch_velocity.y < -(8.0 * 1.25 + 0.5),
		"the draw bonus should launch faster than the bare x1.25 entry boost (got %.2f)" % launch_velocity.y
	)
	_expect(
		abs(launch_velocity.y) <= BallUpdateStaticConfig.MAX_BALL_SPEED * ActiveItemTrampolineRuntime.LAUNCH_OVERSPEED_CAP_RATIO + 0.01,
		"the launch should stay within cap x1.3"
	)
	_expect(
		abs(launch_velocity.x - 2.0) < 0.01,
		"the launch should restore the entry horizontal velocity"
	)
	_expect(
		float(cycle.get("final_pos_y", 0.0)) < ActiveItemTrampolineRuntime.TRAMPOLINE_BOTTOM_Y,
		"the capture should resolve above the floor band, not after a pass-through"
	)
	_expect(
		float(controller.trampolines[0].get("bounce_timer_frames", 0.0)) > 0.0,
		"the launch should arm the rebound animation timer"
	)
	_expect(
		not bool(controller.trampolines[0].get("capture_active", false)),
		"the capture state should be cleared after the launch"
	)


# Drives detector contact -> notify -> velocity shaping each frame, mirroring
# the runtime per-frame distance (ball_vel * delta * 60) and feeding the
# controller update (capture watchdog) once per frame like the real loop.
func _run_capture_cycle(controller: Object, start_pos: Vector2, start_vel: Vector2) -> Dictionary:
	var detector: Object = BallMotionCollisionDetector.new()
	var ball_pos: Vector2 = start_pos
	var ball_vel: Vector2 = start_vel
	var mat_top: float = 0.0
	if not controller.trampolines.is_empty():
		var rect: Rect2 = controller.trampolines[0].get("rect", Rect2())
		mat_top = rect.position.y
	var capture_frames: int = 0
	var max_depth: float = 0.0
	var launch_result: Dictionary = {}
	for frame in range(240):
		ball_pos += ball_vel * FRAME_DELTA * 60.0
		var event: Dictionary = detector.check_trampoline(
			ball_pos, ball_vel, BALL_SIZE, controller.get_trampoline_collision_context()
		)
		if not event.is_empty():
			max_depth = max(max_depth, ball_pos.y + BALL_SIZE * 0.5 - mat_top)
			var result: Dictionary = controller.notify_trampoline_hit(
				int(event.get("trampoline_index", -1)), ball_pos, ball_vel
			)
			if str(result.get("phase", "")) == "launch":
				launch_result = result
				ball_vel = result.get("bounce_velocity", ball_vel)
			else:
				capture_frames += 1
				ball_vel = result.get("ball_vel", ball_vel)
		controller.update(null, FRAME_DELTA)
		if not launch_result.is_empty():
			break
	return {
		"launched": not launch_result.is_empty(),
		"destroyed": bool(launch_result.get("destroyed", false)),
		"bounce_count": int(launch_result.get("bounce_count", 0)),
		"launch_velocity": launch_result.get("bounce_velocity", Vector2.ZERO),
		"capture_frames": capture_frames,
		"max_depth": max_depth,
		"final_pos_y": ball_pos.y,
	}


func _verify_stepper_full_path_collision_priority() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	controller.activate_trampoline(owner, null)
	var rect: Rect2 = controller.trampolines[0].get("rect", Rect2())
	var mat_center_x: float = rect.get_center().x

	# 1. Player paddle x-overlapping the mat: the full stepper path must still
	#    return "trampoline" (the regression Codex review flagged — the paddle
	#    hitbox band y≈695..760 contains the old floor mat, and check_paddles
	#    used to run first and eat the bounce).
	var overlap_event: String = _run_stepper_descent(
		Vector2(mat_center_x, 600.0),
		Vector2(0.0, 8.0),
		_build_step_context(owner, controller)
	)
	_expect(
		overlap_event == "trampoline",
		"full stepper path should return trampoline even while the player paddle x-overlaps the mat (got %s)" % overlap_event
	)

	# 2. Player far away: a ball dropping onto the mat still bounces.
	var away_owner := FakeOwner.new()
	away_owner.player_pos = Vector2(40.0, 700.0)
	var away_event: String = _run_stepper_descent(
		Vector2(mat_center_x, 600.0),
		Vector2(0.0, 8.0),
		_build_step_context(away_owner, controller)
	)
	_expect(
		away_event == "trampoline",
		"full stepper path should return trampoline for a missed ball landing on the mat (got %s)" % away_event
	)

	# 3. Ball dropping onto the player away from the mat: normal paddle bounce.
	var paddle_event: String = _run_stepper_descent(
		Vector2(away_owner.player_pos.x + away_owner.player_paddle_width * 0.5, 600.0),
		Vector2(0.0, 8.0),
		_build_step_context(away_owner, controller)
	)
	_expect(
		paddle_event == "player_paddle",
		"full stepper path should keep normal paddle bounces away from the mat (got %s)" % paddle_event
	)

	# 4. No trampoline placed: the same descent over the player is a paddle hit.
	var empty_controller: Object = ActiveItemEffectController.new()
	var no_item_event: String = _run_stepper_descent(
		Vector2(mat_center_x, 600.0),
		Vector2(0.0, 8.0),
		_build_step_context(owner, empty_controller)
	)
	_expect(
		no_item_event == "player_paddle",
		"without a trampoline the same descent should be a normal paddle hit (got %s)" % no_item_event
	)


func _build_step_context(owner: FakeOwner, controller: Object) -> Dictionary:
	var context: Dictionary = {
		"ball_size": BALL_SIZE,
		"width": 760.0,
		"height": 750.0,
		"max_step_distance": 12.0,
		"player_pos": owner.player_pos,
		"player_paddle_size": Vector2(owner.player_paddle_width, 50.0),
		"boss_pos": Vector2(302.5, 25.0),
		"boss_paddle_size": Vector2(155.0, 40.0),
		"hitbox_padding": 5.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	context.merge(controller.get_trampoline_collision_context(), true)
	return context


func _run_stepper_descent(start_pos: Vector2, ball_vel: Vector2, context: Dictionary) -> String:
	var stepper: Object = BallMotionStepper.new()
	var ball_pos: Vector2 = start_pos
	for frame in range(120):
		# mirror the runtime per-frame distance: ball_vel * delta * 60
		var step_result: Dictionary = stepper.step(ball_pos, ball_vel * FRAME_DELTA * 60.0, ball_vel, context)
		ball_pos = step_result.get("ball_pos", ball_pos)
		var event: String = str(step_result.get("event", "none"))
		if event != "none":
			return event
	return "none"


func _verify_rising_ball_is_ignored() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.activate_trampoline(FakeOwner.new(), null)
	var detector: Object = BallMotionCollisionDetector.new()
	var rect: Rect2 = controller.trampolines[0].get("rect", Rect2())
	var inside_pos: Vector2 = rect.get_center()
	var rising_event: Dictionary = detector.check_trampoline(
		inside_pos,
		Vector2(2.0, -8.0),
		BALL_SIZE,
		controller.get_trampoline_collision_context()
	)
	_expect(rising_event.is_empty(), "a rising ball overlapping the mat should not re-trigger the bounce")


func _verify_bounce_speed_floor_and_cap() -> void:
	var runtime: Object = ActiveItemTrampolineRuntime.new()
	var max_ball_speed: float = BallUpdateStaticConfig.MAX_BALL_SPEED
	var slow: Vector2 = runtime.get_bounce_velocity(Vector2(1.0, 3.0))
	_expect(
		abs(slow.y + ActiveItemTrampolineRuntime.TRAMPOLINE_MIN_UPWARD_SPEED) < 0.01,
		"slow descent with no draw should still leave at the minimum upward speed"
	)
	var full_draw_bonus: Vector2 = runtime.get_bounce_velocity(Vector2(1.0, 8.0), 1.0)
	_expect(
		abs(full_draw_bonus.y + (8.0 * 1.25 + 0.30 * max_ball_speed)) < 0.01,
		"a full draw should add 30% of the global ball speed cap on top of the entry-based launch"
	)
	var overspeed_cap: Vector2 = runtime.get_bounce_velocity(Vector2(1.0, max_ball_speed), 1.0)
	_expect(
		abs(overspeed_cap.y + max_ball_speed * ActiveItemTrampolineRuntime.LAUNCH_OVERSPEED_CAP_RATIO) < 0.01,
		"the launch may exceed the global ball speed cap by at most 30%"
	)
	_expect(
		abs(overspeed_cap.y) > max_ball_speed,
		"a max-speed full-draw launch should actually exceed the global ball speed cap"
	)


# The overspeed is only real if it survives ball_frame_motion_controller's
# per-frame clamp — the transient scene cap key is load-bearing.
func _verify_launch_overspeed_survives_frame_speed_cap() -> void:
	var motion: Object = BallFrameMotionController.new()
	var fake_physics := RefCounted.new()
	var overspeed := Vector2(0.0, -33.0)

	var raised_scene: Dictionary = {
		"ball_vel": overspeed,
		"ball_impact_boost": 1.0,
		"max_ball_speed": BallUpdateStaticConfig.MAX_BALL_SPEED,
		"trampoline_launch_speed_cap": 33.8,
	}
	motion.apply_ball_speed_limits(raised_scene, {"ball_physics": fake_physics})
	_expect(
		abs(Vector2(raised_scene.get("ball_vel", Vector2.ZERO)).length() - overspeed.length()) < 0.01,
		"the trampoline_launch_speed_cap scene key should let the overspeed launch survive the per-frame clamp"
	)

	var plain_scene: Dictionary = {
		"ball_vel": overspeed,
		"ball_impact_boost": 1.0,
		"max_ball_speed": BallUpdateStaticConfig.MAX_BALL_SPEED,
	}
	motion.apply_ball_speed_limits(plain_scene, {"ball_physics": fake_physics})
	_expect(
		abs(Vector2(plain_scene.get("ball_vel", Vector2.ZERO)).length() - BallUpdateStaticConfig.MAX_BALL_SPEED) < 0.01,
		"without the transient cap key the same launch is clamped — proves the key is load-bearing, not decorative"
	)


func _verify_capture_watchdog_releases_on_lost_contact() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.activate_trampoline(FakeOwner.new(), null)
	var rect: Rect2 = controller.trampolines[0].get("rect", Rect2())
	var contact_pos := Vector2(rect.get_center().x, rect.position.y - BALL_SIZE * 0.5 + 4.0)

	var first: Dictionary = controller.notify_trampoline_hit(0, contact_pos, Vector2(0.0, 8.0))
	_expect(str(first.get("phase", "")) == "catch", "first contact should report the catch phase")
	_expect(
		bool(controller.trampolines[0].get("capture_active", false)),
		"first contact should arm the capture state"
	)

	controller.update(null, FRAME_DELTA)
	_expect(
		bool(controller.trampolines[0].get("capture_active", false)),
		"capture should survive the same-frame watchdog pass"
	)
	controller.update(null, FRAME_DELTA)
	_expect(
		not bool(controller.trampolines[0].get("capture_active", false)),
		"capture must self-release when contact events stop arriving (freeze / reset / lateral exit)"
	)
	for i in range(60):
		controller.update(null, FRAME_DELTA)
	_expect(
		float(controller.trampolines[0].get("capture_depth", 0.0)) <= 0.01,
		"the mat should relax back to rest after an aborted capture"
	)


func _verify_trampoline_expires_after_three_bounces() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.activate_trampoline(FakeOwner.new(), null)
	var rect: Rect2 = controller.trampolines[0].get("rect", Rect2())
	var drop_pos := Vector2(rect.get_center().x, 620.0)
	var drop_vel := Vector2(0.0, 8.0)

	var first: Dictionary = _run_capture_cycle(controller, drop_pos, drop_vel)
	_expect(bool(first.get("launched", false)) and not bool(first.get("destroyed", true)), "first launch should keep the trampoline")
	var second: Dictionary = _run_capture_cycle(controller, drop_pos, drop_vel)
	_expect(bool(second.get("launched", false)) and not bool(second.get("destroyed", true)), "second launch should keep the trampoline")
	var third: Dictionary = _run_capture_cycle(controller, drop_pos, drop_vel)
	_expect(bool(third.get("launched", false)), "third capture should still launch the ball")
	_expect(bool(third.get("destroyed", false)), "third launch should destroy the trampoline")
	_expect(
		Vector2(third.get("launch_velocity", Vector2.ZERO)).y < 0.0,
		"the final launch should still send the ball upward"
	)
	_expect(controller.trampolines.is_empty(), "trampoline should be removed after the third launch")
	_expect(
		controller.get_trampoline_collision_context().get("trampolines", []).is_empty(),
		"collision context should expose no trampolines after expiry"
	)

	var invalid: Dictionary = controller.notify_trampoline_hit(0, drop_pos, drop_vel)
	_expect(not bool(invalid.get("destroyed", true)), "contact on a missing index should be a safe no-op")


func _verify_bounce_anim_timer_ticks_down_on_update() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.activate_trampoline(FakeOwner.new(), null)
	var rect: Rect2 = controller.trampolines[0].get("rect", Rect2())
	var cycle: Dictionary = _run_capture_cycle(controller, Vector2(rect.get_center().x, 620.0), Vector2(0.0, 8.0))
	_expect(bool(cycle.get("launched", false)), "precondition: launch completed")

	var before: float = float(controller.trampolines[0].get("bounce_timer_frames", 0.0))
	_expect(before > 0.0, "bounce timer should be armed after a launch")
	controller.update(null, FRAME_DELTA)
	var after: float = float(controller.trampolines[0].get("bounce_timer_frames", 0.0))
	_expect(
		after < before,
		"controller update must tick down the same bounce_timer_frames key the renderer reads"
	)

	var particle_count_before: int = controller.trampoline_particles.size()
	for i in range(120):
		controller.update(null, FRAME_DELTA)
	_expect(
		controller.trampoline_particles.size() < particle_count_before,
		"bounce particles should expire over time"
	)


# Regression: a full slingshot draw (38px sag) sinks the top curve ~20px below
# the 18px mat's bottom edge; with a fixed flat bottom the body polygon
# self-intersected and draw_colored_polygon spammed "Invalid polygon data"
# every capture frame (62 errors/session in the 2026-06-11 perf logs).
func _verify_mat_body_polygon_stays_triangulable() -> void:
	var center := Vector2(380.0, 695.0)
	var sweep: Array = [
		[55.0, 9.0, 0.0, 0.5],   # idle flat mat
		[55.0, 9.0, -7.0, 0.5],  # bounce overshoot above the frame
		[55.0, 9.0, 38.0, 0.5],  # full draw, centered
		[55.0, 9.0, 38.0, 0.1],  # full draw at the capture_x_ratio clamp edge
		[11.0, 2.0, 38.0, 0.9],  # spawn-scale mat (min height) + full draw
	]
	for params in sweep:
		var half_width: float = params[0]
		var half_height: float = params[1]
		var deflection: float = params[2]
		var sag_center: float = params[3]
		var top_points: PackedVector2Array = ActiveItemTrampolineRenderer.build_mat_top_points(
			center, half_width, center.y - half_height, deflection, sag_center
		)
		var body_points: PackedVector2Array = ActiveItemTrampolineRenderer.build_mat_body_points(
			top_points, center.y + half_height
		)
		_expect(
			not Geometry2D.triangulate_polygon(body_points).is_empty(),
			"mat body polygon should stay triangulable (hw=%.1f hh=%.1f defl=%.1f sag=%.1f)" % [
				half_width, half_height, deflection, sag_center
			]
		)


func _verify_reset_clears_trampoline_state() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.activate_trampoline(FakeOwner.new(), null)
	var rect: Rect2 = controller.trampolines[0].get("rect", Rect2())
	controller.notify_trampoline_hit(0, Vector2(rect.get_center().x, rect.position.y - BALL_SIZE * 0.5 + 4.0), Vector2(0.0, 8.0))
	_expect(not controller.trampolines.is_empty(), "precondition: trampoline placed")
	controller.reset()
	_expect(controller.trampolines.is_empty(), "reset should clear placed trampolines")
	_expect(controller.trampoline_particles.is_empty(), "reset should clear trampoline particles")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
