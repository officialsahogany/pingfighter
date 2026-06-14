extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetAfterglowLeakPayloadFactory := preload("res://scripts/lingpet/lingpet_afterglow_leak_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_residue_payload()
	_verify_splat_payload()
	_verify_particle_payload()
	_verify_state_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_afterglow_leak_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_residue_payload() -> void:
	var residue: Dictionary = LingpetAfterglowLeakPayloadFactory.build_residue(
		7,
		Vector2(300.0, 712.0),
		Vector2(300.0, 560.0),
		2.8,
		20.0,
		4,
		4.0,
		1.25,
		0.20,
		0.26
	)
	_expect(int(residue.get("id", -1)) == 7, "residue should preserve id")
	_expect(residue.get("pos", Vector2.ZERO) == Vector2(300.0, 712.0), "residue should preserve floor position")
	_expect(residue.get("origin", Vector2.ZERO) == Vector2(300.0, 560.0), "residue should preserve spray origin")
	_expect(is_equal_approx(float(residue.get("timer", 0.0)), 2.8), "residue should preserve timer")
	_expect(is_equal_approx(float(residue.get("duration", 0.0)), 2.8), "residue should preserve duration")
	_expect(is_equal_approx(float(residue.get("emit_timer", 0.0)), 0.20), "residue should preserve emit timer")
	_expect(is_equal_approx(float(residue.get("emit_accum", -1.0)), 0.0), "residue should start with zero emit accumulator")
	_expect(float(residue.get("lean", 99.0)) >= -0.12 and float(residue.get("lean", -99.0)) <= 0.12, "residue should keep lean range")
	_expect((residue.get("splats", []) as Array).is_empty(), "residue should start with no splats")
	_expect(is_equal_approx(float(residue.get("remaining_gauge", 0.0)), 20.0), "residue should preserve remaining gauge")
	_expect(is_equal_approx(float(residue.get("total_gauge", 0.0)), 20.0), "residue should preserve total gauge")
	_expect(is_equal_approx(float(residue.get("tick_gain", 0.0)), 5.0), "residue should derive tick gain from tick count")
	_expect(is_equal_approx(float(residue.get("absorb_accum", -1.0)), 0.0), "residue should start with zero absorb accumulator")
	_expect(is_equal_approx(float(residue.get("absorb_radius", 0.0)), 8.0), "residue should clamp absorb radius")
	_expect(is_equal_approx(float(residue.get("seed", 0.0)), 1.25), "residue should preserve draw seed")
	_expect(is_equal_approx(float(residue.get("absorb_flash", 0.0)), 0.26), "residue should preserve absorb flash timer")


func _verify_splat_payload() -> void:
	var splat: Dictionary = LingpetAfterglowLeakPayloadFactory.build_splat(320.0, 712.0, 0.40)
	_expect(is_equal_approx(float(splat.get("x", 0.0)), 320.0), "splat should preserve x")
	_expect(is_equal_approx(float(splat.get("y", 0.0)), 712.0), "splat should preserve y")
	_expect(is_equal_approx(float(splat.get("born", 0.0)), 0.40), "splat should preserve born time")
	_expect(float(splat.get("size", 0.0)) >= 6.0 and float(splat.get("size", 0.0)) <= 12.0, "splat should keep size range")
	_expect(is_equal_approx(float(splat.get("seed", 0.0)), fmod(absf(320.0 * 0.13 + 0.40 * 7.0), TAU)), "splat should preserve deterministic seed")


func _verify_particle_payload() -> void:
	var particle: Dictionary = LingpetAfterglowLeakPayloadFactory.build_particle(
		Vector2(1.0, 2.0),
		Vector2(3.0, 4.0),
		-0.2,
		5.0,
		3,
		{
			"target": Vector2(9.0, 10.0),
			"floor_y": 712.0,
			"pool_id": 7,
		}
	)
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(1.0, 2.0), "particle should preserve position")
	_expect(particle.get("vel", Vector2.ZERO) == Vector2(3.0, 4.0), "particle should preserve velocity")
	_expect(is_equal_approx(float(particle.get("life", 0.0)), -0.2), "particle should preserve life for caller-owned expiry")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.01), "particle should clamp max life")
	_expect(is_equal_approx(float(particle.get("size", 0.0)), 5.0), "particle should preserve size")
	_expect(int(particle.get("kind", -1)) == 3, "particle should preserve kind")
	_expect(particle.get("target", Vector2.ZERO) == Vector2(9.0, 10.0), "particle should preserve target")
	_expect(is_equal_approx(float(particle.get("floor_y", 0.0)), 712.0), "particle should preserve floor y")
	_expect(int(particle.get("pool_id", -1)) == 7, "particle should preserve pool id")


func _verify_state_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_afterglow_leak_state.gd")
	_expect(source.find("LingpetAfterglowLeakPayloadFactory.build_residue") >= 0, "Afterglow Leak should delegate residue payloads")
	_expect(source.find("LingpetAfterglowLeakPayloadFactory.build_splat") >= 0, "Afterglow Leak should delegate splat payloads")
	_expect(source.find("LingpetAfterglowLeakPayloadFactory.build_particle") >= 0, "Afterglow Leak should delegate particle payloads")
	_expect(source.find("splats.append({") < 0, "Afterglow Leak should not inline splat dictionaries")
	_expect(source.find("_particles.append({") < 0, "Afterglow Leak should not inline particle dictionaries")
	_expect(source.find("var residue := {") < 0, "Afterglow Leak should not inline residue dictionaries")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_afterglow_leak_payload_factory"), "lingpet module catalog should list the Afterglow Leak payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_afterglow_leak_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_afterglow_leak_payload_factory.gd", "top-level module catalog should resolve the Afterglow Leak payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
