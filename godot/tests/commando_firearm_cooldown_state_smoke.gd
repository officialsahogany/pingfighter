extends SceneTree

const CommandoFirearmCooldownState := preload("res://scripts/characters/commando_firearm_cooldown_state.gd")

var _failures: Array[String] = []


class FakeSkillConfig:
	extends RefCounted

	var cooldowns: Dictionary

	func _init(initial_cooldowns: Dictionary = {}) -> void:
		cooldowns = initial_cooldowns

	func get_cooldown_seconds(weapon_id: String) -> float:
		return float(cooldowns.get(weapon_id, 0.0))


class FakeCooldownState:
	extends RefCounted

	var trigger_calls: Array = []
	var configured_calls: Array = []
	var cooldown_remaining: float = 0.0
	var cooldown_queries: Array = []

	func trigger_cooldown(weapon_id: String, now_msec: int, cooldown_seconds: float) -> void:
		trigger_calls.append({
			"weapon_id": weapon_id,
			"now_msec": now_msec,
			"cooldown_seconds": cooldown_seconds,
		})

	func trigger_configured_cooldown(weapon_id: String, now_msec: int, skill_config: Object) -> void:
		configured_calls.append({
			"weapon_id": weapon_id,
			"now_msec": now_msec,
			"skill_config": skill_config,
		})

	func get_cooldown_remaining(weapon_id: String, now_msec: int, cooldown_seconds: float) -> float:
		cooldown_queries.append({
			"weapon_id": weapon_id,
			"now_msec": now_msec,
			"cooldown_seconds": cooldown_seconds,
		})
		return cooldown_remaining


class FakeConfiguredOnlyState:
	extends RefCounted

	var configured_calls: Array = []

	func trigger_configured_cooldown(weapon_id: String, now_msec: int, skill_config: Object) -> void:
		configured_calls.append({
			"weapon_id": weapon_id,
			"now_msec": now_msec,
			"skill_config": skill_config,
		})


func _init() -> void:
	_verify_direct_cooldown_math()
	_verify_ready_query_uses_configured_cooldown()
	_verify_trigger_prefers_explicit_cooldown()
	_verify_trigger_falls_back_to_configured_cooldown()
	_verify_missing_skill_state_is_noop()
	_verify_removed_runtime_cooldown_bridges()

	if _failures.is_empty():
		print("commando_firearm_cooldown_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_cooldown_math() -> void:
	var skill_config := FakeSkillConfig.new({"ak47": 10.0})
	var active_seconds: float = CommandoFirearmCooldownState.get_skill_cooldown_seconds(
		"ak47",
		skill_config,
		{"fire_rate_multiplier": 0.5},
		true,
		1.0
	)
	_expect(is_equal_approx(active_seconds, 5.0), "active doping should scale configured cooldown seconds")

	var inactive_seconds: float = CommandoFirearmCooldownState.get_skill_cooldown_seconds(
		"ak47",
		skill_config,
		{"fire_rate_multiplier": 0.5},
		false,
		1.0
	)
	_expect(is_equal_approx(inactive_seconds, 10.0), "inactive doping should preserve configured cooldown seconds")
	_expect(
		is_equal_approx(CommandoFirearmCooldownState.get_skill_cooldown_seconds("missing", null, {}, true, 0.5), 0.0),
		"missing skill config should keep zero cooldown seconds"
	)


func _verify_ready_query_uses_configured_cooldown() -> void:
	var state := FakeCooldownState.new()
	state.cooldown_remaining = 1.25
	var ready_with_remaining: bool = CommandoFirearmCooldownState.is_ready(
		"bazooka",
		4321,
		{
			"skill_state": state,
			"skill_config": FakeSkillConfig.new({"bazooka": 8.0}),
		}
	)
	_expect(not ready_with_remaining, "ready query should block when cooldown remains")
	_expect(state.cooldown_queries.size() == 1, "ready query should ask skill state once")
	if not state.cooldown_queries.is_empty():
		var cooldown_query: Dictionary = state.cooldown_queries[0]
		_expect(str(cooldown_query.get("weapon_id", "")) == "bazooka", "ready query should preserve weapon id")
		_expect(int(cooldown_query.get("now_msec", 0)) == 4321, "ready query should preserve timestamp")
		_expect(is_equal_approx(float(cooldown_query.get("cooldown_seconds", 0.0)), 8.0), "ready query should pass configured cooldown seconds")

	state.cooldown_remaining = 0.0
	_expect(
		CommandoFirearmCooldownState.is_ready("bazooka", 4333, {
			"skill_state": state,
			"skill_config": FakeSkillConfig.new({"bazooka": 8.0}),
		}),
		"ready query should pass when no cooldown remains"
	)
	_expect(CommandoFirearmCooldownState.is_ready("bazooka", 4333, {}), "missing skill state should be ready")
	_expect(CommandoFirearmCooldownState.is_ready("pistol", 4333, {}), "base pistol should bypass skill cooldown")


func _verify_trigger_prefers_explicit_cooldown() -> void:
	var state := FakeCooldownState.new()
	var config := FakeSkillConfig.new({"bazooka": 8.0})
	CommandoFirearmCooldownState.trigger_skill_cooldown(
		"bazooka",
		1234,
		{
			"skill_state": state,
			"skill_config": config,
		},
		{"fire_rate_multiplier": 0.25},
		true,
		1.0
	)
	_expect(state.trigger_calls.size() == 1, "cooldown owner should prefer trigger_cooldown when available")
	_expect(state.configured_calls.is_empty(), "cooldown owner should not also call configured cooldown")
	var cooldown_call: Dictionary = state.trigger_calls[0]
	_expect(str(cooldown_call.get("weapon_id", "")) == "bazooka", "trigger_cooldown should preserve weapon id")
	_expect(is_equal_approx(float(cooldown_call.get("cooldown_seconds", 0.0)), 2.0), "trigger_cooldown should receive scaled cooldown seconds")


func _verify_trigger_falls_back_to_configured_cooldown() -> void:
	var state := FakeConfiguredOnlyState.new()
	var config := FakeSkillConfig.new({"net_gun": 6.0})
	CommandoFirearmCooldownState.trigger_skill_cooldown(
		"net_gun",
		5678,
		{
			"skill_state": state,
			"skill_config": config,
		},
		{},
		false,
		1.0
	)
	_expect(state.configured_calls.size() == 1, "cooldown owner should fall back to trigger_configured_cooldown")
	var fallback_call: Dictionary = state.configured_calls[0]
	_expect(str(fallback_call.get("weapon_id", "")) == "net_gun", "configured fallback should preserve weapon id")
	_expect(fallback_call.get("skill_config", null) == config, "configured fallback should pass skill config through")

	var direct_state := FakeConfiguredOnlyState.new()
	CommandoFirearmCooldownState.trigger_configured_cooldown(
		"bowling_trap",
		9012,
		{
			"skill_state": direct_state,
			"skill_config": config,
		}
	)
	_expect(direct_state.configured_calls.size() == 1, "direct configured trigger should call configured cooldown")
	_expect(str(direct_state.configured_calls[0].get("weapon_id", "")) == "bowling_trap", "direct configured trigger should preserve weapon id")


func _verify_missing_skill_state_is_noop() -> void:
	CommandoFirearmCooldownState.trigger_skill_cooldown("ak47", 0, {}, {}, false, 1.0)
	CommandoFirearmCooldownState.trigger_configured_cooldown("net_gun", 0, {})
	_expect(true, "missing skill state should be a no-op")


func _verify_removed_runtime_cooldown_bridges() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_is_ready",
		"_trigger_firearm_skill_cooldown",
		"_get_firearm_skill_cooldown_seconds",
	]:
		_expect(runtime_source.find("func %s(" % bridge_name) == -1, "runtime should not keep cooldown bridge %s" % bridge_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
