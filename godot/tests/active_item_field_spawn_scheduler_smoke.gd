extends SceneTree

const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemFieldSpawnScheduler := preload("res://scripts/items/active_item_field_spawn_scheduler.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var arena_mode_enabled := false


class FakeRuntimePerkState:
	extends RefCounted

	var effective_delay_msec := 0

	func get_item_spawn_delay_msec(_base_delay_msec: int) -> int:
		return effective_delay_msec


class FakeRegistry:
	extends RefCounted

	var runtime_perk_state: Object

	func _init(perk_state: Object = null) -> void:
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


func _init() -> void:
	_verify_due_spawn_consumes_timer()
	_verify_busy_or_blocked_spawns_do_not_queue()
	_verify_effective_delay_override()
	_verify_controller_delegates_scheduler()

	if _failures.is_empty():
		print("active_item_field_spawn_scheduler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_due_spawn_consumes_timer() -> void:
	var scheduler: Object = ActiveItemFieldSpawnScheduler.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	scheduler.last_item_spawn_msec = _elapsed_timestamp(1000)
	scheduler.next_item_spawn_delay_msec = 1

	_expect(
		scheduler.consume_regular_spawn_due(owner, registry, false, false),
		"due scheduler should request a regular field spawn"
	)
	_expect(scheduler.last_item_spawn_msec > 0, "due scheduler should keep a current last-spawn timestamp")
	_expect(scheduler.next_item_spawn_delay_msec >= 20000, "due scheduler should roll the next spawn delay")


func _verify_busy_or_blocked_spawns_do_not_queue() -> void:
	var scheduler: Object = ActiveItemFieldSpawnScheduler.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	scheduler.last_item_spawn_msec = _elapsed_timestamp(1000)
	scheduler.next_item_spawn_delay_msec = 1
	_expect(not scheduler.consume_regular_spawn_due(owner, registry, true, false), "spawned field items should block new regular spawns")
	_expect(not scheduler.consume_regular_spawn_due(owner, registry, false, true), "pending items or portals should block new regular spawns")

	owner.current_stage = 50
	_expect(scheduler.is_item_spawn_blocked(owner), "stage 50 should block field item spawns")
	_expect(not scheduler.consume_regular_spawn_due(owner, registry, false, false), "blocked stage should not request field item spawns")

	owner.current_stage = 1
	owner.arena_mode_enabled = true
	_expect(scheduler.is_item_spawn_blocked(owner), "arena mode should block field item spawns")


func _verify_effective_delay_override() -> void:
	var perk_state := FakeRuntimePerkState.new()
	perk_state.effective_delay_msec = 2000
	var scheduler: Object = ActiveItemFieldSpawnScheduler.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(perk_state)

	scheduler.last_item_spawn_msec = _elapsed_timestamp(1000)
	scheduler.next_item_spawn_delay_msec = 1
	_expect(not scheduler.consume_regular_spawn_due(owner, registry, false, false), "effective delay override should hold early spawns")

	perk_state.effective_delay_msec = 1
	scheduler.last_item_spawn_msec = _elapsed_timestamp(1000)
	scheduler.next_item_spawn_delay_msec = 1
	_expect(scheduler.consume_regular_spawn_due(owner, registry, false, false), "effective delay override should allow elapsed spawns")


func _verify_controller_delegates_scheduler() -> void:
	var controller: Object = ActiveItemFieldSpawnController.new()
	controller.spawn_scheduler.last_item_spawn_msec = 0
	_expect(controller.debug_spawn_item("banana"), "debug spawn should still create a field item")
	_expect(controller.get_spawned_items().size() == 1, "debug spawn should append one field item")
	_expect(controller.spawn_scheduler.last_item_spawn_msec > 0, "debug spawn should mark the scheduler timer")

	controller.reset()
	controller.spawn_scheduler.last_item_spawn_msec = 0
	_expect(controller.activate_dimension_gate(), "dimension gate should still activate through the controller")
	_expect(controller.spawn_scheduler.last_item_spawn_msec > 0, "dimension gate activation should mark the scheduler timer")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _elapsed_timestamp(elapsed_msec: int) -> int:
	return max(1, Time.get_ticks_msec() - elapsed_msec)
