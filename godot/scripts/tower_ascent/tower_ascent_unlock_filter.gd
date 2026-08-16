extends RefCounted

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)

const STORE_KEY := "tower_ascent_unlock_store"
const CONTENT_ITEM := "item"
const CONTENT_RUNTIME_PERK := "runtime_perk"
const CONTENT_NODE := "node"


static func is_content_unlocked(
	registry: Object,
	content_type: String,
	content_id: String
) -> bool:
	var normalized_type := content_type.strip_edges().to_lower()
	var normalized_id := content_id.strip_edges()
	if normalized_type.is_empty() or normalized_id.is_empty():
		return false
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return true
	if registry == null or not registry.has_method("get_instance"):
		return false
	var store_value: Variant = registry.call("get_instance", STORE_KEY)
	if not (store_value is Object):
		return false
	var store := store_value as Object
	if not store.has_method("is_unlocked"):
		return false
	return bool(store.call("is_unlocked", normalized_type, normalized_id))
