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

const INVENTORY_VERSION := "tower_shop_inventory_v1"
const REGULAR_STOCK_COUNT := 3
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
			regular,
			TowerAscentTuning.TEMP_PHASE_C_SHOP_COMMON_ACTIVE_PRICE
		))
	var premium := _take_candidate(premium_candidates, rng)
	stock.append(_item_stock(
		"premium_1",
		"premium",
		premium,
		_premium_price(premium)
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
		if not TowerAscentActiveItemAcquisitionPolicy.is_character_allowed(item_data, owner):
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
	item_data: Dictionary,
	price: int
) -> Dictionary:
	var result := {
		"stock_id": stock_id,
		"kind": kind,
		"item_name": str(item_data.get("name", "")),
		"display_name": str(item_data.get("display_name", item_data.get("name", ""))),
		"rarity": ActiveItemRaritySchema.resolve_rarity(item_data),
		"price": maxi(0, price),
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


func _premium_price(item_data: Dictionary) -> int:
	if ActiveItemRaritySchema.resolve_rarity(item_data) == ActiveItemRaritySchema.RARITY_LEGENDARY:
		return TowerAscentTuning.TEMP_PHASE_C_SHOP_LEGENDARY_ACTIVE_PRICE
	return TowerAscentTuning.TEMP_PHASE_C_SHOP_MYTHIC_ACTIVE_PRICE


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value as Array:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result
