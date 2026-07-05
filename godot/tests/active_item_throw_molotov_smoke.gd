extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemThrowMolotov := preload("res://scripts/items/active_item_throw_molotov.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var boss_pos := Vector2(330.0, 55.0)
	var boss_vel := 0.0


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_throw() -> void:
		calls.append("play_throw")

	func play_molotov_explosion() -> void:
		calls.append("play_molotov_explosion")


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		shakes.append(Vector2(amount, intensity))


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "battle_feedback_state":
			return feedback
		return null


func _init() -> void:
	_verify_helper_spawns_molotov_projectile()
	_verify_controller_windup_release_delegates_molotov()
	_verify_projectile_ignites_fire_zone()
	_verify_direct_fire_zone_clamps_to_visible_center()
	_verify_fire_zone_clamps_away_from_pillars()
	_verify_renderer_ellipse_preserves_playfield_transform()
	_verify_fresh_fire_zone_pushes_on_first_update()
	_verify_fire_zone_bounces_boss_back_instead_of_crossing()
	_verify_fire_zone_updates_boss_fire_and_push()
	_verify_fire_zone_eases_boss_out_smoothly()
	_verify_fire_zone_does_not_repin_boss_while_lingering()
	_verify_fire_zone_paces_rebounce_to_avoid_jitter()
	_verify_fire_zone_blocks_boss_from_crossing()
	_verify_fire_zone_slows_boss_and_lingers()
	_verify_fire_slow_bleeds_off_and_keeps_runtime_alive()
	_verify_round_clear_zeroes_fire_slow()

	if _failures.is_empty():
		print("active_item_throw_molotov_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_spawns_molotov_projectile() -> void:
	var helper: Object = ActiveItemThrowMolotov.new()
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var pending_throw := {
		"start_position": Vector2(377.5, 705.0),
		"target_position": Vector2(380.0, 15.0),
	}

	helper.throw_molotov(controller, owner, pending_throw, registry)

	_expect(controller.get_molotovs().size() == 1, "molotov helper should append one projectile")
	var molotov: Dictionary = controller.get_molotovs()[0]
	_expect(_get_vector2(molotov, "position") == Vector2(377.5, 705.0), "molotov helper should preserve legacy start center")
	_expect(is_equal_approx(float(molotov.get("target_y", 0.0)), 15.0), "molotov helper should preserve target y")
	_expect(
		is_equal_approx(_get_vector2(molotov, "velocity").length(), controller.MOLOTOV_SPEED_PER_FRAME),
		"molotov helper should launch with controller speed"
	)
	_expect(_get_array(molotov, "trail").size() == 1, "molotov helper should seed projectile trail")
	_expect(registry.audio.calls == ["play_throw"], "molotov helper should play throw audio")


func _verify_controller_windup_release_delegates_molotov() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var now_msec: int = Time.get_ticks_msec()
	var pending_throws: Array[Dictionary] = [{
		"item_name": "molotov",
		"start_msec": now_msec - 1000,
		"release_msec": now_msec - 1,
		"start_position": Vector2(377.5, 705.0),
		"target_position": Vector2(380.0, 15.0),
	}]
	controller.pending_throws = pending_throws

	controller._update_throw_windups(FakeOwner.new(), registry)

	_expect(controller.get_pending_throws().is_empty(), "molotov windup release should clear pending queue")
	_expect(controller.get_molotovs().size() == 1, "molotov windup release should spawn projectile")
	_expect(registry.audio.calls == ["play_throw"], "molotov windup release should play throw audio")


func _verify_projectile_ignites_fire_zone() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var molotovs: Array[Dictionary] = [{
		"position": Vector2(380.0, 14.0),
		"velocity": Vector2.ZERO,
		"target_y": 15.0,
		"rotation_degrees": 0.0,
		"rotation_speed": 10.0,
		"trail": [Vector2(380.0, 14.0)],
	}]
	controller.molotovs = molotovs

	controller._update_molotovs(owner, registry, 1.0 / 60.0)

	_expect(controller.get_molotovs().is_empty(), "arrived molotov should be removed")
	_expect(controller.get_molotov_fire_zones().size() == 1, "arrived molotov should create fire zone")
	var zone: Dictionary = controller.get_molotov_fire_zones()[0]
	_expect(_get_vector2(zone, "position") == Vector2(380.0, controller.MOLOTOV_FIRE_MIN_CENTER_Y), "molotov fire zone should clamp to visible center y")
	_expect(is_equal_approx(float(zone.get("width", 0.0)), controller.MOLOTOV_FIRE_WIDTH), "fire zone should preserve width")
	_expect(is_equal_approx(float(zone.get("height", 0.0)), controller.MOLOTOV_FIRE_HEIGHT), "fire zone should preserve height")
	_expect(_get_array(zone, "flames").size() == controller.MOLOTOV_FIRE_INITIAL_FLAMES, "fire zone should seed initial flames")
	_expect(registry.audio.calls == ["play_molotov_explosion"], "fire zone should play molotov explosion audio")
	_expect(registry.feedback.shakes.size() == 1, "fire zone should request impact shake")
	# Modular VFX host pool keys fire zones by zone_id, so trigger_fire_zone
	# must stamp a unique non-zero id on every spawn. age_frames also has to
	# start at zero so the renderer can detect the first frame and fire the
	# one-shot explosion burst tween.
	_expect(int(zone.get("zone_id", 0)) > 0, "fire zone should be stamped with a non-zero zone_id for VFX host matching")
	_expect(is_equal_approx(float(zone.get("age_frames", -1.0)), 0.0), "fire zone should start with age_frames at 0")


func _verify_direct_fire_zone_clamps_to_visible_center() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()

	controller._trigger_molotov_fire_zone(FakeOwner.new(), registry, Vector2(380.0, 10.0))

	_expect(controller.get_molotov_fire_zones().size() == 1, "direct molotov fire trigger should create fire zone")
	var zone: Dictionary = controller.get_molotov_fire_zones()[0]
	_expect(_get_vector2(zone, "position") == Vector2(380.0, controller.MOLOTOV_FIRE_MIN_CENTER_Y), "direct molotov fire trigger should clamp visible y")
	var flames: Array = _get_array(zone, "flames")
	_expect(flames.size() == controller.MOLOTOV_FIRE_INITIAL_FLAMES, "direct molotov fire trigger should seed visible flames")
	for flame_value in flames:
		if not (flame_value is Dictionary):
			_failures.append("direct molotov fire trigger should seed flame dictionaries")
			continue
		var flame: Dictionary = flame_value
		_expect(
			_get_vector2(flame, "position").y >= controller.MOLOTOV_FIRE_MIN_CENTER_Y - 10.0,
			"direct molotov fire trigger should seed flames around clamped center"
		)


func _verify_fire_zone_clamps_away_from_pillars() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()

	controller._trigger_molotov_fire_zone(FakeOwner.new(), registry, Vector2(8.0, 45.0))

	_expect(controller.get_molotov_fire_zones().size() == 1, "left-edge molotov fire trigger should create one fire zone")
	var zone: Dictionary = controller.get_molotov_fire_zones()[0]
	_expect(
		_get_vector2(zone, "position").x == controller.MOLOTOV_FIRE_WIDTH * 0.5,
		"left-edge molotov fire zone should keep the full flame ellipse inside the playfield"
	)


func _verify_renderer_ellipse_preserves_playfield_transform() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_molotov_renderer.gd")
	var prewarm_body := _function_body(source, "func prewarm_assets")
	var body := _function_body(source, "func _draw_filled_ellipse")
	_expect(
		prewarm_body.find("ImpactFlareTextureCache.prewarm()") >= 0,
		"molotov renderer prewarm should build additive flame glow textures before draw-time fire zones"
	)
	_expect(
		body.find("draw_set_transform") < 0,
		"molotov fire-zone ellipse helper should not override the transformed playfield canvas"
	)
	_expect(
		body.find("draw_colored_polygon") >= 0 or body.find("draw_mesh") >= 0,
		"molotov fire-zone ellipse helper should draw in the caller's existing coordinate space"
	)


func _verify_fresh_fire_zone_pushes_on_first_update() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	controller._trigger_molotov_fire_zone(owner, registry, Vector2(380.0, 75.0))
	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)

	_expect(owner.boss_pos.x > 330.0, "fresh fire zone should obstruct movement on the first update without relying on slow")
	_expect(registry.feedback.shakes.size() == 2, "fresh fire-zone trigger and push should request feedback")


func _verify_fire_zone_bounces_boss_back_instead_of_crossing() -> void:
	# A boss moving right into the fire must be knocked BACK to its approach side
	# (left), never pushed across to the far side. The bounce carries one shake.
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.boss_pos = Vector2(330.0, 55.0)  # boss center 380, moving right into the fire
	owner.boss_vel = 5.0
	var zones: Array[Dictionary] = [_fire_zone(controller, 0.0, false)]
	controller.molotov_fire_zones = zones

	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)

	_expect(owner.boss_pos.x < 330.0, "fire zone should bounce the boss back toward its approach side (left), never push it across")
	_expect(registry.feedback.shakes.size() == 1, "a fire-zone contact bounce should request exactly one shake")


func _verify_fire_zone_updates_boss_fire_and_push() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var zone_seed: Dictionary = _fire_zone(controller, 0.0, false)
	zone_seed["spread_timer"] = controller.MOLOTOV_FIRE_SPAWN_INTERVAL_FRAMES
	var zones: Array[Dictionary] = [zone_seed]
	controller.molotov_fire_zones = zones

	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)

	_expect(controller.get_molotov_fire_zones().size() == 1, "active molotov fire zone should remain alive")
	var zone: Dictionary = controller.get_molotov_fire_zones()[0]
	_expect(bool(zone.get("boss_in_fire", false)), "fire zone should mark boss inside fire")
	_expect(_get_array(zone, "flames").size() == controller.MOLOTOV_FIRE_SPAWN_COUNT, "fire zone should spawn flames on interval")
	_expect(owner.boss_pos.x > 330.0, "fire zone should push boss away from flame center")
	_expect(registry.feedback.shakes.size() == 1, "fire push should request small shake")


func _verify_fire_zone_eases_boss_out_smoothly() -> void:
	# The bounce is a decaying VELOCITY, not an instant teleport: after a single
	# frame the boss has barely moved (no snap), but left to play out it eases the
	# boss fully clear of the contact band. This is the anti-jitter contract — a
	# teleport would clear in one frame and read as a flicker.
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.boss_pos = Vector2(330.0, 55.0)  # boss center 380, dead inside the zone
	var zones: Array[Dictionary] = [_fire_zone(controller, 0.0, false)]
	controller.molotov_fire_zones = zones

	var center_x := 380.0
	var contact_band: float = controller.MOLOTOV_FIRE_WIDTH * 0.25 + 50.0

	# One frame: should move only a little, NOT teleport clear (smooth, not a snap).
	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)
	_expect(
		abs((owner.boss_pos.x + 50.0) - center_x) < contact_band,
		"a single frame must NOT teleport the boss clear — the bounce should be a smooth decaying push, not a snap"
	)

	# Let the decaying push play out (no AI in the fake owner pulling back); the
	# boss should ease fully clear of the contact band.
	for _i in range(20):
		controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)
	_expect(
		abs((owner.boss_pos.x + 50.0) - center_x) > contact_band,
		"the decaying bounce should ease the boss fully clear of the fire over time"
	)


func _verify_fire_zone_does_not_repin_boss_while_lingering() -> void:
	# The opposite of the old per-frame wall: a boss already inside the fire
	# (cooldown not yet expired) must NOT be re-positioned every frame. It stays
	# free to move so it can be the AI that walks it back out/in.
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.boss_pos = Vector2(360.0, 55.0)  # boss center 410, inside contact band
	var zones: Array[Dictionary] = [_fire_zone(controller, controller.MOLOTOV_FIRE_PUSH_INTERVAL_FRAMES, true)]
	controller.molotov_fire_zones = zones
	var before_x: float = owner.boss_pos.x

	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)

	_expect(
		is_equal_approx(owner.boss_pos.x, before_x),
		"a boss lingering in the fire within cooldown must stay free to move, not be re-pinned each frame"
	)
	_expect(
		registry.feedback.shakes.is_empty(),
		"lingering boss within cooldown should not fire knockback feedback"
	)


func _verify_fire_zone_paces_rebounce_to_avoid_jitter() -> void:
	# Anti-jitter contract: even a boss dragged back into the fire every frame
	# must be bounced at a paced cadence, not re-armed each frame.
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var zones: Array[Dictionary] = [_fire_zone(controller, 0.0, false)]
	controller.molotov_fire_zones = zones

	# Worst case for jitter: a boss that is forced back into the fire EVERY frame
	# (an infinitely fast return). The paced bounce must NOT re-arm every frame —
	# that machine-gun is exactly the "기괴한 떨림" the user reported. Re-arm waits
	# for the prior bounce velocity to decay AND the short cooldown to elapse.
	for _i in range(20):
		owner.boss_pos = Vector2(330.0, 55.0)  # keep dragging the boss back into the flames
		controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)
	var early_shakes: int = registry.feedback.shakes.size()
	_expect(
		early_shakes >= 1 and early_shakes <= 3,
		"a boss held in the fire must bounce only a couple of times over 20 frames (paced), never per-frame: got %d" % early_shakes
	)

	# Held longer it keeps re-bouncing at the same paced cadence — a handful of
	# times over ~60 frames, never ~60 (which would be the per-frame jitter).
	for _i in range(40):
		owner.boss_pos = Vector2(330.0, 55.0)
		controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)
	var total_shakes: int = registry.feedback.shakes.size()
	_expect(
		total_shakes >= 3 and total_shakes <= 8,
		"over ~60 forced-contact frames the boss should re-bounce a handful of times (paced), not ~60 (jitter): got %d" % total_shakes
	)


func _verify_fire_zone_blocks_boss_from_crossing() -> void:
	# The reported bug: the boss bounced once and then walked straight THROUGH the
	# fire to the far side. Simulate a relentless AI pushing the boss inward at
	# full speed every frame; the contact bounce must keep it on its approach side
	# — it must never reach the far contact edge.
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.boss_pos = Vector2(150.0, 55.0)  # boss center 200, well LEFT of the fire (center 380)
	var zones: Array[Dictionary] = [_fire_zone(controller, 0.0, false)]
	controller.molotov_fire_zones = zones

	var center_x := 380.0
	var far_edge: float = center_x + (controller.MOLOTOV_FIRE_WIDTH * 0.25 + 50.0)  # right contact edge
	var max_reached: float = owner.boss_pos.x + 50.0
	for _i in range(180):  # 3 seconds of relentless inward pressure
		owner.boss_pos.x += 6.0  # AI shoves the boss right (toward/through the fire) at ~full speed
		controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)
		max_reached = max(max_reached, owner.boss_pos.x + 50.0)

	_expect(
		max_reached < far_edge,
		"boss must never cross to the far side of the fire (reached center %.1f, far edge %.1f)" % [max_reached, far_edge]
	)


func _verify_fire_zone_slows_boss_and_lingers() -> void:
	# The 화염 감속 is what keeps the return sluggish (no jitter, no power-through).
	# It must arm while the boss is in the fire, surface in the boss-AI context,
	# and linger a beat after the boss leaves before bleeding off.
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.boss_pos = Vector2(330.0, 55.0)  # boss center 380, in the fire
	var zones: Array[Dictionary] = [_fire_zone(controller, 0.0, false)]
	controller.molotov_fire_zones = zones

	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)
	_expect(
		is_equal_approx(controller.molotov_fire_slow_timer_frames, controller.MOLOTOV_FIRE_SLOW_DURATION_FRAMES),
		"boss in the fire should refresh the 화염 감속 timer to full"
	)
	var ctx: Dictionary = controller.get_boss_ai_context()
	_expect(bool(ctx.get("active_item_molotov_slow_active", false)), "boss-AI context should report molotov slow active")
	_expect(
		float(ctx.get("active_item_molotov_slow_factor", 1.0)) < 1.0,
		"molotov slow factor should actually reduce boss speed"
	)

	# Boss leaves the fire: the slow lingers (sluggish return) then bleeds off.
	owner.boss_pos = Vector2(700.0, 55.0)  # far clear of the fire
	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)
	_expect(
		controller.molotov_fire_slow_timer_frames > 0.0
			and controller.molotov_fire_slow_timer_frames < controller.MOLOTOV_FIRE_SLOW_DURATION_FRAMES,
		"slow should linger but start bleeding off once the boss leaves the fire"
	)


func _verify_fire_slow_bleeds_off_and_keeps_runtime_alive() -> void:
	# The 화염 감속 must NOT get stuck on after the fire zones expire. The bleed-off
	# lives in update_fire_zones, so the controller's update gate must keep running
	# while the slow lingers (or the boss stays slowed forever within the round).
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	# Simulate the slow lingering after the last zone already expired (no zones).
	controller.molotov_fire_slow_timer_frames = controller.MOLOTOV_FIRE_SLOW_DURATION_FRAMES
	_expect(
		controller._has_runtime_update_work(),
		"a lingering molotov fire slow must keep the controller update alive so its bleed-off runs"
	)

	# With no zones, each fire-zone update must bleed the timer down toward zero.
	var before: float = controller.molotov_fire_slow_timer_frames
	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)
	_expect(
		controller.molotov_fire_slow_timer_frames < before,
		"with no live fire zones the slow timer must bleed off, not freeze"
	)

	# Drain it fully and confirm it reaches zero and then reports no work.
	for _i in range(int(controller.MOLOTOV_FIRE_SLOW_DURATION_FRAMES) + 4):
		controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)
	_expect(
		is_equal_approx(controller.molotov_fire_slow_timer_frames, 0.0),
		"the molotov fire slow must fully bleed to zero once the zones are gone"
	)
	_expect(
		not controller._has_runtime_update_work(),
		"once the slow has bled off and nothing else is active, the controller should report no work"
	)


func _verify_round_clear_zeroes_fire_slow() -> void:
	# Round transition (reset_round → clear_round_boss_status_effects) must zero the
	# molotov fire slow and remove its active source zones, or the boss stays slowed
	# into the next round / gets re-slowed by an invisible leftover fire zone.
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	controller.molotov_fire_slow_timer_frames = controller.MOLOTOV_FIRE_SLOW_DURATION_FRAMES
	controller.molotovs.append({
		"position": Vector2(380.0, 120.0),
		"velocity": Vector2.ZERO,
		"target_y": 45.0,
	})
	controller.molotov_fire_zones.append(_fire_zone(controller, 0.0, true))

	controller.clear_round_boss_status_effects()
	_expect(
		is_equal_approx(controller.molotov_fire_slow_timer_frames, 0.0),
		"round-end status clear must zero the molotov fire slow so it does not leak into the next round"
	)
	_expect(controller.get_molotovs().is_empty(), "round-end clear must remove in-flight molotovs")
	_expect(controller.get_molotov_fire_zones().is_empty(), "round-end clear must remove molotov fire zones")

	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)
	_expect(
		is_equal_approx(controller.molotov_fire_slow_timer_frames, 0.0),
		"round-end clear must not leave a hidden fire zone that can reapply slow next round"
	)


func _fire_zone(controller: Object, knockback_cooldown: float, boss_in_fire: bool) -> Dictionary:
	return {
		"position": Vector2(380.0, 75.0),
		"width": controller.MOLOTOV_FIRE_WIDTH,
		"height": controller.MOLOTOV_FIRE_HEIGHT,
		"duration_frames": controller.MOLOTOV_FIRE_DURATION_FRAMES,
		"max_duration_frames": controller.MOLOTOV_FIRE_DURATION_FRAMES,
		"flames": [],
		"spread_timer": 0.0,
		"knockback_cooldown": knockback_cooldown,
		"boss_in_fire": boss_in_fire,
	}


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []


func _function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var next: int = source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
