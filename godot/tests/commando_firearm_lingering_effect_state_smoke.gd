extends SceneTree

const CommandoFirearmLingeringEffectState := preload("res://scripts/characters/commando_firearm_lingering_effect_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_lingering_effect_state()
	_verify_runtime_delegates_lingering_effect_state()

	if _failures.is_empty():
		print("commando_firearm_lingering_effect_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_lingering_effect_state() -> void:
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_duration({"duration_frames": 12.0}, false, false, 30.0), 12.0), "duration helper should read normal durations")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_duration({"dissolve_frames": 8.0}, true, true, 30.0), 8.0), "duration helper should read net dissolve durations")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_duration({"dissolve_frames": -4.0}, true, true, 30.0), 1.0), "duration helper should clamp durations")
	_expect(CommandoFirearmLingeringEffectState.get_size({}, {"impact_radius": 10.0}, false, 280.0, 140.0) == Vector2(20.0, 12.0), "size helper should derive non-net sizes")
	_expect(CommandoFirearmLingeringEffectState.get_size({}, {}, true, 280.0, 140.0) == Vector2(280.0, 140.0), "size helper should preserve net sizes")

	var effect: Dictionary = CommandoFirearmLingeringEffectState.build_effect(
		"suicide_drone",
		{"kind": "fire_zone", "color": Color.RED, "secondary": Color.GREEN},
		{"color": Color.BLUE, "secondary": Color.YELLOW},
		Vector2(100.0, 80.0),
		17,
		Vector2(120.0, 45.0),
		90.0
	)
	_expect(int(effect.get("id", 0)) == 17, "effect builder should preserve ids")
	_expect(str(effect.get("source", "")) == "commando_firearm_suicide_drone_lingering_17", "effect builder should build stable sources")
	_expect(effect.get("color", Color.WHITE) == Color.RED, "effect builder should prefer profile colors")
	var spawn_result: Dictionary = CommandoFirearmLingeringEffectState.build_spawn_result(effect, 90.0)
	_expect(str(spawn_result.get("kind", "")) == "fire_zone", "spawn result should preserve effect kind")
	_expect(is_equal_approx(float(spawn_result.get("duration_frames", 0.0)), 90.0), "spawn result should preserve duration")
	var dissolve_projectile: Dictionary = CommandoFirearmLingeringEffectState.build_net_dissolve_projectile({"id": 7, "net_dissolve": false})
	_expect(bool(dissolve_projectile.get("net_dissolve", false)), "net dissolve projectile helper should force dissolve state")
	_expect(int(dissolve_projectile.get("id", 0)) == 7, "net dissolve projectile helper should preserve source projectile fields")

	var timer_effect := {
		"timer_frames": 10.0,
		"phase": 2.0,
		"rope_broken": true,
		"rope_snap_timer": 6.0,
	}
	CommandoFirearmLingeringEffectState.advance_timers(timer_effect, 4.0, 0.12)
	_expect(is_equal_approx(float(timer_effect.get("timer_frames", 0.0)), 6.0), "advance helper should reduce timers")
	_expect(is_equal_approx(float(timer_effect.get("phase", 0.0)), 2.48), "advance helper should update phase")
	_expect(is_equal_approx(float(timer_effect.get("rope_snap_timer", 0.0)), 2.0), "advance helper should update rope snap timers")
	_expect(CommandoFirearmLingeringEffectState.is_fire_zone(effect), "fire-zone helper should detect fire zones")
	_expect(CommandoFirearmLingeringEffectState.is_active({"timer_frames": 0.1}), "active helper should accept positive timers")
	_expect(not CommandoFirearmLingeringEffectState.is_active({"timer_frames": 0.0}), "active helper should reject expired timers")

	var result := {}
	var context := {}
	CommandoFirearmLingeringEffectState.merge_clamp_result(result, context, {"clamped": true})
	_expect(bool(result.get("clamped", false)), "clamp merge helper should update result payloads")
	_expect(bool(context.get("clamped", false)), "clamp merge helper should update context payloads")


func _verify_runtime_delegates_lingering_effect_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var runtime_result: Dictionary = runtime._spawn_lingering_effect(
		"suicide_drone",
		{"id": 9, "pos": Vector2(200.0, 300.0), "color": Color.BLUE},
		{}
	)
	_expect(str(runtime_result.get("source", "")) == "commando_firearm_suicide_drone_lingering_9", "runtime lingering spawn path should expose owner-built source")
	_expect(is_equal_approx(float(runtime_result.get("duration_frames", 0.0)), 150.0), "runtime lingering spawn path should expose owner-built duration")
	_expect(runtime.lingering_effects.size() == 1, "runtime lingering spawn path should append the owner-built effect")
	_expect(CommandoFirearmLingeringEffectState.is_active({"timer_frames": 0.1}), "active owner should remain the timer-state boundary")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(not runtime_source.contains("func _get_lingering_effect_duration("), "runtime should not keep lingering duration bridge")
	_expect(not runtime_source.contains("func _get_lingering_effect_size("), "runtime should not keep lingering size bridge")
	_expect(not runtime_source.contains("func _build_lingering_effect("), "runtime should not keep lingering effect build bridge")
	_expect(not runtime_source.contains("func _build_lingering_spawn_result("), "runtime should not keep lingering spawn-result bridge")
	_expect(not runtime_source.contains("func _spawn_net_dissolve_effect("), "runtime should not keep net dissolve lingering bridge")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
