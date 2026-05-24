extends SceneTree

const CommandoFirearmPendingResultState := preload("res://scripts/characters/commando_firearm_pending_result_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_pending_result_state()
	_verify_runtime_consumes_pending_result_state()
	_verify_removed_runtime_pending_result_bridges()

	if _failures.is_empty():
		print("commando_firearm_pending_result_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_pending_result_state() -> void:
	var damage_state: Dictionary = CommandoFirearmPendingResultState.queue_boss_damage_state(
		1,
		["existing"],
		{
			"damage_units": 2,
			"damage_sources": ["existing", "headshot"],
		}
	)
	_expect(int(damage_state.get("units", 0)) == 3, "boss damage queue should add damage units")
	_expect((damage_state.get("sources", []) as Array) == ["existing", "headshot"], "boss damage queue should append unique damage sources")
	var damage_result: Dictionary = CommandoFirearmPendingResultState.build_boss_damage_result(3, ["existing", "headshot"])
	_expect(int(damage_result.get("commando_firearm_boss_damage_units", 0)) == 3, "boss damage result should expose units")
	_expect(str(damage_result.get("commando_firearm_last_damage_source", "")) == "headshot", "boss damage result should expose last source")
	_expect(CommandoFirearmPendingResultState.build_boss_damage_result(0, []).is_empty(), "empty boss damage result should stay empty")

	var gauge_state: Dictionary = CommandoFirearmPendingResultState.queue_special_gauge_state(
		10.0,
		["existing"],
		"normal",
		3.0,
		{
			"commando_firearm_special_gauge_gain": 40.0,
			"commando_firearm_special_gauge_source": "legshot",
			"commando_firearm_pistol_hit_kind": "legshot",
			"commando_firearm_pistol_feedback_timer_frames": 18.0,
		}
	)
	_expect(is_equal_approx(float(gauge_state.get("gain", 0.0)), 50.0), "special gauge queue should add gain")
	_expect((gauge_state.get("sources", []) as Array) == ["existing", "legshot"], "special gauge queue should append unique sources")
	_expect(str(gauge_state.get("hit_kind", "")) == "legshot", "special gauge queue should preserve hit kind")
	_expect(is_equal_approx(float(gauge_state.get("feedback_timer_frames", 0.0)), 18.0), "special gauge queue should preserve max feedback timer")
	var gauge_result: Dictionary = CommandoFirearmPendingResultState.build_special_gauge_result(50.0, ["existing", "legshot"], "legshot", 18.0)
	_expect(is_equal_approx(float(gauge_result.get("commando_firearm_special_gauge_gain", 0.0)), 50.0), "special gauge result should expose gain")
	_expect(str(gauge_result.get("commando_firearm_last_gauge_source", "")) == "legshot", "special gauge result should expose last source")
	_expect(str(gauge_result.get("commando_firearm_last_pistol_hit_kind", "")) == "legshot", "special gauge result should expose hit kind")
	_expect(CommandoFirearmPendingResultState.build_special_gauge_result(0.0, [], "", 0.0).is_empty(), "empty special gauge result should stay empty")


func _verify_runtime_consumes_pending_result_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.pending_boss_damage_units = 3
	runtime.pending_boss_damage_sources = ["bazooka", "fire_support"]
	runtime.pending_special_gauge_gain = 40.0
	runtime.pending_special_gauge_sources = ["legshot"]
	runtime.pending_special_gauge_hit_kind = "legshot"
	runtime.pending_pistol_feedback_timer_frames = 18.0
	var result: Dictionary = runtime.update_effects(1.0, 0, {}, {})
	_expect(int(result.get("commando_firearm_boss_damage_units", 0)) == 3, "runtime pending consume should emit boss damage units")
	_expect((result.get("commando_firearm_boss_damage_sources", []) as Array) == ["bazooka", "fire_support"], "runtime pending consume should emit boss damage sources")
	_expect(is_equal_approx(float(result.get("commando_firearm_special_gauge_gain", 0.0)), 40.0), "runtime pending consume should emit special gauge gain")
	_expect(str(result.get("commando_firearm_last_gauge_source", "")) == "legshot", "runtime pending consume should emit gauge source")
	_expect(str(result.get("commando_firearm_last_pistol_hit_kind", "")) == "legshot", "runtime pending consume should emit hit kind")
	_expect(runtime.pending_boss_damage_units == 0, "runtime pending consume should clear boss damage units")
	_expect(runtime.pending_boss_damage_sources.is_empty(), "runtime pending consume should clear boss damage sources")
	_expect(is_equal_approx(runtime.pending_special_gauge_gain, 0.0), "runtime pending consume should clear special gauge gain")
	_expect(runtime.pending_special_gauge_sources.is_empty(), "runtime pending consume should clear special gauge sources")
	_expect(runtime.pending_special_gauge_hit_kind == "", "runtime pending consume should clear hit kind")
	_expect(is_equal_approx(runtime.pending_pistol_feedback_timer_frames, 0.0), "runtime pending consume should clear feedback timer")


func _verify_removed_runtime_pending_result_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_queue_boss_damage",
		"_queue_special_gauge_gain",
		"_consume_pending_boss_damage_result",
		"_consume_pending_special_gauge_result",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep pending-result bridge %s" % bridge_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
