extends SceneTree

const Stage2AmbientVisualState := preload("res://scripts/stages/stage2/stage2_ambient_visual_state.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_falling_leaf_motion_and_compaction()
	_verify_firefly_wrap()
	_verify_leaf_particle_motion_and_compaction()
	_verify_background_delegates_ambient_visuals()

	if _failures.is_empty():
		print("stage2_ambient_visual_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_falling_leaf_motion_and_compaction() -> void:
	var leaves := [
		{"y": 10.0, "fall_speed": 0.5, "sway_offset": 0.0, "rotation": 0.0, "rot_speed": 0.1},
		{"y": 160.0, "fall_speed": 0.5, "sway_offset": 0.0, "rotation": 0.0, "rot_speed": 0.1},
	]
	Stage2AmbientVisualState.update_falling_leaves(leaves, 1.0, Vector2(200.0, 150.0))
	_expect(leaves.size() == 1, "ambient visual state should compact fallen leaves outside layout")
	var leaf: Dictionary = leaves[0]
	_expect(is_equal_approx(float(leaf.get("y", 0.0)), 40.0), "ambient visual state should advance leaf y")
	_expect(is_equal_approx(float(leaf.get("sway_offset", 0.0)), 1.5), "ambient visual state should advance leaf sway")
	_expect(is_equal_approx(float(leaf.get("rotation", 0.0)), 6.0), "ambient visual state should advance leaf rotation")


func _verify_firefly_wrap() -> void:
	var fireflies := [{
		"x": 130.0,
		"y": -40.0,
		"phase": 0.0,
		"speed": 0.0,
	}]
	Stage2AmbientVisualState.update_fireflies(fireflies, 1.0, Vector2(100.0, 80.0))
	var fly: Dictionary = fireflies[0]
	_expect(is_equal_approx(float(fly.get("x", 0.0)), -25.0), "ambient visual state should wrap fireflies on x bounds")
	_expect(is_equal_approx(float(fly.get("y", 0.0)), 105.0), "ambient visual state should wrap fireflies on y bounds")


func _verify_leaf_particle_motion_and_compaction() -> void:
	var particles := [
		{"life": 1.0, "pos": Vector2(5.0, 6.0), "vel": Vector2(10.0, 20.0), "rot": 0.0, "spin": 2.0},
		{"life": 0.05, "pos": Vector2.ZERO, "vel": Vector2.ZERO},
	]
	Stage2AmbientVisualState.update_leaf_particles(particles, 0.1)
	_expect(particles.size() == 1, "ambient visual state should compact expired leaf particles")
	var particle: Dictionary = particles[0]
	_expect(is_equal_approx(float(particle.get("life", 0.0)), 0.9), "ambient visual state should decrement leaf particle life")
	_expect(Vector2(particle.get("pos", Vector2.ZERO)).y > 6.0, "ambient visual state should advance leaf particle y")
	_expect(Vector2(particle.get("vel", Vector2.ZERO)).y > 20.0, "ambient visual state should apply leaf particle gravity")
	_expect(is_equal_approx(float(particle.get("rot", 0.0)), 0.2), "ambient visual state should advance leaf particle rotation")


func _verify_background_delegates_ambient_visuals() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2AmbientVisualState.update_falling_leaves") >= 0,
		"Stage 2 background source should delegate falling leaf state"
	)
	_expect(
		source.find("Stage2AmbientVisualState.update_fireflies") >= 0,
		"Stage 2 background source should delegate firefly state"
	)
	_expect(
		source.find("Stage2AmbientVisualState.update_leaf_particles") >= 0,
		"Stage 2 background source should delegate leaf particle state"
	)

	var background := Stage2PillarBackground.new()
	background.ambient_layout_size = Vector2(100.0, 80.0)
	background.falling_leaves = [{"y": 10.0, "fall_speed": 0.5, "sway_offset": 0.0, "rotation": 0.0, "rot_speed": 0.1}]
	background.fireflies = [{"x": 20.0, "y": 20.0, "phase": 0.0, "speed": 1.0}]
	background.leaf_particles = [{"life": 1.0, "pos": Vector2(5.0, 6.0), "vel": Vector2(10.0, 20.0)}]
	background.update(0.1, {}, {})
	_expect(background.falling_leaves.size() >= 1, "Stage 2 background should keep delegated live leaves")
	var leaf: Dictionary = background.falling_leaves[0]
	var fly: Dictionary = background.fireflies[0]
	var particle: Dictionary = background.leaf_particles[0]
	_expect(float(leaf.get("y", 0.0)) > 10.0, "Stage 2 background should use delegated leaf motion")
	_expect(float(fly.get("x", 0.0)) > 20.0, "Stage 2 background should use delegated firefly drift")
	_expect(float(particle.get("life", 0.0)) < 1.0, "Stage 2 background should use delegated leaf particle decay")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
