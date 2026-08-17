extends SceneTree

const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_drop_payload_defaults_and_options()
	_verify_particle_payloads()
	_verify_stage_sources_delegate_payload_construction()

	if _failures.is_empty():
		print("starpoint_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_drop_payload_defaults_and_options() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var drop: Dictionary = StarpointPayloadFactory.build_drop(
		Vector2(12.0, 34.0),
		rng,
		true,
		20.0,
		90.0,
		0.02,
		0.045,
		"menhera_tail"
	)
	_expect(drop.get("pos", Vector2.ZERO) == Vector2(12.0, 34.0), "drop should preserve spawn position")
	_expect(drop.get("vel", Vector2.ZERO) is Vector2, "drop should include velocity")
	_expect(is_equal_approx(float(drop.get("size", 0.0)), 18.8), "star detector drop should scale size")
	_expect(float(drop.get("rotation_speed", 0.0)) >= 0.02, "custom rotation speed should respect min")
	_expect(float(drop.get("rotation_speed", 1.0)) <= 0.045, "custom rotation speed should respect max")
	_expect(is_equal_approx(float(drop.get("life", 0.0)), 90.0), "drop should preserve custom lifetime")
	_expect(bool(drop.get("star_detector_bonus", false)), "drop should preserve star detector flag")
	_expect(String(drop.get("source_type", "")) == "menhera_tail", "drop should preserve source type")

	var no_source: Dictionary = StarpointPayloadFactory.build_drop(Vector2.ZERO, rng)
	_expect(not no_source.has("source_type"), "drop should omit empty source type")
	_expect(is_equal_approx(float(no_source.get("size", 0.0)), StarpointPayloadFactory.DEFAULT_STARPOINT_DROP_SIZE), "default drop should keep default size")


func _verify_particle_payloads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6789
	var particles: Array = StarpointPayloadFactory.build_particles(Vector2(5.0, 6.0), 4, 1.4, rng, 45.0)
	_expect(particles.size() == 4, "particle factory should create requested count")
	for particle_value in particles:
		var particle: Dictionary = particle_value if particle_value is Dictionary else {}
		_expect(particle.get("pos", Vector2.ZERO) is Vector2, "particle should include position")
		_expect(particle.get("vel", Vector2.ZERO) is Vector2, "particle should include velocity")
		_expect(float(particle.get("size", 0.0)) > 0.0, "particle should include positive size")
		_expect(is_equal_approx(float(particle.get("alpha", 0.0)), 1.0), "particle should start opaque")
		_expect(is_equal_approx(float(particle.get("life", 0.0)), 45.0), "particle should preserve custom lifetime")
		_expect(float(particle.get("fade_speed", 0.0)) >= 0.035, "particle fade should respect min")
		_expect(float(particle.get("fade_speed", 1.0)) <= 0.070, "particle fade should respect max")
	_expect(StarpointPayloadFactory.build_particles(Vector2.ZERO, -3, 1.0, rng).is_empty(), "negative particle count should clamp to empty")


func _verify_stage_sources_delegate_payload_construction() -> void:
	var paths := [
		"res://scripts/stages/stage1/stage1_balloon_starpoint_state.gd",
		"res://scripts/stages/stage2/stage2_starpoint_coordinator.gd",
		"res://scripts/stages/stage3/stage3_starpoint_state.gd",
		"res://scripts/stages/stage4/stage4_bird_starpoint_state.gd",
	]
	for path in paths:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.find("StarpointPayloadFactory.build_drop") >= 0, "%s should delegate starpoint drop payloads" % path)
		_expect(source.find("StarpointPayloadFactory.build_particles") >= 0, "%s should delegate starpoint particles" % path)
		var is_stage1_owner: bool = path.ends_with("stage1_balloon_starpoint_state.gd")
		var is_stage2_owner: bool = path.ends_with("stage2_starpoint_coordinator.gd")
		var is_stage3_owner: bool = path.ends_with("stage3_starpoint_state.gd")
		var is_stage4_owner: bool = path.ends_with("stage4_bird_starpoint_state.gd")
		var drop_body := _slice_between(
			source,
			"func spawn_drop_at" if is_stage1_owner or is_stage2_owner or is_stage3_owner or is_stage4_owner else "func _spawn_starpoint_drop_at",
			"func spawn_star_detector_bonus_drops" if is_stage1_owner or is_stage2_owner or is_stage4_owner else "func _spawn_star_detector_bonus_drops"
		)
		var particle_body := _slice_between(
			source,
			"func spawn_particles" if is_stage1_owner or is_stage2_owner or is_stage4_owner else ("func _spawn_particles" if is_stage3_owner else "func _spawn_starpoint_particles"),
			"func update_particles" if is_stage1_owner or is_stage2_owner or is_stage4_owner else ("func _play_collect_sound" if is_stage3_owner else "func _update_starpoint_particles")
		)
		_expect(drop_body.find("\"glow_intensity\"") < 0, "%s should not keep private drop payload dictionaries" % path)
		_expect(particle_body.find("\"fade_speed\"") < 0, "%s should not keep private particle payload dictionaries" % path)

	var stage2_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(stage2_source.find("Stage2StarpointVisualFactory") < 0, "Stage 2 background should not preload the removed visual factory")
	_expect(stage2_source.find("stage2_starpoint_visual_factory") < 0, "Stage 2 background should not reference the removed visual factory path")

	var catalog_source: String = FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	_expect(catalog_source.find("starpoint_payload_factory") >= 0, "module catalog should expose common starpoint payload factory")
	_expect(catalog_source.find("stage2_starpoint_visual_factory") < 0, "module catalog should not expose removed Stage 2 starpoint factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_between(source: String, start_marker: String, end_marker: String) -> String:
	var start_index := source.find(start_marker)
	if start_index < 0:
		return ""
	var end_index := source.find(end_marker, start_index + start_marker.length())
	if end_index < 0:
		return source.substr(start_index)
	return source.substr(start_index, end_index - start_index)
