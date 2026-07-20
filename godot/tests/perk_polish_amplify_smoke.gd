extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	_verify_catalog_wording()
	_verify_amplifiable_set_contract()
	_verify_flag_on_common_dash_amplify()
	_verify_exclusions()
	_verify_effective_level_and_polish_stack()
	_verify_zero_level_noop()
	_verify_p2_converted_values_not_amplified_yet()
	_verify_flag_off_legacy_roll_and_bonus_paths()
	PerkConversionFlags.debug_set_enabled(false)
	if not _failures.is_empty():
		quit(1)
		return
	print("perk_polish_amplify_smoke: ok")
	quit(0)


func _verify_catalog_wording() -> void:
	var catalog := RuntimePerkCatalog.new()
	var data: Dictionary = catalog.get_perk_data("item_polish")
	_expect(not data.is_empty(), "item_polish should stay registered")
	var descriptions: Dictionary = data.get("descriptions", {})
	_expect(str(descriptions.get(1, "")).find("5%") >= 0, "Lv.1 Polish text should describe 5% amplify")
	_expect(str(descriptions.get(5, "")).find("25%") >= 0, "Lv.5 Polish text should describe 25% amplify")
	_expect(str(data.get("detail", "")).find("수치형 능력치") >= 0, "Polish detail should describe stat-value amplification")


func _verify_amplifiable_set_contract() -> void:
	var amplifiable_ids: Dictionary = RuntimePerkState.PERK_POLISH_AMPLIFIABLE_BONUS_IDS
	var expected_ids := [
		"dash_lightweight",
		"dash_module_control",
		"dash_jump",
		"dash_acceleration",
		"dash_spirit",
		"item_luck",
		"item_cooldown_mastery",
		"item_gauge_mastery",
		"item_caffeine",
		"common_swiftness",
		"common_bulk_up",
		"common_training",
		"perk_boost_charge",
	]
	_expect(amplifiable_ids.size() == expected_ids.size(), "P1 amplifiable set should contain exactly 13 ids")
	for id_value in expected_ids:
		_expect(bool(amplifiable_ids.get(str(id_value), false)), "P1 amplifiable set should include %s" % str(id_value))
	var excluded_ids := [
		"item_bag_expansion",
		"common_expansion",
		"dash_amplification",
		"perk_laurel_shield",
		"item_polish",
		"item_recycle",
	]
	for id_value in excluded_ids:
		_expect(not bool(amplifiable_ids.get(str(id_value), false)), "P1 amplifiable set should exclude %s" % str(id_value))


func _verify_flag_on_common_dash_amplify() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 3
	state.runtime_skill_levels["common_swiftness"] = 2
	state.runtime_skill_levels["dash_lightweight"] = 1
	_expect_close(state._get_perk_amplify_multiplier("common_swiftness"), 1.15, "Lv.3 Polish should expose a 1.15 common multiplier")
	_expect_close(state.get_runtime_skill_bonus("common_swiftness"), 0.12 * 1.15, "Lv.3 Polish should amplify common_swiftness")
	_expect_close(state.get_runtime_skill_bonus("dash_lightweight"), 0.12 * 1.15, "Lv.3 Polish should amplify dash_lightweight")


func _verify_exclusions() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 5
	state.runtime_skill_levels["item_bag_expansion"] = 2
	state.runtime_skill_levels["common_expansion"] = 2
	state.runtime_skill_levels["dash_amplification"] = 3
	state.runtime_skill_levels["perk_laurel_shield"] = 4
	state.runtime_skill_levels["item_recycle"] = 2
	_expect_close(state.get_runtime_skill_bonus("item_polish"), 0.60, "Polish must not amplify itself")
	_expect_close(state.get_runtime_skill_bonus("item_bag_expansion"), 2.0, "active-slot count should not be amplified")
	_expect_close(state.get_runtime_skill_bonus("common_expansion"), 0.0, "flag-ON Expansion should not expose the legacy accessory-slot bonus")
	_expect_close(state.get_runtime_skill_bonus("dash_amplification"), 3.0, "dash-token count should not be amplified")
	_expect_close(state.get_runtime_skill_bonus("perk_laurel_shield"), 4.0, "laurel leaf count should not be amplified")
	_expect_close(state.get_runtime_skill_bonus("item_recycle"), 0.14, "economy/preservation chance should not be amplified in P1")


func _verify_effective_level_and_polish_stack() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 5
	state.runtime_skill_levels["common_swiftness"] = 2
	_expect(state.set_item_perk_level_bonus(2), "test setup should set effective-level bonus")
	_expect(int(state.get_runtime_skill_level("common_swiftness")) == 4, "effective-level bonus should still raise the target perk level")
	_expect_close(state._get_perk_amplify_multiplier("common_swiftness"), 1.35, "Polish amplifier should keep scaling at effective Lv.7")
	_expect_close(state.get_runtime_skill_bonus("common_swiftness"), 0.24 * 1.35, "effective-level Polish should multiply the effective-level target output")


func _verify_zero_level_noop() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 0
	state.runtime_skill_levels["common_swiftness"] = 2
	_expect_close(state._get_perk_amplify_multiplier("common_swiftness"), 1.0, "Lv.0 Polish should not amplify")
	_expect_close(state.get_runtime_skill_bonus("common_swiftness"), 0.12, "Lv.0 Polish should leave common_swiftness unchanged")


func _verify_p2_converted_values_not_amplified_yet() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 5
	_expect(not state.has_method("get_amplified_converted_value"), "P1 must not add the P2 converted-value helper")
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", 3), 15.0, "P1 must not amplify converted benefit tables")
	_expect_close(PerkConversionValues.get_value("soul_burst", "soul_burst_gauge_cost", 3), 135.0, "P1 must not touch converted cost tables")


func _verify_flag_off_legacy_roll_and_bonus_paths() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 5
	state.runtime_skill_levels["common_swiftness"] = 2
	_expect_close(state._get_perk_amplify_multiplier("common_swiftness"), 1.0, "flag-OFF should disable the new amplifier")
	_expect_close(state.get_runtime_skill_bonus("common_swiftness"), 0.12, "flag-OFF common_swiftness should stay legacy")
	_expect(state.set_item_perk_level_bonus(1), "test setup should set legacy effective Polish bonus")
	_expect(int(state.get_runtime_skill_level("item_polish")) == 6, "legacy Polish effective level should still overcap")
	_expect_close(state.get_effective_polish_multiplier(), 1.72, "flag-OFF legacy item-roll Polish multiplier should stay unchanged")
	_expect_close(state.get_base_polish_multiplier(), 1.60, "flag-OFF base item-roll Polish multiplier should ignore effective bonuses")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	PerkConversionFlags.debug_set_enabled(false)
	_failures.append(message)
	push_error(message)
