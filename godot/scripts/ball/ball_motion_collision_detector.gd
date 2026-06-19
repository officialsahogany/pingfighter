extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")

const EVENT_WALL := "wall"
const EVENT_PLAYER_PADDLE := "player_paddle"
const EVENT_BOSS_PADDLE := "boss_paddle"
const EVENT_HOLY_BARRIER := "holy_barrier"
const EVENT_HORN_STRAWBERRY_FIELD := "horn_strawberry_field"
const EVENT_LINGPET_BONE_BARRIER := "lingpet_bone_barrier"
const EVENT_BRICK_WALL := "brick_wall"
const EVENT_TRAMPOLINE := "trampoline"
const EVENT_SAND_TERRAIN := "sand_terrain"


func check_sand_terrain(ball_pos: Vector2, ball_vel: Vector2, ball_size: float, context: Dictionary) -> Dictionary:
	var weather: Object = context.get("weather_event_state", null)
	if weather == null or not weather.has_method("resolve_sand_ball_collision"):
		return {}
	var result: Variant = weather.resolve_sand_ball_collision(ball_pos, ball_vel, ball_size, context)
	if result is Dictionary:
		return result
	return {}


func check_wall(ball_pos: Vector2, ball_size: float, width: float) -> Dictionary:
	if ball_pos.x - ball_size * 0.5 <= 0.0:
		ball_pos.x = ball_size * 0.5
		return {
			"event": EVENT_WALL,
			"side": "left",
			"impact_pos": Vector2(ball_pos.x - ball_size * 0.5, ball_pos.y),
			"ball_pos": ball_pos,
		}
	if ball_pos.x + ball_size * 0.5 >= width:
		ball_pos.x = width - ball_size * 0.5
		return {
			"event": EVENT_WALL,
			"side": "right",
			"impact_pos": Vector2(ball_pos.x + ball_size * 0.5, ball_pos.y),
			"ball_pos": ball_pos,
		}
	return {}


func check_paddles(ball_pos: Vector2, ball_vel: Vector2, ball_size: float, context: Dictionary) -> Dictionary:
	var hitbox_padding: float = float(context.get("hitbox_padding", 5.0))
	var ball_rect: Rect2 = Rect2(ball_pos.x - ball_size * 0.5, ball_pos.y - ball_size * 0.5, ball_size, ball_size)

	var dark_blade_rising_player_hit: bool = _allows_viper_dark_blade_rising_player_hit(context)
	if ball_vel.y > 0.0 or _allows_stopwatch_recovery_upward_player_hit(ball_vel, context) or dark_blade_rising_player_hit:
		if not bool(context.get("viper_core_flip_attack_active", false)):
			if float(context.get("player_collision_cooldown", 0.0)) > 0.0:
				if not (dark_blade_rising_player_hit and ball_vel.y < 0.0):
					return {}
			else:
				var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
				var player_paddle_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2.ZERO), Vector2.ZERO)
				var player_rect: Rect2 = Rect2(
					player_pos.x - hitbox_padding,
					player_pos.y - hitbox_padding,
					player_paddle_size.x + hitbox_padding * 2.0,
					player_paddle_size.y + hitbox_padding * 2.0
				)
				player_rect = _apply_dash_acceleration_height_bonus(player_rect, context)
				var collision_result: Dictionary = _resolve_player_collision_result(player_rect, ball_rect, context)
				if bool(collision_result.get("hit", false)):
					var collision_rect: Rect2 = _as_rect2(collision_result.get("rect", player_rect), player_rect)
					var collision_paddle_x: float = collision_rect.position.x + hitbox_padding
					var result := {
						"event": EVENT_PLAYER_PADDLE,
						"paddle_x": collision_paddle_x,
						"paddle_w": float(collision_result.get("paddle_w", player_paddle_size.x)),
						"is_player": true,
					}
					if bool(collision_result.get("viper_dual_glitch_clone_hit", false)):
						result["viper_dual_glitch_clone_hit"] = true
						result["viper_dual_glitch_clone_index"] = int(collision_result.get("viper_dual_glitch_clone_index", -1))
						result["viper_dual_glitch_clone_side"] = int(collision_result.get("viper_dual_glitch_clone_side", 0))
					if bool(collision_result.get("blacksmith_thor_shield_hit", false)):
						result["blacksmith_thor_shield_hit"] = true
						result["blacksmith_thor_shield_rect"] = collision_result.get("rect", collision_rect)
						result["blacksmith_thor_shield_gauge_gain"] = float(collision_result.get(
							"blacksmith_thor_shield_gauge_gain",
							context.get("blacksmith_umbrella_gauge_gain", 60.0)
						))
					return result

	if ball_vel.y < 0.0:
		if float(context.get("boss_collision_cooldown", 0.0)) > 0.0:
			return {}
		var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
		var boss_paddle_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2.ZERO), Vector2.ZERO)
		var boss_rect: Rect2 = Rect2(
			boss_pos.x - hitbox_padding,
			boss_pos.y - hitbox_padding,
			boss_paddle_size.x + hitbox_padding * 2.0,
			boss_paddle_size.y + hitbox_padding * 2.0
		)
		if boss_rect.intersects(ball_rect):
			return {
				"event": EVENT_BOSS_PADDLE,
				"paddle_x": boss_pos.x,
				"paddle_w": boss_paddle_size.x,
				"is_player": false,
			}

	return {}


func _resolve_player_collision_result(base_rect: Rect2, ball_rect: Rect2, context: Dictionary) -> Dictionary:
	var hitbox_padding: float = float(context.get("hitbox_padding", 5.0))
	var base_hit_rect: Rect2 = _resolve_player_collision_rect(base_rect, ball_rect, context)
	if base_hit_rect.intersects(ball_rect):
		return {
			"hit": true,
			"rect": base_hit_rect,
			"paddle_w": max(1.0, base_hit_rect.size.x - hitbox_padding * 2.0),
		}
	if bool(context.get("blacksmith_thor_shield_active", false)):
		var shield_rect: Rect2 = _as_rect2(context.get("blacksmith_thor_shield_rect", Rect2()), Rect2())
		if shield_rect.size.x > 0.0 and shield_rect.size.y > 0.0 and shield_rect.intersects(ball_rect):
			return {
				"hit": true,
				"rect": shield_rect,
				"paddle_w": max(1.0, float(context.get("blacksmith_thor_shield_paddle_w", shield_rect.size.x))),
				"blacksmith_thor_shield_hit": true,
				"blacksmith_thor_shield_gauge_gain": float(context.get("blacksmith_umbrella_gauge_gain", 60.0)),
			}
	var clone_rects: Array = context.get("viper_dual_glitch_clone_rects", [])
	for entry_value in clone_rects:
		var clone_entry: Dictionary = _resolve_dual_glitch_clone_entry(entry_value, hitbox_padding)
		var clone_rect: Rect2 = _as_rect2(clone_entry.get("rect", Rect2()), Rect2())
		if clone_rect.size.x <= 0.0 or clone_rect.size.y <= 0.0:
			continue
		if not clone_rect.intersects(ball_rect):
			continue
		return {
			"hit": true,
			"rect": clone_rect,
			"paddle_w": max(1.0, clone_rect.size.x - hitbox_padding * 2.0),
			"viper_dual_glitch_clone_hit": true,
			"viper_dual_glitch_clone_index": int(clone_entry.get("index", -1)),
			"viper_dual_glitch_clone_side": int(clone_entry.get("side", 0)),
		}
	return {"hit": false}


func _allows_stopwatch_recovery_upward_player_hit(ball_vel: Vector2, context: Dictionary) -> bool:
	if ball_vel.y >= 0.0:
		return false
	# Why: when recovery completes on the same frame the ball is still
	# overlapping the paddle moving up, `stopwatch_recovery_active` flips to
	# false but the ball still needs the upward-catch path to bounce it
	# instead of leaking up through the paddle. The post-recovery grace flag
	# keeps that catch alive for a short window.
	return (
		bool(context.get("stopwatch_recovery_active", false))
		or bool(context.get("stopwatch_post_recovery_grace_active", false))
	)


func _allows_viper_dark_blade_rising_player_hit(context: Dictionary) -> bool:
	return bool(context.get("viper_dark_blade_rising_contact_active", false))


func _resolve_player_collision_rect(base_rect: Rect2, ball_rect: Rect2, context: Dictionary) -> Rect2:
	var mirror_offset_x: float = float(context.get("player_paddle_mirror_offset_x", 0.0))
	if abs(mirror_offset_x) <= 0.01:
		return base_rect
	var mirror_rect := Rect2(base_rect.position + Vector2(mirror_offset_x, 0.0), base_rect.size)
	var base_hit: bool = base_rect.intersects(ball_rect)
	var mirror_hit: bool = mirror_rect.intersects(ball_rect)
	if mirror_hit and not base_hit:
		return mirror_rect
	if base_hit and not mirror_hit:
		return base_rect
	if mirror_hit and base_hit:
		var ball_center: Vector2 = ball_rect.get_center()
		if abs(ball_center.x - mirror_rect.get_center().x) < abs(ball_center.x - base_rect.get_center().x):
			return mirror_rect
	return base_rect


func _apply_dash_acceleration_height_bonus(base_rect: Rect2, context: Dictionary) -> Rect2:
	if not bool(context.get("dash_acceleration_active", false)):
		return base_rect
	var height_bonus: float = max(0.0, float(context.get("dash_acceleration_height_bonus", 0.0)))
	if height_bonus <= 0.0:
		return base_rect
	var expanded := base_rect
	expanded.position.y -= height_bonus * 0.5
	expanded.size.y += height_bonus
	return expanded


func _resolve_dual_glitch_clone_entry(entry_value: Variant, hitbox_padding: float) -> Dictionary:
	var raw_rect := Rect2()
	var clone_index := -1
	var clone_side := 0
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value
		raw_rect = _as_rect2(entry.get("rect", Rect2()), Rect2())
		clone_index = int(entry.get("index", -1))
		clone_side = int(entry.get("side", 0))
	elif entry_value is Rect2:
		raw_rect = entry_value
	if raw_rect.size.x <= 0.0 or raw_rect.size.y <= 0.0:
		return {}
	return {
		"rect": raw_rect.grow(hitbox_padding),
		"index": clone_index,
		"side": clone_side,
	}


func check_brick_wall(ball_pos: Vector2, ball_vel: Vector2, ball_size: float, context: Dictionary) -> Dictionary:
	if ball_vel.y <= 0.0:
		return {}

	var walls: Array = context.get("brick_walls", [])
	if walls.is_empty():
		return {}

	var ball_rect := Rect2(
		ball_pos.x - ball_size * 0.5,
		ball_pos.y - ball_size * 0.5,
		ball_size,
		ball_size
	)
	for i in range(walls.size()):
		var wall_value: Variant = walls[i]
		if not (wall_value is Dictionary):
			continue
		var wall: Dictionary = wall_value
		var wall_rect: Rect2 = _as_rect2(wall.get("rect", Rect2()), Rect2())
		if wall_rect.size.x <= 0.0 or wall_rect.size.y <= 0.0:
			continue
		if not wall_rect.intersects(ball_rect):
			continue
		ball_pos.y = wall_rect.position.y - ball_size * 0.5
		return {
			"event": EVENT_BRICK_WALL,
			"ball_pos": ball_pos,
			"wall_index": i,
			"impact_pos": Vector2(ball_pos.x, wall_rect.position.y),
		}

	return {}


func check_trampoline(ball_pos: Vector2, ball_vel: Vector2, ball_size: float, context: Dictionary) -> Dictionary:
	if ball_vel.y <= 0.0:
		return {}

	var trampolines: Array = context.get("trampolines", [])
	if trampolines.is_empty():
		return {}

	var ball_rect := Rect2(
		ball_pos.x - ball_size * 0.5,
		ball_pos.y - ball_size * 0.5,
		ball_size,
		ball_size
	)
	for i in range(trampolines.size()):
		var trampoline_value: Variant = trampolines[i]
		if not (trampoline_value is Dictionary):
			continue
		var trampoline: Dictionary = trampoline_value
		var trampoline_rect: Rect2 = _as_rect2(trampoline.get("rect", Rect2()), Rect2())
		if trampoline_rect.size.x <= 0.0 or trampoline_rect.size.y <= 0.0:
			continue
		# The capture band extends one ball below the mat so contact events
		# keep firing while the slingshot draw sinks the ball into the mat.
		var capture_band: Rect2 = trampoline_rect.grow_individual(0.0, 0.0, 0.0, ball_size)
		if not capture_band.intersects(ball_rect):
			continue
		# No snap-to-mat-top: the slingshot capture lets the ball keep
		# sinking into the mat, so the stepped position is the real one.
		return {
			"event": EVENT_TRAMPOLINE,
			"ball_pos": ball_pos,
			"trampoline_index": i,
			"impact_pos": Vector2(ball_pos.x, trampoline_rect.position.y),
		}

	return {}


func check_holy_barrier(ball_pos: Vector2, ball_vel: Vector2, ball_size: float, context: Dictionary) -> Dictionary:
	if not bool(context.get("holy_barrier_active", false)) or ball_vel.y <= 0.0:
		return {}

	var width: float = float(context.get("width", 760.0))
	var barrier_y: float = float(context.get("holy_barrier_y", 725.0))
	var barrier_height: float = float(context.get("holy_barrier_height", 20.0))
	var ball_rect := Rect2(
		ball_pos.x - ball_size * 0.5,
		ball_pos.y - ball_size * 0.5,
		ball_size,
		ball_size
	)
	var barrier_rect := Rect2(0.0, barrier_y, width, barrier_height)
	if not barrier_rect.intersects(ball_rect):
		return {}

	ball_pos.y = barrier_y - ball_size * 0.5
	return {
		"event": EVENT_HOLY_BARRIER,
		"ball_pos": ball_pos,
		"impact_pos": Vector2(ball_pos.x, barrier_y),
	}


func check_horn_strawberry_field(ball_pos: Vector2, ball_vel: Vector2, ball_size: float, context: Dictionary) -> Dictionary:
	if not bool(context.get("horn_strawberry_field_active", false)) or ball_vel.y <= 0.0:
		return {}
	var barriers: Array = context.get("horn_strawberry_field_barriers", [])
	if barriers.is_empty():
		return {}
	var ball_rect := Rect2(
		ball_pos.x - ball_size * 0.5,
		ball_pos.y - ball_size * 0.5,
		ball_size,
		ball_size
	)
	for barrier_value in barriers:
		if not (barrier_value is Dictionary):
			continue
		var barrier: Dictionary = barrier_value
		var barrier_rect: Rect2 = _as_rect2(barrier.get("rect", Rect2()), Rect2())
		if barrier_rect.size.x <= 0.0 or barrier_rect.size.y <= 0.0:
			continue
		if not barrier_rect.intersects(ball_rect):
			continue
		ball_pos.y = barrier_rect.position.y - ball_size * 0.5
		return {
			"event": EVENT_HORN_STRAWBERRY_FIELD,
			"ball_pos": ball_pos,
			"impact_pos": Vector2(ball_pos.x, barrier_rect.position.y),
			"barrier_id": int(barrier.get("id", 0)),
			"reflect_speed_mult": max(1.0, float(barrier.get("reflect_speed_mult", 1.05))),
		}
	return {}


func check_lingpet_bone_barrier(ball_pos: Vector2, ball_vel: Vector2, ball_size: float, context: Dictionary) -> Dictionary:
	if not bool(context.get("lingpet_bone_barrier_active", false)):
		return {}
	var barriers: Array = context.get("lingpet_bone_barrier_barriers", [])
	if barriers.is_empty():
		return {}
	var ball_rect := Rect2(
		ball_pos.x - ball_size * 0.5,
		ball_pos.y - ball_size * 0.5,
		ball_size,
		ball_size
	)
	for barrier_value in barriers:
		if not (barrier_value is Dictionary):
			continue
		var barrier: Dictionary = barrier_value
		var barrier_rect: Rect2 = _as_rect2(barrier.get("rect", Rect2()), Rect2())
		if barrier_rect.size.x <= 0.0 or barrier_rect.size.y <= 0.0:
			continue
		if not barrier_rect.intersects(ball_rect):
			continue
		var built := bool(barrier.get("built", false))
		var reflect_speed_mult := maxf(1.0, float(barrier.get("reflect_speed_mult", 1.05)))
		var hit_offset_vel_scale := float(barrier.get("hit_offset_vel_scale", 0.03))
		var next_vel := ball_vel
		var impact_y := clampf(ball_pos.y, barrier_rect.position.y, barrier_rect.end.y)
		if built:
			var reflect_down := ball_pos.y >= barrier_rect.get_center().y
			var reflected_y := absf(ball_vel.y) * reflect_speed_mult
			if not reflect_down:
				reflected_y = -reflected_y
				ball_pos.y = barrier_rect.position.y - ball_size * 0.5
				impact_y = barrier_rect.position.y
			else:
				ball_pos.y = barrier_rect.end.y + ball_size * 0.5
				impact_y = barrier_rect.end.y
			var hit_offset := ball_pos.x - barrier_rect.get_center().x
			next_vel = Vector2(ball_vel.x + hit_offset * hit_offset_vel_scale, reflected_y)
		return {
			"event": EVENT_LINGPET_BONE_BARRIER,
			"ball_pos": ball_pos,
			"ball_vel": next_vel,
			"impact_pos": Vector2(ball_pos.x, impact_y),
			"barrier_id": int(barrier.get("id", 0)),
			"built": built,
			"reflect_speed_mult": reflect_speed_mult,
		}
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return BallContextReader.as_vector2(value, fallback)


func _as_rect2(value: Variant, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value
	return fallback
