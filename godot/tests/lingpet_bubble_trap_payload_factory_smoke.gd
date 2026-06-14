extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetBubbleTrapPayloadFactory := preload("res://scripts/lingpet/lingpet_bubble_trap_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_projectile_payload()
	_verify_particle_payload()
	_verify_burst_particle_payload()
	_verify_stun_status_payload()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_bubble_trap_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_projectile_payload() -> void:
	var projectile: Dictionary = LingpetBubbleTrapPayloadFactory.build_projectile(Vector2(320.0, 640.0), 220.0, 0.25, 1.04)
	_expect(projectile.get("pos", Vector2.ZERO) == Vector2(320.0, 640.0), "projectile should preserve launch position")
	_expect(projectile.get("vel", Vector2.ZERO) == Vector2(0.0, -220.0), "projectile should preserve launch speed")
	_expect(is_equal_approx(float(projectile.get("age", -1.0)), 0.0), "projectile age should start at zero")
	_expect(is_equal_approx(float(projectile.get("origin_x", 0.0)), 320.0), "projectile should preserve origin x")
	_expect(is_equal_approx(float(projectile.get("phase", 0.0)), 0.25 * TAU), "projectile phase should derive from visual seed")
	_expect(is_equal_approx(float(projectile.get("visual_seed", 0.0)), 0.25), "projectile should preserve visual seed")
	_expect(is_equal_approx(float(projectile.get("radius_scale", 0.0)), 1.04), "projectile should preserve radius scale")
	var trail: Array = projectile.get("trail", []) as Array
	_expect(trail.size() == 1 and trail[0] == Vector2(320.0, 640.0), "projectile should start with a one-point trail")


func _verify_particle_payload() -> void:
	var particle: Dictionary = LingpetBubbleTrapPayloadFactory.build_particle(Vector2(10.0, 12.0), Vector2(4.0, -5.0), 0.44, 3.3)
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(10.0, 12.0), "base particle should preserve position")
	_expect(particle.get("vel", Vector2.ZERO) == Vector2(4.0, -5.0), "base particle should preserve velocity")
	_expect(is_equal_approx(float(particle.get("life", 0.0)), 0.44), "base particle should preserve life")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.44), "base particle should copy max life")
	_expect(is_equal_approx(float(particle.get("size", 0.0)), 3.3), "base particle should preserve size")


func _verify_burst_particle_payload() -> void:
	var origin := Vector2(260.0, 70.0)
	var particle: Dictionary = LingpetBubbleTrapPayloadFactory.build_burst_particle(origin, 0.65)
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	_expect(pos.x >= origin.x - 8.0 and pos.x <= origin.x + 8.0, "burst particle should use the original x scatter")
	_expect(pos.y >= origin.y - 8.0 and pos.y <= origin.y + 8.0, "burst particle should use the original y scatter")
	_expect(particle.get("vel", Vector2.ZERO) is Vector2, "burst particle should carry velocity")
	_expect(float(particle.get("life", 0.0)) >= 0.28 and float(particle.get("life", 0.0)) <= 0.62, "burst particle life should stay in range")
	_expect(float(particle.get("size", 0.0)) >= 2.4 and float(particle.get("size", 0.0)) <= 5.8, "burst particle size should stay in range")


func _verify_stun_status_payload() -> void:
	var data: Dictionary = LingpetBubbleTrapPayloadFactory.build_stun_status_data()
	_expect(bool(data.get("cleansable", false)), "stun status should remain cleansable")
	_expect(str(data.get("visual", "")) == "maribo_bubble_trap", "stun status should keep the Bubble Trap visual key")
	_expect(bool(data.get("suppress_stun_stars", false)), "stun status should suppress legacy stun stars")


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_bubble_trap_skill.gd")
	_expect(source.find("LingpetBubbleTrapPayloadFactory.build_projectile") >= 0, "Bubble Trap should delegate projectile payloads")
	_expect(source.find("LingpetBubbleTrapPayloadFactory.build_burst_particle") >= 0, "Bubble Trap should delegate burst particles")
	_expect(source.find("LingpetBubbleTrapPayloadFactory.build_stun_status_data") >= 0, "Bubble Trap should delegate stun status payload data")
	_expect(source.find("_projectiles.append({") < 0, "Bubble Trap should not inline projectile dictionaries")
	_expect(source.find("_particles.append({") < 0, "Bubble Trap should not inline particle dictionaries")
	_expect(source.find("\"visual\": \"maribo_bubble_trap\"") < 0, "Bubble Trap should not inline stun status data")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_bubble_trap_payload_factory"), "lingpet module catalog should list the Bubble Trap payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_bubble_trap_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_bubble_trap_payload_factory.gd", "top-level module catalog should resolve the Bubble Trap payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
