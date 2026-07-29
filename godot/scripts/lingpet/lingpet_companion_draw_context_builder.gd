extends RefCounted


func build_config(params: Dictionary) -> Dictionary:
	var companion_active := bool(params.get("companion_active", false))
	var body_hit_state: Object = params.get("body_hit_state", null) as Object
	var skill_state: Object = params.get("skill_state", null) as Object
	var switch_state: Object = params.get("switch_state", null) as Object
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
	var bind_sheet_state: Dictionary = {}
	if skill_runtime_host != null and skill_runtime_host.has_method("get_companion_bind_sheet_state"):
		bind_sheet_state = skill_runtime_host.get_companion_bind_sheet_state(skill_id)
	return {
		"radius": float(params.get("radius", 16.0)),
		"burst_particles": int(params.get("burst_particles", 8)),
		"hit_flash": _get_hit_flash_ratio(body_hit_state, companion_active),
		"gauge_flash": _get_gauge_flash_ratio(body_hit_state, companion_active),
		"skill_flash": _get_skill_flash_ratio(skill_state, companion_active, skill_flash_seconds),
		"defense_guard_active": bool(params.get("defense_guard_active", false)),
		"defense_guard_aura_ratio": clampf(float(params.get("defense_guard_aura_ratio", 0.0)), 0.0, 1.0),
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
		"companion_exhausted": bool(params.get("companion_exhausted", false)),
		"companion_alpha": clampf(float(params.get("companion_alpha", 1.0)), 0.0, 1.0),
		"satiety_exhaustion_ratio": clampf(float(params.get("satiety_exhaustion_ratio", 0.0)), 0.0, 1.0),
		"idle_texture": _resolve_body_texture(current_profile, "companion_idle", params),
		"move_left_texture": _resolve_body_texture(current_profile, "companion_move_left", params),
		"move_right_texture": _resolve_body_texture(current_profile, "companion_move_right", params),
		"walk_texture": _resolve_body_texture(current_profile, "companion_walk", params),
		"distance_roll_source_texture": _get_visual_texture(current_profile, "companion_distance_roll_source"),
		"bind_sheet_texture": _get_visual_texture(current_profile, "companion_star_coil_bind"),
		"bind_sheet_active": bool(bind_sheet_state.get("active", false)),
		"bind_sheet_frame": int(bind_sheet_state.get("frame", 0)),
		"companion_star_coil_bind_cols": _get_visual_layout_value(current_profile, "companion_star_coil_bind_cols"),
		"companion_star_coil_bind_rows": _get_visual_layout_value(current_profile, "companion_star_coil_bind_rows"),
		"companion_star_coil_bind_frame_count": _get_visual_layout_value(current_profile, "companion_star_coil_bind_frame_count"),
		"companion_star_coil_bind_draw_size": _get_visual_layout_value(current_profile, "companion_star_coil_bind_draw_size"),
		"strike_texture": _get_visual_texture(current_profile, "companion_strike"),
		"cast_texture": cast_texture,
		"walk_draw_size": _get_visual_layout_value(current_profile, "companion_walk_draw_size"),
		"strike_draw_size": _get_visual_layout_value(current_profile, "companion_strike_draw_size"),
		"cast_draw_size": cast_draw_size,
		"companion_distance_roll_enabled": _get_visual_layout_value(current_profile, "companion_distance_roll_enabled"),
		"companion_distance_roll_radius": _get_visual_layout_value(current_profile, "companion_distance_roll_radius"),
		"companion_roll_angle": _get_float(params.get("companion_roll_angle", 0.0)),
		"companion_stop_freeze_move_frame": _get_visual_layout_value(current_profile, "companion_stop_freeze_move_frame"),
		"companion_idle_cols": _get_visual_layout_value(current_profile, "companion_idle_cols"),
		"companion_idle_rows": _get_visual_layout_value(current_profile, "companion_idle_rows"),
		"companion_idle_frame_count": _get_visual_layout_value(current_profile, "companion_idle_frame_count"),
		"companion_move_left_cols": _get_visual_layout_value(current_profile, "companion_move_left_cols"),
		"companion_move_left_rows": _get_visual_layout_value(current_profile, "companion_move_left_rows"),
		"companion_move_left_frame_count": _get_visual_layout_value(current_profile, "companion_move_left_frame_count"),
		"companion_move_right_cols": _get_visual_layout_value(current_profile, "companion_move_right_cols"),
		"companion_move_right_rows": _get_visual_layout_value(current_profile, "companion_move_right_rows"),
		"companion_move_right_frame_count": _get_visual_layout_value(current_profile, "companion_move_right_frame_count"),
		"companion_walk_cols": _get_visual_layout_value(current_profile, "companion_walk_cols"),
		"companion_walk_rows": _get_visual_layout_value(current_profile, "companion_walk_rows"),
		"companion_walk_frame_count": _get_visual_layout_value(current_profile, "companion_walk_frame_count"),
		"companion_strike_cols": _get_visual_layout_value(current_profile, "companion_strike_cols"),
		"companion_strike_rows": _get_visual_layout_value(current_profile, "companion_strike_rows"),
		"companion_strike_frame_count": _get_visual_layout_value(current_profile, "companion_strike_frame_count"),
		"companion_cast_cols": _get_visual_layout_value(current_profile, "companion_cast_cols"),
		"companion_cast_rows": _get_visual_layout_value(current_profile, "companion_cast_rows"),
		"companion_cast_frame_count": _get_visual_layout_value(current_profile, "companion_cast_frame_count"),
		"companion_puppet_control_cols": _get_visual_layout_value(current_profile, "companion_puppet_control_cols"),
		"companion_puppet_control_rows": _get_visual_layout_value(current_profile, "companion_puppet_control_rows"),
		"companion_puppet_control_frame_count": _get_visual_layout_value(current_profile, "companion_puppet_control_frame_count"),
		"motion_speed_ratio": _resolve_motion_speed_ratio(current_profile, params.get("motion_speed_ratio", 0.0)),
	}


func build_affinity_feedback_config(params: Dictionary) -> Dictionary:
	var companion_active := bool(params.get("companion_active", false))
	var affinity_feedback_state: Object = params.get("affinity_feedback_state", null) as Object
	return {
		"radius": float(params.get("radius", 16.0)),
		"affinity_guard_label": _get_affinity_guard_label(affinity_feedback_state, companion_active),
		"shake_offset": params.get("shake_offset", Vector2.ZERO),
	}


func _get_affinity_guard_label(affinity_feedback_state: Object, companion_active: bool) -> Dictionary:
	if affinity_feedback_state == null or not affinity_feedback_state.has_method("get_guard_label"):
		return {}
	return affinity_feedback_state.get_guard_label(companion_active)


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


# 수호령 탑승: while the rider is mounted, every body sheet (idle / move /
# walk) swaps to the arms-raised shoulder-carry sheet. The carry sheet
# matches the companion sheet format (25f 5x5), so animator geometry is
# unchanged. Fail-closed: pets without an authored companion_carry sheet
# keep their normal sheets.
func _resolve_body_texture(current_profile: Object, visual_key: String, params: Dictionary) -> Texture2D:
	if bool(params.get("mount_carry_active", false)):
		var carry: Texture2D = _get_visual_texture(current_profile, "companion_carry")
		if carry != null:
			return carry
	return _get_visual_texture(current_profile, visual_key)


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
