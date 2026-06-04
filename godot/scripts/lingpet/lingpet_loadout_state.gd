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

const OWNER_PASSIVE_SKILL_KEYS := [
	"lingpet_passive_skill_id",
	"ringpet_passive_skill_id",
]

const OWNER_PASSIVE_SKILL_LEVEL_KEYS := [
	"lingpet_passive_skill_level",
	"ringpet_passive_skill_level",
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
	passive_skill_level: int = LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL
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


func get_passive_skill_id(pet_id: String) -> String:
	return str(get_loadout(pet_id).get("passive_skill_id", ""))


func get_passive_skill_level(pet_id: String) -> int:
	return LingpetCatalog.clamp_skill_level(int(get_loadout(pet_id).get("passive_skill_level", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL)))


func sync_owner(owner: Object, active_pet_id: String = "") -> void:
	if owner == null:
		return
	var snapshot := get_loadouts()
	for key in OWNER_LOADOUT_KEYS:
		owner.set(str(key), snapshot.duplicate(true))
	var normalized_active_pet_id := normalize_pet_id(active_pet_id)
	var current_loadout := get_loadout(normalized_active_pet_id) if normalized_active_pet_id != "" else {}
	var current_active_level := LingpetCatalog.clamp_skill_level(int(current_loadout.get("active_skill_level", LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL))) if not current_loadout.is_empty() else 0
	var current_passive_level := LingpetCatalog.clamp_skill_level(int(current_loadout.get("passive_skill_level", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL))) if not current_loadout.is_empty() else 0
	for key in OWNER_ACTIVE_SKILL_KEYS:
		owner.set(str(key), str(current_loadout.get("active_skill_id", "")))
	for key in OWNER_ACTIVE_SKILL_LEVEL_KEYS:
		owner.set(str(key), current_active_level)
	for key in OWNER_PASSIVE_SKILL_KEYS:
		owner.set(str(key), str(current_loadout.get("passive_skill_id", "")))
	for key in OWNER_PASSIVE_SKILL_LEVEL_KEYS:
		owner.set(str(key), current_passive_level)


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
	var raw_passive_skill_id := str(data.get("passive_skill_id", data.get("passive_skill", data.get("passive_id", ""))))
	if raw_passive_skill_id == "":
		var passive_ids: Variant = data.get("passive_skill_ids", [])
		if passive_ids is Array and not (passive_ids as Array).is_empty():
			raw_passive_skill_id = str((passive_ids as Array)[0])
	var active_skill_id := LingpetCatalog.normalize_active_skill_id(
		pet_id,
		str(data.get("active_skill_id", data.get("active_skill", data.get("skill_id", ""))))
	)
	var passive_skill_id := LingpetCatalog.normalize_passive_skill_id(
		pet_id,
		raw_passive_skill_id
	)
	var active_skill_level := _normalize_skill_level(data.get("active_skill_level", data.get("active_level", data.get("skill_level", LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL))))
	var passive_skill_level := _normalize_skill_level(data.get("passive_skill_level", data.get("passive_level", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL)))
	var passive_skill_levels: Variant = data.get("passive_skill_levels", {})
	if passive_skill_id != "" and passive_skill_levels is Dictionary:
		passive_skill_level = _normalize_skill_level((passive_skill_levels as Dictionary).get(passive_skill_id, (passive_skill_levels as Dictionary).get(raw_passive_skill_id, passive_skill_level)))
	var passive_slot_count := clampi(
		int(data.get("passive_slot_count", data.get("unlocked_passive_slots", LingpetCatalog.DEFAULT_PASSIVE_SLOT_COUNT))),
		0,
		LingpetCatalog.MAX_PASSIVE_SLOT_COUNT
	)
	if fill_missing:
		var defaults := LingpetCatalog.build_default_loadout(pet_id)
		if active_skill_id == "":
			active_skill_id = str(defaults.get("active_skill_id", ""))
		if passive_skill_id == "":
			passive_skill_id = str(defaults.get("passive_skill_id", ""))
		if not data.has("active_skill_level") and not data.has("active_level") and not data.has("skill_level"):
			active_skill_level = int(defaults.get("active_skill_level", LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL))
		if not data.has("passive_skill_level") and not data.has("passive_level") and not (passive_skill_levels is Dictionary and passive_skill_id != "" and (passive_skill_levels as Dictionary).has(passive_skill_id)):
			passive_skill_level = int(defaults.get("passive_skill_level", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL))
		if passive_slot_count <= 0 and passive_skill_id != "":
			passive_slot_count = int(defaults.get("passive_slot_count", LingpetCatalog.DEFAULT_PASSIVE_SLOT_COUNT))
	if active_skill_id == "" and passive_skill_id == "":
		return {}
	var passive_skill_ids: Array[String] = []
	var passive_level_map: Dictionary = {}
	if passive_skill_id != "":
		passive_skill_ids.append(passive_skill_id)
		passive_level_map[passive_skill_id] = passive_skill_level
	return {
		"active_skill_id": active_skill_id,
		"active_skill_level": LingpetCatalog.clamp_skill_level(active_skill_level),
		"passive_skill_id": passive_skill_id,
		"passive_skill_level": LingpetCatalog.clamp_skill_level(passive_skill_level),
		"passive_slot_count": passive_slot_count,
		"passive_skill_ids": passive_skill_ids,
		"passive_skill_levels": passive_level_map,
	}


func _get_owner_value(owner: Object, property_name: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(property_name)
	return fallback if value == null else value


func _normalize_skill_level(value: Variant) -> int:
	if value == null:
		return LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL
	return LingpetCatalog.clamp_skill_level(int(value))
