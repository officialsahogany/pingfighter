extends SceneTree

const Stage4DestructionWavePayloadFactory := preload("res://scripts/stages/stage4/stage4_destruction_wave_payload_factory.gd")
const Stage4TempleDestructionEvent := preload("res://scripts/stages/stage4/stage4_temple_destruction_event.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_wave_payload()
	_verify_particle_payloads()
	_verify_event_delegates_wave_payloads()

	if _failures.is_empty():
		print("stage4_destruction_wave_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_wave_payload() -> void:
	var wave: Dictionary = Stage4DestructionWavePayloadFactory.build_wave(
		Stage4TempleDestructionEvent.WAVE_START,
		Stage4TempleDestructionEvent.WAVE_TARGET,
		Stage4TempleDestructionEvent.WAVE_SPEED_PX_PER_SEC,
		Stage4TempleDestructionEvent.WAVE_MAX_LIFETIME_SEC
	)
	_expect(is_equal_approx(float(wave.get("start_x", 0.0)), Stage4TempleDestructionEvent.WAVE_START.x), "wave should preserve start x")
	_expect(is_equal_approx(float(wave.get("target_y", 0.0)), Stage4TempleDestructionEvent.WAVE_TARGET.y), "wave should preserve target y")
	_expect(float(wave.get("vx", 0.0)) < 0.0, "stage 4 destruction wave should travel left from the moon")
	_expect(float(wave.get("vy", 0.0)) > 0.0, "stage 4 destruction wave should travel downward toward the temple")
	_expect(is_equal_approx(float(wave.get("speed", 0.0)), Stage4TempleDestructionEvent.WAVE_SPEED_PX_PER_SEC / 60.0), "wave should preserve legacy per-frame speed field")
	_expect(is_equal_approx(float(wave.get("max_lifetime", 0.0)), Stage4TempleDestructionEvent.WAVE_MAX_LIFETIME_SEC), "wave should preserve max lifetime")
	_expect(_as_array(wave.get("trail", [])).is_empty(), "wave should start with empty trail payload")
	_expect(_as_array(wave.get("beam_particles", [])).is_empty(), "wave should start with empty beam payload")
	_expect(_as_array(wave.get("energy_rings", [])).is_empty(), "wave should start with empty ring payload")


func _verify_particle_payloads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5001
	var center := Vector2(300.0, 200.0)
	var trail: Array = Stage4DestructionWavePayloadFactory.build_trail_particles(center, 5, rng)
	_expect(trail.size() == 5, "trail factory should create requested particles")
	for particle_value in trail:
		var particle: Dictionary = particle_value if particle_value is Dictionary else {}
		_expect(float(particle.get("life", 0.0)) == 30.0, "trail particle should preserve life")
		_expect(float(particle.get("size", 0.0)) >= 5.0 and float(particle.get("size", 0.0)) <= 15.0, "trail particle size should stay in range")
		_expect(float(particle.get("x", 999.0)) >= center.x - 20.0 and float(particle.get("x", -999.0)) <= center.x + 20.0, "trail x should stay near center")

	var beams: Array = Stage4DestructionWavePayloadFactory.build_beam_particles(center, 1.25, 3, rng)
	_expect(beams.size() == 3, "beam factory should create requested particles")
	for beam_value in beams:
		var beam: Dictionary = beam_value if beam_value is Dictionary else {}
		_expect(float(beam.get("life", 0.0)) == 40.0, "beam particle should preserve life")
		_expect(float(beam.get("length", 0.0)) >= 20.0 and float(beam.get("length", 0.0)) <= 40.0, "beam length should stay in range")
		_expect(is_equal_approx(float(beam.get("angle", 0.0)), 1.25), "beam particle should preserve angle")

	var ring: Dictionary = Stage4DestructionWavePayloadFactory.build_energy_ring(center, 25.0)
	_expect(is_equal_approx(float(ring.get("x", 0.0)), center.x), "ring should preserve x")
	_expect(is_equal_approx(float(ring.get("max_radius", 0.0)), 50.0), "ring max radius should scale from wave radius")
	_expect(is_equal_approx(float(ring.get("opacity", 0.0)), 1.0), "ring should start opaque")
	_expect(Stage4DestructionWavePayloadFactory.build_trail_particles(center, -1, rng).is_empty(), "negative trail count should clamp empty")
	_expect(Stage4DestructionWavePayloadFactory.build_beam_particles(center, 0.0, -1, rng).is_empty(), "negative beam count should clamp empty")


func _verify_event_delegates_wave_payloads() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_temple_destruction_event.gd")
	_expect(source.find("Stage4DestructionWavePayloadFactory.build_wave") >= 0, "temple destruction event should delegate initial wave payload")
	_expect(source.find("Stage4DestructionWavePayloadFactory.build_trail_particles") >= 0, "temple destruction event should delegate trail payloads")
	_expect(source.find("Stage4DestructionWavePayloadFactory.build_beam_particles") >= 0, "temple destruction event should delegate beam payloads")
	_expect(source.find("Stage4DestructionWavePayloadFactory.build_energy_ring") >= 0, "temple destruction event should delegate ring payloads")

	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	_expect(catalog_source.find("stage4_destruction_wave_payload_factory") >= 0, "module catalog should expose Stage 4 destruction-wave payload factory")


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
