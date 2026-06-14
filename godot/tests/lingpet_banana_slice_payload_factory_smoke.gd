extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetBananaSlicePayloadFactory := preload("res://scripts/lingpet/lingpet_banana_slice_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_projectile_payload()
	_verify_landed_banana_payload()
	_verify_burst_particle_payload()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_banana_slice_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_projectile_payload() -> void:
	var projectile: Dictionary = LingpetBananaSlicePayloadFactory.build_projectile(
		Vector2(300.0, 590.0),
		420.0,
		1,
		45.0,
		30.0,
		6.0,
		-20.0,
		0.15
	)
	_expect(projectile.get("position", Vector2.ZERO) == Vector2(300.0, 590.0), "projectile should preserve the launch position")
	_expect(projectile.get("target_position", Vector2.ZERO) == Vector2(420.0, 45.0), "projectile should preserve the target x and land y")
	_expect(projectile.get("velocity", Vector2.ZERO) == Vector2(4.0, -20.0), "projectile should keep the original Banana Slice aim math")
	_expect(is_equal_approx(float(projectile.get("delay", -1.0)), 0.15), "second projectile should keep the staged launch delay")
	_expect(is_equal_approx(float(projectile.get("rotation_degrees", -1.0)), 0.0), "projectile rotation should start at zero")
	_expect(absf(float(projectile.get("rotation_speed_degrees", 0.0))) >= 480.0, "rotation speed should stay inside the original lower bound")
	_expect(absf(float(projectile.get("rotation_speed_degrees", 0.0))) <= 900.0, "rotation speed should stay inside the original upper bound")
	var trail: Array = projectile.get("trail", []) as Array
	_expect(trail.size() == 1 and trail[0] == Vector2(300.0, 590.0), "projectile should start with a one-point trail")

	var centered: Dictionary = LingpetBananaSlicePayloadFactory.build_projectile(
		Vector2(300.0, 590.0),
		300.0,
		0,
		45.0,
		30.0,
		6.0,
		-20.0,
		0.15
	)
	_expect(centered.get("velocity", Vector2.ZERO) == Vector2(0.0, -20.0), "centered projectile should not drift horizontally")


func _verify_landed_banana_payload() -> void:
	var landed: Dictionary = LingpetBananaSlicePayloadFactory.build_landed_banana(Vector2(900.0, 111.0), 30.0, 730.0, 45.0, 3.0)
	_expect(landed.get("position", Vector2.ZERO) == Vector2(730.0, 45.0), "landed banana should clamp x and pin y")
	_expect(is_equal_approx(float(landed.get("timer", 0.0)), 3.0), "landed banana should keep the live timer")
	_expect(is_equal_approx(float(landed.get("max_timer", 0.0)), 3.0), "landed banana should keep the max timer")
	_expect(not bool(landed.get("slip_triggered", true)), "landed banana should start untriggered")

	var expired: Dictionary = LingpetBananaSlicePayloadFactory.build_landed_banana(Vector2(10.0, 0.0), 30.0, 730.0, 45.0, -1.0)
	_expect(is_equal_approx(float(expired.get("timer", -1.0)), 0.0), "test-forced landed bananas should clamp negative timers to zero")
	var forced: Dictionary = LingpetBananaSlicePayloadFactory.build_landed_banana(Vector2(10.0, 0.0), 30.0, 730.0, 45.0, -1.0, 3.0)
	_expect(is_equal_approx(float(forced.get("max_timer", 0.0)), 3.0), "test-forced landed bananas should preserve the original max timer")


func _verify_burst_particle_payload() -> void:
	var particle: Dictionary = LingpetBananaSlicePayloadFactory.build_burst_particle(Vector2(260.0, 45.0))
	_expect(particle.get("position", Vector2.ZERO) == Vector2(260.0, 45.0), "burst particle should preserve the slip position")
	_expect(particle.get("velocity", Vector2.ZERO) is Vector2, "burst particle should carry a velocity vector")
	_expect(float(particle.get("life", 0.0)) >= 0.33 and float(particle.get("life", 0.0)) <= 0.67, "burst particle life should stay in the original range")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.67), "burst particle max life should stay pinned")
	_expect(float(particle.get("size", 0.0)) >= 3.0 and float(particle.get("size", 0.0)) <= 7.0, "burst particle size should stay in the original range")
	var color: Color = particle.get("color", Color.TRANSPARENT)
	_expect(color.a > 0.99, "burst particle should use an opaque banana-chip color")


func _verify_skill_delegation_and_catalog() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_banana_slice_skill.gd")
	_expect(skill_source.find("LingpetBananaSlicePayloadFactory.build_projectile") >= 0, "Banana Slice skill should delegate projectile payloads")
	_expect(skill_source.find("LingpetBananaSlicePayloadFactory.build_landed_banana") >= 0, "Banana Slice skill should delegate landed payloads")
	_expect(skill_source.find("LingpetBananaSlicePayloadFactory.build_burst_particle") >= 0, "Banana Slice skill should delegate burst particle payloads")
	_expect(skill_source.find("_projectiles.append({") < 0, "Banana Slice skill should not inline projectile dictionaries")
	_expect(skill_source.find("_landed_bananas.append({") < 0, "Banana Slice skill should not inline landed banana dictionaries")
	_expect(skill_source.find("_particles.append({") < 0, "Banana Slice skill should not inline burst particle dictionaries")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_banana_slice_payload_factory"), "lingpet module catalog should list the Banana Slice payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_banana_slice_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_banana_slice_payload_factory.gd", "top-level module catalog should resolve the Banana Slice payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
