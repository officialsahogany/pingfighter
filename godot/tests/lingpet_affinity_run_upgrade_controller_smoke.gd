extends SceneTree

const LingpetAffinityRunUpgradeController := preload("res://scripts/lingpet/lingpet_affinity_run_upgrade_controller.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_enhancement_chip_result_contract()
	_verify_ring_core_upgrade_result_contract()
	_verify_runtime_delegates_run_upgrade_controller()

	if _failures.is_empty():
		print("lingpet_affinity_run_upgrade_controller_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_enhancement_chip_result_contract() -> void:
	var controller := LingpetAffinityRunUpgradeController.new()
	var state := LingpetAffinityState.new()
	var first: Dictionary = controller.add_enhancement_chip(state, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS)
	_expect(bool(first.get("accepted", false)), "first chip should be accepted")
	_expect_eq(int(first.get("chip_count", -1)), 1, "first chip result should report chip count 1")
	_expect_eq(int(first.get("max_chips", -1)), LingpetAffinityState.MAX_ENHANCEMENT_CHIPS, "chip result should expose the max chip cap")
	_expect_float(float(first.get("multiplier", 0.0)), 1.2, "first chip result should expose the live multiplier")
	_expect_eq(str(first.get("blocked_reason", "bad")), "", "accepted chip should have no blocked reason")

	for _i in range(LingpetAffinityState.MAX_ENHANCEMENT_CHIPS - 1):
		controller.add_enhancement_chip(state, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS)
	var capped: Dictionary = controller.add_enhancement_chip(state, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS)
	_expect(not bool(capped.get("accepted", true)), "chip above cap should be rejected")
	_expect_eq(int(capped.get("chip_count", -1)), LingpetAffinityState.MAX_ENHANCEMENT_CHIPS, "capped chip result should keep max count")
	_expect_float(float(capped.get("multiplier", 0.0)), 2.0, "capped chip result should keep the max multiplier")
	_expect_eq(str(capped.get("blocked_reason", "")), "max_chips", "chip above cap should report max_chips")


func _verify_ring_core_upgrade_result_contract() -> void:
	var controller := LingpetAffinityRunUpgradeController.new()
	var state := LingpetAffinityState.new()
	var first: Dictionary = controller.upgrade_run_ring_core_tier(state, 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	_expect(bool(first.get("accepted", false)), "tier 0 auto-upgrade should be accepted")
	_expect_eq(int(first.get("new_tier", -1)), 1, "first ring-core upgrade should reach tier 1")
	_expect_eq(int(first.get("new_cap", -1)), 5, "tier 1 ring-core cap should be exposed")
	_expect_eq(int(first.get("max_tier", -1)), LingpetRingCoreRules.MAX_RING_CORE_TIER, "ring-core result should expose max tier")
	_expect_eq(str(first.get("blocked_reason", "bad")), "", "accepted ring-core upgrade should have no blocked reason")

	var stale: Dictionary = controller.upgrade_run_ring_core_tier(state, 1, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	_expect(not bool(stale.get("accepted", true)), "same-tier ring-core upgrade should be rejected")
	_expect_eq(int(stale.get("new_tier", -1)), 1, "rejected ring-core upgrade should preserve tier")
	_expect_eq(str(stale.get("blocked_reason", "")), "ring_core_upgrade_failed", "rejected ring-core upgrade should report refund-safe failure")


func _verify_runtime_delegates_run_upgrade_controller() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_run_upgrade_controller.gd")
	_expect(runtime_source.find("LingpetAffinityRunUpgradeController") >= 0, "egg runtime should preload the run-upgrade controller")
	_expect(runtime_source.find("_affinity_run_upgrade_controller.add_enhancement_chip") >= 0, "runtime chip API should delegate")
	_expect(runtime_source.find("_affinity_run_upgrade_controller.upgrade_run_ring_core_tier") >= 0, "runtime ring-core API should delegate")
	_expect(controller_source.find("\"max_chips\"") >= 0 and controller_source.find("\"ring_core_upgrade_failed\"") >= 0, "controller should own upgrade result payload keys")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
