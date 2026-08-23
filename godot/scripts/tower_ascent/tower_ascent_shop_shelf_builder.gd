extends RefCounted

const ActiveItemCatalog := preload(
	"res://scripts/items/active_item_catalog.gd"
)
const LingpetItemOfferPolicy := preload(
	"res://scripts/lingpet/lingpet_item_offer_policy.gd"
)
const TowerAscentActiveItemAcquisitionPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_active_item_acquisition_policy.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

var _catalog: Object = ActiveItemCatalog.new()


func build_candidate_shelves(registry: Object = null, owner: Object = null) -> Dictionary:
	var all_candidates: Array[Dictionary] = []
	for item_name_value in ActiveItemCatalog.CATALOG_ORDER:
		var item_name := str(item_name_value)
		if not TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_ITEM,
			item_name
		):
			continue
		var item_data: Dictionary = _catalog.build_item_by_name(item_name)
		if item_data.is_empty():
			continue
		if bool(item_data.get("lingpet_generated_only", false)):
			continue
		if not LingpetItemOfferPolicy.can_offer_item(item_name, owner, registry):
			continue
		all_candidates.append(item_data)
	return {
		"regular": TowerAscentActiveItemAcquisitionPolicy.filter_candidates(
			all_candidates,
			TowerAscentActiveItemAcquisitionPolicy.CHANNEL_SHOP_REGULAR,
			owner
		),
		"premium": TowerAscentActiveItemAcquisitionPolicy.filter_candidates(
			all_candidates,
			TowerAscentActiveItemAcquisitionPolicy.CHANNEL_SHOP_PREMIUM,
			owner
		),
	}
