extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const STATE_COMPANION := "companion"

const OWNER_ARRAY_KEYS := [
	"lingpet_owned_pet_ids",
	"owned_lingpet_ids",
	"owned_ringpet_ids",
]
const OWNER_COLLECTION_KEYS := [
	"lingpet_collection",
	"ringpet_collection",
	"owned_lingpets",
	"owned_ringpets",
]

var owned_pet_ids: Array[String] = []


func reset() -> void:
	owned_pet_ids.clear()


func set_owned_pet_ids(value: Variant) -> void:
	owned_pet_ids = normalize_pet_id_array(value)


func get_owned_pet_ids() -> Array[String]:
	return owned_pet_ids.duplicate()


func add_pet(owner: Object, pet_id: String) -> String:
	var normalized_pet_id := normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return ""
	if not owned_pet_ids.has(normalized_pet_id):
		owned_pet_ids.append(normalized_pet_id)
	if owner != null:
		for key in OWNER_ARRAY_KEYS:
			_ensure_owner_array_contains(owner, str(key), normalized_pet_id)
		for key in OWNER_COLLECTION_KEYS:
			_ensure_owner_dict_true(owner, str(key), normalized_pet_id)
	return normalized_pet_id


func get_owned_pet_ids_from_owner(owner: Object) -> Array[String]:
	var result: Array[String] = owned_pet_ids.duplicate()
	for key in OWNER_ARRAY_KEYS:
		var ids: Variant = _get_owner_value(owner, str(key), [])
		if ids is Array:
			for raw_id in (ids as Array):
				var pet_id := normalize_pet_id(str(raw_id))
				if pet_id != "" and not result.has(pet_id):
					result.append(pet_id)
	for key in OWNER_COLLECTION_KEYS:
		var collection: Variant = _get_owner_value(owner, str(key), {})
		if collection is Dictionary:
			for raw_id in (collection as Dictionary).keys():
				var pet_id := normalize_pet_id(str(raw_id))
				if pet_id != "" and bool((collection as Dictionary).get(raw_id, false)) and not result.has(pet_id):
					result.append(pet_id)
	var state: String = str(_get_owner_value(owner, "lingpet_state", ""))
	var id := normalize_pet_id(str(_get_owner_value(owner, "lingpet_id", "")))
	if id != "" and _is_companion_state(state) and not result.has(id):
		result.append(id)
	return result


func find_first_owned_pet_id(owner: Object) -> String:
	for pet_id in get_owned_pet_ids_from_owner(owner):
		if LingpetCatalog.has_pet(pet_id):
			return pet_id
	return ""


func should_spawn_egg(owner: Object) -> bool:
	return not LingpetCatalog.get_hatch_candidates(get_hatch_context(owner), get_owned_pet_ids_from_owner(owner)).is_empty()


func pick_hatch_pet_id(owner: Object) -> String:
	return LingpetCatalog.pick_hatch_pet_id(get_hatch_context(owner), get_owned_pet_ids_from_owner(owner))


func get_hatch_context(owner: Object) -> Dictionary:
	return {
		"league_mode": _normalize_league_mode(str(_get_owner_value(owner, "ai_mode", "champion"))),
		"character_type": _normalize_character_type(_get_owner_value(owner, "selected_character_type", "smasher")),
	}


func normalize_pet_id(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if LingpetCatalog.has_pet(normalized):
		return normalized
	return ""


func normalize_pet_id_array(value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not (value is Array):
		return normalized
	for item in value:
		var pet_id: String = normalize_pet_id(str(item))
		if pet_id != "" and not normalized.has(pet_id):
			normalized.append(pet_id)
	return normalized


func _is_companion_state(value: String) -> bool:
	var normalized: String = value.strip_edges().to_lower()
	return normalized == STATE_COMPANION or normalized == "active" or normalized == "owned" or normalized == "hatched"


func _normalize_league_mode(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace(" ", "").replace("-", "").replace("_", "")
	if normalized in ["junior", "juniorleague"]:
		return "junior"
	return normalized


func _normalize_character_type(value: Variant) -> String:
	var normalized := str(value).strip_edges().to_lower()
	if normalized in ["mika", "smasher"]:
		return "smasher"
	return normalized


func _ensure_owner_array_contains(owner: Object, key: String, pet_id: String) -> void:
	var ids_value: Variant = _get_owner_value(owner, key, [])
	var ids: Array = []
	if ids_value is Array:
		ids = ids_value.duplicate()
	if not ids.has(pet_id):
		ids.append(pet_id)
	owner.set(key, ids)


func _ensure_owner_dict_true(owner: Object, key: String, pet_id: String) -> void:
	var collection_value: Variant = _get_owner_value(owner, key, {})
	var collection: Dictionary = {}
	if collection_value is Dictionary:
		collection = collection_value.duplicate(true)
	collection[pet_id] = true
	owner.set(key, collection)


func _get_owner_value(owner: Object, property_name: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(property_name)
	return fallback if value == null else value
