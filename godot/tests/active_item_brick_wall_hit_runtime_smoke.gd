extends SceneTree

const ActiveItemBrickWallHitRuntime := preload("res://scripts/items/active_item_brick_wall_hit_runtime.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_hit_runtime()
	_verify_invalid_hit_keeps_state()
	_verify_controller_delegates_hit_runtime()

	if _failures.is_empty():
		print("active_item_brick_wall_hit_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_hit_runtime() -> void:
	seed(33)
	var hit_runtime: Object = ActiveItemBrickWallHitRuntime.new()
	var walls: Array[Dictionary] = [_build_wall()]
	var particles: Array[Dictionary] = []

	var first_hit: Dictionary = hit_runtime.apply_hit(walls, particles, 0, Vector2(120.0, 710.0))
	_expect(not bool(first_hit.get("destroyed", true)), "first runtime hit should keep the wall")
	_expect(int(first_hit.get("hit_count", 0)) == 1, "first runtime hit should report hit count")
	_expect(walls.size() == 1, "first runtime hit should not remove wall")
	_expect(int(walls[0].get("crack_level", 0)) == 1, "first runtime hit should apply crack level")
	_expect(particles.size() == 12, "first runtime hit should spawn hit dust")

	var second_hit: Dictionary = hit_runtime.apply_hit(walls, particles, 0, Vector2(120.0, 710.0))
	_expect(bool(second_hit.get("destroyed", false)), "second runtime hit should destroy the wall")
	_expect(int(second_hit.get("hit_count", 0)) == 2, "second runtime hit should report hit count")
	_expect(walls.is_empty(), "second runtime hit should remove wall")
	_expect(particles.size() > 12, "destroyed runtime hit should add destruction particles")
	_expect(particles.size() <= 64, "destroyed runtime hit should respect particle cap")
	_expect(_has_particle_kind(particles, "brick"), "destroyed runtime hit should include brick fragments")


func _verify_invalid_hit_keeps_state() -> void:
	var hit_runtime: Object = ActiveItemBrickWallHitRuntime.new()
	var walls: Array[Dictionary] = [_build_wall()]
	var particles: Array[Dictionary] = []

	var invalid: Dictionary = hit_runtime.apply_hit(walls, particles, -1, Vector2(120.0, 710.0))
	_expect(not bool(invalid.get("destroyed", true)), "invalid runtime hit should not destroy")
	_expect(walls.size() == 1, "invalid runtime hit should keep wall list")
	_expect(int(walls[0].get("hit_count", 0)) == 0, "invalid runtime hit should not mutate hit count")
	_expect(particles.is_empty(), "invalid runtime hit should not spawn particles")


func _verify_controller_delegates_hit_runtime() -> void:
	seed(44)
	var controller: Object = ActiveItemEffectController.new()
	var walls: Array[Dictionary] = [_build_wall()]
	controller.brick_walls = walls

	var first_result: Dictionary = controller.notify_brick_wall_hit(0, Vector2(120.0, 710.0))
	_expect(not bool(first_result.get("destroyed", true)), "controller first runtime hit should keep wall")
	_expect(controller.brick_walls.size() == 1, "controller first runtime hit should retain wall")
	_expect(controller.brick_particles.size() == 12, "controller first runtime hit should spawn hit dust")

	var second_result: Dictionary = controller.notify_brick_wall_hit(0, Vector2(120.0, 710.0))
	_expect(bool(second_result.get("destroyed", false)), "controller second runtime hit should destroy wall")
	_expect(controller.brick_walls.is_empty(), "controller second runtime hit should remove wall")
	_expect(controller.brick_particles.size() > 12, "controller second runtime hit should spawn destruction particles")
	_expect(_has_particle_kind(controller.brick_particles, "brick"), "controller second runtime hit should include brick fragments")


func _build_wall() -> Dictionary:
	return {
		"rect": Rect2(Vector2(100.0, 700.0), Vector2(80.0, 20.0)),
		"hit_count": 0,
		"crack_level": 0,
	}


func _has_particle_kind(particles: Array[Dictionary], kind: String) -> bool:
	for particle in particles:
		if str(particle.get("kind", "")) == kind:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
