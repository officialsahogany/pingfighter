extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const GAUGE_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_gauge_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_owner_math()
	_verify_public_facade_routes_to_owner()

	if _failures.is_empty():
		print("stage7_akamu_gauge_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(GAUGE_STATE_PATH), "Stage 7 shared boss gauge should have a focused state owner")
	if not FileAccess.file_exists(GAUGE_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(GAUGE_STATE_PATH)
	_expect(
		host_source.find("const Stage7AkamuGaugeState := preload(\"%s\")" % GAUGE_STATE_PATH) >= 0,
		"Stage7AkamuState should preload the focused gauge owner"
	)
	_expect(
		host_source.find("var _gauge_state: Object = Stage7AkamuGaugeState.new()") >= 0,
		"Stage7AkamuState should retain one gauge owner instance"
	)
	for marker in [
		"func apply_score_round_carry(",
		"func add_boss_hit(",
		"func add(",
		"func drain(",
		"func try_commit_common_dash(",
		"func commit_result(",
		"func reset_full(",
		"func has_runtime_state(",
	]:
		_expect(helper_source.find(marker) >= 0, "focused gauge owner should implement %s" % marker)
	_expect(
		host_source.find("boss_special_gauge =") < 0,
		"Stage7AkamuState should not mutate the shared gauge outside its owner"
	)
	for routed_call in [
		"_gauge_state.apply_score_round_carry(",
		"_gauge_state.add_boss_hit(",
		"_gauge_state.add(",
		"_gauge_state.drain(",
		"_gauge_state.try_commit_common_dash(",
		"_gauge_state.commit_result(",
	]:
		_expect(host_source.find(routed_call) >= 0, "Stage7AkamuState should route through %s" % routed_call)


func _verify_owner_math() -> void:
	if not FileAccess.file_exists(GAUGE_STATE_PATH):
		return
	var owner_script: Script = load(GAUGE_STATE_PATH)
	var owner: Object = owner_script.new()
	owner.set_raw(499.0)
	owner.add(90.0)
	_expect_close(float(owner.value), 500.0, "gauge rewards should cap at 500")
	owner.set_raw(400.0)
	_expect(owner.apply_score_round_carry(1), "first score generation should commit carry")
	_expect_close(float(owner.value), 280.0, "score carry should truncate gauge times 0.7")
	_expect(not owner.apply_score_round_carry(1), "duplicate score generation should be rejected")
	_expect_close(float(owner.value), 280.0, "rejected generation should not apply carry twice")
	_expect(owner.apply_score_round_carry(2), "newer score generation should commit carry")
	_expect_close(float(owner.value), 196.0, "second accepted score generation should carry once")

	owner.set_raw(0.0)
	owner.add_boss_hit(false, false)
	_expect_close(float(owner.value), 80.0, "normal boss hit should add 80 gauge")
	owner.set_raw(0.0)
	owner.add_boss_hit(true, false)
	_expect_close(float(owner.value), 90.0, "Awakened boss hit should add 90 gauge")
	owner.set_raw(0.0)
	owner.add_boss_hit(true, true)
	_expect_close(float(owner.value), 20.0, "Superspeed boss hit should add only 20 gauge")

	owner.set_raw(49.0)
	_expect(not owner.try_commit_common_dash(false), "ordinary dash should reject 49 gauge")
	_expect_close(float(owner.value), 49.0, "rejected ordinary dash should not spend gauge")
	owner.set_raw(50.0)
	_expect(owner.try_commit_common_dash(false), "ordinary dash should accept exactly 50 gauge")
	_expect_close(float(owner.value), 0.0, "accepted ordinary dash should spend exactly 50 gauge")
	_expect(owner.try_commit_common_dash(true), "Superspeed dash should bypass the ordinary gauge cost")
	owner.set_raw(999.0)
	owner.drain(20.0)
	_expect_close(float(owner.value), 979.0, "raw compatibility values should drain without an implicit cap")
	owner.commit_result({"boss_gauge": 123.0})
	_expect_close(float(owner.value), 123.0, "skill transaction result should commit through the owner")


func _verify_public_facade_routes_to_owner() -> void:
	if not FileAccess.file_exists(GAUGE_STATE_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var helper: Object = state.get("_gauge_state")
	_expect(helper != null, "Stage7AkamuState should expose its focused gauge owner for diagnostics")
	if helper == null:
		return
	state.boss_special_gauge = 999.0
	_expect_close(float(helper.value), 999.0, "legacy public gauge property should preserve raw writes")
	_expect_close(float(state.get("boss_special_gauge")), 999.0, "Object.get should preserve the public gauge compatibility surface")
	state.set("boss_special_gauge", 100.0)
	state.drain_boss_special_gauge(10.0)
	_expect_close(float(helper.value), 90.0, "public drain facade should mutate the focused gauge owner")
	state.debug_set_gauge(600.0)
	_expect_close(float(helper.value), 500.0, "debug gauge setter should retain its clamped contract")
	_expect(state.apply_score_round_carry(7), "host carry facade should mutate the focused owner")
	_expect_close(state.debug_get_gauge(), 350.0, "host carry facade should apply the owner's 0.7 truncation")
	state.clear_round_transients()
	_expect_close(float(helper.value), 350.0, "ordinary round cleanup should preserve the focused gauge")
	state.reset_for_result()
	_expect_close(float(helper.value), 0.0, "full result reset should clear the focused gauge")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
