extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PlazaShopPricing := preload("res://scripts/plaza/plaza_shop_pricing.gd")
const PlazaShopStock := preload("res://scripts/plaza/plaza_shop_stock.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)
const TowerAscentUnlockStore := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_store.gd"
)

const ON_STOCK_SEED := 17017
const STOCK_COUNT := 12
const OFF_STOCK_SEED_SCAN_LIMIT := 512

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	var save_path := "user://perk_conversion_shop_stock_%d.cfg" % Time.get_ticks_usec()
	var unlock_store := TowerAscentUnlockStore.new()
	unlock_store.set_save_path(save_path)
	_expect(unlock_store.clear(), "unlock-store fixture must start from an isolated save")
	var registry := FakeRegistry.new()
	registry.instances[TowerAscentUnlockFilter.STORE_KEY] = unlock_store
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	PerkConversionFlags.debug_set_enabled(false)

	_verify_guaranteed_active_contract()
	_verify_flag_off_legacy_stock_remains(registry)
	_verify_flag_on_legacy_stock_is_removed(registry)
	_verify_locked_guaranteed_active_is_excluded(registry, unlock_store)

	PerkConversionFlags.debug_set_enabled(false)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	_expect(unlock_store.clear(), "unlock-store fixture must remove its isolated save")
	if _failures.is_empty():
		print("perk_conversion_shop_stock_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_guaranteed_active_contract() -> void:
	_expect(not PlazaShopStock.GUARANTEED_ACTIVE_ITEM_NAMES.is_empty(), "plaza shop must configure at least one guaranteed active item")
	_expect(PlazaShopStock.GUARANTEED_ACTIVE_ITEM_NAMES == ["wall", "boomerang"], "plaza shop should retain its original wall and boomerang active products")
	_expect(PlazaShopPricing.get_base_price("wall") == 80, "wall should retain its original 80G plaza price")
	_expect(PlazaShopPricing.get_base_price("boomerang") == 120, "boomerang should retain its original 120G plaza price")


func _verify_flag_off_legacy_stock_remains(registry: Object) -> void:
	var catalog := MythicItemCatalog.new()
	var stock_builder := PlazaShopStock.new()

	PerkConversionFlags.debug_set_enabled(false)
	_expect(not stock_builder._build_pool(catalog, false, registry).is_empty(), "flag-OFF plaza shop passive pool should stay populated")
	_expect(not stock_builder._build_pool(catalog, true, registry).is_empty(), "flag-OFF plaza shop legendary pool should stay populated")

	var stock: Array = _build_off_stock_with_legacy_mix(stock_builder, catalog, registry)
	var counts := _count_stock_groups(stock)
	_expect(stock.size() == STOCK_COUNT, "flag-OFF plaza shop should keep the requested stock count")
	_expect(int(counts.get("active", 0)) > 0, "flag-OFF plaza shop should include guaranteed active stock")
	_expect(_stock_has_all_guaranteed_active(stock), "flag-OFF plaza shop should preserve every configured guaranteed active entry")
	_expect(int(counts.get("passive", 0)) > 0, "flag-OFF plaza shop should still sell passive items")
	_expect(int(counts.get("legendary", 0)) > 0, "flag-OFF plaza shop should still sell legendary items")


func _verify_flag_on_legacy_stock_is_removed(registry: Object) -> void:
	var catalog := MythicItemCatalog.new()
	var stock_builder := PlazaShopStock.new()

	PerkConversionFlags.debug_set_enabled(true)
	_expect(stock_builder._build_pool(catalog, false, registry).is_empty(), "flag-ON plaza shop passive pool should be empty")
	_expect(stock_builder._build_pool(catalog, true, registry).is_empty(), "flag-ON plaza shop legendary pool should be empty")

	var stock: Array = stock_builder.build_inventory(catalog, STOCK_COUNT, ON_STOCK_SEED, registry)
	var counts := _count_stock_groups(stock)
	_expect(not stock.is_empty(), "flag-ON plaza shop should still return guaranteed active stock")
	_expect(stock.size() == PlazaShopStock.GUARANTEED_ACTIVE_ITEM_NAMES.size(), "flag-ON plaza shop should contain exactly the configured guaranteed active stock")
	_expect(int(counts.get("active", 0)) == stock.size(), "flag-ON plaza shop stock should be active-only")
	_expect(int(counts.get("passive", 0)) == 0, "flag-ON plaza shop should remove passive stock")
	_expect(int(counts.get("legendary", 0)) == 0, "flag-ON plaza shop should remove legendary stock")
	_expect(_stock_has_all_guaranteed_active(stock), "flag-ON plaza shop should preserve all guaranteed active feed entries")
	_expect(_featured_discount_is_valid(stock), "flag-ON plaza shop featured discount should handle the small active-only stock")


func _verify_locked_guaranteed_active_is_excluded(
	registry: Object,
	unlock_store: Object
) -> void:
	var locked_item_name := str(PlazaShopStock.GUARANTEED_ACTIVE_ITEM_NAMES[0])
	_expect(
		bool(unlock_store.set_unlocked(TowerAscentUnlockFilter.CONTENT_ITEM, locked_item_name, false)),
		"unlock-store fixture should lock one guaranteed active item"
	)
	PerkConversionFlags.debug_set_enabled(true)
	var stock: Array = PlazaShopStock.new().build_inventory(
		MythicItemCatalog.new(),
		STOCK_COUNT,
		ON_STOCK_SEED,
		registry
	)
	_expect(not _stock_has_item(stock, locked_item_name), "locked guaranteed active content should be excluded from plaza shop stock")
	_expect(stock.size() == PlazaShopStock.GUARANTEED_ACTIVE_ITEM_NAMES.size() - 1, "locking one guaranteed active item should preserve the remaining unlocked stock")
	_expect(
		bool(unlock_store.set_unlocked(TowerAscentUnlockFilter.CONTENT_ITEM, locked_item_name, true)),
		"unlock-store fixture should restore the locked guaranteed active item"
	)


func _count_stock_groups(stock: Array) -> Dictionary:
	var counts := {
		"active": 0,
		"passive": 0,
		"legendary": 0,
	}
	for item_value in stock:
		var item_data := _get_dict(item_value)
		var item_name := str(item_data.get("name", ""))
		var group := _get_stock_group(item_name)
		counts[group] = int(counts.get(group, 0)) + 1
	return counts


func _build_off_stock_with_legacy_mix(
	stock_builder: Object,
	catalog: Object,
	registry: Object
) -> Array:
	for seed in range(1, OFF_STOCK_SEED_SCAN_LIMIT + 1):
		var stock: Array = stock_builder.build_inventory(catalog, STOCK_COUNT, seed, registry)
		var counts := _count_stock_groups(stock)
		if int(counts.get("passive", 0)) > 0 and int(counts.get("legendary", 0)) > 0:
			return stock
	_expect(false, "flag-OFF plaza shop fixed seed scan should find passive and legendary stock")
	return stock_builder.build_inventory(catalog, STOCK_COUNT, 1, registry)


func _get_stock_group(item_name: String) -> String:
	if PlazaShopPricing.ACTIVE_BASE_PRICES.has(item_name):
		return "active"
	if PlazaShopPricing.is_legacy_legendary(item_name):
		return "legendary"
	return "passive"


func _stock_has_all_guaranteed_active(stock: Array) -> bool:
	var seen: Dictionary = {}
	for item_value in stock:
		var item_data := _get_dict(item_value)
		seen[str(item_data.get("name", ""))] = true
	for item_name_value in PlazaShopStock.GUARANTEED_ACTIVE_ITEM_NAMES:
		if not bool(seen.get(str(item_name_value), false)):
			return false
	return true


func _stock_has_item(stock: Array, item_name: String) -> bool:
	for item_value in stock:
		if str(_get_dict(item_value).get("name", "")) == item_name:
			return true
	return false


func _featured_discount_is_valid(stock: Array) -> bool:
	var featured_count := 0
	for item_value in stock:
		var item_data := _get_dict(item_value)
		var item_name := str(item_data.get("name", ""))
		if item_name == "" or not PlazaShopPricing.is_shop_priced_item(item_name):
			return false
		if not str(item_data.get("icon_path", "")).begins_with("res://"):
			return false
		if bool(item_data.get("shop_featured", false)):
			featured_count += 1
			if int(item_data.get("shop_price", 0)) >= int(item_data.get("shop_original_price", 0)):
				return false
	return featured_count == mini(PlazaShopStock.FEATURED_COUNT, stock.size())


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
