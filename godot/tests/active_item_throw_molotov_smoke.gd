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
	_verify_fire_zone_blocks_crossing_between_feedback_ticks()
	_verify_fire_zone_updates_boss_fire_and_push()

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


func _verify_fire_zone_blocks_crossing_between_feedback_ticks() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.boss_pos = Vector2(330.0, 55.0)
	owner.boss_vel = 5.0
	var zones: Array[Dictionary] = [{
		"position": Vector2(380.0, 75.0),
		"width": controller.MOLOTOV_FIRE_WIDTH,
		"height": controller.MOLOTOV_FIRE_HEIGHT,
		"duration_frames": controller.MOLOTOV_FIRE_DURATION_FRAMES,
		"max_duration_frames": controller.MOLOTOV_FIRE_DURATION_FRAMES,
		"flames": [],
		"spread_timer": 0.0,
		"push_timer": 0.0,
		"boss_in_fire": false,
	}]
	controller.molotov_fire_zones = zones

	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)

	_expect(owner.boss_pos.x < 260.0, "fire zone should block a boss crossing through the center even between feedback ticks")
	_expect(registry.feedback.shakes.is_empty(), "between-tick fire-zone obstruction should not spam feedback shake")


func _verify_fire_zone_updates_boss_fire_and_push() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var zones: Array[Dictionary] = [{
		"position": Vector2(380.0, 75.0),
		"width": controller.MOLOTOV_FIRE_WIDTH,
		"height": controller.MOLOTOV_FIRE_HEIGHT,
		"duration_frames": controller.MOLOTOV_FIRE_DURATION_FRAMES,
		"max_duration_frames": controller.MOLOTOV_FIRE_DURATION_FRAMES,
		"flames": [],
		"spread_timer": controller.MOLOTOV_FIRE_SPAWN_INTERVAL_FRAMES,
		"push_timer": controller.MOLOTOV_FIRE_PUSH_INTERVAL_FRAMES,
		"boss_in_fire": false,
	}]
	controller.molotov_fire_zones = zones

	controller._update_molotov_fire_zones(owner, registry, 1.0 / 60.0)

	_expect(controller.get_molotov_fire_zones().size() == 1, "active molotov fire zone should remain alive")
	var zone: Dictionary = controller.get_molotov_fire_zones()[0]
	_expect(bool(zone.get("boss_in_fire", false)), "fire zone should mark boss inside fire")
	_expect(_get_array(zone, "flames").size() == controller.MOLOTOV_FIRE_SPAWN_COUNT, "fire zone should spawn flames on interval")
	_expect(owner.boss_pos.x > 330.0, "fire zone should push boss away from flame center")
	_expect(registry.feedback.shakes.size() == 1, "fire push should request small shake")


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
