extends SceneTree

const LingpetCompanionSkillUpdateContextBuilder := preload("res://scripts/lingpet/lingpet_companion_skill_update_context_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_context_preserves_runtime_fields()
	_verify_active_skill_defaults()
	_verify_runtime_delegates_context_assembly()

	if _failures.is_empty():
		print("lingpet_companion_skill_update_context_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_context_preserves_runtime_fields() -> void:
	var builder := LingpetCompanionSkillUpdateContextBuilder.new()
	var owner := RefCounted.new()
	var registry := RefCounted.new()
	var skill_state := RefCounted.new()
	var skill_runtime_host := RefCounted.new()
	var context := builder.build(
		"companion",
		"companion",
		owner,
		registry,
		"monkeyring_wild_roar",
		skill_state,
		skill_runtime_host,
		0.35,
		true,
		Vector2(300.0, 410.0),
		Vector2(0.0, -12.0),
		28.6,
		true,
		false,
		Vector2(280.0, 640.0),
		16.0,
		54.0,
		{
			"level": 4,
			"roar_radius": 234.0,
			"ball_boost": 3.35,
		},
		2,
		1,
		["maribo_hydro_sphere", "monkeyring_wild_roar"],
		[null, skill_state]
	)
	_expect_str(str(context.get("state", "")), "companion", "context should preserve runtime state")
	_expect(context.get("owner") == owner, "context should preserve owner object identity")
	_expect(context.get("registry") == registry, "context should preserve registry object identity")
	_expect(context.get("skill_state") == skill_state, "context should preserve skill state object identity")
	_expect(context.get("skill_runtime_host") == skill_runtime_host, "context should preserve runtime host object identity")
	_expect_float(float(context.get("windup_seconds", 0.0)), 0.35, "context should preserve windup seconds")
	_expect(context.get("ball_active") == true, "context should preserve ball-active flag")
	_expect_eq(context.get("ball_pos"), Vector2(300.0, 410.0), "context should preserve ball position")
	_expect_eq(context.get("ball_vel"), Vector2(0.0, -12.0), "context should preserve ball velocity")
	_expect_float(float(context.get("ball_size", 0.0)), 28.6, "context should preserve ball size")
	_expect(context.get("switch_transition_active") == true, "context should preserve switch transition flag")
	_expect(context.get("companion_visible") == false, "context should preserve companion visibility")
	_expect_eq(context.get("companion_pos"), Vector2(280.0, 640.0), "context should preserve companion position")
	_expect_float(float(context.get("companion_radius", 0.0)), 16.0, "context should preserve companion radius")
	_expect_float(float(context.get("companion_catch_height", 0.0)), 54.0, "context should preserve companion catch height")
	_expect_eq(int(context.get("active_skill_level", 0)), 4, "context should prefer active skill level")
	_expect_eq(int(context.get("slot_index", -1)), 1, "context should preserve active skill slot index")
	_expect_eq(context.get("active_skill_ids", []), ["maribo_hydro_sphere", "monkeyring_wild_roar"], "context should preserve active skill id list")
	_expect_eq(context.get("skill_states", []), [null, skill_state], "context should preserve skill state list")
	_expect_float(float(context.get("roar_radius", 0.0)), 234.0, "context should preserve Wild Roar radius")
	_expect_float(float(context.get("ball_boost", 0.0)), 3.35, "context should preserve Wild Roar ball boost")


func _verify_active_skill_defaults() -> void:
	var builder := LingpetCompanionSkillUpdateContextBuilder.new()
	var context := builder.build(
		"companion",
		"companion",
		null,
		null,
		"maribo_hydro_sphere",
		null,
		null,
		0.5,
		false,
		Vector2.ZERO,
		Vector2.ZERO,
		28.6,
		false,
		true,
		Vector2.ZERO,
		16.0,
		44.0,
		{},
		3,
		0,
		["maribo_hydro_sphere"],
		[null]
	)
	_expect_eq(int(context.get("active_skill_level", 0)), 3, "context should use active skill level fallback")
	_expect_float(float(context.get("roar_radius", 0.0)), -1.0, "roar radius should default disabled")
	_expect_float(float(context.get("ball_boost", 0.0)), -1.0, "ball boost should default disabled")


func _verify_runtime_delegates_context_assembly() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var builder_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_update_context_builder.gd")
	_expect(runtime_source.find("LingpetCompanionSkillUpdateContextBuilder") >= 0, "egg runtime should preload the companion skill update context builder")
	_expect(runtime_source.find("_companion_skill_update_context_builder.build") >= 0, "runtime skill-effect hook should delegate update context assembly")
	_expect(runtime_source.find("\"companion_catch_height\": _get_current_stat") < 0, "runtime should not keep the catch-height context field inline")
	_expect(runtime_source.find("\"roar_radius\": float(current_active_skill.get") < 0, "runtime should not keep Wild Roar numeric context fields inline")
	_expect(builder_source.find("\"companion_catch_height\"") >= 0, "builder should own companion catch-height context key")
	_expect(builder_source.find("\"roar_radius\"") >= 0 and builder_source.find("\"ball_boost\"") >= 0, "builder should own Wild Roar flattened level context keys")


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
