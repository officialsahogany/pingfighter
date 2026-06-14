extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage4PonkSkillPayloadFactory := preload("res://scripts/stages/stage4/stage4_ponk_skill_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	var trail: Dictionary = Stage4PonkSkillPayloadFactory.build_meditation_trail(Vector2(330.0, 120.0))
	_expect(trail.get("pos", Vector2.ZERO) == Vector2(330.0, 120.0), "meditation trail should preserve position")
	_expect(is_equal_approx(float(trail.get("life", 0.0)), 34.0), "meditation trail life should stay tuned")
	_expect(is_equal_approx(float(trail.get("radius", 0.0)), 11.0), "meditation trail radius should stay tuned")

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260612
	var particle: Dictionary = Stage4PonkSkillPayloadFactory.build_meditation_particle(Vector2(300.0, 90.0), rng)
	var particle_pos: Vector2 = particle.get("pos", Vector2.ZERO) as Vector2
	var particle_vel: Vector2 = particle.get("vel", Vector2.ZERO) as Vector2
	var particle_offset: float = particle_pos.distance_to(Vector2(300.0, 90.0))
	var particle_speed: float = particle_vel.length()
	_expect(particle_offset >= 10.0 and particle_offset <= 34.0, "meditation particle offset should stay in range")
	_expect(particle_speed >= 0.25 and particle_speed <= 1.15, "meditation particle speed should stay in range")
	_expect(float(particle.get("life", 0.0)) >= 20.0 and float(particle.get("life", 0.0)) <= 42.0, "meditation particle life should stay in range")
	_expect(float(particle.get("size", 0.0)) >= 1.8 and float(particle.get("size", 0.0)) <= 4.2, "meditation particle size should stay in range")

	for idx in range(3):
		var circle: Dictionary = Stage4PonkSkillPayloadFactory.build_meditation_circle(Vector2(380.0, 78.0), idx)
		_expect(circle.get("pos", Vector2.ZERO) == Vector2(380.0, 78.0), "meditation circle should preserve center")
		_expect(is_equal_approx(float(circle.get("radius", 0.0)), 34.0 + float(idx) * 20.0), "meditation circle radius should scale by index")
		_expect(is_equal_approx(float(circle.get("grow", 0.0)), 1.6 + float(idx) * 0.35), "meditation circle grow should scale by index")
		_expect(is_equal_approx(float(circle.get("life", 0.0)), 54.0 + float(idx) * 18.0), "meditation circle life should scale by index")

	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_ponk_skill_state.gd")
	_expect(source.find("Stage4PonkSkillPayloadFactory.build_meditation_trail") >= 0, "Ponk skill state should delegate meditation trail payloads")
	_expect(source.find("Stage4PonkSkillPayloadFactory.build_meditation_particle") >= 0, "Ponk skill state should delegate meditation particle payloads")
	_expect(source.find("Stage4PonkSkillPayloadFactory.build_meditation_circle") >= 0, "Ponk skill state should delegate meditation circle payloads")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("stage4_ponk_skill_payload_factory"), "stage module catalog should list the Stage 4 Ponk skill payload factory")

	if _failures.is_empty():
		print("stage4_ponk_skill_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
