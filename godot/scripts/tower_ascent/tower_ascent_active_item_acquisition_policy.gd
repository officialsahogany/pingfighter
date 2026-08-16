extends RefCounted

const ActiveItemRaritySchema := preload(
	"res://scripts/items/active_item_rarity_schema.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const CHANNEL_FIELD_SPAWN := "field_spawn"
const CHANNEL_NORMAL_CHEST := "normal_chest"
const CHANNEL_SHOP_REGULAR := "shop_regular"
const CHANNEL_SHOP_PREMIUM := "shop_premium"


static func is_allowed(item_data: Dictionary, channel: String) -> bool:
	if str(item_data.get("type", "")).strip_edges().to_lower() != "active":
		return false
	return get_allowed_rarities(channel).has(
		ActiveItemRaritySchema.resolve_rarity(item_data)
	)


static func filter_candidates(candidates: Array, channel: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate := candidate_value as Dictionary
		if is_allowed(candidate, channel):
			result.append(candidate.duplicate(true))
	return result


static func get_allowed_rarities(channel: String) -> Array:
	match channel:
		CHANNEL_FIELD_SPAWN:
			return TowerAscentTuning.TEMP_FIELD_ACTIVE_RARITIES
		CHANNEL_NORMAL_CHEST:
			return TowerAscentTuning.TEMP_NORMAL_CHEST_ACTIVE_RARITIES
		CHANNEL_SHOP_REGULAR:
			return TowerAscentTuning.TEMP_SHOP_REGULAR_ACTIVE_RARITIES
		CHANNEL_SHOP_PREMIUM:
			return TowerAscentTuning.TEMP_SHOP_PREMIUM_ACTIVE_RARITIES
	return []
