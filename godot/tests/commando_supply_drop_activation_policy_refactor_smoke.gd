extends SceneTree

const POLICY_PATH := "res://scripts/characters/commando_supply_drop_activation_policy.gd"
const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"

var _failures: Array[String] = []


class FakeSkillConfig:
	extends RefCounted

	var cost := 350.0
	var cooldown := 40.0

	func get_skill_cost(skill_name: String) -> float:
		return cost if skill_name == "supply_drop" else 0.0

	func get_cooldown_seconds(skill_name: String) -> float:
		return cooldown if skill_name == "supply_drop" else 0.0


class FakeSkillState:
	extends RefCounted

	var remaining := 0.0
	var calls: Array = []

	func get_cooldown_remaining(skill_name: String, current_msec: int, cooldown: float) -> float:
		calls.append([skill_name, current_msec, cooldown])
		return remaining


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false
	var player_serves := false
	var serve_timer := 0.0
	var round_start_time_msec := 0

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve

	func does_player_serve() -> bool:
		return player_serves

	func get_round_start_time_msec() -> int:
		return round_start_time_msec

	func get_snapshot() -> Dictionary:
		return {
			"serve_timer": serve_timer,
			"round_start_time_msec": round_start_time_msec,
		}


class SnapshotOnlyRoundState:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeTransformSource:
	extends RefCounted

	var transformed := false

	func is_odins_eye_transformed() -> bool:
		return transformed


class FakeEmergencyMethodState:
	extends RefCounted

	var suppress_until_msec := 0

	func is_supply_drop_hold_suppressed(current_msec: int) -> bool:
		return current_msec < suppress_until_msec


class FakeEmergencySnapshotState:
	extends RefCounted

	var suppress_until_msec := 0

	func get_snapshot() -> Dictionary:
		return {"suppress_until_msec": suppress_until_msec}


func _init() -> void:
	_verify_owner_boundary()
	_verify_input_and_character_gates()
	_verify_transform_and_emergency_gates()
	_verify_round_timing_contract()
	_verify_resource_and_cooldown_contract()

	if _failures.is_empty():
		print("commando_supply_drop_activation_policy_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(POLICY_PATH), "Commando Supply Drop activation should have a focused policy owner")
	if not FileAccess.file_exists(POLICY_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var policy_source := FileAccess.get_file_as_string(POLICY_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropActivationPolicy := preload(\"%s\")" % POLICY_PATH) >= 0,
		"Supply Drop state should preload the focused activation policy"
	)
	_expect(
		host_source.find("var _activation_policy: Object = CommandoSupplyDropActivationPolicy.new()") >= 0,
		"Supply Drop state should retain one activation policy instance"
	)
	for marker in [
		"func get_current_msec(",
		"func is_supply_drop_hold_pressed(",
		"func can_accept_supply_hold(",
		"func is_supply_drop_activation_ready(",
		"func can_activate(",
	]:
		_expect(policy_source.find(marker) >= 0, "activation policy should implement %s" % marker)
	for moved_marker in [
		"func _can_hold_for_activation(",
		"func _can_accept_supply_hold(",
		"func _is_supply_drop_activation_ready(",
		"func _can_activate(",
		"func _is_supply_drop_hold_pressed(",
		"func _is_commando_selected(",
		"func _is_original_skill_blocked(",
		"func _is_transform_skill_blocked(",
		"func _is_emergency_supply_suppressing(",
		"func _is_round_state_allowing_supply_drop(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop state should not retain activation marker %s" % moved_marker)
	for moved_key in [
		"\"commando_original_skills_blocked\"",
		"\"odins_eye_transformed\"",
		"\"commando_supply_drop_ignore_round_gate\"",
		"\"commando_supply_drop_hold_pressed\"",
	]:
		_expect(host_source.find(moved_key) < 0, "Supply Drop state should not retain activation-policy key %s" % moved_key)
	_expect(
		host_source.find("_activation_policy.is_supply_drop_hold_pressed(input_snapshot)") >= 0,
		"input path should delegate hold aliases to the activation policy"
	)
	_expect(
		host_source.find("_activation_policy.can_accept_supply_hold(deps, current_msec)") >= 0,
		"input path should delegate immediate hold acceptance to the activation policy"
	)
	_expect(
		host_source.find("_activation_policy.is_supply_drop_activation_ready(") >= 0,
		"input path should delegate round/resource readiness to the activation policy"
	)


func _verify_input_and_character_gates() -> void:
	var policy: Object = _new_policy()
	if policy == null:
		return
	for key in ["down_pressed", "supply_drop_hold_pressed", "commando_supply_drop_hold_pressed"]:
		var input_snapshot: Dictionary = {}
		input_snapshot[key] = true
		_expect(policy.is_supply_drop_hold_pressed(input_snapshot), "%s should activate the shared Supply Drop hold command" % key)
	_expect(not policy.is_supply_drop_hold_pressed({}), "missing hold aliases should leave Supply Drop idle")
	_expect(policy.can_accept_supply_hold({}, 1000), "missing character identity should retain the compatibility allow path")
	_expect(policy.can_accept_supply_hold({"selected_character_type": " COMMANDO "}, 1000), "Commando identity should be normalized")
	_expect(policy.can_accept_supply_hold({"selected_character_type": "soldier"}, 1000), "legacy Soldier identity should remain accepted")
	_expect(not policy.can_accept_supply_hold({"selected_character_type": "viper"}, 1000), "non-Commando identity should be rejected")
	for key in [
		"commando_original_skills_blocked",
		"soldier_original_skills_blocked",
		"original_skills_blocked",
		"character_original_skills_blocked",
		"commando_skills_blocked",
		"character_skills_blocked",
	]:
		var deps: Dictionary = {}
		deps[key] = true
		_expect(not policy.can_accept_supply_hold(deps, 1000), "%s should block Supply Drop hold" % key)


func _verify_transform_and_emergency_gates() -> void:
	var policy: Object = _new_policy()
	if policy == null:
		return
	for key in [
		"odins_eye_transformed",
		"horn_strawberry_transformed",
		"commando_transformed",
		"character_transformed",
		"original_skill_transform_active",
	]:
		var deps: Dictionary = {}
		deps[key] = true
		_expect(not policy.can_accept_supply_hold(deps, 1000), "%s should block the original Supply Drop skill" % key)
	var transform_source := FakeTransformSource.new()
	transform_source.transformed = true
	_expect(
		not policy.can_accept_supply_hold({"mythic_item_runtime": transform_source}, 1000),
		"runtime transform method should block the original Supply Drop skill"
	)
	var emergency_method := FakeEmergencyMethodState.new()
	emergency_method.suppress_until_msec = 1200
	_expect(
		not policy.can_accept_supply_hold({"commando_emergency_supply_state": emergency_method}, 1199),
		"Emergency Supply method gate should suppress the competing hold"
	)
	_expect(
		policy.can_accept_supply_hold({"commando_emergency_supply_state": emergency_method}, 1200),
		"Emergency Supply method gate should release on the exact expiry edge"
	)
	var emergency_snapshot := FakeEmergencySnapshotState.new()
	emergency_snapshot.suppress_until_msec = 1200
	_expect(
		not policy.can_accept_supply_hold({"commando_emergency_supply_state": emergency_snapshot}, 1199),
		"Emergency Supply snapshot fallback should suppress the competing hold"
	)


func _verify_round_timing_contract() -> void:
	var policy: Object = _new_policy()
	if policy == null:
		return
	var config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var round_state := FakeRoundState.new()
	round_state.waiting_for_serve = true
	round_state.player_serves = false
	_expect(
		not policy.is_supply_drop_activation_ready(500.0, config, skill_state, {"round_state": round_state}, 10_000),
		"boss serve wait should block Supply Drop"
	)
	round_state.player_serves = true
	round_state.serve_timer = 5.999
	_expect(
		not policy.is_supply_drop_activation_ready(500.0, config, skill_state, {"round_state": round_state}, 10_000),
		"player serve hold should stay blocked before six seconds"
	)
	round_state.serve_timer = 6.0
	_expect(
		policy.is_supply_drop_activation_ready(500.0, config, skill_state, {"round_state": round_state}, 10_000),
		"player serve hold should unlock at exactly six seconds"
	)
	round_state.waiting_for_serve = false
	round_state.round_start_time_msec = 10_000
	_expect(
		not policy.is_supply_drop_activation_ready(500.0, config, skill_state, {"round_state": round_state}, 12_999),
		"post-serve lock should remain active before three seconds"
	)
	_expect(
		policy.is_supply_drop_activation_ready(500.0, config, skill_state, {"round_state": round_state}, 13_000),
		"post-serve lock should release at exactly three seconds"
	)
	_expect(
		policy.is_supply_drop_activation_ready(
			500.0,
			config,
			skill_state,
			{"round_state": round_state, "commando_supply_drop_ignore_round_gate": true},
			10_000
		),
		"explicit round-gate bypass should remain authoritative"
	)
	var snapshot_round := SnapshotOnlyRoundState.new()
	snapshot_round.snapshot = {"round_start_time_msec": 10_000}
	_expect(
		not policy.is_supply_drop_activation_ready(500.0, config, skill_state, {"round_state": snapshot_round}, 12_999),
		"snapshot-only round state should preserve the post-serve lock fallback"
	)
	_expect(policy.get_current_msec({"current_msec": 4321}) == 4321, "provided deterministic clock should override Time ticks")


func _verify_resource_and_cooldown_contract() -> void:
	var policy: Object = _new_policy()
	if policy == null:
		return
	var config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	_expect(not policy.can_activate(349.999, config, skill_state, 5000), "gauge below configured cost should reject activation")
	_expect(policy.can_activate(350.0, config, skill_state, 5000), "exact configured gauge cost should pass when cooldown is ready")
	_expect(skill_state.calls == [["supply_drop", 5000, 40.0]], "cooldown gate should query the configured base cooldown once")
	skill_state.remaining = 0.001
	_expect(not policy.can_activate(500.0, config, skill_state, 5000), "positive cooldown residual should reject activation")
	_expect(not policy.can_activate(349.999, null, null, 5000), "missing config should preserve the 350 gauge fallback")
	_expect(policy.can_activate(350.0, null, null, 5000), "missing skill state should preserve the ready fallback")


func _new_policy() -> Object:
	if not FileAccess.file_exists(POLICY_PATH):
		return null
	var policy_script: Script = load(POLICY_PATH)
	return policy_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
