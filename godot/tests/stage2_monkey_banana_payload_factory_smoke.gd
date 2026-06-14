extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage2MonkeyBananaPayloadFactory := preload("res://scripts/stages/stage2/stage2_monkey_banana_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var trunk_points := [
		Vector2(10.0, 100.0),
		Vector2(20.0, 80.0),
		Vector2(30.0, 60.0),
		Vector2(40.0, 40.0),
		Vector2(50.0, 20.0),
		Vector2(60.0, 0.0),
	]
	var monkey: Dictionary = Stage2MonkeyBananaPayloadFactory.build_monkey(
		"left",
		trunk_points,
		1.5,
		3.0,
		rng
	)
	_expect(str(monkey.get("side", "")) == "left", "monkey payload should preserve side")
	_expect(str(monkey.get("state", "")) == "climbing", "monkey payload should start climbing")
	_expect(_as_vector2(monkey.get("position", Vector2.ZERO), Vector2.ZERO) == trunk_points[0], "monkey payload should start at the first trunk point")
	_expect(int(monkey.get("target_point_idx", -1)) == 0, "monkey payload should start from trunk point index 0")
	_expect(int(monkey.get("sit_point_idx", -1)) >= 2 and int(monkey.get("sit_point_idx", -1)) <= 4, "monkey sit point should stay in the authored middle-upper trunk range")
	_expect(float(monkey.get("throw_delay", 0.0)) >= 1.5 and float(monkey.get("throw_delay", 0.0)) <= 3.0, "monkey throw delay should stay inside the event's original range")
	_expect(bool(monkey.get("facing_right", false)), "left-tree monkey should face right toward the playfield")
	_expect(not bool(monkey.get("has_thrown", true)), "new monkey payload should not be marked thrown")

	var flying: Dictionary = Stage2MonkeyBananaPayloadFactory.build_flying_banana(
		Vector2(7.0, 9.0),
		Vector2(300.0, 700.0),
		true
	)
	_expect(str(flying.get("state", "")) == "flying", "banana payload should start in flying state")
	_expect(_as_vector2(flying.get("position", Vector2.ZERO), Vector2.ZERO) == Vector2(7.0, 9.0), "flying banana position should begin at launch")
	_expect(_as_vector2(flying.get("start", Vector2.ZERO), Vector2.ZERO) == Vector2(7.0, 9.0), "flying banana should keep the start point")
	_expect(_as_vector2(flying.get("target", Vector2.ZERO), Vector2.ZERO) == Vector2(300.0, 700.0), "flying banana should keep the target point")
	_expect(bool(flying.get("target_player", false)), "flying banana should preserve target owner")
	_expect(float(flying.get("flight_progress", -1.0)) == 0.0, "flying banana should start at zero flight progress")
	_expect(not bool(flying.get("slip_triggered", true)), "flying banana should not have player slip latched")
	_expect(not bool(flying.get("boss_slip_triggered", true)), "flying banana should not have boss slip latched")
	_expect(flying.get("particles", null) is Array and (flying.get("particles", []) as Array).is_empty(), "flying banana should start without burst particles")

	var landed: Dictionary = Stage2MonkeyBananaPayloadFactory.build_landed_banana(Vector2(50.0, 60.0), false)
	_expect(str(landed.get("state", "")) == "landed", "debug landed banana should use landed state")
	_expect(float(landed.get("flight_progress", 0.0)) == 1.0, "debug landed banana should be fully progressed")
	_expect(not bool(landed.get("target_player", true)), "debug landed banana should preserve boss targeting")
	_expect(_as_vector2(landed.get("position", Vector2.ZERO), Vector2.ZERO) == Vector2(50.0, 60.0), "debug landed banana should preserve position")

	var colors := [Color(1.0, 0.0, 0.0, 1.0), Color(1.0, 1.0, 0.0, 1.0)]
	var particles: Array = Stage2MonkeyBananaPayloadFactory.build_burst_particles(Vector2(5.0, 6.0), 16, colors, rng)
	_expect(particles.size() == 16, "banana burst factory should honor requested particle count")
	for particle_value in particles:
		_expect(particle_value is Dictionary, "banana burst particle should be a dictionary")
		var particle: Dictionary = particle_value
		_expect(_as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) == Vector2(5.0, 6.0), "burst particle should start at the banana origin")
		_expect(particle.get("vel", null) is Vector2, "burst particle should expose a velocity vector")
		_expect(float(particle.get("size", 0.0)) >= 3.0 and float(particle.get("size", 0.0)) <= 8.0, "burst particle size should stay in the event's original range")
		_expect(colors.has(particle.get("color", Color.TRANSPARENT)), "burst particle color should come from the provided palette")
		_expect(float(particle.get("life", 0.0)) >= 0.2 and float(particle.get("life", 0.0)) <= 0.4, "burst particle life should stay in the original range")
		_expect(float(particle.get("max_life", 0.0)) == 0.4, "burst particle should expose max_life for renderer alpha")
		_expect(float(particle.get("rotation_degrees", -1.0)) >= 0.0 and float(particle.get("rotation_degrees", -1.0)) <= 360.0, "burst particle rotation should start inside a full turn")
		_expect(float(particle.get("rot_speed", 0.0)) >= -500.0 and float(particle.get("rot_speed", 0.0)) <= 500.0, "burst particle spin should stay in the original range")

	var fallback_particles: Array = Stage2MonkeyBananaPayloadFactory.build_burst_particles(Vector2.ZERO, 1, [], rng)
	_expect(fallback_particles.size() == 1, "banana burst factory should tolerate an empty color palette")
	_expect(fallback_particles[0].get("color", null) is Color, "empty-palette burst particle should still receive a visible fallback color")
	_expect(Stage2MonkeyBananaPayloadFactory.build_burst_particles(Vector2.ZERO, -2, colors, rng).is_empty(), "negative burst count should produce no particles")

	var event_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_monkey_banana_event.gd")
	_expect(event_source.contains("Stage2MonkeyBananaPayloadFactory.build_monkey"), "Stage 2 monkey event should delegate monkey payload construction")
	_expect(event_source.contains("Stage2MonkeyBananaPayloadFactory.build_flying_banana"), "Stage 2 monkey event should delegate flying banana payload construction")
	_expect(event_source.contains("Stage2MonkeyBananaPayloadFactory.build_landed_banana"), "Stage 2 monkey event should delegate debug landed banana payload construction")
	_expect(event_source.contains("Stage2MonkeyBananaPayloadFactory.build_burst_particles"), "Stage 2 monkey event should delegate burst particle payload construction")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("stage2_monkey_banana_payload_factory"), "stage module catalog should list the Stage 2 monkey-banana payload factory")

	if _failures.is_empty():
		print("stage2_monkey_banana_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
