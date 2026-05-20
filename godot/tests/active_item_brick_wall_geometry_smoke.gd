extends SceneTree

const ActiveItemBrickWallGeometry := preload("res://scripts/items/active_item_brick_wall_geometry.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 700.0)
	var player_paddle_width := 100.0


class FakeMythicRuntime:
	extends RefCounted

	func get_brick_wall_width(_base_width: float) -> float:
		return 120.0


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(initial_instances: Dictionary = {}) -> void:
		instances = initial_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_direct_geometry()
	_verify_controller_delegates_geometry()

	if _failures.is_empty():
		print("active_item_brick_wall_geometry_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_geometry() -> void:
	var geometry: Object = ActiveItemBrickWallGeometry.new()
	var owner := FakeOwner.new()

	var wall_rect: Rect2 = geometry.build_wall_rect(owner)
	_expect(wall_rect == Rect2(Vector2(110.0, 723.0), Vector2(80.0, 20.0)), "brick wall rect should center on the player paddle")
	_expect(geometry.get_gauge_center(owner, wall_rect) == Vector2(150.0, 670.0), "brick wall gauge center should track wall center and player height")

	var mythic_rect: Rect2 = geometry.build_wall_rect(owner, FakeMythicRuntime.new())
	_expect(mythic_rect == Rect2(Vector2(90.0, 723.0), Vector2(120.0, 20.0)), "brick wall rect should use mythic-adjusted width")

	owner.player_pos = Vector2(-80.0, 700.0)
	wall_rect = geometry.build_wall_rect(owner, FakeMythicRuntime.new())
	_expect(is_equal_approx(wall_rect.position.x, 0.0), "brick wall should clamp at the left edge")

	owner.player_pos = Vector2(740.0, 720.0)
	wall_rect = geometry.build_wall_rect(owner, FakeMythicRuntime.new())
	_expect(is_equal_approx(wall_rect.position.x, 640.0), "brick wall should clamp at the right edge")
	_expect(is_equal_approx(geometry.get_gauge_center(owner, wall_rect).y, 686.0), "brick wall gauge center should clamp near the bottom")


func _verify_controller_delegates_geometry() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"mythic_item_runtime": FakeMythicRuntime.new()})

	_expect(controller.activate_wall(owner, registry), "controller should activate brick wall installation")
	var pending_wall: Dictionary = controller.pending_brick_wall
	var wall_rect: Rect2 = pending_wall.get("rect", Rect2())
	_expect(wall_rect == Rect2(Vector2(90.0, 723.0), Vector2(120.0, 20.0)), "controller should delegate brick wall rect geometry")
	_expect(pending_wall.get("gauge_center", Vector2.ZERO) == Vector2(150.0, 670.0), "controller should delegate brick wall gauge center")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
