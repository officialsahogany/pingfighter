extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

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
const OWNER_ACTIVE_ID_KEYS := [
	"active_lingpet_id",
	"current_lingpet_id",
	"lingpet_id",
]


static func get_active_prewarm_pet_ids(
	owner: Object,
	_registry: Object = null,
	_module_getter: Callable = Callable()
) -> Array[String]:
	return _build_prewarm_pet_ids(owner, false)


static func get_slot_prewarm_pet_ids(
	owner: Object,
	_registry: Object = null,
	_module_getter: Callable = Callable()
) -> Array[String]:
	return _build_prewarm_pet_ids(owner, true)


static func _build_prewarm_pet_ids(
	owner: Object,
	include_all_slots: bool
) -> Array[String]:
	var result: Array[String] = []
	_append_from_owner(result, owner, include_all_slots)
	return result


static func _append_from_owner(result: Array[String], owner: Object, include_all_slots: bool) -> void:
	if owner == null:
		return
	var slots := _get_slot_array_from_owner(owner)
	if include_all_slots:
		_append_slot_ids(result, slots)
	else:
		var active_slot_index := _get_active_slot_index_from_owner(owner)
		_append_slot_id_at(result, slots, active_slot_index)
	for key in OWNER_ACTIVE_ID_KEYS:
		_append_unique_pet_id(result, str(_get_owner_value(owner, str(key), "")))
	if result.is_empty() and not include_all_slots:
		_append_first_slot_id(result, slots)


static func _get_slot_array_from_owner(owner: Object) -> Array:
	for key in OWNER_SLOT_KEYS:
		var value: Variant = _get_owner_value(owner, str(key), null)
		if value is Array:
			return value as Array
	return []


static func _get_active_slot_index_from_owner(owner: Object) -> int:
	for key in OWNER_ACTIVE_SLOT_KEYS:
		var value: Variant = _get_owner_value(owner, str(key), null)
		if value != null and int(value) >= 0:
			return int(value)
	return -1


static func _append_slot_ids(result: Array[String], slots: Array) -> void:
	for raw_id in slots:
		_append_unique_pet_id(result, str(raw_id))


static func _append_slot_id_at(result: Array[String], slots: Array, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	_append_unique_pet_id(result, str(slots[slot_index]))


static func _append_first_slot_id(result: Array[String], slots: Array) -> void:
	for raw_id in slots:
		var before_size := result.size()
		_append_unique_pet_id(result, str(raw_id))
		if result.size() > before_size:
			return


static func _append_unique_pet_id(result: Array[String], raw_id: String) -> void:
	var pet_id := raw_id.strip_edges().to_lower()
	if pet_id != "" and pet_id != "<null>" and LingpetCatalog.has_pet(pet_id) and not result.has(pet_id):
		result.append(pet_id)


static func _get_owner_value(owner: Object, property_name: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(property_name)
	return fallback if value == null else value
