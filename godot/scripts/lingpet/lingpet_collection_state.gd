extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const STATE_COMPANION := "companion"
const MAX_BATTLE_SLOTS := 3

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
const OWNER_SLOT_KEYS := [
	"lingpet_slots",
	"ringpet_slots",
	"lingpet_slot_pet_ids",
	"ringpet_slot_pet_ids",
]
const OWNER_ACTIVE_SLOT_KEYS := [
	"lingpet_active_slot_index",
	"ringpet_active_slot_index",
]

var owned_pet_ids: Array[String] = []
var battle_slot_pet_ids: Array[String] = ["", "", ""]
var active_slot_index := 0


func reset() -> void:
	owned_pet_ids.clear()
	battle_slot_pet_ids = ["", "", ""]
	active_slot_index = 0


func set_owned_pet_ids(value: Variant) -> void:
	owned_pet_ids = normalize_pet_id_array(value)


func get_owned_pet_ids() -> Array[String]:
	return owned_pet_ids.duplicate()


func set_battle_slots(value: Variant) -> void:
	battle_slot_pet_ids = normalize_slot_array(value)


func get_battle_slots() -> Array[String]:
	return battle_slot_pet_ids.duplicate()


func set_active_slot_index(value: int) -> void:
	active_slot_index = clampi(value, 0, MAX_BATTLE_SLOTS - 1)


func get_active_slot_index() -> int:
	return active_slot_index


func add_pet(owner: Object, pet_id: String) -> String:
	var normalized_pet_id := normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return ""
	if not owned_pet_ids.has(normalized_pet_id):
		owned_pet_ids.append(normalized_pet_id)
	_ensure_pet_in_battle_slots(normalized_pet_id)
	if owner != null:
		for key in OWNER_ARRAY_KEYS:
			_ensure_owner_array_contains(owner, str(key), normalized_pet_id)
		for key in OWNER_COLLECTION_KEYS:
			_ensure_owner_dict_true(owner, str(key), normalized_pet_id)
		_sync_owner_slots(owner)
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


func find_active_slot_pet_id(owner: Object) -> String:
	var slots: Array[String] = get_battle_slots_from_owner(owner)
	var slot_index := get_active_slot_index_from_owner(owner)
	if slot_index >= 0 and slot_index < slots.size() and slots[slot_index] != "":
		battle_slot_pet_ids = slots
		active_slot_index = slot_index
		return slots[slot_index]
	for i in range(slots.size()):
		if slots[i] != "":
			battle_slot_pet_ids = slots
			active_slot_index = i
			return slots[i]
	return find_first_owned_pet_id(owner)


func select_active_slot(slot_index: int, owner: Object = null) -> String:
	var slots: Array[String] = get_battle_slots_from_owner(owner)
	var clamped_index := clampi(slot_index, 0, MAX_BATTLE_SLOTS - 1)
	if clamped_index >= slots.size() or slots[clamped_index] == "":
		return ""
	battle_slot_pet_ids = slots
	active_slot_index = clamped_index
	if owner != null:
		_sync_owner_slots(owner)
	return slots[clamped_index]


func find_next_occupied_slot_index(direction: int = 1, owner: Object = null) -> int:
	var slots: Array[String] = get_battle_slots_from_owner(owner)
	if slots.is_empty():
		return -1
	var current_index := get_active_slot_index_from_owner(owner)
	var step := 1 if direction >= 0 else -1
	for offset in range(1, MAX_BATTLE_SLOTS + 1):
		var next_index := posmod(current_index + step * offset, MAX_BATTLE_SLOTS)
		if next_index < slots.size() and slots[next_index] != "":
			return next_index
	return -1


func get_battle_slots_from_owner(owner: Object) -> Array[String]:
	var slots: Array[String] = battle_slot_pet_ids.duplicate()
	for key in OWNER_SLOT_KEYS:
		var ids: Variant = _get_owner_value(owner, str(key), null)
		if ids is Array:
			var owner_slots: Array[String] = normalize_slot_array(ids)
			if _has_any_slot(owner_slots):
				slots = owner_slots
				break
	for pet_id in owned_pet_ids:
		if pet_id != "":
			_assign_pet_to_first_empty_slot(slots, pet_id)
	return slots


func get_active_slot_index_from_owner(owner: Object) -> int:
	for key in OWNER_ACTIVE_SLOT_KEYS:
		var value: Variant = _get_owner_value(owner, str(key), null)
		# The schema default is a -1 sentinel: a declared-but-never-synced
		# owner must fall through to the internal index, not force slot 0.
		if value != null and int(value) >= 0:
			return clampi(int(value), 0, MAX_BATTLE_SLOTS - 1)
	return active_slot_index


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


func normalize_slot_array(value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	for _i in range(MAX_BATTLE_SLOTS):
		normalized.append("")
	if not (value is Array):
		return normalized
	var seen := {}
	var index := 0
	for item in (value as Array):
		if index >= MAX_BATTLE_SLOTS:
			break
		var pet_id: String = normalize_pet_id(str(item))
		if pet_id != "" and not bool(seen.get(pet_id, false)):
			normalized[index] = pet_id
			seen[pet_id] = true
		index += 1
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


func _ensure_pet_in_battle_slots(pet_id: String) -> void:
	if pet_id == "" or battle_slot_pet_ids.has(pet_id):
		return
	var assigned_index := _assign_pet_to_first_empty_slot(battle_slot_pet_ids, pet_id)
	if assigned_index >= 0 and battle_slot_pet_ids[active_slot_index] == "":
		active_slot_index = assigned_index


func _assign_pet_to_first_empty_slot(slots: Array[String], pet_id: String) -> int:
	if pet_id == "" or slots.has(pet_id):
		return slots.find(pet_id)
	for i in range(mini(MAX_BATTLE_SLOTS, slots.size())):
		if slots[i] == "":
			slots[i] = pet_id
			return i
	return -1


func _sync_owner_slots(owner: Object) -> void:
	var slots: Array[String] = battle_slot_pet_ids.duplicate()
	for key in OWNER_SLOT_KEYS:
		owner.set(str(key), slots.duplicate())
	for key in OWNER_ACTIVE_SLOT_KEYS:
		owner.set(str(key), active_slot_index)


func _has_any_slot(slots: Array[String]) -> bool:
	for pet_id in slots:
		if pet_id != "":
			return true
	return false


func _get_owner_value(owner: Object, property_name: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(property_name)
	return fallback if value == null else value
