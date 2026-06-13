extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

var _active_item_catalog: Object = ActiveItemCatalog.new()
var _mythic_item_catalog: Object = MythicItemCatalog.new()
var _perk_catalog: Object = RuntimePerkCatalog.new()


func build_progress_snapshot(owner: Object, registry: Object, stage_id: int) -> Dictionary:
	return {
		"stage": max(1, stage_id),
		"active_item_slots": _get_active_item_slots(owner),
		"passive_item_inventory": _get_passive_item_inventory(owner, registry),
		"runtime_perk_levels": _get_runtime_perk_levels(owner, registry),
	}


func build_stage_reward_snapshot(
	owner: Object,
	registry: Object,
	stage_id: int,
	stage_start_snapshot: Dictionary
) -> Dictionary:
	var baseline: Dictionary = stage_start_snapshot
	if int(baseline.get("stage", 0)) != stage_id:
		baseline = {
			"stage": stage_id,
			"active_item_slots": [],
			"passive_item_inventory": [],
			"runtime_perk_levels": {},
		}

	var active_items: Array = []
	for item_value in _get_active_item_slots(owner):
		if item_value is Dictionary:
			var active_item: Dictionary = _build_item_reward(item_value as Dictionary, "active", "remaining_active")
			if not active_item.is_empty():
				active_items.append(active_item)

	var passive_items: Array = []
	var baseline_inventory: Array = _get_array(baseline.get("passive_item_inventory", []))
	var baseline_counts: Dictionary = _build_item_identity_counts(baseline_inventory)
	for item_value in _get_passive_item_inventory(owner, registry):
		if not (item_value is Dictionary):
			continue
		var item_data: Dictionary = item_value
		var identity: String = _get_item_identity(item_data)
		var remaining_count: int = int(baseline_counts.get(identity, 0))
		if remaining_count > 0:
			baseline_counts[identity] = remaining_count - 1
			continue
		var reward_type: String = "mythic" if _is_mythic_item(item_data) else "passive"
		var passive_item: Dictionary = _build_item_reward(item_data, reward_type, "stage_passive")
		if not passive_item.is_empty():
			passive_items.append(passive_item)

	var perks: Array = []
	var baseline_levels: Dictionary = _get_dictionary(baseline.get("runtime_perk_levels", {}))
	var current_levels: Dictionary = _get_runtime_perk_levels(owner, registry)
	for perk_id_value in current_levels.keys():
		var perk_id: String = str(perk_id_value)
		var current_level: int = int(current_levels.get(perk_id_value, 0))
		var baseline_level: int = int(baseline_levels.get(perk_id, baseline_levels.get(perk_id_value, 0)))
		if current_level <= baseline_level:
			continue
		var perk_reward: Dictionary = _build_perk_reward(perk_id, baseline_level, current_level)
		if not perk_reward.is_empty():
			perks.append(perk_reward)

	return {
		"stage": stage_id,
		"active_items": active_items,
		"passive_items": passive_items,
		"perks": perks,
	}


func _build_item_identity_counts(items: Array) -> Dictionary:
	var counts: Dictionary = {}
	for item_value in items:
		if not (item_value is Dictionary):
			continue
		var key: String = _get_item_identity(item_value as Dictionary)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _get_item_identity(item_data: Dictionary) -> String:
	var inventory_id: int = int(item_data.get("_inventory_id", 0))
	if inventory_id > 0:
		return "inventory:%d" % inventory_id
	var item_name: String = _get_item_name(item_data)
	if item_name != "":
		return "name:%s" % item_name
	var label: String = str(item_data.get("display_name", item_data.get("label", "")))
	if label != "":
		return "label:%s" % label
	return "unknown:%s" % str(item_data)


func _build_item_reward(item_data: Dictionary, reward_type: String, source: String) -> Dictionary:
	var item_name: String = _get_item_name(item_data)
	var enriched: Dictionary = item_data.duplicate(true)
	if item_name != "":
		var catalog_data: Dictionary = _build_catalog_item_data(item_name, reward_type)
		if not catalog_data.is_empty():
			catalog_data.merge(enriched, true)
			enriched = catalog_data
	var label: String = _get_item_label(enriched, item_name, reward_type)
	var icon_path: String = str(enriched.get("icon_path", ""))
	return {
		"type": reward_type,
		"label": label,
		"item_name": item_name,
		"icon_path": icon_path,
		"amount": 1,
		"source": source,
		"item_data": enriched,
	}


func _build_catalog_item_data(item_name: String, reward_type: String) -> Dictionary:
	if reward_type == "active":
		if _active_item_catalog != null and _active_item_catalog.has_method("build_item_by_name"):
			var active_value: Variant = _active_item_catalog.build_item_by_name(item_name)
			if active_value is Dictionary:
				return (active_value as Dictionary).duplicate(true)
	else:
		if _mythic_item_catalog != null and _mythic_item_catalog.has_method("build_item_by_name"):
			var mythic_value: Variant = _mythic_item_catalog.build_item_by_name(item_name)
			if mythic_value is Dictionary:
				return (mythic_value as Dictionary).duplicate(true)
	return {}


func _get_item_label(item_data: Dictionary, item_name: String, reward_type: String) -> String:
	if reward_type != "active" and _mythic_item_catalog != null and _mythic_item_catalog.has_method("format_item_display_name"):
		var formatted: String = str(_mythic_item_catalog.format_item_display_name(item_data))
		if formatted != "":
			return formatted
	var display_name: String = str(item_data.get("display_name", item_data.get("label", "")))
	if display_name != "":
		return display_name
	if reward_type == "active" and _active_item_catalog != null and _active_item_catalog.has_method("get_display_name") and item_name != "":
		return str(_active_item_catalog.get_display_name(item_name))
	if reward_type != "active" and _mythic_item_catalog != null and _mythic_item_catalog.has_method("get_display_name") and item_name != "":
		return str(_mythic_item_catalog.get_display_name(item_name))
	return item_name


func _build_perk_reward(perk_id: String, baseline_level: int, current_level: int) -> Dictionary:
	if perk_id == "" or current_level <= baseline_level:
		return {}
	var perk_data: Dictionary = {}
	if _perk_catalog != null and _perk_catalog.has_method("get_perk_data"):
		var perk_value: Variant = _perk_catalog.get_perk_data(perk_id)
		if perk_value is Dictionary:
			perk_data = (perk_value as Dictionary).duplicate(true)
	var perk_name: String = str(perk_data.get("name", perk_id))
	var label: String = "%s Lv.%d" % [perk_name, current_level]
	if current_level - baseline_level > 1:
		label = "%s +%d" % [label, current_level - baseline_level]
	return {
		"type": "perk",
		"label": label,
		"perk_id": perk_id,
		"id": perk_id,
		"current_level": baseline_level,
		"next_level": current_level,
		"level_delta": current_level - baseline_level,
		"source": "stage_perk",
		"perk_data": perk_data,
	}


func _get_active_item_slots(owner: Object) -> Array:
	if owner == null:
		return []
	var value: Variant = owner.get("active_item_slots")
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _get_passive_item_inventory(owner: Object, registry: Object) -> Array:
	var mythic_item_runtime: Object = _get_cached_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_snapshot"):
		var snapshot_value: Variant = mythic_item_runtime.get_snapshot()
		if snapshot_value is Dictionary:
			var inventory_value: Variant = (snapshot_value as Dictionary).get("inventory_items", [])
			if inventory_value is Array:
				return (inventory_value as Array).duplicate(true)
	if owner != null:
		var owner_value: Variant = owner.get("passive_item_inventory")
		if owner_value is Array:
			return (owner_value as Array).duplicate(true)
	return []


func _get_runtime_perk_levels(owner: Object, registry: Object) -> Dictionary:
	var runtime_perk_state: Object = _get_cached_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_snapshot"):
		var snapshot_value: Variant = runtime_perk_state.get_snapshot()
		if snapshot_value is Dictionary:
			var levels_value: Variant = (snapshot_value as Dictionary).get("runtime_skill_levels", {})
			if levels_value is Dictionary:
				return (levels_value as Dictionary).duplicate(true)
	if owner != null:
		var owner_value: Variant = owner.get("runtime_perk_levels")
		if owner_value is Dictionary:
			return (owner_value as Dictionary).duplicate(true)
	return {}


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "":
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
		return null
	if registry.has_method("get_instance"):
		return registry.get_instance(key)
	return null


func _get_item_name(item_data: Dictionary) -> String:
	var item_name: String = str(item_data.get("name", ""))
	if item_name != "":
		return item_name
	return str(item_data.get("item_name", item_data.get("effect", "")))


func _is_mythic_item(item_data: Dictionary) -> bool:
	return str(item_data.get("type", "")) == "mythic" or str(item_data.get("rarity", "")) == "mythic"


func _get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
