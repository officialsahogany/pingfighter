extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetDollCursePayloadFactory := preload("res://scripts/lingpet/lingpet_doll_curse_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_doll_payload()
	_verify_status_payload()
	_verify_destroy_particle_payload()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_doll_curse_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_doll_payload() -> void:
	var spawn_pos := Vector2(230.0, -86.0)
	var target_pos := Vector2(230.0, 624.0)
	var base_angle := -PI * 0.5
	var initial_sweep_half_angle := deg_to_rad(35.0)
	var doll: Dictionary = LingpetDollCursePayloadFactory.build_doll(
		-1,
		spawn_pos,
		target_pos,
		base_angle,
		initial_sweep_half_angle,
		"slow",
		0.75,
		1.25,
		0.85,
		1.45
	)
	_expect(bool(doll.get("alive", false)), "doll payload should start alive")
	_expect(int(doll.get("side", 0)) == -1, "doll payload should preserve side")
	_expect(doll.get("pos", Vector2.ZERO) == spawn_pos, "doll payload should start at sky spawn")
	_expect(doll.get("spawn_pos", Vector2.ZERO) == spawn_pos, "doll payload should preserve sky spawn")
	_expect(doll.get("target_pos", Vector2.ZERO) == target_pos, "doll payload should preserve target")
	_expect(is_equal_approx(float(doll.get("emerge_progress", -1.0)), 0.0), "doll payload should start with zero emerge progress")
	_expect(bool(doll.get("marionette_rigging", false)), "doll payload should carry the marionette rigging contract")
	var beam_angle := float(doll.get("beam_angle", 999.0))
	_expect(beam_angle >= base_angle - initial_sweep_half_angle and beam_angle <= base_angle + initial_sweep_half_angle, "doll payload should keep the original initial beam angle range")
	_expect(is_equal_approx(float(doll.get("beam_target_angle", 0.0)), beam_angle), "doll payload should start target angle at the current beam angle")
	_expect(str(doll.get("beam_sweep_phase", "")) == "slow", "doll payload should start in the slow sweep phase")
	_expect(float(doll.get("beam_sweep_timer", 0.0)) >= 0.75 and float(doll.get("beam_sweep_timer", 0.0)) <= 1.25, "doll payload should keep the slow sweep timer range")
	_expect(float(doll.get("beam_turn_rate", 0.0)) >= 0.85 and float(doll.get("beam_turn_rate", 0.0)) <= 1.45, "doll payload should keep the slow turn-rate range")
	_expect(not bool(doll.get("beam_homing_targeted", true)), "doll payload should not start homing-targeted")
	_expect(not bool(doll.get("beam_homing_focus_active", true)), "doll payload should not start homing-focused")
	_expect(not bool(doll.get("beam_on_boss", true)), "doll payload should not start with boss contact")
	_expect(doll.get("beam_boss_point", Vector2.ONE) == Vector2.ZERO, "doll payload should start with a zero boss contact point")
	_expect(float(doll.get("wobble", -1.0)) >= 0.0 and float(doll.get("wobble", -1.0)) <= TAU, "doll payload should keep the original wobble range")


func _verify_status_payload() -> void:
	var data: Dictionary = LingpetDollCursePayloadFactory.build_confusion_status_data()
	_expect(bool(data.get("cleansable", false)), "confusion status data should stay cleansable")
	_expect(str(data.get("visual", "")) == "koyora_doll_curse", "confusion status data should keep the Doll Curse visual key")


func _verify_destroy_particle_payload() -> void:
	var origin := Vector2(300.0, 560.0)
	var particle: Dictionary = LingpetDollCursePayloadFactory.build_destroy_particle(origin, 0.55)
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	_expect(pos.x >= origin.x - 8.0 and pos.x <= origin.x + 8.0, "destroy particle should keep the original x scatter")
	_expect(pos.y >= origin.y - 10.0 and pos.y <= origin.y + 10.0, "destroy particle should keep the original y scatter")
	var vel: Vector2 = particle.get("vel", Vector2.ZERO)
	_expect(vel.length() >= 55.0 and vel.length() <= 180.0, "destroy particle should keep the original velocity range")
	_expect(float(particle.get("life", 0.0)) >= 0.25 and float(particle.get("life", 0.0)) <= 0.55, "destroy particle should keep the original life range")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.55), "destroy particle should preserve max life")
	_expect(float(particle.get("size", 0.0)) >= 2.0 and float(particle.get("size", 0.0)) <= 5.0, "destroy particle should keep the original size range")


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_doll_curse_skill.gd")
	_expect(source.find("LingpetDollCursePayloadFactory.build_doll") >= 0, "Doll Curse should delegate initial doll payloads")
	_expect(source.find("LingpetDollCursePayloadFactory.build_confusion_status_data") >= 0, "Doll Curse should delegate confusion status data")
	_expect(source.find("LingpetDollCursePayloadFactory.build_destroy_particle") >= 0, "Doll Curse should delegate destroy particle payloads")
	_expect(source.find("_dolls.append({") < 0, "Doll Curse should not inline doll dictionaries")
	_expect(source.find("_destroy_particles.append({") < 0, "Doll Curse should not inline destroy particle dictionaries")
	_expect(source.find("\"visual\": \"koyora_doll_curse\"") < 0, "Doll Curse should not inline confusion status data")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_doll_curse_payload_factory"), "lingpet module catalog should list the Doll Curse payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_doll_curse_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_doll_curse_payload_factory.gd", "top-level module catalog should resolve the Doll Curse payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
