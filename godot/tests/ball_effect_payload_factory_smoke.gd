extends SceneTree

const BallEffectPayloadFactory := preload("res://scripts/ball/ball_effect_payload_factory.gd")
const BallEffects := preload("res://scripts/ball/ball_effects.gd")
const GameplayBallModuleCatalog := preload("res://scripts/resources/gameplay_ball_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")

const TEST_COLORS: Array[Color] = [Color(1.0, 0.4, 0.2), Color(0.4, 0.8, 1.0)]


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_factory_payloads()
	_verify_runtime_fanout()
	_verify_state_delegation_and_catalog()

	if _failures.is_empty():
		print("ball_effect_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_factory_payloads() -> void:
	var ghost: Dictionary = BallEffectPayloadFactory.build_ghost_trail_point(Vector2(1.0, 2.0), 0.25, 28.0)
	_expect(ghost.get("pos", Vector2.ZERO) == Vector2(1.0, 2.0), "ghost trail point should preserve position")
	_expect(is_equal_approx(float(ghost.get("alpha", 0.0)), 0.25), "ghost trail point should preserve alpha")
	_expect(is_equal_approx(float(ghost.get("size", 0.0)), 28.0), "ghost trail point should preserve size")
	_expect(is_equal_approx(float(ghost.get("age", -1.0)), 0.0), "ghost trail point should start with zero age")

	var trail: Dictionary = BallEffectPayloadFactory.build_intensity_trail_point(Vector2(3.0, 4.0), 0.8, 13.0, Color.RED)
	_expect(trail.get("pos", Vector2.ZERO) == Vector2(3.0, 4.0), "intensity trail point should preserve position")
	_expect(is_equal_approx(float(trail.get("alpha", 0.0)), 0.8), "intensity trail point should preserve alpha")
	_expect(is_equal_approx(float(trail.get("size", 0.0)), 13.0), "intensity trail point should preserve size")
	_expect(trail.get("color", Color.TRANSPARENT) == Color.RED, "intensity trail point should preserve color")

	var particle: Dictionary = BallEffectPayloadFactory.build_intensity_particle(Vector2(10.0, 20.0), Vector2(5.0, -7.0), 0.6, TEST_COLORS)
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	_expect(absf(pos.x - 10.0) <= 5.0 and absf(pos.y - 20.0) <= 5.0, "intensity particle should keep spawn jitter")
	_expect(float(particle.get("size", 0.0)) >= 3.0 * 0.8 and float(particle.get("size", 0.0)) <= 8.0 * 0.8, "intensity particle should keep scaled size range")
	_expect(is_equal_approx(float(particle.get("life", 0.0)), 30.0), "intensity particle should derive life from intensity")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 30.0), "intensity particle should mirror max life")
	_expect(_color_in(particle.get("color", Color.TRANSPARENT), TEST_COLORS), "intensity particle should use supplied palette")
	_expect(["flame", "spark"].has(str(particle.get("type", ""))), "intensity particle should keep known types")


func _verify_runtime_fanout() -> void:
	var effects: Object = BallEffects.new()
	effects.update_ghost_trail(Vector2(100.0, 100.0), 28.0, 1.0)
	effects.update_ghost_trail(Vector2(130.0, 100.0), 28.0, 1.0)
	_expect((effects.get_ghost_trail() as Array).size() >= 1, "ball effects should still build ghost trail points")
	effects.update_intensity_particles(Vector2(100.0, 100.0), Vector2(8.0, -6.0), 1.0, 0.8, TEST_COLORS, 1.0)
	effects.update_intensity_particles(Vector2(140.0, 100.0), Vector2(8.0, -6.0), 1.0, 0.8, TEST_COLORS, 1.0)
	_expect((effects.get_intensity_trail() as Array).size() >= 1, "ball effects should still build intensity trail points")
	for _i in range(80):
		effects.update_intensity_particles(Vector2(140.0, 100.0), Vector2(8.0, -6.0), 1.0, 0.8, TEST_COLORS, 1.0)
		if not (effects.get_intensity_particles() as Array).is_empty():
			break
	_expect(not (effects.get_intensity_particles() as Array).is_empty(), "ball effects should still build intensity particles")


func _verify_state_delegation_and_catalog() -> void:
	var ghost_source := FileAccess.get_file_as_string("res://scripts/ball/ball_ghost_trail_state.gd")
	var trail_source := FileAccess.get_file_as_string("res://scripts/ball/ball_intensity_trail_state.gd")
	var particle_source := FileAccess.get_file_as_string("res://scripts/ball/ball_intensity_particle_state.gd")
	_expect(ghost_source.find("BallEffectPayloadFactory.build_ghost_trail_point") >= 0, "ghost trail should delegate point payloads")
	_expect(trail_source.find("BallEffectPayloadFactory.build_intensity_trail_point") >= 0, "intensity trail should delegate point payloads")
	_expect(particle_source.find("BallEffectPayloadFactory.build_intensity_particle") >= 0, "intensity particles should delegate particle payloads")
	_expect(ghost_source.find("ghost_trail.append({") < 0, "ghost trail should not inline point dictionaries")
	_expect(trail_source.find("intensity_trail.append({") < 0, "intensity trail should not inline point dictionaries")
	_expect(particle_source.find("intensity_particles.append({") < 0, "intensity particles should not inline particle dictionaries")

	var ball_modules: Dictionary = GameplayBallModuleCatalog.MODULES
	_expect(ball_modules.has("ball_effect_payload_factory"), "ball module catalog should list the ball effect payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("ball_effect_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/ball/ball_effect_payload_factory.gd", "top-level module catalog should resolve the ball effect payload factory")


func _color_in(value: Variant, colors: Array[Color]) -> bool:
	if not (value is Color):
		return false
	for color in colors:
		if (value as Color).is_equal_approx(color):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
