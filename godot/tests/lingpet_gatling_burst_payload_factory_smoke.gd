extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetGatlingBurstPayloadFactory := preload("res://scripts/lingpet/lingpet_gatling_burst_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_bullet_payload()
	_verify_stun_status_payload()
	_verify_particle_payloads()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_gatling_burst_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_bullet_payload() -> void:
	var direction := Vector2.RIGHT
	var bullet: Dictionary = LingpetGatlingBurstPayloadFactory.build_bullet(Vector2(300.0, 200.0), direction, 620.0, 0.25, 5)
	_expect(bullet.get("pos", Vector2.ZERO) == Vector2(300.0, 200.0), "bullet should preserve muzzle position")
	_expect(bullet.get("vel", Vector2.ZERO) == Vector2(620.0, 0.0), "bullet should preserve direction and speed")
	_expect(is_equal_approx(float(bullet.get("age", -1.0)), 0.0), "bullet age should start at zero")
	_expect(is_equal_approx(float(bullet.get("angle", 0.0)), 0.25), "bullet should preserve aim angle")
	_expect(bool(bullet.get("tracer", false)), "every fifth Gatling shot should be a tracer")

	var non_tracer: Dictionary = LingpetGatlingBurstPayloadFactory.build_bullet(Vector2.ZERO, direction, 620.0, 0.0, 4)
	_expect(not bool(non_tracer.get("tracer", true)), "non-fifth Gatling shots should not be tracers")


func _verify_stun_status_payload() -> void:
	var status_data: Dictionary = LingpetGatlingBurstPayloadFactory.build_ak47_stun_status_data(-17.5, 9.0, 0.77, "volty_gatling_burst")
	_expect(is_equal_approx(float(status_data.get("knockback_vel", 0.0)), -17.5), "stun status should preserve knockback velocity")
	_expect(bool(status_data.get("knockback_active", false)), "non-zero knockback should be marked active")
	_expect(is_equal_approx(float(status_data.get("knockback_frames", 0.0)), 9.0), "stun status should preserve knockback frame count")
	_expect(is_equal_approx(float(status_data.get("knockback_decay_per_frame", 0.0)), 0.77), "stun status should preserve knockback decay")
	_expect(str(status_data.get("source", "")) == "volty_gatling_burst", "stun status should preserve source")


func _verify_particle_payloads() -> void:
	var hit_particle: Dictionary = LingpetGatlingBurstPayloadFactory.build_hit_particle(Vector2(330.0, 70.0), -PI * 0.5, 3)
	_expect(hit_particle.get("pos", Vector2.ZERO) == Vector2(330.0, 70.0), "hit particle should preserve hit position")
	_expect(hit_particle.get("vel", Vector2.ZERO) is Vector2, "hit particle should carry velocity")
	_expect(float(hit_particle.get("life", 0.0)) >= 0.15 and float(hit_particle.get("life", 0.0)) <= 0.35, "hit particle life should stay in the original range")
	_expect(is_equal_approx(float(hit_particle.get("age", -1.0)), 0.0), "hit particle age should start at zero")
	_expect(float(hit_particle.get("size", 0.0)) >= 1.5 and float(hit_particle.get("size", 0.0)) <= 4.0, "hit particle size should stay in the original range")
	_expect(bool(hit_particle.get("ember", false)), "every third hit particle should be ember-colored")

	var casing: Dictionary = LingpetGatlingBurstPayloadFactory.build_shell_casing(Vector2(300.0, 200.0), Vector2.RIGHT)
	_expect(casing.get("pos", Vector2.ZERO) == Vector2(300.0, 200.0), "shell casing should preserve muzzle position")
	_expect(casing.get("vel", Vector2.ZERO) is Vector2, "shell casing should carry velocity")
	_expect(is_equal_approx(float(casing.get("gravity", 0.0)), 500.0), "shell casing gravity should stay pinned")
	_expect(is_equal_approx(float(casing.get("age", -1.0)), 0.0), "shell casing age should start at zero")
	_expect(is_equal_approx(float(casing.get("life", 0.0)), 0.5), "shell casing life should stay pinned")
	_expect(float(casing.get("rotation", -1.0)) >= 0.0 and float(casing.get("rotation", -1.0)) <= TAU, "shell casing rotation should stay in the original range")
	_expect(float(casing.get("rot_speed", 0.0)) >= 8.0 and float(casing.get("rot_speed", 0.0)) <= 20.0, "shell casing rotation speed should stay in the original range")

	var smoke: Dictionary = LingpetGatlingBurstPayloadFactory.build_muzzle_smoke(Vector2(300.0, 200.0), Vector2.RIGHT)
	_expect(smoke.get("pos", Vector2.ZERO) == Vector2(296.0, 200.0), "muzzle smoke should spawn just behind the muzzle")
	_expect(smoke.get("vel", Vector2.ZERO) is Vector2, "muzzle smoke should carry velocity")
	_expect(is_equal_approx(float(smoke.get("age", -1.0)), 0.0), "muzzle smoke age should start at zero")
	_expect(float(smoke.get("life", 0.0)) >= 0.18 and float(smoke.get("life", 0.0)) <= 0.34, "muzzle smoke life should stay in the original range")
	_expect(float(smoke.get("size", 0.0)) >= 4.0 and float(smoke.get("size", 0.0)) <= 8.0, "muzzle smoke size should stay in the original range")


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_gatling_burst_skill.gd")
	_expect(source.find("LingpetGatlingBurstPayloadFactory.build_bullet") >= 0, "Gatling Burst should delegate bullet payloads")
	_expect(source.find("LingpetGatlingBurstPayloadFactory.build_ak47_stun_status_data") >= 0, "Gatling Burst should delegate stun status payloads")
	_expect(source.find("LingpetGatlingBurstPayloadFactory.build_hit_particle") >= 0, "Gatling Burst should delegate hit particle payloads")
	_expect(source.find("LingpetGatlingBurstPayloadFactory.build_shell_casing") >= 0, "Gatling Burst should delegate shell casing payloads")
	_expect(source.find("LingpetGatlingBurstPayloadFactory.build_muzzle_smoke") >= 0, "Gatling Burst should delegate muzzle smoke payloads")
	_expect(source.find("_bullets.append({") < 0, "Gatling Burst should not inline bullet dictionaries")
	_expect(source.find("_hit_particles.append({") < 0, "Gatling Burst should not inline hit particle dictionaries")
	_expect(source.find("_shell_casings.append({") < 0, "Gatling Burst should not inline shell casing dictionaries")
	_expect(source.find("_smoke_puffs.append({") < 0, "Gatling Burst should not inline muzzle smoke dictionaries")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_gatling_burst_payload_factory"), "lingpet module catalog should list the Gatling Burst payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_gatling_burst_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_gatling_burst_payload_factory.gd", "top-level module catalog should resolve the Gatling Burst payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
