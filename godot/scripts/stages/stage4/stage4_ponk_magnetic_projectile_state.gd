extends RefCounted

const FIELD_HEIGHT := 750.0
const PROJECTILE_SPEED := 12.0
const PROJECTILE_HOMING_X_SPEED := 3.2
const PROJECTILE_ENRAGED_HOMING_X_SPEED := 6.0
const PROJECTILE_SLOW_FRAMES := 10.0
const PROJECTILE_SLOW_MULTIPLIER := 0.5
const PROJECTILE_CONTACT_Y_SPEED_MULTIPLIER := 0.5
const PROJECTILE_FADE_SECONDS := 0.15
const DEFAULT_RADIUS := 160.0

# Mutable gameplay owner for Ponk's post-magnetic projectile. The ball-
# interaction coordinator owns contact status/audio side effects; node-backed
# FX lifecycle and frame orchestration remain outside this state owner.

var active := false
var pos := Vector2.ZERO
var radius := DEFAULT_RADIUS
var elapsed_seconds := 0.0
var velocity := Vector2(0.0, PROJECTILE_SPEED)
var y_speed_multiplier := 1.0
var fade_timer_seconds := 0.0
var fade_pos := Vector2.ZERO
var fade_radius := DEFAULT_RADIUS
var fade_velocity := Vector2(0.0, PROJECTILE_SPEED)


func reset() -> void:
	active = false
	pos = Vector2.ZERO
	radius = DEFAULT_RADIUS
	elapsed_seconds = 0.0
	velocity = Vector2(0.0, PROJECTILE_SPEED)
	y_speed_multiplier = 1.0
	fade_timer_seconds = 0.0
	fade_pos = Vector2.ZERO
	fade_radius = DEFAULT_RADIUS
	fade_velocity = Vector2(0.0, PROJECTILE_SPEED)


func reset_round() -> void:
	active = false
	elapsed_seconds = 0.0
	velocity = Vector2(0.0, PROJECTILE_SPEED)
	y_speed_multiplier = 1.0
	fade_timer_seconds = 0.0


func clear_stage_transients() -> void:
	active = false
	y_speed_multiplier = 1.0
	fade_timer_seconds = 0.0


func has_audio_runtime() -> bool:
	return active or fade_timer_seconds > 0.0


func spawn(spawn_pos: Vector2, spawn_radius: float) -> bool:
	active = true
	pos = spawn_pos
	radius = maxf(12.0, spawn_radius)
	elapsed_seconds = 0.0
	velocity = Vector2(0.0, PROJECTILE_SPEED)
	y_speed_multiplier = 1.0
	fade_timer_seconds = 0.0
	return true


func update(fps_scale: float, player_center: Vector2, playfield_height: float, enraged: bool) -> void:
	if not active:
		if fade_timer_seconds > 0.0:
			fade_timer_seconds = maxf(
				0.0,
				fade_timer_seconds - maxf(0.0, fps_scale) / 60.0
			)
		return
	var step: float = maxf(0.0, fps_scale)
	elapsed_seconds += step / 60.0
	var previous_pos := pos
	var homing_speed: float = PROJECTILE_ENRAGED_HOMING_X_SPEED if enraged else PROJECTILE_HOMING_X_SPEED
	if homing_speed > 0.0:
		var dx: float = player_center.x - pos.x
		pos.x += clampf(dx, -homing_speed * step, homing_speed * step)
	pos.y += PROJECTILE_SPEED * maxf(0.0, y_speed_multiplier) * step
	var next_velocity: Vector2 = pos - previous_pos
	if next_velocity.length_squared() > 0.001:
		velocity = next_velocity
	var height: float = maxf(FIELD_HEIGHT, playfield_height)
	if pos.y > height + radius:
		finish_visual()


func overlaps_player(player_rect: Rect2) -> bool:
	if not active or player_rect.size.x <= 0.0 or player_rect.size.y <= 0.0:
		return false
	var closest := Vector2(
		clampf(pos.x, player_rect.position.x, player_rect.position.x + player_rect.size.x),
		clampf(pos.y, player_rect.position.y, player_rect.position.y + player_rect.size.y)
	)
	var collision_radius: float = radius * 0.68
	return closest.distance_squared_to(pos) <= collision_radius * collision_radius


func apply_player_contact() -> float:
	y_speed_multiplier = minf(y_speed_multiplier, PROJECTILE_CONTACT_Y_SPEED_MULTIPLIER)
	return y_speed_multiplier


func finish_visual() -> void:
	fade_pos = pos
	fade_radius = radius
	fade_velocity = velocity
	fade_timer_seconds = PROJECTILE_FADE_SECONDS
	active = false


func get_actor_draw_context() -> Dictionary:
	return {
		"stage4_magnetic_projectile_active": active,
		"stage4_magnetic_projectile_pos": pos,
		"stage4_magnetic_projectile_radius": radius,
		"stage4_magnetic_projectile_elapsed": elapsed_seconds,
		"stage4_magnetic_projectile_velocity": velocity,
		"stage4_magnetic_projectile_y_speed_multiplier": y_speed_multiplier,
		"stage4_magnetic_projectile_fade_active": fade_timer_seconds > 0.0,
		"stage4_magnetic_projectile_fade_timer": fade_timer_seconds,
		"stage4_magnetic_projectile_fade_total": PROJECTILE_FADE_SECONDS,
		"stage4_magnetic_projectile_fade_pos": fade_pos,
		"stage4_magnetic_projectile_fade_radius": fade_radius,
		"stage4_magnetic_projectile_fade_velocity": fade_velocity,
	}


func get_snapshot() -> Dictionary:
	return {
		"magnetic_projectile_active": active,
		"magnetic_projectile_pos": pos,
		"magnetic_projectile_radius": radius,
		"magnetic_projectile_elapsed_seconds": elapsed_seconds,
		"magnetic_projectile_velocity": velocity,
		"magnetic_projectile_y_speed_multiplier": y_speed_multiplier,
		"magnetic_projectile_fade_timer_seconds": fade_timer_seconds,
		"magnetic_projectile_fade_pos": fade_pos,
		"magnetic_projectile_fade_radius": fade_radius,
		"magnetic_projectile_fade_velocity": fade_velocity,
	}
