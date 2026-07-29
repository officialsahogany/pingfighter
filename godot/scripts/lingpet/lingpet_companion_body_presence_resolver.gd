extends RefCounted


func is_available_for_hit(
	ring_dash_override_active: bool,
	ring_dash_visual_hidden: bool,
	active_skill_override_active: bool,
	starlight_override_active: bool,
	motion_visible: bool
) -> bool:
	if ring_dash_override_active:
		return not ring_dash_visual_hidden
	if active_skill_override_active:
		return true
	if starlight_override_active:
		return true
	return motion_visible


func is_available_for_hit_from_surface(
	visual_surface: Dictionary,
	ring_dash_state: Object,
	starlight_tracking_state: Object,
	motion_state: Object
) -> bool:
	return is_available_for_hit(
		_has_companion_position_override(ring_dash_state),
		_is_ring_dash_visual_hidden(ring_dash_state),
		bool(visual_surface.get("has_active_position_override", false)),
		_has_companion_position_override(starlight_tracking_state),
		_get_motion_visible(motion_state)
	)


func is_visible_for_draw(
	ring_dash_visual_hidden: bool,
	motion_visible: bool,
	active_skill_override_active: bool,
	ring_dash_override_active: bool,
	starlight_override_active: bool
) -> bool:
	if ring_dash_visual_hidden:
		return false
	return (
		motion_visible
		or active_skill_override_active
		or ring_dash_override_active
		or starlight_override_active
	)


func is_visible_for_draw_from_surface(
	visual_surface: Dictionary,
	ring_dash_state: Object,
	starlight_tracking_state: Object,
	motion_state: Object
) -> bool:
	return is_visible_for_draw(
		_is_ring_dash_visual_hidden(ring_dash_state),
		_get_motion_visible(motion_state),
		bool(visual_surface.get("has_active_position_override", false)),
		_has_companion_position_override(ring_dash_state),
		_has_companion_position_override(starlight_tracking_state)
	)


func can_begin_click_reaction(motion_state: Object, ring_dash_state: Object) -> bool:
	return _get_motion_visible(motion_state) and not _is_ring_dash_visual_hidden(ring_dash_state)


func is_click_reaction_visible(
	click_reaction_active: bool,
	click_reaction_texture: Object,
	ring_dash_state: Object
) -> bool:
	return click_reaction_active and click_reaction_texture != null and not _is_ring_dash_visual_hidden(ring_dash_state)


func is_front_pass_body_active(
	state: String,
	companion_state: String,
	skill_runtime_surface: Object,
	skill_runtime_host: Object,
	body_skill_id: String
) -> bool:
	if skill_runtime_surface == null:
		return false
	if not skill_runtime_surface.has_method("is_companion_body_drawn_in_front"):
		return false
	return bool(skill_runtime_surface.is_companion_body_drawn_in_front(
		state,
		companion_state,
		skill_runtime_host,
		body_skill_id
	))


func get_draw_motion_speed_ratio_from_sources(
	active_skill_ids: Array[String],
	companion_pos: Vector2,
	skill_runtime_host: Object,
	skill_visual_resolver: Object,
	ring_dash_state: Object,
	starlight_tracking_state: Object,
	motion_visible: bool,
	motion_style: String,
	motion_speed_ratio: float,
	override_move_ratio: float,
	sortie_flap_min_speed_ratio: float
) -> float:
	var active_skill_override_active := false
	if skill_visual_resolver != null and skill_visual_resolver.has_method("get_active_position_override_owner"):
		var override_owner: Variant = skill_visual_resolver.get_active_position_override_owner(
			active_skill_ids,
			skill_runtime_host,
			companion_pos
		)
		if override_owner is Dictionary:
			if skill_visual_resolver.has_method("has_active_position_override"):
				active_skill_override_active = bool(skill_visual_resolver.has_active_position_override(override_owner))
			else:
				active_skill_override_active = bool((override_owner as Dictionary).get("has", false))
	# Patrol / free-flight walk-idle gate: drive it from the ACTUAL drawn horizontal movement,
	# NOT the motion state's INTENDED speed. motion_speed_ratio (derived from patrol_speed /
	# defense step speed) can stay > 0.01 on a frame where the position does NOT actually
	# advance -- defense intercept arriving at a lane-clamped target, a zero/negative-delta tick,
	# sub-tolerance re-anchoring -- which marches the move sheet in place. The distance-roll state's
	# override move ratio is the real per-frame x-travel of the companion position, so a genuinely
	# static companion reads idle while real patrol/defense travel still reads as walking. Sortie
	# flight keeps its wing-flap floor above; ring-dash / not-visible already returned 0 above.
	return get_draw_motion_speed_ratio(
		active_skill_override_active,
		_has_companion_position_override(ring_dash_state),
		_has_companion_position_override(starlight_tracking_state),
		motion_visible,
		motion_style,
		motion_speed_ratio,
		override_move_ratio,
		sortie_flap_min_speed_ratio
	)


func get_draw_motion_speed_ratio_from_runtime(
	profile: Object,
	active_skill_slot_resolver: Object,
	companion_pos: Vector2,
	skill_runtime_host: Object,
	skill_visual_resolver: Object,
	ring_dash_state: Object,
	starlight_tracking_state: Object,
	motion_state: Object,
	distance_roll_state: Object,
	sortie_flap_min_speed_ratio: float
) -> float:
	return get_draw_motion_speed_ratio_from_sources(
		_get_active_skill_ids(profile, active_skill_slot_resolver, skill_runtime_host),
		companion_pos,
		skill_runtime_host,
		skill_visual_resolver,
		ring_dash_state,
		starlight_tracking_state,
		_get_motion_visible(motion_state),
		_get_motion_style(profile),
		_get_motion_speed_ratio(motion_state),
		_get_override_move_ratio(distance_roll_state),
		sortie_flap_min_speed_ratio
	)


func get_draw_motion_speed_ratio_from_surface(
	visual_surface: Dictionary,
	profile: Object,
	ring_dash_state: Object,
	starlight_tracking_state: Object,
	motion_state: Object,
	distance_roll_state: Object,
	sortie_flap_min_speed_ratio: float
) -> float:
	return get_draw_motion_speed_ratio(
		bool(visual_surface.get("has_active_position_override", false)),
		_has_companion_position_override(ring_dash_state),
		_has_companion_position_override(starlight_tracking_state),
		_get_motion_visible(motion_state),
		_get_motion_style(profile),
		_get_motion_speed_ratio(motion_state),
		_get_override_move_ratio(distance_roll_state),
		sortie_flap_min_speed_ratio
	)


func get_draw_motion_speed_ratio(
	active_skill_override_active: bool,
	ring_dash_override_active: bool,
	starlight_override_active: bool,
	motion_visible: bool,
	motion_style: String,
	motion_speed_ratio: float,
	override_move_ratio: float,
	sortie_flap_min_speed_ratio: float
) -> float:
	if active_skill_override_active:
		return override_move_ratio
	if ring_dash_override_active:
		return 0.0
	if starlight_override_active:
		return override_move_ratio
	if not motion_visible:
		return 0.0
	if motion_style == "sortie_flight":
		return maxf(sortie_flap_min_speed_ratio, motion_speed_ratio)
	return override_move_ratio


func _has_companion_position_override(source: Object) -> bool:
	if source == null or not source.has_method("has_companion_position_override"):
		return false
	return bool(source.has_companion_position_override())


func _is_ring_dash_visual_hidden(ring_dash_state: Object) -> bool:
	if ring_dash_state == null or not ring_dash_state.has_method("is_companion_visual_hidden"):
		return false
	return bool(ring_dash_state.is_companion_visual_hidden())


func _get_active_skill_ids(profile: Object, active_skill_slot_resolver: Object, skill_runtime_host: Object) -> Array[String]:
	var ids: Array[String] = []
	if active_skill_slot_resolver == null or not active_skill_slot_resolver.has_method("get_active_skill_ids_for_runtime"):
		return ids
	var raw_ids: Variant = active_skill_slot_resolver.get_active_skill_ids_for_runtime(profile, skill_runtime_host)
	if raw_ids is Array:
		for raw_id in raw_ids:
			ids.append(str(raw_id))
	return ids


func _get_motion_visible(motion_state: Object) -> bool:
	return motion_state != null and bool(motion_state.motion_visible)


func _get_motion_style(profile: Object) -> String:
	if profile == null or not profile.has_method("get_motion_style"):
		return ""
	return str(profile.get_motion_style())


func _get_motion_speed_ratio(motion_state: Object) -> float:
	if motion_state == null:
		return 0.0
	return float(motion_state.motion_speed_ratio)


func _get_override_move_ratio(distance_roll_state: Object) -> float:
	if distance_roll_state == null or not distance_roll_state.has_method("get_override_move_ratio"):
		return 0.0
	return float(distance_roll_state.get_override_move_ratio())
