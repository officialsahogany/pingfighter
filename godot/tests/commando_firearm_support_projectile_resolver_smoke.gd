extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmSupportProjectileResolver := preload("res://scripts/characters/commando_firearm_support_projectile_resolver.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_support_projectile_resolver()
	_verify_runtime_delegates_support_projectile_resolver()

	if _failures.is_empty():
		print("commando_firearm_support_projectile_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_support_projectile_resolver() -> void:
	var profile := _support_profile()
	var projectile: Dictionary = CommandoFirearmSupportProjectileResolver.build_projectile(
		Vector2(320.0, 180.0),
		profile,
		"fire_support",
		99,
		4,
		2,
		760.0,
		750.0,
		52.0,
		1.0,
		0.08,
		0.65
	)
	_expect(int(projectile.get("id", 0)) == 99, "support projectile should preserve assigned projectile id")
	_expect(str(projectile.get("weapon_id", "")) == "fire_support", "support projectile should preserve weapon id")
	_expect(int(projectile.get("support_call_id", 0)) == 4, "support projectile should preserve call id")
	_expect(int(projectile.get("support_spawn_index", 0)) == 2, "support projectile should preserve spawn index")
	_expect_vec(_get_vector2(projectile.get("pos", Vector2.ZERO)), Vector2(320.0, 71.0), "support projectile start position should preserve deterministic aircraft drop row")
	_expect_vec(_get_vector2(projectile.get("target", Vector2.ZERO)), Vector2(320.0, 180.0), "support projectile target should preserve deterministic target y")
	_expect_vec(_get_vector2(projectile.get("velocity", Vector2.ZERO)), Vector2(-0.26325, 1.0), "support projectile velocity should preserve deterministic jitter")
	_expect(is_equal_approx(float(projectile.get("speed", 0.0)), Vector2(-0.26325, 1.0).length()), "support projectile speed should match velocity length")
	_expect(is_equal_approx(float(projectile.get("gravity", 0.0)), 0.08), "support projectile gravity should preserve profile/default value")
	_expect(is_equal_approx(float(projectile.get("explosion_radius", 0.0)), 152.0), "support projectile explosion radius should preserve profile/default value")

	var clamped: Dictionary = CommandoFirearmSupportProjectileResolver.build_projectile(
		Vector2(-20.0, 10.0),
		profile,
		"fire_support",
		100,
		1,
		0,
		760.0,
		750.0,
		52.0,
		1.0,
		0.08,
		0.65
	)
	_expect(is_equal_approx(_get_vector2(clamped.get("pos", Vector2.ZERO)).x, 15.0), "support projectile should clamp start x by radius")
	_expect(float(clamped.get("target_y", 0.0)) >= 42.0, "support projectile should clamp low target y into the field")


func _verify_runtime_delegates_support_projectile_resolver() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var profile := _support_profile()
	var direct: Dictionary = CommandoFirearmSupportProjectileResolver.build_projectile(
		Vector2(320.0, 180.0),
		profile,
		"fire_support",
		99,
		4,
		2,
		760.0,
		750.0,
		52.0,
		1.0,
		0.08,
		0.65
	)
	var wrapped: Dictionary = runtime._build_support_round_projectile(Vector2(320.0, 180.0), profile, "fire_support", 99, 4, 2)
	_expect_vec(_get_vector2(wrapped.get("pos", Vector2.ZERO)), _get_vector2(direct.get("pos", Vector2.ZERO)), "runtime support projectile wrapper should delegate position")
	_expect_vec(_get_vector2(wrapped.get("velocity", Vector2.ZERO)), _get_vector2(direct.get("velocity", Vector2.ZERO)), "runtime support projectile wrapper should delegate velocity")
	_expect(is_equal_approx(float(wrapped.get("target_y", 0.0)), float(direct.get("target_y", 0.0))), "runtime support projectile wrapper should delegate target y")

	runtime._spawn_support_round(Vector2(320.0, 180.0), profile, "fire_support", 4, 2)
	_expect(runtime.projectiles.size() == 1, "runtime support round spawn should append one projectile")
	var spawned: Dictionary = runtime._get_dict(runtime.projectiles[0])
	_expect(int(spawned.get("id", 0)) == 1, "runtime support round spawn should still allocate ids in runtime")
	_expect_vec(_get_vector2(spawned.get("pos", Vector2.ZERO)), Vector2(320.0, 71.0), "runtime support round spawn should use resolver position")
	_expect_vec(_get_vector2(spawned.get("velocity", Vector2.ZERO)), Vector2(-0.26325, 1.0), "runtime support round spawn should use resolver velocity")


func _support_profile() -> Dictionary:
	return {
		"radius": 7.0,
		"gravity": 0.08,
		"initial_vy": 1.0,
		"horizontal_jitter": 0.65,
		"trail": 52.0,
		"life_frames": 44.0,
		"impact_radius": 54.0,
		"explosion_radius": 152.0,
		"color": Color(1.0, 0.34, 0.16),
		"secondary": Color(1.0, 0.82, 0.25),
	}


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect_vec(actual: Vector2, expected: Vector2, message: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
