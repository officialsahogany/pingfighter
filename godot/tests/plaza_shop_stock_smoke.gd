extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const PlazaShopPricing := preload("res://scripts/plaza/plaza_shop_pricing.gd")
const PlazaShopStock := preload("res://scripts/plaza/plaza_shop_stock.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_verify_price_table_samples()
	_verify_stock_roll_shape()
	if _failures.is_empty():
		print("plaza_shop_stock_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_price_table_samples() -> void:
	_expect(PlazaShopPricing.get_base_price("speedboots") == 750, "speedboots should keep the legacy shop base price")
	_expect(PlazaShopPricing.get_base_price("ragnarok_hammer") == 3600, "ragnarok_hammer should keep the legacy shop base price")
	_expect(PlazaShopPricing.get_base_price("transcendent_crown") == 4560, "transcendent_crown should keep the legacy shop base price")
	_expect(PlazaShopPricing.get_sell_price({"name": "gold_bar"}) == PlazaShopPricing.GOLD_BAR_SELL_PRICE, "gold_bar should keep the fixed legacy sell price")
	_expect(PlazaShopPricing.is_shop_priced_item("gold_digger") == false, "items outside the legacy shop table should not enter the plaza shop pool")


func _verify_stock_roll_shape() -> void:
	var catalog := MythicItemCatalog.new()
	var stock_builder := PlazaShopStock.new()
	var stock: Array = stock_builder.build_inventory(catalog, 12, 17017)
	_expect(stock.size() == 12, "shop stock override should build the requested item count")
	var featured_count := 0
	var legendary_seen: Dictionary = {}
	var item_names_seen: Dictionary = {}
	for item_value in stock:
		_expect(item_value is Dictionary, "shop stock entries should be dictionaries")
		if not (item_value is Dictionary):
			continue
		var item_data: Dictionary = item_value
		var item_name := str(item_data.get("name", ""))
		item_names_seen[item_name] = true
		_expect(PlazaShopPricing.is_shop_priced_item(item_name), "shop stock item %s should belong to the priced implemented pool" % item_name)
		_expect(str(item_data.get("shop_stock_id", "")) != "", "shop stock item %s should have a stable stock id" % item_name)
		_expect(int(item_data.get("shop_base_price", 0)) == PlazaShopPricing.get_base_price(item_name), "shop stock item %s should carry its base price" % item_name)
		_expect(int(item_data.get("shop_price", 0)) > 0, "shop stock item %s should carry a positive buy price" % item_name)
		var icon_path := str(item_data.get("icon_path", ""))
		_expect(icon_path.begins_with("res://"), "shop stock item %s should carry a res:// icon path" % item_name)
		_expect(ResourceLoader.exists(icon_path), "shop stock icon path should exist for %s" % item_name)
		if bool(item_data.get("shop_featured", false)):
			featured_count += 1
			_expect(int(item_data.get("shop_price", 0)) < int(item_data.get("shop_original_price", 0)), "featured stock item %s should be discounted" % item_name)
		if PlazaShopPricing.is_legacy_legendary(item_name):
			_expect(not bool(legendary_seen.get(item_name, false)), "legendary shop stock item %s should not duplicate in one roll" % item_name)
			legendary_seen[item_name] = true
	_expect(featured_count == 2, "shop stock should mark two featured sale items")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
