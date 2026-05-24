extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func build_ak47_shell(
	origin: Vector2,
	direction: Vector2,
	config: Dictionary,
	shot_id: int,
	field_height: float,
	lifetime_frames: float
) -> Dictionary:
	var player_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(config.get("player_pos", origin), origin)
	var paddle_height: float = max(1.0, float(config.get("paddle_height", 50.0)))
	@warning_ignore("shadowed_global_identifier")
	var seed: int = max(1, shot_id)
	var spawn_pos: Vector2 = origin + _get_shell_side(direction) * 11.0 + Vector2(0.0, -6.0)
	var floor_y: float = clamp(player_pos.y + paddle_height + 5.0, 0.0, field_height - 4.0)
	return {
		"id": seed,
		"weapon_id": "ak47",
		"pos": spawn_pos,
		"velocity": Vector2(
			3.0 + float(seed % 5) * 0.55,
			-6.8 + float((seed + 2) % 4) * 0.45
		),
		"rotation": float((seed * 47) % 360),
		"rotation_speed": 16.0 + float((seed * 7) % 12),
		"bounce_count": 0,
		"floor_y": floor_y,
		"lifetime_frames": lifetime_frames,
		"max_lifetime_frames": lifetime_frames,
		"length": 8.0,
		"width": 3.0,
	}


static func build_pistol_shell(
	origin: Vector2,
	direction: Vector2,
	config: Dictionary,
	shot_id: int,
	weapon_id: String,
	field_height: float,
	lifetime_frames: float
) -> Dictionary:
	var player_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(config.get("player_pos", origin), origin)
	var paddle_height: float = max(1.0, float(config.get("paddle_height", 50.0)))
	@warning_ignore("shadowed_global_identifier")
	var seed: int = max(1, shot_id)
	var spawn_pos: Vector2 = origin + _get_shell_side(direction) * 8.0 + Vector2(0.0, -3.0)
	var floor_y: float = clamp(player_pos.y + paddle_height + 4.0, 0.0, field_height - 4.0)
	return {
		"id": seed,
		"weapon_id": weapon_id,
		"pos": spawn_pos,
		"velocity": Vector2(
			2.0 + float(seed % 4) * 0.35,
			-4.6 + float((seed + 1) % 3) * 0.30
		),
		"rotation": float((seed * 41) % 360),
		"rotation_speed": 11.0 + float((seed * 5) % 9),
		"bounce_count": 0,
		"floor_y": floor_y,
		"lifetime_frames": lifetime_frames,
		"max_lifetime_frames": lifetime_frames,
		"length": 6.0,
		"width": 2.4,
	}


static func append_runtime_shell(
	shells: Array,
	weapon_id: String,
	origin: Vector2,
	direction: Vector2,
	config: Dictionary,
	shot_id: int,
	field_height: float,
	ak47_lifetime_frames: float,
	pistol_lifetime_frames: float,
	shell_limit: int
) -> bool:
	if weapon_id == "ak47":
		CommandoFirearmValueUtils.append_limited(
			shells,
			build_ak47_shell(
				origin,
				direction,
				config,
				shot_id,
				field_height,
				ak47_lifetime_frames
			),
			shell_limit
		)
		return true
	if weapon_id == "pistol" or weapon_id == "commando_pistol":
		CommandoFirearmValueUtils.append_limited(
			shells,
			build_pistol_shell(
				origin,
				direction,
				config,
				shot_id,
				weapon_id,
				field_height,
				pistol_lifetime_frames
			),
			shell_limit
		)
		return true
	return false


static func advance_shell(
	shell: Dictionary,
	fps_scale: float,
	field_width: float,
	field_height: float,
	gravity: float,
	bounce_decay: float,
	max_bounces: int
) -> Dictionary:
	var step: float = max(0.0, fps_scale)
	var next_shell: Dictionary = shell.duplicate(true)
	var lifetime: float = max(0.0, float(next_shell.get("lifetime_frames", 0.0)) - step)
	if lifetime <= 0.0:
		return {"active": false}
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(next_shell.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(next_shell.get("velocity", Vector2.ZERO), Vector2.ZERO)
	velocity.y += gravity * step
	pos += velocity * step
	var rotation: float = float(next_shell.get("rotation", 0.0)) + float(next_shell.get("rotation_speed", 0.0)) * step
	var bounce_count: int = int(next_shell.get("bounce_count", 0))
	var floor_y: float = float(next_shell.get("floor_y", field_height - 50.0))
	if pos.y >= floor_y:
		pos.y = floor_y
		if bounce_count < max_bounces:
			velocity.y = -abs(velocity.y) * bounce_decay
			velocity.x *= 0.70
			next_shell["rotation_speed"] = float(next_shell.get("rotation_speed", 0.0)) * 0.60
			bounce_count += 1
			if abs(velocity.y) < 1.0:
				velocity.y = 0.0
				velocity.x *= 0.50
				next_shell["rotation_speed"] = 0.0
		else:
			velocity.y = 0.0
			velocity.x *= 0.85
			next_shell["rotation_speed"] = 0.0
			if abs(velocity.x) < 0.30:
				velocity.x = 0.0
	next_shell["pos"] = pos
	next_shell["velocity"] = velocity
	next_shell["rotation"] = rotation
	next_shell["bounce_count"] = bounce_count
	next_shell["lifetime_frames"] = lifetime
	if pos.x < -80.0 or pos.x > field_width + 80.0:
		return {"active": false}
	return {
		"active": true,
		"shell": next_shell,
	}


static func advance_shells(
	shells: Array,
	fps_scale: float,
	field_width: float,
	field_height: float,
	gravity: float,
	bounce_decay: float,
	max_bounces: int
) -> Array:
	var step: float = max(0.0, fps_scale)
	if step <= 0.0:
		return shells.duplicate(true)
	var next_shells: Array = []
	for value in shells:
		var shell: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		var update_result: Dictionary = advance_shell(
			shell,
			step,
			field_width,
			field_height,
			gravity,
			bounce_decay,
			max_bounces
		)
		if bool(update_result.get("active", false)):
			next_shells.append(CommandoFirearmValueUtils.get_dict(update_result.get("shell", shell)))
	return next_shells


static func _get_shell_side(direction: Vector2) -> Vector2:
	var side: Vector2 = direction.rotated(PI * 0.5)
	if side.x < 0.0:
		side = -side
	return side.normalized()
