extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetHydroSpherePayloadFactory := preload("res://scripts/lingpet/lingpet_hydro_sphere_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_particle_payload()
	_verify_splash_particle_payload()
	_verify_ambient_particle_payload()
	_verify_slow_status_payload()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_hydro_sphere_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_particle_payload() -> void:
	var particle: Dictionary = LingpetHydroSpherePayloadFactory.build_particle(Vector2(10.0, 20.0), Vector2(3.0, -4.0), 0.5, 6.0, 1)
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(10.0, 20.0), "base particle should preserve position")
	_expect(particle.get("vel", Vector2.ZERO) == Vector2(3.0, -4.0), "base particle should preserve velocity")
	_expect(is_equal_approx(float(particle.get("life", 0.0)), 0.5), "base particle should preserve life")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.5), "base particle should copy max life")
	_expect(is_equal_approx(float(particle.get("size", 0.0)), 6.0), "base particle should preserve size")
	_expect(int(particle.get("kind", -1)) == 1, "base particle should preserve kind")

	var tiny: Dictionary = LingpetHydroSpherePayloadFactory.build_particle(Vector2.ZERO, Vector2.ZERO, -1.0, 1.0, 0)
	_expect(is_equal_approx(float(tiny.get("max_life", 0.0)), 0.01), "base particle should clamp max life")


func _verify_splash_particle_payload() -> void:
	var origin := Vector2(380.0, 12.0)
	var particle: Dictionary = LingpetHydroSpherePayloadFactory.build_splash_particle(origin)
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	_expect(pos.x >= origin.x - 10.0 and pos.x <= origin.x + 10.0, "splash particle should use the original x scatter")
	_expect(pos.y >= origin.y - 4.0 and pos.y <= origin.y + 4.0, "splash particle should use the original y scatter")
	_expect(particle.get("vel", Vector2.ZERO) is Vector2, "splash particle should carry velocity")
	_expect(float(particle.get("life", 0.0)) >= 0.34 and float(particle.get("life", 0.0)) <= 0.62, "splash particle life should stay in range")
	_expect(float(particle.get("size", 0.0)) >= 3.0 and float(particle.get("size", 0.0)) <= 7.0, "splash particle size should stay in range")
	_expect(int(particle.get("kind", -1)) == 0, "splash particle should use kind 0")


func _verify_ambient_particle_payload() -> void:
	var puddle_pos := Vector2(420.0, 74.0)
	var particle: Dictionary = LingpetHydroSpherePayloadFactory.build_ambient_particle(puddle_pos, 134.4, 33.6)
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	_expect(pos.x >= puddle_pos.x - 134.4 * 0.92 and pos.x <= puddle_pos.x + 134.4 * 0.92, "ambient particle should stay inside the original x spread")
	_expect(pos.y >= puddle_pos.y - 33.6 * 0.55 and pos.y <= puddle_pos.y + 33.6 * 0.55, "ambient particle should stay inside the original y spread")
	var vel: Vector2 = particle.get("vel", Vector2.ZERO)
	_expect(vel.x >= -12.0 and vel.x <= 12.0, "ambient particle x velocity should stay in range")
	_expect(vel.y >= -28.0 and vel.y <= -10.0, "ambient particle y velocity should stay in range")
	_expect(float(particle.get("life", 0.0)) >= 0.5 and float(particle.get("life", 0.0)) <= 0.95, "ambient particle life should stay in range")
	_expect(float(particle.get("size", 0.0)) >= 2.0 and float(particle.get("size", 0.0)) <= 4.2, "ambient particle size should stay in range")
	_expect(int(particle.get("kind", -1)) == 1, "ambient particle should use kind 1")


func _verify_slow_status_payload() -> void:
	var data: Dictionary = LingpetHydroSpherePayloadFactory.build_slow_status_data(0.65)
	_expect(is_equal_approx(float(data.get("multiplier", 0.0)), 0.65), "slow status should preserve multiplier")
	_expect(bool(data.get("cleansable", false)), "slow status should remain cleansable")
	_expect(str(data.get("visual", "")) == "maribo_hydro_sphere", "slow status should keep the Hydro Sphere visual key")


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_hydro_sphere_skill.gd")
	_expect(source.find("LingpetHydroSpherePayloadFactory.build_splash_particle") >= 0, "Hydro Sphere should delegate splash particles")
	_expect(source.find("LingpetHydroSpherePayloadFactory.build_ambient_particle") >= 0, "Hydro Sphere should delegate ambient particles")
	_expect(source.find("LingpetHydroSpherePayloadFactory.build_slow_status_data") >= 0, "Hydro Sphere should delegate slow status payload data")
	_expect(source.find("_particles.append({") < 0, "Hydro Sphere should not inline particle dictionaries")
	_expect(source.find("\"visual\": \"maribo_hydro_sphere\"") < 0, "Hydro Sphere should not inline slow status data")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_hydro_sphere_payload_factory"), "lingpet module catalog should list the Hydro Sphere payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_hydro_sphere_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_hydro_sphere_payload_factory.gd", "top-level module catalog should resolve the Hydro Sphere payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
