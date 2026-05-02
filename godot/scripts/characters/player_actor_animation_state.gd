extends RefCounted

const IDLE_FRAME_COUNT := 8
const SPRITE_FRAME_COUNT := 6
const IDLE_ANIMATION_SPEED := 0.15
const SPRITE_ANIMATION_SPEED := 0.10
const HIT_ANIM_DURATION := 0.36
const HIT_FRAME_COUNT := 4

var idle_frame := 0
var idle_timer := 0.0
var sprite_frame := 0
var sprite_timer := 0.0
var hit_active := false
var hit_timer := 0.0
var hit_frame := 0
var hit_side := -1
var anim_clock := 0.0


func reset() -> void:
	idle_frame = 0
	idle_timer = 0.0
	sprite_frame = 0
	sprite_timer = 0.0
	hit_active = false
	hit_timer = 0.0
	hit_frame = 0
	hit_side = -1
	anim_clock = 0.0


func update(delta: float, context: Dictionary) -> void:
	anim_clock += delta

	if hit_active:
		hit_timer -= delta
		if hit_timer <= 0.0:
			hit_active = false
		else:
			var hit_progress: float = get_hit_progress(float(context.get("player_hit_anim_duration", HIT_ANIM_DURATION)))
			var frame_progress: float = _ease_out_cubic(hit_progress)
			hit_frame = min(
				int(floor(frame_progress * float(context.get("player_hit_frame_count", HIT_FRAME_COUNT)))),
				max(0, int(context.get("player_hit_frame_count", HIT_FRAME_COUNT)) - 1)
			)
		return

	var player_is_moving: bool = abs(float(context.get("player_speed", 0.0))) > 0.2 or bool(context.get("dash_active", false))
	if player_is_moving and bool(context.get("player_has_sprite", false)):
		sprite_timer += delta
		var walk_speed: float = float(context.get("player_sprite_animation_speed", SPRITE_ANIMATION_SPEED))
		if sprite_timer >= walk_speed:
			sprite_timer -= walk_speed
			sprite_frame = (sprite_frame + 1) % max(1, int(context.get("player_sprite_frame_count", SPRITE_FRAME_COUNT)))
		idle_timer = 0.0
		idle_frame = 0
	else:
		sprite_timer = 0.0
		sprite_frame = 0
		if bool(context.get("player_has_idle_sprite", false)):
			idle_timer += delta
			var idle_speed: float = float(context.get("player_idle_animation_speed", IDLE_ANIMATION_SPEED))
			if idle_timer >= idle_speed:
				idle_timer -= idle_speed
				idle_frame = (idle_frame + 1) % max(1, int(context.get("player_idle_frame_count", IDLE_FRAME_COUNT)))


func trigger_hit(hit_pos: float, has_hit_texture: bool, hit_duration: float = HIT_ANIM_DURATION) -> void:
	if not has_hit_texture:
		return
	hit_active = true
	hit_timer = hit_duration
	hit_frame = 0
	hit_side = 1 if hit_pos >= 0.0 else -1


func get_hit_progress(hit_duration: float) -> float:
	if hit_duration <= 0.0:
		return 1.0
	return clamp(1.0 - (hit_timer / hit_duration), 0.0, 1.0)


func get_draw_context() -> Dictionary:
	return {
		"player_anim_clock": anim_clock,
		"player_hit_active": hit_active,
		"player_hit_timer": hit_timer,
		"player_hit_side": hit_side,
		"player_hit_frame": hit_frame,
		"player_idle_frame": idle_frame,
		"player_sprite_frame": sprite_frame,
	}


func _ease_out_cubic(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0) - 1.0
	return t * t * t + 1.0
