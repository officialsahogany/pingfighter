extends RefCounted

const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const Stage3BossSkillPayloadFactory := preload("res://scripts/stages/stage3/stage3_boss_skill_payload_factory.gd")
const Stage3TailWhipGeometry := preload("res://scripts/stages/stage3/stage3_tail_whip_geometry.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const INITIAL_COOLDOWN_SEC := 5.0
const COOLDOWN_MIN_SEC := 5.0
const COOLDOWN_MAX_SEC := 10.0
const DURATION_SEC := 1.0
const CURVE_DURATION_SEC := 2.0
const TRACK_PROGRESS_LIMIT := 0.5
const BASE_SPEED_MAX := 18.0
const HIT_BURST_SEC := 0.55
const MAX_HIT_BURSTS := 4
const HIT_PROGRESS_MIN := Stage3TailWhipGeometry.TAIL_HIT_PROGRESS_MIN
const HIT_PROGRESS_MAX := Stage3TailWhipGeometry.TAIL_HIT_PROGRESS_MAX
const HIT_RADIUS := Stage3TailWhipGeometry.TAIL_HIT_RADIUS
const POINT_COUNT := Stage3TailWhipGeometry.TAIL_POINT_COUNT
const COLLISION_MID_INDEX_RANGE := Stage3TailWhipGeometry.TAIL_COLLISION_MID_INDEX_RANGE

var tail_whip_active := false
var tail_whip_timer := 0.0
var tail_whip_cooldown := INITIAL_COOLDOWN_SEC
var tail_hit_ball := false
var tail_curve_active := false
var tail_curve_timer := 0.0
var tail_curve_direction := 0
var tail_whip_target := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
var tail_has_target := false
var tail_points: Array[Vector2] = []
var tail_hit_bursts: Array = []

var _rng: RandomNumberGenerator


func _init(shared_rng: RandomNumberGenerator) -> void:
	_rng = shared_rng


func reset() -> void:
	tail_whip_cooldown = INITIAL_COOLDOWN_SEC
	reset_effects()


func reset_effects() -> void:
	tail_whip_active = false
	tail_whip_timer = 0.0
	tail_hit_ball = false
	tail_curve_active = false
	tail_curve_timer = 0.0
	tail_curve_direction = 0
	tail_has_target = false
	tail_points.clear()
	tail_hit_bursts.clear()


func update_cooldown(delta: float, enabled: bool) -> void:
	if enabled and not tail_whip_active:
		tail_whip_cooldown = max(0.0, tail_whip_cooldown - delta)


func roll_cooldown() -> float:
	tail_whip_cooldown = _rng.randf_range(COOLDOWN_MIN_SEC, COOLDOWN_MAX_SEC)
	return tail_whip_cooldown


func is_ready() -> bool:
	return tail_whip_cooldown <= 0.0 and not tail_whip_active


func activate(target: Vector2, elapsed_msec: int) -> void:
	tail_whip_active = true
	tail_whip_timer = DURATION_SEC
	tail_hit_ball = false
	tail_whip_target = target
	tail_has_target = true
	tail_points = Stage3TailWhipGeometry.build_points(
		0.0,
		tail_whip_target,
		Vector2(WIDTH * 0.5, HEIGHT * 0.5),
		elapsed_msec
	)


func consume_parried() -> void:
	reset_effects()
	roll_cooldown()


func update(delta: float, context: Dictionary, result: Dictionary, elapsed_msec: int) -> Dictionary:
	if tail_curve_active:
		tail_curve_timer = max(0.0, tail_curve_timer - delta)
		var ball_vel: Vector2 = _as_vector2(result.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
		var curve_strength: float = 0.3 * (tail_curve_timer / CURVE_DURATION_SEC)
		ball_vel.x += float(tail_curve_direction) * curve_strength * delta * 60.0
		if ball_vel.length() > BASE_SPEED_MAX:
			ball_vel = ball_vel.normalized() * BASE_SPEED_MAX
		result["ball_vel"] = ball_vel
		if tail_curve_timer <= 0.0:
			tail_curve_active = false
	if not tail_whip_active:
		tail_points.clear()
		return {}

	tail_whip_timer = max(0.0, tail_whip_timer - delta)
	var progress: float = 1.0 - tail_whip_timer / max(0.001, DURATION_SEC)
	if progress < TRACK_PROGRESS_LIMIT:
		tail_whip_target = _as_vector2(result.get("ball_pos", context.get("ball_pos", tail_whip_target)), tail_whip_target)
	tail_points = Stage3TailWhipGeometry.build_points(
		progress,
		tail_whip_target,
		Vector2(WIDTH * 0.5, HEIGHT * 0.5),
		elapsed_msec
	)
	var hit_event: Dictionary = {}
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	if not tail_hit_ball and Stage3TailWhipGeometry.hits_ball(progress, ball_pos, tail_points):
		hit_event = _apply_hit(ball_pos, context, result)
	if tail_whip_timer <= 0.0:
		tail_whip_active = false
		roll_cooldown()
		tail_has_target = false
		tail_points.clear()
	return hit_event


func update_bursts(delta: float) -> void:
	var write_idx: int = 0
	for idx in range(tail_hit_bursts.size()):
		var burst: Dictionary = tail_hit_bursts[idx]
		burst["life"] = float(burst.get("life", 0.0)) - delta
		if float(burst.get("life", 0.0)) <= 0.0:
			continue
		tail_hit_bursts[write_idx] = burst
		write_idx += 1
	if write_idx < tail_hit_bursts.size():
		tail_hit_bursts.resize(write_idx)


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage3_tail_whip_active": tail_whip_active,
		"stage3_tail_whip_progress": 1.0 - tail_whip_timer / max(0.001, DURATION_SEC),
		"stage3_tail_whip_target": tail_whip_target,
		"stage3_tail_points": StageActorDrawContextArrays.snapshot(tail_points, copy_arrays, true),
		"stage3_tail_curve_active": tail_curve_active,
		"stage3_tail_hit_bursts": StageActorDrawContextArrays.snapshot(tail_hit_bursts, copy_arrays, true),
	}


func _apply_hit(ball_pos: Vector2, context: Dictionary, result: Dictionary) -> Dictionary:
	tail_hit_ball = true
	tail_curve_active = true
	tail_curve_timer = CURVE_DURATION_SEC
	var ball_vel: Vector2 = _as_vector2(result.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
	var center := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
	var direction: Vector2 = center - ball_pos
	if direction.length() > 0.0:
		direction = direction.normalized()
	var redirected_vel: Vector2 = direction * (ball_vel.length() * 0.85)
	result["ball_vel"] = redirected_vel
	result["ball_impact_boost"] = 1.0
	tail_curve_direction = 1 if ball_pos.x < center.x else -1
	_create_hit_burst(ball_pos, redirected_vel)
	return {
		"ball_pos": ball_pos,
		"redirected_vel": redirected_vel,
	}


func _create_hit_burst(pos: Vector2, redirected_vel: Vector2) -> void:
	tail_hit_bursts.append(Stage3BossSkillPayloadFactory.build_tail_hit_burst(
		pos,
		redirected_vel,
		HIT_BURST_SEC,
		_rng
	))
	if tail_hit_bursts.size() > MAX_HIT_BURSTS:
		_trim_array_from_front(tail_hit_bursts, MAX_HIT_BURSTS)


func _trim_array_from_front(source: Array, max_size: int) -> void:
	var overflow: int = source.size() - max_size
	if overflow <= 0:
		return
	var write_idx: int = 0
	for read_idx in range(overflow, source.size()):
		source[write_idx] = source[read_idx]
		write_idx += 1
	source.resize(write_idx)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
