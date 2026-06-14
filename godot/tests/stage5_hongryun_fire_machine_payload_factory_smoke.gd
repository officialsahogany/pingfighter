extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage5HongryunFireMachinePayloadFactory := preload("res://scripts/stages/stage5/stage5_hongryun_fire_machine_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 105

	var dragons: Array[Dictionary] = Stage5HongryunFireMachinePayloadFactory.build_dragons(2)
	_expect(dragons.size() == 2, "fire-machine payload factory should create two reusable dragon slots")
	_expect(float(dragons[0].get("base_angle_offset", 0.0)) < 0.0, "first dragon should keep the left angle offset")
	_expect(float(dragons[1].get("base_angle_offset", 0.0)) > 0.0, "second dragon should keep the right angle offset")
	for dragon in dragons:
		_expect(float(dragon.get("cannon_angle", -1.0)) == 0.0, "new dragon should start with neutral cannon angle")
		_expect(float(dragon.get("cannon_emergence", -1.0)) == 0.0, "new dragon should start hidden")
		_expect(str(dragon.get("jaw_phase", "")) == "closed", "new dragon jaw should start closed")
		_expect(not bool(dragon.get("fired", true)), "new dragon should not be marked fired")
		_expect(_as_vector2(dragon.get("aim_target", Vector2.INF), Vector2.INF) == Vector2.ZERO, "new dragon target should start at zero")

	var stream: Dictionary = Stage5HongryunFireMachinePayloadFactory.build_fire_stream(
		Vector2(10.0, 20.0),
		Vector2(70.0, 20.0),
		1.25,
		60.0
	)
	_expect(_as_vector2(stream.get("start", Vector2.ZERO), Vector2.ZERO) == Vector2(10.0, 20.0), "fire stream should preserve start")
	_expect(_as_vector2(stream.get("target", Vector2.ZERO), Vector2.ZERO) == Vector2(70.0, 20.0), "fire stream should preserve target")
	_expect(is_equal_approx(float(stream.get("angle", -1.0)), 0.0), "fire stream should aim along the start-to-target vector")
	_expect(is_equal_approx(float(stream.get("distance", 0.0)), 60.0), "fire stream should expose target distance for renderer width")
	_expect(float(stream.get("timer", -1.0)) == 0.0, "fire stream should start at timer zero")
	_expect(float(stream.get("duration", 0.0)) == 60.0, "fire stream should preserve duration")
	_expect(not bool(stream.get("completed", true)), "fire stream should start incomplete")
	_expect(stream.get("particles", null) is Array and (stream.get("particles", []) as Array).is_empty(), "fire stream should start without particles")

	var fallback_stream: Dictionary = Stage5HongryunFireMachinePayloadFactory.build_fire_stream(
		Vector2(10.0, 20.0),
		Vector2(10.0, 20.0),
		1.25,
		60.0
	)
	_expect(is_equal_approx(float(fallback_stream.get("angle", 0.0)), 1.25), "zero-length fire stream should keep the fallback angle")

	var stream_particle: Dictionary = Stage5HongryunFireMachinePayloadFactory.build_stream_particle(Vector2(100.0, 120.0), rng)
	_expect(_as_vector2(stream_particle.get("pos", Vector2.ZERO), Vector2.ZERO).distance_to(Vector2(100.0, 120.0)) <= 8.0, "stream particle should start near the stream head")
	_expect(stream_particle.get("vel", null) is Vector2, "stream particle should expose velocity")
	_expect(float(stream_particle.get("size", 0.0)) >= 6.0 and float(stream_particle.get("size", 0.0)) <= 12.0, "stream particle size should keep original range")
	_expect(float(stream_particle.get("life", 0.0)) == 30.0, "stream particle life should keep original duration")
	_expect(stream_particle.get("color", null) is Color, "stream particle should have a flame color")

	var zone: Dictionary = Stage5HongryunFireMachinePayloadFactory.build_fire_zone(
		Vector2(300.0, 700.0),
		80.0,
		32.0,
		150.0,
		15,
		rng
	)
	_expect(_as_vector2(zone.get("pos", Vector2.ZERO), Vector2.ZERO) == Vector2(300.0, 700.0), "fire zone should preserve position")
	_expect(float(zone.get("width", 0.0)) == 80.0, "fire zone should preserve width")
	_expect(float(zone.get("height", 0.0)) == 32.0, "fire zone should preserve height")
	_expect(float(zone.get("duration", 0.0)) == 150.0, "fire zone should preserve duration")
	_expect(float(zone.get("spread_timer", -1.0)) == 0.0, "fire zone should start with zero spread timer")
	var zone_flames: Array = zone.get("flames", [])
	_expect(zone_flames.size() == 15, "fire zone should seed the original initial flame count")
	for flame_value in zone_flames:
		_expect(flame_value is Dictionary, "seeded flame should be a dictionary")
		_verify_flame(flame_value, Vector2(300.0, 700.0), 80.0, 32.0, true)

	var spread_flame: Dictionary = Stage5HongryunFireMachinePayloadFactory.build_flame(Vector2(300.0, 700.0), 80.0, 32.0, false, rng)
	_verify_flame(spread_flame, Vector2(300.0, 700.0), 80.0, 32.0, false)

	var smoke_particles: Array[Dictionary] = Stage5HongryunFireMachinePayloadFactory.build_smoke_particles(
		Vector2(300.0, 700.0),
		80.0,
		32.0,
		24,
		rng
	)
	_expect(smoke_particles.size() == 24, "smoke factory should honor requested particle count")
	for smoke in smoke_particles:
		var smoke_pos: Vector2 = _as_vector2(smoke.get("pos", Vector2.INF), Vector2.INF)
		_expect(abs(smoke_pos.x - 300.0) <= 36.0 and abs(smoke_pos.y - 700.0) <= 14.4, "smoke particle should start inside the extinguished zone footprint")
		_expect(smoke.get("vel", null) is Vector2, "smoke particle should expose velocity")
		_expect(float(smoke.get("size", 0.0)) >= 8.0 and float(smoke.get("size", 0.0)) <= 14.0, "smoke particle size should keep original range")
		_expect(float(smoke.get("max_size", 0.0)) >= 28.0 and float(smoke.get("max_size", 0.0)) <= 46.0, "smoke particle max size should keep original range")
		_expect(float(smoke.get("life", 0.0)) >= 80.0 and float(smoke.get("life", 0.0)) <= 140.0, "smoke particle life should keep original range")
		_expect(is_equal_approx(float(smoke.get("max_life", -1.0)), float(smoke.get("life", 0.0))), "smoke particle should start with max_life equal to life")
		_expect(float(smoke.get("alpha", -1.0)) == 0.0, "smoke particle should fade in from zero alpha")
		_expect(float(smoke.get("warmth", 0.0)) >= 0.3 and float(smoke.get("warmth", 0.0)) <= 0.9, "smoke warmth should keep original range")
		_expect(float(smoke.get("wobble_freq", 0.0)) >= 0.04 and float(smoke.get("wobble_freq", 0.0)) <= 0.09, "smoke wobble frequency should keep original range")
		_expect(float(smoke.get("wobble_amp", 0.0)) >= 0.4 and float(smoke.get("wobble_amp", 0.0)) <= 1.0, "smoke wobble amplitude should keep original range")
	_expect(Stage5HongryunFireMachinePayloadFactory.build_smoke_particles(Vector2.ZERO, 80.0, 32.0, -1, rng).is_empty(), "negative smoke count should produce no particles")

	var event_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_fire_machine_event.gd")
	_expect(event_source.contains("Stage5HongryunFireMachinePayloadFactory.build_dragons"), "Stage 5 fire-machine event should delegate dragon payload construction")
	_expect(event_source.contains("Stage5HongryunFireMachinePayloadFactory.build_fire_stream"), "Stage 5 fire-machine event should delegate fire stream payload construction")
	_expect(event_source.contains("Stage5HongryunFireMachinePayloadFactory.build_stream_particle"), "Stage 5 fire-machine event should delegate stream particle payload construction")
	_expect(event_source.contains("Stage5HongryunFireMachinePayloadFactory.build_fire_zone"), "Stage 5 fire-machine event should delegate fire zone payload construction")
	_expect(event_source.contains("Stage5HongryunFireMachinePayloadFactory.build_flame"), "Stage 5 fire-machine event should delegate flame payload construction")
	_expect(event_source.contains("Stage5HongryunFireMachinePayloadFactory.build_smoke_particles"), "Stage 5 fire-machine event should delegate smoke payload construction")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("stage5_hongryun_fire_machine_payload_factory"), "stage module catalog should list the Stage 5 fire-machine payload factory")

	if _failures.is_empty():
		print("stage5_hongryun_fire_machine_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_flame(flame_value: Variant, center: Vector2, width: float, height: float, initial: bool) -> void:
	var flame: Dictionary = flame_value
	var flame_pos: Vector2 = _as_vector2(flame.get("pos", Vector2.INF), Vector2.INF)
	_expect(abs(flame_pos.x - center.x) <= width * 0.5, "flame should stay inside zone width")
	_expect(abs(flame_pos.y - center.y) <= height * 0.5, "flame should stay inside zone height")
	var min_size := 8.0 if initial else 5.0
	var max_size := 20.0 if initial else 15.0
	var min_life := 20.0 if initial else 15.0
	var max_life := 40.0 if initial else 30.0
	_expect(float(flame.get("size", 0.0)) >= min_size and float(flame.get("size", 0.0)) <= max_size, "flame size should stay in the original range")
	_expect(float(flame.get("life", 0.0)) >= min_life and float(flame.get("life", 0.0)) <= max_life, "flame life should stay in the original range")
	_expect(float(flame.get("color_phase", -1.0)) >= 0.0 and float(flame.get("color_phase", -1.0)) < 1.0, "flame color phase should be normalized")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
