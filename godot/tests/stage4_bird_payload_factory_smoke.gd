extends SceneTree

const Stage4BirdPayloadFactory := preload("res://scripts/stages/stage4/stage4_bird_payload_factory.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_crow_payload()
	_verify_gold_dust_payload()
	_verify_explosion_payloads()
	_verify_event_delegates_payload_construction()

	if _failures.is_empty():
		print("stage4_bird_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_crow_payload() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1001
	var left_crow: Dictionary = Stage4BirdPayloadFactory.build_crow("left", rng, 760.0)
	_expect(is_equal_approx(float(left_crow.get("x", 0.0)), -50.0), "left crow should spawn off the left edge")
	_expect(float(left_crow.get("vx", 0.0)) > 0.0, "left crow should fly right")
	_expect(float(left_crow.get("y", 0.0)) >= 50.0 and float(left_crow.get("y", 0.0)) <= 200.0, "crow spawn y should stay in reference band")
	_expect(int(left_crow.get("size", 0)) >= 20 and int(left_crow.get("size", 0)) <= 30, "crow size should stay in reference range")
	_expect(left_crow.get("gold_dust", null) is Array, "crow should start with a gold-dust array")
	_expect(is_equal_approx(float(left_crow.get("last_x", 0.0)), -50.0), "crow should seed last_x from spawn")

	rng.seed = 1002
	var right_crow: Dictionary = Stage4BirdPayloadFactory.build_crow("right", rng, 760.0)
	_expect(is_equal_approx(float(right_crow.get("x", 0.0)), 810.0), "right crow should spawn off the right edge")
	_expect(float(right_crow.get("vx", 0.0)) < 0.0, "right crow should fly left")


func _verify_gold_dust_payload() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2001
	var crow := {"vx": 2.0, "wing_phase": 1.25}
	var dust: Dictionary = Stage4BirdPayloadFactory.build_gold_dust_particle(
		crow,
		Vector2(100.0, 120.0),
		Vector2(112.0, 124.0),
		1.0,
		24.0,
		rng
	)
	_expect(float(dust.get("life", 0.0)) >= 42.0 and float(dust.get("life", 0.0)) <= 78.0, "gold dust life should stay in reference range")
	_expect(is_equal_approx(float(dust.get("max_life", 0.0)), float(dust.get("life", 0.0))), "gold dust should keep max_life equal to initial life")
	_expect(float(dust.get("size", 0.0)) >= 1.0 and float(dust.get("size", 0.0)) <= 2.8, "gold dust size should stay in reference range")
	_expect(float(dust.get("phase_speed", 0.0)) >= 0.12 and float(dust.get("phase_speed", 0.0)) <= 0.28, "gold dust phase speed should stay in reference range")


func _verify_explosion_payloads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3001
	var fragments: Array = Stage4BirdPayloadFactory.build_crow_fragments(300.0, 200.0, 24, rng)
	_expect(fragments.size() >= 6 and fragments.size() <= 8, "crow explosion should create 6-8 fragments")
	for fragment_value in fragments:
		var fragment: Dictionary = fragment_value if fragment_value is Dictionary else {}
		_expect(is_equal_approx(float(fragment.get("x", 0.0)), 300.0), "fragment should preserve explosion x")
		_expect(is_equal_approx(float(fragment.get("y", 0.0)), 200.0), "fragment should preserve explosion y")
		_expect(fragment.get("color", Color.BLACK) is Color, "fragment should include color")
		_expect(int(fragment.get("num_points", 0)) == _as_array(fragment.get("shape_offsets", [])).size(), "fragment point count should match offsets")
		_expect(float(fragment.get("life", 0.0)) >= 60.0 and float(fragment.get("life", 0.0)) <= 90.0, "fragment life should stay in reference range")

	var debris: Array = Stage4BirdPayloadFactory.build_crow_debris_particles(300.0, 200.0, 8, rng)
	_expect(debris.size() == 8, "crow explosion should create requested debris count")
	for debris_value in debris:
		var particle: Dictionary = debris_value if debris_value is Dictionary else {}
		_expect(is_equal_approx(float(particle.get("opacity", 0.0)), 0.78), "debris should preserve starting opacity")
		_expect(_as_array(particle.get("shape_offsets", [])).size() == 4, "debris should keep four-point offset payload")
	_expect(Stage4BirdPayloadFactory.build_crow_debris_particles(0.0, 0.0, -2, rng).is_empty(), "negative debris count should clamp to empty")


func _verify_event_delegates_payload_construction() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_bird_event.gd")
	_expect(source.find("Stage4BirdPayloadFactory.build_crow") >= 0, "bird event should delegate crow payload construction")
	_expect(source.find("Stage4BirdPayloadFactory.build_gold_dust_particle") >= 0, "bird event should delegate gold-dust payload construction")
	_expect(source.find("Stage4BirdPayloadFactory.build_crow_fragments") >= 0, "bird event should delegate fragment payload construction")
	_expect(source.find("Stage4BirdPayloadFactory.build_crow_debris_particles") >= 0, "bird event should delegate debris payload construction")

	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	_expect(catalog_source.find("stage4_bird_payload_factory") >= 0, "module catalog should expose Stage 4 bird payload factory")


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
