extends SceneTree

const BossSlowTiers := preload("res://scripts/status/boss_slow_tiers.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const GameplayStatusModuleCatalog := preload("res://scripts/resources/gameplay_status_module_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_standard_values()
	_verify_tier_lookup()
	_verify_slow_percentages()
	_verify_catalog_registration()

	if _failures.is_empty():
		print("boss_slow_tiers_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_standard_values() -> void:
	_expect_float(BossSlowTiers.WEAK, 0.70, "weak boss slow should be a 0.70 multiplier")
	_expect_float(BossSlowTiers.MEDIUM, 0.55, "medium boss slow should be a 0.55 multiplier")
	_expect_float(BossSlowTiers.STRONG, 0.40, "strong boss slow should be a 0.40 multiplier")
	_expect(
		BossSlowTiers.STRONG < BossSlowTiers.MEDIUM and BossSlowTiers.MEDIUM < BossSlowTiers.WEAK,
		"stronger boss slow tiers should have lower movement multipliers"
	)
	for multiplier in [BossSlowTiers.WEAK, BossSlowTiers.MEDIUM, BossSlowTiers.STRONG]:
		_expect(float(multiplier) >= 0.05 and float(multiplier) <= 1.0, "boss slow tiers should stay inside the safe multiplier range")


func _verify_tier_lookup() -> void:
	_expect_float(BossSlowTiers.multiplier_for_tier(BossSlowTiers.TIER_WEAK), BossSlowTiers.WEAK, "tier 1 should resolve to weak slow")
	_expect_float(BossSlowTiers.multiplier_for_tier(BossSlowTiers.TIER_MEDIUM), BossSlowTiers.MEDIUM, "tier 2 should resolve to medium slow")
	_expect_float(BossSlowTiers.multiplier_for_tier(BossSlowTiers.TIER_STRONG), BossSlowTiers.STRONG, "tier 3 should resolve to strong slow")
	_expect_float(BossSlowTiers.multiplier_for_tier(0), BossSlowTiers.WEAK, "out-of-range low tiers should clamp to weak")
	_expect_float(BossSlowTiers.multiplier_for_tier(4), BossSlowTiers.STRONG, "out-of-range high tiers should clamp to strong")


func _verify_slow_percentages() -> void:
	_expect_float(BossSlowTiers.slow_pct_for_tier(BossSlowTiers.TIER_WEAK), 0.30, "weak boss slow should report 30 percent slow")
	_expect_float(BossSlowTiers.slow_pct_for_tier(BossSlowTiers.TIER_MEDIUM), 0.45, "medium boss slow should report 45 percent slow")
	_expect_float(BossSlowTiers.slow_pct_for_tier(BossSlowTiers.TIER_STRONG), 0.60, "strong boss slow should report 60 percent slow")


func _verify_catalog_registration() -> void:
	var status_modules: Dictionary = GameplayStatusModuleCatalog.MODULES
	_expect(status_modules.has("boss_slow_tiers"), "status module catalog should list boss slow tiers")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("boss_slow_tiers")
	_expect(str(spec.get("path", "")) == "res://scripts/status/boss_slow_tiers.gd", "top-level module catalog should resolve boss slow tiers")
	_expect(str(spec.get("label", "")) == "boss slow tier constants", "boss slow tier catalog label should stay stable")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.3f, got %.3f" % [message, expected, actual])
