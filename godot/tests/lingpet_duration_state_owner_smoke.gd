extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetDurationState := preload("res://scripts/lingpet/lingpet_duration_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_shared_pool_drain_and_recovery()
	_verify_epsilon_snap_and_resummon_gate()
	_verify_affinity_delegation_surface()

	if _failures.is_empty():
		print("lingpet_duration_state_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_shared_pool_drain_and_recovery() -> void:
	var state := LingpetDurationState.new()
	var rolled: Dictionary = state.ensure_initial_roll(null, 40)
	_expect(bool(rolled.get("accepted", false)), "first hatch should initialize the shared pool")
	state.advance_pool(5.0, true)
	_expect_float(state.get_pool_current(), 35.0, "summoned guardian should drain one second per second")
	state.advance_pool(3.0, false)
	_expect_float(state.get_pool_current(), 36.0, "stowed guardian should recover at one third speed")
	_expect_eq(state.get_pool_pct(), 90, "duration percent should be derived from the shared pool")


func _verify_epsilon_snap_and_resummon_gate() -> void:
	var state := LingpetDurationState.new()
	state.set_pool_for_tests(0.0005, 40.0)
	_expect_float(state.get_pool_current(), 0.0, "near-zero duration should snap exactly to zero")
	_expect(state.is_resummon_locked(), "zero duration should lock resummon")
	state.advance_pool(31.0, false)
	_expect(state.get_pool_current() > LingpetDurationState.RESUMMON_THRESHOLD, "stowed recovery should cross the ten-second threshold")
	_expect(not state.is_resummon_locked(), "crossing the threshold should unlock resummon")
	state.set_pool_for_tests(39.9995, 40.0)
	_expect_float(state.get_pool_current(), 40.0, "near-full duration should snap exactly to maximum")


func _verify_affinity_delegation_surface() -> void:
	var affinity := LingpetAffinityState.new()
	affinity.ensure_duration_pool_roll(null, 45)
	var result: Dictionary = affinity.advance_duration_pool(2.0, true, 0.5)
	_expect(bool(result.get("changed", false)), "affinity compatibility owner should forward shared-pool changes")
	_expect_float(affinity.get_duration_pool_current(), 44.0, "duration runtime multiplier should reach the shared pool")
	var affinity_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_state.gd")
	_expect(affinity_source.contains("_duration_state.advance_pool("), "affinity owner should delegate directly to the duration pool")
	var legacy_term := "sati" + "ety"
	_expect(not affinity_source.contains("func get_" + legacy_term), "retired fullness getter must not remain")
	_expect(not affinity_source.contains("func advance_" + legacy_term), "retired fullness tick must not remain")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
