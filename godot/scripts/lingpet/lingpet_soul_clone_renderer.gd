extends RefCounted

const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const TEXTURE_PATH := "res://assets/sprites/lingpet/rabi_companion_walk.png"
const CLONE_DRAW_SIZE := Vector2(86.0, 86.0)
const CLONE_STRIKE_DRAW_SIZE := Vector2(100.0, 100.0)
const CLONE_MAX_SPEED := 168.0

var _texture: Texture2D = null


func prewarm() -> void:
	_ensure_texture()


func draw_soul_clone(
	canvas: CanvasItem,
	shake_offset: Vector2,
	active: bool,
	elapsed: float,
	active_duration: float,
	visual_time_msec: float,
	clones: Array[Dictionary],
	particles: Array[Dictionary]
) -> void:
	if canvas == null:
		return
	_draw_particles(canvas, particles, shake_offset)
	if not active:
		return
	var texture := _ensure_texture()
	var remaining_ratio := clampf((active_duration - elapsed) / maxf(0.001, active_duration), 0.0, 1.0)
	var fade_alpha := clampf(minf(elapsed / 0.28, remaining_ratio / 0.12), 0.0, 1.0)
	for clone_value in clones:
		var clone := clone_value as Dictionary
		var visual_phase := get_clone_visual_phase_for_tests(visual_time_msec, float(clone.get("bob_phase", 0.0)))
		var pulse := float(visual_phase.get("pulse", 0.5))
		var clone_pos := _get_clone_vector2(clone, "pos", Vector2.ZERO)
		var draw_center := clone_pos + shake_offset + Vector2(0.0, float(visual_phase.get("bob_offset", 0.0)))
		_draw_clone_aura(canvas, draw_center, fade_alpha, pulse)
		if texture == null:
			_draw_procedural_fallback(canvas, draw_center)
		else:
			_draw_clone_sprite(canvas, texture, clone, draw_center, fade_alpha, pulse)


func get_clone_visual_phase_for_tests(visual_time_msec: float, bob_phase: float) -> Dictionary:
	return {
		"pulse": 0.5 + 0.5 * sin(visual_time_msec * 0.006 + bob_phase),
		"bob_offset": sin(visual_time_msec * 0.0048 + bob_phase) * 2.4,
	}


func _ensure_texture() -> Texture2D:
	if _texture != null:
		return _texture
	_texture = ProjectResourceLoader.load_imported_texture(
		TEXTURE_PATH,
		"[LingpetSoulClone] missing Rabi clone texture: %s",
		"[LingpetSoulClone] failed to load Rabi clone texture: %s"
	)
	return _texture


func _draw_particles(canvas: CanvasItem, particles: Array[Dictionary], shake_offset: Vector2) -> void:
	for particle_value in particles:
		var particle := particle_value as Dictionary
		var life := float(particle.get("life", 0.0))
		var max_life := maxf(0.01, float(particle.get("max_life", life)))
		var ratio := clampf(life / max_life, 0.0, 1.0)
		var color: Color = particle.get("color", Color(0.6, 0.9, 1.0, 0.4))
		color.a *= ratio
		var radius := maxf(0.5, float(particle.get("radius", 2.0)) * (0.55 + 0.45 * ratio))
		var pos: Vector2 = particle.get("pos", Vector2.ZERO)
		canvas.draw_circle(pos + shake_offset, radius, color)


func _draw_clone_aura(canvas: CanvasItem, center: Vector2, alpha: float, pulse: float) -> void:
	var outer_radius := lerpf(35.0, 44.0, pulse)
	var inner_radius := lerpf(22.0, 28.0, 1.0 - pulse)
	canvas.draw_circle(center, outer_radius, Color(0.18, 0.62, 1.0, 0.075 * alpha))
	canvas.draw_circle(center, inner_radius, Color(0.58, 0.92, 1.0, 0.10 * alpha))
	canvas.draw_arc(center, outer_radius * 0.82, -PI * 0.5, PI * 1.2, 36, Color(0.70, 0.96, 1.0, 0.34 * alpha), 1.6, true)


func _draw_clone_sprite(
	canvas: CanvasItem,
	texture: Texture2D,
	clone: Dictionary,
	center: Vector2,
	alpha: float,
	pulse: float
) -> void:
	var animator: Object = clone.get("animator", null) as Object
	if animator == null:
		return
	var velocity := _get_clone_vector2(clone, "velocity", Vector2.ZERO)
	var mode := LingpetCompanionSpriteAnimator.MODE_STRIKE if animator.strike_active else LingpetCompanionSpriteAnimator.MODE_WALK
	var draw_size := CLONE_STRIKE_DRAW_SIZE if animator.strike_active else CLONE_DRAW_SIZE
	var speed_ratio := clampf(velocity.length() / CLONE_MAX_SPEED, 0.12, 1.0)
	var rects: Dictionary = animator.build_draw_rects(texture, mode, center, 0.0, 0.0, 0.0, speed_ratio, draw_size)
	if rects.is_empty():
		return
	var dest_rect: Rect2 = rects.get("dest", Rect2())
	var source_rect: Rect2 = rects.get("source", Rect2())
	var trail_offset := Vector2(-signf(velocity.x) * 5.0, 3.0)
	if velocity.length() <= 1.0:
		trail_offset = Vector2(0.0, 4.0)
	var trail_color := Color(0.33, 0.72, 1.0, 0.16 * alpha)
	var second_trail_color := Color(0.75, 0.52, 1.0, 0.10 * alpha)
	var face_left := bool(clone.get("face_left", false))
	_draw_region(canvas, texture, source_rect, Rect2(dest_rect.position + trail_offset * 1.7, dest_rect.size), second_trail_color, face_left)
	_draw_region(canvas, texture, source_rect, Rect2(dest_rect.position + trail_offset, dest_rect.size), trail_color, face_left)
	var main_color := Color(0.76 + 0.08 * pulse, 0.95, 1.0, 0.67 * alpha)
	_draw_region(canvas, texture, source_rect, dest_rect, main_color, face_left)


func _draw_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color,
	face_left: bool
) -> void:
	if face_left:
		_draw_flipped_texture_region(canvas, texture, source_rect, target_rect, modulate)
	else:
		canvas.draw_texture_rect_region(texture, target_rect, source_rect, modulate, false, true)


func _draw_flipped_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_procedural_fallback(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_circle(center, 24.0, Color(0.50, 0.86, 1.0, 0.32))
	canvas.draw_arc(center, 31.0, 0.0, TAU, 28, Color(0.72, 0.96, 1.0, 0.56), 2.0, true)


func _get_clone_vector2(clone: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = clone.get(key, fallback)
	return value as Vector2 if value is Vector2 else fallback
