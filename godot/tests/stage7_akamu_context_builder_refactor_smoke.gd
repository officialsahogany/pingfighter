extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const CONTEXT_BUILDER_PATH := "res://scripts/stages/stage7/stage7_akamu_context_builder.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_ai_context_facade()
	_verify_actor_context_and_borrowed_payloads()

	if _failures.is_empty():
		print("stage7_akamu_context_builder_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(CONTEXT_BUILDER_PATH), "Stage 7 AI/actor context should have a focused draw-free builder")
	if not FileAccess.file_exists(CONTEXT_BUILDER_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(CONTEXT_BUILDER_PATH)
	_expect(
		host_source.find("const Stage7AkamuContextBuilder := preload(\"%s\")" % CONTEXT_BUILDER_PATH) >= 0,
		"Stage7AkamuState should preload the focused context builder"
	)
	_expect(
		host_source.find("var _context_builder: Object = Stage7AkamuContextBuilder.new()") >= 0,
		"Stage7AkamuState should retain one context builder instance"
	)
	_expect(helper_source.find("func build_boss_ai_context(") >= 0, "focused context builder should implement boss-AI projection")
	_expect(helper_source.find("func build_actor_draw_context(") >= 0, "focused context builder should implement actor projection")
	_expect(
		host_source.find("return _context_builder.build_boss_ai_context(") >= 0,
		"public boss-AI facade should delegate directly to the focused builder"
	)
	_expect(
		host_source.find("return _context_builder.build_actor_draw_context(") >= 0,
		"public actor facade should delegate directly to the focused builder"
	)
	for moved_key in [
		"\"stage7_akamu_state_owner\"",
		"\"stage7_akamu_wind_burst_particles\"",
		"\"stage7_akamu_clone_cast_progress\"",
	]:
		_expect(host_source.find(moved_key) < 0, "Stage7AkamuState should not retain moved context key %s" % moved_key)


func _verify_ai_context_facade() -> void:
	if not FileAccess.file_exists(CONTEXT_BUILDER_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(321.0)
	state.debug_set_awakened(true)
	state.debug_set_scripted_boss_position(true, Vector2(123.0, 45.0))
	var context: Dictionary = state.get_boss_ai_context()
	_expect_close(float(context.get("stage7_akamu_boss_gauge", 0.0)), 321.0, "AI context should publish focused gauge state")
	_expect(bool(context.get("stage7_akamu_awakened", false)), "AI context should publish focused Awakening state")
	_expect(bool(context.get("stage7_akamu_boss_ai_frozen", false)), "scripted motion should freeze ordinary boss AI")
	_expect(bool(context.get("stage7_akamu_scripted_motion_active", false)), "AI context should publish scripted ownership")
	_expect(context.get("stage7_akamu_scripted_boss_pos", Vector2.ZERO) == Vector2(123.0, 45.0), "AI context should publish the authored boss position")
	_expect(context.get("stage7_akamu_state_owner", null) == state, "AI context should preserve its state-owner callback surface")


func _verify_actor_context_and_borrowed_payloads() -> void:
	if not FileAccess.file_exists(CONTEXT_BUILDER_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(500.0)
	state.debug_set_boss_ball_intangible(true)
	state.debug_spawn_shuriken(Vector2(100.0, 100.0), Vector2(200.0, 300.0))
	state.debug_spawn_shadow_clones(Vector2(380.0, 200.0), true)
	var context: Dictionary = state.get_actor_draw_context()
	_expect_close(float(context.get("stage7_akamu_boss_gauge", 0.0)), 500.0, "actor context should publish focused gauge state")
	_expect(bool(context.get("stage7_akamu_boss_ball_intangible", false)), "actor context should publish composite intangibility")
	var clone_owner: Object = state.get("_clone_state")
	var shuriken_owner: Object = state.get("_shuriken_state")
	var awakening_owner: Object = state.get("_awakening_state")
	_expect(
		is_same(context.get("stage7_akamu_clones", null), clone_owner.entities),
		"actor context must borrow the clone array instead of deep-copying it"
	)
	_expect(
		is_same(context.get("stage7_akamu_shurikens", null), shuriken_owner.projectiles),
		"actor context must borrow the shuriken array instead of deep-copying it"
	)
	_expect(
		is_same(context.get("stage7_akamu_wind_burst_particles", null), awakening_owner.burst_particles),
		"actor context must borrow the wind-burst array instead of deep-copying it"
	)
	_expect(int(context.get("stage7_akamu_clone_live_count", 0)) > 0, "actor context should publish the live clone count")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
