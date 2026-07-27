extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const STATE_COMPANION := "companion"
const MAX_BATTLE_SLOTS := 3
const MAX_OWNED := MAX_BATTLE_SLOTS

# 테스트(주니어) 난이도에서 시작 수호령 알을 스매셔와 동일하게 지급받는 캐릭터들.
# 부화 후보(hatch candidates)의 unlock이 character_type == "smasher"로 게이트돼 있어,
# 이 캐릭터들은 주니어 한정으로 hatch context의 character_type를 smasher로 승격해
# 같은 시작 알 풀을 공유한다(is_first_lingpet_egg_eligible의 표준 링코어 지급도 같은
# 컨텍스트를 읽으므로 스매셔와 동일하게 링코어 tier 1도 함께 받는다).
# 코만도는 내부적으로 "soldier"이며 "commando" 별칭도 안전하게 포함한다.
const JUNIOR_STARTER_EGG_CHARACTERS := ["smasher", "soldier", "commando", "viper"]

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


func sync_from_owner(owner: Object) -> void:
	owned_pet_ids = get_owned_pet_ids_from_owner(owner)
	battle_slot_pet_ids = get_battle_slots_from_owner(owner)
	active_slot_index = get_active_slot_index_from_owner(owner)


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
	sync_from_owner(owner)
	if not owned_pet_ids.has(normalized_pet_id):
		if owned_pet_ids.size() >= MAX_OWNED:
			return ""
		owned_pet_ids.append(normalized_pet_id)
	_ensure_pet_in_battle_slots(normalized_pet_id)
	if owner != null:
		_sync_owner_collections(owner)
		_sync_owner_slots(owner)
	return normalized_pet_id


func add_pet_to_next_empty_slot(owner: Object, pet_id: String) -> String:
	var normalized_pet_id := normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return ""
	sync_from_owner(owner)
	if not owned_pet_ids.has(normalized_pet_id):
		if owned_pet_ids.size() >= MAX_OWNED:
			return ""
		owned_pet_ids.append(normalized_pet_id)
	var slots: Array[String] = battle_slot_pet_ids.duplicate()
	var slot_index := slots.find(normalized_pet_id)
	if slot_index < 0:
		slot_index = _assign_pet_to_first_empty_slot(slots, normalized_pet_id)
	if slot_index < 0:
		return ""
	battle_slot_pet_ids = slots
	active_slot_index = clampi(slot_index, 0, MAX_BATTLE_SLOTS - 1)
	if owner != null:
		_sync_owner_collections(owner)
		_sync_owner_slots(owner)
	return normalized_pet_id


# Like add_pet_to_next_empty_slot, but PRESERVES the current active_slot_index so a
# coexisting incubator-egg hatch (the lingpet_egg item used while a companion is already
# active) registers the new pet into a free battle slot WITHOUT stealing the active
# companion. Returns the normalized pet id on success, or "" if the roster is full / has
# no empty slot. The companion keeps accompanying the player; the new pet is just
# collected into its slot after the item-egg lifecycle reveal transition.
func add_pet_to_collection_keep_active(owner: Object, pet_id: String) -> String:
	var normalized_pet_id := normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return ""
	sync_from_owner(owner)
	var preserved_active := active_slot_index
	if not owned_pet_ids.has(normalized_pet_id):
		if owned_pet_ids.size() >= MAX_OWNED:
			return ""
		owned_pet_ids.append(normalized_pet_id)
	var slots: Array[String] = battle_slot_pet_ids.duplicate()
	var slot_index := slots.find(normalized_pet_id)
	if slot_index < 0:
		slot_index = _assign_pet_to_first_empty_slot(slots, normalized_pet_id)
	if slot_index < 0:
		return ""
	battle_slot_pet_ids = slots
	# Keep the companion's slot active; only fall back if the preserved index is invalid.
	if preserved_active >= 0 and preserved_active < battle_slot_pet_ids.size() and battle_slot_pet_ids[preserved_active] != "":
		active_slot_index = preserved_active
	else:
		active_slot_index = clampi(slot_index, 0, MAX_BATTLE_SLOTS - 1)
	if owner != null:
		_sync_owner_collections(owner)
		_sync_owner_slots(owner)
	return normalized_pet_id


func release_pet(owner: Object, pet_id: String) -> bool:
	var normalized_pet_id := normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return false
	sync_from_owner(owner)
	var changed := false
	if owned_pet_ids.has(normalized_pet_id):
		owned_pet_ids.erase(normalized_pet_id)
		changed = true
	for i in range(battle_slot_pet_ids.size()):
		if battle_slot_pet_ids[i] == normalized_pet_id:
			battle_slot_pet_ids[i] = ""
			changed = true
	if active_slot_index < 0 or active_slot_index >= battle_slot_pet_ids.size() or battle_slot_pet_ids[active_slot_index] == "":
		active_slot_index = _first_occupied_slot_index(battle_slot_pet_ids)
	if owner != null:
		_sync_owner_collections(owner)
		_sync_owner_slots(owner)
	return changed


func replace_slot(owner: Object, slot_index: int, new_pet_id: String) -> Dictionary:
	var normalized_pet_id := normalize_pet_id(new_pet_id)
	if normalized_pet_id == "":
		return {}
	sync_from_owner(owner)
	var clamped_index := clampi(slot_index, 0, MAX_BATTLE_SLOTS - 1)
	if clamped_index >= battle_slot_pet_ids.size():
		return {}
	var previous_pet_id := battle_slot_pet_ids[clamped_index]
	if previous_pet_id != "" and previous_pet_id != normalized_pet_id and owned_pet_ids.has(previous_pet_id):
		owned_pet_ids.erase(previous_pet_id)
	if not owned_pet_ids.has(normalized_pet_id):
		if owned_pet_ids.size() >= MAX_OWNED:
			return {}
		owned_pet_ids.append(normalized_pet_id)
	for i in range(battle_slot_pet_ids.size()):
		if battle_slot_pet_ids[i] == normalized_pet_id:
			battle_slot_pet_ids[i] = ""
	battle_slot_pet_ids[clamped_index] = normalized_pet_id
	active_slot_index = clamped_index
	if owner != null:
		_sync_owner_collections(owner)
		_sync_owner_slots(owner)
	return {
		"old_pet_id": previous_pet_id,
		"new_pet_id": normalized_pet_id,
		"slot_index": clamped_index,
	}


func owned_count(owner: Object = null) -> int:
	return get_owned_pet_ids_from_owner(owner).size() if owner != null else owned_pet_ids.size()


func is_full(owner: Object = null) -> bool:
	return owned_count(owner) >= MAX_OWNED


func has_unowned_pet_candidates(owner: Object) -> bool:
	var owned_ids: Array[String] = get_owned_pet_ids_from_owner(owner)
	for pet_id in LingpetCatalog.get_pet_ids():
		if pet_id != "" and not owned_ids.has(pet_id):
			return true
	return false


func has_owned_pet(owner: Object, pet_id: String) -> bool:
	var normalized_pet_id := normalize_pet_id(pet_id)
	return normalized_pet_id != "" and get_owned_pet_ids_from_owner(owner).has(normalized_pet_id)


func get_pet_display_name(pet_id: String) -> String:
	var normalized_pet_id := normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return ""
	return LingpetCatalog.get_display_name(normalized_pet_id)


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
	return _cap_owned_pet_ids(result)


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


func ensure_pet_active_slot(owner: Object, pet_id: String) -> String:
	var normalized_pet_id := add_pet(owner, pet_id)
	if normalized_pet_id == "":
		return ""
	var slots: Array[String] = get_battle_slots_from_owner(owner)
	var slot_index := slots.find(normalized_pet_id)
	if slot_index < 0:
		slot_index = clampi(get_active_slot_index_from_owner(owner), 0, MAX_BATTLE_SLOTS - 1)
		if slot_index >= 0 and slot_index < slots.size():
			slots[slot_index] = normalized_pet_id
		else:
			slot_index = _assign_pet_to_first_empty_slot(slots, normalized_pet_id)
	if slot_index < 0:
		return normalized_pet_id
	battle_slot_pet_ids = slots
	active_slot_index = clampi(slot_index, 0, MAX_BATTLE_SLOTS - 1)
	if owner != null:
		_sync_owner_slots(owner)
	return normalized_pet_id


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


func is_auto_present_league(owner: Object) -> bool:
	var hatch_context: Dictionary = get_hatch_context(owner)
	return str(hatch_context.get("league_mode", "")) == "junior"


# Picks a uniformly-random pet from the ENTIRE enabled catalog, ignoring
# ownership and league/character unlock gating. Used by the Pro/Mythic
# "lingpet_egg" active item, whose design is "use to hatch one random lingpet
# among all" (deploy_egg_from_item), not the unlock-filtered hatch-candidate
# pool that pick_hatch_pet_id uses.
func pick_random_any_pet_id(rng: RandomNumberGenerator = null) -> String:
	var ids: Array[String] = LingpetCatalog.get_pet_ids()
	if ids.is_empty():
		return ""
	var index: int = (rng.randi() if rng != null else randi()) % ids.size()
	return ids[index]


func pick_random_unowned_pet_id(owner: Object, rng: RandomNumberGenerator = null) -> String:
	var owned_ids: Array[String] = get_owned_pet_ids_from_owner(owner)
	var candidates: Array[String] = []
	for pet_id in LingpetCatalog.get_pet_ids():
		if pet_id != "" and not owned_ids.has(pet_id):
			candidates.append(pet_id)
	if candidates.is_empty():
		return ""
	var index: int = (rng.randi() if rng != null else randi()) % candidates.size()
	return candidates[index]


func get_hatch_context(owner: Object) -> Dictionary:
	var league_mode: String = _normalize_league_mode(str(_get_owner_value(owner, "ai_mode", "champion")))
	var character_type: String = _normalize_character_type(_get_owner_value(owner, "selected_character_type", "smasher"))
	# 주니어(테스트) 난이도 시작 알은 스매셔 전용이 아니다. 코만도/바이퍼도 스매셔처럼
	# 시작 알을 받도록, 주니어 한정으로 hatch context 캐릭터를 smasher로 승격한다.
	# 다른 리그에서는 승격하지 않으므로 상위 리그 hatch/gacha 게이팅에는 영향이 없다.
	if league_mode == "junior" and character_type in JUNIOR_STARTER_EGG_CHARACTERS:
		character_type = "smasher"
	return {
		"league_mode": league_mode,
		"character_type": character_type,
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
			if normalized.size() >= MAX_OWNED:
				break
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


func _sync_owner_collections(owner: Object) -> void:
	if owner == null:
		return
	var ids: Array[String] = _cap_owned_pet_ids(owned_pet_ids)
	owned_pet_ids = ids
	for key in OWNER_ARRAY_KEYS:
		owner.set(str(key), ids.duplicate())
	var collection: Dictionary = {}
	for pet_id in ids:
		collection[pet_id] = true
	for key in OWNER_COLLECTION_KEYS:
		owner.set(str(key), collection.duplicate(true))


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


func _first_occupied_slot_index(slots: Array[String]) -> int:
	for i in range(mini(MAX_BATTLE_SLOTS, slots.size())):
		if slots[i] != "":
			return i
	return 0


func _cap_owned_pet_ids(ids: Array[String]) -> Array[String]:
	var capped: Array[String] = []
	for pet_id in ids:
		if pet_id != "" and not capped.has(pet_id):
			capped.append(pet_id)
			if capped.size() >= MAX_OWNED:
				break
	return capped


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
