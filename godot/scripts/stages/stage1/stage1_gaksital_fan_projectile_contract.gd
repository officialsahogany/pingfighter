extends RefCounted

const BattleBossSpritePaths := preload(
	"res://scripts/resources/battle_boss_sprite_paths.gd"
)
const StarpointDropOverlapQuery := preload(
	"res://scripts/stages/common/starpoint_drop_overlap_query.gd"
)

const PROJECTILE_TEXTURE_PATH := BattleBossSpritePaths.GAKSITAL_FAN_PROJECTILE_PATH
const DURATION_FRAMES := 180.0
const SPEED := 5.5
const VX_JITTER := 0.8
const SPIN_PER_FRAME := 0.3
const HIT_RADIUS := 24.0
const DRAW_SIZE := 56.0
const EXTRA_DRAW_SIZE := 50.0
const MAIN_FAN_SOUND_VOLUME := 0.35
const EXTRA_FAN_SOUND_VOLUME := 0.25
const MAIN_HIT_SOUND_VOLUME := 0.6
const EXTRA_HIT_SOUND_VOLUME := 0.5
const STUN_FRAMES := 18.0
const KNOCKBACK_POWER := 12.0
const KNOCKBACK_FRAMES := 18.0
const KNOCKBACK_DECAY := 0.92


static func build_projectile(
	origin: Vector2,
	direction: Vector2,
	draw_size: float = DRAW_SIZE,
	tint: Color = Color.WHITE,
	fan_sound_volume: float = MAIN_FAN_SOUND_VOLUME,
	hit_sound_volume: float = MAIN_HIT_SOUND_VOLUME,
	jitter_x: float = 0.0
) -> Dictionary:
	var safe_direction := direction.normalized()
	if safe_direction.length_squared() <= 0.001:
		safe_direction = Vector2.UP
	var velocity := safe_direction * SPEED
	velocity.x += clampf(jitter_x, -VX_JITTER, VX_JITTER)
	return {
		"x": origin.x,
		"y": origin.y,
		"vx": velocity.x,
		"vy": velocity.y,
		"elapsed": 0.0,
		"timer": DURATION_FRAMES,
		"spin": 0.0,
		"draw_size": draw_size,
		"alpha": 1.0,
		"tint": tint,
		"fan_sound_volume": fan_sound_volume,
		"hit_sound_volume": hit_sound_volume,
	}


static func advance_projectile(projectile: Dictionary, fps_scale: float) -> Dictionary:
	var fan := projectile
	var safe_scale := maxf(0.0, fps_scale)
	var previous_spin := float(fan.get("spin", 0.0))
	var next_spin := previous_spin + SPIN_PER_FRAME * safe_scale
	var elapsed := float(fan.get("elapsed", 0.0)) + safe_scale
	var speed_mod := 0.6 + 0.5 * sin(elapsed * 0.25)
	var sway := sin(elapsed * 0.15) * 1.8
	var timer := maxf(0.0, float(fan.get("timer", DURATION_FRAMES)) - safe_scale)
	fan["timer"] = timer
	fan["elapsed"] = elapsed
	fan["spin"] = next_spin
	fan["x"] = float(fan.get("x", 0.0)) + (float(fan.get("vx", 0.0)) * speed_mod + sway) * safe_scale
	fan["y"] = float(fan.get("y", 0.0)) + float(fan.get("vy", 0.0)) * speed_mod * 1.3 * safe_scale
	return {
		"projectile": fan,
		"spin_boundary_crossed": int(floor(previous_spin / TAU)) < int(floor(next_spin / TAU)),
	}


static func get_position(projectile: Dictionary) -> Vector2:
	return Vector2(
		float(projectile.get("x", 0.0)),
		float(projectile.get("y", 0.0))
	)


static func is_expired_or_out_of_bounds(projectile: Dictionary, width: float, height: float) -> bool:
	if float(projectile.get("timer", 0.0)) <= 0.0:
		return true
	var pos := get_position(projectile)
	return pos.x < -40.0 or pos.x > width + 40.0 or pos.y < -40.0 or pos.y > height + 40.0


static func roll_knockback_velocity(rng: RandomNumberGenerator) -> float:
	var direction := -1.0
	if rng != null and rng.randf() >= 0.5:
		direction = 1.0
	return direction * KNOCKBACK_POWER


static func build_boss_stun_status_data(knockback_velocity: float, source: String) -> Dictionary:
	return {
		"source": source,
		"cleansable": true,
		"knockback_vel": knockback_velocity,
		"knockback_active": absf(knockback_velocity) > 0.001,
		"knockback_frames": KNOCKBACK_FRAMES,
		"knockback_decay_per_frame": KNOCKBACK_DECAY,
	}


static func play_fan_audio(deps: Dictionary, volume: float = MAIN_FAN_SOUND_VOLUME) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_gaksital_fan"):
		audio.play_gaksital_fan(volume)


static func play_hit_audio(deps: Dictionary, volume: float = MAIN_HIT_SOUND_VOLUME) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_whipcrack"):
		audio.play_whipcrack(volume)
