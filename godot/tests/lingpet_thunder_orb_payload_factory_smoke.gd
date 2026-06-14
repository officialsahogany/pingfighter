extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetThunderOrbPayloadFactory := preload("res://scripts/lingpet/lingpet_thunder_orb_payload_factory.gd")

const ENERGY_TEST_COLORS: Array[Color] = [Color(0.78, 0.90, 1.0), Color(0.39, 0.70, 1.0)]
const LARGE_TEST_COLORS: Array[Color] = [Color.WHITE, Color(0.59, 0.82, 1.0)]


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_status_payload()
	_verify_energy_particle_payload()
	_verify_explosion_particle_payloads()
	_verify_base_particle_payload()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_thunder_orb_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_status_payload() -> void:
	var data: Dictionary = LingpetThunderOrbPayloadFactory.build_electric_stun_status_data()
	_expect(bool(data.get("cleansable", false)), "electric stun data should stay cleansable")
	_expect(str(data.get("visual", "")) == "lumion_thunder_orb", "electric stun data should keep the Thunder Orb visual key")
	_expect(bool(data.get("suppress_stun_stars", false)), "electric stun data should suppress generic stun stars")
	_expect(bool(data.get("electric_stun", false)), "electric stun data should mark the electric-stun flavor")


func _verify_energy_particle_payload() -> void:
	var origin := Vector2(380.0, 220.0)
	var particle: Dictionary = LingpetThunderOrbPayloadFactory.build_energy_particle(origin, 30.0, ENERGY_TEST_COLORS)
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	var distance := pos.distance_to(origin)
	_expect(distance >= 30.0 * 0.9 and distance <= 30.0 * 1.5, "energy particle should keep the original radial spawn range")
	var vel: Vector2 = particle.get("vel", Vector2.ZERO)
	_expect(vel.x >= -12.0 and vel.x <= 12.0, "energy particle should keep the x drift range")
	_expect(vel.y >= -42.0 and vel.y <= -16.0, "energy particle should keep the upward y drift range")
	_expect(float(particle.get("life", 0.0)) >= 0.33 and float(particle.get("life", 0.0)) <= 0.66, "energy particle should keep the life range")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.66), "energy particle should keep the fixed max life")
	_expect(float(particle.get("size", 0.0)) >= 1.2 and float(particle.get("size", 0.0)) <= 2.6, "energy particle should keep the size range")
	_expect(_color_in(particle.get("color", Color.TRANSPARENT), ENERGY_TEST_COLORS), "energy particle should pick from the provided palette")


func _verify_explosion_particle_payloads() -> void:
	var origin := Vector2(380.0, 65.0)
	var large_particle: Dictionary = LingpetThunderOrbPayloadFactory.build_large_explosion_particle(origin, LARGE_TEST_COLORS)
	_expect(_is_explosion_particle_inside_ranges(large_particle, origin, 6.0, 200.0, 600.0, 0.20, 0.45, 2.0, 5.0, 0, LARGE_TEST_COLORS), "large explosion particle should keep the original range")
	var small_particle: Dictionary = LingpetThunderOrbPayloadFactory.build_small_explosion_particle(origin, ENERGY_TEST_COLORS)
	_expect(_is_explosion_particle_inside_ranges(small_particle, origin, 10.0, 300.0, 800.0, 0.10, 0.30, 1.0, 2.5, 1, ENERGY_TEST_COLORS), "small explosion particle should keep the original range")


func _is_explosion_particle_inside_ranges(
	particle: Dictionary,
	origin: Vector2,
	offset_range: float,
	speed_min: float,
	speed_max: float,
	life_min: float,
	life_max: float,
	size_min: float,
	size_max: float,
	kind: int,
	colors: Array[Color]
) -> bool:
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	if pos.x < origin.x - offset_range or pos.x > origin.x + offset_range:
		return false
	if pos.y < origin.y - offset_range or pos.y > origin.y + offset_range:
		return false
	var speed := (particle.get("vel", Vector2.ZERO) as Vector2).length()
	if speed < speed_min or speed > speed_max:
		return false
	var life := float(particle.get("life", 0.0))
	if life < life_min or life > life_max:
		return false
	if not is_equal_approx(float(particle.get("max_life", 0.0)), life):
		return false
	var size := float(particle.get("size", 0.0))
	if size < size_min or size > size_max:
		return false
	if int(particle.get("kind", -1)) != kind:
		return false
	return _color_in(particle.get("color", Color.TRANSPARENT), colors)


func _verify_base_particle_payload() -> void:
	var particle: Dictionary = LingpetThunderOrbPayloadFactory.build_particle(Vector2(1.0, 2.0), Vector2(3.0, 4.0), -0.2, 9.0, 7, Color.RED)
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(1.0, 2.0), "base particle should preserve position")
	_expect(particle.get("vel", Vector2.ZERO) == Vector2(3.0, 4.0), "base particle should preserve velocity")
	_expect(is_equal_approx(float(particle.get("life", 0.0)), 0.01), "base particle should clamp life")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.01), "base particle should clamp max life")
	_expect(is_equal_approx(float(particle.get("size", 0.0)), 9.0), "base particle should preserve size")
	_expect(int(particle.get("kind", -1)) == 7, "base particle should preserve kind")
	_expect(particle.get("color", Color.TRANSPARENT) == Color.RED, "base particle should preserve color")


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_thunder_orb_skill.gd")
	_expect(source.find("LingpetThunderOrbPayloadFactory.build_energy_particle") >= 0, "Thunder Orb should delegate energy-particle payloads")
	_expect(source.find("LingpetThunderOrbPayloadFactory.build_electric_stun_status_data") >= 0, "Thunder Orb should delegate electric stun status data")
	_expect(source.find("LingpetThunderOrbPayloadFactory.build_large_explosion_particle") >= 0, "Thunder Orb should delegate large explosion particles")
	_expect(source.find("LingpetThunderOrbPayloadFactory.build_small_explosion_particle") >= 0, "Thunder Orb should delegate small explosion particles")
	_expect(source.find("_energy_particles.append({") < 0, "Thunder Orb should not inline energy-particle dictionaries")
	_expect(source.find("_explosion_particles.append({") < 0, "Thunder Orb should not inline explosion-particle dictionaries")
	_expect(source.find("\"visual\": \"lumion_thunder_orb\"") < 0, "Thunder Orb should not inline electric stun status data")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_thunder_orb_payload_factory"), "lingpet module catalog should list the Thunder Orb payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_thunder_orb_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_thunder_orb_payload_factory.gd", "top-level module catalog should resolve the Thunder Orb payload factory")


func _color_in(value: Variant, colors: Array[Color]) -> bool:
	if not (value is Color):
		return false
	for color in colors:
		if (value as Color).is_equal_approx(color):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
