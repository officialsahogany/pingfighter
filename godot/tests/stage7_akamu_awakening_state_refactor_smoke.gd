extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const AWAKENING_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_awakening_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_owner_lifecycle()
	_verify_public_facade_routes_to_owner()

	if _failures.is_empty():
		print("stage7_akamu_awakening_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(AWAKENING_STATE_PATH), "Stage 7 Awakening/Wind Aura should have a focused state owner")
	if not FileAccess.file_exists(AWAKENING_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(AWAKENING_STATE_PATH)
	_expect(
		host_source.find("const Stage7AkamuAwakeningState := preload(\"%s\")" % AWAKENING_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused Awakening/Wind Aura owner"
	)
	_expect(
		host_source.find("var _awakening_state: Object = Stage7AkamuAwakeningState.new()") >= 0,
		"Stage7AkamuState should retain one Awakening/Wind Aura owner instance"
	)
	for marker in [
		"func handle_score_event(",
		"func sync_trigger(",
		"func try_begin_intro(",
		"func complete_awakening(",
		"func resolve_collision(",
		"func spawn_depletion_burst(",
		"func advance_runtime(",
		"func advance_freeze_visuals(",
		"func tick_recharge(",
		"func clear_round_transients(",
	]:
		_expect(helper_source.find(marker) >= 0, "focused Awakening owner should implement %s" % marker)
	var free_skill_index := host_source.find("_try_start_clone_cast(context, true, true, \"wind_aura\", true)")
	var burst_index := host_source.find("_awakening_state.spawn_depletion_burst")
	_expect(
		free_skill_index >= 0 and burst_index > free_skill_index,
		"fifth-hit disperse particles should consume shared RNG after free-skill execution"
	)
	for forbidden in [
		"func _update_wind_aura_visuals(",
		"func _init_wind_aura_particles(",
		"func _spawn_wind_burst(",
		"func _update_wind_burst_particles(",
		"func _update_wind_aura_recharge(",
		"func _sync_wind_aura_draw_context(",
		"func _get_wind_aura_ripple_intensity(",
	]:
		_expect(host_source.find(forbidden) < 0, "Stage7AkamuState should not retain inline aura lifecycle logic: %s" % forbidden)


func _verify_owner_lifecycle() -> void:
	if not FileAccess.file_exists(AWAKENING_STATE_PATH):
		return
	var owner_script: Script = load(AWAKENING_STATE_PATH)
	var owner: Object = owner_script.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77101
	owner.handle_score_event({"player_score": Stage7AkamuState.AWAKEN_SCORE_THRESHOLD})
	_expect(bool(owner.trigger_armed), "reaching the awaken score threshold should arm the focused Awakening owner")
	_expect(owner.try_begin_intro(false), "focused owner should promote the armed edge to a pending intro")
	_expect(owner.complete_awakening(Vector2(380.0, 45.0), rng, false), "focused owner should complete a pending Awakening")
	var snapshot: Dictionary = owner.get_snapshot()
	_expect(bool(snapshot.get("awakened", false)), "focused owner should commit Awakening")
	_expect(bool(snapshot.get("active", false)), "Awakening should activate the focused Wind Aura")
	_expect(int(snapshot.get("particle_count", 0)) == 24, "focused owner should initialize 24 persistent aura particles")
	_expect(int(snapshot.get("burst_particle_count", 0)) == 48, "focused owner should initialize 48 Awakening burst particles")

	for _hit_index in range(5):
		owner.clear_hit_cooldown()
		var hit: Dictionary = owner.resolve_collision(
			Vector2(380.0, 45.0),
			Vector2(0.0, -20.0),
			Vector2(380.0, 45.0),
			true,
			true,
			false,
			rng
		)
		_expect(not hit.is_empty(), "focused owner should resolve aura hit %d" % (_hit_index + 1))
		if bool(hit.get("_wind_aura_disperse_burst_pending", false)):
			owner.spawn_depletion_burst(Vector2(380.0, 45.0), rng, false)
	snapshot = owner.get_snapshot()
	_expect(int(snapshot.get("hit_count", 0)) == 5, "focused owner should spend all five aura hits")
	_expect(bool(snapshot.get("depleted", false)), "fifth focused-owner hit should deplete the aura")
	_expect_close(float(snapshot.get("recharge_remaining_sec", 0.0)), 10.0, "depletion should start a ten-second recharge")
	_expect(int(snapshot.get("burst_particle_count", 0)) == 32, "depletion should replace the burst with 32 disperse particles")
	owner.clear_round_transients()
	snapshot = owner.get_snapshot()
	_expect(bool(snapshot.get("awakened", false)), "round cleanup should preserve focused-owner Awakening")
	_expect(bool(snapshot.get("depleted", false)), "round cleanup should preserve focused-owner depletion")
	_expect(int(snapshot.get("hit_count", 0)) == 5, "round cleanup should preserve spent aura hits")
	_expect_close(float(snapshot.get("recharge_remaining_sec", 0.0)), 10.0, "round cleanup should preserve the recharge clock")
	_expect(int(snapshot.get("burst_particle_count", -1)) == 0, "round cleanup should clear transient aura bursts")


func _verify_public_facade_routes_to_owner() -> void:
	if not FileAccess.file_exists(AWAKENING_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var helper: Object = state.get("_awakening_state")
	_expect(helper != null, "Stage7AkamuState should expose its focused Awakening owner for diagnostics")
	if helper == null:
		return
	state.awakened = true
	_expect(bool(helper.awakened), "legacy awakened property should forward writes to the focused owner")
	state.awakened = false
	state.debug_seed_rng(77102)
	state.debug_force_complete_awakening(Vector2(330.0, 25.0), Vector2(100.0, 40.0))
	_expect(state.debug_get_wind_aura_snapshot() == helper.get_snapshot(), "debug aura snapshot should forward without rebuilding mutable state")
	var actor_context: Dictionary = state.get_actor_draw_context()
	_expect(
		(actor_context.get("stage7_akamu_wind_burst_particles", []) as Array) == helper.burst_particles,
		"actor draw context should borrow focused-owner burst particles"
	)
	_expect(
		(actor_context.get("stage7_akamu_wind_aura", {}) as Dictionary) == helper.draw_context,
		"actor draw context should borrow the focused owner's aura payload"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
