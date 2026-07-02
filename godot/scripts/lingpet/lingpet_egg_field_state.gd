extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const EGG_RADIUS := 28.0
const EGG_TEXTURE_DRAW_SIZE := Vector2(88.0, 88.0)
const EGG_FLOOR_MARGIN := 18.0
const EGG_PLAYER_NUDGE_RADIUS := 40.0
const EGG_PLAYER_NUDGE_STRENGTH := 0.32
const EGG_PLAYER_NUDGE_MAX_VX := 0.75
const EGG_PLAYER_NUDGE_MAX_STEP := 0.45
const EGG_PLAYER_NUDGE_DAMPING := 0.62
const EGG_PLAYER_WOBBLE_DAMPING := 0.72
const EGG_PLAYER_WOBBLE_SPRING := 0.35
const EGG_PLAYER_WOBBLE_MAX_DEGREES := 8.0
const EGG_DASH_CONTACT_PADDING := 8.0
const EGG_DASH_KNOCKBACK_VX := 13.5
const EGG_DASH_MIN_VX := 8.0
const EGG_DASH_MAX_VX := 16.0
const EGG_DASH_FRICTION := 0.94
const EGG_DASH_STOP_VX := 0.08
const EGG_DASH_WALL_RESTITUTION := 0.72
const EGG_DASH_WALL_MIN_REBOUND_VX := 5.0
const EGG_DASH_CONTACT_COOLDOWN_SECONDS := 0.12
const EGG_DASH_WOBBLE_IMPULSE := 5.5
const EGG_ROLL_CONTACT_RADIUS := 30.0
const EGG_ROLL_SETTLE_RATE := 0.22
const EGG_ROLL_SETTLE_EPSILON := 0.02
const EGG_VARIANT_COUNT := 5
const BALL_RADIUS_FALLBACK := 14.3
const HIT_COOLDOWN_SECONDS := 0.20
const PADDLE_BOUNCE_DEFAULT_MAX_ANGLE := 60.0
const PADDLE_BOUNCE_DEFAULT_MIN_SPEED := 3.0
const PADDLE_BOUNCE_DEFAULT_MAX_SPEED := 20.0

var hatch_hits := 0
var egg_color_index := -1
var pos := Vector2.ZERO
var nudge_vx := 0.0
var dash_vx := 0.0
var roll_angle := 0.0
var wobble_angle := 0.0
var wobble_vel := 0.0
var hatch_flash_timer := 0.0
var ball_was_inside := false
var hit_cooldown := 0.0
var dash_hit_cooldown := 0.0
var dash_was_contacting := false
var _last_player_pos := Vector2.ZERO
var _last_player_pos_valid := false


func advance(delta: float) -> void:
	var safe_delta: float = maxf(0.0, delta)
	hit_cooldown = maxf(0.0, hit_cooldown - safe_delta)
	dash_hit_cooldown = maxf(0.0, dash_hit_cooldown - safe_delta)
	hatch_flash_timer = maxf(0.0, hatch_flash_timer - safe_delta)


func reset_all() -> void:
	hatch_hits = 0
	egg_color_index = -1
	pos = Vector2.ZERO
	reset_hatch_flash()
	reset_contact_motion()


func reset_contact_motion() -> void:
	nudge_vx = 0.0
	dash_vx = 0.0
	roll_angle = 0.0
	wobble_angle = 0.0
	wobble_vel = 0.0
	ball_was_inside = false
	hit_cooldown = 0.0
	dash_hit_cooldown = 0.0
	dash_was_contacting = false
	_last_player_pos = Vector2.ZERO
	_last_player_pos_valid = false


func spawn(owner: Object) -> void:
	hatch_hits = 0
	pos = resolve_spawn_pos(owner)
	roll_color_index()
	reset_hatch_flash()
	reset_contact_motion()


func set_hatched(required_hits: int) -> void:
	hatch_hits = maxi(0, required_hits)
	reset_hatch_flash()
	reset_contact_motion()


func trigger_hatch_flash(duration_seconds: float) -> void:
	hatch_flash_timer = maxf(0.0, duration_seconds)


func reset_hatch_flash() -> void:
	hatch_flash_timer = 0.0


func has_hatch_flash() -> bool:
	return hatch_flash_timer > 0.0


func get_hatch_flash_timer() -> float:
	return hatch_flash_timer


func roll_color_index() -> void:
	egg_color_index = int(randi() % EGG_VARIANT_COUNT)


func set_color_index(index: int) -> void:
	egg_color_index = index if index >= 0 and index < EGG_VARIANT_COUNT else -1


func get_color_index() -> int:
	return egg_color_index


func update_player_contact(delta: float, owner: Object, registry: Object = null) -> void:
	if pos == Vector2.ZERO:
		return
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO)
	var player_size := Vector2(
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", 50.0)))
	)
	var player_center: Vector2 = player_pos + player_size * 0.5
	var prox: Vector2 = player_center - pos
	var dist: float = prox.length()
	var frame_scale: float = minf(2.0, maxf(0.0, delta) * 60.0)
	if frame_scale > 0.0 and dist < EGG_PLAYER_NUDGE_RADIUS and dist > 1.0:
		var push_dir: float = -prox.x / dist
		if absf(push_dir) < 0.12:
			push_dir = -1.0 if player_center.x >= pos.x else 1.0
		var push_strength: float = (1.0 - dist / EGG_PLAYER_NUDGE_RADIUS) * EGG_PLAYER_NUDGE_STRENGTH * frame_scale
		nudge_vx = clampf(nudge_vx + push_dir * push_strength, -EGG_PLAYER_NUDGE_MAX_VX, EGG_PLAYER_NUDGE_MAX_VX)
		wobble_vel += push_dir * push_strength * 2.0

	var dash_context: Dictionary = _get_player_dash_context(owner, registry)
	var dash_contacting := false
	if bool(dash_context.get("active", false)):
		dash_contacting = _is_dash_contacting_egg(player_pos, player_size)
		if dash_contacting and not dash_was_contacting and dash_hit_cooldown <= 0.0:
			_apply_dash_knockback(_resolve_dash_push_direction(dash_context, player_pos, player_size))
	dash_was_contacting = dash_contacting

	if frame_scale > 0.0:
		var x_before: float = pos.x
		if absf(nudge_vx) > 0.05:
			var nudge_step: float = clampf(nudge_vx, -EGG_PLAYER_NUDGE_MAX_STEP, EGG_PLAYER_NUDGE_MAX_STEP)
			pos.x = clampf(pos.x + nudge_step, _get_egg_min_x(), _get_egg_max_x())
			nudge_vx *= pow(EGG_PLAYER_NUDGE_DAMPING, frame_scale)
		else:
			nudge_vx = 0.0
		_advance_dash_motion(frame_scale)
		_integrate_roll_from_delta(pos.x - x_before)
		if dash_vx == 0.0 and absf(nudge_vx) <= 0.05:
			_settle_roll_angle(frame_scale)
		wobble_vel += -wobble_angle * EGG_PLAYER_WOBBLE_SPRING * frame_scale
		wobble_vel *= pow(EGG_PLAYER_WOBBLE_DAMPING, frame_scale)
		wobble_angle = clampf(wobble_angle + wobble_vel, -EGG_PLAYER_WOBBLE_MAX_DEGREES, EGG_PLAYER_WOBBLE_MAX_DEGREES)
	_last_player_pos = player_pos
	_last_player_pos_valid = true


func resolve_ball_hit(owner: Object, required_hits: int) -> Dictionary:
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		ball_was_inside = false
		return {"changed": false, "hit": false, "hatched": false}

	var ball_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius: float = maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5)
	var hit_radius: float = EGG_RADIUS + ball_radius
	var inside: bool = ball_pos.distance_squared_to(pos) <= hit_radius * hit_radius
	var hit_now: bool = inside and not ball_was_inside and hit_cooldown <= 0.0
	ball_was_inside = inside
	if not hit_now:
		return {"changed": false, "hit": false, "hatched": false}

	hit_cooldown = HIT_COOLDOWN_SECONDS
	_apply_paddle_bounce(owner, ball_pos, hit_radius)
	if _is_player_serve_ball(owner):
		return {"changed": false, "hit": true, "hatched": false, "counted": false}

	var safe_required_hits: int = maxi(1, required_hits)
	hatch_hits = mini(safe_required_hits, hatch_hits + 1)
	return {
		"changed": true,
		"hit": true,
		"hatched": hatch_hits >= safe_required_hits,
		"counted": true,
	}


func get_snapshot() -> Dictionary:
	return {
		"hatch_hits": hatch_hits,
		"egg_color_index": egg_color_index,
		"egg_pos": pos,
		"egg_nudge_vx": nudge_vx,
		"egg_dash_vx": dash_vx,
		"egg_roll_angle": roll_angle,
		"egg_wobble_angle": wobble_angle,
		"egg_wobble_vel": wobble_vel,
		"hit_cooldown": hit_cooldown,
		"dash_hit_cooldown": dash_hit_cooldown,
	}


func resolve_spawn_pos(owner: Object) -> Vector2:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - 50.0))
	var player_size := Vector2(
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", 50.0)))
	)
	var center_x: float = player_pos.x + player_size.x * 0.5
	var side_sign: float = -1.0 if center_x >= FIELD_WIDTH * 0.5 else 1.0
	var x: float = center_x + side_sign * (player_size.x * 0.5 + EGG_RADIUS + 18.0)
	var y: float = FIELD_HEIGHT - EGG_RADIUS - EGG_FLOOR_MARGIN
	return Vector2(
		clampf(x, EGG_RADIUS + 14.0, FIELD_WIDTH - EGG_RADIUS - 14.0),
		clampf(y, EGG_RADIUS + 28.0, FIELD_HEIGHT - EGG_RADIUS - EGG_FLOOR_MARGIN)
	)


func _is_player_serve_ball(owner: Object) -> bool:
	return str(BattleSceneOwnerReader.get_value(owner, "ball_serve_origin", "")).strip_edges().to_lower() == "player"


func _apply_paddle_bounce(owner: Object, ball_pos: Vector2, hit_radius: float) -> void:
	var half_width: float = maxf(1.0, EGG_TEXTURE_DRAW_SIZE.x * 0.5)
	var hit_pos: float = clampf((ball_pos.x - pos.x) / half_width, -1.0, 1.0)
	var max_angle: float = float(BattleSceneOwnerReader.get_value(owner, "max_bounce_angle", PADDLE_BOUNCE_DEFAULT_MAX_ANGLE))
	var launch_dir := Vector2(0.0, -1.0).rotated(deg_to_rad(hit_pos * max_angle)).normalized()
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	var min_speed: float = maxf(0.0, float(BattleSceneOwnerReader.get_value(owner, "min_ball_speed", PADDLE_BOUNCE_DEFAULT_MIN_SPEED)))
	var max_speed: float = maxf(min_speed, float(BattleSceneOwnerReader.get_value(owner, "max_ball_speed", maxf(PADDLE_BOUNCE_DEFAULT_MAX_SPEED, ball_vel.length()))))
	var speed: float = clampf(maxf(ball_vel.length(), min_speed), min_speed, max_speed)
	owner.set("ball_vel", launch_dir * speed)
	owner.set("ball_pos", Vector2(
		clampf(ball_pos.x, _get_egg_min_x(), _get_egg_max_x()),
		pos.y - hit_radius - 1.0
	))


func _is_dash_contacting_egg(player_pos: Vector2, player_size: Vector2) -> bool:
	var padding: float = EGG_RADIUS + EGG_DASH_CONTACT_PADDING
	var sweep_rect: Rect2 = _build_player_sweep_rect(player_pos, player_size, padding)
	return sweep_rect.has_point(pos)


func _build_player_sweep_rect(player_pos: Vector2, player_size: Vector2, padding: float) -> Rect2:
	var previous_pos: Vector2 = _last_player_pos if _last_player_pos_valid else player_pos
	var min_x: float = minf(previous_pos.x, player_pos.x)
	var min_y: float = minf(previous_pos.y, player_pos.y)
	var max_x: float = maxf(previous_pos.x + player_size.x, player_pos.x + player_size.x)
	var max_y: float = maxf(previous_pos.y + player_size.y, player_pos.y + player_size.y)
	var origin := Vector2(min_x - padding, min_y - padding)
	var size := Vector2(max_x - min_x + padding * 2.0, max_y - min_y + padding * 2.0)
	return Rect2(origin, size)


func _apply_dash_knockback(direction: float) -> void:
	var push_dir: float = _normalize_direction(direction)
	if push_dir == 0.0:
		return
	dash_vx = clampf(dash_vx + push_dir * EGG_DASH_KNOCKBACK_VX, -EGG_DASH_MAX_VX, EGG_DASH_MAX_VX)
	if absf(dash_vx) < EGG_DASH_MIN_VX:
		dash_vx = push_dir * EGG_DASH_MIN_VX
	wobble_vel += push_dir * EGG_DASH_WOBBLE_IMPULSE
	dash_hit_cooldown = EGG_DASH_CONTACT_COOLDOWN_SECONDS


func _advance_dash_motion(frame_scale: float) -> void:
	if absf(dash_vx) <= EGG_DASH_STOP_VX:
		dash_vx = 0.0
		return
	var next_x: float = pos.x + dash_vx * frame_scale
	if next_x <= _get_egg_min_x():
		pos.x = _get_egg_min_x()
		_reflect_dash_from_wall(1.0)
	elif next_x >= _get_egg_max_x():
		pos.x = _get_egg_max_x()
		_reflect_dash_from_wall(-1.0)
	else:
		pos.x = next_x
		dash_vx *= pow(EGG_DASH_FRICTION, frame_scale)
	if absf(dash_vx) <= EGG_DASH_STOP_VX:
		dash_vx = 0.0


func _reflect_dash_from_wall(wall_push_direction: float) -> void:
	var push_dir: float = _normalize_direction(wall_push_direction)
	if push_dir == 0.0:
		return
	var rebound_speed: float = maxf(EGG_DASH_WALL_MIN_REBOUND_VX, absf(dash_vx) * EGG_DASH_WALL_RESTITUTION)
	dash_vx = clampf(push_dir * rebound_speed, -EGG_DASH_MAX_VX, EGG_DASH_MAX_VX)
	wobble_vel += push_dir * EGG_DASH_WOBBLE_IMPULSE * 0.6


func _integrate_roll_from_delta(delta_x: float) -> void:
	if absf(delta_x) <= 0.0001:
		return
	roll_angle = fposmod(roll_angle + delta_x / EGG_ROLL_CONTACT_RADIUS, TAU)


func _settle_roll_angle(frame_scale: float) -> void:
	var settle_delta: float = _get_upright_roll_delta()
	if absf(settle_delta) <= EGG_ROLL_SETTLE_EPSILON:
		roll_angle = 0.0
		return
	roll_angle = fposmod(roll_angle + settle_delta * minf(1.0, EGG_ROLL_SETTLE_RATE * frame_scale), TAU)
	if absf(_get_upright_roll_delta()) <= EGG_ROLL_SETTLE_EPSILON:
		roll_angle = 0.0


func _get_upright_roll_delta() -> float:
	return -roll_angle if roll_angle <= PI else TAU - roll_angle


func _resolve_dash_push_direction(dash_context: Dictionary, player_pos: Vector2, player_size: Vector2) -> float:
	var dash_direction: float = float(dash_context.get("direction", 0.0))
	if absf(dash_direction) > 0.01:
		return _normalize_direction(dash_direction)
	if _last_player_pos_valid:
		var move_delta_x: float = player_pos.x - _last_player_pos.x
		if absf(move_delta_x) > 0.01:
			return _normalize_direction(move_delta_x)
	var player_center_x: float = player_pos.x + player_size.x * 0.5
	if absf(player_center_x - pos.x) > 0.01:
		return -1.0 if player_center_x > pos.x else 1.0
	return 1.0


func _get_player_dash_context(owner: Object, registry: Object) -> Dictionary:
	var context := {
		"active": false,
		"direction": 0.0,
	}
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	if dash_state != null:
		if dash_state.has_method("get_snapshot"):
			var snapshot_value: Variant = dash_state.get_snapshot()
			if snapshot_value is Dictionary:
				var snapshot: Dictionary = snapshot_value
				context["active"] = bool(snapshot.get("active", context.get("active", false)))
				context["direction"] = float(snapshot.get("direction", context.get("direction", 0.0)))
		elif dash_state.has_method("is_active") and bool(dash_state.is_active()):
			context["active"] = true
	if owner != null:
		if not bool(context.get("active", false)):
			for key in ["dash_active", "player_dash_active", "soul_burst_dash_active"]:
				var active_value: Variant = owner.get(str(key))
				if active_value != null and bool(active_value):
					context["active"] = true
					break
		if absf(float(context.get("direction", 0.0))) <= 0.01:
			for key in ["dash_direction", "player_dash_direction", "smasher_dash_direction", "sensor_last_dash_direction", "poseidon_last_dash_direction"]:
				var direction_value: Variant = owner.get(str(key))
				if direction_value != null and absf(float(direction_value)) > 0.01:
					context["direction"] = float(direction_value)
					break
	return context


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if value is Object:
		return value
	return null


func _normalize_direction(direction: float) -> float:
	if direction > 0.01:
		return 1.0
	if direction < -0.01:
		return -1.0
	return 0.0


func _get_egg_min_x() -> float:
	return EGG_TEXTURE_DRAW_SIZE.x * 0.5


func _get_egg_max_x() -> float:
	return FIELD_WIDTH - EGG_TEXTURE_DRAW_SIZE.x * 0.5
