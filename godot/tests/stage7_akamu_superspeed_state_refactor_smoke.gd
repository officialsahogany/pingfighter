extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const SUPERSPEED_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_superspeed_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_public_facade_routes_to_owner()
	_verify_cooldown_contract_and_round_boundary()

	if _failures.is_empty():
		print("stage7_akamu_superspeed_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(SUPERSPEED_STATE_PATH), "Stage 7 Superspeed should have a focused state owner")
	if not FileAccess.file_exists(SUPERSPEED_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(SUPERSPEED_STATE_PATH)
	_expect(
		host_source.find("const Stage7AkamuSuperspeedState := preload(\"%s\")" % SUPERSPEED_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused Superspeed owner"
	)
	_expect(
		host_source.find("var _superspeed_state: Object = Stage7AkamuSuperspeedState.new()") >= 0,
		"Stage7AkamuState should retain one Superspeed owner instance"
	)
	for marker in [
		"func try_start(",
		"func advance_runtime(",
		"func advance_freeze(",
		"func notify_dash_started(",
		"func notify_dash_finished(",
		"func build_hud_skill(",
		"func clear_round_transients(",
	]:
		_expect(helper_source.find(marker) >= 0, "focused Superspeed owner should implement %s" % marker)
	_expect(
		helper_source.count("const COOLDOWN_SEC := 50.0") == 1,
		"focused Superspeed owner should define the shared 50-second cooldown exactly once"
	)
	_expect(
		host_source.find("const SUPERSPEED_COOLDOWN_SEC") < 0
			and host_source.find("const TEMP_STAGE7_ULTIMATE_COOLDOWN_SEC") < 0,
		"Stage7AkamuState should not duplicate the Superspeed cooldown constant"
	)
	var end_body := _function_body(helper_source, "func _end() -> void:")
	_expect(
		end_body.find("cooldown_remaining_sec = COOLDOWN_SEC") >= 0,
		"natural expiry should reuse the focused owner's shared cooldown constant"
	)
	for forbidden in [
		"func _spawn_superspeed_afterimages(",
		"func _update_superspeed_afterimages(",
		"func _spawn_superspeed_dark_particles(",
		"func _advance_superspeed_dark_particles_tick(",
		"func _spawn_superspeed_trail(",
		"func _advance_superspeed_trails_tick(",
		"func _finish_superspeed_dash(",
		"func _end_superspeed(",
	]:
		_expect(host_source.find(forbidden) < 0, "Stage7AkamuState should not retain inline Superspeed logic: %s" % forbidden)


func _verify_public_facade_routes_to_owner() -> void:
	if not FileAccess.file_exists(SUPERSPEED_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var helper: Object = state.get("_superspeed_state")
	_expect(helper != null, "Stage7AkamuState should expose its focused Superspeed owner for diagnostics")
	if helper == null:
		return
	state._superspeed_active = true
	_expect(bool(helper.active), "legacy Superspeed active property should forward writes to the focused owner")
	state._superspeed_active = false
	state.debug_set_awakened(true)
	state.debug_set_gauge(300.0)
	var context := {
		"current_stage": 7,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_shrink_scale": 0.45,
	}
	_expect(state.debug_start_superspeed(context), "debug Superspeed start should mutate the focused owner")
	_expect_close(state.debug_get_gauge(), 50.0, "focused owner should commit the 250-gauge activation cost")
	_expect(
		state.debug_get_superspeed_snapshot() == helper.get_snapshot(),
		"debug Superspeed snapshot should forward without rebuilding mutable state"
	)

	state.notify_superspeed_dash_started(
		Vector2(330.0, 25.0),
		Vector2(100.0, 40.0),
		1,
		710.0,
		11.0
	)
	_expect(helper.afterimages.size() == 5, "dash notification should create five focused-owner afterimages")
	var draw_context: Dictionary = state.get_actor_draw_context()
	_expect(
		(draw_context.get("stage7_akamu_superspeed_afterimages", []) as Array) == helper.afterimages,
		"actor draw context should borrow the focused owner's afterimage array"
	)
	helper.advance_runtime(2.0, 1.0 / 30.0, context, state.get("_rng"))
	_expect(not helper.dark_particles.is_empty(), "focused owner should advance Superspeed dark particles")
	_expect(not helper.trails.is_empty(), "focused owner should advance Superspeed trails")

	state.debug_set_superspeed_cooldown_remaining(3.5)
	state.clear_round_transients()
	var snapshot: Dictionary = helper.get_snapshot()
	_expect(not bool(snapshot.get("active", true)), "round cleanup should cancel focused-owner Superspeed")
	_expect(int(snapshot.get("afterimage_count", -1)) == 0, "round cleanup should clear focused-owner Superspeed afterimages")
	_expect(int(snapshot.get("dark_particle_count", -1)) == 0, "round cleanup should clear focused-owner Superspeed particles")
	_expect(int(snapshot.get("trail_count", -1)) == 0, "round cleanup should clear focused-owner Superspeed trails")
	_expect_close(
		float(snapshot.get("cooldown_remaining_sec", 0.0)),
		3.5,
		"round cleanup should preserve the Superspeed cooldown"
	)


func _verify_cooldown_contract_and_round_boundary() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_set_awakened(true)
	state.debug_set_gauge(250.0)
	_expect(state.debug_start_superspeed(_base_context()), "cooldown fixture should start Superspeed")
	var helper: Object = state.get("_superspeed_state")
	helper.advance_runtime(0.0, 10.001, _base_context(), state.get("_rng"))
	var snapshot: Dictionary = helper.get_snapshot()
	_expect(not bool(snapshot.get("active", true)), "focused owner should end Superspeed naturally")
	_expect_close(
		float(snapshot.get("cooldown_remaining_sec", 0.0)),
		50.0,
		"natural end should arm the shared 50-second cooldown"
	)
	_expect_close(
		float(snapshot.get("cooldown_total_sec", 0.0)),
		50.0,
		"focused owner snapshot should expose its shared cooldown total"
	)
	state.clear_round_transients()
	_expect_close(
		float(helper.get_snapshot().get("cooldown_remaining_sec", 0.0)),
		50.0,
		"round cleanup should preserve the newly armed 50-second cooldown"
	)
	helper.tick_cooldown(49.999)
	_expect(float(helper.cooldown_remaining_sec) > 0.0, "cooldown should remain closed before 50 seconds")
	helper.tick_cooldown(0.002)
	_expect_close(float(helper.cooldown_remaining_sec), 0.0, "cooldown should reopen after 50 seconds")


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
	}


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
