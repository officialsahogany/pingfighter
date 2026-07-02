extends SceneTree

const LingpetDebugStatOverrideState := preload("res://scripts/lingpet/lingpet_debug_stat_override_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

var _failures: Array[String] = []


class FakeProfile:
	var motion_style := "patrol"
	var stats := {
		"patrol_speed_default": 120.0,
		"patrol_speed_max": 180.0,
	}
	var defense_rate := 0.3
	var appearance_rate := 0.2

	func get_motion_style() -> String:
		return motion_style

	func get_stat(stat_name: String, fallback: float) -> float:
		return float(stats.get(stat_name, fallback))

	func get_defense_rate(fallback: float) -> float:
		return defense_rate if defense_rate >= 0.0 else fallback

	func get_appearance_rate(fallback: float) -> float:
		return appearance_rate if appearance_rate >= 0.0 else fallback


func _init() -> void:
	_verify_clamp_and_clear_contracts()
	_verify_motion_style_resolution()
	_verify_runtime_delegates_debug_stat_override_state()

	if _failures.is_empty():
		print("lingpet_debug_stat_override_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_clamp_and_clear_contracts() -> void:
	var state := LingpetDebugStatOverrideState.new()
	state.set_defense_rate_override(2.5)
	_expect_float(state.defense_rate_override, 1.0, "defense override should clamp to 1.0")
	state.set_defense_rate_override(-0.01)
	_expect_float(state.defense_rate_override, -1.0, "negative defense override should clear")

	state.set_appearance_rate_override(0.75)
	_expect_float(state.appearance_rate_override, 0.75, "appearance override should keep in-range values")
	state.set_appearance_rate_override(-10.0)
	_expect_float(state.appearance_rate_override, -1.0, "negative appearance override should clear")

	state.set_move_speed_override(0.01)
	_expect_float(state.move_speed_override, 0.1, "move-speed override should clamp to minimum multiplier")
	state.set_move_speed_override(99.0)
	_expect_float(state.move_speed_override, 5.0, "move-speed override should clamp to maximum multiplier")
	state.set_move_speed_override(-1.0)
	_expect_float(state.move_speed_override, -1.0, "negative move-speed override should clear")


func _verify_motion_style_resolution() -> void:
	var state := LingpetDebugStatOverrideState.new()
	state.set_defense_rate_override(0.8)
	_expect_float(state.resolve_defense_rate("patrol", 0.3), 0.8, "patrol defense should use the debug override")
	_expect_float(state.resolve_defense_rate("flight", 0.3), 0.0, "flight defense should stay hidden even with a defense override")

	state.set_appearance_rate_override(0.6)
	_expect_float(state.resolve_appearance_rate("flight", 0.2), 0.6, "flight appearance should use the debug override")
	_expect_float(state.resolve_appearance_rate("patrol", 0.2), 0.0, "patrol appearance should stay hidden even with an appearance override")

	state.set_move_speed_override(1.25)
	_expect_float(state.apply_move_speed_override(120.0), 150.0, "move-speed override should multiply the base speed")
	var patrol_profile := FakeProfile.new()
	_expect_float(state.get_patrol_speed(patrol_profile, "patrol_speed_default", 100.0), 150.0, "profile patrol speed should read profile stats then apply the move-speed override")
	_expect_float(state.get_patrol_speed(patrol_profile, "missing", 80.0), 100.0, "profile patrol speed should fall back before applying the move-speed override")
	state.set_move_speed_override(-1.0)
	_expect_float(state.apply_move_speed_override(120.0), 120.0, "cleared move-speed override should return the base speed")
	_expect_float(state.get_patrol_speed(patrol_profile, "patrol_speed_max", 100.0), 180.0, "cleared profile patrol speed should expose the raw profile stat")

	state.set_defense_rate_override(0.9)
	_expect_float(state.get_defense_rate(patrol_profile, 0.1), 0.9, "profile patrol defense should use the debug override")
	patrol_profile.motion_style = "free_flight"
	_expect_float(state.get_defense_rate(patrol_profile, 0.1), 0.0, "profile flight defense should stay hidden")

	state.set_appearance_rate_override(0.7)
	_expect_float(state.get_appearance_rate(patrol_profile, 0.0), 0.7, "profile flight appearance should use the debug override")
	patrol_profile.motion_style = "patrol"
	_expect_float(state.get_appearance_rate(patrol_profile, 0.0), 0.0, "profile patrol appearance should stay hidden")


func _verify_runtime_delegates_debug_stat_override_state() -> void:
	var runtime := LingpetEggRuntime.new()
	runtime.set_debug_defense_rate_override(0.55)
	runtime.set_debug_appearance_rate_override(0.65)
	runtime.set_debug_move_speed_override(1.5)
	_expect_float(runtime.get_debug_defense_rate_override(), 0.55, "runtime defense getter should expose delegated override state")
	_expect_float(runtime.get_debug_appearance_rate_override(), 0.65, "runtime appearance getter should expose delegated override state")
	_expect_float(runtime.get_debug_move_speed_override(), 1.5, "runtime move-speed getter should expose delegated override state")

	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_debug_stat_override_state.gd")
	_expect(runtime_source.find("LingpetDebugStatOverrideState") >= 0, "egg runtime should preload the debug stat override owner")
	_expect(runtime_source.find("_debug_stat_overrides.set_defense_rate_override") >= 0, "runtime defense setter should delegate")
	_expect(runtime_source.find("_debug_stat_overrides.get_defense_rate") >= 0, "runtime defense rate calculation should delegate through the profile-aware owner method")
	_expect(runtime_source.find("_debug_stat_overrides.get_appearance_rate") >= 0, "runtime appearance rate calculation should delegate through the profile-aware owner method")
	_expect(runtime_source.find("_debug_stat_overrides.get_patrol_speed") >= 0, "runtime patrol speed calculation should delegate through the profile-aware owner method")
	for wrapper_name in ["func _get_current_patrol_speed", "func _get_current_defense_rate", "func _get_current_appearance_rate"]:
		_expect(runtime_source.find(wrapper_name) < 0, "runtime should not keep profile-aware debug stat wrapper %s" % wrapper_name)
	_expect(runtime_source.find("var _debug_defense_rate_override") < 0, "runtime should not keep defense override state locally")
	_expect(runtime_source.find("var _debug_appearance_rate_override") < 0, "runtime should not keep appearance override state locally")
	_expect(runtime_source.find("var _debug_move_speed_override") < 0, "runtime should not keep move-speed override state locally")
	_expect(owner_source.find("get_patrol_speed") >= 0 and owner_source.find("get_defense_rate") >= 0 and owner_source.find("get_appearance_rate") >= 0, "owner should contain profile-aware motion-style gated stat resolution")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
