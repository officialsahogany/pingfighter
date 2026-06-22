extends SceneTree

const CommandoFirearmProjectileSpawnState := preload("res://scripts/characters/commando_firearm_projectile_spawn_state.gd")

var _failures: Array[String] = []


class FakeShotCounter:
	extends RefCounted

	var shot_serial := 0


func _init() -> void:
	_verify_shot_id_owner()
	_verify_fire_direction_payloads()
	_verify_direct_projectile_payloads()

	if _failures.is_empty():
		print("commando_firearm_projectile_spawn_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shot_id_owner() -> void:
	var counter := FakeShotCounter.new()
	counter.shot_serial = 41
	_expect(CommandoFirearmProjectileSpawnState.claim_next_shot_id(counter) == 42, "shot id owner should return the next serial")
	_expect(counter.shot_serial == 42, "shot id owner should store the next serial on the target")
	_expect(CommandoFirearmProjectileSpawnState.claim_next_shot_id(counter) == 43, "shot id owner should keep incrementing serials")
	_expect(CommandoFirearmProjectileSpawnState.claim_next_shot_id(null) == 0, "shot id owner should tolerate missing targets")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(runtime_source.find("func _next_shot_id(") == -1, "runtime should not keep shot id allocation bridge")


func _verify_fire_direction_payloads() -> void:
	var upward: Vector2 = CommandoFirearmProjectileSpawnState.get_fire_direction(Vector2(200.0, 200.0), Vector2(100.0, 100.0), true, 0.0)
	_expect(upward == Vector2.UP, "direction helper should force vertical launches upward")

	var fallback: Vector2 = CommandoFirearmProjectileSpawnState.get_fire_direction(Vector2(100.0, 100.0), Vector2(100.0, 100.0), false, 0.0)
	_expect(fallback == Vector2.UP, "direction helper should use upward fallback for zero-length aim")

	var diagonal: Vector2 = CommandoFirearmProjectileSpawnState.get_fire_direction(Vector2(3.0, 4.0), Vector2.ZERO, false, 0.0)
	_expect(is_equal_approx(diagonal.length(), 1.0), "direction helper should normalize non-vertical aim")
	_expect(is_equal_approx(diagonal.x, 0.6) and is_equal_approx(diagonal.y, 0.8), "direction helper should preserve normalized aim vector")

	var rotated: Vector2 = CommandoFirearmProjectileSpawnState.get_fire_direction(Vector2.RIGHT, Vector2.ZERO, false, PI * 0.5)
	_expect(is_equal_approx(rotated.x, 0.0) and is_equal_approx(rotated.y, 1.0), "direction helper should apply angle offsets")


func _verify_direct_projectile_payloads() -> void:
	var origin := Vector2(100.0, 620.0)
	var target := Vector2(380.0, 80.0)
	var aim_origin := Vector2(104.0, 612.0)
	var rocket_profile := {
		"radius": 9.5,
		"trail": 36.0,
		"life_frames": 60.0,
		"impact_radius": 46.0,
		"explosion_radius": 152.0,
		"acceleration": 0.8,
		"max_speed": 18.0,
		"smoke_trail_limit": 3,
		"color": Color(1.0, 0.46, 0.18),
		"secondary": Color(1.0, 0.88, 0.38),
	}
	var rocket: Dictionary = CommandoFirearmProjectileSpawnState.build_projectile(
		"bazooka",
		"rocket",
		12,
		origin,
		target,
		Vector2.UP,
		3.0,
		0.0,
		aim_origin,
		rocket_profile,
		{},
		5,
		6,
		2.0,
		1.25
	)
	_expect(int(rocket.get("id", 0)) == 12, "projectile helper should preserve projectile id")
	_expect(str(rocket.get("weapon_id", "")) == "bazooka", "projectile helper should preserve weapon id")
	_expect(_get_vector2(rocket.get("velocity", Vector2.ZERO)) == Vector2(0.0, -3.0), "projectile helper should multiply direction by speed")
	_expect(is_equal_approx(float(rocket.get("explosion_radius", 0.0)), 152.0), "projectile helper should copy explosion radius")
	_expect(is_equal_approx(float(rocket.get("acceleration", 0.0)), 0.8), "projectile helper should copy acceleration")
	_expect(is_equal_approx(float(rocket.get("max_speed", 0.0)), 18.0), "projectile helper should copy max speed")
	_expect(int(rocket.get("smoke_trail_limit", 0)) == 3, "projectile helper should preserve smoke trail limit")
	_expect(_get_array(rocket.get("smoke_trail", [])).is_empty(), "projectile helper should seed empty smoke trail")

	var doped_pistol: Dictionary = CommandoFirearmProjectileSpawnState.build_projectile(
		"commando_pistol",
		"bullet",
		2,
		origin,
		target,
		Vector2.RIGHT,
		14.0,
		0.15,
		aim_origin,
		{},
		{"active": true, "head_leg_multiplier": 2.75, "pistol_speed_multiplier": 1.4},
		5,
		6,
		2.0,
		1.25
	)
	_expect(bool(doped_pistol.get("active_item_doping_potion_active", false)), "projectile helper should mark active doping projectiles")
	_expect(is_equal_approx(float(doped_pistol.get("active_item_doping_potion_head_leg_multiplier", 0.0)), 2.75), "projectile helper should carry doping head/leg multiplier")
	_expect(is_equal_approx(float(doped_pistol.get("active_item_doping_potion_pistol_speed_multiplier", 0.0)), 1.4), "projectile helper should carry doping speed multiplier")

	var slingshot_profile := {
		"slingshot": true,
		"charge_level": 7,
	}
	var slingshot: Dictionary = CommandoFirearmProjectileSpawnState.build_projectile(
		"pistol",
		"bullet",
		6,
		origin,
		target,
		Vector2.UP,
		32.0,
		0.0,
		aim_origin,
		slingshot_profile,
		{},
		5,
		6,
		2.0,
		1.25
	)
	_expect(bool(slingshot.get("slingshot", false)), "projectile helper should mark slingshot projectiles")
	_expect(int(slingshot.get("charge_level", 0)) == 3, "projectile helper should clamp slingshot charge level")
	_expect(int(slingshot.get("slingshot_stone_variant", -1)) == 1, "projectile helper should derive stable slingshot stone variant")
	_expect(int(slingshot.get("slingshot_stone_frame", -1)) == 9, "projectile helper should derive slingshot sheet frame")

	var net_origin := Vector2(205.0, 500.0)
	var net: Dictionary = CommandoFirearmProjectileSpawnState.build_projectile(
		"net_gun",
		"net",
		21,
		origin,
		target,
		Vector2.UP,
		16.0,
		0.0,
		net_origin,
		{"rope_trail_limit": 8},
		{},
		5,
		6,
		2.0,
		1.25
	)
	_expect(_get_vector2(net.get("origin", Vector2.ZERO)) == net_origin, "projectile helper should preserve net rope origin")
	_expect(_get_array(net.get("rope_points", [])).is_empty(), "projectile helper should seed empty net rope points")
	_expect(int(net.get("rope_trail_limit", 0)) == 8, "projectile helper should preserve net rope limit")

	var counter := FakeShotCounter.new()
	var runtime_projectiles: Array = []
	var runtime_shells: Array = []
	var append_result: Dictionary = CommandoFirearmProjectileSpawnState.append_runtime_projectile(
		runtime_projectiles,
		runtime_shells,
		counter,
		"ak47",
		"bullet",
		origin,
		target,
		Vector2.UP,
		0.0,
		aim_origin,
		{"speed": 16.0},
		{},
		{"player_pos": Vector2(90.0, 600.0), "paddle_height": 40.0},
		16.0,
		5,
		6,
		2.0,
		1.25,
		1.0,
		4,
		750.0,
		180.0,
		150.0,
		4
	)
	_expect(int(append_result.get("shot_id", 0)) == 1, "runtime projectile append should allocate a shot id")
	_expect(runtime_projectiles.size() == 1, "runtime projectile append should append one projectile")
	_expect(runtime_shells.size() == 1, "runtime projectile append should append supported shell casings")
	_expect(bool(append_result.get("shell_appended", false)), "runtime projectile append should report shell append")


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
