extends SceneTree

const MatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")

var _failures: Array[String] = []
var _drive_reset_calls := 0
var _ball_reset_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 7
	var applied_marker := false


class FakeContextBuilder:
	extends RefCounted

	var requested_stage := 0

	func build_match_flow_deps(_registry: Object, current_stage: int = 1) -> Dictionary:
		requested_stage = current_stage
		return {"current_stage": current_stage}


class FakeController:
	extends RefCounted

	var reset_calls := 0

	func reset_game(deps: Dictionary, callbacks: Dictionary) -> Dictionary:
		reset_calls += 1
		var reset_drive_input_callback: Callable = callbacks.get("reset_drive_input", Callable())
		if reset_drive_input_callback.is_valid():
			reset_drive_input_callback.call()
		var reset_ball_callback: Callable = callbacks.get("reset_ball", Callable())
		if reset_ball_callback.is_valid():
			reset_ball_callback.call()
		return {
			"result_marker": true,
			"current_stage": deps.get("current_stage", 0),
		}


class FakeApplier:
	extends RefCounted

	var calls := 0
	var applied_stage := 0

	func apply_reset_result(owner: Object, result: Dictionary) -> void:
		calls += 1
		applied_stage = int(result.get("current_stage", 0))
		owner.set("applied_marker", bool(result.get("result_marker", false)))


class FakeRegistry:
	extends RefCounted

	var context_builder: Object
	var controller: Object
	var applier: Object

	func _init(next_context_builder: Object, next_controller: Object, next_applier: Object) -> void:
		context_builder = next_context_builder
		controller = next_controller
		applier = next_applier

	func get_instance(key: String) -> Object:
		match key:
			"battle_update_context":
				return context_builder
			"match_flow_controller":
				return controller
			"battle_scene_match_reset_result_applier":
				return applier
			_:
				return null


func _init() -> void:
	var owner := FakeOwner.new()
	var context_builder := FakeContextBuilder.new()
	var controller := FakeController.new()
	var applier := FakeApplier.new()
	var registry := FakeRegistry.new(context_builder, controller, applier)
	var driver: Object = MatchFlowDriver.new()

	driver.reset_game(
		owner,
		registry,
		Callable(self, "_record_drive_reset"),
		Callable(self, "_record_ball_reset")
	)

	_expect(controller.reset_calls == 1, "reset game should call match flow controller")
	_expect(context_builder.requested_stage == 7, "reset deps should use owner current stage")
	_expect(_drive_reset_calls == 1 and _ball_reset_calls == 1, "reset callbacks should be forwarded")
	_expect(applier.calls == 1 and applier.applied_stage == 7, "registered reset-result applier should be used")
	_expect(owner.applied_marker, "registered applier should mutate owner from reset result")

	if _failures.is_empty():
		print("match_flow_driver_applier_deps_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _record_drive_reset() -> void:
	_drive_reset_calls += 1


func _record_ball_reset() -> void:
	_ball_reset_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
