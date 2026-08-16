extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PlazaShopPricing := preload("res://scripts/plaza/plaza_shop_pricing.gd")
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

const MIN_STOCK_COUNT := 5
const MAX_STOCK_COUNT := 12
const LEGENDARY_ROLL_CHANCE := 0.05
const FEATURED_DISCOUNT_RATE := 0.20
const FEATURED_COUNT := 2
const GUARANTEED_ACTIVE_ITEM_NAMES: Array[String] = []


func build_inventory(
	catalog: Object = null,
	item_count: int = -1,
	seed: int = 0,
	registry: Object = null
) -> Array:
	var source_catalog := catalog if catalog != null else MythicItemCatalog.new()
	var active_catalog := ActiveItemCatalog.new()
	var passive_pool := _build_pool(source_catalog, false, registry)
	var legendary_pool := _build_pool(source_catalog, true, registry)
	var count := item_count
	if count < 0:
		count = randi_range(MIN_STOCK_COUNT, MAX_STOCK_COUNT)
	count = clampi(count, MIN_STOCK_COUNT, MAX_STOCK_COUNT)
	var rng := RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	var stock: Array = []
	_append_guaranteed_active_stock(stock, active_catalog, registry)
	var available_legendary := legendary_pool.duplicate()
	var random_slots := maxi(0, count - stock.size())
	for _index in range(random_slots):
		var choose_legendary := not available_legendary.is_empty() and rng.randf() < LEGENDARY_ROLL_CHANCE
		var item_name := ""
		if choose_legendary:
			var legendary_index := rng.randi_range(0, available_legendary.size() - 1)
			item_name = str(available_legendary[legendary_index])
			available_legendary.remove_at(legendary_index)
		elif not passive_pool.is_empty():
			item_name = str(passive_pool[rng.randi_range(0, passive_pool.size() - 1)])
		elif not available_legendary.is_empty():
			item_name = str(available_legendary.pop_back())
		var item_data := _build_shop_item(source_catalog, item_name, stock.size())
		if not item_data.is_empty():
			stock.append(item_data)
	_apply_featured_discount(stock, rng)
	return stock


func _append_guaranteed_active_stock(
	stock: Array,
	active_catalog: Object,
	registry: Object
) -> void:
	for item_name_value in GUARANTEED_ACTIVE_ITEM_NAMES:
		var item_name := str(item_name_value)
		if not TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_ITEM,
			item_name
		):
			continue
		if not PlazaShopPricing.is_shop_priced_item(item_name):
			continue
		var item_data := _build_shop_item(active_catalog, item_name, stock.size())
		if not item_data.is_empty():
			stock.append(item_data)


func _build_pool(catalog: Object, legendary: bool, registry: Object) -> Array:
	var result: Array = []
	if PerkConversionFlags.is_enabled():
		return result
	for item_name_value in MythicItemCatalog.FIELD_SPAWN_ORDER:
		var item_name := str(item_name_value)
		if not TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_ITEM,
			item_name
		):
			continue
		if not PlazaShopPricing.is_shop_priced_item(item_name):
			continue
		if PlazaShopPricing.is_legacy_legendary(item_name) != legendary:
			continue
		if catalog == null or not catalog.has_method("build_item_by_name"):
			continue
		var item_data: Variant = catalog.build_item_by_name(item_name)
		if item_data is Dictionary and not (item_data as Dictionary).is_empty():
			result.append(item_name)
	return result


func _build_shop_item(catalog: Object, item_name: String, index: int) -> Dictionary:
	if item_name == "" or catalog == null or not catalog.has_method("build_item_by_name"):
		return {}
	var item_value: Variant = catalog.build_item_by_name(item_name)
	if not (item_value is Dictionary):
		return {}
	var item_data: Dictionary = (item_value as Dictionary).duplicate(true)
	if item_data.is_empty():
		return {}
	if catalog.has_method("build_random_rolls"):
		var rolls_value: Variant = catalog.build_random_rolls(item_name)
		if rolls_value is Dictionary:
			item_data["rolls"] = (rolls_value as Dictionary).duplicate(true)
	if catalog.has_method("sync_roll_fields"):
		var synced_value: Variant = catalog.sync_roll_fields(item_data, false)
		if synced_value is Dictionary:
			item_data = (synced_value as Dictionary).duplicate(true)
	var base_price := PlazaShopPricing.get_base_price(item_name)
	var price := PlazaShopPricing.get_buy_price(item_data)
	if catalog.has_method("get_icon_path"):
		item_data["icon_path"] = str(catalog.get_icon_path(item_name))
	if catalog.has_method("get_icon_sheet_path"):
		item_data["icon_sheet_path"] = str(catalog.get_icon_sheet_path(item_name))
	item_data["shop_stock_id"] = "shop_stock_%02d_%s" % [index, item_name]
	item_data["shop_base_price"] = base_price
	item_data["shop_original_price"] = price
	item_data["shop_price"] = price
	item_data["shop_sell_price"] = PlazaShopPricing.get_sell_price(item_data)
	item_data["shop_featured"] = false
	item_data["shop_discount_rate"] = 0.0
	return item_data


func _apply_featured_discount(stock: Array, rng: RandomNumberGenerator) -> void:
	if stock.is_empty():
		return
	var indices: Array[int] = []
	for index in range(stock.size()):
		indices.append(index)
	for _count in range(mini(FEATURED_COUNT, indices.size())):
		var pick := rng.randi_range(0, indices.size() - 1)
		var stock_index := int(indices[pick])
		indices.remove_at(pick)
		var item_data := _get_dict(stock[stock_index]).duplicate(true)
		if item_data.is_empty():
			continue
		var original_price := maxi(1, int(item_data.get("shop_original_price", item_data.get("shop_price", 1))))
		item_data["shop_featured"] = true
		item_data["shop_discount_rate"] = FEATURED_DISCOUNT_RATE
		item_data["shop_original_price"] = original_price
		item_data["shop_price"] = maxi(1, int(round(float(original_price) * (1.0 - FEATURED_DISCOUNT_RATE))))
		stock[stock_index] = item_data


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
