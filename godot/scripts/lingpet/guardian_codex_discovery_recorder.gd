extends RefCounted

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)

const STORE_KEY := "guardian_codex_store"
const DISCOVERY_ID_PREFIX := "guardian:first_seen:"


static func record_identity_reveal(registry: Object, pet_id: String) -> Dictionary:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	var discovery_id := make_discovery_id(normalized_pet_id)
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return _result(true, false, "legacy_bypass", normalized_pet_id, discovery_id)
	if normalized_pet_id.is_empty():
		return _result(false, false, "invalid_pet_id", normalized_pet_id, discovery_id)
	var store := _resolve_store(registry)
	if store == null or not store.has_method("record_first_seen"):
		return _result(false, false, "missing_guardian_codex_store", normalized_pet_id, discovery_id)
	var value: Variant = store.call("record_first_seen", normalized_pet_id, discovery_id)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return _result(false, false, "invalid_store_result", normalized_pet_id, discovery_id)


static func make_discovery_id(pet_id: String) -> String:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if normalized_pet_id.is_empty():
		return ""
	return "%s%s" % [DISCOVERY_ID_PREFIX, normalized_pet_id]


static func _resolve_store(registry: Object) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if not registry.has_method(method_name):
			continue
		var value: Variant = registry.call(method_name, STORE_KEY)
		if value is Object and value != null:
			return value as Object
	return null


static func _result(
	accepted: bool,
	changed: bool,
	reason: String,
	pet_id: String,
	discovery_id: String
) -> Dictionary:
	return {
		"accepted": accepted,
		"changed": changed,
		"reason": reason,
		"pet_id": pet_id,
		"discovery_id": discovery_id,
	}
