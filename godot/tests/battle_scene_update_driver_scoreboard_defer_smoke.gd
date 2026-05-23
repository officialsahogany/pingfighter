extends SceneTree

const BattleSceneUpdateDriver := preload("res://scripts/core/battle_scene_update_driver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeFlowController:
	extends RefCounted

	var update_calls := 0

	func update(_delta: float, _deps: Dictionary, _callbacks: Dictionary) -> void:
		update_calls += 1


class FakeDepsBuilder:
	extends RefCounted

	var build_calls := 0

	func build_deps(_owner: Object, _registry: Object) -> Dictionary:
		build_calls += 1
		return {}


class FakeScoreboardDriver:
	extends RefCounted

	var dispatch_result := false
	var dispatch_calls := 0

	func dispatch_pending_scoreboard_result(_frame_callbacks: Dictionary, _perf_logger: Object = null) -> bool:
		dispatch_calls += 1
		return dispatch_result


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if typeof(value) == TYPE_OBJECT:
			return value as Object
		return null


func _init() -> void:
	_verify_pending_scoreboard_result_skips_normal_flow()
	_verify_empty_scoreboard_result_runs_normal_flow()

	if _failures.is_empty():
		print("battle_scene_update_driver_scoreboard_defer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pending_scoreboard_result_skips_normal_flow() -> void:
	var driver: Object = BattleSceneUpdateDriver.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var flow := FakeFlowController.new()
	var deps := FakeDepsBuilder.new()
	var scoreboard := FakeScoreboardDriver.new()
	scoreboard.dispatch_result = true
	registry.instances = {
		"battle_frame_flow_controller": flow,
		"battle_frame_flow_deps_builder": deps,
		"battle_scene_scoreboard_update_driver": scoreboard,
	}

	driver.update(owner, registry, 1.0 / 72.0)

	_expect(scoreboard.dispatch_calls == 1, "pending scoreboard result should dispatch once")
	_expect(flow.update_calls == 0, "pending scoreboard result should skip normal frame flow")
	_expect(deps.build_calls == 0, "pending scoreboard result should avoid building normal flow deps")


func _verify_empty_scoreboard_result_runs_normal_flow() -> void:
	var driver: Object = BattleSceneUpdateDriver.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var flow := FakeFlowController.new()
	var deps := FakeDepsBuilder.new()
	var scoreboard := FakeScoreboardDriver.new()
	registry.instances = {
		"battle_frame_flow_controller": flow,
		"battle_frame_flow_deps_builder": deps,
		"battle_scene_scoreboard_update_driver": scoreboard,
	}

	driver.update(owner, registry, 1.0 / 72.0)

	_expect(scoreboard.dispatch_calls == 1, "empty scoreboard result should still be checked")
	_expect(flow.update_calls == 1, "empty scoreboard result should run normal frame flow")
	_expect(deps.build_calls == 1, "empty scoreboard result should build normal flow deps")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
