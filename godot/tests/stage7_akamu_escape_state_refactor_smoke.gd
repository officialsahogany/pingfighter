extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const ESCAPE_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_escape_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_public_facade_routes_to_owner()

	if _failures.is_empty():
		print("stage7_akamu_escape_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(ESCAPE_STATE_PATH), "Stage 7 Stun/Net Escape should have a focused state owner")
	if not FileAccess.file_exists(ESCAPE_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(ESCAPE_STATE_PATH)
	_expect(
		host_source.find("const Stage7AkamuEscapeState := preload(\"%s\")" % ESCAPE_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused Escape owner"
	)
	_expect(
		host_source.find("var _escape_state: Object = Stage7AkamuEscapeState.new()") >= 0,
		"Stage7AkamuState should retain one Escape owner instance"
	)
	for marker in [
		"func update_trigger(",
		"func try_start(",
		"func advance(",
		"func get_disable_context(",
		"func get_boss_pos(",
		"func clear_round_transients(",
	]:
		_expect(helper_source.find(marker) >= 0, "focused Escape owner should implement %s" % marker)
	for forbidden in [
		"func _get_escape_disable_context(",
		"func _clear_escape_disable_effects(",
		"func _refresh_escape_afterimages(",
		"func _update_hologram(",
		"func _get_escape_boss_pos(",
	]:
		_expect(host_source.find(forbidden) < 0, "Stage7AkamuState should not retain inline Escape logic: %s" % forbidden)


func _verify_public_facade_routes_to_owner() -> void:
	if not FileAccess.file_exists(ESCAPE_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var helper: Object = state.get("_escape_state")
	_expect(helper != null, "Stage7AkamuState should expose its focused Escape owner for diagnostics")
	if helper == null:
		return
	state._escape_episode_active = true
	state._escape_attempted = true
	_expect(bool(helper.episode_active), "legacy Escape episode property should forward writes to the focused owner")
	_expect(bool(helper.attempted), "legacy Escape attempt property should forward writes to the focused owner")
	state._escape_episode_active = false
	state._escape_attempted = false
	state._afterimages = [{"alpha": 1.0}]
	_expect(helper.afterimages.size() == 1, "legacy Escape afterimage property should forward writes to the focused owner")

	var context := {
		"current_stage": 7,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_shrink_scale": 0.45,
		"ball_pos": Vector2(700.0, 400.0),
		"play_left": 0.0,
		"play_right": 760.0,
	}
	_expect(state.debug_start_escape(context, {}, 1.0), "debug Escape start should mutate the focused owner")
	_expect(state.debug_get_escape_snapshot() == helper.get_snapshot(), "debug Escape snapshot should forward without rebuilding mutable state")
	var draw_context: Dictionary = state.get_actor_draw_context()
	_expect(
		(draw_context.get("stage7_akamu_afterimages", []) as Array) == helper.afterimages,
		"actor draw context should borrow the focused owner's afterimage array"
	)
	_expect(
		(draw_context.get("stage7_akamu_hologram", {}) as Dictionary) == helper.hologram_draw_context,
		"actor draw context should borrow the focused owner's hologram payload"
	)

	state.clear_round_transients()
	var snapshot: Dictionary = helper.get_snapshot()
	_expect(not bool(snapshot.get("active", true)), "round cleanup should cancel focused-owner Escape motion")
	_expect(not bool(snapshot.get("episode_active", true)), "round cleanup should close the focused-owner Escape episode")
	_expect(int(snapshot.get("afterimage_count", -1)) == 0, "round cleanup should clear focused-owner Escape afterimages")
	_expect(not bool(snapshot.get("hologram_active", true)), "round cleanup should clear the focused-owner Escape hologram")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
