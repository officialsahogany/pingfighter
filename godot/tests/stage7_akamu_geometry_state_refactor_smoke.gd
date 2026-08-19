extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const GEOMETRY_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_geometry_state.gd"
const HOST_PATH := "res://scripts/stages/stage7/stage7_akamu_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_snapshot_and_fallback_contract()
	_verify_host_sync_and_reset_facades()

	if _failures.is_empty():
		print("stage7_akamu_geometry_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(GEOMETRY_STATE_PATH), "Stage 7 boss geometry should have a focused snapshot owner")
	if not FileAccess.file_exists(GEOMETRY_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var geometry_source := FileAccess.get_file_as_string(GEOMETRY_STATE_PATH)
	_expect(
		host_source.find("const Stage7AkamuGeometryState := preload(\"%s\")" % GEOMETRY_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused geometry owner"
	)
	_expect(
		host_source.find("var _geometry_state: Object = Stage7AkamuGeometryState.new()") >= 0,
		"Stage7AkamuState should retain one geometry owner instance"
	)
	for marker in [
		"func reset(",
		"func sync(",
		"func set_snapshot(",
		"func resolve_position(",
		"func resolve_size(",
	]:
		_expect(geometry_source.find(marker) >= 0, "focused geometry owner should implement %s" % marker)
	for moved_marker in [
		"var _last_boss_pos :=",
		"var _last_boss_size :=",
		"var _last_boss_visual_scale :=",
		"func _cache_boss_geometry(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Stage7AkamuState should not retain geometry marker %s" % moved_marker)
	_expect(host_source.find("_geometry_state.sync(context)") >= 0, "update/freeze paths should sync the focused geometry owner")
	_expect(
		host_source.find("_geometry_state.resolve_position(context)") >= 0,
		"Wind Aura collision should resolve boss position through the focused owner"
	)
	_expect(
		host_source.find("_geometry_state.resolve_size(context)") >= 0,
		"Wind Aura collision should resolve boss size through the focused owner"
	)


func _verify_snapshot_and_fallback_contract() -> void:
	var geometry: Object = _new_geometry_owner()
	if geometry == null:
		return
	_expect(geometry.boss_pos == Vector2(330.0, 25.0), "geometry owner should start at the Stage 7 default boss position")
	_expect(geometry.boss_size == Vector2(100.0, 40.0), "geometry owner should start at the Stage 7 default boss size")
	_expect_close(float(geometry.visual_scale), 1.0, "geometry owner should start at full visual scale")

	geometry.sync({
		"boss_pos": Vector2(120.0, 35.0),
		"boss_paddle_size": Vector2(140.0, 52.0),
		"boss_paddle_shrink_scale": 1.4,
	})
	_expect(geometry.boss_pos == Vector2(120.0, 35.0), "typed boss position should replace the cached position")
	_expect(geometry.boss_size == Vector2(140.0, 52.0), "typed boss size should replace the cached size")
	_expect_close(float(geometry.visual_scale), 1.0, "visual scale should clamp to the shipped upper bound")

	geometry.sync({
		"boss_paddle_width": 160.0,
		"boss_hitbox_height": 55.0,
		"boss_paddle_shrink_scale": 0.05,
	})
	_expect(geometry.boss_pos == Vector2(120.0, 35.0), "missing position should preserve the cached position")
	_expect(geometry.boss_size == Vector2(160.0, 55.0), "legacy width/height keys should remain the size fallback")
	_expect_close(float(geometry.visual_scale), 0.2, "visual scale should clamp to the shipped lower bound")

	geometry.sync({
		"boss_pos": "invalid",
		"boss_paddle_size": "invalid",
		"boss_paddle_width": 999.0,
		"boss_hitbox_height": 999.0,
	})
	_expect(geometry.boss_pos == Vector2(120.0, 35.0), "wrongly typed position should preserve the cached position")
	_expect(
		geometry.boss_size == Vector2(160.0, 55.0),
		"an explicitly present but wrongly typed size should preserve the cache instead of consulting legacy keys"
	)
	geometry.set_snapshot(Vector2(210.0, 40.0), Vector2(88.0, 33.0))
	_expect(geometry.boss_pos == Vector2(210.0, 40.0), "debug snapshot should replace position")
	_expect(geometry.boss_size == Vector2(88.0, 33.0), "debug snapshot should replace size")
	_expect_close(float(geometry.visual_scale), 0.2, "debug snapshot should preserve the live visual scale")
	geometry.reset()
	_expect(geometry.boss_pos == Vector2(330.0, 25.0), "full reset should restore the default position")
	_expect(geometry.boss_size == Vector2(100.0, 40.0), "full reset should restore the default size")
	_expect_close(float(geometry.visual_scale), 1.0, "full reset should restore full visual scale")


func _verify_host_sync_and_reset_facades() -> void:
	if not FileAccess.file_exists(GEOMETRY_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	state.update(0.0, {
		"current_stage": 7,
		"ball_active": true,
		"waiting_for_serve": false,
		"boss_pos": Vector2(180.0, 30.0),
		"boss_paddle_size": Vector2(125.0, 44.0),
		"boss_paddle_shrink_scale": 0.65,
		"ball_pos": Vector2(380.0, 700.0),
	})
	var geometry: Object = state.get("_geometry_state")
	_expect(geometry != null, "Stage7AkamuState should expose its geometry owner for diagnostics")
	if geometry == null:
		return
	_expect(geometry.boss_pos == Vector2(180.0, 30.0), "host update should sync the focused position snapshot")
	_expect(geometry.boss_size == Vector2(125.0, 44.0), "host update should sync the focused size snapshot")
	_expect_close(float(geometry.visual_scale), 0.65, "host update should sync the focused scale snapshot")
	state.reset()
	_expect(geometry.boss_pos == Vector2(330.0, 25.0), "host full reset should reset the focused position snapshot")
	_expect(geometry.boss_size == Vector2(100.0, 40.0), "host full reset should reset the focused size snapshot")


func _new_geometry_owner() -> Object:
	if not FileAccess.file_exists(GEOMETRY_STATE_PATH):
		return null
	var geometry_script: Script = load(GEOMETRY_STATE_PATH)
	return geometry_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
