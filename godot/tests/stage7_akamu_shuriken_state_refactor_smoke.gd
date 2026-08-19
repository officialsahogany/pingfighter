extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const SHURIKEN_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_shuriken_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_public_facade_routes_to_owner()

	if _failures.is_empty():
		print("stage7_akamu_shuriken_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(SHURIKEN_STATE_PATH), "Stage 7 shuriken lifecycle should have a focused state owner")
	if not FileAccess.file_exists(SHURIKEN_STATE_PATH):
		return
	var owner_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(SHURIKEN_STATE_PATH)
	_expect(
		owner_source.find("const Stage7AkamuShurikenState := preload(\"%s\")" % SHURIKEN_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused shuriken owner"
	)
	_expect(
		owner_source.find("var _shuriken_state: Object = Stage7AkamuShurikenState.new()") >= 0,
		"Stage7AkamuState should retain one shuriken owner instance"
	)
	for marker in [
		"func update_projectiles(",
		"func update_gauge_drain(",
		"func spawn_from_context(",
		"func build_hud_skill(",
		"func clear_round_transients(",
	]:
		_expect(helper_source.find(marker) >= 0, "focused shuriken owner should implement %s" % marker)
	_expect(
		owner_source.find("func _register_shuriken_hit(") < 0,
		"Stage7AkamuState should not retain inline shuriken hit/status logic"
	)
	_expect(
		owner_source.find("func _get_shuriken_player_hit_point(") < 0,
		"Stage7AkamuState should not retain inline shuriken collision geometry"
	)


func _verify_public_facade_routes_to_owner() -> void:
	if not FileAccess.file_exists(SHURIKEN_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var helper: Object = state.get("_shuriken_state")
	_expect(helper != null, "Stage7AkamuState should expose its focused shuriken owner for diagnostics")
	if helper == null:
		return
	state._shuriken_casting = true
	_expect(bool(helper.casting), "legacy shuriken casting property should forward writes to the focused owner")
	state._shuriken_casting = false
	state.debug_set_shuriken_cooldown_remaining(1.5, 8.0)
	var facade_snapshot: Dictionary = state.debug_get_shuriken_snapshot()
	var helper_snapshot: Dictionary = helper.get_snapshot()
	_expect(facade_snapshot == helper_snapshot, "debug shuriken snapshot should forward without rebuilding mutable state")

	state.debug_spawn_shuriken(Vector2(100.0, 100.0), Vector2(200.0, 300.0))
	_expect(int(helper.get_snapshot().get("projectile_count", 0)) == 1, "debug spawn should mutate the focused shuriken owner")
	_expect(
		(state.get_actor_draw_context().get("stage7_akamu_shurikens", []) as Array) == helper.projectiles,
		"actor draw context should borrow the focused owner's projectile array"
	)

	state.clear_round_transients()
	helper_snapshot = helper.get_snapshot()
	_expect(int(helper_snapshot.get("projectile_count", -1)) == 0, "round cleanup should clear focused-owner projectiles")
	_expect(is_equal_approx(float(helper_snapshot.get("cooldown_remaining_sec", 0.0)), 1.5), "round cleanup should preserve the shuriken cooldown")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
