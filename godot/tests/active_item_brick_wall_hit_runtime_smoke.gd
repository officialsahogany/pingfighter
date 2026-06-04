extends SceneTree

const ActiveItemBrickWallHitRuntime := preload("res://scripts/items/active_item_brick_wall_hit_runtime.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")

var _failures: Array[String] = []


class FakeBrickMotionStepper:
	extends RefCounted

	var response: Dictionary = {}

	func _init(p_response: Dictionary) -> void:
		response = p_response

	func step(_ball_pos: Vector2, _step_vel: Vector2, _ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		return response.duplicate(true)


class FakeBrickActiveItemRuntime:
	extends RefCounted

	var hit_result: Dictionary = {}

	func _init(p_hit_result: Dictionary) -> void:
		hit_result = p_hit_result

	func get_ball_collision_context() -> Dictionary:
		return {}

	func notify_brick_wall_hit(_wall_index: int, _impact_pos: Vector2) -> Dictionary:
		return hit_result.duplicate(true)


class FakeBrickAudio:
	extends RefCounted

	var wall_hit_count := 0
	var brick_destroy_count := 0

	func play_wall_hit(_impact_speed: float) -> void:
		wall_hit_count += 1

	func play_brick_wall_destroy() -> void:
		brick_destroy_count += 1


func _init() -> void:
	_verify_direct_hit_runtime()
	_verify_invalid_hit_keeps_state()
	_verify_controller_delegates_hit_runtime()
	_verify_brick_wall_audio_routing()

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
	_expect(int(walls[0].get("crack_seed", 0)) > 0, "first runtime hit should assign a crack seed")
	var first_origin: Vector2 = _get_vector2(walls[0], "crack_origin_ratio", Vector2.ZERO)
	_expect(is_equal_approx(first_origin.x, 0.25) and is_equal_approx(first_origin.y, 0.5), "first runtime hit should anchor cracks near impact")
	_expect(particles.size() == 12, "first runtime hit should spawn hit dust")

	var second_hit: Dictionary = hit_runtime.apply_hit(walls, particles, 0, Vector2(120.0, 710.0))
	_expect(bool(second_hit.get("destroyed", false)), "second runtime hit should destroy the wall")
	_expect(int(second_hit.get("hit_count", 0)) == 2, "second runtime hit should report hit count")
	_expect(walls.is_empty(), "second runtime hit should remove wall")
	_expect(particles.size() > 12, "destroyed runtime hit should add destruction particles")
	_expect(particles.size() <= 64, "destroyed runtime hit should respect particle cap")
	_expect(_has_particle_kind(particles, "brick"), "destroyed runtime hit should include brick fragments")
	_verify_crack_payload_randomizes_between_hits()


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
	_expect(int(controller.brick_walls[0].get("crack_seed", 0)) > 0, "controller first runtime hit should assign a crack seed")
	_expect(controller.brick_particles.size() == 12, "controller first runtime hit should spawn hit dust")

	var second_result: Dictionary = controller.notify_brick_wall_hit(0, Vector2(120.0, 710.0))
	_expect(bool(second_result.get("destroyed", false)), "controller second runtime hit should destroy wall")
	_expect(controller.brick_walls.is_empty(), "controller second runtime hit should remove wall")
	_expect(controller.brick_particles.size() > 12, "controller second runtime hit should spawn destruction particles")
	_expect(_has_particle_kind(controller.brick_particles, "brick"), "controller second runtime hit should include brick fragments")


func _verify_brick_wall_audio_routing() -> void:
	_expect(GameAudio.BRICK_WALL_DESTROY_SOUND_PATH == "res://assets/sounds/stonebreak2.wav", "Brick Wall destroy should use the legacy BRICK_DESTROY stonebreak2 cue")
	var first_hit_audio: Object = _run_brick_wall_motion_event({"destroyed": false, "hit_count": 1})
	_expect(first_hit_audio.wall_hit_count == 1, "first Brick Wall hit should keep the wall-hit cue")
	_expect(first_hit_audio.brick_destroy_count == 0, "first Brick Wall hit should not play destroy cue")

	var destroyed_hit_audio: Object = _run_brick_wall_motion_event({"destroyed": true, "hit_count": 2})
	_expect(destroyed_hit_audio.wall_hit_count == 0, "destroyed Brick Wall hit should not fall back to wall-hit cue")
	_expect(destroyed_hit_audio.brick_destroy_count == 1, "destroyed Brick Wall hit should play the dedicated destroy cue")


func _run_brick_wall_motion_event(hit_result: Dictionary) -> Object:
	var processor: Object = BallMotionEventProcessor.new()
	var audio: Object = FakeBrickAudio.new()
	var scene: Dictionary = {
		"ball_pos": Vector2(120.0, 710.0),
		"ball_vel": Vector2(4.0, 12.0),
		"ball_impact_boost": 1.0,
	}
	var context: Dictionary = {
		"width": 760.0,
		"height": 750.0,
		"ball_size": 28.6,
	}
	var deps: Dictionary = {
		"motion_stepper": FakeBrickMotionStepper.new({
			"event": "brick_wall",
			"wall_index": 0,
			"impact_pos": Vector2(120.0, 710.0),
			"ball_pos": Vector2(120.0, 706.0),
		}),
		"active_item_runtime": FakeBrickActiveItemRuntime.new(hit_result),
		"audio": audio,
	}
	processor.step_motion(scene, 1.0, context, deps, {})
	return audio


func _build_wall() -> Dictionary:
	return {
		"rect": Rect2(Vector2(100.0, 700.0), Vector2(80.0, 20.0)),
		"hit_count": 0,
		"crack_level": 0,
	}


func _verify_crack_payload_randomizes_between_hits() -> void:
	seed(77)
	var hit_runtime: Object = ActiveItemBrickWallHitRuntime.new()
	var walls: Array[Dictionary] = [_build_wall(), _build_wall()]
	var particles: Array[Dictionary] = []
	hit_runtime.apply_hit(walls, particles, 0, Vector2(120.0, 710.0))
	hit_runtime.apply_hit(walls, particles, 1, Vector2(120.0, 710.0))
	_expect(int(walls[0].get("crack_seed", 0)) != int(walls[1].get("crack_seed", 0)), "separate brick hits should randomize crack seeds")


func _has_particle_kind(particles: Array[Dictionary], kind: String) -> bool:
	for particle in particles:
		if str(particle.get("kind", "")) == kind:
			return true
	return false


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
