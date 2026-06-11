extends RefCounted


func build_config(params: Dictionary) -> Dictionary:
	var companion_active := bool(params.get("companion_active", false))
	var body_hit_state: Object = params.get("body_hit_state", null) as Object
	var skill_state: Object = params.get("skill_state", null) as Object
	var switch_state: Object = params.get("switch_state", null) as Object
	var affinity_feedback_state: Object = params.get("affinity_feedback_state", null) as Object
	var skill_runtime_host: Object = params.get("skill_runtime_host", null) as Object
	var current_profile: Object = params.get("current_profile", null) as Object
	var skill_id := str(params.get("skill_id", ""))
	var skill_flash_seconds := maxf(0.0, float(params.get("skill_flash_seconds", 0.0)))
	var switch_transition_seconds := maxf(0.0, float(params.get("switch_transition_seconds", 0.0)))
	var windup_seconds := maxf(0.0, float(params.get("windup_seconds", 0.0)))
	var windup_active := skill_state != null and bool(skill_state.windup_active)
	var skill_cast_pose_progress := _get_skill_cast_pose_progress(skill_runtime_host, skill_id)
	var skill_cast_pose_active := skill_cast_pose_progress >= 0.0
	var casting_windup := skill_cast_pose_active or (windup_active and skill_runtime_host != null and bool(skill_runtime_host.should_show_cast_windup(skill_id)))
	var animator: Object = params.get("animator", null) as Object
	var attacking := animator != null and bool(animator.strike_active)
	var cast_texture: Texture2D = null
	if skill_cast_pose_active:
		cast_texture = _get_visual_texture(current_profile, "companion_puppet_control")
	if cast_texture == null:
		cast_texture = _get_visual_texture(current_profile, "companion_cast")
	var cast_draw_size := _get_visual_layout_value(current_profile, "companion_cast_draw_size")
	if skill_cast_pose_active:
		var puppet_control_draw_size := _get_visual_layout_value(current_profile, "companion_puppet_control_draw_size")
		if puppet_control_draw_size > 0.0:
			cast_draw_size = puppet_control_draw_size
	return {
		"radius": float(params.get("radius", 16.0)),
		"burst_particles": int(params.get("burst_particles", 8)),
		"hit_flash": _get_hit_flash_ratio(body_hit_state, companion_active),
		"gauge_flash": _get_gauge_flash_ratio(body_hit_state, companion_active),
		"skill_flash": _get_skill_flash_ratio(skill_state, companion_active, skill_flash_seconds),
		"affinity_flash": _get_affinity_flash_ratio(affinity_feedback_state, companion_active),
		"affinity_label": _get_affinity_label(affinity_feedback_state, companion_active),
		"affinity_title": _get_affinity_title(affinity_feedback_state),
		"affinity_heart_tint": _get_affinity_heart_tint(affinity_feedback_state),
		"affinity_trigger_count": _get_trigger_count(affinity_feedback_state),
		"switch_transition": _get_switch_ratio(switch_state, switch_transition_seconds),
		"switch_particles": int(params.get("switch_particles", 12)),
		"switch_trigger_count": _get_trigger_count(switch_state),
		"display_name": _get_display_name(current_profile),
		"gauge_trigger_count": _get_trigger_count(body_hit_state, "gauge_trigger_count"),
		"skill_trigger_count": _get_trigger_count(skill_state),
		"animator": animator,
		"patrol_pause": _get_float(params.get("patrol_pause", 0.0)),
		# Dedicated SD sets may provide rear idle and left/right movement sheets.
		# Older pets still fall back to the AutoSprite-canonical "generate NE,
		# flip for NW" model by using companion_walk + face_left.
		"face_left": bool(params.get("face_left", false)),
		"windup_elapsed": skill_cast_pose_progress if skill_cast_pose_active else _get_float(skill_state.windup_elapsed if skill_state != null else 0.0),
		"windup_seconds": 1.0 if skill_cast_pose_active else windup_seconds,
		"casting_windup": casting_windup,
		"skill_cast_pose_active": skill_cast_pose_active,
		"attacking": attacking,
		"companion_visible": bool(params.get("companion_visible", true)),
		"idle_texture": _get_visual_texture(current_profile, "companion_idle"),
		"move_left_texture": _get_visual_texture(current_profile, "companion_move_left"),
		"move_right_texture": _get_visual_texture(current_profile, "companion_move_right"),
		"walk_texture": _get_visual_texture(current_profile, "companion_walk"),
		"strike_texture": _get_visual_texture(current_profile, "companion_strike"),
		"cast_texture": cast_texture,
		"walk_draw_size": _get_visual_layout_value(current_profile, "companion_walk_draw_size"),
		"strike_draw_size": _get_visual_layout_value(current_profile, "companion_strike_draw_size"),
		"cast_draw_size": cast_draw_size,
		"motion_speed_ratio": _resolve_motion_speed_ratio(current_profile, params.get("motion_speed_ratio", 0.0)),
	}


func build_affinity_feedback_config(params: Dictionary) -> Dictionary:
	var companion_active := bool(params.get("companion_active", false))
	var affinity_feedback_state: Object = params.get("affinity_feedback_state", null) as Object
	return {
		"radius": float(params.get("radius", 16.0)),
		"burst_particles": int(params.get("burst_particles", 8)),
		"affinity_flash": _get_affinity_flash_ratio(affinity_feedback_state, companion_active),
		"affinity_label": _get_affinity_label(affinity_feedback_state, companion_active),
		"affinity_title": _get_affinity_title(affinity_feedback_state),
		"affinity_heart_tint": _get_affinity_heart_tint(affinity_feedback_state),
		"affinity_trigger_count": _get_trigger_count(affinity_feedback_state),
	}


func _get_hit_flash_ratio(body_hit_state: Object, companion_active: bool) -> float:
	if body_hit_state == null:
		return 0.0
	return float(body_hit_state.get_hit_flash_ratio(companion_active))


func _get_gauge_flash_ratio(body_hit_state: Object, companion_active: bool) -> float:
	if body_hit_state == null:
		return 0.0
	return float(body_hit_state.get_gauge_flash_ratio(companion_active))


func _get_skill_flash_ratio(skill_state: Object, companion_active: bool, flash_seconds: float) -> float:
	if not companion_active or skill_state == null or flash_seconds <= 0.0:
		return 0.0
	return float(skill_state.get_flash_ratio(flash_seconds))


func _get_affinity_flash_ratio(affinity_feedback_state: Object, companion_active: bool) -> float:
	if affinity_feedback_state == null or not affinity_feedback_state.has_method("get_flash_ratio"):
		return 0.0
	return float(affinity_feedback_state.get_flash_ratio(companion_active))


func _get_affinity_label(affinity_feedback_state: Object, companion_active: bool) -> String:
	if affinity_feedback_state == null or _get_affinity_flash_ratio(affinity_feedback_state, companion_active) <= 0.0:
		return ""
	return str(affinity_feedback_state.label)


func _get_affinity_title(affinity_feedback_state: Object) -> String:
	if affinity_feedback_state == null:
		return ""
	return str(affinity_feedback_state.title_label)


func _get_affinity_heart_tint(affinity_feedback_state: Object) -> bool:
	if affinity_feedback_state == null:
		return false
	return bool(affinity_feedback_state.heart_tint_unlocked)


func _get_switch_ratio(switch_state: Object, transition_seconds: float) -> float:
	if switch_state == null:
		return 0.0
	return float(switch_state.get_ratio(transition_seconds))


func _get_trigger_count(state: Object, property_name: String = "trigger_count") -> int:
	if state == null:
		return 0
	return int(state.get(property_name))


func _get_visual_texture(current_profile: Object, visual_key: String) -> Texture2D:
	if current_profile == null:
		return null
	return current_profile.get_visual_texture(visual_key, null)


func _get_visual_layout_value(current_profile: Object, layout_key: String) -> float:
	if current_profile == null or not current_profile.has_method("get_visual_layout_value"):
		return 0.0
	return maxf(0.0, float(current_profile.get_visual_layout_value(layout_key, 0.0)))


func _get_skill_cast_pose_progress(skill_runtime_host: Object, skill_id: String) -> float:
	if skill_runtime_host == null or not skill_runtime_host.has_method("get_companion_cast_pose_progress"):
		return -1.0
	return clampf(float(skill_runtime_host.get_companion_cast_pose_progress(skill_id)), -1.0, 1.0)


func _resolve_motion_speed_ratio(current_profile: Object, value: Variant) -> float:
	var ratio := clampf(_get_float(value), 0.0, 1.0)
	var max_ratio := _get_visual_layout_value(current_profile, "companion_wing_flap_max_speed_ratio")
	if max_ratio > 0.0:
		ratio = minf(ratio, clampf(max_ratio, 0.0, 1.0))
	return ratio


func _get_display_name(current_profile: Object) -> String:
	if current_profile == null or not current_profile.has_method("get_display_name"):
		return ""
	return str(current_profile.get_display_name())


func _get_float(value: Variant) -> float:
	return float(value)
