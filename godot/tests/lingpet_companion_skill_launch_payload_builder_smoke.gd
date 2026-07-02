extends SceneTree

const LingpetCompanionSkillLaunchPayloadBuilder := preload("res://scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_payload_overrides_and_identity_fields()
	_verify_default_payload_fallbacks()
	_verify_runtime_delegates_payload_assembly()

	if _failures.is_empty():
		print("lingpet_companion_skill_launch_payload_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_payload_overrides_and_identity_fields() -> void:
	var builder := LingpetCompanionSkillLaunchPayloadBuilder.new()
	var registry := RefCounted.new()
	var payload: Dictionary = builder.build(
		{
			"id": "volty_gatling_burst",
			"level": 4,
			"refire_chance_pct": 72.5,
			"beam_homing_chance_pct": 95.0,
			"banana_count": 6.0,
			"clone_count": 3.0,
			"duration_seconds": 20.0,
			"barrier_width": 88.0,
			"headbutt_count": 3.0,
			"mega_stun_seconds": 1.25,
		},
		"fallback_skill",
		2,
		Vector2(120.0, 340.0),
		16.0,
		registry
	)
	_expect_eq(payload.get("companion_pos"), Vector2(120.0, 340.0), "payload should preserve companion launch position")
	_expect_float(float(payload.get("companion_radius", 0.0)), 16.0, "payload should preserve companion radius")
	_expect(payload.get("registry") == registry, "payload should preserve registry object identity")
	_expect_str(str(payload.get("active_skill_id", "")), "volty_gatling_burst", "payload should prefer active-skill id over fallback id")
	_expect_eq(int(payload.get("active_skill_level", 0)), 4, "payload should prefer active-skill level over fallback level")
	_expect_float(float(payload.get("refire_chance_pct", 0.0)), 72.5, "payload should forward refire chance")
	_expect_float(float(payload.get("beam_homing_chance_pct", 0.0)), 95.0, "payload should forward Doll Curse beam homing chance")
	_expect_float(float(payload.get("banana_count", 0.0)), 6.0, "payload should forward banana count")
	_expect_float(float(payload.get("clone_count", 0.0)), 3.0, "payload should forward clone count")
	_expect_float(float(payload.get("duration_seconds", 0.0)), 20.0, "payload should forward skill duration")
	_expect_float(float(payload.get("barrier_width", 0.0)), 88.0, "payload should forward barrier width")
	_expect_float(float(payload.get("headbutt_count", 0.0)), 3.0, "payload should forward headbutt count")
	_expect_float(float(payload.get("mega_stun_seconds", 0.0)), 1.25, "payload should forward mega stun seconds")


func _verify_default_payload_fallbacks() -> void:
	var builder := LingpetCompanionSkillLaunchPayloadBuilder.new()
	var payload: Dictionary = builder.build({}, "maribo_hydro_sphere", 3, Vector2.ZERO, 12.0, null)
	_expect_str(str(payload.get("active_skill_id", "")), "maribo_hydro_sphere", "empty active skill should use fallback id")
	_expect_eq(int(payload.get("active_skill_level", 0)), 3, "empty active skill should use fallback level")
	_expect_float(float(payload.get("refire_chance_pct", 0.0)), 50.0, "refire chance should keep its historical fallback")
	_expect_float(float(payload.get("beam_homing_chance_pct", 0.0)), -1.0, "beam homing chance should default disabled")
	_expect_float(float(payload.get("stun_duration_seconds", -1.0)), 0.0, "stun duration should keep zero fallback")
	_expect_float(float(payload.get("explosion_radius", -1.0)), 0.0, "explosion radius should keep zero fallback")
	_expect_float(float(payload.get("golden_chance_pct", 0.0)), -1.0, "golden chance should default disabled")
	_expect_float(float(payload.get("mega_knockback_bonus_pct", 0.0)), -1.0, "mega knockback bonus should default disabled")
	_expect_float(float(payload.get("mega_stun_seconds", 0.0)), -1.0, "mega stun should default disabled")


func _verify_runtime_delegates_payload_assembly() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var builder_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd")
	_expect(runtime_source.find("LingpetCompanionSkillLaunchPayloadBuilder") >= 0, "egg runtime should preload the companion skill launch payload builder")
	_expect(runtime_source.find("_companion_skill_launch_payload_builder.build") >= 0, "egg runtime launch path should delegate payload assembly")
	_expect(runtime_source.find("\"mega_knockback_bonus_pct\": float(current_active_skill.get") < 0, "egg runtime should not keep the launch payload field list inline")
	_expect(builder_source.find("FLOAT_PAYLOAD_DEFAULTS") >= 0, "payload builder should own numeric launch payload defaults")
	_expect(builder_source.find("mega_knockback_bonus_pct") >= 0, "payload builder should preserve late-skill payload fields")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected '%s', got '%s')" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.01) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
