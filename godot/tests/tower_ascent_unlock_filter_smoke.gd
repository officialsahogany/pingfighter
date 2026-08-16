extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentUnlockStore := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_store.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)
const ActiveItemFieldSpawnPool := preload(
	"res://scripts/items/active_item_field_spawn_pool.gd"
)
const StageClearRewardResolver := preload(
	"res://scripts/core/stage_clear_reward_resolver.gd"
)
const PlazaGachaTransactions := preload(
	"res://scripts/plaza/plaza_gacha_transactions.gd"
)
const PlazaShopStock := preload(
	"res://scripts/plaza/plaza_shop_stock.gd"
)
const MythicItemCatalog := preload(
	"res://scripts/items/mythic_item_catalog.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const MythicPerkGrantHelper := preload(
	"res://scripts/characters/mythic_perk_grant_helper.gd"
)

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	var save_path := "user://tower_ascent_unlock_filter_%d.cfg" % Time.get_ticks_usec()
	var store := TowerAscentUnlockStore.new()
	store.set_save_path(save_path)
	_expect(store.clear(), "unlock-store fixture must start from an isolated save")
	_verify_default_all_unlocked_and_persistence(store, save_path)
	var registry := FakeRegistry.new()
	registry.instances[TowerAscentUnlockFilter.STORE_KEY] = store
	_verify_single_filter_flag_contract(store, registry)
	_verify_item_consumers_share_filter(store, registry)
	_verify_runtime_perk_consumers_share_filter(store, registry)
	_verify_registration_and_connection_sources()
	_expect(store.clear(), "unlock-store fixture must remove its isolated save")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_unlock_filter_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_default_all_unlocked_and_persistence(store: Object, save_path: String) -> void:
	_expect(store.is_unlocked("item", "gauge_charge"), "missing save must default every existing item to unlocked")
	_expect(store.set_default_unlocked(false), "test fixture must be able to enable restricted-pool mode")
	_expect(store.set_unlocked("item", "gauge_charge", true), "item unlock must persist immediately")
	_expect(store.set_unlocked("item", "speedboots", true), "shop item unlock must persist immediately")
	_expect(store.set_unlocked("runtime_perk", "item_luck", true), "runtime perk unlock must persist immediately")
	var restored := TowerAscentUnlockStore.new()
	restored.set_save_path(save_path)
	_expect(restored.load(), "unlock store must load its own schema-versioned save")
	_expect(restored.is_unlocked("item", "gauge_charge"), "persisted item unlock must survive a fresh store instance")
	_expect(not restored.is_unlocked("item", "life_elixir"), "unlisted item must stay locked in restricted-pool mode")
	_expect(restored.is_unlocked("runtime_perk", "item_luck"), "persisted perk unlock must survive a fresh store instance")


func _verify_single_filter_flag_contract(store: Object, registry: Object) -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	_expect(TowerAscentUnlockFilter.is_content_unlocked(
		registry,
		TowerAscentUnlockFilter.CONTENT_ITEM,
		"life_elixir"
	), "flag OFF must bypass the new store and preserve every legacy acquisition pool")
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_expect(not TowerAscentUnlockFilter.is_content_unlocked(
		registry,
		TowerAscentUnlockFilter.CONTENT_ITEM,
		"life_elixir"
	), "flag ON must enforce the independent Godot unlock store")
	_expect(not TowerAscentUnlockFilter.is_content_unlocked(
		null,
		TowerAscentUnlockFilter.CONTENT_ITEM,
		"gauge_charge"
	), "flag ON without the registered store must fail closed")
	_expect(store.get_summary().default_unlocked == false, "restricted fixture must not mutate the store default implicitly")


func _verify_item_consumers_share_filter(store: Object, registry: Object) -> void:
	var allowed_items := {"gauge_charge": true, "speedboots": true}
	var spawn_candidates: Array = ActiveItemFieldSpawnPool.new().build_spawn_candidates(registry)
	_expect(not spawn_candidates.is_empty(), "field spawn pool must retain explicitly unlocked items")
	_expect(_all_entry_ids_allowed(spawn_candidates, "name", allowed_items), "field spawn pool must exclude every locked item")

	var chest_candidates_value: Variant = StageClearRewardResolver.new().call(
		"_build_candidates_for_group",
		"active",
		null,
		registry
	)
	var chest_candidates: Array = chest_candidates_value if chest_candidates_value is Array else []
	_expect(not chest_candidates.is_empty(), "normal chest active lane must retain the unlocked field candidate")
	_expect(_all_entry_ids_allowed(chest_candidates, "name", allowed_items), "normal chest candidates must share the item filter")

	var gacha := PlazaGachaTransactions.new()
	gacha.force_next_item_for_test("life_elixir")
	var pulled_value: Variant = gacha.call("_pick_active_item", null, registry)
	var pulled: Dictionary = pulled_value if pulled_value is Dictionary else {}
	_expect(str(pulled.get("name", "")) == "gauge_charge", "gacha must reject a forced locked item and fall back inside the unlocked pool")

	var shop_stock := PlazaShopStock.new().build_inventory(
		MythicItemCatalog.new(),
		5,
		17017,
		registry
	)
	_expect(not shop_stock.is_empty(), "shop must retain an explicitly unlocked priced item")
	_expect(_all_entry_ids_allowed(shop_stock, "name", {"speedboots": true}), "shop stock must exclude every locked priced item")
	_expect(store.is_unlocked("item", "speedboots"), "shop verification must use the persisted store, not a test-only pool")


func _verify_runtime_perk_consumers_share_filter(store: Object, registry: Object) -> void:
	var catalog := RuntimePerkCatalog.new()
	var choices_value: Variant = catalog.get_choices("smasher", {}, true, 3, null, registry)
	var choices: Array = choices_value if choices_value is Array else []
	_expect(not choices.is_empty(), "runtime perk offer must retain the explicitly unlocked perk")
	_expect(_all_entry_ids_allowed(choices, "id", {"item_luck": true}), "runtime perk and academy-style offers must exclude locked perks")
	var mythic_before: Array[String] = MythicPerkGrantHelper.get_available_mythic_perk_ids(
		null,
		registry,
		catalog
	)
	_expect(mythic_before.is_empty(), "mythic chest helper must expose no locked mythic perk")
	_expect(store.set_unlocked("runtime_perk", "megingjord", true), "mythic perk unlock must commit immediately")
	var mythic_after: Array[String] = MythicPerkGrantHelper.get_available_mythic_perk_ids(
		null,
		registry,
		catalog
	)
	_expect(mythic_after == ["megingjord"], "mythic chest helper must use the same runtime-perk filter")


func _verify_registration_and_connection_sources() -> void:
	var module_source := FileAccess.get_file_as_string(
		"res://scripts/resources/gameplay_core_module_catalog.gd"
	)
	var plaza_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	_expect(module_source.find('"tower_ascent_unlock_store"') >= 0, "production registry must instantiate the independent unlock store")
	_expect(plaza_source.find("build_inventory(catalog, -1, 0, _runtime_registry)") >= 0, "production plaza shop must pass the live registry into the shared filter")


func _all_entry_ids_allowed(entries: Array, id_key: String, allowed: Dictionary) -> bool:
	for entry_value in entries:
		if not (entry_value is Dictionary):
			return false
		var entry := entry_value as Dictionary
		if not allowed.has(str(entry.get(id_key, ""))):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
