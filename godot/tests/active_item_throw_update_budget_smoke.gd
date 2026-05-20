extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


class CountingWindup:
	extends RefCounted

	var update_calls := 0

	func update_pending_throws(
		pending_throws: Array[Dictionary],
		_owner: Object,
		_registry: Object,
		_release_callback: Callable
	) -> Array[Dictionary]:
		update_calls += 1
		return pending_throws


func _init() -> void:
	_verify_idle_update_fast_path()
	_verify_status_timer_keeps_update_path()
	_verify_visible_throw_state_counts_as_work()

	if _failures.is_empty():
		print("active_item_throw_update_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_idle_update_fast_path() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var windup := CountingWindup.new()
	controller.throw_windup = windup

	_expect(not controller._has_runtime_update_work(), "fresh throw controller should report no runtime work")
	controller.update(FakeOwner.new(), FakeRegistry.new(), 1.0 / 60.0)
	_expect(windup.update_calls == 0, "idle throw update should skip per-item update fanout")


func _verify_status_timer_keeps_update_path() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var windup := CountingWindup.new()
	controller.throw_windup = windup
	controller.grenade_boss_stun_timer_frames = 4.0

	_expect(controller._has_runtime_update_work(), "active boss status timers should keep throw update live")
	controller.update(FakeOwner.new(), FakeRegistry.new(), 1.0 / 60.0)
	_expect(windup.update_calls == 1, "active status timers should still run the update fanout")
	_expect(controller.grenade_boss_stun_timer_frames < 4.0, "active boss status timer should keep ticking down")


func _verify_visible_throw_state_counts_as_work() -> void:
	var controller: Object = ActiveItemThrowController.new()
	_expect(not controller._has_runtime_update_work(), "controller should start idle before any visible throw state")
	controller.boomerang_particles.append({"age": 0.0, "lifetime": 0.5})
	_expect(controller._has_runtime_update_work(), "visible throw particles should keep throw update live")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
