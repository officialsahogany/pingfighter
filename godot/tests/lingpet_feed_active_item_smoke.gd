extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []
var _direct_effect_calls := 0


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var special_gauge := 0.0
	var special_gauge_max := 500.0
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_slots: Array = []
	var ringpet_slots: Array = []
	var lingpet_slot_pet_ids: Array = []
	var ringpet_slot_pet_ids: Array = []
	var lingpet_active_slot_index := -1
	var ringpet_active_slot_index := -1
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0

	func queue_redraw() -> void:
		pass


class FakeHudState:
	extends RefCounted

	var selected_index := 0

	func set_selected_index(index: int) -> void:
		selected_index = index

	func get_selected_index() -> int:
		return selected_index


class FakeFeedback:
	extends RefCounted

	var shake_count := 0
	var gauge_flash_count := 0

	func max_screen_shake(_amount: float, _duration: float) -> void:
		shake_count += 1

	func trigger_gauge_flash() -> void:
		gauge_flash_count += 1


class FakeAudio:
	extends RefCounted

	var active_item_count := 0
	var alchemy_count := 0

	func play_active_item() -> void:
		active_item_count += 1

	func play_alchemy() -> void:
		alchemy_count += 1


class FakeAlchemyPerkState:
	extends RefCounted

	func get_active_item_recycle_chance() -> float:
		return 0.90


class FakeRegistry:
	extends RefCounted

	var lingpet_runtime: Object
	var runtime_perk_state: Object = null
	var hud_state := FakeHudState.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()

	func _init(runtime: Object, perk_state: Object = null) -> void:
		lingpet_runtime = runtime
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		match key:
			"lingpet_egg_runtime":
				return lingpet_runtime
			"runtime_perk_state":
				return runtime_perk_state
			"active_item_hud_state":
				return hud_state
			"battle_feedback_state":
				return feedback
			"game_audio":
				return audio
		return null

	func clear_refs() -> void:
		lingpet_runtime = null
		runtime_perk_state = null


func _init() -> void:
	_run()


func _run() -> void:
	_verify_feed_catalog_tiers_and_icon()
	_verify_feed_field_spawn_gate_uses_real_catalog()
	_verify_basic_feed_active_item_restores_satiety()
	_verify_melon_feed_wakes_ko_through_shared_effect()
	_verify_full_satiety_and_battle_cap_preserve_item()
	_verify_feed_no_global_cooldown_contract()
	_verify_alchemy_recycle_cannot_bypass_battle_cap()
	_verify_lingpet_feed_source_contracts()

	if _failures.is_empty():
		print("lingpet_feed_active_item_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_feed_catalog_tiers_and_icon() -> void:
	var catalog := ActiveItemCatalog.new()
	var basic_data: Dictionary = catalog.build_item_by_name("lingpet_feed")
	var apple_data: Dictionary = catalog.build_item_by_name("lingpet_apple_feed")
	var melon_data: Dictionary = catalog.build_item_by_name("lingpet_melon_feed")
	var special_data: Dictionary = catalog.build_item_by_name("lingpet_special_feed")
	_expect(not basic_data.is_empty(), "lingpet_feed should build from the active item catalog")
	_expect(not apple_data.is_empty(), "lingpet_apple_feed should build from the active item catalog")
	_expect(not melon_data.is_empty(), "lingpet_melon_feed should build from the active item catalog")
	_expect(not special_data.is_empty(), "lingpet_special_feed should build from the active item catalog")
	_expect(ActiveItemCatalog.FIELD_SPAWN_ORDER.has("lingpet_feed"), "basic feed should remain in the active field-spawn order")
	_expect(ActiveItemCatalog.FIELD_SPAWN_ORDER.has("lingpet_apple_feed"), "apple feed should join the active field-spawn order")
	_expect(ActiveItemCatalog.FIELD_SPAWN_ORDER.has("lingpet_melon_feed"), "melon feed should join the active field-spawn order")
	_expect(not ActiveItemCatalog.FIELD_SPAWN_ORDER.has("lingpet_special_feed"), "special feed should remain reward/shop-only and not field-spawn")
	_expect_str(str(basic_data.get("display_name", "")), "귤", "basic feed should be renamed to 귤")
	_expect_str(str(apple_data.get("display_name", "")), "사과", "apple feed should expose its locked Korean name")
	_expect_str(str(melon_data.get("display_name", "")), "멜론", "melon feed should expose its locked Korean name")
	_expect_str(str(special_data.get("display_name", "")), "특제 사료", "special feed should expose its locked Korean name")
	_expect_str(str(basic_data.get("effect", "")), "lingpet_feed", "basic feed should dispatch through the shared feed effect id")
	_expect_str(str(apple_data.get("effect", "")), "lingpet_feed", "apple feed should dispatch through the shared feed effect id")
	_expect_str(str(melon_data.get("effect", "")), "lingpet_feed", "melon feed should dispatch through the shared feed effect id")
	_expect_str(str(special_data.get("effect", "")), "lingpet_feed", "special feed should dispatch through the shared feed effect id")
	_expect_float(float(apple_data.get("feed_amount", 0.0)), 30.0, "apple feed should restore 30 satiety")
	_expect_float(float(basic_data.get("feed_amount", 0.0)), 40.0, "basic feed should restore 40 satiety")
	_expect_float(float(melon_data.get("feed_amount", 0.0)), 50.0, "melon feed should restore 50 satiety")
	_expect_float(float(special_data.get("feed_amount", 0.0)), 100.0, "special feed should restore 100 satiety")
	_expect(bool(basic_data.get("consumable", false)), "basic feed should be consumable")
	_expect(bool(apple_data.get("consumable", false)), "apple feed should be consumable")
	_expect(bool(melon_data.get("consumable", false)), "melon feed should be consumable")
	_expect(bool(special_data.get("consumable", false)), "special feed should be consumable")
	_expect(bool(basic_data.get("no_global_cooldown", false)), "basic feed should not trigger the shared active-item cooldown")
	_expect(bool(apple_data.get("no_global_cooldown", false)), "apple feed should not trigger the shared active-item cooldown")
	_expect(bool(melon_data.get("no_global_cooldown", false)), "melon feed should not trigger the shared active-item cooldown")
	_expect(bool(special_data.get("no_global_cooldown", false)), "special feed should not trigger the shared active-item cooldown")
	_expect(bool(basic_data.get("shop_guaranteed", false)), "basic feed should be guaranteed shop stock")
	_expect(bool(apple_data.get("shop_guaranteed", false)), "apple feed should be guaranteed shop stock")
	_expect(bool(melon_data.get("shop_guaranteed", false)), "melon feed should be guaranteed shop stock")
	_expect(bool(special_data.get("shop_guaranteed", false)), "special feed should be guaranteed shop stock")
	_expect(not bool(apple_data.get("reward_only", false)), "apple feed should not be reward-only")
	_expect(not bool(melon_data.get("reward_only", false)), "melon feed should not be reward-only")
	_expect(bool(special_data.get("reward_only", false)), "special feed should be marked as reward/shop-only, not field-spawn")
	_expect(not bool(basic_data.get("no_recycle", false)), "feed should stay recyclable; the battle cap owns infinite-use prevention")
	_expect(not bool(apple_data.get("no_recycle", false)), "apple feed should stay recyclable; the battle cap owns infinite-use prevention")
	_expect(not bool(melon_data.get("no_recycle", false)), "melon feed should stay recyclable; the battle cap owns infinite-use prevention")
	_expect(not bool(special_data.get("no_recycle", false)), "special feed should stay recyclable; the battle cap owns infinite-use prevention")
	var icon_path := str(basic_data.get("icon_path", ""))
	_expect(icon_path.ends_with("lingpet_feed_icon.png"), "basic feed should use the dedicated item icon path")
	var apple_icon_path := str(apple_data.get("icon_path", ""))
	var melon_icon_path := str(melon_data.get("icon_path", ""))
	_expect(apple_icon_path.ends_with("lingpet_apple_feed_icon.png"), "apple feed should use its dedicated item icon path")
	_expect(melon_icon_path.ends_with("lingpet_melon_feed_icon.png"), "melon feed should use its dedicated item icon path")
	_expect_str(str(special_data.get("icon_path", "")), icon_path, "special feed should reuse the accepted feed icon in Slice 4")
	_expect(ProjectResourceLoader.load_texture(icon_path) != null, "lingpet feed icon should load through the project resource loader")
	_expect(ProjectResourceLoader.load_texture(apple_icon_path) != null, "apple feed icon should load through the project resource loader")
	_expect(ProjectResourceLoader.load_texture(melon_icon_path) != null, "melon feed icon should load through the project resource loader")


func _verify_feed_field_spawn_gate_uses_real_catalog() -> void:
	var pool := ActiveItemFieldSpawnPool.new()
	var empty_owner := FakeOwner.new()
	var owned_owner := FakeOwner.new()
	owned_owner.lingpet_owned_pet_ids = ["maribo"]
	_expect(
		not _array_has_item(pool.build_spawn_candidates(null, empty_owner), "lingpet_feed"),
		"real field-spawn candidates should hide basic feed before the player owns a lingpet"
	)
	_expect(
		not _array_has_item(pool.build_spawn_candidates(null, empty_owner), "lingpet_apple_feed"),
		"real field-spawn candidates should hide apple feed before the player owns a lingpet"
	)
	_expect(
		not _array_has_item(pool.build_spawn_candidates(null, empty_owner), "lingpet_melon_feed"),
		"real field-spawn candidates should hide melon feed before the player owns a lingpet"
	)
	pool.clear_spawn_candidate_cache()
	var owned_candidates: Array[Dictionary] = pool.build_spawn_candidates(null, owned_owner)
	_expect(
		_array_has_item(owned_candidates, "lingpet_feed"),
		"real field-spawn candidates should expose basic feed after the player owns a lingpet"
	)
	_expect(
		_array_has_item(owned_candidates, "lingpet_apple_feed"),
		"real field-spawn candidates should expose apple feed after the player owns a lingpet"
	)
	_expect(
		_array_has_item(owned_candidates, "lingpet_melon_feed"),
		"real field-spawn candidates should expose melon feed after the player owns a lingpet"
	)
	_expect(
		not _array_has_item(owned_candidates, "lingpet_special_feed"),
		"special feed should not leak into field-spawn candidates"
	)


func _verify_basic_feed_active_item_restores_satiety() -> void:
	var runtime := ActiveItemRuntime.new()
	var lingpet_runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new(lingpet_runtime)
	var owner := FakeOwner.new()

	_expect(runtime.grant_item_to_slot("lingpet_feed", owner, registry, false), "fixture should grant a basic feed active item")
	_expect(not runtime.use_slot(0, owner, registry), "feed should not apply without an active lingpet")
	_expect(owner.active_item_slots.size() == 1, "failed feed should remain in the active slot")
	_expect_str(str(lingpet_runtime.get_last_affinity_result_for_tests().get("blocked_reason", "")), "missing_lingpet", "missing-lingpet feed should report the runtime gate")

	_expect(lingpet_runtime.debug_grant_and_activate_pet("maribo", owner), "fixture should activate a lingpet")
	lingpet_runtime.set_satiety_for_tests("maribo", 20.0)
	var affinity_before := lingpet_runtime.get_affinity_points("maribo")
	_clear_active_item_cooldown(runtime, owner)
	_expect(runtime.use_slot(0, owner, registry), "basic feed should apply through the active item runtime once a lingpet is active")
	_expect(owner.active_item_slots.is_empty(), "successful consumable basic feed should leave the active slot")
	_expect_float(lingpet_runtime.get_satiety("maribo"), 20.0, "feed should wait for the bowl completion before restoring satiety")
	_expect(bool(lingpet_runtime.get_snapshot().get("feed_bowl_active", false)), "successful feed should spawn a visible feed bowl")
	_advance_feed_until_complete(lingpet_runtime, owner, registry)
	var last_result: Dictionary = lingpet_runtime.get_last_affinity_result_for_tests()
	_expect_str(str(last_result.get("source", "")), "satiety_feed", "completed feed should report the satiety-feed source")
	_expect_float(float(last_result.get("feed_amount", 0.0)), 40.0, "completed basic feed should preserve its threaded amount")
	_expect_float(float(last_result.get("granted_satiety", 0.0)), 40.0, "completed basic feed should restore 40 satiety")
	_expect(lingpet_runtime.get_satiety("maribo") > 58.0 and lingpet_runtime.get_satiety("maribo") <= 60.0, "basic feed should restore satiety after normal bowl-walk drain")
	_expect_float(lingpet_runtime.get_affinity_points("maribo"), affinity_before, "completed feed must not grant affinity points")
	_expect(registry.audio.active_item_count == 1, "successful feed should play active item feedback")

	runtime.reset()
	_cleanup_runtime(lingpet_runtime, registry)


func _verify_melon_feed_wakes_ko_through_shared_effect() -> void:
	var runtime := ActiveItemRuntime.new()
	var lingpet_runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new(lingpet_runtime)
	var owner := FakeOwner.new()
	_expect(lingpet_runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "", registry), "KO fixture should activate a skill-capable lingpet")
	lingpet_runtime.set_satiety_for_tests("maribo", 0.0)
	lingpet_runtime.update(2.0, owner, registry)
	_expect(lingpet_runtime.is_companion_exhausted_for_tests(owner), "fixture should reach exhausted state before melon feed")

	_expect(runtime.grant_item_to_slot("lingpet_melon_feed", owner, registry, false), "fixture should grant a melon feed active item")
	_clear_active_item_cooldown(runtime, owner)
	_expect(runtime.use_slot(0, owner, registry), "melon feed should be usable on a KO companion")
	_advance_feed_until_complete(lingpet_runtime, owner, registry)
	var satiety_after_feed := lingpet_runtime.get_satiety("maribo")
	_expect(satiety_after_feed > 0.0 and satiety_after_feed <= LingpetAffinityState.SATIETY_MAX, "melon feed should restore positive satiety after KO (got %.2f)" % satiety_after_feed)
	_expect(not lingpet_runtime.is_companion_exhausted_for_tests(owner), "melon feed should wake an exhausted companion through set_satiety")
	var last_result: Dictionary = lingpet_runtime.get_last_affinity_result_for_tests()
	_expect_float(float(last_result.get("feed_amount", 0.0)), 50.0, "melon feed should thread 50 satiety through the runtime")
	_expect(float(last_result.get("granted_satiety", 0.0)) >= 49.0, "melon feed from zero should grant almost the full 50 satiety even after KO rest ticks")

	runtime.reset()
	_cleanup_runtime(lingpet_runtime, registry)


func _verify_full_satiety_and_battle_cap_preserve_item() -> void:
	var runtime := ActiveItemRuntime.new()
	var lingpet_runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new(lingpet_runtime)
	var owner := FakeOwner.new()
	_expect(lingpet_runtime.debug_grant_and_activate_pet("maribo", owner), "fixture should activate a lingpet")

	lingpet_runtime.set_satiety_for_tests("maribo", LingpetAffinityState.SATIETY_MAX)
	_expect(runtime.grant_item_to_slot("lingpet_feed", owner, registry, false), "fixture should grant a full-satiety feed")
	_clear_active_item_cooldown(runtime, owner)
	_expect(not runtime.use_slot(0, owner, registry), "full-satiety feed use should be blocked")
	_expect(owner.active_item_slots.size() == 1, "full-satiety blocked feed should not be consumed")
	_expect_str(str(lingpet_runtime.get_last_affinity_result_for_tests().get("blocked_reason", "")), "satiety_full", "full-satiety blocked feed should report satiety_full")
	owner.active_item_slots.clear()

	lingpet_runtime.set_satiety_for_tests("maribo", 0.0)
	_complete_feed_item(runtime, lingpet_runtime, owner, registry, "lingpet_apple_feed")
	lingpet_runtime.set_satiety_for_tests("maribo", 0.0)
	_complete_feed_item(runtime, lingpet_runtime, owner, registry, "lingpet_melon_feed")
	lingpet_runtime.set_satiety_for_tests("maribo", 20.0)
	_expect(runtime.grant_item_to_slot("lingpet_feed", owner, registry, false), "fixture should grant a third battle feed")
	_clear_active_item_cooldown(runtime, owner)
	_expect(not runtime.use_slot(0, owner, registry), "third completed feed in one battle should be blocked")
	_expect(owner.active_item_slots.size() == 1, "battle-cap blocked feed should not be consumed")
	_expect_str(str(lingpet_runtime.get_last_affinity_result_for_tests().get("blocked_reason", "")), "max_battle_feed_uses", "third feed should report max_battle_feed_uses")

	runtime.reset()
	_cleanup_runtime(lingpet_runtime, registry)


func _verify_feed_no_global_cooldown_contract() -> void:
	var slot_controller := ActiveItemSlotController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(null)
	var feed_item: Dictionary = ActiveItemCatalog.new().build_item_by_name("lingpet_feed")
	feed_item["last_use_msec"] = -999999
	var held_item := {
		"name": "banana",
		"effect": "banana",
		"display_name": "banana",
		"cooldown_msec": 7000,
		"consumable": true,
		"last_use_msec": -999999,
	}
	owner.active_item_slots = [feed_item, held_item]
	slot_controller.last_item_use_msec = -999999
	_direct_effect_calls = 0
	_expect(slot_controller.use_slot(0, owner, registry, false, Callable(self, "_apply_direct_effect")), "direct feed slot use should succeed")
	_expect_eq(_direct_effect_calls, 1, "direct feed use should call the effect once")
	_expect_eq(slot_controller.last_item_use_msec, -999999, "feed should not move the shared global cooldown anchor")
	_expect(owner.active_item_slots.size() == 1, "direct feed use should consume only the feed slot")
	if owner.active_item_slots.size() == 1:
		var remaining: Dictionary = owner.active_item_slots[0]
		_expect_eq(int(remaining.get("last_use_msec", 0)), -999999, "feed should not stamp cooldown onto other held items")


func _verify_alchemy_recycle_cannot_bypass_battle_cap() -> void:
	var runtime := ActiveItemRuntime.new()
	var lingpet_runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new(lingpet_runtime, FakeAlchemyPerkState.new())
	var owner := FakeOwner.new()
	_expect(lingpet_runtime.debug_grant_and_activate_pet("maribo", owner), "alchemy fixture should activate a lingpet")
	var recycle_seed := _find_recycle_seed(2)
	_expect(recycle_seed >= 0, "fixture should find a deterministic seed that recycles two feeds")
	seed(recycle_seed)

	lingpet_runtime.set_satiety_for_tests("maribo", 0.0)
	_expect(runtime.grant_item_to_slot("lingpet_feed", owner, registry, false), "fixture should grant an alchemy feed")
	_clear_active_item_cooldown(runtime, owner)
	_expect(runtime.use_slot(0, owner, registry), "first alchemy feed should apply")
	_advance_feed_until_complete(lingpet_runtime, owner, registry)
	_expect(owner.active_item_slots.size() == 1, "alchemy should recycle the first feed into the slot")
	_expect(registry.audio.alchemy_count == 1, "first feed recycle should play Alchemy feedback")

	lingpet_runtime.set_satiety_for_tests("maribo", 0.0)
	_clear_active_item_cooldown(runtime, owner)
	_expect(runtime.use_slot(0, owner, registry), "second recycled feed should apply")
	_advance_feed_until_complete(lingpet_runtime, owner, registry)
	_expect(owner.active_item_slots.size() == 1, "alchemy should recycle the second feed into the slot")
	_expect(registry.audio.alchemy_count == 2, "second feed recycle should play Alchemy feedback")

	lingpet_runtime.set_satiety_for_tests("maribo", 0.0)
	_clear_active_item_cooldown(runtime, owner)
	_expect(not runtime.use_slot(0, owner, registry), "recycled feed should still stop at the battle feed cap")
	_expect(owner.active_item_slots.size() == 1, "battle-cap blocked recycled feed should remain in the slot")
	_expect_str(str(lingpet_runtime.get_last_affinity_result_for_tests().get("blocked_reason", "")), "max_battle_feed_uses", "recycled third feed should report max_battle_feed_uses")

	runtime.reset()
	_cleanup_runtime(lingpet_runtime, registry)


func _verify_lingpet_feed_source_contracts() -> void:
	var catalog_source := FileAccess.get_file_as_string("res://scripts/items/active_item_catalog.gd")
	_expect(catalog_source.find("\"lingpet_feed\"") >= 0, "active item catalog should mention basic feed")
	_expect(catalog_source.find("\"lingpet_apple_feed\"") >= 0, "active item catalog should mention apple feed")
	_expect(catalog_source.find("\"lingpet_melon_feed\"") >= 0, "active item catalog should mention melon feed")
	_expect(catalog_source.find("\"lingpet_special_feed\"") >= 0, "active item catalog should mention special feed")
	_expect(catalog_source.find("func _build_lingpet_feed") >= 0, "active item catalog should build basic feed")
	_expect(catalog_source.find("func _build_lingpet_apple_feed") >= 0, "active item catalog should build apple feed")
	_expect(catalog_source.find("func _build_lingpet_melon_feed") >= 0, "active item catalog should build melon feed")
	_expect(catalog_source.find("func _build_lingpet_special_feed") >= 0, "active item catalog should build special feed")
	_expect(catalog_source.find("\"feed_amount\": 30.0") >= 0, "apple feed catalog should own the 30 satiety amount")
	_expect(catalog_source.find("\"feed_amount\": 40.0") >= 0, "basic feed catalog should own the 40 satiety amount")
	_expect(catalog_source.find("\"feed_amount\": 50.0") >= 0, "melon feed catalog should own the 50 satiety amount")
	_expect(catalog_source.find("\"feed_amount\": 100.0") >= 0, "special feed catalog should own the 100 satiety amount")

	var router_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_router.gd")
	_expect(router_source.find("\"lingpet_feed\"") >= 0 and router_source.find("\"apply_lingpet_feed\"") >= 0, "active item effect router should dispatch feed items")

	var facade_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_action_facade.gd")
	_expect(facade_source.find("feed_amount") >= 0, "effect facade should thread catalog feed_amount")
	_expect(facade_source.find("feed_lingpet(owner, registry, feed_amount)") >= 0, "effect facade should call runtime feed_lingpet with feed_amount")

	var slot_source := FileAccess.get_file_as_string("res://scripts/items/active_item_slot_controller.gd")
	_expect(slot_source.find("func _uses_global_cooldown") >= 0, "slot controller should own the no-global-cooldown helper")
	_expect(slot_source.find("if not ignore_cooldown and _uses_global_cooldown(item_data):") >= 0, "feed should not stamp global cooldown onto other slots")

	var bowl_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_feed_bowl_state.gd")
	_expect(bowl_source.find("lingpet_feed_bowl.png") >= 0, "feed bowl state should draw the dedicated bowl icon")

	var debug_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	_expect(debug_source.find("\"lingpet_feed\"") >= 0 and debug_source.find("\"lingpet_apple_feed\"") >= 0 and debug_source.find("\"lingpet_melon_feed\"") >= 0 and debug_source.find("\"lingpet_special_feed\"") >= 0, "debug active item menu should expose every feed tier")

	var reward_source := FileAccess.get_file_as_string("res://scripts/core/stage_clear_reward_resolver.gd")
	_expect(reward_source.find("\"lingpet_special_feed\"") >= 0, "stage-clear active rewards should include special feed as an extra candidate")
	var gacha_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_gacha_transactions.gd")
	_expect(gacha_source.find("\"lingpet_special_feed\"") >= 0, "plaza gacha active-item candidates should include special feed")
	var shop_stock_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_shop_stock.gd")
	var shop_pricing_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_shop_pricing.gd")
	var shop_scene_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	_expect(shop_stock_source.find("\"lingpet_feed\"") >= 0 and shop_stock_source.find("\"lingpet_apple_feed\"") >= 0 and shop_stock_source.find("\"lingpet_melon_feed\"") >= 0 and shop_stock_source.find("\"lingpet_special_feed\"") >= 0, "plaza shop stock should guarantee every feed tier")
	_expect(shop_pricing_source.find("\"lingpet_feed\"") >= 0 and shop_pricing_source.find("\"lingpet_apple_feed\"") >= 0 and shop_pricing_source.find("\"lingpet_melon_feed\"") >= 0 and shop_pricing_source.find("\"lingpet_special_feed\"") >= 0, "plaza shop pricing should price every feed tier")
	_expect(shop_scene_source.find("_buy_active_shop_stock_item") >= 0, "plaza shop purchases should route active feed items into active slots")


func _complete_feed_item(
	runtime: Object,
	lingpet_runtime: Object,
	owner: Object,
	registry: Object,
	item_name: String
) -> void:
	_expect(runtime.grant_item_to_slot(item_name, owner, registry, false), "fixture should grant %s" % item_name)
	_clear_active_item_cooldown(runtime, owner)
	_expect(runtime.use_slot(0, owner, registry), "%s should apply before the battle cap" % item_name)
	_advance_feed_until_complete(lingpet_runtime, owner, registry)


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _clear_active_item_cooldown(runtime: Object, owner: Object) -> void:
	if runtime == null or runtime.slot_controller == null:
		return
	runtime.slot_controller.last_item_use_msec = -999999
	if owner == null:
		return
	for index in range(owner.active_item_slots.size()):
		var item_value: Variant = owner.active_item_slots[index]
		if item_value is Dictionary:
			var item_data: Dictionary = item_value
			item_data["last_use_msec"] = -999999
			item_data["last_use"] = -999999
			owner.active_item_slots[index] = item_data


func _advance_feed_until_complete(lingpet_runtime: Object, owner: Object, registry: Object) -> void:
	for _i in range(260):
		lingpet_runtime.update(1.0 / 60.0, owner, registry)
		if not bool(lingpet_runtime.get_snapshot().get("feed_bowl_active", false)):
			return
	_expect(false, "feed bowl active item animation should complete within the smoke time budget")


func _find_recycle_seed(required_successes: int) -> int:
	for candidate in range(1, 1000):
		seed(candidate)
		var success := true
		for _i in range(required_successes):
			if randf() >= 0.90:
				success = false
				break
		if success:
			return candidate
	return -1


func _apply_direct_effect(_item_data: Dictionary, _owner: Object, _registry: Object) -> bool:
	_direct_effect_calls += 1
	return true


func _cleanup_runtime(runtime: Object, registry: Object) -> void:
	if runtime != null and runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()
	if registry != null and registry.has_method("clear_refs"):
		registry.clear_refs()
	ProjectResourceLoader.clear_caches()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
