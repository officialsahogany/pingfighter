extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const EGG_RADIUS := 28.0
const EGG_TEXTURE_DRAW_SIZE := Vector2(88.0, 88.0)
const EGG_FLOOR_MARGIN := 18.0
const EGG_PLAYER_NUDGE_RADIUS := 47.0
const EGG_PLAYER_NUDGE_STRENGTH := 0.50
const EGG_PLAYER_NUDGE_MAX_VX := 1.2
const EGG_PLAYER_NUDGE_MAX_STEP := 0.74
const EGG_PLAYER_NUDGE_DAMPING := 0.72
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
# 공 피격 넉백(2026-07-06 전시 후속, WIP 파괴 후 재구현): counted 비최종
# 히트에 접촉 반대방향으로 dash 임펄스 레인을 재사용한다 — 마찰·벽반동·
# 굴림 적분·오뚜기 셋틀이 공짜로 따라온다. 6.0 ≈ 100px 스키드.
const EGG_BALL_HIT_KNOCKBACK_VX := 6.0
const EGG_BALL_HIT_WOBBLE_IMPULSE := 4.0
const EGG_ROLL_CONTACT_RADIUS := 30.0
# Roly-poly (오뚜기) settle: a damped restoring spring toward upright, NOT a
# monotonic ease. Low stiffness + high damping-retention makes the egg tip
# past upright and wobble back a few times before resting, instead of
# snapping back instantly. Tuned for a slow, gentle weeble.
const EGG_ROLL_SETTLE_STIFFNESS := 0.055
const EGG_ROLL_SETTLE_DAMPING := 0.90
const EGG_ROLL_SETTLE_EPSILON := 0.02
const EGG_VARIANT_COUNT := 5
# Per-egg hatch difficulty pool: every egg needs 2-4 counted hits and cracks
# per counted hit before breaking. Rolled once at spawn, pet-independent
# (same spoiler-blocking rule as the visual variant roll). 0 = unrolled, so
# consumers fall back to the caller-supplied value (legacy behavior).
const HATCH_REQUIRED_HITS_POOL: Array[int] = [2, 3, 4]
# Shell-break cinematic between the final counted hit and the acquire cut-in:
# the egg rolls restlessly under a build-then-settle envelope, shivers harder
# as the break approaches, and comes to rest before the shell bursts. Battle
# physics is paused for the whole window (modal gate), so this motion is
# advanced from the ungated idle pump via advance_hatch_break(), never from
# the gated update path.
const HATCH_BREAK_SECONDS := 1.5
const HATCH_BREAK_ROLL_AMPLITUDE := 30.0
const HATCH_BREAK_ROLL_FREQ_PRIMARY_HZ := 1.6
const HATCH_BREAK_ROLL_FREQ_SECONDARY_HZ := 3.7
# Roll envelope dies out at this ratio of the break so the burst fires from a
# stationary egg (the shard burst anchors cleanly instead of mid-swing).
const HATCH_BREAK_MOTION_END_RATIO := 0.84
const HATCH_BREAK_SHIVER_RATE := 43.0
const HATCH_BREAK_SHIVER_MAX_DEGREES := 4.5
const BALL_RADIUS_FALLBACK := 14.3
const HIT_COOLDOWN_SECONDS := 0.20
const PADDLE_BOUNCE_DEFAULT_MAX_ANGLE := 60.0
const PADDLE_BOUNCE_DEFAULT_MIN_SPEED := 3.0
const PADDLE_BOUNCE_DEFAULT_MAX_SPEED := 20.0

var hatch_hits := 0
var hatch_required_hits := 0
var egg_color_index := -1
var pos := Vector2.ZERO
var nudge_vx := 0.0
var dash_vx := 0.0
var roll_angle := 0.0
var roll_settle_vel := 0.0
var wobble_angle := 0.0
var wobble_vel := 0.0
var hatch_flash_timer := 0.0
var hatch_break_active := false
var hatch_break_elapsed := 0.0
var _hatch_break_origin_x := 0.0
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
	hatch_required_hits = 0
	egg_color_index = -1
	pos = Vector2.ZERO
	reset_hatch_flash()
	reset_hatch_break()
	reset_contact_motion()


func reset_contact_motion() -> void:
	nudge_vx = 0.0
	dash_vx = 0.0
	roll_angle = 0.0
	roll_settle_vel = 0.0
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
	roll_required_hits()
	reset_hatch_flash()
	reset_hatch_break()
	reset_contact_motion()


func set_hatched(required_hits: int) -> void:
	hatch_hits = maxi(0, required_hits)
	reset_hatch_flash()
	reset_hatch_break()
	reset_contact_motion()


func trigger_hatch_flash(duration_seconds: float) -> void:
	hatch_flash_timer = maxf(0.0, duration_seconds)


func trigger_hatch_break() -> void:
	hatch_break_active = true
	hatch_break_elapsed = 0.0
	_hatch_break_origin_x = pos.x
	# The scripted break roll owns the egg from here; drop residual contact
	# motion so player nudges / dash momentum cannot fight the choreography.
	nudge_vx = 0.0
	dash_vx = 0.0
	wobble_vel = 0.0
	roll_settle_vel = 0.0


func reset_hatch_break() -> void:
	hatch_break_active = false
	hatch_break_elapsed = 0.0
	_hatch_break_origin_x = 0.0


func is_hatch_break_active() -> bool:
	return hatch_break_active


func get_hatch_break_progress() -> float:
	if HATCH_BREAK_SECONDS <= 0.0:
		return 1.0
	return clampf(hatch_break_elapsed / HATCH_BREAK_SECONDS, 0.0, 1.0)


# Advances the scripted shell-break motion. Returns true exactly once, on the
# frame the break completes (the caller then bursts the shell + starts the
# burst hold). Restless roll: two mixed sine rates under a build-then-settle
# envelope, with the net offset returning to the origin so the burst anchors
# where the egg rested; shiver builds toward the burst independently.
func advance_hatch_break(delta: float) -> bool:
	if not hatch_break_active:
		return false
	var safe_delta: float = maxf(0.0, delta)
	var frame_scale: float = minf(2.0, safe_delta * 60.0)
	hatch_break_elapsed += safe_delta
	var t: float = clampf(hatch_break_elapsed / HATCH_BREAK_SECONDS, 0.0, 1.0)
	var motion_t: float = clampf(t / HATCH_BREAK_MOTION_END_RATIO, 0.0, 1.0)
	var envelope: float = sin(PI * motion_t)
	var swing: float = (
		sin(TAU * HATCH_BREAK_ROLL_FREQ_PRIMARY_HZ * hatch_break_elapsed)
		+ 0.38 * sin(TAU * HATCH_BREAK_ROLL_FREQ_SECONDARY_HZ * hatch_break_elapsed + 1.1)
	)
	var prev_x: float = pos.x
	pos.x = clampf(
		_hatch_break_origin_x + swing * envelope * HATCH_BREAK_ROLL_AMPLITUDE,
		_get_egg_min_x(),
		_get_egg_max_x()
	)
	_integrate_roll_from_delta(pos.x - prev_x)
	if motion_t >= 1.0:
		# Settle tail: ease any residual tilt back upright before the burst.
		_settle_roll_angle(frame_scale)
	wobble_angle = clampf(
		sin(hatch_break_elapsed * HATCH_BREAK_SHIVER_RATE)
			* HATCH_BREAK_SHIVER_MAX_DEGREES * pow(t, 1.5),
		-EGG_PLAYER_WOBBLE_MAX_DEGREES,
		EGG_PLAYER_WOBBLE_MAX_DEGREES
	)
	if hatch_break_elapsed >= HATCH_BREAK_SECONDS:
		hatch_break_active = false
		wobble_angle = 0.0
		return true
	return false


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


# rng is injectable so tests can roll deterministically off a LOCAL RandomNumberGenerator
# without draining the global randi() stream that RNG-coupled callers rely on. Production
# spawn() passes nothing -> global randi (unchanged behavior).
func roll_required_hits(rng: RandomNumberGenerator = null) -> void:
	var raw: int = rng.randi() if rng != null else randi()
	hatch_required_hits = int(HATCH_REQUIRED_HITS_POOL[raw % HATCH_REQUIRED_HITS_POOL.size()])


func set_required_hits(value: int) -> void:
	hatch_required_hits = maxi(0, value)


func get_required_hits(fallback: int = 0) -> int:
	return hatch_required_hits if hatch_required_hits >= 1 else maxi(0, fallback)


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
		else:
			# Still being driven by dash/walk; drop stale settle momentum so the
			# weeble spring starts fresh the moment motion stops.
			roll_settle_vel = 0.0
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

	# 플레이어가 서브로 발사한 공은 수호령 알과 타격판정 자체를 하지 않는다: 바운스도,
	# 부화 카운트도, 히트 SFX도 없이 공이 알을 그대로 통과한다(hit=false). 히트
	# 쿨다운도 세팅하지 않으므로, ball_serve_origin이 "player"인 동안에는 같은 라운드의
	# 공이 다시 겹쳐도 계속 통과한다. (예전에는 바운스+SFX는 시키고 카운트만 제외했지만,
	# 사용자 요청으로 서브공은 알을 완전히 무시하도록 바꿨다.)
	if _is_player_serve_ball(owner):
		return {"changed": false, "hit": false, "hatched": false, "counted": false}

	hit_cooldown = HIT_COOLDOWN_SECONDS
	# 진입 vx는 바운스 반사 전에 보존한다 — 데드센터 접촉의 넉백 방향
	# 폴백이 반사된(0이 될 수 있는) vx를 읽으면 원래 진행방향이 소실된다.
	var entry_ball_vel_x: float = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO).x
	_apply_paddle_bounce(owner, ball_pos, hit_radius)

	var safe_required_hits: int = maxi(1, required_hits)
	hatch_hits = mini(safe_required_hits, hatch_hits + 1)
	var hatched: bool = hatch_hits >= safe_required_hits
	if not hatched:
		# 피격 넉백은 counted 비최종 히트 전용. 최종 히트는 임펄스 금지 —
		# trigger_hatch_break가 잔여 모션을 zero로 만들고 셸브레이크 안무가
		# 위치를 소유한다.
		_apply_ball_hit_knockback(ball_pos, entry_ball_vel_x)
	return {
		"changed": true,
		"hit": true,
		"hatched": hatched,
		"counted": true,
	}


# 접촉 반대방향으로 굴러가며 튕겨나가는 스키드. 데드센터(수직 낙하 등)는
# 반사 전 진입 vx(공의 원래 진행 방향)를, 그것도 0이면 필드의 넓은 쪽을
# 따른다. 피격 직후의 dash_vx 부호는 반드시 의도 방향과 일치해야 한다 —
# 반대 잔여 모멘텀(예: +16)에 단순 가산하면 알이 접촉 쪽으로 계속 간다.
func _apply_ball_hit_knockback(ball_pos: Vector2, entry_ball_vel_x: float) -> void:
	var direction: float = signf(pos.x - ball_pos.x)
	if direction == 0.0:
		direction = signf(entry_ball_vel_x)
	if direction == 0.0:
		direction = 1.0 if pos.x < 380.0 else -1.0
	var boosted: float = dash_vx + direction * EGG_BALL_HIT_KNOCKBACK_VX
	if signf(boosted) != direction or absf(boosted) < EGG_BALL_HIT_KNOCKBACK_VX:
		boosted = direction * EGG_BALL_HIT_KNOCKBACK_VX
	dash_vx = clampf(boosted, -EGG_DASH_MAX_VX, EGG_DASH_MAX_VX)
	wobble_vel += direction * EGG_BALL_HIT_WOBBLE_IMPULSE


func get_snapshot() -> Dictionary:
	return {
		"hatch_hits": hatch_hits,
		"egg_required_hits": hatch_required_hits,
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
	var to_upright: float = _get_upright_roll_delta()
	# Rest only when BOTH the tilt and the wobble velocity are near zero, so the
	# egg is allowed to overshoot upright and swing back (오뚜기) rather than
	# snapping the instant it first crosses upright.
	if absf(to_upright) <= EGG_ROLL_SETTLE_EPSILON and absf(roll_settle_vel) <= EGG_ROLL_SETTLE_EPSILON:
		roll_angle = 0.0
		roll_settle_vel = 0.0
		return
	# Damped restoring spring toward upright: accelerate toward 0, bleed velocity.
	roll_settle_vel += to_upright * EGG_ROLL_SETTLE_STIFFNESS * frame_scale
	roll_settle_vel *= pow(EGG_ROLL_SETTLE_DAMPING, frame_scale)
	roll_angle = fposmod(roll_angle + roll_settle_vel * frame_scale, TAU)


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
