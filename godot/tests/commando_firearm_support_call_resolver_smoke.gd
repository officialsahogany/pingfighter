extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmSupportCallResolver := preload("res://scripts/characters/commando_firearm_support_call_resolver.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_support_call_resolver()
	_verify_runtime_delegates_support_call_resolver()
	_verify_removed_support_call_setup_bridges()

	if _failures.is_empty():
		print("commando_firearm_support_call_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_support_call_resolver() -> void:
	var target := Vector2(320.0, 180.0)
	_expect(
		CommandoFirearmSupportCallResolver.support_call_seed(4, target) == 4414083065,
		"support call seed should preserve the deterministic legacy formula"
	)
	_expect(
		is_equal_approx(CommandoFirearmSupportCallResolver.get_delay_frames(4, target, 120.0, 180.0), 148.0),
		"support call delay should stay inside the legacy deterministic range"
	)
	_expect(
		CommandoFirearmSupportCallResolver.get_bomb_count(4, target, 5, 7) == 7,
		"support bomb count should stay inside the legacy deterministic range"
	)
	_expect(
		is_equal_approx(CommandoFirearmSupportCallResolver.get_delay_frames(1, target, 30.0, 30.0), 30.0),
		"single-value delay ranges should not divide by zero"
	)
	_expect(
		CommandoFirearmSupportCallResolver.get_bomb_count(1, target, 2, 2) == 2,
		"single-value bomb-count ranges should not divide by zero"
	)
	var payload: Dictionary = CommandoFirearmSupportCallResolver.build_call_payload(
		9,
		Vector2(10.0, 20.0),
		target,
		{},
		"fire_support",
		148.0,
		7,
		42.0,
		18.0,
		116.0,
		8.0
	)
	_expect(int(payload.get("id", 0)) == 9, "support payload should preserve the call id")
	_expect(str(payload.get("state", "")) == "calling", "support payload should start in calling state")
	_expect(payload.get("aircraft_pos", Vector2.ZERO) == Vector2(-140.0, 116.0), "support payload should seed aircraft offscreen at the configured lane")
	_expect(payload.get("aircraft_velocity", Vector2.ZERO) == Vector2(8.0, 0.0), "support payload should preserve configured aircraft speed")
	var marker: Dictionary = CommandoFirearmSupportCallResolver.build_marker_flash("fire_support", target, {"impact_radius": 50.0}, 42.0)
	_expect(str(marker.get("kind", "")) == "support_marker", "support marker should preserve marker kind")
	_expect(is_equal_approx(float(marker.get("radius", 0.0)), 37.0), "support marker radius should scale profile impact radius")
	var bomb_target_a: Vector2 = CommandoFirearmSupportCallResolver.get_bomb_target(target, 0, 760.0, 750.0, 4)
	var bomb_target_b: Vector2 = CommandoFirearmSupportCallResolver.get_bomb_target(target, 1, 760.0, 750.0, 4)
	_expect(_vector2_is_equal_approx(bomb_target_a, Vector2(518.8, 140.0)), "support bomb target should use deterministic random x spread from the marked point")
	_expect(_vector2_is_equal_approx(bomb_target_b, Vector2(418.6, 177.0)), "support bomb target should randomize each projectile independently")
	_expect(abs(bomb_target_a.x - target.x) <= 200.0 and abs(bomb_target_b.x - target.x) <= 200.0, "support bomb random x spread should stay within 200px of the marked point")
	_expect(not is_equal_approx(bomb_target_a.x, bomb_target_b.x), "sequential support bombs should not reuse the same target x")
	var calling: Dictionary = CommandoFirearmSupportCallResolver.advance_call(
		{"state": "calling", "call_timer_frames": 42.0, "delay_frames": 120.0},
		10.0,
		Vector2(-140.0, 116.0),
		Vector2(8.0, 0.0),
		18.0,
		760.0,
		150.0
	)
	var calling_payload: Dictionary = _get_dict(calling.get("call", {}))
	_expect(str(calling_payload.get("state", "")) == "calling", "support advance should keep active call locks in calling state")
	_expect(is_equal_approx(float(calling_payload.get("call_timer_frames", 0.0)), 32.0), "support advance should decrement call lock timers")
	_expect(not bool(calling.get("started_aircraft", true)), "support advance should not start aircraft during call lock")
	var inbound: Dictionary = CommandoFirearmSupportCallResolver.advance_call(
		{"state": "calling", "call_timer_frames": 0.0, "delay_frames": 20.0},
		5.0,
		Vector2(-140.0, 116.0),
		Vector2(8.0, 0.0),
		18.0,
		760.0,
		150.0
	)
	var inbound_payload: Dictionary = _get_dict(inbound.get("call", {}))
	_expect(str(inbound_payload.get("state", "")) == "inbound", "support advance should enter inbound while delay remains")
	_expect(is_equal_approx(float(inbound_payload.get("delay_frames", 0.0)), 15.0), "support advance should decrement inbound delay")
	var striking: Dictionary = CommandoFirearmSupportCallResolver.advance_call(
		{
			"state": "inbound",
			"call_timer_frames": 0.0,
			"delay_frames": 0.0,
			"bomb_timer_frames": 0.0,
			"bombs_remaining": 2,
			"bombs_spawned": 0,
			"aircraft_active": false,
			"aircraft_drop_arm_frames": 18.0,
		},
		20.0,
		Vector2(-140.0, 116.0),
		Vector2(8.0, 0.0),
		18.0,
		760.0,
		150.0
	)
	var striking_payload: Dictionary = _get_dict(striking.get("call", {}))
	_expect(str(striking_payload.get("state", "")) == "striking", "support advance should enter striking when delay is done")
	_expect(bool(striking.get("started_aircraft", false)), "support advance should report aircraft startup once")
	_expect(bool(striking.get("spawn_bomb", false)), "support advance should request a bomb after drop arm")
	_expect(int(striking.get("spawn_index", -1)) == 0, "support advance should report the bomb spawn index")
	_expect(int(striking_payload.get("bombs_remaining", 0)) == 1, "support advance should decrement remaining bomb count")
	_expect(striking_payload.get("aircraft_pos", Vector2.ZERO) == Vector2(20.0, 116.0), "support advance should move aircraft by velocity and step")
	var finished: Dictionary = CommandoFirearmSupportCallResolver.advance_call(
		{
			"state": "striking",
			"call_timer_frames": 0.0,
			"delay_frames": 0.0,
			"bomb_timer_frames": 5.0,
			"bombs_remaining": 0,
			"aircraft_active": true,
			"aircraft_pos": Vector2(900.0, 116.0),
			"aircraft_velocity": Vector2(20.0, 0.0),
		},
		1.0,
		Vector2(-140.0, 116.0),
		Vector2(8.0, 0.0),
		18.0,
		760.0,
		150.0
	)
	_expect(bool(finished.get("finished", false)), "support advance should finish after all bombs and offscreen aircraft")
	_expect(
		CommandoFirearmSupportCallResolver.has_active_lock([{"radio_active": true}]),
		"support active-lock helper should detect active radio calls"
	)
	_expect(
		CommandoFirearmSupportCallResolver.has_active_lock([{"call_timer_frames": 1.0}]),
		"support active-lock helper should detect active call timers"
	)
	_expect(
		not CommandoFirearmSupportCallResolver.has_active_lock([{"radio_active": false, "call_timer_frames": 0.0}, "bad"]),
		"support active-lock helper should ignore inactive and invalid calls"
	)


func _verify_runtime_delegates_support_call_resolver() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var advance_result: Dictionary = runtime._advance_support_call({
		"call_timer_frames": 0.0,
		"delay_frames": 0.0,
		"bombs_remaining": 1,
		"bombs_spawned": 0,
		"aircraft_active": false,
		"aircraft_drop_arm_frames": 18.0,
	}, 20.0)
	var advanced_call: Dictionary = _get_dict(advance_result.get("call", {}))
	_expect(bool(advance_result.get("started_aircraft", false)), "runtime support advance wrapper should report aircraft startup")
	_expect(bool(advance_result.get("spawn_bomb", false)), "runtime support advance wrapper should report bomb spawn")
	var advanced_pos: Vector2 = _get_vector2(advanced_call.get("aircraft_pos", Vector2.ZERO), Vector2.ZERO)
	_expect(is_equal_approx(advanced_pos.x, -144.0), "runtime support advance wrapper should use the pillar-edge aircraft lane and doubled speed")
	_expect(advanced_pos.y > 340.0, "runtime support advance wrapper should curve through the center-screen aircraft lane")
	_expect(abs(float(advanced_call.get("aircraft_curve_roll", 0.0))) > 0.0, "runtime support advance wrapper should expose curve roll metadata")
	runtime.support_calls = [{"call_timer_frames": 1.0}]
	_expect(runtime._has_active_support_call_lock(), "runtime support active-lock wrapper should delegate active calls")
	runtime.support_calls = [{"call_timer_frames": 0.0, "radio_active": false}]
	_expect(not runtime._has_active_support_call_lock(), "runtime support active-lock wrapper should delegate inactive calls")


func _verify_removed_support_call_setup_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_build_support_call_payload",
		"_build_support_marker_flash",
		"_get_support_call_delay_frames",
		"_get_support_bomb_count",
		"_support_call_seed",
		"_get_support_bomb_target",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep support-call setup bridge %s" % bridge_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _vector2_is_equal_approx(a: Vector2, b: Vector2) -> bool:
	return is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y)
