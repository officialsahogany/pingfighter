extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const OWNER_LOADOUT_KEYS := [
	"lingpet_loadouts",
	"ringpet_loadouts",
	"owned_lingpet_loadouts",
	"owned_ringpet_loadouts",
]

const OWNER_ACTIVE_SKILL_KEYS := [
	"lingpet_active_skill_id",
	"ringpet_active_skill_id",
]

const OWNER_ACTIVE_SKILL_LEVEL_KEYS := [
	"lingpet_active_skill_level",
	"ringpet_active_skill_level",
]

const OWNER_SECOND_ACTIVE_SKILL_KEYS := [
	"lingpet_second_active_skill_id",
	"ringpet_second_active_skill_id",
]

const OWNER_SECOND_ACTIVE_SKILL_LEVEL_KEYS := [
	"lingpet_second_active_skill_level",
	"ringpet_second_active_skill_level",
]

const OWNER_PASSIVE_SKILL_KEYS := [
	"lingpet_passive_skill_id",
	"ringpet_passive_skill_id",
]

const OWNER_PASSIVE_SKILL_LEVEL_KEYS := [
	"lingpet_passive_skill_level",
	"ringpet_passive_skill_level",
]

const OWNER_SECOND_PASSIVE_SKILL_KEYS := [
	"lingpet_second_passive_skill_id",
	"ringpet_second_passive_skill_id",
]

const OWNER_SECOND_PASSIVE_SKILL_LEVEL_KEYS := [
	"lingpet_second_passive_skill_level",
	"ringpet_second_passive_skill_level",
]

var loadouts_by_pet_id: Dictionary = {}


func reset() -> void:
	loadouts_by_pet_id.clear()


func set_loadouts(value: Variant) -> void:
	loadouts_by_pet_id.clear()
	if not (value is Dictionary):
		return
	for raw_pet_id in (value as Dictionary).keys():
		var pet_id := normalize_pet_id(str(raw_pet_id))
		if pet_id == "":
			continue
		var loadout := _normalize_loadout(pet_id, (value as Dictionary).get(raw_pet_id, {}), true)
		if not loadout.is_empty():
			loadouts_by_pet_id[pet_id] = loadout


func get_loadouts() -> Dictionary:
	return loadouts_by_pet_id.duplicate(true)


func sync_from_owner(owner: Object) -> void:
	var owner_loadouts := _get_owner_loadouts(owner)
	if owner_loadouts.is_empty():
		return
	for raw_pet_id in owner_loadouts.keys():
		var pet_id := normalize_pet_id(str(raw_pet_id))
		if pet_id == "":
			continue
		var loadout := _normalize_loadout(pet_id, owner_loadouts.get(raw_pet_id, {}), true)
		if not loadout.is_empty():
			loadouts_by_pet_id[pet_id] = loadout


func ensure_pet_loadout(owner: Object, pet_id: String, rng: RandomNumberGenerator = null, randomize_missing: bool = true) -> Dictionary:
	var normalized_pet_id := normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {}
	sync_from_owner(owner)
	if loadouts_by_pet_id.has(normalized_pet_id):
		var stored := _normalize_loadout(normalized_pet_id, loadouts_by_pet_id.get(normalized_pet_id, {}), true)
		if not stored.is_empty():
			loadouts_by_pet_id[normalized_pet_id] = stored
			sync_owner(owner, normalized_pet_id)
			return stored.duplicate(true)
	var picked_source: Dictionary = LingpetCatalog.pick_skill_loadout(normalized_pet_id, rng) if randomize_missing else LingpetCatalog.build_default_loadout(normalized_pet_id)
	var picked := _normalize_loadout(normalized_pet_id, picked_source, true)
	if picked.is_empty():
		picked = LingpetCatalog.build_default_loadout(normalized_pet_id)
	loadouts_by_pet_id[normalized_pet_id] = picked
	sync_owner(owner, normalized_pet_id)
	return picked.duplicate(true)


func set_pet_loadout(
	owner: Object,
	pet_id: String,
	active_skill_id: String,
	passive_skill_id: String,
	active_skill_level: int = LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL,
	passive_skill_level: int = LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL,
	second_active_skill_id: String = "",
	second_passive_skill_id: String = "",
	second_active_skill_level: int = LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL,
	second_passive_skill_level: int = LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL
) -> Dictionary:
	var normalized_pet_id := normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {}
	sync_from_owner(owner)
	var loadout := _normalize_loadout(
		normalized_pet_id,
		{
			"active_skill_id": active_skill_id,
			"passive_skill_id": passive_skill_id,
			"active_skill_level": active_skill_level,
			"passive_skill_level": passive_skill_level,
			"active_skill_ids": [active_skill_id, second_active_skill_id],
			"active_skill_levels": {
				active_skill_id: active_skill_level,
				second_active_skill_id: second_active_skill_level,
			},
			"active_slot_count": _slot_count_for_pair(active_skill_id, second_active_skill_id),
			"passive_skill_ids": [passive_skill_id, second_passive_skill_id],
			"passive_skill_levels": {
				passive_skill_id: passive_skill_level,
				second_passive_skill_id: second_passive_skill_level,
			},
			"passive_slot_count": _slot_count_for_pair(passive_skill_id, second_passive_skill_id),
		},
		true
	)
	if loadout.is_empty():
		loadout = LingpetCatalog.build_default_loadout(normalized_pet_id)
	loadouts_by_pet_id[normalized_pet_id] = loadout
	sync_owner(owner, normalized_pet_id)
	return loadout.duplicate(true)


func get_loadout(pet_id: String) -> Dictionary:
	var normalized_pet_id := normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {}
	if loadouts_by_pet_id.has(normalized_pet_id):
		var loadout := _normalize_loadout(normalized_pet_id, loadouts_by_pet_id.get(normalized_pet_id, {}), true)
		if not loadout.is_empty():
			return loadout
	return LingpetCatalog.build_default_loadout(normalized_pet_id)


func get_active_skill_id(pet_id: String) -> String:
	return str(get_loadout(pet_id).get("active_skill_id", ""))


func get_active_skill_level(pet_id: String) -> int:
	return LingpetCatalog.clamp_skill_level(int(get_loadout(pet_id).get("active_skill_level", LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL)))


func get_active_skill_ids(pet_id: String) -> Array[String]:
	var ids: Array[String] = []
	var raw_ids: Variant = get_loadout(pet_id).get("active_skill_ids", [])
	if raw_ids is Array:
		for raw_id in raw_ids as Array:
			var skill_id := str(raw_id)
			if skill_id != "":
				ids.append(skill_id)
	return ids


func get_active_skill_level_for_slot(pet_id: String, slot_index: int) -> int:
	var ids := get_active_skill_ids(pet_id)
	if slot_index < 0 or slot_index >= ids.size():
		return 0
	var levels: Dictionary = get_loadout(pet_id).get("active_skill_levels", {}) as Dictionary
	return LingpetCatalog.clamp_skill_level(int(levels.get(ids[slot_index], LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL)))


func get_passive_skill_id(pet_id: String) -> String:
	return str(get_loadout(pet_id).get("passive_skill_id", ""))


func get_passive_skill_level(pet_id: String) -> int:
	return LingpetCatalog.clamp_skill_level(int(get_loadout(pet_id).get("passive_skill_level", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL)))


func get_passive_skill_ids(pet_id: String) -> Array[String]:
	var ids: Array[String] = []
	var raw_ids: Variant = get_loadout(pet_id).get("passive_skill_ids", [])
	if raw_ids is Array:
		for raw_id in raw_ids as Array:
			var skill_id := str(raw_id)
			if skill_id != "":
				ids.append(skill_id)
	return ids


func get_passive_skill_level_for_slot(pet_id: String, slot_index: int) -> int:
	var ids := get_passive_skill_ids(pet_id)
	if slot_index < 0 or slot_index >= ids.size():
		return 0
	var levels: Dictionary = get_loadout(pet_id).get("passive_skill_levels", {}) as Dictionary
	return LingpetCatalog.clamp_skill_level(int(levels.get(ids[slot_index], LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL)))


func sync_owner(owner: Object, active_pet_id: String = "") -> void:
	if owner == null:
		return
	var snapshot := get_loadouts()
	for key in OWNER_LOADOUT_KEYS:
		owner.set(str(key), snapshot.duplicate(true))
	var normalized_active_pet_id := normalize_pet_id(active_pet_id)
	var current_loadout := get_loadout(normalized_active_pet_id) if normalized_active_pet_id != "" else {}
	var active_skill_ids: Array = current_loadout.get("active_skill_ids", []) as Array
	var active_skill_levels: Dictionary = current_loadout.get("active_skill_levels", {}) as Dictionary
	var passive_skill_ids: Array = current_loadout.get("passive_skill_ids", []) as Array
	var passive_skill_levels: Dictionary = current_loadout.get("passive_skill_levels", {}) as Dictionary
	var current_active_id := str(current_loadout.get("active_skill_id", ""))
	var current_active_level := LingpetCatalog.clamp_skill_level(int(current_loadout.get("active_skill_level", LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL))) if current_active_id != "" else 0
	var second_active_id := str(active_skill_ids[1]) if active_skill_ids.size() > 1 else ""
	var second_active_level := LingpetCatalog.clamp_skill_level(int(active_skill_levels.get(second_active_id, LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL))) if second_active_id != "" else 0
	var current_passive_id := str(current_loadout.get("passive_skill_id", ""))
	var current_passive_level := LingpetCatalog.clamp_skill_level(int(current_loadout.get("passive_skill_level", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL))) if current_passive_id != "" else 0
	var second_passive_id := str(passive_skill_ids[1]) if passive_skill_ids.size() > 1 else ""
	var second_passive_level := LingpetCatalog.clamp_skill_level(int(passive_skill_levels.get(second_passive_id, LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL))) if second_passive_id != "" else 0
	for key in OWNER_ACTIVE_SKILL_KEYS:
		owner.set(str(key), current_active_id)
	for key in OWNER_ACTIVE_SKILL_LEVEL_KEYS:
		owner.set(str(key), current_active_level)
	for key in OWNER_SECOND_ACTIVE_SKILL_KEYS:
		owner.set(str(key), second_active_id)
	for key in OWNER_SECOND_ACTIVE_SKILL_LEVEL_KEYS:
		owner.set(str(key), second_active_level)
	for key in OWNER_PASSIVE_SKILL_KEYS:
		owner.set(str(key), current_passive_id)
	for key in OWNER_PASSIVE_SKILL_LEVEL_KEYS:
		owner.set(str(key), current_passive_level)
	for key in OWNER_SECOND_PASSIVE_SKILL_KEYS:
		owner.set(str(key), second_passive_id)
	for key in OWNER_SECOND_PASSIVE_SKILL_LEVEL_KEYS:
		owner.set(str(key), second_passive_level)


func normalize_pet_id(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if LingpetCatalog.has_pet(normalized):
		return normalized
	return ""


func _get_owner_loadouts(owner: Object) -> Dictionary:
	for key in OWNER_LOADOUT_KEYS:
		var value: Variant = _get_owner_value(owner, str(key), {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			return (value as Dictionary).duplicate(true)
	return {}


func _normalize_loadout(pet_id: String, value: Variant, fill_missing: bool) -> Dictionary:
	var data: Dictionary = {}
	if value is Dictionary:
		data = value as Dictionary
	var active_raw_by_id: Dictionary = {}
	var passive_raw_by_id: Dictionary = {}
	var active_skill_ids := _normalize_active_skill_ids(pet_id, data, active_raw_by_id)
	var passive_skill_ids := _normalize_passive_skill_ids(pet_id, data, passive_raw_by_id)
	var active_slot_count := clampi(
		int(data.get("active_slot_count", data.get("unlocked_active_slots", LingpetCatalog.DEFAULT_ACTIVE_SLOT_COUNT))),
		0,
		LingpetCatalog.MAX_ACTIVE_SLOT_COUNT
	)
	var passive_slot_count := clampi(
		int(data.get("passive_slot_count", data.get("unlocked_passive_slots", LingpetCatalog.DEFAULT_PASSIVE_SLOT_COUNT))),
		0,
		LingpetCatalog.MAX_PASSIVE_SLOT_COUNT
	)
	if fill_missing:
		var defaults := LingpetCatalog.build_default_loadout(pet_id)
		if active_skill_ids.is_empty() and active_slot_count > 0:
			active_raw_by_id.clear()
			active_skill_ids = _normalize_active_skill_ids(pet_id, defaults, active_raw_by_id)
		if passive_skill_ids.is_empty() and passive_slot_count > 0:
			passive_raw_by_id.clear()
			passive_skill_ids = _normalize_passive_skill_ids(pet_id, defaults, passive_raw_by_id)
	if active_skill_ids.size() > active_slot_count:
		active_slot_count = active_skill_ids.size()
	if passive_skill_ids.size() > passive_slot_count:
		passive_slot_count = passive_skill_ids.size()
	if active_slot_count <= 0 and not active_skill_ids.is_empty():
		active_slot_count = LingpetCatalog.DEFAULT_ACTIVE_SLOT_COUNT
	if passive_slot_count <= 0 and not passive_skill_ids.is_empty():
		passive_slot_count = LingpetCatalog.DEFAULT_PASSIVE_SLOT_COUNT
	if active_skill_ids.is_empty() and passive_skill_ids.is_empty():
		if active_slot_count <= 0 and passive_slot_count <= 0:
			return LingpetCatalog.build_empty_loadout(pet_id)
		return {}
	var active_level_map := _normalize_slot_level_map(
		active_skill_ids,
		active_raw_by_id,
		data.get("active_skill_levels", {}),
		_normalize_skill_level(data.get("active_skill_level", data.get("active_level", data.get("skill_level", LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL)))),
		_normalize_skill_level(data.get("second_active_skill_level", data.get("active_skill_level_2", LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL))),
		LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL
	)
	var passive_level_map := _normalize_slot_level_map(
		passive_skill_ids,
		passive_raw_by_id,
		data.get("passive_skill_levels", {}),
		_normalize_skill_level(data.get("passive_skill_level", data.get("passive_level", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL))),
		_normalize_skill_level(data.get("second_passive_skill_level", data.get("passive_skill_level_2", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL))),
		LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL
	)
	var active_skill_id := active_skill_ids[0] if active_skill_ids.size() > 0 else ""
	var passive_skill_id := passive_skill_ids[0] if passive_skill_ids.size() > 0 else ""
	var second_active_skill_id := active_skill_ids[1] if active_skill_ids.size() > 1 else ""
	var second_passive_skill_id := passive_skill_ids[1] if passive_skill_ids.size() > 1 else ""
	var active_skill_level := LingpetCatalog.clamp_skill_level(int(active_level_map.get(active_skill_id, LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL))) if active_skill_id != "" else 0
	var passive_skill_level := LingpetCatalog.clamp_skill_level(int(passive_level_map.get(passive_skill_id, LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL))) if passive_skill_id != "" else 0
	return {
		"active_skill_id": active_skill_id,
		"active_skill_level": active_skill_level,
		"second_active_skill_id": second_active_skill_id,
		"second_active_skill_level": LingpetCatalog.clamp_skill_level(int(active_level_map.get(second_active_skill_id, LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL))) if second_active_skill_id != "" else 0,
		"active_slot_count": active_slot_count,
		"active_skill_ids": active_skill_ids,
		"active_skill_levels": active_level_map,
		"passive_skill_id": passive_skill_id,
		"passive_skill_level": passive_skill_level,
		"second_passive_skill_id": second_passive_skill_id,
		"second_passive_skill_level": LingpetCatalog.clamp_skill_level(int(passive_level_map.get(second_passive_skill_id, LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL))) if second_passive_skill_id != "" else 0,
		"passive_slot_count": passive_slot_count,
		"passive_skill_ids": passive_skill_ids,
		"passive_skill_levels": passive_level_map,
	}


func _normalize_active_skill_ids(pet_id: String, data: Dictionary, raw_by_id: Dictionary) -> Array[String]:
	var raw_ids: Array[String] = []
	_append_raw_skill_id(raw_ids, str(data.get("active_skill_id", data.get("active_skill", data.get("skill_id", "")))))
	var active_ids_value: Variant = data.get("active_skill_ids", [])
	if active_ids_value is Array:
		for raw_id in active_ids_value as Array:
			_append_raw_skill_id(raw_ids, str(raw_id))
	_append_raw_skill_id(raw_ids, str(data.get("second_active_skill_id", data.get("active_skill_id_2", ""))))
	var result: Array[String] = []
	for raw_id in raw_ids:
		var normalized := LingpetCatalog.normalize_active_skill_id(pet_id, raw_id)
		if normalized != "" and not result.has(normalized):
			result.append(normalized)
			raw_by_id[normalized] = raw_id
		if result.size() >= LingpetCatalog.MAX_ACTIVE_SLOT_COUNT:
			break
	return result


func _normalize_passive_skill_ids(pet_id: String, data: Dictionary, raw_by_id: Dictionary) -> Array[String]:
	var raw_ids: Array[String] = []
	_append_raw_skill_id(raw_ids, str(data.get("passive_skill_id", data.get("passive_skill", data.get("passive_id", "")))))
	var passive_ids_value: Variant = data.get("passive_skill_ids", [])
	if passive_ids_value is Array:
		for raw_id in passive_ids_value as Array:
			_append_raw_skill_id(raw_ids, str(raw_id))
	_append_raw_skill_id(raw_ids, str(data.get("second_passive_skill_id", data.get("passive_skill_id_2", ""))))
	var result: Array[String] = []
	for raw_id in raw_ids:
		var normalized := LingpetCatalog.normalize_passive_skill_id(pet_id, raw_id)
		if normalized != "" and not result.has(normalized):
			result.append(normalized)
			raw_by_id[normalized] = raw_id
		if result.size() >= LingpetCatalog.MAX_PASSIVE_SLOT_COUNT:
			break
	return result


func _append_raw_skill_id(raw_ids: Array[String], skill_id: String) -> void:
	var normalized := skill_id.strip_edges()
	if normalized != "":
		raw_ids.append(normalized)


func _slot_count_for_pair(first_id: String, second_id: String) -> int:
	if second_id.strip_edges() != "":
		return 2
	if first_id.strip_edges() != "":
		return 1
	return 0


func _normalize_slot_level_map(
	skill_ids: Array[String],
	raw_by_id: Dictionary,
	raw_levels: Variant,
	first_slot_level: int,
	second_slot_level: int,
	default_level: int
) -> Dictionary:
	var level_source: Dictionary = raw_levels as Dictionary if raw_levels is Dictionary else {}
	var result: Dictionary = {}
	for index in range(skill_ids.size()):
		var skill_id := str(skill_ids[index])
		var raw_id := str(raw_by_id.get(skill_id, ""))
		var fallback := first_slot_level if index == 0 else second_slot_level
		if index > 1:
			fallback = default_level
		result[skill_id] = _normalize_skill_level(level_source.get(skill_id, level_source.get(raw_id, fallback)))
	return result


func _get_owner_value(owner: Object, property_name: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(property_name)
	return fallback if value == null else value


func _normalize_skill_level(value: Variant) -> int:
	if value == null:
		return LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL
	return LingpetCatalog.clamp_skill_level(int(value))
