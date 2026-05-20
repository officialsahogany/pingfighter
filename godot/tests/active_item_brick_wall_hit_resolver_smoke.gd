extends SceneTree

const ActiveItemBrickWallHitResolver := preload("res://scripts/items/active_item_brick_wall_hit_resolver.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_hit_resolution()
	_verify_controller_delegates_hit_resolution()

	if _failures.is_empty():
		print("active_item_brick_wall_hit_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_hit_resolution() -> void:
	var resolver: Object = ActiveItemBrickWallHitResolver.new()
	var walls: Array[Dictionary] = [{
		"rect": Rect2(Vector2(10.0, 20.0), Vector2(80.0, 20.0)),
		"hit_count": 0,
		"crack_level": 0,
	}]

	var invalid: Dictionary = resolver.resolve_hit(walls, -1)
	_expect(not bool(invalid.get("valid", true)), "invalid brick wall hit should be marked invalid")
	_expect(not bool(invalid.get("destroyed", true)), "invalid brick wall hit should not destroy")

	var first_hit: Dictionary = resolver.resolve_hit(walls, 0)
	_expect(bool(first_hit.get("valid", false)), "valid brick wall hit should resolve")
	_expect(not bool(first_hit.get("destroyed", true)), "first brick wall hit should not destroy")
	_expect(int(first_hit.get("hit_count", 0)) == 1, "first brick wall hit should increment hit count")
	var updated_wall: Dictionary = first_hit.get("updated_wall", {})
	_expect(int(updated_wall.get("crack_level", 0)) == 1, "first brick wall hit should advance crack level")
	_expect(first_hit.get("wall_rect", Rect2()) == Rect2(Vector2(10.0, 20.0), Vector2(80.0, 20.0)), "brick wall hit should expose wall rect")

	walls[0] = updated_wall
	var second_hit: Dictionary = resolver.resolve_hit(walls, 0)
	_expect(bool(second_hit.get("destroyed", false)), "second brick wall hit should destroy with default threshold")
	_expect(int(second_hit.get("hit_count", 0)) == 2, "second brick wall hit should report hit count")


func _verify_controller_delegates_hit_resolution() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var walls: Array[Dictionary] = [{
		"rect": Rect2(Vector2(100.0, 700.0), Vector2(80.0, 20.0)),
		"hit_count": 0,
		"crack_level": 0,
	}]
	controller.brick_walls = walls

	var first_result: Dictionary = controller.notify_brick_wall_hit(0, Vector2(120.0, 710.0))
	_expect(not bool(first_result.get("destroyed", true)), "controller first brick wall hit should not destroy")
	_expect(int(first_result.get("hit_count", 0)) == 1, "controller first brick wall hit should report hit count")
	_expect(controller.brick_walls.size() == 1, "controller should keep wall after first hit")
	_expect(int(controller.brick_walls[0].get("crack_level", 0)) == 1, "controller should apply updated crack level")

	var second_result: Dictionary = controller.notify_brick_wall_hit(0, Vector2(120.0, 710.0))
	_expect(bool(second_result.get("destroyed", false)), "controller second brick wall hit should destroy")
	_expect(int(second_result.get("hit_count", 0)) == 2, "controller second brick wall hit should report hit count")
	_expect(controller.brick_walls.is_empty(), "controller should remove destroyed wall")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
