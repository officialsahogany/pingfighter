extends RefCounted


static func build_active_item_rewards(
	active_item_slots: Array,
	active_item_catalog: Object,
	mythic_item_catalog: Object
) -> Array:
	var rewards: Array = []
	for item_value in active_item_slots:
		if item_value is Dictionary:
			var active_item: Dictionary = build_item_reward(
				item_value as Dictionary,
				"active",
				"remaining_active",
				active_item_catalog,
				mythic_item_catalog
			)
			if not active_item.is_empty():
				rewards.append(active_item)
	return rewards


static func build_new_passive_item_rewards(
	passive_item_inventory: Array,
	baseline_inventory: Array,
	active_item_catalog: Object,
	mythic_item_catalog: Object
) -> Array:
	var rewards: Array = []
	var baseline_counts: Dictionary = build_item_identity_counts(baseline_inventory)
	for item_value in passive_item_inventory:
		if not (item_value is Dictionary):
			continue
		var item_data: Dictionary = item_value
		var identity: String = get_item_identity(item_data)
		var remaining_count: int = int(baseline_counts.get(identity, 0))
		if remaining_count > 0:
			baseline_counts[identity] = remaining_count - 1
			continue
		var reward_type: String = "mythic" if is_mythic_item(item_data) else "passive"
		var passive_item: Dictionary = build_item_reward(
			item_data,
			reward_type,
			"stage_passive",
			active_item_catalog,
			mythic_item_catalog
		)
		if not passive_item.is_empty():
			rewards.append(passive_item)
	return rewards


static func build_item_identity_counts(items: Array) -> Dictionary:
	var counts: Dictionary = {}
	for item_value in items:
		if not (item_value is Dictionary):
			continue
		var key: String = get_item_identity(item_value as Dictionary)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


static func get_item_identity(item_data: Dictionary) -> String:
	var inventory_id: int = int(item_data.get("_inventory_id", 0))
	if inventory_id > 0:
		return "inventory:%d" % inventory_id
	var item_name: String = get_item_name(item_data)
	if item_name != "":
		return "name:%s" % item_name
	var label: String = str(item_data.get("display_name", item_data.get("label", "")))
	if label != "":
		return "label:%s" % label
	return "unknown:%s" % str(item_data)


static func build_item_reward(
	item_data: Dictionary,
	reward_type: String,
	source: String,
	active_item_catalog: Object,
	mythic_item_catalog: Object
) -> Dictionary:
	var item_name: String = get_item_name(item_data)
	var enriched: Dictionary = item_data.duplicate(true)
	if item_name != "":
		var catalog_data: Dictionary = build_catalog_item_data(
			item_name,
			reward_type,
			active_item_catalog,
			mythic_item_catalog
		)
		if not catalog_data.is_empty():
			catalog_data.merge(enriched, true)
			enriched = catalog_data
	var label: String = get_item_label(enriched, item_name, reward_type, active_item_catalog, mythic_item_catalog)
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


static func build_catalog_item_data(
	item_name: String,
	reward_type: String,
	active_item_catalog: Object,
	mythic_item_catalog: Object
) -> Dictionary:
	if reward_type == "active":
		if active_item_catalog != null and active_item_catalog.has_method("build_item_by_name"):
			var active_value: Variant = active_item_catalog.build_item_by_name(item_name)
			if active_value is Dictionary:
				return (active_value as Dictionary).duplicate(true)
	else:
		if mythic_item_catalog != null and mythic_item_catalog.has_method("build_item_by_name"):
			var mythic_value: Variant = mythic_item_catalog.build_item_by_name(item_name)
			if mythic_value is Dictionary:
				return (mythic_value as Dictionary).duplicate(true)
	return {}


static func get_item_label(
	item_data: Dictionary,
	item_name: String,
	reward_type: String,
	active_item_catalog: Object,
	mythic_item_catalog: Object
) -> String:
	if reward_type != "active" and mythic_item_catalog != null and mythic_item_catalog.has_method("format_item_display_name"):
		var formatted: String = str(mythic_item_catalog.format_item_display_name(item_data))
		if formatted != "":
			return formatted
	var display_name: String = str(item_data.get("display_name", item_data.get("label", "")))
	if display_name != "":
		return display_name
	if reward_type == "active" and active_item_catalog != null and active_item_catalog.has_method("get_display_name") and item_name != "":
		return str(active_item_catalog.get_display_name(item_name))
	if reward_type != "active" and mythic_item_catalog != null and mythic_item_catalog.has_method("get_display_name") and item_name != "":
		return str(mythic_item_catalog.get_display_name(item_name))
	return item_name


static func get_item_name(item_data: Dictionary) -> String:
	var item_name: String = str(item_data.get("name", ""))
	if item_name != "":
		return item_name
	return str(item_data.get("item_name", item_data.get("effect", "")))


static func is_mythic_item(item_data: Dictionary) -> bool:
	return str(item_data.get("type", "")) == "mythic" or str(item_data.get("rarity", "")) == "mythic"
