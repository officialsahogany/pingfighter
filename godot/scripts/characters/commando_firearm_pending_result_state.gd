extends RefCounted


static func queue_boss_damage_state(
	current_units: int,
	current_sources: Array,
	combat_result: Dictionary
) -> Dictionary:
	var damage_units: int = max(0, int(combat_result.get("damage_units", 0)))
	if damage_units <= 0:
		return {
			"units": current_units,
			"sources": current_sources.duplicate(true),
		}
	var next_sources: Array = current_sources.duplicate(true)
	var damage_sources: Array = _get_array(combat_result.get("damage_sources", []))
	if not damage_sources.is_empty():
		for value in damage_sources:
			var damage_source := str(value)
			if damage_source != "" and not next_sources.has(damage_source):
				next_sources.append(damage_source)
	else:
		var source: String = str(combat_result.get("source", "commando_firearm"))
		if source != "" and not next_sources.has(source):
			next_sources.append(source)
	return {
		"units": current_units + damage_units,
		"sources": next_sources,
	}


static func queue_special_gauge_state(
	current_gain: float,
	current_sources: Array,
	current_hit_kind: String,
	current_feedback_timer_frames: float,
	combat_result: Dictionary
) -> Dictionary:
	var gauge_gain: float = max(0.0, float(combat_result.get("commando_firearm_special_gauge_gain", 0.0)))
	if gauge_gain <= 0.0:
		return {
			"gain": current_gain,
			"sources": current_sources.duplicate(true),
			"hit_kind": current_hit_kind,
			"feedback_timer_frames": current_feedback_timer_frames,
		}
	var next_sources: Array = current_sources.duplicate(true)
	var source: String = str(combat_result.get(
		"commando_firearm_special_gauge_source",
		combat_result.get("source", "commando_firearm")
	))
	if source != "" and not next_sources.has(source):
		next_sources.append(source)
	return {
		"gain": current_gain + gauge_gain,
		"sources": next_sources,
		"hit_kind": str(combat_result.get("commando_firearm_pistol_hit_kind", current_hit_kind)),
		"feedback_timer_frames": max(
			current_feedback_timer_frames,
			float(combat_result.get("commando_firearm_pistol_feedback_timer_frames", 0.0))
		),
	}


static func build_boss_damage_result(units: int, sources: Array) -> Dictionary:
	if units <= 0:
		return {}
	return {
		"commando_firearm_boss_damage_units": units,
		"commando_firearm_boss_damage_sources": sources.duplicate(true),
		"commando_firearm_last_damage_source": str(sources.back()) if not sources.is_empty() else "commando_firearm",
	}


static func build_special_gauge_result(
	gain: float,
	sources: Array,
	hit_kind: String,
	feedback_timer_frames: float
) -> Dictionary:
	if gain <= 0.0:
		return {}
	return {
		"commando_firearm_special_gauge_gain": gain,
		"commando_firearm_special_gauge_sources": sources.duplicate(true),
		"commando_firearm_last_gauge_source": str(sources.back()) if not sources.is_empty() else "commando_firearm",
		"commando_firearm_last_pistol_hit_kind": hit_kind,
		"commando_firearm_pistol_feedback_timer_frames": feedback_timer_frames,
	}


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
