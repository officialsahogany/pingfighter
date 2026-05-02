extends RefCounted

const SPRITE_FRAME_COUNT := 6
const SPRITE_ANIMATION_SPEED := 0.10
const HIT_ANIM_DURATION := 0.35
const HIT_FRAME_COUNT := 6
const HIT_FRAME_SPEED := 0.05

var sprite_frame := 0
var sprite_timer := 0.0
var sprite_row := 1
var hit_active := false
var hit_timer := 0.0
var hit_frame := 0
var hit_frame_timer := 0.0
var hit_row := 1


func reset() -> void:
	sprite_frame = 0
	sprite_timer = 0.0
	sprite_row = 1
	hit_active = false
	hit_timer = 0.0
	hit_frame = 0
	hit_frame_timer = 0.0
	hit_row = 1


func update(delta: float, context: Dictionary) -> void:
	_update_sprite_animation(delta, context)
	_update_hit_animation(delta, context)


func trigger_hit(boss_vel: float, has_hit_texture: bool, hit_duration: float = HIT_ANIM_DURATION) -> void:
	if not has_hit_texture:
		return
	hit_active = true
	hit_timer = hit_duration
	hit_frame = 0
	hit_frame_timer = 0.0
	hit_row = 0 if boss_vel < 0.0 else 1


func get_draw_context() -> Dictionary:
	return {
		"boss_sprite_frame": sprite_frame,
		"boss_sprite_row": sprite_row,
		"boss_hit_active": hit_active,
		"boss_hit_frame": hit_frame,
		"boss_hit_row": hit_row,
	}


func _update_sprite_animation(delta: float, context: Dictionary) -> void:
	if not bool(context.get("boss_has_sprite", false)):
		return

	var boss_vel: float = float(context.get("boss_vel", 0.0))
	if abs(boss_vel) > 0.2:
		sprite_row = 0 if boss_vel < 0.0 else 1
		sprite_timer += delta
		var animation_speed: float = float(context.get("boss_sprite_animation_speed", SPRITE_ANIMATION_SPEED))
		if sprite_timer >= animation_speed:
			sprite_timer -= animation_speed
			sprite_frame = (sprite_frame + 1) % max(1, int(context.get("boss_sprite_frame_count", SPRITE_FRAME_COUNT)))
	else:
		sprite_timer = 0.0
		sprite_frame = 0


func _update_hit_animation(delta: float, context: Dictionary) -> void:
	if not hit_active:
		return
	hit_timer -= delta
	if hit_timer <= 0.0:
		hit_active = false
		return
	hit_frame_timer += delta
	var hit_frame_speed: float = float(context.get("boss_hit_frame_speed", HIT_FRAME_SPEED))
	if hit_frame_timer >= hit_frame_speed:
		hit_frame_timer -= hit_frame_speed
		hit_frame = (hit_frame + 1) % max(1, int(context.get("boss_hit_frame_count", HIT_FRAME_COUNT)))
