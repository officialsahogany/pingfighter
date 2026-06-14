extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetDragonWingPayloadFactory := preload("res://scripts/lingpet/lingpet_dragon_wing_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_flying_dragon_payload()
	_verify_wind_particle_payloads()
	_verify_trail_payloads()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_dragon_wing_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_flying_dragon_payload() -> void:
	var rightward: Dictionary = LingpetDragonWingPayloadFactory.build_flying_dragon(Vector2(380.0, 520.0), 1.0, 760.0, 70.0)
	_expect(bool(rightward.get("active", false)), "flying dragon should start active")
	_expect(rightward.get("pos", Vector2.ZERO) == Vector2(-70.0, 520.0), "rightward dragon should start off the left edge")
	_expect(is_equal_approx(float(rightward.get("base_y", 0.0)), 520.0), "flying dragon should preserve the clamped origin y")
	_expect(is_equal_approx(float(rightward.get("direction", 0.0)), 1.0), "flying dragon should preserve travel direction")
	_expect(is_equal_approx(float(rightward.get("wing_time", -1.0)), 0.0), "flying dragon wing time should start at zero")
	_expect(is_equal_approx(float(rightward.get("hit_cooldown", -1.0)), 0.0), "flying dragon hit cooldown should start at zero")

	var leftward_random_y: Dictionary = LingpetDragonWingPayloadFactory.build_flying_dragon(Vector2.ZERO, -1.0, 760.0, 70.0)
	var random_pos: Vector2 = leftward_random_y.get("pos", Vector2.ZERO)
	_expect(is_equal_approx(random_pos.x, 830.0), "leftward dragon should start off the right edge")
	_expect(random_pos.y >= 420.0 and random_pos.y <= 540.0, "zero-origin dragon should use the original random y band")


func _verify_wind_particle_payloads() -> void:
	var initial_particle: Dictionary = LingpetDragonWingPayloadFactory.build_wind_particle(true, -1.0, 760.0, -1.0, 28.0, 84.0)
	_expect(_is_wind_particle_inside_ranges(initial_particle, 0.0, 760.0, 150.0, 610.0, -1.0), "initial wind particle should keep the original full-field spawn range")
	var live_particle: Dictionary = LingpetDragonWingPayloadFactory.build_wind_particle(false, 1.0, 760.0, -1.0, 28.0, 84.0)
	_expect(_is_wind_particle_inside_ranges(live_particle, -22.0, 22.0, 90.0, 660.0, 1.0), "live wind particle should keep the original edge spawn range")


func _is_wind_particle_inside_ranges(
	particle: Dictionary,
	x_min: float,
	x_max: float,
	y_min: float,
	y_max: float,
	direction: float
) -> bool:
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	if pos.x < x_min or pos.x > x_max:
		return false
	if pos.y < y_min or pos.y > y_max:
		return false
	var vel: Vector2 = particle.get("vel", Vector2.ZERO)
	if signf(vel.x) != signf(direction) or absf(vel.x) < 210.0 or absf(vel.x) > 420.0:
		return false
	if vel.y > -28.0 or vel.y < -84.0:
		return false
	var life := float(particle.get("life", 0.0))
	if life < 0.55 or life > 1.05:
		return false
	if not is_equal_approx(float(particle.get("max_life", 0.0)), life):
		return false
	var length := float(particle.get("length", 0.0))
	if length < 24.0 or length > 58.0:
		return false
	var width := float(particle.get("width", 0.0))
	if width < 1.3 or width > 3.4:
		return false
	var phase := float(particle.get("phase", -1.0))
	return phase >= 0.0 and phase <= TAU


func _verify_trail_payloads() -> void:
	var swirl: Dictionary = LingpetDragonWingPayloadFactory.build_ball_swirl_trail_entry(Vector2(300.0, 420.0), 0.25, 0.48)
	_expect(swirl.get("pos", Vector2.ZERO) == Vector2(300.0, 420.0), "swirl trail should preserve ball position")
	_expect(is_equal_approx(float(swirl.get("life", 0.0)), 0.48), "swirl trail should preserve life")
	_expect(is_equal_approx(float(swirl.get("max_life", 0.0)), 0.48), "swirl trail should copy max life")
	var phase := float(swirl.get("phase", 999.0))
	_expect(phase >= 0.25 * 8.0 - 0.35 and phase <= 0.25 * 8.0 + 0.35, "swirl trail should keep the original phase jitter")

	var dragon_trail: Dictionary = LingpetDragonWingPayloadFactory.build_dragon_trail_entry(Vector2(50.0, 520.0), 0.34)
	_expect(dragon_trail.get("pos", Vector2.ZERO) == Vector2(50.0, 520.0), "dragon trail should preserve position")
	_expect(is_equal_approx(float(dragon_trail.get("life", 0.0)), 0.34), "dragon trail should preserve life")
	_expect(is_equal_approx(float(dragon_trail.get("max_life", 0.0)), 0.34), "dragon trail should copy max life")


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_dragon_wing_skill.gd")
	_expect(source.find("LingpetDragonWingPayloadFactory.build_flying_dragon") >= 0, "Dragon Wing should delegate flying-dragon payloads")
	_expect(source.find("LingpetDragonWingPayloadFactory.build_wind_particle") >= 0, "Dragon Wing should delegate wind-particle payloads")
	_expect(source.find("LingpetDragonWingPayloadFactory.build_ball_swirl_trail_entry") >= 0, "Dragon Wing should delegate ball-swirl trail payloads")
	_expect(source.find("LingpetDragonWingPayloadFactory.build_dragon_trail_entry") >= 0, "Dragon Wing should delegate dragon-trail payloads")
	_expect(source.find("_wind_particles.append({") < 0, "Dragon Wing should not inline wind-particle dictionaries")
	_expect(source.find("_ball_swirl_trail.append({") < 0, "Dragon Wing should not inline ball-swirl trail dictionaries")
	_expect(source.find("_dragon_trail.append({") < 0, "Dragon Wing should not inline dragon-trail dictionaries")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_dragon_wing_payload_factory"), "lingpet module catalog should list the Dragon Wing payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_dragon_wing_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_dragon_wing_payload_factory.gd", "top-level module catalog should resolve the Dragon Wing payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
