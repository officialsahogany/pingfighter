extends RefCounted

const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmStage2RockInteractionResolver := preload("res://scripts/characters/commando_firearm_stage2_rock_interaction_resolver.gd")
const CommandoFirearmSuicideDroneState := preload("res://scripts/characters/commando_firearm_suicide_drone_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func replace_projectile_payload(projectile: Dictionary, next_projectile: Dictionary) -> void:
	projectile.clear()
	projectile.merge(next_projectile, true)


static func write_motion_fields(projectile: Dictionary, prev_pos: Vector2, pos: Vector2, velocity: Vector2) -> void:
	projectile["prev_pos"] = prev_pos
	projectile["pos"] = pos
	projectile["velocity"] = velocity


static func advance_life_timer(projectile: Dictionary, step: float) -> void:
	projectile["life_frames"] = max(0.0, float(projectile.get("life_frames", 0.0)) - max(0.0, step))


static func finalize_frame_motion(
	projectile: Dictionary,
	prev_pos: Vector2,
	pos: Vector2,
	velocity: Vector2,
	step: float
) -> void:
	write_motion_fields(projectile, prev_pos, pos, velocity)
	advance_life_timer(projectile, step)


static func apply_pistol_side_wall_bounce(
	projectile: Dictionary,
	pos: Vector2,
	velocity: Vector2,
	field_width: float,
	margin: float,
	max_bounces: int,
	damping: float
) -> Dictionary:
	if int(projectile.get("wall_bounces", 0)) >= max_bounces:
		return {"bounced": false}
	var next_projectile: Dictionary = projectile.duplicate(true)
	var left_margin := margin
	var right_margin := field_width - margin
	var bounced := false
	if pos.x <= left_margin:
		pos.x = left_margin
		velocity.x = abs(velocity.x) * damping
		next_projectile["wall_bounce_side"] = "left"
		bounced = true
	elif pos.x >= right_margin:
		pos.x = right_margin
		velocity.x = -abs(velocity.x) * damping
		next_projectile["wall_bounce_side"] = "right"
		bounced = true
	if not bounced:
		return {"bounced": false}
	next_projectile["wall_bounces"] = int(next_projectile.get("wall_bounces", 0)) + 1
	next_projectile["pos"] = pos
	next_projectile["velocity"] = velocity
	next_projectile["speed"] = velocity.length()
	return {
		"bounced": true,
		"projectile": next_projectile,
	}


static func update_rocket_motion(
	projectile: Dictionary,
	pos: Vector2,
	velocity: Vector2,
	step: float,
	default_acceleration: float,
	default_max_speed: float,
	default_smoke_trail_limit: int
) -> Dictionary:
	var next_projectile: Dictionary = projectile.duplicate(true)
	var direction: Vector2 = velocity.normalized() if velocity.length() > 0.001 else Vector2.UP
	var speed: float = float(next_projectile.get("speed", velocity.length()))
	var acceleration: float = max(0.0, float(next_projectile.get("acceleration", default_acceleration)))
	var max_speed: float = max(speed, float(next_projectile.get("max_speed", default_max_speed)))
	var smoke_trail: Array = CommandoFirearmValueUtils.get_array(next_projectile.get("smoke_trail", []))
	var should_append_smoke := smoke_trail.is_empty()
	if not should_append_smoke:
		var last_smoke: Vector2 = CommandoFirearmValueUtils.get_vector2(smoke_trail.back(), pos)
		should_append_smoke = last_smoke.distance_to(pos) > 5.0
	if should_append_smoke:
		smoke_trail.append(pos)
		var smoke_limit: int = max(1, int(next_projectile.get("smoke_trail_limit", default_smoke_trail_limit)))
		while smoke_trail.size() > smoke_limit:
			smoke_trail.pop_front()
		next_projectile["smoke_trail"] = smoke_trail
	speed = min(max_speed, speed + acceleration * max(0.0, step))
	next_projectile["speed"] = speed
	return {
		"projectile": next_projectile,
		"velocity": direction * speed,
	}


static func advance_linear_motion(
	projectile: Dictionary,
	pos: Vector2,
	velocity: Vector2,
	step: float
) -> Dictionary:
	var frame_step: float = max(0.0, step)
	var next_velocity: Vector2 = velocity
	if projectile.has("gravity"):
		next_velocity.y += float(projectile.get("gravity", 0.0)) * frame_step
	return {
		"prev_pos": pos,
		"pos": pos + next_velocity * frame_step,
		"velocity": next_velocity,
	}


static func update_net_projectile_rope(
	projectile: Dictionary,
	pos: Vector2,
	origin: Vector2,
	default_rope_trail_limit: int
) -> Dictionary:
	var next_projectile: Dictionary = projectile.duplicate(true)
	next_projectile["origin"] = origin
	var rope_points: Array = CommandoFirearmValueUtils.get_array(next_projectile.get("rope_points", []))
	rope_points.append(pos)
	var rope_limit: int = max(1, int(next_projectile.get("rope_trail_limit", default_rope_trail_limit)))
	while rope_points.size() > rope_limit:
		rope_points.pop_front()
	next_projectile["rope_points"] = rope_points
	return next_projectile


static func advance_runtime_projectile_motion(
	projectile: Dictionary,
	projectile_kind: String,
	_projectile_weapon_id: String,
	is_pistol_projectile: bool,
	context: Dictionary,
	deps: Dictionary,
	step: float,
	field_size: Vector2,
	pistol_wall_bounce_margin: float,
	pistol_wall_bounce_max: int,
	pistol_wall_bounce_damping: float,
	bazooka_acceleration: float,
	bazooka_max_speed: float,
	bazooka_smoke_trail_limit: int,
	net_gun_muzzle_source: Vector2,
	fire_sheet_source_cell_size: Vector2,
	fire_sheet_player_foot_y_offset: float,
	net_gun_rope_trail_limit: int
) -> Dictionary:
	var frame_step: float = max(0.0, step)
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	if projectile_kind == "drone":
		velocity = CommandoFirearmSuicideDroneState.get_homing_velocity(
			pos,
			projectile,
			CommandoFirearmOriginGeometry.get_boss_target_pos(context, field_size.x),
			frame_step
		)
	elif projectile_kind == "rocket":
		var rocket_motion: Dictionary = update_rocket_motion(
			projectile,
			pos,
			velocity,
			frame_step,
			bazooka_acceleration,
			bazooka_max_speed,
			bazooka_smoke_trail_limit
		)
		replace_projectile_payload(
			projectile,
			CommandoFirearmValueUtils.get_dict(rocket_motion.get("projectile", projectile))
		)
		velocity = CommandoFirearmValueUtils.get_vector2(rocket_motion.get("velocity", velocity), velocity)
	var linear_motion: Dictionary = advance_linear_motion(projectile, pos, velocity, frame_step)
	var prev_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(linear_motion.get("prev_pos", pos), pos)
	pos = CommandoFirearmValueUtils.get_vector2(linear_motion.get("pos", pos), pos)
	velocity = CommandoFirearmValueUtils.get_vector2(linear_motion.get("velocity", velocity), velocity)
	if is_pistol_projectile:
		var field_width: float = max(pistol_wall_bounce_margin * 2.0, float(context.get("width", field_size.x)))
		var bounce_result: Dictionary = apply_pistol_side_wall_bounce(
			projectile,
			pos,
			velocity,
			field_width,
			pistol_wall_bounce_margin,
			pistol_wall_bounce_max,
			pistol_wall_bounce_damping
		)
		if bool(bounce_result.get("bounced", false)):
			replace_projectile_payload(
				projectile,
				CommandoFirearmValueUtils.get_dict(bounce_result.get("projectile", projectile))
			)
			pos = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", pos), pos)
			velocity = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", velocity), velocity)
	write_motion_fields(projectile, prev_pos, pos, velocity)
	var rock_bounce_result: Dictionary = CommandoFirearmStage2RockInteractionResolver.apply_pistol_rock_bounce(
		projectile,
		context,
		deps,
		is_pistol_projectile
	)
	if bool(rock_bounce_result.get("consumed", false)):
		return {
			"consumed": true,
			"projectile": projectile,
		}
	if bool(rock_bounce_result.get("bounced", false)):
		pos = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", pos), pos)
		velocity = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", velocity), velocity)
	if projectile_kind == "net":
		replace_projectile_payload(
			projectile,
			update_net_projectile_rope(
				projectile,
				pos,
				CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(
					context,
					net_gun_muzzle_source,
					field_size,
					fire_sheet_source_cell_size,
					fire_sheet_player_foot_y_offset
				),
				net_gun_rope_trail_limit
			)
		)
	finalize_frame_motion(
		projectile,
		CommandoFirearmValueUtils.get_vector2(projectile.get("prev_pos", prev_pos), prev_pos),
		pos,
		velocity,
		frame_step
	)
	return {
		"consumed": false,
		"projectile": projectile,
		"prev_pos": prev_pos,
		"pos": pos,
		"velocity": velocity,
		"rock_bounced": bool(rock_bounce_result.get("bounced", false)),
	}
