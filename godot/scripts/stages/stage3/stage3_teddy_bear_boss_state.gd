extends RefCounted

const PlayerKnockbackImmunity := preload("res://scripts/stages/common/player_knockback_immunity.gd")

const STAGE_ID := 3
const VARIANT_ID := "teddy_bear"
const WIDTH := 760.0
const HEIGHT := 750.0
const LEGACY_FPS := 60.0
const GAUGE_MAX := 500.0
const GAUGE_GAIN_ON_HIT := 50.0

const COTTON_THROW_COST := 200.0
const COTTON_THROW_CHANCE := 0.15
const COTTON_THROW_COOLDOWN_SEC := 600.0 / LEGACY_FPS
const COTTON_THROW_WINDUP_SEC := 30.0 / LEGACY_FPS
const COTTON_THROW_COUNT_MIN := 3
const COTTON_THROW_COUNT_MAX := 5
const COTTON_THROW_SPEED := 4.0
const COTTON_THROW_LIFETIME_SEC := 240.0 / LEGACY_FPS
const COTTON_THROW_HIT_RADIUS := 22.0
const COTTON_BLACKOUT_DURATION_SEC := 120.0 / LEGACY_FPS
const COTTON_BLACKOUT_FULL_SEC := 30.0 / LEGACY_FPS

const COTTON_BOMB_COST := 150.0
const COTTON_BOMB_CHANCE := 0.10
const COTTON_BOMB_COOLDOWN_SEC := 720.0 / LEGACY_FPS
const COTTON_BOMB_WINDUP_SEC := 30.0 / LEGACY_FPS
const COTTON_BOMB_COUNT_MIN := 3
const COTTON_BOMB_COUNT_MAX := 5
const COTTON_BOMB_LIFETIME_SEC := 480.0 / LEGACY_FPS
const COTTON_BOMB_HIT_RADIUS := 24.0
const COTTON_BOMB_PLAYER_SLOW_SEC := 120.0 / LEGACY_FPS
const COTTON_BOMB_SLOW_MULTIPLIER := 0.50
const COTTON_BOMB_FRAGMENT_COUNT := 4
const COTTON_BOMB_FRAGMENT_SPEED := 3.0
const COTTON_BOMB_FRAGMENT_LIFETIME_SEC := 90.0 / LEGACY_FPS
const GHOST_CURVE_DURATION_SEC := 60.0 / LEGACY_FPS

const DEADLY_HUG_COST := 250.0
const DEADLY_HUG_CHANCE := 0.20
const DEADLY_HUG_COOLDOWN_SEC := 900.0 / LEGACY_FPS
const DEADLY_HUG_DURATION_SEC := 300.0 / LEGACY_FPS
const DEADLY_HUG_RUSH_SPEED := 6.0
const DEADLY_HUG_ZONE_WIDTH := 350.0
const DEADLY_HUG_ZONE_Y := 630.0

const HEART_BEAM_COST := 150.0
# The legacy comment says 13%, but the live branch compares against 0.20.
const HEART_BEAM_CHANCE := 0.20
const HEART_BEAM_COOLDOWN_SEC := 480.0 / LEGACY_FPS
const HEART_BEAM_SPEED := 9.0
const HEART_BEAM_SIZE := 12.0
const HEART_BEAM_HIT_RADIUS := 18.0
const HEART_KNOCKBACK_DURATION_SEC := 72.0 / LEGACY_FPS

var rng := RandomNumberGenerator.new()
var boss_special_gauge := 0.0
var hit_timer := 0.0
var status := "charging"

var cotton_throw_cooldown := 0.0
var cotton_throw_windup := 0.0
var cotton_throw_projectiles: Array = []
var blackout_timer := 0.0

var cotton_bomb_cooldown := 0.0
var cotton_bomb_windup := 0.0
var cotton_bombs: Array = []
var cotton_fragments: Array = []
var cotton_slow_timer := 0.0
var ghost_curve_timer := 0.0
var ghost_curve_phase := 0.0
var ghost_curve_seed := 1.0
var ghost_trail: Array = []

var deadly_hug_cooldown := 0.0
var deadly_hug_rush_active := false
var deadly_hug_rush_y := 0.0
var deadly_hug_timer := 0.0
var latest_player_pos := Vector2.ZERO
var latest_player_size := Vector2(155.0, 50.0)

var heart_beam_cooldown := 0.0
var heart_projectile: Dictionary = {}
var heart_trail: Array = []
var heart_knockback_timer := 0.0
var heart_knockback_schedule: Array = []
var heart_particles: Array = []


func _init() -> void:
	rng.seed = 33031


func reset() -> void:
	boss_special_gauge = 0.0
	cotton_throw_cooldown = 0.0
	cotton_bomb_cooldown = 0.0
	deadly_hug_cooldown = 0.0
	heart_beam_cooldown = 0.0
	_reset_round_effects()


func reset_round() -> void:
	# Legacy round cleanup preserves the four cooldown clocks and boss gauge.
	_reset_round_effects()


func _reset_round_effects() -> void:
	hit_timer = 0.0
	status = "charging"
	cotton_throw_windup = 0.0
	cotton_throw_projectiles.clear()
	blackout_timer = 0.0
	cotton_bomb_windup = 0.0
	cotton_bombs.clear()
	cotton_fragments.clear()
	cotton_slow_timer = 0.0
	ghost_curve_timer = 0.0
	ghost_curve_phase = 0.0
	ghost_trail.clear()
	deadly_hug_rush_active = false
	deadly_hug_rush_y = 0.0
	deadly_hug_timer = 0.0
	heart_projectile.clear()
	heart_trail.clear()
	heart_knockback_timer = 0.0
	heart_knockback_schedule.clear()
	heart_particles.clear()


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or str(context.get("stage_boss_variant", "")) != VARIANT_ID:
		return {}
	var step := clampf(delta, 0.0, 0.05)
	latest_player_pos = _as_vector2(context.get("player_pos", latest_player_pos), latest_player_pos)
	latest_player_size = _as_vector2(context.get("player_paddle_size", latest_player_size), latest_player_size)
	hit_timer = maxf(0.0, hit_timer - step)
	if not _is_cooldown_paused(context):
		cotton_throw_cooldown = maxf(0.0, cotton_throw_cooldown - step)
		cotton_bomb_cooldown = maxf(0.0, cotton_bomb_cooldown - step)
		deadly_hug_cooldown = maxf(0.0, deadly_hug_cooldown - step)
		heart_beam_cooldown = maxf(0.0, heart_beam_cooldown - step)
	blackout_timer = maxf(0.0, blackout_timer - step)
	cotton_slow_timer = maxf(0.0, cotton_slow_timer - step)
	if cotton_slow_timer > 0.0:
		_apply_cotton_slow(deps)
	var result: Dictionary = {}
	_update_cotton_throw(step, context, deps)
	_update_cotton_bombs(step, context, deps, result)
	_update_deadly_hug(step, context, deps)
	_update_heart_beam(step, context, deps, result)
	_update_visual_particles(step)
	status = _resolve_status()
	return result


func register_boss_hit(_ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or str(context.get("stage_boss_variant", "")) != VARIANT_ID:
		return {}
	boss_special_gauge = minf(GAUGE_MAX, boss_special_gauge + GAUGE_GAIN_ON_HIT)
	hit_timer = 0.35
	var triggered := {
		"cotton_throw": false,
		"cotton_bomb": false,
		"deadly_hug": false,
		"heart_beam": false,
	}
	if (
		boss_special_gauge >= COTTON_THROW_COST
		and cotton_throw_projectiles.is_empty()
		and cotton_throw_windup <= 0.0
		and cotton_throw_cooldown <= 0.0
		and rng.randf() <= COTTON_THROW_CHANCE
	):
		_activate_cotton_throw(deps)
		boss_special_gauge -= COTTON_THROW_COST
		triggered["cotton_throw"] = true
	if (
		boss_special_gauge >= COTTON_BOMB_COST
		and cotton_bombs.is_empty()
		and cotton_bomb_windup <= 0.0
		and cotton_bomb_cooldown <= 0.0
		and cotton_throw_projectiles.is_empty()
		and cotton_throw_windup <= 0.0
		and rng.randf() <= COTTON_BOMB_CHANCE
	):
		_activate_cotton_bomb(deps)
		boss_special_gauge -= COTTON_BOMB_COST
		triggered["cotton_bomb"] = true
	if (
		boss_special_gauge >= DEADLY_HUG_COST
		and deadly_hug_timer <= 0.0
		and not deadly_hug_rush_active
		and deadly_hug_cooldown <= 0.0
		and cotton_throw_projectiles.is_empty()
		and rng.randf() <= DEADLY_HUG_CHANCE
	):
		_activate_deadly_hug(context, deps)
		boss_special_gauge -= DEADLY_HUG_COST
		triggered["deadly_hug"] = true
	if (
		boss_special_gauge >= HEART_BEAM_COST
		and heart_projectile.is_empty()
		and heart_knockback_timer <= 0.0
		and heart_beam_cooldown <= 0.0
		and deadly_hug_timer <= 0.0
		and rng.randf() <= HEART_BEAM_CHANCE
	):
		_activate_heart_beam(context, deps)
		boss_special_gauge -= HEART_BEAM_COST
		triggered["heart_beam"] = true
	status = _resolve_status()
	return {
		"stage3_boss_gauge": boss_special_gauge,
		"stage3_boss_gauge_gain": GAUGE_GAIN_ON_HIT,
		"teddy_cotton_throw_triggered": triggered["cotton_throw"],
		"teddy_cotton_bomb_triggered": triggered["cotton_bomb"],
		"teddy_deadly_hug_triggered": triggered["deadly_hug"],
		"teddy_heart_beam_triggered": triggered["heart_beam"],
	}


func handle_score_event(_scoring_side: String, _score_result: Dictionary, _deps: Dictionary = {}) -> void:
	pass


func _activate_cotton_throw(deps: Dictionary) -> void:
	cotton_throw_windup = COTTON_THROW_WINDUP_SEC
	cotton_throw_cooldown = COTTON_THROW_COOLDOWN_SEC
	_play_audio(deps, "play_stage3_dollcurse")


func _launch_cotton_throw(context: Dictionary) -> void:
	cotton_throw_projectiles.clear()
	var boss_pos := _get_boss_bottom_center(context)
	var target := _get_player_center(context)
	var base_angle := boss_pos.angle_to_point(target)
	for _index in range(rng.randi_range(COTTON_THROW_COUNT_MIN, COTTON_THROW_COUNT_MAX)):
		var angle := base_angle + deg_to_rad(rng.randf_range(-25.0, 25.0))
		var speed := COTTON_THROW_SPEED + rng.randf_range(-0.5, 0.5)
		cotton_throw_projectiles.append({
			"pos": boss_pos + Vector2(rng.randf_range(-15.0, 15.0), 0.0),
			"vel": Vector2.from_angle(angle) * speed,
			"remaining": COTTON_THROW_LIFETIME_SEC,
			"wobble": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(18.0, 28.0),
		})


func _update_cotton_throw(step: float, context: Dictionary, _deps: Dictionary) -> void:
	if cotton_throw_windup > 0.0:
		cotton_throw_windup = maxf(0.0, cotton_throw_windup - step)
		if cotton_throw_windup <= 0.0:
			_launch_cotton_throw(context)
		return
	var player_center := _get_player_center(context)
	var player_radius := _get_player_size(context).x * 0.5
	for idx in range(cotton_throw_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = cotton_throw_projectiles[idx]
		projectile["remaining"] = float(projectile.get("remaining", 0.0)) - step
		projectile["wobble"] = float(projectile.get("wobble", 0.0)) + 0.12 * step * LEGACY_FPS
		var pos := _as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel := _as_vector2(projectile.get("vel", Vector2.ZERO), Vector2.ZERO)
		pos += (vel + Vector2(sin(float(projectile["wobble"])) * 1.5, 0.0)) * step * LEGACY_FPS
		vel *= pow(0.998, step * LEGACY_FPS)
		projectile["pos"] = pos
		projectile["vel"] = vel
		if float(projectile["remaining"]) <= 0.0 or pos.x < -30.0 or pos.x > WIDTH + 30.0 or pos.y < -30.0 or pos.y > HEIGHT + 30.0:
			cotton_throw_projectiles.remove_at(idx)
		elif blackout_timer <= 0.0 and pos.distance_to(player_center) < COTTON_THROW_HIT_RADIUS + player_radius:
			cotton_throw_projectiles.remove_at(idx)
			blackout_timer = COTTON_BLACKOUT_DURATION_SEC
		else:
			cotton_throw_projectiles[idx] = projectile


func _activate_cotton_bomb(deps: Dictionary) -> void:
	cotton_bomb_windup = COTTON_BOMB_WINDUP_SEC
	cotton_bomb_cooldown = COTTON_BOMB_COOLDOWN_SEC
	_play_audio(deps, "play_stage3_chest_land")


func _launch_cotton_bombs() -> void:
	for _index in range(rng.randi_range(COTTON_BOMB_COUNT_MIN, COTTON_BOMB_COUNT_MAX)):
		cotton_bombs.append({
			"pos": Vector2(rng.randf_range(40.0, WIDTH - 40.0), rng.randf_range(200.0, 650.0)),
			"remaining": COTTON_BOMB_LIFETIME_SEC,
			"wobble": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(20.0, 30.0),
			"pulse": 0.0,
		})


func _update_cotton_bombs(
	step: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary
) -> void:
	_update_ghost_curve(step, context, result)
	if cotton_bomb_windup > 0.0:
		cotton_bomb_windup = maxf(0.0, cotton_bomb_windup - step)
		if cotton_bomb_windup <= 0.0:
			_launch_cotton_bombs()
		return
	var ball_pos := _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_radius := float(context.get("ball_size", 28.6)) * 0.5
	var player_center := _get_player_center(context)
	var player_radius := _get_player_size(context).x * 0.5
	for idx in range(cotton_fragments.size() - 1, -1, -1):
		var fragment: Dictionary = cotton_fragments[idx]
		fragment["remaining"] = float(fragment.get("remaining", 0.0)) - step
		fragment["wobble"] = float(fragment.get("wobble", 0.0)) + 0.15 * step * LEGACY_FPS
		var fragment_pos := _as_vector2(fragment.get("pos", Vector2.ZERO), Vector2.ZERO)
		var fragment_vel := _as_vector2(fragment.get("vel", Vector2.ZERO), Vector2.ZERO)
		fragment_pos += fragment_vel * step * LEGACY_FPS
		fragment_vel *= pow(0.97, step * LEGACY_FPS)
		fragment["pos"] = fragment_pos
		fragment["vel"] = fragment_vel
		var fragment_size := float(fragment.get("size", 10.0))
		if float(fragment["remaining"]) <= 0.0:
			cotton_fragments.remove_at(idx)
		elif bool(context.get("ball_active", false)) and fragment_pos.distance_to(ball_pos) < fragment_size + ball_radius:
			result["ball_vel"] = _activate_ghost_curve(_as_vector2(result.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO))
			cotton_fragments.remove_at(idx)
		elif fragment_pos.distance_to(player_center) < fragment_size + player_radius:
			cotton_slow_timer = COTTON_BOMB_PLAYER_SLOW_SEC
			_apply_cotton_slow(deps)
			cotton_fragments.remove_at(idx)
		else:
			cotton_fragments[idx] = fragment
	for idx in range(cotton_bombs.size() - 1, -1, -1):
		var bomb: Dictionary = cotton_bombs[idx]
		bomb["remaining"] = float(bomb.get("remaining", 0.0)) - step
		bomb["wobble"] = float(bomb.get("wobble", 0.0)) + 0.08 * step * LEGACY_FPS
		bomb["pulse"] = float(bomb.get("pulse", 0.0)) + 0.05 * step * LEGACY_FPS
		var bomb_pos := _as_vector2(bomb.get("pos", Vector2.ZERO), Vector2.ZERO)
		if float(bomb["remaining"]) <= 0.0:
			cotton_bombs.remove_at(idx)
		elif bool(context.get("ball_active", false)) and bomb_pos.distance_to(ball_pos) < COTTON_BOMB_HIT_RADIUS + ball_radius:
			result["ball_vel"] = _activate_ghost_curve(_as_vector2(result.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO))
			if bool(context.get("enraged_boss_active", false)):
				_explode_cotton_bomb(bomb, deps)
			cotton_bombs.remove_at(idx)
		elif bomb_pos.distance_to(player_center) < COTTON_BOMB_HIT_RADIUS + player_radius:
			cotton_slow_timer = COTTON_BOMB_PLAYER_SLOW_SEC
			_apply_cotton_slow(deps)
			if bool(context.get("enraged_boss_active", false)):
				_explode_cotton_bomb(bomb, deps)
			cotton_bombs.remove_at(idx)
		else:
			cotton_bombs[idx] = bomb


func _explode_cotton_bomb(bomb: Dictionary, deps: Dictionary) -> void:
	var pos := _as_vector2(bomb.get("pos", Vector2.ZERO), Vector2.ZERO)
	for _index in range(COTTON_BOMB_FRAGMENT_COUNT):
		var angle := rng.randf_range(0.0, TAU)
		var speed := COTTON_BOMB_FRAGMENT_SPEED + rng.randf_range(-0.5, 0.5)
		cotton_fragments.append({
			"pos": pos,
			"vel": Vector2.from_angle(angle) * speed,
			"remaining": COTTON_BOMB_FRAGMENT_LIFETIME_SEC,
			"size": rng.randf_range(8.0, 14.0),
			"wobble": rng.randf_range(0.0, TAU),
		})
	_play_audio(deps, "play_stage3_curse_explode")


func _activate_ghost_curve(ball_vel: Vector2) -> Vector2:
	ghost_curve_timer = GHOST_CURVE_DURATION_SEC
	ghost_curve_phase = rng.randf_range(0.0, TAU)
	ghost_curve_seed = rng.randf_range(0.8, 1.5)
	ghost_trail.clear()
	var speed := ball_vel.length()
	if speed <= 0.5:
		return ball_vel
	var kick := rng.randf_range(0.4, 0.7) * (-1.0 if rng.randi_range(0, 1) == 0 else 1.0)
	return ball_vel.rotated(kick)


func _update_ghost_curve(step: float, context: Dictionary, result: Dictionary) -> void:
	if ghost_curve_timer <= 0.0:
		return
	ghost_curve_timer = maxf(0.0, ghost_curve_timer - step)
	if ghost_curve_timer <= 0.0:
		return
	var velocity := _as_vector2(result.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
	var speed := velocity.length()
	if speed > 0.5:
		ghost_curve_phase += (0.12 + ghost_curve_seed * 0.06) * step * LEGACY_FPS
		var wave1 := sin(ghost_curve_phase * 0.4 * ghost_curve_seed) * 2.2
		var wave2 := sin(ghost_curve_phase * 1.1 + ghost_curve_seed * 3.0) * 0.8
		var ratio := ghost_curve_timer / GHOST_CURVE_DURATION_SEC
		var perpendicular := Vector2(-velocity.y, velocity.x).normalized()
		velocity += perpendicular * (wave1 + wave2) * sin(ratio * PI) * 0.2 * step * LEGACY_FPS
		velocity = velocity.normalized() * speed
		result["ball_vel"] = velocity
	var ball_pos := _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	ghost_trail.append({"pos": ball_pos, "life": 1.0, "size": float(context.get("ball_size", 28.6)) * 0.5})
	if ghost_trail.size() > 18:
		ghost_trail.pop_front()


func _apply_cotton_slow(deps: Dictionary) -> void:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status("player", "slow", 2.0, {
			"multiplier": COTTON_BOMB_SLOW_MULTIPLIER,
			"cleansable": false,
		}, "teddy_cotton_bomb")


func _activate_deadly_hug(context: Dictionary, deps: Dictionary) -> void:
	deadly_hug_rush_active = true
	deadly_hug_rush_y = _get_boss_bottom_center(context).y
	deadly_hug_timer = 0.0
	deadly_hug_cooldown = DEADLY_HUG_COOLDOWN_SEC
	_play_audio(deps, "play_lingpet_puppet_grab_pull")


func _update_deadly_hug(step: float, _context: Dictionary, deps: Dictionary) -> void:
	if deadly_hug_rush_active:
		deadly_hug_rush_y += DEADLY_HUG_RUSH_SPEED * step * LEGACY_FPS
		if deadly_hug_rush_y >= DEADLY_HUG_ZONE_Y:
			deadly_hug_rush_y = DEADLY_HUG_ZONE_Y
			deadly_hug_rush_active = false
			deadly_hug_timer = DEADLY_HUG_DURATION_SEC
			_play_audio(deps, "play_bomb_surprise_attach")
		return
	deadly_hug_timer = maxf(0.0, deadly_hug_timer - step)


func is_deadly_hug_dash_blocked() -> bool:
	if deadly_hug_timer <= 0.0:
		return false
	var center := latest_player_pos + latest_player_size * 0.5
	var zone_left := (WIDTH - DEADLY_HUG_ZONE_WIDTH) * 0.5
	return center.x >= zone_left and center.x <= zone_left + DEADLY_HUG_ZONE_WIDTH and center.y >= DEADLY_HUG_ZONE_Y - 30.0 and center.y <= HEIGHT


func _activate_heart_beam(context: Dictionary, deps: Dictionary) -> void:
	var start := _get_boss_bottom_center(context) + Vector2(0.0, 5.0)
	var direction := start.direction_to(_get_player_center(context))
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	heart_projectile = {
		"pos": start,
		"vel": direction * HEART_BEAM_SPEED,
		"size": HEART_BEAM_SIZE,
	}
	heart_trail.clear()
	heart_beam_cooldown = HEART_BEAM_COOLDOWN_SEC
	_play_audio(deps, "play_lingpet_puppet_grab_kiss")


func _update_heart_beam(
	step: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary
) -> void:
	_update_heart_knockback(step, context, deps, result)
	if heart_projectile.is_empty():
		return
	var pos := _as_vector2(heart_projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	heart_trail.append({"pos": pos, "life": 1.0})
	var velocity := _as_vector2(heart_projectile.get("vel", Vector2.ZERO), Vector2.ZERO)
	pos += velocity * step * LEGACY_FPS
	heart_projectile["pos"] = pos
	if pos.x < -40.0 or pos.x > WIDTH + 40.0 or pos.y < -40.0 or pos.y > HEIGHT + 40.0:
		heart_projectile.clear()
		return
	if heart_knockback_timer <= 0.0 and pos.distance_to(_get_player_center(context)) < HEART_BEAM_HIT_RADIUS + _get_player_size(context).x * 0.5:
		heart_projectile.clear()
		heart_trail.clear()
		_start_heart_knockback()


func _start_heart_knockback() -> void:
	heart_knockback_timer = HEART_KNOCKBACK_DURATION_SEC
	heart_knockback_schedule.clear()
	var direction := -1 if rng.randi_range(0, 1) == 0 else 1
	for index in range(3):
		heart_knockback_schedule.append({
			"frame": index * 24,
			"direction": direction,
			"strength": rng.randi_range(60, 85),
			"applied": false,
		})
		direction *= -1


func _update_heart_knockback(
	step: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary
) -> void:
	if heart_knockback_timer <= 0.0:
		return
	var elapsed_frames := int(round((HEART_KNOCKBACK_DURATION_SEC - heart_knockback_timer) * LEGACY_FPS))
	for index in range(heart_knockback_schedule.size()):
		var knockback: Dictionary = heart_knockback_schedule[index]
		if bool(knockback.get("applied", false)) or elapsed_frames < int(knockback.get("frame", 0)):
			continue
		knockback["applied"] = true
		heart_knockback_schedule[index] = knockback
		if (
			PlayerKnockbackImmunity.is_cleanse_immune(deps, context)
			or PlayerKnockbackImmunity.try_block_player_knockback(deps, context, "teddy_heart_beam")
		):
			continue
		var player_pos := _as_vector2(result.get("player_pos", context.get("player_pos", Vector2.ZERO)), Vector2.ZERO)
		var player_width := _get_player_size(context).x
		player_pos.x = clampf(
			player_pos.x + float(knockback.get("direction", 1)) * float(knockback.get("strength", 60)),
			0.0,
			WIDTH - player_width
		)
		result["player_pos"] = player_pos
		latest_player_pos = player_pos
		_spawn_heart_particles(player_pos + _get_player_size(context) * Vector2(0.5, 0.4), int(knockback.get("direction", 1)))
		var feedback: Object = deps.get("feedback", null)
		if feedback != null and feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.1, 5.0)
		_play_audio(deps, "play_stage3_tail")
	heart_knockback_timer = maxf(0.0, heart_knockback_timer - step)
	if heart_knockback_timer <= 0.0:
		heart_knockback_schedule.clear()


func _spawn_heart_particles(pos: Vector2, direction: int) -> void:
	for _index in range(rng.randi_range(6, 10)):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(2.0, 5.5)
		heart_particles.append({
			"pos": pos,
			"vel": Vector2.from_angle(angle) * speed + Vector2(direction * 2.0, -rng.randf_range(1.0, 3.0)),
			"life": 1.0,
			"size": rng.randf_range(3.0, 6.0),
		})


func _update_visual_particles(step: float) -> void:
	for idx in range(ghost_trail.size() - 1, -1, -1):
		var trail: Dictionary = ghost_trail[idx]
		trail["life"] = float(trail.get("life", 0.0)) - step * 3.6
		if float(trail["life"]) <= 0.0:
			ghost_trail.remove_at(idx)
		else:
			ghost_trail[idx] = trail
	for idx in range(heart_trail.size() - 1, -1, -1):
		var trail: Dictionary = heart_trail[idx]
		trail["life"] = float(trail.get("life", 0.0)) - step * 3.6
		if float(trail["life"]) <= 0.0:
			heart_trail.remove_at(idx)
		else:
			heart_trail[idx] = trail
	for idx in range(heart_particles.size() - 1, -1, -1):
		var particle: Dictionary = heart_particles[idx]
		var velocity := _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		velocity.y += 0.15 * step * LEGACY_FPS
		velocity.x *= pow(0.96, step * LEGACY_FPS)
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + velocity * step * LEGACY_FPS
		particle["vel"] = velocity
		particle["life"] = float(particle.get("life", 0.0)) - step * 2.4
		if float(particle["life"]) <= 0.0:
			heart_particles.remove_at(idx)
		else:
			heart_particles[idx] = particle


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	return {
		"stage3_boss_skill_hud_active": true,
		"stage3_boss_skill_hud_boss_name": "테디베어",
		"stage3_boss_skill_hud_status": status,
		"stage3_boss_skill_hud_boss_gauge": boss_special_gauge,
		"stage3_boss_skill_hud_boss_gauge_max": GAUGE_MAX,
		"stage3_boss_skill_hud_boss_gauge_progress": get_boss_gauge_progress(),
		"stage3_boss_skill_hud_show_boss_gauge": true,
		"stage3_boss_skill_hud_skills": [
			_build_skill("cotton_throw", "솜뭉치 투척", cotton_throw_windup > 0.0 or not cotton_throw_projectiles.is_empty(), cotton_throw_cooldown, COTTON_THROW_COOLDOWN_SEC, Color("fff0ed")),
			_build_skill("cotton_bomb", "솜뭉치 폭탄", cotton_bomb_windup > 0.0 or not cotton_bombs.is_empty(), cotton_bomb_cooldown, COTTON_BOMB_COOLDOWN_SEC, Color("ffc7dd")),
			_build_skill("deadly_hug", "죽음의 포옹", deadly_hug_rush_active or deadly_hug_timer > 0.0, deadly_hug_cooldown, DEADLY_HUG_COOLDOWN_SEC, Color("a86f54")),
			_build_skill("heart_beam", "하트 빔", not heart_projectile.is_empty() or heart_knockback_timer > 0.0, heart_beam_cooldown, HEART_BEAM_COOLDOWN_SEC, Color("ff609c")),
		],
	}


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage_boss_variant": VARIANT_ID,
		"stage3_teddy_hit_ratio": hit_timer / 0.35,
		"stage3_teddy_cotton_throw_windup_ratio": cotton_throw_windup / COTTON_THROW_WINDUP_SEC,
		"stage3_teddy_cotton_projectiles": _draw_array(cotton_throw_projectiles, copy_arrays),
		"stage3_teddy_blackout_ratio": _get_blackout_ratio(),
		"stage3_teddy_cotton_bomb_windup_ratio": cotton_bomb_windup / COTTON_BOMB_WINDUP_SEC,
		"stage3_teddy_cotton_bombs": _draw_array(cotton_bombs, copy_arrays),
		"stage3_teddy_cotton_fragments": _draw_array(cotton_fragments, copy_arrays),
		"stage3_teddy_cotton_slow_ratio": cotton_slow_timer / COTTON_BOMB_PLAYER_SLOW_SEC,
		"stage3_teddy_ghost_curve_ratio": ghost_curve_timer / GHOST_CURVE_DURATION_SEC,
		"stage3_teddy_ghost_trail": _draw_array(ghost_trail, copy_arrays),
		"stage3_teddy_hug_rush_active": deadly_hug_rush_active,
		"stage3_teddy_hug_rush_y": deadly_hug_rush_y,
		"stage3_teddy_hug_ratio": deadly_hug_timer / DEADLY_HUG_DURATION_SEC,
		"stage3_teddy_heart_projectile": heart_projectile.duplicate(true) if copy_arrays else heart_projectile,
		"stage3_teddy_heart_trail": _draw_array(heart_trail, copy_arrays),
		"stage3_teddy_heart_particles": _draw_array(heart_particles, copy_arrays),
	}


func get_boss_gauge_progress() -> float:
	return clampf(boss_special_gauge / GAUGE_MAX, 0.0, 1.0)


func get_snapshot() -> Dictionary:
	var snapshot := get_actor_draw_context(true)
	snapshot.merge({
		"status": status,
		"boss_special_gauge": boss_special_gauge,
		"cotton_throw_cooldown": cotton_throw_cooldown,
		"cotton_bomb_cooldown": cotton_bomb_cooldown,
		"deadly_hug_cooldown": deadly_hug_cooldown,
		"heart_beam_cooldown": heart_beam_cooldown,
		"deadly_hug_dash_blocked": is_deadly_hug_dash_blocked(),
	}, true)
	return snapshot


func _get_blackout_ratio() -> float:
	if blackout_timer <= 0.0:
		return 0.0
	var elapsed := COTTON_BLACKOUT_DURATION_SEC - blackout_timer
	if elapsed < COTTON_BLACKOUT_FULL_SEC:
		return clampf(elapsed / (5.0 / LEGACY_FPS), 0.0, 1.0)
	return clampf(blackout_timer / (COTTON_BLACKOUT_DURATION_SEC - COTTON_BLACKOUT_FULL_SEC), 0.0, 1.0)


func _build_skill(id: String, label: String, active: bool, cooldown: float, total: float, color: Color) -> Dictionary:
	var skill_status := "casting" if active else ("ready" if cooldown <= 0.0 else "charging")
	return {
		"id": id,
		"label": label,
		"status": skill_status,
		"cooldown_remaining": cooldown,
		"cooldown_total": total,
		"progress": 1.0 if active else clampf(1.0 - cooldown / maxf(total, 0.001), 0.0, 1.0),
		"ready": skill_status == "ready",
		"trigger_type": "boss_hit",
		"color": color,
	}


func _resolve_status() -> String:
	if deadly_hug_rush_active or deadly_hug_timer > 0.0:
		return "deadly_hug"
	if heart_knockback_timer > 0.0 or not heart_projectile.is_empty():
		return "heart_beam"
	if cotton_throw_windup > 0.0 or not cotton_throw_projectiles.is_empty() or blackout_timer > 0.0:
		return "cotton_throw"
	if cotton_bomb_windup > 0.0 or not cotton_bombs.is_empty() or not cotton_fragments.is_empty() or ghost_curve_timer > 0.0:
		return "cotton_bomb"
	return "charging"


func _is_cooldown_paused(context: Dictionary) -> bool:
	return bool(context.get(
		"active_item_boss_skill_cooldown_paused",
		context.get("active_item_tear_gas_cooldown_pause_active", false)
	))


func _get_boss_bottom_center(context: Dictionary) -> Vector2:
	var pos := _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	return pos + Vector2(float(context.get("boss_paddle_width", 100.0)) * 0.5, float(context.get("boss_hitbox_height", 40.0)))


func _get_player_center(context: Dictionary) -> Vector2:
	var pos := _as_vector2(context.get("player_pos", latest_player_pos), latest_player_pos)
	return pos + _get_player_size(context) * 0.5


func _get_player_size(context: Dictionary) -> Vector2:
	return _as_vector2(context.get("player_paddle_size", latest_player_size), latest_player_size)


func _draw_array(source: Array, copy_arrays: bool) -> Array:
	return source.duplicate(true) if copy_arrays else source


func _play_audio(deps: Dictionary, method: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method):
		audio.call(method)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
