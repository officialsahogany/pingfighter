extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")

var sprite_renderer: Object = Stage1PlayerSpriteRenderer.new()


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var pillar_drawer = context.get("pillar_drawer", null)
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var paddle_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(84.0, 16.0)), Vector2(84.0, 16.0))
	var player_speed: float = float(context.get("player_speed", 0.0))
	var dash_active: bool = bool(context.get("dash_active", false))
	var dash_recovering: bool = bool(context.get("dash_recovering", false))
	var player_move_active: bool = abs(player_speed) > 0.2 or dash_active
	var player_anim_clock: float = float(context.get("player_anim_clock", 0.0))
	var hover_amplitude: float = float(context.get("player_hover_amplitude", 7.0))
	var hover_wave: float = sin(player_anim_clock * float(context.get("player_hover_speed", 4.5)))
	var hover_offset: float = hover_wave * hover_amplitude
	var move_bob: float = 0.0
	var breath_wave: float = 0.0
	var player_draw_size: Vector2 = _as_vector2(context.get("player_sprite_draw_size", Vector2(250.0, 120.0)), Vector2(250.0, 120.0))
	# Smasher attack sheet has overhead paddle reach (cell aspect 344x384). When
	# the sheet is loaded AND the hit anim is active, use a taller draw size so
	# the apex frame's overhead paddle isn't squished into the walk-strip's
	# 250x120 footprint. Bottom stays anchored at the paddle (rect builder
	# below uses `paddle_size.y - player_draw_size.y` so the bottom edge is
	# fixed; growing height extends the rect upward).
	var attack_sheet_present: bool = context.get("player_attack_sheet", null) is Texture2D
	if attack_sheet_present and bool(context.get("player_hit_active", false)):
		player_draw_size = _as_vector2(context.get("player_attack_draw_size", Vector2(250.0, 280.0)), Vector2(250.0, 280.0))
	var player_paddle_scale: float = max(0.1, float(context.get("player_paddle_scale", max(1.0, paddle_size.x / 155.0))))
	player_draw_size *= player_paddle_scale
	var player_visual_x_offset: float = 0.0
	var throw_pose_active: bool = bool(context.get("active_item_throw_windup_active", false))
	var throw_pose_progress: float = clamp(float(context.get("active_item_throw_windup_progress", 0.0)), 0.0, 1.0)

	if player_move_active:
		move_bob = abs(sin(player_anim_clock * 10.0)) * float(context.get("player_move_bob_amplitude", 5.0))
	else:
		breath_wave = sin(player_anim_clock * 5.236)
		player_draw_size.x *= 1.0 - breath_wave * float(context.get("player_idle_breath_scale_x", 0.015))
		player_draw_size.y *= 1.0 + breath_wave * float(context.get("player_idle_breath_scale_y", 0.025))

	var player_visual_y_offset: float = -hover_offset - move_bob - (breath_wave * float(context.get("player_idle_breath_y", 2.5)))
	if bool(context.get("player_hit_active", false)):
		var hit_progress: float = _get_player_hit_progress(float(context.get("player_hit_timer", 0.0)), float(context.get("player_hit_anim_duration", 0.36)))
		var hit_snap: float = 1.0 - _ease_out_cubic(pillar_drawer, hit_progress)
		var hit_rebound: float = _ease_in_out_sine(pillar_drawer, hit_progress) * (1.0 - hit_progress)
		player_visual_x_offset = float(context.get("player_hit_side", 1)) * (
			float(context.get("player_hit_lunge_x", 14.0)) * hit_snap - float(context.get("player_hit_rebound_x", 5.0)) * hit_rebound
		)
		player_visual_y_offset += -float(context.get("player_hit_lunge_y", 8.0)) * hit_snap + float(context.get("player_hit_rebound_y", 2.5)) * hit_rebound
		player_draw_size.x *= 1.0 + float(context.get("player_hit_scale_x", 0.055)) * hit_snap - float(context.get("player_hit_scale_x", 0.055)) * 0.35 * hit_rebound
		player_draw_size.y *= 1.0 - float(context.get("player_hit_scale_y", 0.045)) * hit_snap + float(context.get("player_hit_scale_y", 0.045)) * 0.4 * hit_rebound

	if dash_recovering:
		player_visual_x_offset += float(randi_range(-2, 2))
		player_visual_y_offset += float(randi_range(-1, 1))

	if throw_pose_active:
		player_visual_y_offset -= sin(throw_pose_progress * PI) * 5.0

	var shadow_scale: float = 1.0 - ((hover_offset + hover_amplitude) / (hover_amplitude * 2.0)) * 0.18
	var shadow_width: float = 180.0 * shadow_scale * max(1.0, player_paddle_scale)
	var shadow_height: float = 16.0 * shadow_scale * (0.82 + 0.18 * max(1.0, player_paddle_scale))
	var player_shadow_rect := Rect2(
		player_pos.x + paddle_size.x * 0.5 - shadow_width * 0.5 + shake_offset.x,
		player_pos.y + paddle_size.y - 6.0 + shake_offset.y,
		shadow_width,
		shadow_height
	)
	if pillar_drawer != null and pillar_drawer.has_method("draw_soft_shadow_ellipse"):
		pillar_drawer.draw_soft_shadow_ellipse(
			canvas,
			player_shadow_rect,
			Color(0.0, 0.0, 0.0, 0.18 + (1.0 - shadow_scale) * 0.05)
		)

	var player_visual_rect := Rect2(
		player_pos.x + paddle_size.x * 0.5 - player_draw_size.x * 0.5 + shake_offset.x + player_visual_x_offset,
		player_pos.y + paddle_size.y - player_draw_size.y + 12.0 + shake_offset.y + player_visual_y_offset,
		player_draw_size.x,
		player_draw_size.y
	)
	var sprite_context: Dictionary = context
	if throw_pose_active:
		sprite_context = context.duplicate()
		sprite_context["player_sprite_rotation_degrees"] = float(context.get("active_item_throw_windup_angle_degrees", 0.0))
	sprite_renderer.draw(
		canvas,
		sprite_context,
		player_visual_rect,
		player_move_active,
		player_pos,
		paddle_size,
		shake_offset
	)


func _get_player_hit_progress(hit_timer: float, hit_duration: float) -> float:
	if hit_duration <= 0.0:
		return 1.0
	return clamp(1.0 - (hit_timer / hit_duration), 0.0, 1.0)


func _ease_out_cubic(pillar_drawer, t: float) -> float:
	if pillar_drawer != null and pillar_drawer.has_method("ease_out_cubic"):
		return pillar_drawer.ease_out_cubic(t)
	var clamped_t: float = clamp(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped_t, 3.0)


func _ease_in_out_sine(pillar_drawer, t: float) -> float:
	if pillar_drawer != null and pillar_drawer.has_method("ease_in_out_sine"):
		return pillar_drawer.ease_in_out_sine(t)
	var clamped_t: float = clamp(t, 0.0, 1.0)
	return -(cos(PI * clamped_t) - 1.0) * 0.5


func _as_vector2(value, fallback: Vector2) -> Vector2:
	return Stage1ContextReader.as_vector2(value, fallback)
