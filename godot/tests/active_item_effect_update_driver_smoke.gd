extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectUpdateDriver := preload("res://scripts/items/active_item_effect_update_driver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_scale := 1.0
	var special_gauge := 100.0
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(3.0, -4.0)


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	_verify_update_driver_sequence()

	if _failures.is_empty():
		print("active_item_effect_update_driver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_update_driver_sequence() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var driver := ActiveItemEffectUpdateDriver.new()
	var perf_logger := FakePerfLogger.new()
	driver.configure({
		"state_applier": controller._state_applier,
		"paddle_sync": controller._paddle_sync,
		"player_center_reader": controller._player_center_reader,
		"aipill_runtime": controller._aipill_runtime,
		"stopwatch_runtime": controller._stopwatch_runtime,
		"stopwatch_owner_effects": controller._stopwatch_owner_effects,
		"magnet_field_runtime": controller._magnet_field_runtime,
		"magnet_field_particles": controller._magnet_field_particles,
		"timed_paddle_effects": controller._timed_paddle_effects,
		"holy_barrier_runtime": controller._holy_barrier_runtime,
		"holy_barrier_particles": controller._holy_barrier_particles,
		"dash_boost_runtime": controller._dash_boost_runtime,
		"dash_boost_particles": controller._dash_boost_particles,
		"brick_wall_installation": controller._brick_wall_installation,
		"brick_wall_particles": controller._brick_wall_particles,
		"transient_effect_updater": controller._transient_effect_updater,
		"regeneration_potion_effect": controller._regeneration_potion_effect,
		"pickup_effect_state": controller._pickup_effect_state,
		"commando_supply_actions": controller._commando_supply_actions,
	})

	controller.long_boost_active = true
	controller.long_boost_timer_frames = 480.0
	controller.long_boost_initial_timer_frames = 480.0
	controller.brick_particles.append({
		"kind": "dust",
		"position": Vector2.ZERO,
		"velocity": Vector2(1.0, -1.0),
		"life": 30.0,
		"initial_life": 30.0,
	})
	controller.regeneration_potion_particles.append({
		"position": Vector2.ZERO,
		"velocity": Vector2(0.0, -12.0),
		"age": 0.0,
		"lifetime": 1.0,
	})
	controller.regeneration_potion_rings.append({
		"position": Vector2.ZERO,
		"age": 0.0,
		"duration": 1.0,
	})
	controller.pickup_particles.append({
		"position": Vector2.ZERO,
		"velocity": Vector2(12.0, 0.0),
		"age": 0.0,
		"lifetime": 1.0,
	})
	controller.pickup_effect = {
		"timer": 2.0,
		"alpha": 180.0 / 255.0,
		"position": Vector2.ZERO,
		"start_position": Vector2.ZERO,
	}

	driver.apply_update(controller, owner, 1.0 / 60.0, null, null, perf_logger)

	_expect(controller.long_boost_timer_frames < 480.0, "update driver should tick timed paddle states")
	_expect(controller.long_boost_scale > 1.0, "update driver should apply timed paddle scale")
	_expect(owner.player_paddle_width > 155.0, "update driver should sync owner paddle after timed updates")
	_expect(float(controller.brick_particles[0].get("life", 0.0)) < 30.0, "update driver should tick brick particles")
	_expect(float(controller.regeneration_potion_particles[0].get("age", 0.0)) > 0.0, "update driver should tick regeneration particles")
	_expect(float(controller.regeneration_potion_rings[0].get("age", 0.0)) > 0.0, "update driver should tick regeneration rings")
	_expect(float(controller.pickup_particles[0].get("age", 0.0)) > 0.0, "update driver should tick pickup particles")
	_expect(float(controller.pickup_effect.get("timer", 0.0)) < 2.0, "update driver should tick pickup popup")
	_expect(not perf_logger.labels.has("physics.callback.active_items.aipill"), "effect driver should skip idle aipill timing")
	_expect(not perf_logger.labels.has("physics.callback.active_items.stopwatch"), "effect driver should skip idle stopwatch timing")
	_expect(not perf_logger.labels.has("physics.callback.active_items.magnet_field"), "effect driver should skip idle magnet timing")
	_expect(perf_logger.labels.has("physics.callback.active_items.long_boost"), "effect driver should label long boost timing")
	_expect(perf_logger.labels.has("physics.callback.active_items.transient_effects"), "effect driver should label transient active-item effects")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
