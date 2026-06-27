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
const EGG_TINT_COUNT := 5
const BALL_RADIUS_FALLBACK := 14.3
const HIT_COOLDOWN_SECONDS := 0.20
const PADDLE_BOUNCE_DEFAULT_MAX_ANGLE := 60.0
const PADDLE_BOUNCE_DEFAULT_MIN_SPEED := 3.0
const PADDLE_BOUNCE_DEFAULT_MAX_SPEED := 20.0

var hatch_hits := 0
var egg_color_index := -1
var pos := Vector2.ZERO
var nudge_vx := 0.0
var wobble_angle := 0.0
var wobble_vel := 0.0
var ball_was_inside := false
var hit_cooldown := 0.0


func advance(delta: float) -> void:
	hit_cooldown = maxf(0.0, hit_cooldown - maxf(0.0, delta))


func reset_all() -> void:
	hatch_hits = 0
	egg_color_index = -1
	pos = Vector2.ZERO
	reset_contact_motion()


func reset_contact_motion() -> void:
	nudge_vx = 0.0
	wobble_angle = 0.0
	wobble_vel = 0.0
	ball_was_inside = false
	hit_cooldown = 0.0


func spawn(owner: Object) -> void:
	hatch_hits = 0
	pos = resolve_spawn_pos(owner)
	roll_color_index()
	reset_contact_motion()


func set_hatched(required_hits: int) -> void:
	hatch_hits = maxi(0, required_hits)
	reset_contact_motion()


func roll_color_index() -> void:
	egg_color_index = int(randi() % EGG_TINT_COUNT)


func set_color_index(index: int) -> void:
	egg_color_index = index if index >= 0 and index < EGG_TINT_COUNT else -1


func get_color_index() -> int:
	return egg_color_index


func update_player_contact(delta: float, owner: Object) -> void:
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

	if frame_scale > 0.0:
		if absf(nudge_vx) > 0.05:
			var nudge_step: float = clampf(nudge_vx, -EGG_PLAYER_NUDGE_MAX_STEP, EGG_PLAYER_NUDGE_MAX_STEP)
			pos.x = clampf(pos.x + nudge_step, EGG_TEXTURE_DRAW_SIZE.x * 0.5, FIELD_WIDTH - EGG_TEXTURE_DRAW_SIZE.x * 0.5)
			nudge_vx *= pow(EGG_PLAYER_NUDGE_DAMPING, frame_scale)
		else:
			nudge_vx = 0.0
		wobble_vel += -wobble_angle * EGG_PLAYER_WOBBLE_SPRING * frame_scale
		wobble_vel *= pow(EGG_PLAYER_WOBBLE_DAMPING, frame_scale)
		wobble_angle = clampf(wobble_angle + wobble_vel, -EGG_PLAYER_WOBBLE_MAX_DEGREES, EGG_PLAYER_WOBBLE_MAX_DEGREES)


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
		"egg_wobble_angle": wobble_angle,
		"egg_wobble_vel": wobble_vel,
		"hit_cooldown": hit_cooldown,
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
		clampf(ball_pos.x, EGG_TEXTURE_DRAW_SIZE.x * 0.5, FIELD_WIDTH - EGG_TEXTURE_DRAW_SIZE.x * 0.5),
		pos.y - hit_radius - 1.0
	))
