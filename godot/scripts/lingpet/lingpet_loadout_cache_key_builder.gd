extends RefCounted


func build_key(pet_id: String, loadout: Dictionary, reward_signature: String) -> String:
	return "%s|%s|%s|%s|%s|%s" % [
		pet_id,
		slot_signature(loadout, "active_skill_ids", "active_skill_levels"),
		str(loadout.get("active_slot_count", 1)),
		slot_signature(loadout, "passive_skill_ids", "passive_skill_levels"),
		str(loadout.get("passive_slot_count", 1)),
		reward_signature,
	]


func slot_signature(loadout: Dictionary, ids_key: String, levels_key: String) -> String:
	var raw_ids: Variant = loadout.get(ids_key, [])
	var raw_levels: Variant = loadout.get(levels_key, {})
	var levels: Dictionary = raw_levels if raw_levels is Dictionary else {}
	var parts: Array[String] = []
	if raw_ids is Array:
		for raw_id in raw_ids as Array:
			var skill_id := str(raw_id)
			if skill_id != "":
				parts.append("%s:%d" % [skill_id, int(levels.get(skill_id, 0))])
	return ",".join(parts)
