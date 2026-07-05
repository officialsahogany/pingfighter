extends RefCounted

const ITEM_MEGINGJORD := "megingjord"
const ITEM_DOWSING_GOGGLES := "dowsing_goggles"
const ITEM_RAGNAROK_HAMMER := "ragnarok_hammer"
const ITEM_POSEIDON_TRIDENT := "poseidon_trident"
const ITEM_FOUL_WHISTLE := "foul_whistle"
const ITEM_SOUL_BURST := "soul_burst"
const ITEM_SENSOR := "sensor"
const ITEM_SMARTPHONE := "smartphone"
const ITEM_VENOM_MIST_GAUNTLET := "venom_mist_gauntlet"
const ITEM_RAINBOW_FUR_GLOVE := "rainbow_fur_glove"
const ITEM_ADVERSITY_ARMOR := "adversity_armor"
const ITEM_SHRAPNEL_ARMOR := "shrapnel_armor"
const ITEM_CELESTIAL_ARMOR := "celestial_armor"
const ITEM_HERMES_SHOES := "hermes_shoes"
const ITEM_BAAL_BOOTS := "baal_boots"
const ITEM_HORN_STRAWBERRY_MASK := "horn_strawberry_mask"
const ITEM_ODINS_EYE := "odins_eye"
const ITEM_PANDORA_LEGACY := "pandora_legacy"
const ITEM_REINFORCED_BOOMERANG_GAUNTLET := "reinforced_boomerang_gauntlet"
const ITEM_BOOMERANG := "boomerang"


func acquire_item(
	runtime: Object,
	item_name: String,
	owner: Object,
	registry: Object = null,
	roll_overrides: Dictionary = {},
	auto_equip: bool = true,
	play_pickup_sound: bool = false,
	acquired_item_data: Dictionary = {},
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> int:
	var item_data: Dictionary = runtime.catalog.build_item_by_name(item_name)
	if item_data.is_empty():
		return -1
	var item_rolls: Dictionary = runtime.catalog.build_random_rolls(item_name)
	if item_rolls.is_empty():
		item_rolls = runtime._get_dict(item_data.get("rolls", {})).duplicate(true)
	for key in roll_overrides.keys():
		item_rolls[str(key)] = roll_overrides[key]
	item_data["rolls"] = item_rolls
	var preserve_acquired_quality: bool = bool(runtime.roll_query.has_acquired_quality_identity(acquired_item_data))
	if preserve_acquired_quality:
		item_data = runtime.roll_query.copy_acquired_quality_identity(item_data, acquired_item_data)
	item_data = runtime.catalog.sync_roll_fields(item_data, false, not preserve_acquired_quality)
	item_data["owned"] = true
	item_data["equipped"] = false
	item_data["_equipped_slot"] = ""
	item_data["_inventory_id"] = runtime.next_inventory_id
	runtime.next_inventory_id += 1
	runtime.inventory_items.append(item_data)
	var index: int = runtime.inventory_items.size() - 1
	if auto_equip:
		if not equip_inventory_item(runtime, index, owner, registry, context_constants, baal_boots_constants):
			runtime._sync_owner(owner, registry)
	else:
		runtime._sync_owner(owner, registry)
	runtime.pickup_bonus.try_grant_reinforced_boomerang_pickup_bonus(
		runtime,
		item_name,
		owner,
		registry,
		ITEM_REINFORCED_BOOMERANG_GAUNTLET,
		ITEM_BOOMERANG
	)
	if play_pickup_sound:
		runtime.audio_router.play_pickup_audio(runtime, registry)
	return index


func equip_item(
	runtime: Object,
	item_name: String,
	owner: Object,
	registry: Object = null,
	roll_overrides: Dictionary = {},
	play_pickup_sound: bool = false,
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> bool:
	var index: int = runtime.equipment_index.find_inventory_index_by_name(runtime, item_name)
	if index < 0:
		index = acquire_item(
			runtime,
			item_name,
			owner,
			registry,
			roll_overrides,
			false,
			play_pickup_sound,
			{},
			context_constants,
			baal_boots_constants
		)
		if index < 0:
			return false
	else:
		runtime.roll_query.apply_roll_overrides(runtime, index, roll_overrides)
	var equipped: bool = equip_inventory_item(runtime, index, owner, registry, context_constants, baal_boots_constants)
	if play_pickup_sound and not equipped:
		runtime.audio_router.play_pickup_audio(runtime, registry)
	return equipped


func unequip_item(
	runtime: Object,
	item_name: String,
	owner: Object,
	registry: Object = null,
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> bool:
	var index: int = runtime.equipment_index.find_equipped_inventory_index_by_name(runtime, item_name)
	if index < 0:
		return false
	return unequip_inventory_item(runtime, index, owner, registry, context_constants, baal_boots_constants)


func equip_inventory_item(
	runtime: Object,
	index: int,
	owner: Object,
	registry: Object = null,
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> bool:
	if index < 0 or index >= runtime.inventory_items.size():
		return false
	if not (runtime.inventory_items[index] is Dictionary):
		return false
	var item_data: Dictionary = runtime.inventory_items[index]
	var item_name: String = str(item_data.get("name", ""))
	if runtime.equipment_index.is_single_equipment_item(item_name, context_constants):
		var equipped_index: int = runtime.equipment_index.find_equipped_inventory_index_by_name(runtime, item_name)
		if equipped_index >= 0 and equipped_index != index:
			return false
	var slot_key: String = runtime.equipment_index.resolve_equipment_slot_key(runtime, item_data, owner, context_constants)
	if slot_key == "":
		return false
	if not runtime.equipment_index.is_equipment_slot_enabled(runtime, slot_key, owner):
		return false
	var displaced_names: Array = _displace_slot_occupants(runtime, index, slot_key)
	item_data["equipped"] = true
	item_data["_equipped_slot"] = slot_key
	runtime.inventory_items[index] = item_data
	runtime.equipment_index.rebuild_equipped_items(runtime, context_constants)
	_run_displaced_unequip_cleanup(runtime, displaced_names, item_name, registry, baal_boots_constants)
	_clear_on_equip(runtime, item_name, owner, registry, baal_boots_constants)
	runtime._sync_owner(owner, registry)
	runtime.audio_router.play_equipment_audio(runtime, registry)
	return true


# Clears every inventory item currently occupying canonical_slot (except
# exclude_index) and returns their item names so callers can run unequip
# cleanup for the displaced items.
func _displace_slot_occupants(runtime: Object, exclude_index: int, canonical_slot: String) -> Array:
	var displaced_names: Array = []
	for i in range(runtime.inventory_items.size()):
		if i == exclude_index or not (runtime.inventory_items[i] is Dictionary):
			continue
		var other: Dictionary = runtime.inventory_items[i]
		if runtime.equipment_index.canonical_equipment_slot_key(str(other.get("_equipped_slot", ""))) == canonical_slot:
			other["equipped"] = false
			other["_equipped_slot"] = ""
			var other_name: String = str(other.get("name", ""))
			if other_name != "":
				displaced_names.append(other_name)
	return displaced_names


# A displaced item is being unequipped by the replacement, so it must run the
# same per-item teardown as an explicit unequip (Hermes / Baal Boots / Pandora /
# Horn Strawberry / Odin's Eye etc. leave runtime state alive otherwise). Must
# run AFTER rebuild_equipped_items so is_*_equipped() guards see the new state.
func _run_displaced_unequip_cleanup(runtime: Object, displaced_names: Array, equipped_item_name: String, registry: Object, baal_boots_constants: Dictionary) -> void:
	for displaced_name in displaced_names:
		var name_text: String = str(displaced_name)
		if name_text == "" or name_text == equipped_item_name:
			continue
		_clear_on_unequip(runtime, name_text, registry, baal_boots_constants)


func unequip_inventory_item(
	runtime: Object,
	index: int,
	owner: Object,
	registry: Object = null,
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> bool:
	if index < 0 or index >= runtime.inventory_items.size():
		return false
	if not (runtime.inventory_items[index] is Dictionary):
		return false
	var item_data: Dictionary = runtime.inventory_items[index]
	if not bool(item_data.get("equipped", false)) and str(item_data.get("_equipped_slot", "")) == "":
		return false
	item_data["equipped"] = false
	item_data["_equipped_slot"] = ""
	runtime.inventory_items[index] = item_data
	runtime.equipment_index.rebuild_equipped_items(runtime, context_constants)
	_clear_on_unequip(runtime, str(item_data.get("name", "")), registry, baal_boots_constants)
	runtime._sync_owner(owner, registry)
	runtime.audio_router.play_equipment_audio(runtime, registry)
	return true


func toggle_inventory_item(
	runtime: Object,
	index: int,
	owner: Object,
	registry: Object = null,
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> bool:
	if index < 0 or index >= runtime.inventory_items.size():
		return false
	var item_data: Dictionary = runtime._get_dict(runtime.inventory_items[index])
	if item_data.is_empty():
		return false
	if bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != "":
		return unequip_inventory_item(runtime, index, owner, registry, context_constants, baal_boots_constants)
	return equip_inventory_item(runtime, index, owner, registry, context_constants, baal_boots_constants)


func unequip_slot(
	runtime: Object,
	slot_key: String,
	owner: Object,
	registry: Object = null,
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> bool:
	var index: int = runtime.equipment_index.find_equipped_inventory_index_by_slot(runtime, slot_key)
	if index < 0:
		return false
	return unequip_inventory_item(runtime, index, owner, registry, context_constants, baal_boots_constants)


func equip_inventory_item_to_slot(
	runtime: Object,
	index: int,
	slot_key: String,
	owner: Object,
	registry: Object = null,
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> bool:
	# Slot-targeted equip (drag-and-drop / right-click auto-equip). Mirrors
	# equip_inventory_item but the caller chooses the destination slot instead
	# of resolve_equipment_slot_key picking only an empty one.
	if index < 0 or index >= runtime.inventory_items.size():
		return false
	if not (runtime.inventory_items[index] is Dictionary):
		return false
	var item_data: Dictionary = runtime.inventory_items[index]
	var item_name: String = str(item_data.get("name", ""))
	var canonical_slot: String = runtime.equipment_index.canonical_equipment_slot_key(slot_key)
	if not runtime.equipment_index.is_slot_compatible(runtime, item_data, canonical_slot):
		return false
	if not runtime.equipment_index.is_equipment_slot_enabled(runtime, canonical_slot, owner):
		return false
	if runtime.equipment_index.is_single_equipment_item(item_name, context_constants):
		var equipped_index: int = runtime.equipment_index.find_equipped_inventory_index_by_name(runtime, item_name)
		if equipped_index >= 0 and equipped_index != index:
			return false
	var displaced_names: Array = _displace_slot_occupants(runtime, index, canonical_slot)
	item_data["equipped"] = true
	item_data["_equipped_slot"] = canonical_slot
	runtime.inventory_items[index] = item_data
	runtime.equipment_index.rebuild_equipped_items(runtime, context_constants)
	_run_displaced_unequip_cleanup(runtime, displaced_names, item_name, registry, baal_boots_constants)
	_clear_on_equip(runtime, item_name, owner, registry, baal_boots_constants)
	runtime._sync_owner(owner, registry)
	runtime.audio_router.play_equipment_audio(runtime, registry)
	return true


func auto_equip_inventory_item(
	runtime: Object,
	index: int,
	owner: Object,
	registry: Object = null,
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> bool:
	# Right-click parity: equip into the first empty compatible slot, else the
	# first enabled compatible slot (swap-replacing whatever is there).
	if index < 0 or index >= runtime.inventory_items.size():
		return false
	if not (runtime.inventory_items[index] is Dictionary):
		return false
	var item_data: Dictionary = runtime.inventory_items[index]
	var slot_key: String = runtime.equipment_index.resolve_auto_equip_slot(runtime, item_data, owner, context_constants)
	if slot_key == "":
		return false
	return equip_inventory_item_to_slot(runtime, index, slot_key, owner, registry, context_constants, baal_boots_constants)


func swap_equipment_slots(
	runtime: Object,
	slot_a: String,
	slot_b: String,
	owner: Object,
	registry: Object = null,
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> bool:
	# Drag a slot item onto another occupied slot. Both items must be
	# cross-compatible with the other slot, otherwise the swap is rejected.
	var canonical_a: String = runtime.equipment_index.canonical_equipment_slot_key(slot_a)
	var canonical_b: String = runtime.equipment_index.canonical_equipment_slot_key(slot_b)
	if canonical_a == canonical_b:
		return false
	var index_a: int = runtime.equipment_index.find_equipped_inventory_index_by_slot(runtime, canonical_a)
	var index_b: int = runtime.equipment_index.find_equipped_inventory_index_by_slot(runtime, canonical_b)
	if index_a < 0 and index_b < 0:
		return false
	if index_a >= 0:
		var item_a_check: Dictionary = runtime._get_dict(runtime.inventory_items[index_a])
		if not runtime.equipment_index.is_slot_compatible(runtime, item_a_check, canonical_b):
			return false
		if not runtime.equipment_index.is_equipment_slot_enabled(runtime, canonical_b, owner):
			return false
	if index_b >= 0:
		var item_b_check: Dictionary = runtime._get_dict(runtime.inventory_items[index_b])
		if not runtime.equipment_index.is_slot_compatible(runtime, item_b_check, canonical_a):
			return false
		if not runtime.equipment_index.is_equipment_slot_enabled(runtime, canonical_a, owner):
			return false
	if index_a >= 0 and runtime.inventory_items[index_a] is Dictionary:
		var item_a: Dictionary = runtime.inventory_items[index_a]
		item_a["equipped"] = true
		item_a["_equipped_slot"] = canonical_b
		runtime.inventory_items[index_a] = item_a
	if index_b >= 0 and runtime.inventory_items[index_b] is Dictionary:
		var item_b: Dictionary = runtime.inventory_items[index_b]
		item_b["equipped"] = true
		item_b["_equipped_slot"] = canonical_a
		runtime.inventory_items[index_b] = item_b
	runtime.equipment_index.rebuild_equipped_items(runtime, context_constants)
	runtime._sync_owner(owner, registry)
	runtime.audio_router.play_equipment_audio(runtime, registry)
	return true


func discard_inventory_item(
	runtime: Object,
	index: int,
	owner: Object,
	registry: Object = null,
	context_constants: Dictionary = {},
	baal_boots_constants: Dictionary = {}
) -> bool:
	if index < 0 or index >= runtime.inventory_items.size():
		return false
	var item_data: Dictionary = runtime._get_dict(runtime.inventory_items[index])
	runtime.inventory_items.remove_at(index)
	var item_name: String = str(item_data.get("name", ""))
	_clear_on_remove_before_rebuild(runtime, item_name, registry, baal_boots_constants)
	runtime.equipment_index.rebuild_equipped_items(runtime, context_constants)
	_clear_on_remove_after_rebuild(runtime, item_name, registry, baal_boots_constants)
	runtime._sync_owner(owner, registry)
	return true


func _clear_on_equip(
	runtime: Object,
	item_name: String,
	owner: Object,
	registry: Object,
	baal_boots_constants: Dictionary
) -> void:
	if item_name == ITEM_MEGINGJORD:
		runtime.megingjord_extra_pick_count = 0
	if item_name == ITEM_DOWSING_GOGGLES:
		runtime.dowsing_goggles_bonus_triggered = false
	if item_name == ITEM_RAGNAROK_HAMMER:
		runtime.ragnarok_runtime.clear_runtime(runtime, registry)
	if item_name == ITEM_POSEIDON_TRIDENT:
		runtime.poseidon_runtime.clear_runtime(runtime)
	if item_name == ITEM_FOUL_WHISTLE:
		runtime.foul_whistle_runtime.clear_runtime(runtime)
	if item_name == ITEM_SOUL_BURST:
		runtime.soul_burst_runtime.clear_runtime(runtime)
	if item_name == ITEM_SENSOR:
		runtime.sensor_enabled = true
		runtime.auto_defense_runtime.clear_sensor_round_state(runtime)
	if item_name == ITEM_SMARTPHONE:
		runtime.ai_assist_runtime.clear_smartphone_runtime(runtime)
	if item_name == ITEM_VENOM_MIST_GAUNTLET and not runtime.is_venom_mist_gauntlet_equipped():
		runtime.venom_mist_runtime.clear_runtime(runtime)
	if item_name == ITEM_RAINBOW_FUR_GLOVE:
		runtime.rainbow_fur_glove_runtime.clear_runtime(runtime)
	if item_name == ITEM_ADVERSITY_ARMOR:
		runtime.adversity_armor_runtime.clear_runtime(runtime)
	if item_name == ITEM_SHRAPNEL_ARMOR:
		runtime.shrapnel_armor_runtime.clear_runtime(runtime)
	if item_name == ITEM_CELESTIAL_ARMOR:
		runtime.celestial_armor_runtime.clear_round_state(runtime)
	if item_name == ITEM_HERMES_SHOES:
		runtime.hermes_shoes_runtime.clear_round_state(runtime)
	elif not runtime.is_hermes_shoes_equipped():
		runtime.hermes_shoes_runtime.clear_runtime(runtime)
	if item_name == ITEM_RAINBOW_FUR_GLOVE:
		runtime.rainbow_fur_glove_runtime.clear_round_state(runtime)
	if item_name == ITEM_ADVERSITY_ARMOR:
		runtime.adversity_armor_runtime.clear_round_state(runtime)
	if item_name == ITEM_SHRAPNEL_ARMOR:
		runtime.shrapnel_armor_runtime.clear_round_state(runtime)
	if item_name == ITEM_BAAL_BOOTS:
		runtime.baal_boots_runtime.clear_round_state(runtime, registry, baal_boots_constants)
		runtime.baal_boots_runtime.try_arm_from_weather(runtime, owner, registry, "", baal_boots_constants)
	if item_name == ITEM_HORN_STRAWBERRY_MASK:
		runtime.horn_strawberry_mask_runtime.clear_on_equip(runtime)
	if item_name == ITEM_ODINS_EYE:
		runtime.odins_eye_runtime.clear_on_equip(runtime)
	if item_name == ITEM_PANDORA_LEGACY:
		runtime.pandora_legacy_runtime.clear_selection(runtime, false)


func _clear_on_unequip(
	runtime: Object,
	item_name: String,
	registry: Object,
	baal_boots_constants: Dictionary
) -> void:
	if item_name == ITEM_MEGINGJORD:
		runtime.megingjord_extra_pick_count = 0
	if item_name == ITEM_DOWSING_GOGGLES:
		runtime.dowsing_goggles_bonus_triggered = false
	if item_name == ITEM_RAGNAROK_HAMMER:
		runtime.ragnarok_runtime.clear_runtime(runtime, registry)
	if item_name == ITEM_POSEIDON_TRIDENT:
		runtime.poseidon_runtime.clear_runtime(runtime)
	if item_name == ITEM_FOUL_WHISTLE:
		runtime.foul_whistle_runtime.clear_runtime(runtime)
	if item_name == ITEM_SOUL_BURST:
		runtime.soul_burst_runtime.clear_runtime(runtime)
	if item_name == ITEM_SENSOR:
		runtime.auto_defense_runtime.clear_sensor_round_state(runtime)
	if item_name == ITEM_SMARTPHONE:
		runtime.ai_assist_runtime.clear_smartphone_runtime(runtime)
	if item_name == ITEM_VENOM_MIST_GAUNTLET and not runtime.is_venom_mist_gauntlet_equipped():
		runtime.venom_mist_runtime.clear_runtime(runtime)
	if item_name == ITEM_RAINBOW_FUR_GLOVE:
		runtime.rainbow_fur_glove_runtime.clear_runtime(runtime)
	if item_name == ITEM_ADVERSITY_ARMOR:
		runtime.adversity_armor_runtime.clear_runtime(runtime)
	if item_name == ITEM_SHRAPNEL_ARMOR:
		runtime.shrapnel_armor_runtime.clear_runtime(runtime)
	if item_name == ITEM_CELESTIAL_ARMOR:
		runtime.celestial_armor_runtime.clear_runtime(runtime)
	if item_name == ITEM_HERMES_SHOES:
		runtime.hermes_shoes_runtime.clear_runtime(runtime)
	if item_name == ITEM_BAAL_BOOTS:
		runtime.baal_boots_runtime.clear_runtime(runtime, registry, baal_boots_constants)
	if item_name == ITEM_HORN_STRAWBERRY_MASK:
		runtime.horn_strawberry_mask_runtime.clear_on_unequip(runtime)
	if item_name == ITEM_ODINS_EYE:
		runtime.odins_eye_runtime.clear_on_unequip(runtime)
	if item_name == ITEM_PANDORA_LEGACY:
		runtime.pandora_legacy_runtime.clear_runtime(runtime)


func _clear_on_remove_before_rebuild(
	runtime: Object,
	item_name: String,
	registry: Object,
	baal_boots_constants: Dictionary
) -> void:
	if item_name == ITEM_MEGINGJORD:
		runtime.megingjord_extra_pick_count = 0
	if item_name == ITEM_DOWSING_GOGGLES:
		runtime.dowsing_goggles_bonus_triggered = false
	if item_name == ITEM_RAGNAROK_HAMMER:
		runtime.ragnarok_runtime.clear_runtime(runtime, null)
	if item_name == ITEM_POSEIDON_TRIDENT:
		runtime.poseidon_runtime.clear_runtime(runtime)
	if item_name == ITEM_FOUL_WHISTLE:
		runtime.foul_whistle_runtime.clear_runtime(runtime)
	if item_name == ITEM_SENSOR:
		runtime.auto_defense_runtime.clear_sensor_round_state(runtime)
	if item_name == ITEM_SMARTPHONE:
		runtime.ai_assist_runtime.clear_smartphone_runtime(runtime)
	if item_name == ITEM_BAAL_BOOTS:
		runtime.baal_boots_runtime.clear_runtime(runtime, registry, baal_boots_constants)
	if item_name == ITEM_HORN_STRAWBERRY_MASK:
		runtime.horn_strawberry_mask_runtime.clear_on_unequip(runtime)
	if item_name == ITEM_ODINS_EYE:
		runtime.odins_eye_runtime.clear_on_unequip(runtime)
	if item_name == ITEM_PANDORA_LEGACY:
		runtime.pandora_legacy_runtime.clear_runtime(runtime)


func _clear_on_remove_after_rebuild(
	runtime: Object,
	item_name: String,
	registry: Object,
	baal_boots_constants: Dictionary
) -> void:
	if item_name == ITEM_VENOM_MIST_GAUNTLET and not runtime.is_venom_mist_gauntlet_equipped():
		runtime.venom_mist_runtime.clear_runtime(runtime)
	if item_name == ITEM_RAINBOW_FUR_GLOVE and not runtime.is_rainbow_fur_glove_equipped():
		runtime.rainbow_fur_glove_runtime.clear_runtime(runtime)
	if item_name == ITEM_ADVERSITY_ARMOR and not runtime.is_adversity_armor_equipped():
		runtime.adversity_armor_runtime.clear_runtime(runtime)
	if item_name == ITEM_SHRAPNEL_ARMOR and not runtime.is_shrapnel_armor_equipped():
		runtime.shrapnel_armor_runtime.clear_runtime(runtime)
	if item_name == ITEM_CELESTIAL_ARMOR and not runtime.is_celestial_armor_equipped():
		runtime.celestial_armor_runtime.clear_runtime(runtime)
	if item_name == ITEM_HERMES_SHOES and not runtime.is_hermes_shoes_equipped():
		runtime.hermes_shoes_runtime.clear_runtime(runtime)
	if item_name == ITEM_BAAL_BOOTS and not runtime.is_baal_boots_equipped():
		runtime.baal_boots_runtime.clear_runtime(runtime, registry, baal_boots_constants)
