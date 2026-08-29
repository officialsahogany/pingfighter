extends SceneTree

const LanguageSettingsData := preload(
	"res://scripts/core/language_settings_data.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerRewardPickOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_reward_pick_offer_builder.gd"
)

var _failures: Array[String] = []


class FakeTreasureMapRuntime:
	extends RefCounted

	var multiplier := 1.0

	func get_downtown_treasure_map_mythic_multiplier() -> float:
		return multiplier


func _init() -> void:
	_verify_catalog_and_seven_locales()
	_verify_reward_pick_probability_owner()
	_verify_tower_mode_legacy_consumer_guards()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("treasure_map_perk_port_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_seven_locales() -> void:
	var treasure_map: Dictionary = RuntimePerkCatalog.new().get_perk_data(
		"downtown_treasure_map"
	)
	_expect(str(treasure_map.get("name", "")) == "천기보도", "catalog must preserve the Korean Heavenly-Secret Treasure Map name")
	_expect(int(treasure_map.get("max_level", 0)) == 3, "Treasure Map must use the current three-rank progression")
	var descriptions_value: Variant = treasure_map.get("descriptions", {})
	var descriptions: Dictionary = descriptions_value if descriptions_value is Dictionary else {}
	var expected_chances := [188, 435, 750]
	var expected_cost_copy := ["비용 -1", "비용 -3", "비용 없음"]
	for level in range(1, 4):
		var description := str(descriptions.get(level, ""))
		_expect(description.contains("승리 보상 픽"), "Korean Lv.%d copy must name the victory reward pick" % level)
		_expect(description.contains("절세무공"), "Korean Lv.%d copy must name the Peerless card lane" % level)
		_expect(description.contains("+%d%%" % int(expected_chances[level - 1])), "Korean Lv.%d copy must expose the authored three-rank curve" % level)
		_expect(description.contains(str(expected_cost_copy[level - 1])), "Korean Lv.%d copy must expose the fusion-cost tier" % level)
		_expect(not description.contains("비전초식") and not description.contains("상자"), "Korean Lv.%d copy must not advertise the retired Vision-box lane" % level)
	var detail := str(treasure_map.get("detail", ""))
	_expect(detail.contains("승리 보상 픽") and detail.contains("750%"), "Korean detail must explain the current reward-pick effect")
	_expect(detail.contains("1성") and detail.contains("2성") and detail.contains("0으로 고정"), "Korean detail must explain every fusion-cost tier")
	_expect(not detail.contains("비전초식") and not detail.contains("보물탐색"), "Korean detail must omit retired secondary lanes")

	var localized_summaries: Array[String] = [
		str(LanguageSettingsData.PERK_SUMMARY_EN.get("treasure_map", "")),
		str(LanguageSettingsData.PERK_SUMMARY_ZH.get("treasure_map", "")),
		str(LanguageSettingsData.PERK_SUMMARY_JA.get("treasure_map", "")),
		str(LanguageSettingsData.PERK_SUMMARY_ES.get("treasure_map", "")),
		str(LanguageSettingsData.PERK_SUMMARY_PT_BR.get("treasure_map", "")),
		str(LanguageSettingsData.PERK_SUMMARY_RU.get("treasure_map", "")),
	]
	_expect(localized_summaries.size() + 1 == 7, "Treasure Map copy must cover Korean plus six localized summaries")
	for summary in localized_summaries:
		_expect(not summary.is_empty() and summary.contains("150%"), "every non-Korean Treasure Map summary must retain the 150% per-level value")


func _verify_reward_pick_probability_owner() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var builder := TowerRewardPickOfferBuilder.new()
	var runtime := FakeTreasureMapRuntime.new()
	var context := {"floor": 1}
	_expect_close(float(builder.call("_supreme_chance", context, runtime)), 0.05, "base reward-pick Peerless chance must remain five percent")
	runtime.multiplier = 2.875
	_expect_close(float(builder.call("_supreme_chance", context, runtime)), 0.14375, "Treasure Map Lv.1 multiplier must raise only the reward-pick Peerless lane")
	runtime.multiplier = 8.5
	_expect_close(float(builder.call("_supreme_chance", context, runtime)), 0.425, "Treasure Map Lv.3 multiplier must preserve the authored ceiling")


func _verify_tower_mode_legacy_consumer_guards() -> void:
	var runtime := RuntimePerkState.new()
	runtime.runtime_skill_levels["downtown_treasure_map"] = 3
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	_expect_close(runtime.get_downtown_treasure_map_mythic_multiplier(), 8.5, "flag-off legacy consumers must retain the Treasure Map multiplier")
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_expect_close(runtime.get_downtown_treasure_map_mythic_multiplier(), 1.0, "tower mode must suppress every generic legacy Treasure Map consumer")
	_expect_close(runtime.get_downtown_treasure_map_reward_pick_multiplier(), 8.5, "tower reward picks must retain the dedicated Treasure Map multiplier")
	runtime.runtime_skill_levels.erase("downtown_treasure_map")
	_expect(runtime.get_downtown_treasure_map_fusion_muhon_cost(3) == 3, "unowned Treasure Map must not change fusion cost")
	runtime.runtime_skill_levels["downtown_treasure_map"] = 1
	_expect(runtime.get_downtown_treasure_map_fusion_muhon_cost(3) == 2, "Treasure Map Lv.1 must reduce fusion cost by one")
	runtime.runtime_skill_levels["downtown_treasure_map"] = 2
	_expect(runtime.get_downtown_treasure_map_fusion_muhon_cost(3) == 0, "Treasure Map Lv.2 must reduce fusion cost by three")
	_expect(runtime.get_downtown_treasure_map_fusion_muhon_cost(1) == 0, "Treasure Map cost reduction must floor at zero")
	runtime.runtime_skill_levels["downtown_treasure_map"] = 3
	_expect(runtime.get_downtown_treasure_map_fusion_muhon_cost(99) == 0, "Treasure Map max rank must remain fixed free after a base-cost increase")
	var field_source := FileAccess.get_file_as_string(
		"res://scripts/items/active_item_field_spawn_pool.gd"
	)
	var pick_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_reward_pick_offer_builder.gd"
	)
	_expect(field_source.contains("TowerAscentFeatureFlags.is_vertical_slice_enabled():\n\t\treturn 1.0"), "tower field spawns must suppress the legacy Treasure Map multiplier")
	_expect(pick_source.contains("get_downtown_treasure_map_reward_pick_multiplier"), "the reward-pick builder must use the dedicated tower-mode Treasure Map probability owner")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= 0.0001, "%s: expected %.6f, got %.6f" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
