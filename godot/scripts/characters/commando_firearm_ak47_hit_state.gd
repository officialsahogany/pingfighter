extends RefCounted


static func build_accumulated_damage_payload(
	weapon_id: String,
	current_hit_count: int,
	current_damage_units: int,
	damage_hit_threshold: int
) -> Dictionary:
	if weapon_id != "ak47":
		return {}
	var next_hit_count: int = max(0, current_hit_count) + 1
	var threshold: int = max(1, damage_hit_threshold)
	var result_fields: Dictionary = {}
	if next_hit_count < threshold:
		result_fields["ak47_boss_hit_count"] = next_hit_count
		return {
			"next_hit_count": next_hit_count,
			"result_fields": result_fields,
		}
	next_hit_count = 0
	result_fields["ak47_boss_hit_count"] = 0
	result_fields["ak47_accumulated_damage_ready"] = true
	result_fields["damage_units"] = max(1, current_damage_units)
	return {
		"next_hit_count": next_hit_count,
		"result_fields": result_fields,
	}


static func apply_runtime_accumulated_damage(
	weapon_id: String,
	result: Dictionary,
	current_hit_count: int,
	damage_hit_threshold: int
) -> Dictionary:
	var hit_payload: Dictionary = build_accumulated_damage_payload(
		weapon_id,
		current_hit_count,
		int(result.get("damage_units", 0)),
		damage_hit_threshold
	)
	if hit_payload.is_empty():
		return {}
	result.merge(_get_dict(hit_payload.get("result_fields", {})), true)
	return {
		"next_hit_count": int(hit_payload.get("next_hit_count", current_hit_count)),
	}


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
