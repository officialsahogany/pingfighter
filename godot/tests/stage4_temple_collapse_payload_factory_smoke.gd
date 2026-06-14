extends SceneTree

const Stage4TempleCollapsePayloadFactory := preload("res://scripts/stages/stage4/stage4_temple_collapse_payload_factory.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_debris_defaults_and_sprite_variants()
	_verify_dust_and_fire_payloads()
	_verify_falling_lantern_payload()
	_verify_event_delegates_payload_defaults()

	if _failures.is_empty():
		print("stage4_temple_collapse_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_debris_defaults_and_sprite_variants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6001
	var variants := {"brick": [0, 12, 13], "glass": []}
	var debris: Dictionary = Stage4TempleCollapsePayloadFactory.make_debris({
		"x": 10.0,
		"y": 20.0,
		"type": "brick",
	}, rng, variants)
	_expect(str(debris.get("type", "")) == "brick", "debris should preserve type")
	_expect([0, 12, 13].has(int(debris.get("sprite_index", -1))), "debris should pick sprite index from type variants")
	_expect(is_equal_approx(float(debris.get("opacity", 0.0)), 1.0), "debris should default opacity")
	_expect(is_equal_approx(float(debris.get("delay", -1.0)), 0.0), "debris should default delay")
	_expect(is_equal_approx(float(debris.get("gravity", 0.0)), 0.35), "debris should default gravity")
	_expect(is_equal_approx(float(debris.get("drag", 0.0)), 0.98), "debris should default drag")
	_expect(bool(debris.has("sprite_flip_x")), "debris should include sprite flip")
	_expect(float(debris.get("sprite_scale_jitter", 0.0)) >= 0.88 and float(debris.get("sprite_scale_jitter", 0.0)) <= 1.14, "debris scale jitter should stay in range")

	var explicit: Dictionary = Stage4TempleCollapsePayloadFactory.make_debris({
		"type": "glass",
		"sprite_index": 9,
		"sprite_flip_x": false,
		"sprite_scale_jitter": 1.0,
		"opacity": 0.4,
		"delay": 0.25,
		"gravity": 0.1,
		"drag": 0.9,
	}, rng, variants)
	_expect(int(explicit.get("sprite_index", -1)) == 9, "explicit sprite index should win")
	_expect(not bool(explicit.get("sprite_flip_x", true)), "explicit flip should win")
	_expect(is_equal_approx(float(explicit.get("sprite_scale_jitter", 0.0)), 1.0), "explicit scale jitter should win")
	_expect(is_equal_approx(float(explicit.get("opacity", 0.0)), 0.4), "explicit opacity should win")

	var fallback: Dictionary = Stage4TempleCollapsePayloadFactory.make_debris({"type": "glass"}, rng, variants)
	_expect(int(fallback.get("sprite_index", -1)) == Stage4TempleCollapsePayloadFactory.FALLBACK_DEBRIS_SPRITE_INDEX, "empty variant list should use fallback sprite")


func _verify_dust_and_fire_payloads() -> void:
	var dust: Dictionary = Stage4TempleCollapsePayloadFactory.make_dust_cloud(1.0, 2.0, 30.0, 0.5, 1.2, -0.4, 0.25)
	_expect(is_equal_approx(float(dust.get("opacity", 1.0)), 0.0), "dust cloud should start transparent")
	_expect(is_equal_approx(float(dust.get("max_opacity", 0.0)), 0.5), "dust cloud should preserve max opacity")
	_expect(is_equal_approx(float(dust.get("rise_speed", 0.0)), -0.4), "dust cloud should preserve rise speed")

	var rng := RandomNumberGenerator.new()
	rng.seed = 6002
	var fire: Dictionary = Stage4TempleCollapsePayloadFactory.make_fire_particle(10.0, 20.0, 1.0, -2.0, 4.0, 30.0, rng)
	_expect(is_equal_approx(float(fire.get("x", 0.0)), 10.0), "fire particle should preserve x")
	_expect(is_equal_approx(float(fire.get("vy", 0.0)), -2.0), "fire particle should preserve velocity")
	_expect(is_equal_approx(float(fire.get("life", 0.0)), 30.0), "fire particle should preserve life")
	_expect(float(fire.get("color_phase", -1.0)) >= 0.0 and float(fire.get("color_phase", 2.0)) <= 1.0, "fire particle should include random color phase")


func _verify_falling_lantern_payload() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6003
	var lantern: Dictionary = Stage4TempleCollapsePayloadFactory.make_falling_lantern({
		"x": 210.0,
		"y": 120.0,
		"size": "large",
	}, rng)
	_expect(is_equal_approx(float(lantern.get("x", 0.0)), 210.0), "falling lantern should preserve anchor x")
	_expect(is_equal_approx(float(lantern.get("y", 0.0)), 120.0), "falling lantern should preserve anchor y")
	_expect(float(lantern.get("vx", 99.0)) >= -4.0 and float(lantern.get("vx", 99.0)) <= 4.0, "falling lantern vx should clamp")
	_expect(is_equal_approx(float(lantern.get("vy", -1.0)), 0.0), "falling lantern should start with zero vy")
	_expect(is_equal_approx(float(lantern.get("rotation", -1.0)), 0.0), "falling lantern should start unrotated")
	_expect(float(lantern.get("rotation_speed", 99.0)) >= -5.0 and float(lantern.get("rotation_speed", 99.0)) <= 5.0, "falling lantern rotation speed should stay in range")
	_expect(str(lantern.get("size", "")) == "large", "falling lantern should preserve size")
	_expect(not bool(lantern.get("broken", true)), "falling lantern should start unbroken")
	_expect(float(lantern.get("ground_y", 0.0)) >= 640.0 and float(lantern.get("ground_y", 0.0)) <= 660.0, "falling lantern ground y should jitter near floor")
	_expect(is_equal_approx(float(lantern.get("deformation", -1.0)), 0.0), "falling lantern should start undeformed")
	_expect(int(lantern.get("bounce_count", -1)) == 0, "falling lantern should start with zero bounces")


func _verify_event_delegates_payload_defaults() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_temple_destruction_event.gd")
	_expect(source.find("Stage4TempleCollapsePayloadFactory.make_debris") >= 0, "temple destruction event should delegate debris defaults")
	_expect(source.find("Stage4TempleCollapsePayloadFactory.make_dust_cloud") >= 0, "temple destruction event should delegate dust payloads")
	_expect(source.find("Stage4TempleCollapsePayloadFactory.make_fire_particle") >= 0, "temple destruction event should delegate fire particle payloads")
	_expect(source.find("Stage4TempleCollapsePayloadFactory.make_falling_lantern") >= 0, "temple destruction event should delegate falling lantern payloads")
	_expect(source.find("func _pick_debris_sprite_index") < 0, "temple destruction event should not keep private debris sprite picker")

	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	_expect(catalog_source.find("stage4_temple_collapse_payload_factory") >= 0, "module catalog should expose Stage 4 temple collapse payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
