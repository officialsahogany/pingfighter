extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const PandoraLegacyPoolBuilder := preload("res://scripts/items/pandora_legacy_pool_builder.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const PlazaShopStock := preload("res://scripts/plaza/plaza_shop_stock.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_choice_active := false
	var selected_character_type := "smasher"
	var accessory_slot_count := 4
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(330.0, 25.0)
	var special_gauge := 500.0
	var values: Dictionary = {}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		values["redraw_queued"] = true

	func request_battle_redraw() -> void:
		values["redraw_requested"] = true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(source_instances: Dictionary = {}) -> void:
		instances = source_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class OpenSlotCatalog:
	extends RefCounted

	var catalog := RuntimePerkCatalog.new()

	func get_perk_data(perk_id: String) -> Dictionary:
		return catalog.get_perk_data(perk_id)

	func has_open_perk_slot(_runtime_levels: Dictionary, _slot_context: Object = null) -> bool:
		return true


func _init() -> void:
	seed(17071)
	PerkConversionFlags.debug_set_enabled(false)

	_verify_catalog_and_value_contract()
	_verify_sage_contract_raw_level_and_exemptions()
	_verify_sacred_laurel_mythic_channel_and_runtime_value()
	_verify_dowsing_goggles_insight_gate()
	_verify_gold_bar_remains_deleted_and_runtime_neutral()
	_verify_flag_off_legacy_items_still_work()

	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("perk_conversion_redesign_group_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_value_contract() -> void:
	var catalog := RuntimePerkCatalog.new()
	var sage_data: Dictionary = catalog.get_perk_data("sage_ring")
	var dowsing_data: Dictionary = catalog.get_perk_data("dowsing_goggles")
	var laurel_data: Dictionary = catalog.get_perk_data("sacred_laurel")
	_expect(not sage_data.is_empty(), "sage_ring should resolve as Hyeonmun Charyeok")
	_expect(not dowsing_data.is_empty(), "dowsing_goggles should resolve as Insight")
	_expect(not laurel_data.is_empty(), "sacred_laurel should resolve as Great Laurel")
	_expect(str(sage_data.get("tree", "")) == "common", "Hyeonmun Charyeok should be a normal common perk")
	_expect(int(sage_data.get("max_level", 0)) == 5, "Hyeonmun Charyeok should be max Lv.5")
	_expect(bool(sage_data.get("effective_level_exempt", false)), "Hyeonmun Charyeok catalog entry should be effective-level exempt")
	_expect(str(dowsing_data.get("tree", "")) == "item", "Insight should stay in the item perk family")
	_expect(int(dowsing_data.get("max_level", 0)) == 3, "Insight should be max Lv.3")
	_expect(str(laurel_data.get("rarity", "")) == "mythic", "Great Laurel should be a mythic perk")
	_expect(int(laurel_data.get("max_level", 0)) == 1, "Great Laurel should be max Lv.1")
	_expect(bool(laurel_data.get("effective_level_exempt", false)), "Great Laurel should be effective-level exempt")
	_expect(PerkConversionValues.CONVERSION_SOURCE_TO_PERK.get("sage_ring", "") == "sage_ring", "Sage Ring should map to Hyeonmun Charyeok")
	_expect(PerkConversionValues.CONVERSION_SOURCE_TO_PERK.get("dowsing_goggles", "") == "dowsing_goggles", "Dowsing Goggles should map to Insight")
	_expect(PerkConversionValues.CONVERSION_SOURCE_TO_PERK.get("sacred_laurel", "") == "sacred_laurel", "Sacred Laurel should map to Great Laurel")
	_expect(not PerkConversionValues.CONVERSION_SOURCE_TO_PERK.has("gold_bar"), "Gold Bar should have no conversion mapping")
	_expect(PerkConversionValues.get_effective_converted_perk_level("sage_ring", 5, 99) == 5, "Hyeonmun proc spec should follow invested level only")
	_expect(PerkConversionValues.get_effective_converted_perk_level("sacred_laurel", 1, 99) == 1, "Great Laurel should ignore effective-level bonuses")

	PerkConversionFlags.debug_set_enabled(true)
	var choices: Array = catalog.get_choices("smasher", {}, true, 300)
	_expect(_has_choice_id(choices, "sage_ring"), "flag-ON normal offers should include Hyeonmun Charyeok")
	_expect(_has_choice_id(choices, "dowsing_goggles"), "flag-ON normal offers should include Insight")
	_expect(not _has_choice_id(choices, "sacred_laurel"), "flag-ON normal offers should not include Great Laurel")
	_expect(catalog.is_slot_consuming_perk(sage_data), "Hyeonmun Charyeok should consume one perk slot")
	_expect(catalog.is_slot_consuming_perk(dowsing_data), "Insight should consume one perk slot")
	_expect(catalog.is_slot_consuming_perk(laurel_data), "Great Laurel should consume one perk slot")
	_expect(
		catalog.count_owned_slot_perks({"sage_ring": 3, "dowsing_goggles": 3, "sacred_laurel": 1}) == 3,
		"R1 redesigned perks should each count as one distinct slot-consuming perk"
	)


func _verify_sage_contract_raw_level_and_exemptions() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var expected_bonuses := [1, 1, 2, 2, 3]
	var expected_durations := [6.0, 7.0, 8.0, 9.0, 10.0]
	for level in [1, 2, 3, 4, 5]:
		var env := _make_env({"sage_ring": level})
		var runtime: Object = env["runtime"]
		var owner: Object = env["owner"]
		var registry: Object = env["registry"]
		runtime.refresh_runtime_perk_scaling(owner, registry)
		_expect(int(runtime.get_sage_ring_count()) == level, "Hyeonmun Lv.%d should expose raw invested level" % level)
		_expect(int(runtime.get_sage_ring_perk_level_bonus()) == 0, "Hyeonmun should grant no level bonus before its hit proc")
		_expect_close(runtime.get_sage_ring_speed_penalty_pct(), 0.0, "Hyeonmun should remove converted speed penalty")
		_expect_close(runtime.get_sage_ring_body_penalty_pct(), 0.0, "Hyeonmun should remove converted body penalty")
		var proc: Dictionary = env["state"].try_proc_hyeonmun_charyeok(
			{"hyeonmun_charyeok_roll_unit": 0.0},
			{"mythic_item_runtime": runtime, "registry": registry}
		)
		_expect(bool(proc.get("activated", false)), "Hyeonmun Lv.%d should proc on a forced successful roll" % level)
		_expect(int(proc.get("level_bonus", 0)) == int(expected_bonuses[level - 1]), "Hyeonmun Lv.%d bonus tier" % level)
		_expect_close(float(proc.get("total_duration_sec", 0.0)), float(expected_durations[level - 1]), "Hyeonmun Lv.%d duration" % level)
		_expect(int(runtime.get_sage_ring_perk_level_bonus()) == int(expected_bonuses[level - 1]), "active Hyeonmun should expose its temporary bonus")

	var regular_env := _make_env({"sage_ring": 3, "star_detector": 1})
	var regular_runtime: Object = regular_env["runtime"]
	regular_runtime.refresh_runtime_perk_scaling(regular_env["owner"], regular_env["registry"])
	var regular_state: Object = regular_env["state"]
	_expect(int(regular_state.get_item_perk_level_bonus()) == 0, "Hyeonmun should stay dormant before a hit proc")
	regular_state.try_proc_hyeonmun_charyeok(
		{"hyeonmun_charyeok_roll_unit": 0.0},
		{"mythic_item_runtime": regular_runtime, "registry": regular_env["registry"]}
	)
	_expect(int(regular_state.get_item_perk_level_bonus()) == 2, "Hyeonmun Lv.3 should sync temporary +2 after proc")
	_expect(int(regular_state.get_converted_perk_effect_level("star_detector")) == 3, "active Hyeonmun should raise other regular converted perks")
	_expect(int(regular_state.get_runtime_skill_level("sage_ring")) == 3, "Hyeonmun Charyeok should be excluded from runtime level bonuses")
	_expect(int(regular_state.get_converted_perk_effect_level("sage_ring")) == 3, "Hyeonmun Charyeok should not raise itself")

	var crown_env := _make_env({"sage_ring": 5, "transcendent_crown": 1, "star_detector": 1, "odins_eye": 1})
	var crown_runtime: Object = crown_env["runtime"]
	crown_runtime.refresh_runtime_perk_scaling(crown_env["owner"], crown_env["registry"])
	var crown_state: Object = crown_env["state"]
	_expect(int(crown_state.get_item_perk_level_bonus()) == 2, "Crown should remain the only source before Hyeonmun procs")
	crown_state.try_proc_hyeonmun_charyeok(
		{"hyeonmun_charyeok_roll_unit": 0.0},
		{"mythic_item_runtime": crown_runtime, "registry": crown_env["registry"]}
	)
	_expect(int(crown_state.get_item_perk_level_bonus()) == 5, "active Hyeonmun Lv.5 + Crown should stack for other regular perks")
	_expect(int(crown_state.get_converted_perk_effect_level("star_detector")) == 6, "Hyeonmun Charyeok + Crown should raise a regular converted perk")
	_expect(int(crown_state.get_converted_perk_effect_level("sage_ring")) == 5, "Crown should not buff Hyeonmun itself")
	_expect(int(crown_state.get_converted_perk_effect_level("transcendent_crown")) == 1, "Hyeonmun Charyeok should not buff Crown")
	_expect(int(crown_state.get_converted_perk_effect_level("odins_eye")) == 1, "Hyeonmun Charyeok should not buff mythic perks")


func _verify_sacred_laurel_mythic_channel_and_runtime_value() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_expect(MythicPerkGrantHelper.MYTHIC_PERK_IDS.has("sacred_laurel"), "Great Laurel should be in the mythic perk grant channel")

	var env := _make_env({"sacred_laurel": 1})
	var runtime: Object = env["runtime"]
	runtime.refresh_runtime_perk_scaling(env["owner"], env["registry"])
	_expect(int(runtime.get_sacred_laurel_leaf_bonus()) == 8, "Great Laurel Lv.1 should grant fixed eight leaves")
	var inactive_env := _make_env({})
	_expect(int(inactive_env["runtime"].get_sacred_laurel_leaf_bonus()) == 0, "Great Laurel Lv.0 should grant no leaves")

	var state := RuntimePerkState.new()
	for perk_id_value in MythicPerkGrantHelper.MYTHIC_PERK_IDS:
		var perk_id := str(perk_id_value)
		if perk_id != "sacred_laurel":
			state.runtime_skill_levels[perk_id] = 1
	var reward: Dictionary = MythicPerkGrantHelper.build_reward(null, FakeRegistry.new({
		"runtime_perk_state": state,
		"runtime_perk_catalog": OpenSlotCatalog.new(),
	}))
	_expect(str(reward.get("type", "")) == MythicPerkGrantHelper.REWARD_MYTHIC_PERK, "mythic channel should still return a perk when only Great Laurel is unowned")
	_expect(str(reward.get("perk_id", "")) == "sacred_laurel", "mythic channel should pick Great Laurel when it is the only unowned mythic perk")


func _verify_dowsing_goggles_insight_gate() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for level_value in [1, 2, 3]:
		var level := int(level_value)
		var env := _make_env({"dowsing_goggles": level})
		var runtime: Object = env["runtime"]
		runtime.refresh_runtime_perk_scaling(env["owner"], env["registry"])
		var expected_values: Array[float] = [40.0, 70.0, 100.0]
		var expected: float = expected_values[level - 1]
		_expect(runtime.is_dowsing_goggles_active(), "Insight Lv.%d should activate Dowsing Goggles effect gate" % level)
		_expect_close(runtime.get_dowsing_goggles_bonus_perk_chance_pct(), expected, "Insight bonus chance Lv.%d" % level)

	var level_zero_env := _make_env({})
	_expect(not level_zero_env["runtime"].is_dowsing_goggles_active(), "Insight Lv.0 should be inactive")
	_expect_close(level_zero_env["runtime"].get_dowsing_goggles_bonus_perk_chance_pct(), 0.0, "Insight Lv.0 chance")

	var guaranteed_env := _make_env({"dowsing_goggles": 3})
	var guaranteed_runtime: Object = guaranteed_env["runtime"]
	guaranteed_runtime.refresh_runtime_perk_scaling(guaranteed_env["owner"], guaranteed_env["registry"])
	_expect(
		int(guaranteed_runtime.get_runtime_perk_choice_count_bonus(guaranteed_env["owner"], guaranteed_env["registry"])) == 1,
		"Insight Lv.3 should guarantee the real runtime +1 choice consumer"
	)
	_expect(guaranteed_runtime.was_dowsing_goggles_bonus_triggered(), "Insight Lv.3 should keep the existing bonus-trigger flag")


func _verify_gold_bar_remains_deleted_and_runtime_neutral() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_expect(not PerkConversionValues.CONVERSION_SOURCE_TO_PERK.has("gold_bar"), "Gold Bar should remain unmapped under flag ON")
	_expect(not PerkConversionValues.DELETED_ITEM_COMPENSATION.has("gold_bar"), "Gold Bar should not receive compensation mapping")

	var field_candidates: Array = ActiveItemFieldSpawnPool.new().build_spawn_candidates(FakeRegistry.new())
	_expect(not _array_has_item(field_candidates, "gold_bar"), "flag-ON field spawn should not emit Gold Bar")
	_expect(not _array_has_item(PandoraLegacyPoolBuilder.new().build_passive_pool(MythicItemCatalog.new(), FakeOwner.new()), "gold_bar"), "flag-ON Pandora passive pool should not emit Gold Bar")
	_expect(not _array_has_item(PlazaShopStock.new().build_inventory(MythicItemCatalog.new(), 12, 17071), "gold_bar"), "flag-ON plaza shop should not emit Gold Bar")

	var resolver := StageClearRewardResolver.new()
	var box_result: Dictionary = resolver._roll_normal_box_reward(FakeOwner.new(), FakeRegistry.new(), 0.15)
	_expect(str(box_result.get("type", "")) != StageClearRewardResolver.REWARD_PASSIVE, "flag-ON stage-clear passive lane should not emit passive items")
	_expect(str(box_result.get("type", "")) == StageClearRewardResolver.REWARD_STARPOINT, "flag-ON stage-clear passive lane should redirect to starpoints")


func _verify_flag_off_legacy_items_still_work() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var env := _make_env({})
	var runtime: Object = env["runtime"]
	_expect(_equip_item(env, "sage_ring", {"sage_speed_penalty_pct": 17.0, "sage_body_penalty_pct": 11.0}), "flag-OFF legacy Sage Ring should still equip")
	_expect(_equip_item(env, "sacred_laurel", {"leaf_count": 5.0}), "flag-OFF legacy Sacred Laurel should still equip")
	_expect(_equip_item(env, "dowsing_goggles", {"bonus_perk_chance": 88.0}), "flag-OFF legacy Dowsing Goggles should still equip")
	_expect(
		int(runtime.acquire_item("gold_bar", env["owner"], env["registry"], {}, false, false)) >= 0,
		"flag-OFF legacy Gold Bar should still be acquirable through direct runtime paths"
	)
	_expect(int(runtime.get_sage_ring_perk_level_bonus()) == 1, "flag-OFF Sage Ring should keep legacy +1 item bonus")
	_expect_close(runtime.get_sage_ring_speed_penalty_pct(), 17.0, "flag-OFF Sage Ring speed roll")
	_expect_close(runtime.get_sage_ring_body_penalty_pct(), 11.0, "flag-OFF Sage Ring body roll")
	_expect(int(runtime.get_sacred_laurel_leaf_bonus()) == 5, "flag-OFF Sacred Laurel should keep legacy leaf roll")
	_expect_close(runtime.get_dowsing_goggles_bonus_perk_chance_pct(), 88.0, "flag-OFF Dowsing Goggles chance roll")
	_expect(int(runtime.get_gold_bar_count()) == 1, "flag-OFF Gold Bar direct runtime count should remain")
	_expect(int(runtime.get_gold_bar_total_sell_price()) == 2000, "flag-OFF Gold Bar sell price should remain")
	_expect_close(runtime.get_gold_bar_speed_penalty_pct(), 30.0, "flag-OFF Gold Bar penalty should remain")


func _make_env(levels: Dictionary) -> Dictionary:
	var runtime := MythicItemRuntime.new()
	runtime.get_snapshot()
	var state := RuntimePerkState.new()
	for id_value in levels.keys():
		state.runtime_skill_levels[str(id_value)] = int(levels[id_value])
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"runtime_perk_state": state,
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
	})
	runtime.owner_syncer.sync_runtime_perk_state_ref(runtime, registry)
	return {
		"runtime": runtime,
		"state": state,
		"owner": owner,
		"registry": registry,
	}


func _equip_item(env: Dictionary, item_name: String, rolls: Dictionary) -> bool:
	return bool(env["runtime"].equip_item(item_name, env["owner"], env["registry"], rolls, false))


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str((item_value as Dictionary).get("name", "")) == item_name:
			return true
		if str(item_value) == item_name:
			return true
	return false


func _has_choice_id(choices: Array, choice_id: String) -> bool:
	for choice in choices:
		if choice is Dictionary and str((choice as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
