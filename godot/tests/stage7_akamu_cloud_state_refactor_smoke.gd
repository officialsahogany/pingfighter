extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")
const Stage7AkamuBossSkillHudRenderer := preload("res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd")

const CLOUD_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_cloud_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_public_facade_routes_to_owner()

	if _failures.is_empty():
		print("stage7_akamu_cloud_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(CLOUD_STATE_PATH), "Stage 7 Cloud Veil lifecycle should have a focused state owner")
	if not FileAccess.file_exists(CLOUD_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(CLOUD_STATE_PATH)
	_expect(
		host_source.find("const Stage7AkamuCloudState := preload(\"%s\")" % CLOUD_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused Cloud Veil owner"
	)
	_expect(
		host_source.find("var _cloud_state: Object = Stage7AkamuCloudState.new()") >= 0,
		"Stage7AkamuState should retain one Cloud Veil owner instance"
	)
	for marker in [
		"func try_start(",
		"func advance(",
		"func build_hud_skill(",
		"func get_boss_pos(",
		"func get_field_alpha(",
		"func clear_round_transients(",
	]:
		_expect(helper_source.find(marker) >= 0, "focused Cloud Veil owner should implement %s" % marker)
	for forbidden in [
		"func _start_cloud_field(",
		"func _update_cloud_field(",
		"func _get_cloud_field_alpha(",
		"func _get_cloud_phase_progress(",
		"func _get_cloud_boss_pos(",
	]:
		_expect(host_source.find(forbidden) < 0, "Stage7AkamuState should not retain inline Cloud Veil logic: %s" % forbidden)


func _verify_public_facade_routes_to_owner() -> void:
	if not FileAccess.file_exists(CLOUD_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var helper: Object = state.get("_cloud_state")
	_expect(helper != null, "Stage7AkamuState should expose its focused Cloud Veil owner for diagnostics")
	if helper == null:
		return
	state.debug_set_cloud_cooldown_remaining(3.5, 7.0)
	_expect(
		state.debug_get_cloud_snapshot() == helper.get_snapshot(),
		"debug Cloud Veil snapshot should forward without rebuilding mutable state"
	)

	state.debug_set_awakened(true)
	state.debug_set_gauge(200.0)
	var started: bool = state.debug_start_cloud({
		"current_stage": 7,
		"boss_pos": Vector2(120.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
	})
	_expect(started, "debug Cloud Veil start should mutate the focused owner")
	_expect(bool(helper.get_snapshot().get("dash_active", false)), "focused Cloud Veil owner should become active")
	var rolled_cooldown: float = float(helper.get_snapshot().get("cooldown_total_sec", 0.0))
	_expect(rolled_cooldown >= 10.0 and rolled_cooldown <= 20.0, "Cloud Veil should roll the Python-parity 10-20 second cooldown")
	var cloud_tooltip: Dictionary = Stage7AkamuBossSkillHudRenderer.TOOLTIP_INFO.get("stage7_cloud", {})
	_expect(str(cloud_tooltip.get("cooldown", "")) == "10~20초", "Cloud Veil runtime cooldown should remain synchronized with its tooltip")
	_expect(
		(state.get_actor_draw_context().get("stage7_akamu_aura", {}) as Dictionary) == helper.aura_draw_context,
		"actor draw context should borrow the focused owner's aura payload"
	)
	state.debug_set_cloud_cooldown_remaining(3.5, 7.0)
	state.clear_round_transients()
	var snapshot: Dictionary = helper.get_snapshot()
	_expect(not bool(snapshot.get("dash_active", true)), "round cleanup should clear focused-owner Cloud Veil motion")
	_expect(not bool(snapshot.get("field_active", true)), "round cleanup should clear focused-owner Cloud Veil field")
	_expect(
		is_equal_approx(float(snapshot.get("cooldown_remaining_sec", 0.0)), 3.5),
		"round cleanup should preserve the Cloud Veil cooldown"
	)
	_expect(helper.draw_context.is_empty(), "round cleanup should clear the focused-owner Cloud Veil draw payload")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
