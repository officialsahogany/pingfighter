extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmSupportCallResolver := preload("res://scripts/characters/commando_firearm_support_call_resolver.gd")
const CommandoFirearmSupportProjectileResolver := preload("res://scripts/characters/commando_firearm_support_projectile_resolver.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_support_projectile_resolver()
	_verify_runtime_delegates_support_projectile_resolver()
	_verify_removed_runtime_support_projectile_bridge()

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
		320.0,
		0.0,
		0.0,
		0.0,
		Vector2(94.0, 330.0),
		22.0,
		90.0,
		150.0,
		"opponent_wall"
	)
	_expect(int(projectile.get("id", 0)) == 99, "support projectile should preserve assigned projectile id")
	_expect(str(projectile.get("weapon_id", "")) == "fire_support", "support projectile should preserve weapon id")
	_expect(int(projectile.get("support_call_id", 0)) == 4, "support projectile should preserve call id")
	_expect(int(projectile.get("support_spawn_index", 0)) == 2, "support projectile should preserve spawn index")
	_expect(str(projectile.get("support_impact_mode", "")) == "opponent_wall", "support projectile should use the wall-impact missile mode")
	_expect_vec(_get_vector2(projectile.get("pos", Vector2.ZERO)), Vector2(94.0, 364.0), "support projectile should launch from the aircraft underside")
	_expect_vec(_get_vector2(projectile.get("target", Vector2.ZERO)), Vector2(320.0, 22.0), "support projectile should target the opponent-side wall")
	_expect_vec(_get_vector2(projectile.get("velocity", Vector2.ZERO)), Vector2(226.0 / 90.0, -342.0 / 90.0), "support projectile velocity should reach the wall in 90 frames")
	_expect(is_equal_approx(float(projectile.get("speed", 0.0)), Vector2(226.0 / 90.0, -342.0 / 90.0).length()), "support projectile speed should match velocity length")
	_expect(is_equal_approx(float(projectile.get("gravity", 0.0)), 0.0), "support projectile gravity should stay disabled for wall-flight missiles")
	_expect(is_equal_approx(float(projectile.get("explosion_radius", 0.0)), 152.0), "support projectile explosion radius should preserve profile/default value")
	_expect(is_equal_approx(float(projectile.get("support_flight_frames", 0.0)), 90.0), "support projectile should preserve the tuned wall-flight duration")

	var clamped: Dictionary = CommandoFirearmSupportProjectileResolver.build_projectile(
		Vector2(-20.0, 10.0),
		profile,
		"fire_support",
		100,
		1,
		0,
		760.0,
		750.0,
		320.0,
		0.0,
		0.0,
		0.0,
		Vector2(-500.0, 330.0),
		22.0,
		90.0,
		150.0,
		"opponent_wall"
	)
	_expect(is_equal_approx(_get_vector2(clamped.get("pos", Vector2.ZERO)).x, -380.0), "support projectile should clamp aircraft launch x to the extended flight band")
	_expect(is_equal_approx(float(clamped.get("target_y", 0.0)), 22.0), "support projectile should clamp low target y to the opponent wall")
	var appended: Array = []
	CommandoFirearmSupportProjectileResolver.append_projectile(
		appended,
		Vector2(320.0, 180.0),
		profile,
		"fire_support",
		101,
		4,
		2,
		760.0,
		750.0,
		320.0,
		0.0,
		0.0,
		0.0,
		Vector2(94.0, 330.0),
		22.0,
		90.0,
		150.0,
		"opponent_wall",
		2
	)
	_expect(appended.size() == 1, "support projectile append helper should append one projectile")
	_expect(int((appended[0] as Dictionary).get("id", 0)) == 101, "support projectile append helper should preserve assigned ids")
	var appended_from_call: Array = []
	CommandoFirearmSupportProjectileResolver.append_from_call(
		appended_from_call,
		{
			"id": 4,
			"target": Vector2(320.0, 180.0),
			"aircraft_pos": Vector2(-360.0, 320.0),
		},
		Vector2(380.0, 80.0),
		profile,
		"fire_support",
		102,
		2,
		760.0,
		750.0,
		320.0,
		0.0,
		0.0,
		0.0,
		Vector2(-360.0, 320.0),
		22.0,
		90.0,
		150.0,
		"opponent_wall",
		300.0,
		2
	)
	_expect(appended_from_call.size() == 1, "support call append helper should append one projectile from call data")
	_expect(int((appended_from_call[0] as Dictionary).get("support_call_id", 0)) == 4, "support call append helper should preserve support call ids")

	var runtime_owner := CommandoFirearmRuntime.new()
	var runtime_calls: Array = [{
		"id": 4,
		"target": Vector2(320.0, 180.0),
		"state": "striking",
		"call_timer_frames": 0.0,
		"delay_frames": 0.0,
		"bomb_timer_frames": 0.0,
		"bombs_remaining": 1,
		"bombs_spawned": 0,
		"aircraft_active": false,
		"aircraft_drop_arm_frames": 0.0,
	}]
	var runtime_projectiles: Array = []
	var runtime_result: Dictionary = CommandoFirearmSupportProjectileResolver.advance_runtime_calls(
		runtime_calls,
		runtime_projectiles,
		runtime_owner,
		{},
		profile,
		1.0,
		Vector2(760.0, 750.0),
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_START_X,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_Y,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_SPEED,
		CommandoFirearmRuntime.SUPPORT_BOMB_INTERVAL_FRAMES,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_FINISH_MARGIN,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_CURVE_AMPLITUDE,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_CURVE_FREQUENCY,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_CURVE_SECONDARY_RATIO,
		CommandoFirearmRuntime.SUPPORT_BOMB_INITIAL_VY,
		CommandoFirearmRuntime.SUPPORT_BOMB_GRAVITY,
		CommandoFirearmRuntime.SUPPORT_BOMB_HORIZONTAL_JITTER,
		CommandoFirearmRuntime.SUPPORT_OPPONENT_WALL_Y,
		CommandoFirearmRuntime.SUPPORT_MISSILE_FLIGHT_FRAMES,
		CommandoFirearmRuntime.SUPPORT_MISSILE_LIFE_FRAMES,
		CommandoFirearmRuntime.SUPPORT_BOMB_RANDOM_X_RANGE,
		CommandoFirearmRuntime.PROJECTILE_LIMIT
	)
	var runtime_events: Array = CommandoFirearmValueUtils.get_array(runtime_result.get("audio_events", []))
	_expect(runtime_projectiles.size() == 1, "runtime support owner should append spawned projectiles")
	_expect(runtime_owner.shot_serial == 1, "runtime support owner should allocate projectile ids through the runtime owner")
	_expect(runtime_events.size() == 1, "runtime support owner should report aircraft audio start")
	_expect(str(CommandoFirearmValueUtils.get_dict(runtime_events[0]).get("type", "")) == "start_aircraft", "runtime support owner should preserve audio event order")


func _verify_runtime_delegates_support_projectile_resolver() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var profile := _support_profile()
	var call_target := Vector2(320.0, 180.0)
	var bomb_target: Vector2 = CommandoFirearmSupportCallResolver.get_bomb_target(
		call_target,
		2,
		CommandoFirearmRuntime.FIELD_WIDTH,
		CommandoFirearmRuntime.FIELD_HEIGHT,
		4,
		CommandoFirearmRuntime.SUPPORT_BOMB_RANDOM_X_RANGE
	)
	bomb_target.y = CommandoFirearmRuntime.SUPPORT_OPPONENT_WALL_Y
	var direct: Dictionary = CommandoFirearmSupportProjectileResolver.build_projectile(
		bomb_target,
		profile,
		"fire_support",
		99,
		4,
		2,
		760.0,
		750.0,
		320.0,
		0.0,
		0.0,
		0.0,
		Vector2(-360.0, 320.0),
		22.0,
		90.0,
		150.0,
		"opponent_wall"
	)
	runtime.support_calls = [{
		"id": 4,
		"target": call_target,
		"state": "striking",
		"call_timer_frames": 0.0,
		"delay_frames": 0.0,
		"bomb_timer_frames": 0.0,
		"bombs_remaining": 1,
		"bombs_spawned": 2,
		"aircraft_active": true,
		"aircraft_pos": Vector2(-360.0, 320.0),
		"aircraft_velocity": Vector2.ZERO,
		"aircraft_drop_arm_frames": 0.0,
		"aircraft_spawn_timer": 20.0,
	}]
	CommandoFirearmSupportProjectileResolver.advance_runtime_support_calls(
		runtime.support_calls,
		runtime.projectiles,
		runtime,
		{},
		{},
		1.0,
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		Vector2(CommandoFirearmRuntime.FIELD_WIDTH, CommandoFirearmRuntime.FIELD_HEIGHT),
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_START_X,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_Y,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_SPEED,
		CommandoFirearmRuntime.SUPPORT_BOMB_INTERVAL_FRAMES,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_FINISH_MARGIN,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_CURVE_AMPLITUDE,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_CURVE_FREQUENCY,
		CommandoFirearmRuntime.SUPPORT_AIRCRAFT_CURVE_SECONDARY_RATIO,
		CommandoFirearmRuntime.SUPPORT_BOMB_INITIAL_VY,
		CommandoFirearmRuntime.SUPPORT_BOMB_GRAVITY,
		CommandoFirearmRuntime.SUPPORT_BOMB_HORIZONTAL_JITTER,
		CommandoFirearmRuntime.SUPPORT_OPPONENT_WALL_Y,
		CommandoFirearmRuntime.SUPPORT_MISSILE_FLIGHT_FRAMES,
		CommandoFirearmRuntime.SUPPORT_MISSILE_LIFE_FRAMES,
		CommandoFirearmRuntime.SUPPORT_BOMB_RANDOM_X_RANGE,
		CommandoFirearmRuntime.PROJECTILE_LIMIT
	)
	_expect(runtime.projectiles.size() == 1, "runtime support round spawn should append one projectile")
	var spawned: Dictionary = CommandoFirearmValueUtils.get_dict(runtime.projectiles[0])
	_expect(int(spawned.get("id", 0)) == 1, "runtime support round spawn should still allocate ids in runtime")
	_expect_vec(_get_vector2(spawned.get("pos", Vector2.ZERO)), _get_vector2(direct.get("pos", Vector2.ZERO)), "runtime support round spawn should use resolver position")
	_expect_vec(_get_vector2(spawned.get("velocity", Vector2.ZERO)), _get_vector2(direct.get("velocity", Vector2.ZERO)), "runtime support round spawn should use resolver velocity")


func _verify_removed_runtime_support_projectile_bridge() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(source.find("func _build_support_round_projectile(") < 0, "runtime should not keep support projectile build bridge")
	_expect(source.find("func _spawn_support_round(") < 0, "runtime should not keep support projectile append bridge")
	_expect(source.find("func _spawn_support_bomb(") < 0, "runtime should not keep support bomb append bridge")
	_expect(source.find("func _update_support_calls(") < 0, "runtime should not keep support call update bridge")
	_expect(source.find("CommandoFirearmSupportProjectileResolver.advance_runtime_support_calls") >= 0, "runtime should delegate support call projectile advancement")
	_expect(source.find("CommandoFirearmSupportProjectileResolver.advance_runtime_calls") < 0, "runtime should not call the lower-level support call advance helper directly")


func _support_profile() -> Dictionary:
	return {
		"radius": 7.0,
		"gravity": 0.0,
		"initial_vy": 0.0,
		"horizontal_jitter": 0.0,
		"flight_frames": 90.0,
		"trail": 52.0,
		"life_frames": 150.0,
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
