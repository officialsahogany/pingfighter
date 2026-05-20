extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemRuntimeUpdateDriver := preload("res://scripts/items/active_item_runtime_update_driver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted

	var warp_gate_state := RefCounted.new()
	var mythic_item_runtime := RefCounted.new()

	func get_instance(key: String) -> Object:
		if key == "smasher_warp_gate_state":
			return warp_gate_state
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		return null


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakeEffectController:
	extends RefCounted

	var time_frozen := false
	var aipill_active := false
	var update_calls := 0
	var sync_calls := 0
	var saw_warp_gate_state: Object = null
	var saw_mythic_item_runtime: Object = null

	func update(_owner: Object, _delta: float, warp_gate_state: Object = null, mythic_item_runtime: Object = null) -> void:
		update_calls += 1
		saw_warp_gate_state = warp_gate_state
		saw_mythic_item_runtime = mythic_item_runtime

	func is_time_frozen() -> bool:
		return time_frozen

	func is_wall_installing() -> bool:
		return false

	func is_aipill_active() -> bool:
		return aipill_active

	func sync_long_boost_owner_state(_owner: Object, warp_gate_state: Object = null, mythic_item_runtime: Object = null) -> void:
		sync_calls += 1
		saw_warp_gate_state = warp_gate_state
		saw_mythic_item_runtime = mythic_item_runtime


class FakeFieldSpawnController:
	extends RefCounted

	var update_calls := 0
	var collect_callable_used := false
	var saw_perf_logger: Object = null

	func update(
		_owner: Object,
		_registry: Object,
		_delta: float,
		store_callback: Callable,
		pickup_callback: Callable,
		perf_logger: Object = null
	) -> void:
		update_calls += 1
		saw_perf_logger = perf_logger
		if store_callback.is_valid() and pickup_callback.is_valid():
			pass

	func collect_items_near(_center: Vector2, _radius: float) -> Array[Dictionary]:
		collect_callable_used = true
		return []


class FakeThrowController:
	extends RefCounted

	var update_calls := 0
	var locked := false

	func update(
		_owner: Object,
		_registry: Object,
		_delta: float,
		collect_items_callback: Callable = Callable(),
		_boomerang_return_callback: Callable = Callable()
	) -> void:
		update_calls += 1
		if collect_items_callback.is_valid():
			collect_items_callback.call(Vector2.ZERO, 1.0)

	func is_player_control_locked() -> bool:
		return locked


class FakeSlotController:
	extends RefCounted

	var update_calls := 0
	var last_input_locked := false

	func update(
		_owner: Object,
		_registry: Object,
		input_locked: bool,
		apply_item_effect_callback: Callable,
		pending_use_backup_callback: Callable = Callable()
	) -> Dictionary:
		update_calls += 1
		last_input_locked = input_locked
		return {
			"used_slot": 2 if apply_item_effect_callback.is_valid() and pending_use_backup_callback.is_valid() else -1,
		}


class FakePendingThrowRecovery:
	extends RefCounted

	var clear_calls := 0

	func clear_backup_if_released(_throw_controller: Object) -> void:
		clear_calls += 1


class FakeBoomerangReturnHandler:
	extends RefCounted

	func handle_return(_owner: Object, _result: Dictionary, _registry: Object) -> void:
		pass


class FakeRuntime:
	extends RefCounted

	var effect_controller := FakeEffectController.new()
	var field_spawn_controller := FakeFieldSpawnController.new()
	var throw_controller := FakeThrowController.new()
	var slot_controller := FakeSlotController.new()
	var pending_throw_recovery := FakePendingThrowRecovery.new()
	var boomerang_return_handler := FakeBoomerangReturnHandler.new()

	func is_player_control_locked() -> bool:
		return throw_controller.is_player_control_locked() or effect_controller.is_wall_installing()

	func is_aipill_active() -> bool:
		return effect_controller.is_aipill_active()


class FakeUpdateDriver:
	extends RefCounted

	var call_count := 0
	var callbacks_valid := false

	func apply_update(
		_runtime: Object,
		_owner: Object,
		_registry: Object,
		_delta: float,
		store_item_callback: Callable,
		pickup_callback: Callable,
		apply_item_effect_callback: Callable,
		pending_use_backup_callback: Callable
	) -> Dictionary:
		call_count += 1
		callbacks_valid = (
			store_item_callback.is_valid()
			and pickup_callback.is_valid()
			and apply_item_effect_callback.is_valid()
			and pending_use_backup_callback.is_valid()
		)
		return {"used_slot": 7}


func _init() -> void:
	_verify_update_driver_runs_normal_frame_lifecycle()
	_verify_update_driver_preserves_time_frozen_skip()
	_verify_runtime_update_delegates_to_driver()

	if _failures.is_empty():
		print("active_item_runtime_update_driver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_update_driver_runs_normal_frame_lifecycle() -> void:
	var driver: Object = ActiveItemRuntimeUpdateDriver.new()
	var runtime := FakeRuntime.new()
	var registry := FakeRegistry.new()
	var perf_logger := FakePerfLogger.new()

	var result: Dictionary = driver.apply_update(
		runtime,
		FakeOwner.new(),
		registry,
		1.0 / 60.0,
		Callable(self, "_store_item"),
		Callable(self, "_pickup_item"),
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use"),
		perf_logger
	)

	_expect(runtime.effect_controller.update_calls == 1, "update driver should update effects first")
	_expect(runtime.field_spawn_controller.update_calls == 1, "update driver should update field spawns when time is not frozen")
	_expect(runtime.field_spawn_controller.saw_perf_logger == perf_logger, "update driver should pass perf logger to field spawns")
	_expect(runtime.throw_controller.update_calls == 1, "update driver should update throws when time is not frozen")
	_expect(runtime.pending_throw_recovery.clear_calls == 1, "update driver should clear pending throw backup after throw update")
	_expect(runtime.slot_controller.update_calls == 1, "update driver should update slots")
	_expect(not runtime.slot_controller.last_input_locked, "normal update should keep slot input unlocked")
	_expect(runtime.effect_controller.sync_calls == 1, "update driver should sync owner paddle state after slots")
	_expect(runtime.field_spawn_controller.collect_callable_used, "update driver should pass field collection callback to throw update")
	_expect(result.get("used_slot", -1) == 2, "update driver should return slot update result")
	_expect(runtime.effect_controller.saw_warp_gate_state == registry.warp_gate_state, "update driver should pass warp gate state")
	_expect(runtime.effect_controller.saw_mythic_item_runtime == registry.mythic_item_runtime, "update driver should pass mythic runtime")
	_expect(perf_logger.labels.has("physics.callback.active_items.effect_controller"), "update driver should time active item effects")
	_expect(perf_logger.labels.has("physics.callback.active_items.field_spawn"), "update driver should time field spawns")
	_expect(perf_logger.labels.has("physics.callback.active_items.throws"), "update driver should time throw updates")
	_expect(perf_logger.labels.has("physics.callback.active_items.pending_throw_recovery"), "update driver should time pending throw recovery")
	_expect(perf_logger.labels.has("physics.callback.active_items.slots"), "update driver should time active item slot polling")
	_expect(perf_logger.labels.has("physics.callback.active_items.owner_sync"), "update driver should time owner sync")


func _verify_update_driver_preserves_time_frozen_skip() -> void:
	var driver: Object = ActiveItemRuntimeUpdateDriver.new()
	var runtime := FakeRuntime.new()
	runtime.effect_controller.time_frozen = true
	runtime.throw_controller.locked = true

	driver.apply_update(
		runtime,
		FakeOwner.new(),
		FakeRegistry.new(),
		1.0 / 60.0,
		Callable(self, "_store_item"),
		Callable(self, "_pickup_item"),
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use")
	)

	_expect(runtime.field_spawn_controller.update_calls == 0, "time freeze should skip field update")
	_expect(runtime.throw_controller.update_calls == 0, "time freeze should skip throw update")
	_expect(runtime.pending_throw_recovery.clear_calls == 0, "time freeze should skip pending backup clear")
	_expect(runtime.slot_controller.update_calls == 1, "time freeze should still update slots")
	_expect(runtime.slot_controller.last_input_locked, "pre-existing throw lock should lock slot input")
	_expect(runtime.effect_controller.sync_calls == 1, "time freeze should still sync owner paddle state")


func _verify_runtime_update_delegates_to_driver() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var fake_driver := FakeUpdateDriver.new()
	runtime.update_driver = fake_driver

	var result: Dictionary = runtime.update(FakeOwner.new(), FakeRegistry.new(), 1.0 / 60.0)

	_expect(fake_driver.call_count == 1, "runtime update should delegate to update driver")
	_expect(fake_driver.callbacks_valid, "runtime update should pass its internal callbacks to update driver")
	_expect(result.get("used_slot", -1) == 7, "runtime update should return delegated result")


func _store_item(_field_item: Dictionary, _active_item_slots: Array, _registry: Object, _owner: Object) -> bool:
	return true


func _pickup_item(_field_item: Dictionary, _registry: Object) -> void:
	pass


func _apply_item_effect(_item_data: Dictionary, _owner: Object, _registry: Object) -> bool:
	return true


func _backup_pending_use(_item_data: Dictionary, _slot_index: int, _owner: Object, _registry: Object) -> void:
	pass


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
