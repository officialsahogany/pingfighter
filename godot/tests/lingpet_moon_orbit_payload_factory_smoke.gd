extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetMoonOrbitPayloadFactory := preload("res://scripts/lingpet/lingpet_moon_orbit_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_particle_payload()
	_verify_burst_particle_payload()
	_verify_ambient_particle_payload()
	_verify_slow_status_payload()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_moon_orbit_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_particle_payload() -> void:
	var particle: Dictionary = LingpetMoonOrbitPayloadFactory.build_particle(Vector2(12.0, 18.0), Vector2(-3.0, 4.0), 0.3, 5.0, 1)
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(12.0, 18.0), "base particle should preserve position")
	_expect(particle.get("vel", Vector2.ZERO) == Vector2(-3.0, 4.0), "base particle should preserve velocity")
	_expect(is_equal_approx(float(particle.get("life", 0.0)), 0.3), "base particle should preserve life")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.3), "base particle should copy max life")
	_expect(is_equal_approx(float(particle.get("size", 0.0)), 5.0), "base particle should preserve size")
	_expect(int(particle.get("kind", -1)) == 1, "base particle should preserve kind")


func _verify_burst_particle_payload() -> void:
	var origin := Vector2(360.0, 12.0)
	var particle: Dictionary = LingpetMoonOrbitPayloadFactory.build_burst_particle(origin)
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	_expect(pos.x >= origin.x - 9.0 and pos.x <= origin.x + 9.0, "burst particle should use the original x scatter")
	_expect(pos.y >= origin.y - 4.0 and pos.y <= origin.y + 5.0, "burst particle should use the original y scatter")
	_expect(particle.get("vel", Vector2.ZERO) is Vector2, "burst particle should carry velocity")
	_expect(float(particle.get("life", 0.0)) >= 0.28 and float(particle.get("life", 0.0)) <= 0.58, "burst particle life should stay in range")
	_expect(float(particle.get("size", 0.0)) >= 2.2 and float(particle.get("size", 0.0)) <= 5.2, "burst particle size should stay in range")
	_expect(int(particle.get("kind", -1)) == 0, "burst particle should use kind 0")


func _verify_ambient_particle_payload() -> void:
	var orbit_pos := Vector2(420.0, 62.0)
	var particle: Dictionary = LingpetMoonOrbitPayloadFactory.build_ambient_particle(orbit_pos, 220.0, 54.0)
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	_expect(pos.x >= orbit_pos.x - 220.0 * 0.92 and pos.x <= orbit_pos.x + 220.0 * 0.92, "ambient particle should stay inside the original x spread")
	_expect(pos.y >= orbit_pos.y - 54.0 * 0.42 and pos.y <= orbit_pos.y + 54.0 * 0.42, "ambient particle should stay inside the original y spread")
	var vel: Vector2 = particle.get("vel", Vector2.ZERO)
	_expect(vel.x >= -22.0 and vel.x <= 22.0, "ambient particle x velocity should stay in range")
	_expect(vel.y >= -12.0 and vel.y <= 8.0, "ambient particle y velocity should stay in range")
	_expect(float(particle.get("life", 0.0)) >= 0.42 and float(particle.get("life", 0.0)) <= 0.82, "ambient particle life should stay in range")
	_expect(float(particle.get("size", 0.0)) >= 1.8 and float(particle.get("size", 0.0)) <= 3.8, "ambient particle size should stay in range")
	_expect(int(particle.get("kind", -1)) == 1, "ambient particle should use kind 1")


func _verify_slow_status_payload() -> void:
	var data: Dictionary = LingpetMoonOrbitPayloadFactory.build_slow_status_data(0.72)
	_expect(is_equal_approx(float(data.get("multiplier", 0.0)), 0.72), "slow status should preserve multiplier")
	_expect(bool(data.get("cleansable", false)), "slow status should remain cleansable")
	_expect(str(data.get("visual", "")) == "draft_bat_moon_orbit", "slow status should keep the Moon Orbit visual key")
	_expect(bool(data.get("suppress_legacy_boss_ai_slow", false)), "slow status should keep the boss-AI slow suppression marker")


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_moon_orbit_skill.gd")
	_expect(source.find("LingpetMoonOrbitPayloadFactory.build_burst_particle") >= 0, "Moon Orbit should delegate burst particles")
	_expect(source.find("LingpetMoonOrbitPayloadFactory.build_ambient_particle") >= 0, "Moon Orbit should delegate ambient particles")
	_expect(source.find("LingpetMoonOrbitPayloadFactory.build_slow_status_data") >= 0, "Moon Orbit should delegate slow status payload data")
	_expect(source.find("_particles.append({") < 0, "Moon Orbit should not inline particle dictionaries")
	_expect(source.find("\"visual\": \"draft_bat_moon_orbit\"") < 0, "Moon Orbit should not inline slow status data")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_moon_orbit_payload_factory"), "lingpet module catalog should list the Moon Orbit payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_moon_orbit_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_moon_orbit_payload_factory.gd", "top-level module catalog should resolve the Moon Orbit payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
