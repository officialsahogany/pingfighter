extends RefCounted


func get_boss_ai_context(state: String, companion_state: String, skill_runtime_host: Object) -> Dictionary:
	if state != companion_state or skill_runtime_host == null:
		return {}
	if not skill_runtime_host.has_method("get_boss_ai_context"):
		return {}
	var context: Variant = skill_runtime_host.get_boss_ai_context()
	if context is Dictionary:
		return context
	return {}


func get_ball_collision_context(state: String, companion_state: String, skill_runtime_host: Object) -> Dictionary:
	if state != companion_state or skill_runtime_host == null:
		return {}
	if not skill_runtime_host.has_method("get_ball_collision_context"):
		return {}
	var context: Variant = skill_runtime_host.get_ball_collision_context()
	if context is Dictionary:
		return context
	return {}


func is_companion_body_drawn_in_front(
	state: String,
	companion_state: String,
	skill_runtime_host: Object,
	skill_id: String
) -> bool:
	if state != companion_state or skill_runtime_host == null:
		return false
	if not skill_runtime_host.has_method("get_companion_bind_sheet_state"):
		return false
	var bind_state: Variant = skill_runtime_host.get_companion_bind_sheet_state(skill_id)
	if bind_state is Dictionary:
		return bool(bind_state.get("active", false))
	return false


func is_companion_body_hit_suppressed(skill_runtime_host: Object, skill_id: String) -> bool:
	if skill_runtime_host == null or not skill_runtime_host.has_method("suppresses_companion_body_hit"):
		return false
	return bool(skill_runtime_host.suppresses_companion_body_hit(skill_id))


func is_companion_body_draw_suppressed(skill_runtime_host: Object, skill_id: String) -> bool:
	if skill_runtime_host == null or not skill_runtime_host.has_method("suppresses_companion_body_draw"):
		return false
	return bool(skill_runtime_host.suppresses_companion_body_draw(skill_id))


func get_active_surface_for_slot(
	profile: Object,
	active_skill_slot_resolver: Object,
	companion_skill_persistence: Object,
	companion_skill_states: Array,
	skill_runtime_host: Object,
	default_windup_seconds: float,
	slot_index: int,
	active_slot_count: int = -1
) -> Dictionary:
	if active_skill_slot_resolver == null:
		return _empty_active_surface()
	var clamped_slot: int = maxi(0, slot_index)
	var slot_count := active_slot_count if active_slot_count >= 0 else get_active_slot_count(profile, active_skill_slot_resolver, skill_runtime_host)
	if clamped_slot >= slot_count:
		return _empty_active_surface()
	var skill_state: Object = null
	if companion_skill_persistence != null:
		skill_state = companion_skill_persistence.get_state_for_slot(companion_skill_states, clamped_slot)
	return {
		"skill_id": active_skill_slot_resolver.get_skill_id_for_slot(profile, clamped_slot),
		"active_skill": active_skill_slot_resolver.get_active_skill_for_slot(profile, clamped_slot),
		"active_skill_level_fallback": _get_active_skill_level_fallback(profile, clamped_slot),
		"skill_state": skill_state,
		"windup_seconds": active_skill_slot_resolver.get_skill_windup_seconds_for_slot(
			profile,
			default_windup_seconds,
			clamped_slot
		),
	}


func get_second_active_surface(
	profile: Object,
	active_skill_slot_resolver: Object,
	companion_skill_persistence: Object,
	companion_skill_states: Array,
	skill_runtime_host: Object,
	default_windup_seconds: float,
	active_slot_count: int = -1
) -> Dictionary:
	return get_active_surface_for_slot(
		profile,
		active_skill_slot_resolver,
		companion_skill_persistence,
		companion_skill_states,
		skill_runtime_host,
		default_windup_seconds,
		1,
		active_slot_count
	)


func get_active_slot_count(
	profile: Object,
	active_skill_slot_resolver: Object,
	skill_runtime_host: Object
) -> int:
	if active_skill_slot_resolver == null:
		return 0
	if not active_skill_slot_resolver.has_method("get_active_slot_count"):
		return 0
	return maxi(0, int(active_skill_slot_resolver.get_active_slot_count(profile, skill_runtime_host)))


func get_active_skill_ids(
	profile: Object,
	active_skill_slot_resolver: Object,
	skill_runtime_host: Object
) -> Array[String]:
	var ids: Array[String] = []
	if active_skill_slot_resolver == null:
		return ids
	if not active_skill_slot_resolver.has_method("get_active_skill_ids_for_runtime"):
		return ids
	var raw_ids: Variant = active_skill_slot_resolver.get_active_skill_ids_for_runtime(profile, skill_runtime_host)
	if raw_ids is Array:
		for raw_id in raw_ids:
			ids.append(str(raw_id))
	return ids


func get_body_skill_id(
	profile: Object,
	active_skill_slot_resolver: Object,
	companion_skill_visual_resolver: Object,
	skill_runtime_host: Object,
	companion_pos: Vector2
) -> String:
	if active_skill_slot_resolver == null:
		return ""
	var active_position_owner: Dictionary = get_active_position_owner(
		profile,
		active_skill_slot_resolver,
		companion_skill_visual_resolver,
		skill_runtime_host,
		companion_pos
	)
	var primary_skill_id: String = active_skill_slot_resolver.get_skill_id_for_slot(profile, 0)
	return _get_body_skill_id_from_owner(
		companion_skill_visual_resolver,
		active_position_owner,
		primary_skill_id
	)


func get_active_position_owner(
	profile: Object,
	active_skill_slot_resolver: Object,
	companion_skill_visual_resolver: Object,
	skill_runtime_host: Object,
	companion_pos: Vector2
) -> Dictionary:
	if active_skill_slot_resolver == null:
		return {}
	var active_skill_ids: Array[String] = get_active_skill_ids(profile, active_skill_slot_resolver, skill_runtime_host)
	return get_active_position_owner_for_ids(
		active_skill_ids,
		companion_skill_visual_resolver,
		skill_runtime_host,
		companion_pos
	)


func get_active_position_owner_for_ids(
	active_skill_ids: Array[String],
	companion_skill_visual_resolver: Object,
	skill_runtime_host: Object,
	companion_pos: Vector2
) -> Dictionary:
	return _get_active_position_owner_from_ids(
		active_skill_ids,
		companion_skill_visual_resolver,
		skill_runtime_host,
		companion_pos
	)


func has_active_position_override(
	companion_skill_visual_resolver: Object,
	active_position_owner: Dictionary
) -> bool:
	if companion_skill_visual_resolver == null:
		return bool(active_position_owner.get("has", false))
	if not companion_skill_visual_resolver.has_method("has_active_position_override"):
		return bool(active_position_owner.get("has", false))
	return bool(companion_skill_visual_resolver.has_active_position_override(active_position_owner))


func get_visual_surface(
	profile: Object,
	active_skill_slot_resolver: Object,
	companion_skill_visual_resolver: Object,
	companion_skill_persistence: Object,
	companion_skill_states: Array,
	skill_runtime_host: Object,
	companion_pos: Vector2,
	default_windup_seconds: float
) -> Dictionary:
	if active_skill_slot_resolver == null:
		return _empty_visual_surface()
	var active_skill_ids: Array[String] = get_active_skill_ids(profile, active_skill_slot_resolver, skill_runtime_host)
	var visual_slot: int = 0
	if companion_skill_visual_resolver != null:
		visual_slot = maxi(0, int(companion_skill_visual_resolver.get_active_visual_slot_index(
			active_skill_ids,
			companion_skill_states,
			skill_runtime_host
		)))
	var active_position_owner: Dictionary = {}
	var has_position_override := false
	active_position_owner = _get_active_position_owner_from_ids(
		active_skill_ids,
		companion_skill_visual_resolver,
		skill_runtime_host,
		companion_pos
	)
	has_position_override = has_active_position_override(
		companion_skill_visual_resolver,
		active_position_owner
	)
	var primary_skill_id: String = active_skill_slot_resolver.get_skill_id_for_slot(profile, 0)
	var body_skill_id: String = _get_body_skill_id_from_owner(
		companion_skill_visual_resolver,
		active_position_owner,
		primary_skill_id
	)
	var visual_surface: Dictionary = get_active_surface_for_slot(
		profile,
		active_skill_slot_resolver,
		companion_skill_persistence,
		companion_skill_states,
		skill_runtime_host,
		default_windup_seconds,
		visual_slot
	)
	visual_surface["active_skill_ids"] = active_skill_ids
	visual_surface["visual_slot"] = visual_slot
	visual_surface["skill_id"] = active_skill_slot_resolver.get_skill_id_for_slot(profile, visual_slot)
	visual_surface["primary_skill_id"] = primary_skill_id
	visual_surface["body_skill_id"] = body_skill_id
	visual_surface["active_position_owner"] = active_position_owner
	visual_surface["has_active_position_override"] = has_position_override
	return visual_surface


func consume_companion_strike_request(skill_runtime_host: Object, skill_id: String) -> bool:
	if skill_runtime_host == null or not skill_runtime_host.has_method("consume_companion_strike_request"):
		return false
	return bool(skill_runtime_host.consume_companion_strike_request(skill_id))


func notify_lingpet_bone_barrier_hit(
	skill_runtime_host: Object,
	barrier_id: int,
	impact_pos: Vector2,
	next_ball_vel: Vector2,
	built: bool,
	registry: Object
) -> bool:
	if skill_runtime_host == null or not skill_runtime_host.has_method("notify_lingpet_bone_barrier_hit"):
		return false
	return bool(skill_runtime_host.notify_lingpet_bone_barrier_hit(barrier_id, impact_pos, next_ball_vel, built, registry))


func _empty_active_surface() -> Dictionary:
	return {
		"skill_id": "",
		"active_skill": {},
		"active_skill_level_fallback": 0,
		"skill_state": null,
		"windup_seconds": 0.0,
	}


func _empty_visual_surface() -> Dictionary:
	var result: Dictionary = _empty_active_surface()
	result["active_skill_ids"] = []
	result["visual_slot"] = 0
	result["skill_id"] = ""
	result["primary_skill_id"] = ""
	result["body_skill_id"] = ""
	result["active_position_owner"] = {}
	result["has_active_position_override"] = false
	return result


func _get_active_position_owner_from_ids(
	active_skill_ids: Array[String],
	companion_skill_visual_resolver: Object,
	skill_runtime_host: Object,
	companion_pos: Vector2
) -> Dictionary:
	if companion_skill_visual_resolver == null:
		return {}
	if not companion_skill_visual_resolver.has_method("get_active_position_override_owner"):
		return {}
	var owner: Variant = companion_skill_visual_resolver.get_active_position_override_owner(
		active_skill_ids,
		skill_runtime_host,
		companion_pos
	)
	if owner is Dictionary:
		return owner
	return {}


func _get_active_skill_level_fallback(profile: Object, slot_index: int) -> int:
	if profile == null:
		return 0
	if not profile.has_method("get_active_skill_level_for_slot"):
		return 0
	return maxi(0, int(profile.call("get_active_skill_level_for_slot", slot_index)))


func _get_body_skill_id_from_owner(
	companion_skill_visual_resolver: Object,
	active_position_owner: Dictionary,
	primary_skill_id: String
) -> String:
	if companion_skill_visual_resolver == null:
		return primary_skill_id
	if not companion_skill_visual_resolver.has_method("get_companion_body_skill_id"):
		return primary_skill_id
	return str(companion_skill_visual_resolver.get_companion_body_skill_id(
		active_position_owner,
		primary_skill_id
	))
