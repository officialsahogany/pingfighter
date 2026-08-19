extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const FREEZE_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_freeze_state.gd"
const ODIN_CC_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_odin_cc_state.gd"

var _failures: Array[String] = []


class FakeSwampState:
	extends RefCounted

	var boss_knockback_timer_frames := 0.0
	var boss_stun_timer_frames := 0.0
	var boss_knockback_vel := 0.0


class FakeMythicRuntime:
	extends RefCounted

	var odins_eye_dark_swamp_state: Object = null


class FakeRegistry:
	extends RefCounted

	var mythic: Object = null
	var requested_keys: Array[String] = []

	func get_cached_instance(key: String) -> Object:
		requested_keys.append(key)
		return mythic if key == "mythic_item_runtime" else null


func _init() -> void:
	_verify_owner_boundaries()
	_verify_freeze_clock_contract()
	_verify_odin_snapshot_contract()
	_verify_host_facades_route_to_owners()

	if _failures.is_empty():
		print("stage7_akamu_control_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundaries() -> void:
	_expect(FileAccess.file_exists(FREEZE_STATE_PATH), "Stage 7 gameplay freeze should have a focused clock owner")
	_expect(FileAccess.file_exists(ODIN_CC_STATE_PATH), "Stage 7 Odin CC should have a focused external-snapshot owner")
	if not FileAccess.file_exists(FREEZE_STATE_PATH) or not FileAccess.file_exists(ODIN_CC_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var freeze_source := FileAccess.get_file_as_string(FREEZE_STATE_PATH)
	var odin_source := FileAccess.get_file_as_string(ODIN_CC_STATE_PATH)
	_expect(
		host_source.find("const Stage7AkamuFreezeState := preload(\"%s\")" % FREEZE_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused freeze owner"
	)
	_expect(
		host_source.find("const Stage7AkamuOdinCcState := preload(\"%s\")" % ODIN_CC_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused Odin snapshot owner"
	)
	_expect(
		host_source.find("var _freeze_state: Object = Stage7AkamuFreezeState.new()") >= 0,
		"Stage7AkamuState should retain one freeze owner instance"
	)
	_expect(
		host_source.find("var _odin_cc_state: Object = Stage7AkamuOdinCcState.new()") >= 0,
		"Stage7AkamuState should retain one Odin snapshot owner instance"
	)
	for marker in [
		"func clear_round_transients(",
		"func begin(",
		"func advance(",
		"func cancel_if_reason(",
		"func is_active(",
		"func has_runtime_state(",
		"func get_snapshot(",
	]:
		_expect(freeze_source.find(marker) >= 0, "focused freeze owner should implement %s" % marker)
	for marker in [
		"func clear_snapshot(",
		"func sync_from_deps(",
		"func get_escape_rewind_x(",
		"func get_snapshot(",
	]:
		_expect(odin_source.find(marker) >= 0, "focused Odin snapshot owner should implement %s" % marker)
	for inline_field in [
		"var _gameplay_freeze_remaining_sec :=",
		"var _gameplay_freeze_reason :=",
		"var _odin_knockback_window_active :=",
		"var _odin_knockback_vel :=",
		"var _odin_stun_residual :=",
	]:
		_expect(host_source.find(inline_field) < 0, "Stage7AkamuState should not retain control field %s" % inline_field)
	_expect(host_source.find("func _sync_odin_cc_window(") < 0, "Odin lookup precedence should live only in its snapshot owner")
	_expect(host_source.find("_freeze_state.advance(") >= 0, "freeze advancement should route through the focused owner")
	_expect(host_source.find("_odin_cc_state.sync_from_deps(") >= 0, "per-frame Odin snapshot should route through the focused owner")


func _verify_freeze_clock_contract() -> void:
	var owner: Object = _new_owner(FREEZE_STATE_PATH)
	if owner == null:
		return
	owner.begin("awakening", 3.0)
	_expect(owner.is_active(), "positive freeze duration should activate the clock")
	_expect(str(owner.reason) == "awakening", "freeze owner should retain its reason")
	_expect(str(owner.advance(1.0)) == "", "partial freeze advance should not emit a completion edge")
	_expect_close(float(owner.remaining_sec), 2.0, "partial freeze advance should subtract exact elapsed time")
	_expect(str(owner.advance(2.0)) == "awakening", "final freeze advance should emit its completed reason once")
	_expect(not owner.is_active(), "completed freeze should become inactive")
	_expect(str(owner.reason) == "", "completed freeze should clear its live reason")
	_expect(str(owner.advance(1.0)) == "", "inactive freeze should not repeat its completion edge")

	owner.begin("superspeed", 0.35)
	_expect(not owner.cancel_if_reason("awakening"), "mismatched cancellation should preserve the live freeze")
	_expect(owner.is_active(), "mismatched cancellation should leave the freeze active")
	_expect(owner.cancel_if_reason("superspeed"), "matching cancellation should clear the live freeze")
	_expect(not owner.is_active(), "matching cancellation should release the freeze")
	owner.begin("debug", -1.0)
	_expect(not owner.is_active() and str(owner.reason) == "", "non-positive begin should remain inactive and clear its reason")


func _verify_odin_snapshot_contract() -> void:
	var owner: Object = _new_owner(ODIN_CC_STATE_PATH)
	if owner == null:
		return
	var swamp := FakeSwampState.new()
	swamp.boss_knockback_timer_frames = 24.0
	swamp.boss_stun_timer_frames = 60.0
	swamp.boss_knockback_vel = -25.0
	owner.sync_from_deps({"odins_eye_dark_swamp_state": swamp})
	_expect(owner.knockback_window_active, "direct Odin dependency should publish the knockback window")
	_expect_close(float(owner.knockback_vel), -25.0, "active knockback should publish its velocity")
	_expect_close(float(owner.stun_residual), -25.0, "active stun should publish its residual")
	_expect_close(float(owner.get_escape_rewind_x()), -25.0, "escape rewind should use active knockback velocity")

	swamp.boss_knockback_timer_frames = 0.0
	swamp.boss_stun_timer_frames = 10.0
	swamp.boss_knockback_vel = -7.0
	owner.sync_from_deps({"odins_eye_dark_swamp_state": swamp})
	_expect(not owner.knockback_window_active, "expired knockback window should clear its active flag")
	_expect_close(float(owner.knockback_vel), 0.0, "expired knockback window should not leak velocity into escape rewind")
	_expect_close(float(owner.stun_residual), -7.0, "stun tail should retain its residual independently")
	_expect_close(float(owner.get_escape_rewind_x()), 0.0, "escape rewind should be zero outside the knockback window")

	var mythic := FakeMythicRuntime.new()
	mythic.odins_eye_dark_swamp_state = swamp
	owner.sync_from_deps({"mythic_item_runtime": mythic})
	_expect_close(float(owner.stun_residual), -7.0, "mythic runtime fallback should resolve the cached swamp state")
	var registry := FakeRegistry.new()
	registry.mythic = mythic
	owner.sync_from_deps({"registry": registry})
	_expect(registry.requested_keys == ["mythic_item_runtime"], "registry fallback should use one non-instantiating cached lookup")
	_expect_close(float(owner.stun_residual), -7.0, "registry fallback should publish the cached swamp snapshot")
	owner.sync_from_deps({})
	var cleared: Dictionary = owner.get_snapshot()
	_expect(not bool(cleared.get("knockback_window_active", true)), "missing Odin state should clear the knockback snapshot")
	_expect_close(float(cleared.get("knockback_vel", 99.0)), 0.0, "missing Odin state should clear knockback velocity")
	_expect_close(float(cleared.get("stun_residual", 99.0)), 0.0, "missing Odin state should clear stun residual")


func _verify_host_facades_route_to_owners() -> void:
	if not FileAccess.file_exists(FREEZE_STATE_PATH) or not FileAccess.file_exists(ODIN_CC_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var freeze_owner: Object = state.get("_freeze_state")
	var odin_owner: Object = state.get("_odin_cc_state")
	_expect(freeze_owner != null, "Stage7AkamuState should expose its freeze owner for diagnostics")
	_expect(odin_owner != null, "Stage7AkamuState should expose its Odin snapshot owner for diagnostics")
	if freeze_owner == null or odin_owner == null:
		return
	state.debug_begin_gameplay_freeze(0.05)
	_expect(state.is_gameplay_freeze_active(), "debug freeze facade should activate the focused owner")
	_expect_close(
		float(state.get_actor_draw_context().get("stage7_akamu_gameplay_freeze_remaining", 0.0)),
		0.05,
		"actor context should publish the focused freeze clock"
	)
	var swamp := FakeSwampState.new()
	swamp.boss_knockback_timer_frames = 24.0
	swamp.boss_stun_timer_frames = 60.0
	swamp.boss_knockback_vel = -25.0
	state.update(0.0, _base_context(), {"odins_eye_dark_swamp_state": swamp})
	_expect(bool(odin_owner.get_snapshot().get("knockback_window_active", false)), "host update should sync the focused Odin snapshot")
	state.clear_round_transients()
	_expect(not freeze_owner.is_active(), "round cleanup should release the focused freeze clock")
	_expect(not bool(odin_owner.get_snapshot().get("knockback_window_active", true)), "round cleanup should clear the focused Odin snapshot")


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"ball_active": true,
		"waiting_for_serve": false,
		"gameplay_timing_frozen": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"ball_pos": Vector2(380.0, 700.0),
	}


func _new_owner(path: String) -> Object:
	if not FileAccess.file_exists(path):
		return null
	var owner_script: Script = load(path)
	return owner_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
