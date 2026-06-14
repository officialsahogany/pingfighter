extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetGhostSummonPayloadFactory := preload("res://scripts/lingpet/lingpet_ghost_summon_payload_factory.gd")

const TELEPORT_TEST_COLORS: Array[Color] = [
	Color(0.36, 0.92, 0.82, 0.68),
	Color(0.55, 1.0, 0.90, 0.74),
	Color(0.25, 0.72, 0.62, 0.62),
]


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_ghost_payload()
	_verify_dying_ghost_payload()
	_verify_particle_payload()
	_verify_teleport_particle_payload()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_ghost_summon_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_ghost_payload() -> void:
	var ghost: Dictionary = LingpetGhostSummonPayloadFactory.build_ghost(2, Vector2(380.0, 650.0), 325.0, 0.0, 760.0)
	var target_pos: Vector2 = ghost.get("target_pos", Vector2.ZERO)
	_expect(int(ghost.get("id", -1)) == 2, "Ghost Summon ghost should preserve id")
	_expect(ghost.get("pos", Vector2.ZERO) == Vector2(380.0, 650.0), "Ghost Summon ghost should preserve position")
	_expect(ghost.get("start_pos", Vector2.ZERO) == Vector2(380.0, 650.0), "Ghost Summon ghost should preserve start position")
	_expect(target_pos.x >= 100.0 and target_pos.x <= 660.0, "Ghost Summon ghost should keep target x inside the original launch range")
	_expect(is_equal_approx(target_pos.y, 325.0), "Ghost Summon ghost should preserve target y")
	_expect(is_equal_approx(float(ghost.get("spawn_time", -1.0)), 0.0), "Ghost Summon ghost should start with zero spawn time")
	_expect(float(ghost.get("vx", -99.0)) >= -5.0 and float(ghost.get("vx", 99.0)) <= 5.0, "Ghost Summon ghost should keep original drift range")
	_expect(not bool(ghost.get("eating", true)), "Ghost Summon ghost should not start eating")
	_expect(not bool(ghost.get("teleporting", true)), "Ghost Summon ghost should not start teleporting")
	_expect(str(ghost.get("teleport_phase", "x")) == "", "Ghost Summon ghost should start without a teleport phase")
	_expect(is_equal_approx(float(ghost.get("teleport_target_x", 0.0)), target_pos.x), "Ghost Summon ghost should mirror target x into teleport target")
	_expect(ghost.get("pre_teleport_pos", Vector2.ZERO) == Vector2(380.0, 650.0), "Ghost Summon ghost should preserve pre-teleport position")
	_expect(float(ghost.get("phase", -1.0)) >= 0.0 and float(ghost.get("phase", -1.0)) <= TAU, "Ghost Summon ghost should keep phase in range")


func _verify_dying_ghost_payload() -> void:
	var dying: Dictionary = LingpetGhostSummonPayloadFactory.build_dying_ghost(Vector2(100.0, 200.0), 1.25)
	_expect(dying.get("pos", Vector2.ZERO) == Vector2(100.0, 200.0), "dying ghost should preserve position")
	_expect(is_equal_approx(float(dying.get("death_timer", -1.0)), 0.0), "dying ghost should start with zero death timer")
	_expect(is_equal_approx(float(dying.get("phase", 0.0)), 1.25), "dying ghost should preserve phase")


func _verify_particle_payload() -> void:
	var particle: Dictionary = LingpetGhostSummonPayloadFactory.build_particle(
		Vector2(1.0, 2.0),
		Vector2(3.0, 4.0),
		-0.2,
		6.0,
		Color(0.50, 1.0, 0.86, 0.72)
	)
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(1.0, 2.0), "particle should preserve position")
	_expect(particle.get("vel", Vector2.ZERO) == Vector2(3.0, 4.0), "particle should preserve velocity")
	_expect(is_equal_approx(float(particle.get("life", 0.0)), 0.05), "particle should clamp life")
	_expect(is_equal_approx(float(particle.get("age", -1.0)), 0.0), "particle should start with zero age")
	_expect(is_equal_approx(float(particle.get("size", 0.0)), 6.0), "particle should preserve size")
	_expect(particle.get("color", Color.TRANSPARENT) == Color(0.50, 1.0, 0.86, 0.72), "particle should preserve color")


func _verify_teleport_particle_payload() -> void:
	var origin := Vector2(380.0, 320.0)
	var outward: Dictionary = LingpetGhostSummonPayloadFactory.build_teleport_particle(origin, 1.0, false)
	_expect(_teleport_particle_inside_ranges(outward, origin, 1.0, false), "outward teleport particle should keep the original range")
	var inward: Dictionary = LingpetGhostSummonPayloadFactory.build_teleport_particle(origin, 0.5, true)
	_expect(_teleport_particle_inside_ranges(inward, origin, 0.5, true), "inward teleport particle should keep the original range")


func _teleport_particle_inside_ranges(particle: Dictionary, origin: Vector2, ratio: float, inward: bool) -> bool:
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	var offset := pos - origin
	if offset.length() > 40.0 * clampf(ratio, 0.0, 1.0) + 0.01:
		return false
	var vel: Vector2 = particle.get("vel", Vector2.ZERO)
	if offset.length() > 0.001:
		var radial := offset.normalized()
		var dot := vel.dot(radial)
		if inward and dot >= 0.0:
			return false
		if not inward and dot <= 0.0:
			return false
	if float(particle.get("life", 0.0)) < 0.3 or float(particle.get("life", 0.0)) > 0.8:
		return false
	if not is_equal_approx(float(particle.get("age", -1.0)), 0.0):
		return false
	if float(particle.get("size", 0.0)) < 3.0 or float(particle.get("size", 0.0)) > 8.0:
		return false
	return _color_in(particle.get("color", Color.TRANSPARENT), TELEPORT_TEST_COLORS)


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_ghost_summon_skill.gd")
	_expect(source.find("LingpetGhostSummonPayloadFactory.build_ghost") >= 0, "Ghost Summon should delegate ghost payloads")
	_expect(source.find("LingpetGhostSummonPayloadFactory.build_dying_ghost") >= 0, "Ghost Summon should delegate dying-ghost payloads")
	_expect(source.find("LingpetGhostSummonPayloadFactory.build_teleport_particle") >= 0, "Ghost Summon should delegate teleport particle payloads")
	_expect(source.find("LingpetGhostSummonPayloadFactory.build_particle") >= 0, "Ghost Summon should delegate normal particle payloads")
	_expect(source.find("_dying_ghosts.append({") < 0, "Ghost Summon should not inline dying-ghost dictionaries")
	_expect(source.find("_particles.append({") < 0, "Ghost Summon should not inline particle dictionaries")
	_expect(source.find("var particle := {") < 0, "Ghost Summon should not inline teleport particle dictionaries")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_ghost_summon_payload_factory"), "lingpet module catalog should list the Ghost Summon payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_ghost_summon_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_ghost_summon_payload_factory.gd", "top-level module catalog should resolve the Ghost Summon payload factory")


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
