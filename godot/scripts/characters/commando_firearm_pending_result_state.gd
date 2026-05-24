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


static func queue_runtime_combat_result(target: Object, combat_result: Dictionary) -> void:
	if target == null:
		return
	var damage_state: Dictionary = queue_boss_damage_state(
		int(target.get("pending_boss_damage_units")),
		_get_array(target.get("pending_boss_damage_sources")),
		combat_result
	)
	target.set("pending_boss_damage_units", int(damage_state.get("units", target.get("pending_boss_damage_units"))))
	target.set("pending_boss_damage_sources", _get_array(damage_state.get("sources", target.get("pending_boss_damage_sources"))))
	var gauge_state: Dictionary = queue_special_gauge_state(
		float(target.get("pending_special_gauge_gain")),
		_get_array(target.get("pending_special_gauge_sources")),
		str(target.get("pending_special_gauge_hit_kind")),
		float(target.get("pending_pistol_feedback_timer_frames")),
		combat_result
	)
	target.set("pending_special_gauge_gain", float(gauge_state.get("gain", target.get("pending_special_gauge_gain"))))
	target.set("pending_special_gauge_sources", _get_array(gauge_state.get("sources", target.get("pending_special_gauge_sources"))))
	target.set("pending_special_gauge_hit_kind", str(gauge_state.get("hit_kind", target.get("pending_special_gauge_hit_kind"))))
	target.set("pending_pistol_feedback_timer_frames", float(gauge_state.get(
		"feedback_timer_frames",
		target.get("pending_pistol_feedback_timer_frames")
	)))


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


static func consume_runtime_pending_results(target: Object) -> Dictionary:
	if target == null:
		return {}
	var result: Dictionary = {}
	var damage_result: Dictionary = build_boss_damage_result(
		int(target.get("pending_boss_damage_units")),
		_get_array(target.get("pending_boss_damage_sources"))
	)
	if not damage_result.is_empty():
		result.merge(damage_result, true)
		target.set("pending_boss_damage_units", 0)
		target.set("pending_boss_damage_sources", [])
	var gauge_result: Dictionary = build_special_gauge_result(
		float(target.get("pending_special_gauge_gain")),
		_get_array(target.get("pending_special_gauge_sources")),
		str(target.get("pending_special_gauge_hit_kind")),
		float(target.get("pending_pistol_feedback_timer_frames"))
	)
	if not gauge_result.is_empty():
		result.merge(gauge_result, true)
		target.set("pending_special_gauge_gain", 0.0)
		target.set("pending_special_gauge_sources", [])
		target.set("pending_special_gauge_hit_kind", "")
		target.set("pending_pistol_feedback_timer_frames", 0.0)
	return result


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
