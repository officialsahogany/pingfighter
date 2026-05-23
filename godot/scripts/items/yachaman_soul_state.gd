extends RefCounted

const STATE_IDLE := "idle"
const STATE_REVIVAL_EVENT := "revival_event"
const STATE_TRANSFORMED := "transformed"

const MOVE_SPEED := 3.0
const PADDLE_SIZE_MULT := 0.70
const GATHER_FRAMES := 60.0
const BURST_FRAMES := 30.0
const TOTAL_FRAMES := GATHER_FRAMES + BURST_FRAMES
const BOMB_SPIN_WINDUP := 8.0
const BOMB_SPIN_SPIN1 := 20.0
const BOMB_SPIN_SPIN2 := 20.0
const BOMB_SPIN_RECOVERY := 10.0
const BOMB_SPIN_COOLDOWN := 90.0
const BOMB_SPIN_SPIN1_SPEED := 6.0
const BOMB_SPIN_DASH_SPEED := 22.0
const BOMB_SPIN_HELMET_R := 14.0
const HELMET_RETURN_FRAMES := 30.0
const BOMB_EXPLOSION_FRAMES := 30.0
const BOMB_STUN_DURATION := 60.0
const BOMB_KNOCKBACK_POWER := 15.0

var equipped := false
var state := STATE_IDLE
var used_this_round := false
var animation_timer_frames := 0.0
var pending_round_reset := false
var reset_ready := false
var revival_anchor := Vector2.ZERO
var last_loss_type := ""
var last_trigger_roll_pct := -1.0
var last_triggered := false
var bomb_spin_active := false
var bomb_spin_timer := 0.0
var bomb_spin_phase := 0
var bomb_spin_direction := 0
var bomb_spin_angle := 0.0
var bomb_spin_cooldown := 0.0
var bomb_spin_helmet_pos := Vector2.ZERO
var helmet_removed := false
var helmet_returning := false
var helmet_return_timer := 0.0
var helmet_return_pos := Vector2.ZERO
var helmet_return_start := Vector2.ZERO
var bomb_loaded_on_ball := false
var bomb_explosion_active := false
var bomb_explosion_timer := 0.0
var bomb_explosion_pos := Vector2.ZERO
var bomb_explosion_particles: Array = []


func set_equipped(is_equipped: bool) -> void:
	equipped = is_equipped
	if not equipped:
		clear_runtime(false)


func can_try_revival() -> bool:
	return equipped and state == STATE_IDLE and not used_this_round


func try_begin_revival(
	chance_pct: float,
	loss_type: String,
	anchor: Vector2,
	roll_pct: float
) -> bool:
	last_trigger_roll_pct = roll_pct
	last_triggered = false
	if not can_try_revival():
		return false
	if chance_pct <= 0.0 or roll_pct > chance_pct:
		return false
	used_this_round = true
	state = STATE_REVIVAL_EVENT
	animation_timer_frames = 0.0
	pending_round_reset = true
	reset_ready = false
	revival_anchor = anchor
	last_loss_type = loss_type
	last_triggered = true
	return true


func on_defeat_in_yachaman() -> bool:
	if state != STATE_TRANSFORMED:
		return false
	state = STATE_IDLE
	animation_timer_frames = 0.0
	pending_round_reset = false
	reset_ready = false
	reset_bomb_spin()
	return true


func update(fps_scale: float) -> bool:
	var previous_state: String = state
	if state == STATE_REVIVAL_EVENT:
		animation_timer_frames = min(TOTAL_FRAMES, animation_timer_frames + max(0.0, fps_scale))
		if animation_timer_frames >= TOTAL_FRAMES:
			state = STATE_TRANSFORMED
			reset_ready = true
	return previous_state != state


func consume_reset_ready() -> bool:
	if not pending_round_reset or not reset_ready:
		return false
	pending_round_reset = false
	reset_ready = false
	return true


func reset_round() -> void:
	# Yachaman is a round-scoped revival form. A real round boundary clears both
	# the once-this-round flag and any transformed body, unlike Horn Strawberry's
	# stage-scoped timed command transform.
	clear_runtime(false)


func clear_runtime(preserve_used_round: bool = false) -> void:
	var previous_used := used_this_round
	state = STATE_IDLE
	animation_timer_frames = 0.0
	pending_round_reset = false
	reset_ready = false
	revival_anchor = Vector2.ZERO
	last_loss_type = ""
	last_trigger_roll_pct = -1.0
	last_triggered = false
	used_this_round = previous_used if preserve_used_round else false
	reset_bomb_spin()


func is_event_playing() -> bool:
	return equipped and state == STATE_REVIVAL_EVENT


func is_transformed() -> bool:
	return equipped and state == STATE_TRANSFORMED


func is_skills_locked() -> bool:
	return is_event_playing() or is_transformed()


func is_control_locked() -> bool:
	return is_event_playing()


func has_runtime_update_work() -> bool:
	return (
		is_event_playing()
		or is_transformed()
		or bomb_spin_active
		or bomb_spin_cooldown > 0.0
		or helmet_returning
		or bomb_loaded_on_ball
		or bomb_explosion_active
	)


func try_bomb_spin(direction: int) -> bool:
	if not is_transformed():
		return false
	if bomb_spin_active or bomb_spin_cooldown > 0.0 or helmet_returning:
		return false
	if direction == 0:
		return false
	bomb_spin_active = true
	bomb_spin_timer = 0.0
	bomb_spin_phase = 0
	bomb_spin_direction = clampi(direction, -1, 1)
	bomb_spin_angle = 0.0
	helmet_removed = true
	return true


func update_bomb_spin(player_center: Vector2, fps_scale: float) -> Dictionary:
	var step: float = max(0.0, fps_scale)
	if bomb_spin_cooldown > 0.0:
		bomb_spin_cooldown = max(0.0, bomb_spin_cooldown - step)
	if not bomb_spin_active:
		return {"dx": 0.0, "helmet_pos": null, "helmet_radius": BOMB_SPIN_HELMET_R, "done": false}

	bomb_spin_timer += step
	var dx := 0.0
	var spin_center_y := player_center.y - 15.0
	var t := bomb_spin_timer
	if t <= BOMB_SPIN_WINDUP:
		bomb_spin_phase = 0
		var progress: float = clampf(t / BOMB_SPIN_WINDUP, 0.0, 1.0)
		var start_y: float = player_center.y - 50.0
		bomb_spin_helmet_pos = Vector2(
			player_center.x + float(bomb_spin_direction) * progress * 30.0,
			lerpf(start_y, spin_center_y, progress)
		)
	elif t <= BOMB_SPIN_WINDUP + BOMB_SPIN_SPIN1:
		bomb_spin_phase = 1
		var spin_t: float = t - BOMB_SPIN_WINDUP
		var progress: float = clampf(spin_t / BOMB_SPIN_SPIN1, 0.0, 1.0)
		bomb_spin_angle = progress * TAU
		dx = float(bomb_spin_direction) * BOMB_SPIN_SPIN1_SPEED * min(1.0, progress * 2.0)
		bomb_spin_helmet_pos = Vector2(
			player_center.x + sin(bomb_spin_angle) * 35.0,
			spin_center_y - cos(bomb_spin_angle) * 20.0
		)
	elif t <= BOMB_SPIN_WINDUP + BOMB_SPIN_SPIN1 + BOMB_SPIN_SPIN2:
		bomb_spin_phase = 2
		var spin_t: float = t - BOMB_SPIN_WINDUP - BOMB_SPIN_SPIN1
		var progress: float = clampf(spin_t / BOMB_SPIN_SPIN2, 0.0, 1.0)
		bomb_spin_angle = progress * TAU
		dx = float(bomb_spin_direction) * BOMB_SPIN_DASH_SPEED * (1.0 - progress * 0.4)
		bomb_spin_helmet_pos = Vector2(
			player_center.x + float(bomb_spin_direction) * 22.0 + sin(bomb_spin_angle) * 40.0,
			spin_center_y - cos(bomb_spin_angle) * 22.0
		)
	else:
		bomb_spin_phase = 3
		var rec_t: float = t - BOMB_SPIN_WINDUP - BOMB_SPIN_SPIN1 - BOMB_SPIN_SPIN2
		if rec_t >= BOMB_SPIN_RECOVERY:
			bomb_spin_active = false
			bomb_spin_cooldown = BOMB_SPIN_COOLDOWN
			bomb_spin_phase = 0
			if not bomb_loaded_on_ball:
				helmet_removed = false
			return {"dx": 0.0, "helmet_pos": null, "helmet_radius": BOMB_SPIN_HELMET_R, "done": true}
		var progress: float = clampf(rec_t / BOMB_SPIN_RECOVERY, 0.0, 1.0)
		bomb_spin_helmet_pos = Vector2(
			player_center.x,
			lerpf(spin_center_y, player_center.y - 50.0, progress)
		)
	return {
		"dx": dx,
		"helmet_pos": bomb_spin_helmet_pos,
		"helmet_radius": BOMB_SPIN_HELMET_R,
		"done": false,
	}


func check_bomb_spin_ball_collision(ball_pos: Vector2, ball_vel: Vector2, ball_size: float) -> bool:
	if not bomb_spin_active or bomb_spin_phase < 0 or bomb_spin_phase > 2:
		return false
	if bomb_loaded_on_ball:
		return false
	var ball_radius: float = max(1.0, ball_size) * 0.5
	var collision_radius: float = BOMB_SPIN_HELMET_R + ball_radius + 8.0
	var min_dist: float = ball_pos.distance_to(bomb_spin_helmet_pos)
	var next_ball_pos: Vector2 = ball_pos + ball_vel
	var segment: Vector2 = next_ball_pos - ball_pos
	var segment_len_sq: float = segment.length_squared()
	if segment_len_sq > 0.0:
		var closest_t: float = clampf((bomb_spin_helmet_pos - ball_pos).dot(segment) / segment_len_sq, 0.0, 1.0)
		var closest: Vector2 = ball_pos + segment * closest_t
		min_dist = min(min_dist, next_ball_pos.distance_to(bomb_spin_helmet_pos), closest.distance_to(bomb_spin_helmet_pos))
	if min_dist > collision_radius:
		return false
	bomb_loaded_on_ball = true
	return true


func trigger_bomb_explosion(boss_center: Vector2) -> Dictionary:
	if not bomb_loaded_on_ball:
		return {}
	bomb_loaded_on_ball = false
	bomb_explosion_active = true
	bomb_explosion_timer = 0.0
	bomb_explosion_pos = boss_center
	helmet_returning = true
	helmet_return_timer = 0.0
	helmet_return_start = boss_center
	helmet_return_pos = boss_center
	_spawn_bomb_explosion_particles(boss_center)
	return {
		"stun_frames": BOMB_STUN_DURATION,
		"knockback": BOMB_KNOCKBACK_POWER,
	}


func update_lingering(player_center: Vector2, fps_scale: float) -> void:
	var step: float = max(0.0, fps_scale)
	if bomb_explosion_active:
		bomb_explosion_timer += step
		if bomb_explosion_timer >= BOMB_EXPLOSION_FRAMES:
			bomb_explosion_active = false
			bomb_explosion_particles.clear()
		else:
			_update_bomb_explosion_particles(step)
	if helmet_returning:
		helmet_return_timer += step
		var progress: float = clampf(helmet_return_timer / HELMET_RETURN_FRAMES, 0.0, 1.0)
		var eased: float = progress * progress * (3.0 - 2.0 * progress)
		var target := Vector2(player_center.x, player_center.y - 50.0)
		helmet_return_pos = helmet_return_start.lerp(target, eased)
		helmet_return_pos.y += -80.0 * (progress * (1.0 - progress) * 4.0)
		if helmet_return_timer >= HELMET_RETURN_FRAMES:
			helmet_returning = false
			helmet_removed = false


func reset_bomb_spin() -> void:
	bomb_spin_active = false
	bomb_spin_timer = 0.0
	bomb_spin_phase = 0
	bomb_spin_direction = 0
	bomb_spin_angle = 0.0
	bomb_spin_cooldown = 0.0
	bomb_spin_helmet_pos = Vector2.ZERO
	helmet_removed = false
	helmet_returning = false
	helmet_return_timer = 0.0
	helmet_return_pos = Vector2.ZERO
	helmet_return_start = Vector2.ZERO
	bomb_loaded_on_ball = false
	bomb_explosion_active = false
	bomb_explosion_timer = 0.0
	bomb_explosion_pos = Vector2.ZERO
	bomb_explosion_particles.clear()


func has_bomb_visible_effects() -> bool:
	return bomb_spin_active or helmet_returning or bomb_explosion_active


func has_ball_draw_context() -> bool:
	return bomb_loaded_on_ball


func get_animation_progress() -> float:
	if state != STATE_REVIVAL_EVENT:
		return 0.0
	return clampf(animation_timer_frames / TOTAL_FRAMES, 0.0, 1.0)


func get_context() -> Dictionary:
	return {
		"equipped": equipped,
		"active": equipped,
		"state": state,
		"transformed": is_transformed(),
		"event_playing": is_event_playing(),
		"skills_locked": is_skills_locked(),
		"control_locked": is_control_locked(),
		"used_this_round": used_this_round,
		"animation_timer_frames": animation_timer_frames,
		"animation_total_frames": TOTAL_FRAMES,
		"animation_progress": get_animation_progress(),
		"pending_round_reset": pending_round_reset,
		"reset_ready": reset_ready,
		"revival_anchor": revival_anchor,
		"move_speed": MOVE_SPEED,
		"paddle_size_mult": PADDLE_SIZE_MULT,
		"last_loss_type": last_loss_type,
		"last_trigger_roll_pct": last_trigger_roll_pct,
		"last_triggered": last_triggered,
		"bomb_spin_active": bomb_spin_active,
		"bomb_spin_timer": bomb_spin_timer,
		"bomb_spin_phase": bomb_spin_phase,
		"bomb_spin_direction": bomb_spin_direction,
		"bomb_spin_angle": bomb_spin_angle,
		"bomb_spin_cooldown": bomb_spin_cooldown,
		"bomb_spin_helmet_pos": bomb_spin_helmet_pos,
		"bomb_spin_helmet_radius": BOMB_SPIN_HELMET_R,
		"helmet_removed": helmet_removed,
		"helmet_returning": helmet_returning,
		"helmet_return_timer": helmet_return_timer,
		"helmet_return_pos": helmet_return_pos,
		"helmet_return_start": helmet_return_start,
		"helmet_return_total_frames": HELMET_RETURN_FRAMES,
		"bomb_loaded_on_ball": bomb_loaded_on_ball,
		"bomb_explosion_active": bomb_explosion_active,
		"bomb_explosion_timer": bomb_explosion_timer,
		"bomb_explosion_total_frames": BOMB_EXPLOSION_FRAMES,
		"bomb_explosion_pos": bomb_explosion_pos,
		"bomb_explosion_particles": bomb_explosion_particles.duplicate(true),
		"bomb_stun_frames": BOMB_STUN_DURATION,
		"bomb_knockback": BOMB_KNOCKBACK_POWER,
	}


func _spawn_bomb_explosion_particles(center: Vector2) -> void:
	bomb_explosion_particles.clear()
	for i in range(30):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(2.0, 10.0)
		var color: Color = [
			Color(1.0, 200.0 / 255.0, 50.0 / 255.0),
			Color(1.0, 140.0 / 255.0, 0.0),
			Color(1.0, 80.0 / 255.0, 0.0),
			Color(40.0 / 255.0, 40.0 / 255.0, 40.0 / 255.0),
			Color(60.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0),
		][i % 5]
		bomb_explosion_particles.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": float(randi_range(15, 30)),
			"max_life": 30.0,
			"size": float(randi_range(3, 7)),
			"color": color,
		})


func _update_bomb_explosion_particles(step: float) -> void:
	var next_particles: Array = []
	for value in bomb_explosion_particles:
		if not (value is Dictionary):
			continue
		var particle: Dictionary = value
		var pos: Vector2 = particle.get("pos", bomb_explosion_pos)
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		pos += vel * step
		vel.y += 0.3 * step
		vel *= pow(0.95, step)
		var life: float = float(particle.get("life", 0.0)) - step
		if life <= 0.0:
			continue
		particle["pos"] = pos
		particle["vel"] = vel
		particle["life"] = life
		next_particles.append(particle)
	bomb_explosion_particles = next_particles
