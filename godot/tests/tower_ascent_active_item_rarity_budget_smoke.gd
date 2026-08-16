extends SceneTree

const ActiveItemCatalog := preload(
	"res://scripts/items/active_item_catalog.gd"
)
const ActiveItemFieldSpawnPool := preload(
	"res://scripts/items/active_item_field_spawn_pool.gd"
)
const ActiveItemFieldSpawnScheduler := preload(
	"res://scripts/items/active_item_field_spawn_scheduler.gd"
)
const ActiveItemRaritySchema := preload(
	"res://scripts/items/active_item_rarity_schema.gd"
)
const StageClearRewardResolver := preload(
	"res://scripts/core/stage_clear_reward_resolver.gd"
)
const TowerAscentActiveItemAcquisitionPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_active_item_acquisition_policy.gd"
)
const TowerAscentChestContract := preload(
	"res://scripts/tower_ascent/tower_ascent_chest_contract.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentShopShelfBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_shop_shelf_builder.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_schema()
	_verify_shared_acquisition_channels()
	_verify_live_field_chest_and_shop_consumers()
	_verify_regular_spawn_budget_owner()
	_verify_source_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_active_item_rarity_budget_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_schema() -> void:
	var catalog := ActiveItemCatalog.new()
	var built_count := 0
	for item_name_value in ActiveItemCatalog.CATALOG_ORDER:
		var item_data: Dictionary = catalog.build_item_by_name(str(item_name_value))
		if item_data.is_empty():
			continue
		built_count += 1
		_expect(
			ActiveItemRaritySchema.has_valid_rarity(item_data),
			"every buildable active catalog entry must expose one canonical rarity: %s" % item_name_value
		)
	_expect(built_count > 0, "the formal catalog order must expose buildable entries")
	var mythic: Dictionary = catalog.build_item_by_name("elixir_of_mastery")
	_expect(str(mythic.get("rarity", "")) == ActiveItemRaritySchema.RARITY_MYTHIC, "the existing mythic active must preserve its explicit rarity")
	var common: Dictionary = catalog.build_item_by_name("banana")
	_expect(str(common.get("rarity", "")) == ActiveItemRaritySchema.RARITY_COMMON, "flat legacy active items must normalize to the temporary common assignment")


func _verify_shared_acquisition_channels() -> void:
	var common := {"type": "active", "rarity": "common"}
	var rare := {"type": "active", "rarity": "rare"}
	var legendary := {"type": "active", "rarity": "legendary"}
	var mythic := {"type": "active", "rarity": "mythic"}
	_expect(TowerAscentActiveItemAcquisitionPolicy.is_allowed(common, TowerAscentActiveItemAcquisitionPolicy.CHANNEL_FIELD_SPAWN), "field channel must admit common active items")
	_expect(not TowerAscentActiveItemAcquisitionPolicy.is_allowed(rare, TowerAscentActiveItemAcquisitionPolicy.CHANNEL_FIELD_SPAWN), "field channel must reject above-common active items")
	_expect(TowerAscentActiveItemAcquisitionPolicy.is_allowed(rare, TowerAscentActiveItemAcquisitionPolicy.CHANNEL_NORMAL_CHEST), "normal chest must share the schema while admitting temporary rare items")
	_expect(TowerAscentActiveItemAcquisitionPolicy.is_allowed(legendary, TowerAscentActiveItemAcquisitionPolicy.CHANNEL_SHOP_PREMIUM), "premium shelf must admit legendary items")
	_expect(TowerAscentActiveItemAcquisitionPolicy.is_allowed(mythic, TowerAscentActiveItemAcquisitionPolicy.CHANNEL_SHOP_PREMIUM), "premium shelf must admit mythic items")
	_expect(not TowerAscentActiveItemAcquisitionPolicy.is_allowed({"type": "passive", "rarity": "common"}, TowerAscentActiveItemAcquisitionPolicy.CHANNEL_FIELD_SPAWN), "tower active acquisition channels must reject passive items regardless of rarity")


func _verify_live_field_chest_and_shop_consumers() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var registry := FakeRegistry.new()
	var field_candidates: Array[Dictionary] = ActiveItemFieldSpawnPool.new().build_spawn_candidates(registry)
	_expect(not field_candidates.is_empty(), "tower field spawn must retain common active candidates")
	for item_data in field_candidates:
		_expect(
			TowerAscentActiveItemAcquisitionPolicy.is_allowed(
				item_data,
				TowerAscentActiveItemAcquisitionPolicy.CHANNEL_FIELD_SPAWN
			),
			"tower field spawn must use the shared common-only rarity filter"
		)

	var reward: Dictionary = StageClearRewardResolver.new().roll_reward(
		TowerAscentChestContract.CHEST_NORMAL,
		null,
		registry,
		0.04
	)
	_expect(str(reward.get("type", "")) == StageClearRewardResolver.REWARD_ACTIVE, "deterministic normal-chest active lane must remain reachable")
	_expect(
		TowerAscentActiveItemAcquisitionPolicy.is_allowed(
			reward.get("item_data", {}) as Dictionary,
			TowerAscentActiveItemAcquisitionPolicy.CHANNEL_NORMAL_CHEST
		),
		"normal chest active reward must use the shared rarity field"
	)

	var shelves: Dictionary = TowerAscentShopShelfBuilder.new().build_candidate_shelves(registry)
	var regular: Array = shelves.get("regular", []) as Array
	var premium: Array = shelves.get("premium", []) as Array
	_expect(not regular.is_empty(), "tower shop must expose regular active candidates")
	_expect(not premium.is_empty(), "tower shop must expose its separate premium candidate lane")
	for item_value in regular:
		_expect(TowerAscentActiveItemAcquisitionPolicy.is_allowed(item_value as Dictionary, TowerAscentActiveItemAcquisitionPolicy.CHANNEL_SHOP_REGULAR), "regular shelf must use the shared rarity field")
	for item_value in premium:
		_expect(TowerAscentActiveItemAcquisitionPolicy.is_allowed(item_value as Dictionary, TowerAscentActiveItemAcquisitionPolicy.CHANNEL_SHOP_PREMIUM), "premium shelf must use the shared rarity field")


func _verify_regular_spawn_budget_owner() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var scheduler := ActiveItemFieldSpawnScheduler.new()
	scheduler.reset()
	var initial: Dictionary = scheduler.get_regular_spawn_budget_state()
	_expect(int(initial.get("budget", -1)) >= TowerAscentTuning.TEMP_REGULAR_SPAWN_BUDGET_MIN, "tower match reset must roll the budget from the tuning table")
	_expect(int(initial.get("budget", -1)) <= TowerAscentTuning.TEMP_REGULAR_SPAWN_BUDGET_MAX, "tower match reset must cap the budget at the tuning-table maximum")
	var generation := int(initial.get("generation", 0))
	scheduler.debug_set_regular_spawn_budget_for_test(1)
	_make_due(scheduler)
	_expect(scheduler.consume_regular_spawn_due(FakeOwner.new(), null, false, false), "one available regular budget must admit one due spawn")
	_make_due(scheduler)
	_expect(not scheduler.consume_regular_spawn_due(FakeOwner.new(), null, false, false), "the per-match regular budget must cap later timer opportunities")
	var capped: Dictionary = scheduler.get_regular_spawn_budget_state()
	_expect(int(capped.get("consumed", 0)) == 1 and int(capped.get("remaining", -1)) == 0, "budget state must own consumed and remaining counts")
	scheduler.mark_spawn_now()
	_expect(int(scheduler.get_regular_spawn_budget_state().get("consumed", 0)) == 1, "skill or debug-created items must not consume regular budget")
	scheduler.reset()
	_expect(int(scheduler.get_regular_spawn_budget_state().get("generation", 0)) == generation + 1, "each match reset or retry must perform a fresh budget roll")

	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	scheduler.reset()
	_expect(bool(scheduler.get_regular_spawn_budget_state().get("unlimited", false)), "flag OFF scheduler must preserve the uncapped legacy timer")
	_make_due(scheduler)
	_expect(scheduler.consume_regular_spawn_due(FakeOwner.new(), null, false, false), "flag OFF first legacy timer opportunity must remain available")
	_make_due(scheduler)
	_expect(scheduler.consume_regular_spawn_due(FakeOwner.new(), null, false, false), "flag OFF later legacy timer opportunities must remain available")


func _verify_source_contract() -> void:
	var field_source := FileAccess.get_file_as_string("res://scripts/items/active_item_field_spawn_pool.gd")
	var chest_source := FileAccess.get_file_as_string("res://scripts/core/stage_clear_reward_resolver.gd")
	var shelf_source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_shop_shelf_builder.gd")
	_expect(field_source.find("CHANNEL_FIELD_SPAWN") >= 0, "field pool must call the shared acquisition policy")
	_expect(chest_source.find("CHANNEL_NORMAL_CHEST") >= 0, "normal chest must call the shared acquisition policy")
	_expect(shelf_source.find("CHANNEL_SHOP_REGULAR") >= 0 and shelf_source.find("CHANNEL_SHOP_PREMIUM") >= 0, "both shop shelves must call the shared acquisition policy")
	var tuning_source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_tuning.gd")
	_expect(tuning_source.find("TEMP_REGULAR_SPAWN_BUDGET_MIN") >= 0 and tuning_source.find("TEMP_REGULAR_SPAWN_BUDGET_MAX") >= 0, "unresolved budget values must stay named TEMP tuning constants")


func _make_due(scheduler: Object) -> void:
	scheduler.last_item_spawn_msec = maxi(1, Time.get_ticks_msec() - 1000)
	scheduler.next_item_spawn_delay_msec = 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeOwner:
	extends RefCounted
	var current_stage := 1
	var arena_mode_enabled := false
	var victory_loot_phase_active := false


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class FakeRegistry:
	extends RefCounted
	var unlock_store: Object = FakeUnlockStore.new()

	func get_instance(key: String) -> Object:
		return unlock_store if key == TowerAscentUnlockFilter.STORE_KEY else null
