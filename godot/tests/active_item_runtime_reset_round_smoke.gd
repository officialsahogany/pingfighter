extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")


class FakeThrowController:
	extends RefCounted

	var clear_calls := 0

	func clear_round_boss_status_effects() -> void:
		clear_calls += 1


class FakeRenderFacade:
	extends RefCounted

	var deactivate_calls := 0

	func deactivate_all_hosts() -> void:
		deactivate_calls += 1


class FakeLifecycleFacade:
	extends RefCounted

	var reset_calls := 0
	var stage_transition_calls := 0

	func reset(_runtime: Object) -> void:
		reset_calls += 1

	func reset_for_stage_transition(_runtime: Object, _owner: Object, _registry: Object = null) -> void:
		stage_transition_calls += 1


var _failures: Array[String] = []


func _init() -> void:
	_verify_reset_round_clears_throw_status_effects()
	_verify_full_reset_deactivates_render_hosts()
	_verify_stage_transition_reset_deactivates_render_hosts()

	if _failures.is_empty():
		print("active_item_runtime_reset_round_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_reset_round_clears_throw_status_effects() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var throw_controller := FakeThrowController.new()
	var render_facade := FakeRenderFacade.new()
	runtime.throw_controller = throw_controller
	runtime.render_facade = render_facade

	runtime.reset_round()
	_expect(throw_controller.clear_calls == 1, "active item reset_round should clear round boss status effects")
	_expect(render_facade.deactivate_calls == 1, "active item reset_round should deactivate detached render hosts")

	runtime.throw_controller = RefCounted.new()
	runtime.render_facade = RefCounted.new()
	runtime.reset_round()


func _verify_full_reset_deactivates_render_hosts() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var lifecycle_facade := FakeLifecycleFacade.new()
	var render_facade := FakeRenderFacade.new()
	runtime.lifecycle_facade = lifecycle_facade
	runtime.render_facade = render_facade

	runtime.reset()
	_expect(lifecycle_facade.reset_calls == 1, "active item full reset should still route through lifecycle facade")
	_expect(render_facade.deactivate_calls == 1, "active item full reset should deactivate detached render hosts")


func _verify_stage_transition_reset_deactivates_render_hosts() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var lifecycle_facade := FakeLifecycleFacade.new()
	var render_facade := FakeRenderFacade.new()
	runtime.lifecycle_facade = lifecycle_facade
	runtime.render_facade = render_facade

	runtime.reset_for_stage_transition()
	_expect(lifecycle_facade.stage_transition_calls == 1, "active item stage reset should still route through lifecycle facade")
	_expect(render_facade.deactivate_calls == 1, "active item stage reset should deactivate detached render hosts")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
