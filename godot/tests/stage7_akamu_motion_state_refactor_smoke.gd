extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const MOTION_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_motion_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_priority_and_debug_fallback()
	_verify_composite_intangibility()
	_verify_release_and_odin_result_contract()
	_verify_host_facade_routes_to_owner()

	if _failures.is_empty():
		print("stage7_akamu_motion_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(MOTION_STATE_PATH), "Stage 7 scripted motion should have a focused coordinator owner")
	if not FileAccess.file_exists(MOTION_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(MOTION_STATE_PATH)
	_expect(
		host_source.find("const Stage7AkamuMotionState := preload(\"%s\")" % MOTION_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused motion coordinator"
	)
	_expect(
		host_source.find("var _motion_state: Object = Stage7AkamuMotionState.new()") >= 0,
		"Stage7AkamuState should retain one motion coordinator instance"
	)
	for marker in [
		"func clear_round_transients(",
		"func begin_frame(",
		"func set_external_scripted_motion_active(",
		"func set_boss_ball_intangible_source(",
		"func refresh_boss_ball_intangible(",
		"func set_debug_scripted_position(",
		"func refresh_scripted_motion(",
		"func publish_release(",
		"func has_scripted_skill_conflict(",
		"func build_position_result(",
		"func has_runtime_state(",
	]:
		_expect(helper_source.find(marker) >= 0, "focused motion coordinator should implement %s" % marker)
	for inline_field in [
		"var _boss_ball_intangible :=",
		"var _boss_ball_intangible_sources:",
		"var _scripted_motion_active :=",
		"var _scripted_boss_pos :=",
		"var _debug_scripted_motion_active :=",
		"var _debug_scripted_boss_pos :=",
		"var _external_scripted_motion_active :=",
		"var _boss_position_release_pending :=",
		"var _boss_position_release_pos :=",
	]:
		_expect(host_source.find(inline_field) < 0, "Stage7AkamuState should not retain mutable motion field %s" % inline_field)
	_expect(host_source.find("func _refresh_scripted_motion(") < 0, "scripted-motion priority should live only in the coordinator")
	_expect(host_source.find("func _refresh_boss_ball_intangible(") < 0, "composite intangibility should live only in the coordinator")


func _verify_priority_and_debug_fallback() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.set_debug_scripted_position(true, Vector2(10.0, 11.0))
	owner.refresh_scripted_motion({})
	_expect(owner.scripted_motion_active, "debug position should provide the final scripted-motion fallback")
	_expect(owner.scripted_boss_pos == Vector2(10.0, 11.0), "debug fallback should preserve its authored position")
	_expect(owner.scripted_source == "debug", "debug fallback should identify its source")

	owner.refresh_scripted_motion({
		"shuriken_active": true,
		"shuriken_pos": Vector2(20.0, 21.0),
		"clone_active": true,
		"clone_pos": Vector2(30.0, 31.0),
		"cloud_active": true,
		"cloud_pos": Vector2(40.0, 41.0),
		"escape_active": true,
		"escape_pos": Vector2(50.0, 51.0),
	})
	_expect(owner.scripted_boss_pos == Vector2(50.0, 51.0), "escape should outrank every other scripted-position source")
	_expect(owner.scripted_source == "escape", "escape should own the published source at highest priority")
	owner.refresh_scripted_motion({
		"shuriken_active": true,
		"shuriken_pos": Vector2(20.0, 21.0),
		"clone_active": true,
		"clone_pos": Vector2(30.0, 31.0),
		"cloud_active": true,
		"cloud_pos": Vector2(40.0, 41.0),
	})
	_expect(owner.scripted_boss_pos == Vector2(40.0, 41.0), "cloud should outrank clone and shuriken")
	owner.refresh_scripted_motion({
		"shuriken_active": true,
		"shuriken_pos": Vector2(20.0, 21.0),
		"clone_active": true,
		"clone_pos": Vector2(30.0, 31.0),
	})
	_expect(owner.scripted_boss_pos == Vector2(30.0, 31.0), "clone should outrank shuriken")
	owner.refresh_scripted_motion({"shuriken_active": true, "shuriken_pos": Vector2(20.0, 21.0)})
	_expect(owner.scripted_boss_pos == Vector2(20.0, 21.0), "shuriken should outrank debug fallback")
	owner.set_debug_scripted_position(false)
	owner.refresh_scripted_motion({})
	_expect(not owner.scripted_motion_active, "coordinator should release scripted motion when every source is inactive")


func _verify_composite_intangibility() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.refresh_boss_ball_intangible(true)
	_expect(owner.boss_ball_intangible, "clone contribution should make the boss intangible")
	owner.set_boss_ball_intangible_source("cloud", true, false)
	owner.set_boss_ball_intangible_source("escape", true, false)
	_expect(owner.boss_ball_intangible, "external sources should compose without replacing one another")
	owner.set_boss_ball_intangible_source("cloud", false, false)
	_expect(owner.boss_ball_intangible, "clearing one source should preserve the remaining contributor")
	owner.set_boss_ball_intangible_source("escape", false, false)
	_expect(not owner.boss_ball_intangible, "clearing the final source should restore tangibility")
	owner.set_boss_ball_intangible_source("shadow_clone", true, false)
	_expect(not owner.boss_ball_intangible, "shadow_clone should remain reserved for the clone owner's direct contribution")
	owner.set_boss_ball_intangible_source("  ", true, false)
	_expect(not owner.boss_ball_intangible, "blank intangibility sources should be ignored")


func _verify_release_and_odin_result_contract() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.publish_release(Vector2(70.0, 71.0))
	var result: Dictionary = owner.build_position_result(false, 0.0)
	_expect(result.get("boss_pos", Vector2.ZERO) == Vector2(70.0, 71.0), "completed motion should publish its exact release position")
	owner.begin_frame()
	_expect(owner.build_position_result(false, 0.0).is_empty(), "release position should be delivered for only one advancing frame")

	owner.refresh_scripted_motion({"clone_active": true, "clone_pos": Vector2(100.0, 25.0)})
	_expect(owner.build_position_result(true, 0.0).is_empty(), "clone pin should yield completely during Odin knockback")
	result = owner.build_position_result(false, -12.0)
	_expect(result.get("boss_pos", Vector2.ZERO) == Vector2(88.0, 25.0), "clone pin should preserve Odin stun residual after knockback")
	owner.refresh_scripted_motion({"escape_active": true, "escape_pos": Vector2(200.0, 25.0)})
	result = owner.build_position_result(true, -12.0)
	_expect(result.get("boss_pos", Vector2.ZERO) == Vector2(200.0, 25.0), "escape should retain its exact authored position through Odin CC")


func _verify_host_facade_routes_to_owner() -> void:
	if not FileAccess.file_exists(MOTION_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var owner: Object = state.get("_motion_state")
	_expect(owner != null, "Stage7AkamuState should expose its motion coordinator for diagnostics")
	if owner == null:
		return
	state.debug_set_scripted_boss_position(true, Vector2(123.0, 45.0))
	_expect(owner.scripted_motion_active, "debug scripted-position facade should mutate the coordinator")
	_expect(state.get_boss_ai_context().get("stage7_akamu_scripted_boss_pos", Vector2.ZERO) == Vector2(123.0, 45.0), "AI context should publish the coordinator position")
	state.set_boss_ball_intangible_source("external_test", true)
	_expect(owner.boss_ball_intangible, "public intangibility facade should mutate the coordinator")
	state.clear_round_transients()
	_expect(not owner.scripted_motion_active, "round cleanup should release coordinator scripted motion")
	_expect(not owner.boss_ball_intangible, "round cleanup should clear coordinator intangibility")
	_expect(not owner.release_pending, "round cleanup should clear coordinator release delivery")


func _new_owner() -> Object:
	if not FileAccess.file_exists(MOTION_STATE_PATH):
		return null
	var owner_script: Script = load(MOTION_STATE_PATH)
	return owner_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
