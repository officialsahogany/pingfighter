extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PlazaShopPricing := preload("res://scripts/plaza/plaza_shop_pricing.gd")
const PlazaShopStock := preload("res://scripts/plaza/plaza_shop_stock.gd")

const ON_STOCK_SEED := 17017
const STOCK_COUNT := 12
const OFF_STOCK_SEED_SCAN_LIMIT := 512

var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)

	_verify_flag_off_legacy_stock_remains()
	_verify_flag_on_legacy_stock_is_removed()

	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("perk_conversion_shop_stock_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_flag_off_legacy_stock_remains() -> void:
	var catalog := MythicItemCatalog.new()
	var stock_builder := PlazaShopStock.new()

	PerkConversionFlags.debug_set_enabled(false)
	_expect(not stock_builder._build_pool(catalog, false).is_empty(), "flag-OFF plaza shop passive pool should stay populated")
	_expect(not stock_builder._build_pool(catalog, true).is_empty(), "flag-OFF plaza shop legendary pool should stay populated")

	var stock: Array = _build_off_stock_with_legacy_mix(stock_builder, catalog)
	var counts := _count_stock_groups(stock)
	_expect(stock.size() == STOCK_COUNT, "flag-OFF plaza shop should keep the requested stock count")
	_expect(int(counts.get("active", 0)) > 0, "flag-OFF plaza shop should include guaranteed active feed")
	_expect(int(counts.get("passive", 0)) > 0, "flag-OFF plaza shop should still sell passive items")
	_expect(int(counts.get("legendary", 0)) > 0, "flag-OFF plaza shop should still sell legendary items")


func _verify_flag_on_legacy_stock_is_removed() -> void:
	var catalog := MythicItemCatalog.new()
	var stock_builder := PlazaShopStock.new()

	PerkConversionFlags.debug_set_enabled(true)
	_expect(stock_builder._build_pool(catalog, false).is_empty(), "flag-ON plaza shop passive pool should be empty")
	_expect(stock_builder._build_pool(catalog, true).is_empty(), "flag-ON plaza shop legendary pool should be empty")

	var stock: Array = stock_builder.build_inventory(catalog, STOCK_COUNT, ON_STOCK_SEED)
	var counts := _count_stock_groups(stock)
	_expect(not stock.is_empty(), "flag-ON plaza shop should still return guaranteed active stock")
	_expect(stock.size() == PlazaShopStock.GUARANTEED_ACTIVE_ITEM_NAMES.size(), "flag-ON plaza shop should only contain guaranteed active feed")
	_expect(int(counts.get("active", 0)) == stock.size(), "flag-ON plaza shop stock should be active-only")
	_expect(int(counts.get("passive", 0)) == 0, "flag-ON plaza shop should remove passive stock")
	_expect(int(counts.get("legendary", 0)) == 0, "flag-ON plaza shop should remove legendary stock")
	_expect(_stock_has_all_guaranteed_active(stock), "flag-ON plaza shop should preserve all guaranteed active feed entries")
	_expect(_featured_discount_is_valid(stock), "flag-ON plaza shop featured discount should handle the small active-only stock")


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


func _build_off_stock_with_legacy_mix(stock_builder: Object, catalog: Object) -> Array:
	for seed in range(1, OFF_STOCK_SEED_SCAN_LIMIT + 1):
		var stock: Array = stock_builder.build_inventory(catalog, STOCK_COUNT, seed)
		var counts := _count_stock_groups(stock)
		if int(counts.get("passive", 0)) > 0 and int(counts.get("legendary", 0)) > 0:
			return stock
	_expect(false, "flag-OFF plaza shop fixed seed scan should find passive and legendary stock")
	return stock_builder.build_inventory(catalog, STOCK_COUNT, 1)


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
