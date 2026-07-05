extends RefCounted


static func apply_motion(runtime: Object, fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if runtime.chaos_release_pending:
		result["ball_vel"] = runtime.chaos_release_velocity
		result["skip_ball_motion_step"] = false
		result["ball_impact_boost"] = 1.0
		runtime.chaos_release_pending = false
		runtime.chaos_release_velocity = Vector2.ZERO
		runtime.chaos_ball_motion_owned = false
	elif runtime.chaos_ball_motion_owned and runtime.chaos_state != "blackhole":
		# 자가 해제: update_ball이 멈춘 일시정지 창(신화 획득 시네마틱 등)에서 블랙홀이
		# 만료->fade->reset까지 끝나면 pending 해제가 와이프된 채 공유 skip 플래그만 잔류한다.
		# 소유권 플래그가 남아 있고 scene 플래그가 아직 true면 만료 해제와 같은 속도로 풀어준다.
		if bool(scene.get("skip_ball_motion_step", false)):
			var stuck_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
			var heal_speed: float = max(16.0, stuck_vel.length() * 1.6)
			var heal_angle: float = randf_range(0.0, TAU)
			result["ball_vel"] = Vector2(cos(heal_angle), sin(heal_angle)) * heal_speed
			result["skip_ball_motion_step"] = false
			result["ball_impact_boost"] = 1.0
		runtime.chaos_ball_motion_owned = false
	if runtime.chaos_state != "blackhole" or not bool(context.get("ball_active", false)):
		return result
	var center: Vector2 = runtime.chaos_target
	var elapsed_frames: float = max(0.0, runtime.chaos_phase_frames)
	var blackhole_frames: float = float(constants.get("blackhole_frames", 180.0))
	var progress: float = clamp(elapsed_frames / max(1.0, blackhole_frames), 0.0, 1.0)
	var angle: float = runtime.chaos_orbit_seed + elapsed_frames * 0.1833
	var radius_ratio: float = 0.42 + 0.28 * (0.5 + 0.5 * sin(elapsed_frames * 0.1515))
	var radius: float = max(36.0, runtime.chaos_base_radius * radius_ratio * (1.0 - 0.35 * progress))
	var orbit_pos: Vector2 = Vector2(center.x + cos(angle) * radius, center.y + sin(angle * 1.35 + runtime.chaos_orbit_seed * 0.7) * radius * 0.75)
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	if not runtime.chaos_blackhole_origin_valid:
		runtime.chaos_blackhole_ball_origin = ball_pos
		runtime.chaos_blackhole_origin_valid = true
		runtime.chaos_prev_ball_center = ball_pos
		runtime.chaos_prev_ball_valid = true
	var ingress_frames: float = float(constants.get("ingress_frames", 31.2))
	var ingress_t: float = 1.0 - pow(1.0 - clamp(elapsed_frames / max(1.0, ingress_frames), 0.0, 1.0), 3.0)
	var new_pos: Vector2 = runtime.chaos_blackhole_ball_origin.lerp(orbit_pos, ingress_t)
	var prev_pos: Vector2 = runtime.chaos_prev_ball_center if runtime.chaos_prev_ball_valid else ball_pos
	result["ball_pos"] = new_pos
	result["ball_vel"] = new_pos - prev_pos
	result["skip_ball_motion_step"] = true
	runtime.chaos_ball_motion_owned = true
	result["player_collision_cooldown"] = max(6.0, float(scene.get("player_collision_cooldown", 0.0)))
	result["ball_impact_boost"] = 1.0
	runtime.chaos_prev_ball_center = new_pos
	runtime.chaos_prev_ball_valid = true
	var gold_award: int = _update_gold_ticks(runtime, elapsed_frames, constants)
	gold_award += _update_absorb_poll(runtime, fps_scale, center, deps, constants)
	if gold_award > 0:
		var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
		if runtime_perk_state != null and runtime_perk_state.has_method("award_gold"):
			result["runtime_perk_gold"] = int(_call_award_gold(runtime_perk_state, gold_award, context, deps))
	return result


static func _update_gold_ticks(runtime: Object, elapsed_frames: float, constants: Dictionary) -> int:
	var target_gold_ticks: int = int(floor(elapsed_frames / float(constants.get("gold_tick_frames", 6.0))))
	if target_gold_ticks <= runtime.chaos_gold_ticks_paid:
		return 0
	var tick_count: int = target_gold_ticks - runtime.chaos_gold_ticks_paid
	runtime.chaos_gold_ticks_paid = target_gold_ticks
	return tick_count * int(constants.get("gold_per_tick", 1))


static func _update_absorb_poll(runtime: Object, fps_scale: float, center: Vector2, deps: Dictionary, constants: Dictionary) -> int:
	runtime.chaos_absorb_poll_frames += fps_scale
	if runtime.chaos_absorb_poll_frames < float(constants.get("absorb_poll_frames", 5.4)):
		return 0
	runtime.chaos_absorb_poll_frames = 0.0
	var absorbed_objects: Array = _collect_absorbed_objects(center, deps, float(constants.get("pull_radius", 175.0)))
	for absorb_entry in absorbed_objects:
		_append_absorb_pulse(runtime, absorb_entry, center)
	return absorbed_objects.size() * int(constants.get("object_gold", 5))


static func _collect_absorbed_objects(center: Vector2, deps: Dictionary, pull_radius: float) -> Array:
	var absorbed_objects: Array = []
	var seen_instance_ids: Dictionary = {}
	for absorb_key in ["stage1_balloon_event", "stage1_gaksital_fan_wind_skill_state", "stage_background", "stage2_pillar_background"]:
		var absorb_target: Object = deps.get(absorb_key, null)
		if absorb_target == null or not absorb_target.has_method("absorb_chaos_spear_objects"):
			continue
		var instance_id: int = absorb_target.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		var absorb_entries: Variant = absorb_target.absorb_chaos_spear_objects(center, pull_radius, deps)
		if absorb_entries is Array:
			for absorb_entry in absorb_entries:
				if absorb_entry is Dictionary:
					absorbed_objects.append(absorb_entry)
	return absorbed_objects


static func _call_award_gold(runtime_perk_state: Object, amount: int, context: Dictionary, deps: Dictionary) -> int:
	if _method_accepts_arg_count(runtime_perk_state, "award_gold", 3):
		return int(runtime_perk_state.award_gold(amount, context, deps))
	return int(runtime_perk_state.award_gold(amount))


static func _method_accepts_arg_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	for method in target.get_method_list():
		if str(method.get("name", "")) != method_name:
			continue
		var args: Variant = method.get("args", [])
		if args is Array:
			return (args as Array).size() >= arg_count
	return false


static func _append_absorb_pulse(runtime: Object, absorb_entry: Dictionary, center: Vector2) -> void:
	var absorb_pos: Vector2 = _get_vector2(absorb_entry.get("position", center), center)
	var absorb_strength: float = float(absorb_entry.get("strength", 1.0))
	var absorb_color: Color = _get_color(absorb_entry.get("color", Color(0.78, 0.48, 1.0, 1.0)), Color(0.78, 0.48, 1.0, 1.0))
	var pulse_center: Vector2 = runtime.chaos_target
	var delta: Vector2 = pulse_center - absorb_pos
	var distance: float = max(1.0, delta.length())
	var inward: float = 0.8 + absorb_strength * 0.4
	var tangential: float = randf_range(-1.0, 1.0) * 1.4
	var velocity: Vector2 = delta / distance * inward + Vector2(-delta.y, delta.x) / distance * tangential
	var pulse_size: float = max(6.0, 12.0 * absorb_strength)
	runtime.chaos_absorb_pulses.append({"pos": absorb_pos, "vel": velocity, "size": pulse_size, "base_size": pulse_size, "life": 60.0, "max_life": 60.0, "color": absorb_color, "consumed": false})


static func _get_color(value: Variant, fallback: Color) -> Color:
	return value if value is Color else fallback


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
