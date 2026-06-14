extends SceneTree

const Stage3BossSkillPayloadFactory := preload("res://scripts/stages/stage3/stage3_boss_skill_payload_factory.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_falling_tear_payload()
	_verify_curse_payloads()
	_verify_psychoball_and_kuromi_payloads()
	_verify_tail_and_prism_payloads()
	_verify_stage3_source_delegates_payloads()

	if _failures.is_empty():
		print("stage3_boss_skill_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_falling_tear_payload() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8001
	var tear: Dictionary = Stage3BossSkillPayloadFactory.build_falling_tear(Stage3BossSkillState.WIDTH, rng)
	_expect(float(tear.get("x", -1.0)) >= 0.0 and float(tear.get("x", -1.0)) <= Stage3BossSkillState.WIDTH - 20.0, "tear x should stay in play width")
	_expect(float(tear.get("y", 0.0)) >= -200.0 and float(tear.get("y", 0.0)) <= -20.0, "tear y should spawn above field")
	_expect(is_equal_approx(float(tear.get("prev_y", 999.0)), float(tear.get("y", 0.0))), "tear prev_y should start at y")
	_expect(float(tear.get("speed", 0.0)) >= 2.0 and float(tear.get("speed", 0.0)) <= 5.0, "tear speed should stay in reference range")


func _verify_curse_payloads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8002
	var smoke: Dictionary = Stage3BossSkillPayloadFactory.build_curse_smoke_particle(Vector2(300.0, 700.0), rng)
	_expect(float(smoke.get("x", 0.0)) >= 290.0 and float(smoke.get("x", 0.0)) <= 310.0, "curse smoke x should stay near chest")
	_expect(float(smoke.get("y", 0.0)) >= 690.0 and float(smoke.get("y", 0.0)) <= 705.0, "curse smoke y should stay near chest")
	_expect(float(smoke.get("life", 0.0)) >= 1.0 and float(smoke.get("life", 0.0)) <= 2.0, "curse smoke life should stay in range")
	_expect(float(smoke.get("size", 0.0)) >= 8.0 and float(smoke.get("size", 0.0)) <= 18.0, "curse smoke size should stay in range")
	_expect(is_equal_approx(float(smoke.get("alpha", 0.0)), 1.0), "curse smoke should start opaque")

	var explosion: Array = Stage3BossSkillPayloadFactory.build_curse_explosion_particles(Vector2(300.0, 700.0), 15, rng)
	_expect(explosion.size() == 15, "curse explosion should create requested particle count")
	for particle_value in explosion:
		var particle: Dictionary = particle_value if particle_value is Dictionary else {}
		_expect(float(particle.get("life", 0.0)) >= 0.34 and float(particle.get("life", 0.0)) <= 0.67, "curse explosion life should stay in range")
		_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.67), "curse explosion should preserve max_life")
		_expect(float(particle.get("size", 0.0)) >= 3.0 and float(particle.get("size", 0.0)) <= 8.0, "curse explosion size should stay in range")
	_expect(Stage3BossSkillPayloadFactory.build_curse_explosion_particles(Vector2.ZERO, -1, rng).is_empty(), "negative curse explosion count should clamp empty")


func _verify_psychoball_and_kuromi_payloads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8003
	var neutralize: Array = Stage3BossSkillPayloadFactory.build_psychoball_neutralize_particles(Vector2(320.0, 240.0), 20, rng)
	_expect(neutralize.size() == 20, "psychoball neutralize should create requested count")
	for particle_value in neutralize:
		var particle: Dictionary = particle_value if particle_value is Dictionary else {}
		_expect(is_equal_approx(float(particle.get("life_frames", 0.0)), 30.0), "neutralize particle should preserve life frames")
		_expect(int(particle.get("color_r", 0)) >= 150 and int(particle.get("color_r", 0)) <= 200, "neutralize red channel should stay in range")
		_expect(int(particle.get("color_g", -1)) == 0, "neutralize green channel should stay zero")
		_expect(int(particle.get("color_b", 0)) >= 150 and int(particle.get("color_b", 0)) <= 255, "neutralize blue channel should stay in range")

	var mouth: Dictionary = Stage3BossSkillPayloadFactory.build_kuromi_mouth_particle(Vector2(380.0, 375.0), 0.5, true, rng)
	_expect(float(mouth.get("x", 0.0)) >= 368.0 and float(mouth.get("x", 0.0)) <= 392.0, "Kuromi mouth particle x should stay near center")
	_expect(float(mouth.get("life", 0.0)) >= 0.35 and float(mouth.get("life", 0.0)) <= 0.9, "Kuromi mouth life should stay in range")
	_expect(is_equal_approx(float(mouth.get("max_life", 0.0)), 0.9), "Kuromi mouth should preserve max_life")
	_expect(float(mouth.get("hue", 0.0)) >= 0.86 and float(mouth.get("hue", 0.0)) <= 0.98, "Kuromi mouth hue should stay in range")

	var spit_trail: Dictionary = Stage3BossSkillPayloadFactory.build_kuromi_spit_trail_point(Vector2(380.0, 375.0), 18.0)
	_expect(is_equal_approx(float(spit_trail.get("x", 0.0)), 380.0), "Kuromi spit trail should preserve x")
	_expect(is_equal_approx(float(spit_trail.get("y", 0.0)), 375.0), "Kuromi spit trail should preserve y")
	_expect(is_equal_approx(float(spit_trail.get("life", 0.0)), 1.0), "Kuromi spit trail should default to full life")
	_expect(is_equal_approx(float(spit_trail.get("size", 0.0)), 18.0), "Kuromi spit trail should preserve size")


func _verify_tail_and_prism_payloads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8004
	var burst: Dictionary = Stage3BossSkillPayloadFactory.build_tail_hit_burst(Vector2(100.0, 200.0), Vector2(3.0, 4.0), Stage3BossSkillState.TAIL_HIT_BURST_SEC, rng)
	_expect(is_equal_approx(float(burst.get("x", 0.0)), 100.0), "tail hit burst should preserve x")
	_expect(is_equal_approx(float(burst.get("life", 0.0)), Stage3BossSkillState.TAIL_HIT_BURST_SEC), "tail hit burst should preserve life")
	_expect(is_equal_approx(float(burst.get("max_life", 0.0)), Stage3BossSkillState.TAIL_HIT_BURST_SEC), "tail hit burst should preserve max_life")
	_expect(is_equal_approx(float(burst.get("angle", 0.0)), Vector2(3.0, 4.0).angle()), "tail hit burst should derive redirected angle")
	_expect(burst.has("seed"), "tail hit burst should include seed")

	var prism: Array = Stage3BossSkillPayloadFactory.build_prism_particles(Vector2(100.0, 200.0), 18, false, rng)
	_expect(prism.size() == 18, "normal prism burst should create requested count")
	for particle_value in prism:
		var particle: Dictionary = particle_value if particle_value is Dictionary else {}
		_expect(is_equal_approx(float(particle.get("life", 0.0)), 1.0), "normal prism life should stay at one second")
		_expect(float(particle.get("size", 0.0)) >= 1.5 and float(particle.get("size", 0.0)) <= 3.8, "normal prism size should stay in range")

	var strong_prism: Array = Stage3BossSkillPayloadFactory.build_prism_particles(Vector2(100.0, 200.0), 20, true, rng)
	_expect(strong_prism.size() == 20, "strong prism burst should create requested count")
	for particle_value in strong_prism:
		var particle: Dictionary = particle_value if particle_value is Dictionary else {}
		_expect(float(particle.get("life", 0.0)) >= 1.0 and float(particle.get("life", 0.0)) <= 2.0, "strong prism life should stay in range")
		_expect(float(particle.get("size", 0.0)) >= 2.0 and float(particle.get("size", 0.0)) <= 5.0, "strong prism size should stay in range")
	_expect(Stage3BossSkillPayloadFactory.build_prism_particles(Vector2.ZERO, -1, false, rng).is_empty(), "negative prism count should clamp empty")


func _verify_stage3_source_delegates_payloads() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
	_expect(source.find("Stage3BossSkillPayloadFactory.build_falling_tear") >= 0, "Stage 3 state should delegate tear payloads")
	_expect(source.find("Stage3BossSkillPayloadFactory.build_curse_smoke_particle") >= 0, "Stage 3 state should delegate curse smoke payloads")
	_expect(source.find("Stage3BossSkillPayloadFactory.build_curse_explosion_particles") >= 0, "Stage 3 state should delegate curse explosion payloads")
	_expect(source.find("Stage3BossSkillPayloadFactory.build_psychoball_neutralize_particles") >= 0, "Stage 3 state should delegate psychoball neutralize payloads")
	_expect(source.find("Stage3BossSkillPayloadFactory.build_kuromi_mouth_particle") >= 0, "Stage 3 state should delegate Kuromi mouth payloads")
	_expect(source.find("Stage3BossSkillPayloadFactory.build_kuromi_spit_trail_point") >= 0, "Stage 3 state should delegate Kuromi spit trail payloads")
	_expect(source.find("Stage3BossSkillPayloadFactory.build_tail_hit_burst") >= 0, "Stage 3 state should delegate tail hit burst payloads")
	_expect(source.find("Stage3BossSkillPayloadFactory.build_prism_particles") >= 0, "Stage 3 state should delegate prism payloads")

	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	_expect(catalog_source.find("stage3_boss_skill_payload_factory") >= 0, "module catalog should expose Stage 3 boss skill payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
