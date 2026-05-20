extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemThrowTearGas := preload("res://scripts/items/active_item_throw_tear_gas.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var boss_pos := Vector2(330.0, 55.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_throw() -> void:
		calls.append("play_throw")

	func play_smokebomb() -> void:
		calls.append("play_smokebomb")

	func play_active_item() -> void:
		calls.append("play_active_item")


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
	_verify_helper_spawns_tear_gas_projectile()
	_verify_controller_windup_release_delegates_tear_gas()
	_verify_projectile_arming_triggers_gas_zone()
	_verify_gas_zone_clamps_away_from_pillars()
	_verify_zone_update_sets_boss_pause()

	if _failures.is_empty():
		print("active_item_throw_tear_gas_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_spawns_tear_gas_projectile() -> void:
	var helper: Object = ActiveItemThrowTearGas.new()
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var pending_throw := {
		"start_position": Vector2(377.5, 705.0),
		"target_position": Vector2(380.0, 75.0),
	}

	helper.throw_tear_gas(controller, owner, pending_throw, registry)

	_expect(controller.get_tear_gas_projectiles().size() == 1, "tear gas helper should append one projectile")
	var projectile: Dictionary = controller.get_tear_gas_projectiles()[0]
	_expect(_get_vector2(projectile, "position") == Vector2(377.5, 705.0), "tear gas helper should preserve legacy start center")
	_expect(_get_vector2(projectile, "target_position") == Vector2(380.0, 75.0), "tear gas helper should preserve target")
	_expect(
		is_equal_approx(_get_vector2(projectile, "velocity").length(), controller.TEAR_GAS_SPEED_PER_FRAME),
		"tear gas helper should launch with controller speed"
	)
	_expect(not bool(projectile.get("arrived", true)), "tear gas helper should start in flight")
	_expect(not bool(projectile.get("emitted", true)), "tear gas helper should start unemitted")
	_expect(registry.audio.calls == ["play_throw"], "tear gas helper should play throw audio")


func _verify_controller_windup_release_delegates_tear_gas() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var now_msec: int = Time.get_ticks_msec()
	var pending_throws: Array[Dictionary] = [{
		"item_name": "tear_gas",
		"start_msec": now_msec - 1000,
		"release_msec": now_msec - 1,
		"start_position": Vector2(377.5, 705.0),
		"target_position": Vector2(380.0, 75.0),
	}]
	controller.pending_throws = pending_throws

	controller._update_throw_windups(FakeOwner.new(), registry)

	_expect(controller.get_pending_throws().is_empty(), "tear gas windup release should clear pending queue")
	_expect(controller.get_tear_gas_projectiles().size() == 1, "tear gas windup release should spawn projectile")
	_expect(registry.audio.calls == ["play_throw"], "tear gas windup release should play throw audio")


func _verify_projectile_arming_triggers_gas_zone() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var projectiles: Array[Dictionary] = [{
		"position": Vector2(380.0, 75.0),
		"velocity": Vector2.ZERO,
		"target_position": Vector2(380.0, 75.0),
		"rotation_degrees": 0.0,
		"timer_frames": controller.TEAR_GAS_ARMED_DELAY_FRAMES,
		"emitted": false,
		"arrived": true,
		"trail": [Vector2(380.0, 75.0)],
	}]
	controller.tear_gas_projectiles = projectiles

	controller._update_tear_gas_projectiles(owner, registry, 1.0 / 60.0)

	_expect(controller.get_tear_gas_projectiles().is_empty(), "armed tear gas projectile should be removed after emission")
	_expect(controller.get_tear_gas_zones().size() == 1, "armed tear gas projectile should trigger a gas zone")
	var zone: Dictionary = controller.get_tear_gas_zones()[0]
	_expect(is_equal_approx(float(zone.get("max_radius", 0.0)), controller.TEAR_GAS_MAX_RADIUS), "gas zone should preserve max radius")
	_expect(is_equal_approx(float(zone.get("max_radius_x", 0.0)), controller.TEAR_GAS_MAX_RADIUS_X), "gas zone should preserve horizontal max radius")
	_expect(_get_array(zone, "particles").size() > 0, "gas zone should seed smoke particles")
	_expect(_get_array(zone, "particles").size() <= controller.TEAR_GAS_PARTICLE_CAP, "gas zone should respect particle cap")
	_expect(registry.audio.calls == ["play_smokebomb"], "gas zone should play smokebomb audio")
	_expect(registry.feedback.shakes.size() == 1, "gas zone should request screen shake")


func _verify_gas_zone_clamps_away_from_pillars() -> void:
	var helper: Object = ActiveItemThrowTearGas.new()
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()

	helper.trigger_zone(controller, registry, Vector2(8.0, 150.0), FakeOwner.new())

	_expect(controller.get_tear_gas_zones().size() == 1, "left-edge tear gas should create one gas zone")
	var zone: Dictionary = controller.get_tear_gas_zones()[0]
	_expect(
		_get_vector2(zone, "position").x == min(controller.FIELD_WIDTH * 0.5, controller.TEAR_GAS_MAX_RADIUS_X),
		"left-edge tear gas should keep its full smoke ellipse inside the playfield"
	)
	_expect(_get_array(zone, "particles").size() > 0, "left-edge tear gas should seed particles around the clamped center")


func _verify_zone_update_sets_boss_pause() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var zones: Array[Dictionary] = [{
		"position": Vector2(380.0, 75.0),
		"radius": 160.0,
		"max_radius": controller.TEAR_GAS_MAX_RADIUS,
		"radius_x": 300.0,
		"max_radius_x": controller.TEAR_GAS_MAX_RADIUS_X,
		"duration_frames": controller.TEAR_GAS_ZONE_DURATION_FRAMES,
		"max_duration_frames": controller.TEAR_GAS_ZONE_DURATION_FRAMES,
		"opacity": 0.68,
		"burst_timer": controller.TEAR_GAS_BURST_FRAMES,
		"burst_ring_radius": 0.0,
		"particles": [],
		"spawn_timer": controller.TEAR_GAS_PARTICLE_SPAWN_INTERVAL_FRAMES,
		"boss_in_gas": false,
	}]
	controller.tear_gas_zones = zones

	controller._update_tear_gas_zones(owner, registry, 1.0 / 60.0)

	_expect(controller.get_tear_gas_zones().size() == 1, "active gas zone should remain alive")
	var zone: Dictionary = controller.get_tear_gas_zones()[0]
	_expect(float(zone.get("radius", 0.0)) > 160.0, "gas zone should expand vertically")
	_expect(float(zone.get("radius_x", 0.0)) > 300.0, "gas zone should expand horizontally")
	_expect(bool(zone.get("boss_in_gas", false)), "gas zone should mark boss inside gas")
	_expect(_get_array(zone, "particles").size() > 0, "gas zone update should spawn particles")
	_expect(controller.tear_gas_boss_pause_timer_frames > 0.0, "gas zone should pause boss skill cooldown")
	_expect(controller.tear_gas_boss_pause_text_timer_frames > 0.0, "gas zone should show pause text timer")

	var pause_before: float = controller.tear_gas_boss_pause_timer_frames
	var text_before: float = controller.tear_gas_boss_pause_text_timer_frames
	controller._update_tear_gas_boss_pause(1.0 / 60.0)
	_expect(controller.tear_gas_boss_pause_timer_frames < pause_before, "boss pause wrapper should decay latch timer")
	_expect(controller.tear_gas_boss_pause_text_timer_frames < text_before, "boss pause wrapper should decay text timer")


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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
