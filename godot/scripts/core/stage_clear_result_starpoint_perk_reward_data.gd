extends RefCounted


static func build_box_perk_choice_reward(snapshot: Dictionary, perk_catalog: Object) -> Dictionary:
	var choice_value: Variant = snapshot.get("last_selected_choice", {})
	var choice: Dictionary = choice_value if choice_value is Dictionary else {}
	var perk_id: String = str(choice.get("id", snapshot.get("last_selected_id", "")))
	if perk_id == "":
		return {}
	var runtime_levels: Dictionary = _get_dictionary(snapshot.get("runtime_skill_levels", {}))
	var current_level: int = max(0, int(choice.get("current_level", 0)))
	var next_level: int = int(choice.get("next_level", runtime_levels.get(perk_id, 0)))
	if next_level > 0 and current_level <= 0:
		current_level = max(0, next_level - 1)
	var perk_data: Dictionary = _build_perk_data(perk_id, choice, perk_catalog)
	var perk_name: String = str(perk_data.get("name", choice.get("name", perk_id)))
	var label: String = perk_name
	if next_level > 0:
		label = "%s Lv.%d" % [perk_name, next_level]
	return {
		"type": "perk",
		"label": label,
		"perk_id": perk_id,
		"id": perk_id,
		"current_level": current_level,
		"next_level": max(1, next_level),
		"level_delta": max(1, int(choice.get("level_delta", max(1, next_level - current_level)))),
		"source": "box_starpoint_choice",
		"perk_data": perk_data,
	}


static func get_runtime_perk_snapshot(runtime_perk_state: Object) -> Dictionary:
	if runtime_perk_state != null and runtime_perk_state.has_method("get_snapshot"):
		var snapshot_value: Variant = runtime_perk_state.get_snapshot()
		if snapshot_value is Dictionary:
			return (snapshot_value as Dictionary).duplicate(true)
	return {}


static func get_runtime_perk_choice_sequence(runtime_perk_state: Object) -> int:
	var snapshot: Dictionary = get_runtime_perk_snapshot(runtime_perk_state)
	return int(snapshot.get("selected_choice_sequence", 0))


static func _build_perk_data(perk_id: String, choice: Dictionary, perk_catalog: Object) -> Dictionary:
	var perk_data: Dictionary = {}
	if perk_catalog != null and perk_catalog.has_method("get_perk_data"):
		var perk_value: Variant = perk_catalog.get_perk_data(perk_id)
		if perk_value is Dictionary:
			perk_data = (perk_value as Dictionary).duplicate(true)
	for key in ["id", "name", "description", "detail", "icon_color", "character_restriction"]:
		if str(perk_data.get(key, "")) == "" and choice.has(key):
			perk_data[key] = choice.get(key)
	if str(perk_data.get("id", "")) == "":
		perk_data["id"] = perk_id
	return perk_data


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
