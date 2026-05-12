extends SceneTree

const ActiveItemFieldItemMotion := preload("res://scripts/items/active_item_field_item_motion.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var player_pos := Vector2(100.0, 100.0)
	var player_paddle_width := 50.0
	var player_paddle_height := 50.0


class FakeRegistry:
	extends RefCounted

	var mythic_runtime: Object

	func _init(runtime: Object = null) -> void:
		mythic_runtime = runtime

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_runtime
		return null


class FakeDowsingRuntime:
	extends RefCounted

	func get_dowsing_pendulum_context() -> Dictionary:
		return {
			"active": true,
			"range": 180.0,
			"force": 4.0,
			"max_speed": 12.0,
			"min_distance": 0.0,
		}


func _init() -> void:
	_verify_spawn_skip_and_bounce()
	_verify_max_bounce_culling()
	_verify_dowsing_attraction()
	_verify_collect_items_near()
	_verify_controller_delegates_motion()

	if _failures.is_empty():
		print("active_item_field_item_motion_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_spawn_skip_and_bounce() -> void:
	var motion: Object = ActiveItemFieldItemMotion.new()
	var player_rect := Rect2(Vector2(200.0, 200.0), Vector2(50.0, 50.0))
	var item: Dictionary = motion.build_field_item({"name": "banana"}, Vector2(16.0, 100.0))
	item["velocity"] = Vector2(-4.0, 0.0)
	item["max_bounces"] = 5

	var skipped: Dictionary = motion.advance_field_item(item, player_rect, {}, 1.0 / 60.0)
	_expect(bool(skipped.get("skipped", false)), "fresh field item should skip its first update")
	_expect(not bool(item.get("spawn_skip_update_once", true)), "first update should clear skip flag")

	var advanced: Dictionary = motion.advance_field_item(item, player_rect, {}, 1.0 / 60.0)
	_expect(not bool(advanced.get("skipped", true)), "second update should advance movement")
	_expect(is_equal_approx(_get_vector2(item, "position").x, 15.0), "field item should clamp at the left wall radius")
	_expect(_get_vector2(item, "velocity").x > 0.0, "field item should bounce X velocity at the wall")
	_expect(int(item.get("bounce_count", 0)) == 1, "field item should increment bounce count")
	_expect(bool(advanced.get("alive", false)), "field item should remain alive below max bounces")


func _verify_max_bounce_culling() -> void:
	var motion: Object = ActiveItemFieldItemMotion.new()
	var player_rect := Rect2(Vector2(300.0, 300.0), Vector2(50.0, 50.0))
	var item := {
		"item_data": {"name": "soap"},
		"position": Vector2(744.0, 100.0),
		"velocity": Vector2(4.0, 0.0),
		"bounce_count": 1,
		"max_bounces": 2,
		"angle_degrees": 0.0,
	}
	var advanced: Dictionary = motion.advance_field_item(item, player_rect, {}, 1.0 / 60.0)
	_expect(not bool(advanced.get("alive", true)), "field item should be culled when bounce count reaches max")


func _verify_dowsing_attraction() -> void:
	var motion: Object = ActiveItemFieldItemMotion.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(FakeDowsingRuntime.new())
	var player_rect: Rect2 = motion.get_player_rect(owner)
	var context: Dictionary = motion.get_dowsing_pendulum_context(registry)
	var item := {
		"item_data": {"name": "boomerang"},
		"position": Vector2(125.0, 220.0),
		"velocity": Vector2.ZERO,
		"bounce_count": 0,
		"max_bounces": 5,
		"angle_degrees": 0.0,
	}
	motion.advance_field_item(item, player_rect, context, 1.0 / 60.0)
	_expect(_get_vector2(item, "velocity").y < 0.0, "dowsing attraction should pull items toward the player center")


func _verify_collect_items_near() -> void:
	var motion: Object = ActiveItemFieldItemMotion.new()
	var items: Array[Dictionary] = [
		{"item_data": {"name": "banana"}, "position": Vector2(20.0, 20.0)},
		{"item_data": {"name": "soap"}, "position": Vector2(200.0, 200.0)},
	]
	var result: Dictionary = motion.collect_items_near(items, Vector2(25.0, 25.0), 20.0)
	_expect(_get_dictionary_array(result, "picked_items").size() == 1, "collect should pick near items")
	_expect(_get_dictionary_array(result, "survivors").size() == 1, "collect should preserve far items")


func _verify_controller_delegates_motion() -> void:
	var controller: Object = ActiveItemFieldSpawnController.new()
	var seeded_items: Array[Dictionary] = [
		{"item_data": {"name": "banana"}, "position": Vector2(10.0, 10.0)},
		{"item_data": {"name": "soap"}, "position": Vector2(300.0, 300.0)},
	]
	controller.spawned_items = seeded_items
	var picked_items: Array[Dictionary] = controller.collect_items_near(Vector2(10.0, 10.0), 5.0)
	_expect(picked_items.size() == 1, "controller should delegate near-item collection to motion helper")
	_expect(controller.get_spawned_items().size() == 1, "controller should keep collection survivors")
	var survivor_item_data: Dictionary = _get_dictionary(controller.get_spawned_items()[0], "item_data")
	_expect(str(survivor_item_data.get("name", "")) == "soap", "controller survivor should preserve item data")


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


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
