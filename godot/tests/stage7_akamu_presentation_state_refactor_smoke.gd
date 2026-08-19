extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const PRESENTATION_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_presentation_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_attack_pose_lifecycle()
	_verify_status_priority()
	_verify_host_facade_routes_to_owner()

	if _failures.is_empty():
		print("stage7_akamu_presentation_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(PRESENTATION_STATE_PATH), "Stage 7 attack/status presentation should have a focused state owner")
	if not FileAccess.file_exists(PRESENTATION_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(PRESENTATION_STATE_PATH)
	_expect(
		host_source.find("const Stage7AkamuPresentationState := preload(\"%s\")" % PRESENTATION_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused presentation owner"
	)
	_expect(
		host_source.find("var _presentation_state: Object = Stage7AkamuPresentationState.new()") >= 0,
		"Stage7AkamuState should retain one presentation owner instance"
	)
	for marker in [
		"func clear_round_transients(",
		"func set_status(",
		"func trigger_boss_attack(",
		"func update_boss_attack(",
		"func refresh_status(",
		"func has_runtime_state(",
		"func get_snapshot(",
	]:
		_expect(helper_source.find(marker) >= 0, "focused presentation owner should implement %s" % marker)
	for inline_field in [
		"var status :=",
		"var _boss_attack_remaining_sec :=",
		"var _boss_attack_source :=",
		"var _boss_attack_target_x :=",
	]:
		_expect(host_source.find(inline_field) < 0, "Stage7AkamuState should not retain presentation field %s" % inline_field)
	_expect(host_source.find("func _trigger_boss_attack(") < 0, "attack-pose mutation should live only in the presentation owner")
	_expect(host_source.find("func _update_boss_attack(") < 0, "attack-pose ticking should live only in the presentation owner")
	_expect(host_source.find("func _refresh_status(") < 0, "status-priority branching should live only in the presentation owner")


func _verify_attack_pose_lifecycle() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.trigger_boss_attack("boss_paddle_hit", 321.0)
	var snapshot: Dictionary = owner.get_snapshot()
	_expect(bool(snapshot.get("boss_attack_active", false)), "attack trigger should activate the pose clock")
	_expect_close(float(snapshot.get("boss_attack_remaining_sec", 0.0)), 0.20, "attack trigger should arm the exact 0.2-second pose")
	_expect(str(snapshot.get("boss_attack_source", "")) == "boss_paddle_hit", "attack trigger should retain its source")
	_expect_close(float(snapshot.get("boss_attack_target_x", 0.0)), 321.0, "attack trigger should retain its target x")
	owner.update_boss_attack(0.19)
	_expect(bool(owner.get_snapshot().get("boss_attack_active", false)), "attack pose should remain active before 0.2 seconds")
	owner.update_boss_attack(0.011)
	_expect(not bool(owner.get_snapshot().get("boss_attack_active", true)), "attack pose should expire at 0.2 seconds")
	_expect(str(owner.get_snapshot().get("boss_attack_source", "stale")) == "", "attack expiry should clear its source")


func _verify_status_priority() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.trigger_boss_attack("boss_paddle_hit", 0.0)
	var all_active := {
		"gameplay_freeze_active": true,
		"gameplay_freeze_reason": "awakening",
		"escape_active": true,
		"cloud_dash_active": true,
		"cloud_dash_phase": "pre",
		"superspeed_active": true,
		"skill_cooldown_paused": true,
		"clone_casting": true,
		"shuriken_casting": true,
		"live_clones": true,
		"shuriken_active": true,
		"shuriken_gauge_ticks_left": 4,
		"cloud_field_active": true,
		"wind_aura_depleted": true,
		"awakened": true,
	}
	_expect(owner.refresh_status(all_active) == "awakening_freeze", "gameplay freeze should outrank every normal status")
	all_active["gameplay_freeze_active"] = false
	_expect(owner.refresh_status(all_active) == "escape_active", "escape should outrank cloud, Superspeed, and pause")
	all_active["escape_active"] = false
	_expect(owner.refresh_status(all_active) == "cloud_pre", "cloud phase should outrank Superspeed and pause")
	all_active["cloud_dash_active"] = false
	_expect(owner.refresh_status(all_active) == "superspeed_active", "Superspeed should outrank pause and casts")
	all_active["superspeed_active"] = false
	_expect(owner.refresh_status(all_active) == "paused", "cooldown pause should outrank casts")
	all_active["skill_cooldown_paused"] = false
	_expect(owner.refresh_status(all_active) == "clone_casting", "clone casting should outrank shuriken casting")
	all_active["clone_casting"] = false
	_expect(owner.refresh_status(all_active) == "shuriken_casting", "shuriken casting should outrank attack pose")
	all_active["shuriken_casting"] = false
	_expect(owner.refresh_status(all_active) == "boss_hit", "boss contact pose should outrank lingering entities")
	owner.update_boss_attack(0.20)
	_expect(owner.refresh_status(all_active) == "clone_active", "live clone status should follow an expired attack pose")
	for key in ["live_clones", "shuriken_active"]:
		all_active[key] = false
	_expect(owner.refresh_status(all_active) == "shuriken_debuff", "shuriken drain should outrank cloud field and aura")
	all_active["shuriken_gauge_ticks_left"] = 0
	_expect(owner.refresh_status(all_active) == "cloud_active", "cloud field should outrank aura status")
	all_active["cloud_field_active"] = false
	_expect(owner.refresh_status(all_active) == "wind_aura_recharging", "depleted aura should outrank awakened idle")
	all_active["wind_aura_depleted"] = false
	_expect(owner.refresh_status(all_active) == "awakened", "awakened idle should outrank charging")
	all_active["awakened"] = false
	_expect(owner.refresh_status(all_active) == "charging", "inactive presentation should return to charging")


func _verify_host_facade_routes_to_owner() -> void:
	if not FileAccess.file_exists(PRESENTATION_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var owner: Object = state.get("_presentation_state")
	_expect(owner != null, "Stage7AkamuState should expose its presentation owner for diagnostics")
	if owner == null:
		return
	state.handle_boss_paddle_hit({"ball_pos": Vector2(300.0, 400.0)}, _base_context())
	var draw_context: Dictionary = state.get_actor_draw_context()
	_expect(bool(draw_context.get("stage7_akamu_boss_attack_active", false)), "boss-hit facade should trigger the focused attack pose")
	_expect(str(draw_context.get("stage7_akamu_boss_attack_source", "")) == "boss_paddle_hit", "actor context should publish the focused attack source")
	state.clear_round_transients()
	_expect(not bool(owner.get_snapshot().get("boss_attack_active", true)), "round cleanup should clear focused attack presentation")
	_expect(state.get_status() == "charging", "round cleanup should restore focused charging status")


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"ball_active": true,
		"waiting_for_serve": false,
		"gameplay_timing_frozen": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
	}


func _new_owner() -> Object:
	if not FileAccess.file_exists(PRESENTATION_STATE_PATH):
		return null
	var owner_script: Script = load(PRESENTATION_STATE_PATH)
	return owner_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
