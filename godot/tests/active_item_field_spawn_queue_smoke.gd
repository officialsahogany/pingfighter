extends SceneTree

const ActiveItemFieldItemMotion := preload("res://scripts/items/active_item_field_item_motion.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemFieldSpawnPortals := preload("res://scripts/items/active_item_field_spawn_portals.gd")
const ActiveItemFieldSpawnQueue := preload("res://scripts/items/active_item_field_spawn_queue.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var lucky_spawn_count := 0

	func play_lucky_coin_spawn() -> void:
		lucky_spawn_count += 1


class FakeLuckyCoinRuntime:
	extends RefCounted

	func should_lucky_coin_double_spawn() -> bool:
		return true


class FakeRegistry:
	extends RefCounted

	var mythic_runtime := FakeLuckyCoinRuntime.new()
	var audio := FakeAudio.new()

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_runtime
		if key == "game_audio":
			return audio
		return null


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	_verify_regular_queue_with_lucky_bonus()
	_verify_dimension_queue_with_lucky_bonus()
	_verify_controller_legacy_queue_call_delegates()
	_verify_queue_perf_labels()

	if _failures.is_empty():
		print("active_item_field_spawn_queue_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_regular_queue_with_lucky_bonus() -> void:
	var queue: Object = ActiveItemFieldSpawnQueue.new()
	var pool: Object = ActiveItemFieldSpawnPool.new()
	var motion: Object = ActiveItemFieldItemMotion.new()
	var portals: Object = ActiveItemFieldSpawnPortals.new()
	var registry := FakeRegistry.new()

	_expect(queue.queue_item_after_portal(null, registry, pool, motion, portals), "queue builder should queue a regular field item")
	_expect(portals.get_pending_spawn_items().size() == 2, "regular queue should include main item plus Lucky Coin bonus")
	_expect(portals.get_item_spawn_portals().size() == 2, "regular queue should create a portal for main and bonus items")
	_expect(registry.audio.lucky_spawn_count == 1, "regular queue should play Lucky Coin bonus audio")
	var bonus_item: Dictionary = _find_lucky_bonus_pending_item(portals.get_pending_spawn_items())
	_expect(not bonus_item.is_empty(), "regular queue should mark a Lucky Coin bonus field item")
	var bonus_data: Dictionary = _get_dictionary(bonus_item, "item_data")
	_expect(str(bonus_data.get("name", "")) != "lucky_coin", "regular queue Lucky Coin bonus should not recursively spawn Lucky Coin")


func _verify_dimension_queue_with_lucky_bonus() -> void:
	var queue: Object = ActiveItemFieldSpawnQueue.new()
	var pool: Object = ActiveItemFieldSpawnPool.new()
	var motion: Object = ActiveItemFieldItemMotion.new()
	var portals: Object = ActiveItemFieldSpawnPortals.new()
	var registry := FakeRegistry.new()

	_expect(queue.queue_dimension_gate_item(null, registry, pool, motion, portals), "queue builder should queue a dimension-gate item")
	_expect(portals.get_pending_spawn_items().size() == 2, "dimension queue should include main item plus Lucky Coin bonus")
	_expect(portals.get_item_spawn_portals().size() == 1, "dimension queue should create only the Lucky Coin bonus portal directly")
	var first_pending: Dictionary = _get_pending_field_item(portals.get_pending_spawn_items(), 0)
	_expect(_get_vector2(first_pending, "position") == portals.get_dimension_gate_center(), "dimension queue main item should spawn at the gate center")


func _verify_controller_legacy_queue_call_delegates() -> void:
	var controller: Object = ActiveItemFieldSpawnController.new()
	var registry := FakeRegistry.new()

	controller._queue_item_after_portal(registry)
	_expect(controller.get_pending_spawn_items().size() == 2, "controller legacy queue call should still include Lucky Coin bonus")
	_expect(controller.get_item_spawn_portals().size() == 2, "controller legacy queue call should still expose both portals")
	_expect(registry.audio.lucky_spawn_count == 1, "controller legacy queue call should still play Lucky Coin audio")


func _verify_queue_perf_labels() -> void:
	var queue: Object = ActiveItemFieldSpawnQueue.new()
	var pool: Object = ActiveItemFieldSpawnPool.new()
	var motion: Object = ActiveItemFieldItemMotion.new()
	var portals: Object = ActiveItemFieldSpawnPortals.new()
	var registry := FakeRegistry.new()
	var perf_logger := FakePerfLogger.new()

	_expect(
		queue.queue_item_after_portal(null, registry, pool, motion, portals, perf_logger),
		"perf-labelled queue should still create a regular field item"
	)
	_expect(
		perf_logger.labels.has("physics.callback.active_items.field_spawn.queue.regular.random_item"),
		"queue perf should label regular item selection"
	)
	_expect(
		perf_logger.labels.has("physics.callback.active_items.field_spawn.pool.random.candidates"),
		"queue perf should label random candidate construction"
	)
	_expect(
		perf_logger.labels.has("physics.callback.active_items.field_spawn.queue.regular.lucky_bonus"),
		"queue perf should label Lucky Coin bonus handling"
	)


func _find_lucky_bonus_pending_item(pending_items: Array) -> Dictionary:
	for pending_value in pending_items:
		var pending: Dictionary = pending_value if pending_value is Dictionary else {}
		var field_item: Dictionary = _get_dictionary(pending, "item")
		if bool(field_item.get("lucky_bonus", false)):
			return field_item
	return {}


func _get_pending_field_item(pending_items: Array, index: int) -> Dictionary:
	if index < 0 or index >= pending_items.size():
		return {}
	var pending: Dictionary = pending_items[index] if pending_items[index] is Dictionary else {}
	return _get_dictionary(pending, "item")


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
