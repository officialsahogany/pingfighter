extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetSoulClonePayloadFactory := preload("res://scripts/lingpet/lingpet_soul_clone_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	_verify_particle_payload()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_soul_clone_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_particle_payload() -> void:
	var particle: Dictionary = LingpetSoulClonePayloadFactory.build_particle(
		Vector2(1.0, 2.0),
		Vector2(3.0, 4.0),
		-0.2,
		-9.0,
		Color(0.48, 0.88, 1.0, 0.42)
	)
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(1.0, 2.0), "Soul Clone particle should preserve position")
	_expect(particle.get("vel", Vector2.ZERO) == Vector2(3.0, 4.0), "Soul Clone particle should preserve velocity")
	_expect(is_equal_approx(float(particle.get("life", 0.0)), 0.05), "Soul Clone particle should clamp life")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.05), "Soul Clone particle should clamp max life")
	_expect(is_equal_approx(float(particle.get("radius", 0.0)), 0.5), "Soul Clone particle should clamp radius")
	_expect(particle.get("color", Color.TRANSPARENT) == Color(0.48, 0.88, 1.0, 0.42), "Soul Clone particle should preserve color")


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_soul_clone_skill.gd")
	_expect(source.find("LingpetSoulClonePayloadFactory.build_particle") >= 0, "Soul Clone should delegate particle payloads")
	_expect(source.find("_particles.append({") < 0, "Soul Clone should not inline particle dictionaries")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_soul_clone_payload_factory"), "lingpet module catalog should list the Soul Clone payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_soul_clone_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_soul_clone_payload_factory.gd", "top-level module catalog should resolve the Soul Clone payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
