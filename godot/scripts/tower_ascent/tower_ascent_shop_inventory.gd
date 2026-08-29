extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemRaritySchema := preload(
	"res://scripts/items/active_item_rarity_schema.gd"
)
const LingpetItemOfferPolicy := preload(
	"res://scripts/lingpet/lingpet_item_offer_policy.gd"
)
const TowerAscentActiveItemAcquisitionPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_active_item_acquisition_policy.gd"
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

const INVENTORY_VERSION := "tower_shop_inventory_v4"
const REGULAR_STOCK_COUNT := 5
const PREMIUM_STOCK_COUNT := 1

var _catalog: Object = ActiveItemCatalog.new()
var _shelf_builder: Object = TowerAscentShopShelfBuilder.new()


func build_inventory(
	node_id: String,
	map_seed: int,
	owner: Object,
	registry: Object
) -> Dictionary:
	var normalized_node_id := node_id.strip_edges()
	if normalized_node_id.is_empty():
		return {"accepted": false, "reason": "invalid_node_id", "stock": []}
	var shelves: Dictionary = _shelf_builder.build_candidate_shelves(registry, owner)
	var regular_candidates := _dictionary_array(shelves.get("regular", []))
	var premium_candidates := _dictionary_array(shelves.get("premium", []))
	var capsule_candidates := _build_capsule_candidates(owner, registry)
	var missing_item_names := _collect_missing_active_item_prices(
		regular_candidates,
		premium_candidates,
		capsule_candidates
	)
	if not missing_item_names.is_empty():
		return {
			"accepted": false,
			"reason": "missing_active_item_price",
			"inventory_version": INVENTORY_VERSION,
			"node_id": normalized_node_id,
			"missing_item_names": missing_item_names,
			"stock": [],
		}
	if regular_candidates.size() < REGULAR_STOCK_COUNT:
		return {"accepted": false, "reason": "insufficient_regular_candidates", "stock": []}
	if premium_candidates.size() < PREMIUM_STOCK_COUNT:
		return {"accepted": false, "reason": "insufficient_premium_candidates", "stock": []}
	if capsule_candidates.is_empty():
		return {"accepted": false, "reason": "empty_capsule_pool", "stock": []}

	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%d:%s:%s" % [map_seed, normalized_node_id, INVENTORY_VERSION]))
	var stock: Array[Dictionary] = []
	for index in range(REGULAR_STOCK_COUNT):
		var regular := _take_candidate(regular_candidates, rng)
		stock.append(_item_stock(
			"regular_%d" % (index + 1),
			"regular",
			regular
		))
	var premium := _take_candidate(premium_candidates, rng)
	stock.append(_item_stock(
		"premium_1",
		"premium",
		premium
	))
	var capsule := _pick_weighted(capsule_candidates, rng)
	var capsule_stock := {
		"stock_id": "capsule_1",
		"kind": "capsule",
		"item_name": str(capsule.get("name", "")),
		"display_name": str(capsule.get("display_name", capsule.get("name", ""))),
		"rarity": ActiveItemRaritySchema.resolve_rarity(capsule),
		"price": TowerAscentTuning.TEMP_PHASE_C_SHOP_CAPSULE_PRICE,
		"sold": false,
	}
	capsule_stock.merge(_item_card_metadata(capsule), true)
	stock.append(capsule_stock)
	stock.append({
		"stock_id": "chance_gem_1",
		"kind": "chance_gem",
		"item_name": "chance_gem",
		"display_name": "기회의 보석",
		"rarity": "",
		"price": TowerAscentTuning.TEMP_PHASE_C_SHOP_CHANCE_GEM_PRICE,
		"sold": false,
	})
	return {
		"accepted": true,
		"reason": "generated",
		"inventory_version": INVENTORY_VERSION,
		"node_id": normalized_node_id,
		"stock": stock,
	}


func _build_capsule_candidates(owner: Object, registry: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_name_value in ActiveItemCatalog.FIELD_SPAWN_ORDER:
		var item_name := str(item_name_value)
		if not TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_ITEM,
			item_name
		):
			continue
		var item_data: Dictionary = _catalog.build_item_by_name(item_name)
		if item_data.is_empty() or str(item_data.get("type", "")) != "active":
			continue
		if not TowerAscentActiveItemAcquisitionPolicy.is_tower_acquisition_allowed(
			item_data,
			owner
		):
			continue
		if not LingpetItemOfferPolicy.can_offer_item(item_name, owner, registry):
			continue
		result.append(item_data)
	return result


func _take_candidate(candidates: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if candidates.is_empty():
		return {}
	var index := rng.randi_range(0, candidates.size() - 1)
	var result := candidates[index].duplicate(true)
	candidates.remove_at(index)
	return result


func _pick_weighted(candidates: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if candidates.is_empty():
		return {}
	var total_weight := 0.0
	for candidate in candidates:
		total_weight += maxf(0.0, float(candidate.get("chance", 0.0)))
	var roll := rng.randf() * maxf(0.001, total_weight)
	for candidate in candidates:
		roll -= maxf(0.0, float(candidate.get("chance", 0.0)))
		if roll <= 0.0:
			return candidate.duplicate(true)
	return candidates.back().duplicate(true)


func _item_stock(
	stock_id: String,
	kind: String,
	item_data: Dictionary
) -> Dictionary:
	var item_name := str(item_data.get("name", "")).strip_edges()
	var result := {
		"stock_id": stock_id,
		"kind": kind,
		"item_name": item_name,
		"display_name": str(item_data.get("display_name", item_data.get("name", ""))),
		"rarity": ActiveItemRaritySchema.resolve_rarity(item_data),
		"price": TowerAscentTuning.get_shop_active_item_gold_price(item_name),
		"sold": false,
	}
	result.merge(_item_card_metadata(item_data), true)
	return result


func _item_card_metadata(item_data: Dictionary) -> Dictionary:
	return {
		"description": str(item_data.get("description", "")),
		"icon_path": str(item_data.get("icon_path", "")),
		"icon_sheet_path": str(item_data.get("icon_sheet_path", "")),
		"icon_frame_count": maxi(1, int(item_data.get("icon_frame_count", 1))),
		"color": item_data.get("color", Color(0.78, 0.78, 0.78)),
	}


func _collect_missing_active_item_prices(
	regular_candidates: Array[Dictionary],
	premium_candidates: Array[Dictionary],
	capsule_candidates: Array[Dictionary]
) -> Array[String]:
	var missing: Array[String] = []
	for candidates in [regular_candidates, premium_candidates, capsule_candidates]:
		for candidate in candidates:
			var item_name := str(candidate.get("name", "")).strip_edges()
			if TowerAscentTuning.get_shop_active_item_gold_price(item_name) >= 0:
				continue
			if not missing.has(item_name):
				missing.append(item_name)
	missing.sort()
	return missing


func normalize_existing_inventory_prices(inventory: Dictionary) -> Dictionary:
	if not bool(inventory.get("accepted", true)):
		return {
			"accepted": false,
			"reason": str(inventory.get("reason", "shop_inventory_unavailable")),
			"missing_item_names": _string_array(inventory.get("missing_item_names", [])),
		}
	var missing_item_names: Array[String] = []
	var stock_values: Variant = inventory.get("stock", [])
	if not (stock_values is Array):
		return {
			"accepted": false,
			"reason": "invalid_shop_stock",
			"missing_item_names": [],
		}
	var stock_array := stock_values as Array
	for stock_value in stock_array:
		if not (stock_value is Dictionary):
			continue
		var stock := stock_value as Dictionary
		var stock_kind := str(stock.get("kind", ""))
		if stock_kind == "chance_gem":
			continue
		var item_name := str(stock.get("item_name", "")).strip_edges()
		if TowerAscentTuning.get_shop_active_item_gold_price(item_name) < 0:
			if not missing_item_names.has(item_name):
				missing_item_names.append(item_name)
	if not missing_item_names.is_empty():
		missing_item_names.sort()
		return {
			"accepted": false,
			"reason": "missing_active_item_price",
			"missing_item_names": missing_item_names,
		}
	for stock_index in range(stock_array.size()):
		var stock_value: Variant = stock_array[stock_index]
		if not (stock_value is Dictionary):
			continue
		var stock := stock_value as Dictionary
		match str(stock.get("kind", "")):
			"capsule":
				stock["price"] = TowerAscentTuning.TEMP_PHASE_C_SHOP_CAPSULE_PRICE
			"chance_gem":
				stock["price"] = TowerAscentTuning.TEMP_PHASE_C_SHOP_CHANCE_GEM_PRICE
			_:
				stock["price"] = TowerAscentTuning.get_shop_active_item_gold_price(
					str(stock.get("item_name", ""))
				)
		stock_array[stock_index] = stock
	inventory["stock"] = stock_array
	inventory["inventory_version"] = INVENTORY_VERSION
	return {
		"accepted": true,
		"reason": "canonical_prices",
		"missing_item_names": [],
	}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value as Array:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result
