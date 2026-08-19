extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const CLONE_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_clone_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_public_facade_routes_to_owner()

	if _failures.is_empty():
		print("stage7_akamu_clone_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(CLONE_STATE_PATH), "Stage 7 clone lifecycle should have a focused state owner")
	if not FileAccess.file_exists(CLONE_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(CLONE_STATE_PATH)
	_expect(
		host_source.find("const Stage7AkamuCloneState := preload(\"%s\")" % CLONE_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused clone owner"
	)
	_expect(
		host_source.find("var _clone_state: Object = Stage7AkamuCloneState.new()") >= 0,
		"Stage7AkamuState should retain one clone owner instance"
	)
	for marker in [
		"func try_start_cast(",
		"func advance_cast(",
		"func update_entities(",
		"func query_ball_collision(",
		"func begin_dying(",
		"func build_hud_skill(",
		"func clear_round_transients(",
	]:
		_expect(helper_source.find(marker) >= 0, "focused clone owner should implement %s" % marker)
	_expect(
		helper_source.find("const TEMP_GOLDEN_CHANCE := 0.50") >= 0
			and helper_source.find("const TEMP_GOLDEN_MUHON_DROPS := 1") >= 0,
		"focused clone owner should own the locked golden reward constants"
	)
	var velocity_roll_index := helper_source.find("var velocity_x: float = rng.randf_range(")
	var noise_roll_index := helper_source.find("var motion_noise_state: int = rng.randi_range(")
	var golden_roll_index := helper_source.find(
		"var golden: bool = rng.randf() < TEMP_GOLDEN_CHANCE"
	)
	_expect(
		velocity_roll_index >= 0
			and noise_roll_index > velocity_roll_index
			and golden_roll_index > noise_roll_index,
		"golden should roll exactly once at creation after existing movement RNG consumption"
	)
	_expect(
		helper_source.find("\"golden\": bool(nearest_clone.get(\"golden\", false))") >= 0
			and helper_source.find("\"clone_center\": clone_rect.get_center()") >= 0,
		"focused clone owner should return immutable reward data with the collision result"
	)
	for forbidden in [
		"func _advance_clone_motion_tick(",
		"func _find_nearest_clone_hit(",
		"func _get_segment_rect_hit_point(",
		"func _begin_clone_dying(",
	]:
		_expect(host_source.find(forbidden) < 0, "Stage7AkamuState should not retain inline clone logic: %s" % forbidden)
	_expect(
		host_source.find("const TEMP_GOLDEN_CHANCE") < 0
			and host_source.find("rng.randf() < TEMP_GOLDEN_CHANCE") < 0,
		"Stage7AkamuState should not retain golden RNG ownership"
	)


func _verify_public_facade_routes_to_owner() -> void:
	if not FileAccess.file_exists(CLONE_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var helper: Object = state.get("_clone_state")
	_expect(helper != null, "Stage7AkamuState should expose its focused clone owner for diagnostics")
	if helper == null:
		return
	state._clone_casting = true
	_expect(bool(helper.casting), "legacy clone casting property should forward writes to the focused owner")
	state._clone_casting = false
	state.debug_set_clone_cooldown_remaining(3.5)
	_expect(
		state.debug_get_clone_snapshot() == helper.get_snapshot(),
		"debug clone snapshot should forward without rebuilding mutable state"
	)

	state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	_expect(int(helper.get_snapshot().get("live_count", 0)) == 2, "debug spawn should mutate the focused clone owner")
	_expect(
		(state.get_actor_draw_context().get("stage7_akamu_clones", []) as Array) == helper.entities,
		"actor draw context should borrow the focused owner's entity array"
	)
	state.debug_set_clone_cooldown_remaining(3.5)
	var hit: Dictionary = state.query_clone_ball_collision(
		Vector2(270.0, 200.0),
		Vector2(490.0, 200.0),
		Vector2(0.0, -12.0),
		{"current_stage": 7, "ball_active": true, "waiting_for_serve": false, "ball_size": 28.6}
	)
	_expect(not hit.is_empty(), "clone collision facade should query the focused owner")
	_expect(
		hit.has("golden") and hit.has("clone_rect") and hit.has("clone_center"),
		"clone collision facade should preserve the focused owner's reward payload"
	)

	state.clear_round_transients()
	var snapshot: Dictionary = helper.get_snapshot()
	_expect(int(snapshot.get("entity_count", -1)) == 0, "round cleanup should clear focused-owner clones")
	_expect(
		is_equal_approx(float(snapshot.get("cooldown_remaining_sec", 0.0)), 3.5),
		"round cleanup should preserve the clone cooldown"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
