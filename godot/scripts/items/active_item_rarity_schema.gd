extends RefCounted

const RARITY_COMMON := "common"
const RARITY_RARE := "rare"
const RARITY_LEGENDARY := "legendary"
const RARITY_MYTHIC := "mythic"
const VALID_RARITIES := [
	RARITY_COMMON,
	RARITY_RARE,
	RARITY_LEGENDARY,
	RARITY_MYTHIC,
]


static func normalize_item_data(item_data: Dictionary) -> Dictionary:
	if item_data.is_empty():
		return {}
	var result := item_data.duplicate(true)
	result["rarity"] = resolve_rarity(result)
	return result


static func resolve_rarity(item_data: Dictionary) -> String:
	var explicit := str(item_data.get("rarity", "")).strip_edges().to_lower()
	if VALID_RARITIES.has(explicit):
		return explicit
	var item_type := str(item_data.get("type", "")).strip_edges().to_lower()
	if bool(item_data.get("mythic_active", false)) or item_type == RARITY_MYTHIC:
		return RARITY_MYTHIC
	if item_type == RARITY_LEGENDARY:
		return RARITY_LEGENDARY
	return RARITY_COMMON


static func has_valid_rarity(item_data: Dictionary) -> bool:
	return VALID_RARITIES.has(
		str(item_data.get("rarity", "")).strip_edges().to_lower()
	)
