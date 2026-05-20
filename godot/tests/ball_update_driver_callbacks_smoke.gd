extends SceneTree

const BallUpdateDriver := preload("res://scripts/core/battle_scene_ball_update_driver.gd")

var _failures: Array[String] = []
var _score_events: Array[String] = []
var _round_events: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_pos := Vector2.ZERO
	var drive_ball_active := true
	var ball_spin_strength := 5.0


class FakeContextBuilder:
	extends RefCounted

	var update_context_calls := 0
	var update_deps_calls := 0
	var last_update_deps_context: Dictionary = {}

	func build_update_context(_owner: Object) -> Dictionary:
		update_context_calls += 1
		return {"context_seen": true}

	func build_update_deps(_registry: Object, runtime_context: Dictionary = {}) -> Dictionary:
		update_deps_calls += 1
		last_update_deps_context = runtime_context
		return {"deps_seen": true}


class FakeBridge:
	extends RefCounted

	var reset_calls := 0
	var clear_calls := 0
	var last_clear_spin := false
	var last_registry: Object

	func reset_drive_input_frames(registry: Object) -> void:
		reset_calls += 1
		last_registry = registry

	func clear_drive_ball_state(registry: Object, clear_spin: bool = false) -> Dictionary:
		clear_calls += 1
		last_registry = registry
		last_clear_spin = clear_spin
		return {
			"drive_ball_active": false,
			"ball_spin_strength": 0.0 if clear_spin else 9.0,
		}


class FakeController:
	extends RefCounted

	var calls := 0

	func update(_delta: float, context: Dictionary, deps: Dictionary, callbacks: Dictionary = {}) -> Dictionary:
		calls += 1
		var reset_callback: Callable = callbacks.get("reset_drive_input", Callable())
		if reset_callback.is_valid():
			reset_callback.call()
		var clear_callback: Callable = callbacks.get("clear_drive_ball", Callable())
		if clear_callback.is_valid():
			clear_callback.call(true)
		return {
			"snapshot": {
				"ball_pos": Vector2(123.0, 456.0),
			},
			"score_event": "player",
			"round_restart_event": "rematch",
			"context_seen": bool(context.get("context_seen", false)),
			"deps_seen": bool(deps.get("deps_seen", false)),
		}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_update_callbacks_are_bound()
	_verify_clear_drive_callback_accepts_bound_owner_without_clear_spin()

	if _failures.is_empty():
		print("ball_update_driver_callbacks_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_update_callbacks_are_bound() -> void:
	var owner := FakeOwner.new()
	var controller := FakeController.new()
	var context_builder := FakeContextBuilder.new()
	var bridge := FakeBridge.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"ball_update_controller": controller,
		"ball_update_context": context_builder,
		"ball_scene_bridge": bridge,
	}
	var driver: Object = BallUpdateDriver.new()

	driver.update_ball(
		owner,
		registry,
		0.25,
		Callable(self, "_record_score_event"),
		Callable(self, "_record_round_event")
	)

	_expect(controller.calls == 1, "ball update driver should call update controller")
	_expect(context_builder.update_context_calls == 1 and context_builder.update_deps_calls == 1, "ball update driver should build update context and deps")
	_expect(bool(context_builder.last_update_deps_context.get("context_seen", false)), "ball update driver should pass the built update context into deps")
	_expect(bridge.reset_calls == 1 and bridge.last_registry == registry, "reset callback should receive bound registry")
	_expect(bridge.clear_calls == 1 and bridge.last_clear_spin, "clear callback should preserve clear_spin argument")
	_expect(not owner.drive_ball_active and abs(owner.ball_spin_strength) <= 0.001, "clear callback should apply bridge snapshot to owner")
	_expect(owner.ball_pos == Vector2(123.0, 456.0), "ball update result snapshot should apply after callback snapshot")
	_expect(_score_events == ["player"], "ball update driver should forward score event")
	_expect(_round_events == ["rematch"], "ball update driver should forward round restart event")

	bridge.last_registry = null
	registry.instances.clear()


func _verify_clear_drive_callback_accepts_bound_owner_without_clear_spin() -> void:
	var owner := FakeOwner.new()
	var bridge := FakeBridge.new()
	var registry := FakeRegistry.new()
	registry.instances = {"ball_scene_bridge": bridge}
	var driver: Object = BallUpdateDriver.new()

	driver.call("_clear_drive_ball_state", owner, registry)

	_expect(bridge.clear_calls == 1 and not bridge.last_clear_spin, "bound clear callback without clear_spin should default false")
	_expect(not owner.drive_ball_active and abs(owner.ball_spin_strength - 9.0) <= 0.001, "bound clear callback without clear_spin should apply bridge snapshot")

	bridge.last_registry = null
	registry.instances.clear()


func _record_score_event(event: String) -> void:
	_score_events.append(event)


func _record_round_event(event: String) -> void:
	_round_events.append(event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
