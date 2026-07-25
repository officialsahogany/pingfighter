extends RefCounted

const PlazaShopPricing := preload("res://scripts/plaza/plaza_shop_pricing.gd")
const PlazaTradeItemPresentation := preload("res://scripts/plaza/plaza_trade_item_presentation.gd")

var _items: Array = []


func replace(items: Variant) -> void:
	_items = _duplicate_dictionary_array(items)


func clear() -> void:
	_items.clear()


func size() -> int:
	return _items.size()


func snapshot() -> Array:
	return _duplicate_dictionary_array(_items)


func get_item(index: int) -> Dictionary:
	if index < 0 or index >= _items.size():
		return {}
	return _get_dict(_items[index]).duplicate(true)


func find_stock_index(stock_id: String) -> int:
	if stock_id == "":
		return -1
	for index in range(_items.size()):
		if str(_get_dict(_items[index]).get("shop_stock_id", "")) == stock_id:
			return index
	return -1


func remove_at(index: int) -> bool:
	if index < 0 or index >= _items.size():
		return false
	_items.remove_at(index)
	return true


func reorder(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= _items.size() or _items.is_empty():
		return false
	var insert_index := clampi(to_index, 0, _items.size() - 1)
	if from_index == insert_index:
		return false
	var item: Variant = _items[from_index]
	_items.remove_at(from_index)
	insert_index = clampi(insert_index, 0, _items.size())
	_items.insert(insert_index, item)
	return true


func relist(item_data: Dictionary) -> bool:
	var relisted := item_data.duplicate(true)
	var item_name := PlazaTradeItemPresentation.get_item_identity(relisted)
	if item_name == "":
		return false
	var buy_price := PlazaShopPricing.get_buy_price(relisted)
	relisted["shop_stock_id"] = "shop_resale_%02d_%s" % [_items.size(), item_name]
	relisted["shop_base_price"] = PlazaShopPricing.get_base_price(item_name)
	relisted["shop_original_price"] = buy_price
	relisted["shop_price"] = buy_price
	relisted["shop_sell_price"] = PlazaShopPricing.get_sell_price(relisted)
	relisted["shop_featured"] = false
	relisted["shop_discount_rate"] = 0.0
	_items.append(relisted)
	return true


static func _duplicate_dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item_value in value as Array:
		if item_value is Dictionary:
			result.append((item_value as Dictionary).duplicate(true))
	return result


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
