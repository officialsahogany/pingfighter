extends SceneTree

const ActiveItemFieldItemMotion := preload("res://scripts/items/active_item_field_item_motion.gd")
const ActiveItemFieldPickupFlow := preload("res://scripts/items/active_item_field_pickup_flow.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")

var _failures: Array[String] = []
var _pickup_count := 0
var _store_accept := true


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var player_pos := Vector2(100.0, 100.0)
	var player_paddle_width := 50.0
	var player_paddle_height := 50.0


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	_verify_pickup_flow_stores_and_writes_owner_slots()
	_verify_pickup_flow_keeps_item_when_store_rejects()
	_verify_pickup_flow_collects_near_items()
	_verify_controller_delegates_pickup_flow()
	_verify_pickup_flow_perf_labels()

	if _failures.is_empty():
		print("active_item_field_pickup_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pickup_flow_stores_and_writes_owner_slots() -> void:
	var flow: Object = ActiveItemFieldPickupFlow.new()
	var motion: Object = ActiveItemFieldItemMotion.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	_pickup_count = 0
	_store_accept = true
	var field_items: Array[Dictionary] = [_build_field_item("banana", Vector2(120.0, 120.0))]

	var survivors: Array[Dictionary] = flow.update_field_items(
		owner,
		registry,
		field_items,
		motion,
		1.0 / 60.0,
		Callable(self, "_store_field_item"),
		Callable(self, "_record_pickup")
	)

	_expect(survivors.is_empty(), "stored field pickup should be removed from spawned items")
	_expect(owner.active_item_slots.size() == 1, "stored field pickup should write owner active slots")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "banana", "stored field pickup should preserve item data")
	_expect(_pickup_count == 1, "stored field pickup should trigger pickup callback")


func _verify_pickup_flow_keeps_item_when_store_rejects() -> void:
	var flow: Object = ActiveItemFieldPickupFlow.new()
	var motion: Object = ActiveItemFieldItemMotion.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	_pickup_count = 0
	_store_accept = false
	var field_items: Array[Dictionary] = [_build_field_item("soap", Vector2(120.0, 120.0))]

	var survivors: Array[Dictionary] = flow.update_field_items(
		owner,
		registry,
		field_items,
		motion,
		1.0 / 60.0,
		Callable(self, "_store_field_item"),
		Callable(self, "_record_pickup")
	)

	_expect(survivors.size() == 1, "rejected pickup should stay in spawned items")
	_expect(owner.active_item_slots.is_empty(), "rejected pickup should not write owner active slots")
	_expect(_pickup_count == 0, "rejected pickup should not trigger pickup callback")


func _verify_pickup_flow_collects_near_items() -> void:
	var flow: Object = ActiveItemFieldPickupFlow.new()
	var motion: Object = ActiveItemFieldItemMotion.new()
	var field_items: Array[Dictionary] = [
		{"item_data": {"name": "banana"}, "position": Vector2(25.0, 25.0)},
		{"item_data": {"name": "soap"}, "position": Vector2(220.0, 220.0)},
	]
	var result: Dictionary = flow.collect_items_near(
		field_items,
		motion,
		Vector2(20.0, 20.0),
		10.0
	)

	_expect(_get_dictionary_array(result, "picked_items").size() == 1, "pickup flow should collect near items")
	_expect(_get_dictionary_array(result, "survivors").size() == 1, "pickup flow should return collection survivors")


func _verify_controller_delegates_pickup_flow() -> void:
	var controller: Object = ActiveItemFieldSpawnController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var field_items: Array[Dictionary] = [_build_field_item("gauge_charge", Vector2(120.0, 120.0))]
	controller.spawned_items = field_items
	_pickup_count = 0
	_store_accept = true

	controller._update_field_items(
		owner,
		registry,
		1.0 / 60.0,
		Callable(self, "_store_field_item"),
		Callable(self, "_record_pickup")
	)

	_expect(controller.get_spawned_items().is_empty(), "controller should delegate stored pickup removal")
	_expect(owner.active_item_slots.size() == 1, "controller delegated pickup should write owner slots")
	_expect(_pickup_count == 1, "controller delegated pickup should trigger pickup callback")


func _verify_pickup_flow_perf_labels() -> void:
	var flow: Object = ActiveItemFieldPickupFlow.new()
	var motion: Object = ActiveItemFieldItemMotion.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var perf_logger := FakePerfLogger.new()
	_pickup_count = 0
	_store_accept = true
	var field_items: Array[Dictionary] = [_build_field_item("banana", Vector2(120.0, 120.0))]

	var survivors: Array[Dictionary] = flow.update_field_items(
		owner,
		registry,
		field_items,
		motion,
		1.0 / 60.0,
		Callable(self, "_store_field_item"),
		Callable(self, "_record_pickup"),
		perf_logger
	)

	_expect(survivors.is_empty(), "perf-labelled pickup flow should still collect the item")
	_expect(perf_logger.labels.has("physics.callback.active_items.field_spawn.field_items.prepare"), "pickup flow perf should label prepare")
	_expect(perf_logger.labels.has("physics.callback.active_items.field_spawn.field_items.motion"), "pickup flow perf should label item motion")
	_expect(perf_logger.labels.has("physics.callback.active_items.field_spawn.field_items.store"), "pickup flow perf should label item storage")
	_expect(perf_logger.labels.has("physics.callback.active_items.field_spawn.field_items.pickup_feedback"), "pickup flow perf should label pickup feedback")
	_expect(perf_logger.labels.has("physics.callback.active_items.field_spawn.field_items.owner_slots"), "pickup flow perf should label owner slot writeback")


func _store_field_item(
	field_item: Dictionary,
	active_item_slots: Array,
	_registry: Object,
	_owner: Object
) -> bool:
	if not _store_accept:
		return false
	active_item_slots.append(_get_dictionary(field_item, "item_data"))
	return true


func _record_pickup(_field_item: Dictionary, _registry: Object) -> void:
	_pickup_count += 1


func _build_field_item(item_name: String, position: Vector2) -> Dictionary:
	return {
		"item_data": {"name": item_name},
		"position": position,
		"velocity": Vector2.ZERO,
		"bounce_count": 0,
		"max_bounces": 5,
		"angle_degrees": 0.0,
		"spawn_spark_timer": 0.0,
	}


func _get_dictionary_array(source: Dictionary, key: String) -> Array[Dictionary]:
	var value: Variant = source.get(key, [])
	var items: Array[Dictionary] = []
	if value is Array:
		for item_value in value:
			if item_value is Dictionary:
				items.append(item_value)
	return items


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
