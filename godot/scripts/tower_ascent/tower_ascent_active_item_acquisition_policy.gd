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


static func is_allowed(
	item_data: Dictionary,
	channel: String,
	owner: Object = null
) -> bool:
	if str(item_data.get("type", "")).strip_edges().to_lower() != "active":
		return false
	if not is_character_allowed(item_data, owner):
		return false
	return get_allowed_rarities(channel).has(
		ActiveItemRaritySchema.resolve_rarity(item_data)
	)


static func filter_candidates(
	candidates: Array,
	channel: String,
	owner: Object = null
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate := candidate_value as Dictionary
		if is_allowed(candidate, channel, owner):
			result.append(candidate.duplicate(true))
	return result


static func is_character_allowed(item_data: Dictionary, owner: Object) -> bool:
	var restriction := str(item_data.get("character_restriction", "")).strip_edges().to_lower()
	if restriction.is_empty():
		return true
	if owner == null:
		return false
	var owner_character := str(owner.get("selected_character_type")).strip_edges().to_lower()
	return _normalize_character_type(restriction) == _normalize_character_type(owner_character)


static func _normalize_character_type(character_type: String) -> String:
	match character_type:
		"commando":
			return "soldier"
		"io":
			return "optimus"
		"baltor", "kohaku":
			return "blacksmith"
	return character_type


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
