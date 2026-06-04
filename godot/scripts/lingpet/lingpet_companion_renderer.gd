extends RefCounted

const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const SoftGlowTexture := preload("res://scripts/effects/soft_glow_texture.gd")

# Soft ambient aura tuning. The persistent companion glow (Lunabi / Maribo) is a
# cached radial-falloff texture blitted as a few fully-overlapping low-alpha
# layers -- NOT a hard draw_circle disc, and NOT discrete orbiting dots (those
# read as "air bubbles") -- so the SD body reads as wrapped in one smooth, even
# fluorescent glow. Kept deliberately faint and feathered ("아주 티 안 나게 투명"),
# driven by a two-rate organic breathing ease. The flash/burst glows below stay
# sharp on purpose -- those are gameplay feedback, not the ambient aura.
const _SOFT_GLOW_TEX_SIZE := 64


func prewarm_assets() -> void:
	_get_or_create_soft_glow_texture()


func draw_companion(canvas: CanvasItem, center: Vector2, config: Dictionary) -> void:
	if canvas == null:
		return
	if not bool(config.get("companion_visible", true)):
		return
	var radius: float = float(config.get("radius", 16.0))
	var hit_flash: float = float(config.get("hit_flash", 0.0))
	var gauge_flash: float = float(config.get("gauge_flash", 0.0))
	var skill_flash: float = float(config.get("skill_flash", 0.0))
	var switch_transition: float = clampf(float(config.get("switch_transition", 0.0)), 0.0, 1.0)
	var now_ms: float = float(Time.get_ticks_msec())
	var bob: float = sin(now_ms * 0.0048) * 2.6
	var draw_center: Vector2 = center + Vector2(0.0, bob)
	# Soft "barely-there" ambient aura -- replaces the old hard draw_circle disc.
	# See the _SOFT_GLOW_TEX_SIZE notes at the top of the file.
	_draw_soft_aura(canvas, draw_center, radius, now_ms)
	if switch_transition > 0.0:
		_draw_switch_transition(canvas, draw_center, radius, switch_transition, int(config.get("switch_particles", 12)), int(config.get("switch_trigger_count", 0)))
	var sprite_alpha: float = 1.0 if switch_transition <= 0.0 else lerpf(0.42, 1.0, 1.0 - switch_transition)
	_draw_companion_sprite(canvas, draw_center, config, sprite_alpha)
	if switch_transition > 0.0:
		_draw_switch_label(canvas, draw_center, str(config.get("display_name", "")), switch_transition)
	if gauge_flash > 0.0:
		var gauge_radius: float = lerpf(radius + 14.0, radius + 42.0, 1.0 - gauge_flash)
		canvas.draw_circle(draw_center, gauge_radius, Color(1.0, 0.88, 0.24, 0.16 * gauge_flash))
		canvas.draw_arc(draw_center, gauge_radius * 0.82, 0.0, TAU, 36, Color(1.0, 0.94, 0.42, 0.68 * gauge_flash), 2.2, true)
		_draw_burst(canvas, draw_center, gauge_flash, int(config.get("burst_particles", 8)), int(config.get("gauge_trigger_count", 0)), Color(1.0, 0.88, 0.24, 1.0), true)
	if skill_flash > 0.0:
		var skill_radius: float = lerpf(radius + 18.0, radius + 54.0, 1.0 - skill_flash)
		canvas.draw_circle(draw_center, skill_radius, Color(0.24, 0.92, 1.0, 0.18 * skill_flash))
		canvas.draw_arc(draw_center, skill_radius * 0.82, 0.0, TAU, 40, Color(0.72, 1.0, 1.0, 0.72 * skill_flash), 2.6, true)
		_draw_burst(canvas, draw_center, skill_flash, int(config.get("burst_particles", 8)), int(config.get("skill_trigger_count", 0)), Color(0.54, 1.0, 1.0, 1.0), false)
	if hit_flash > 0.0:
		var flash_radius: float = lerpf(radius + 8.0, radius + 34.0, 1.0 - hit_flash)
		canvas.draw_circle(draw_center, flash_radius, Color(0.70, 1.0, 0.92, 0.22 * hit_flash))
		canvas.draw_arc(draw_center, flash_radius * 0.86, 0.0, TAU, 36, Color(0.88, 1.0, 0.76, 0.58 * hit_flash), 2.0, true)


func _draw_soft_aura(canvas: CanvasItem, center: Vector2, radius: float, now_ms: float) -> void:
	var tex: Texture2D = _get_or_create_soft_glow_texture()
	if tex == null:
		return
	# Two-rate breathing: a slow primary swell mixed with a gentler faster
	# shimmer so the pulse never reads as one mechanical sine. Small amplitude.
	var breath_slow: float = 0.5 + 0.5 * sin(now_ms * 0.00082)
	var breath_fast: float = 0.5 + 0.5 * sin(now_ms * 0.0021 + 1.3)
	var breath: float = lerpf(breath_slow, breath_fast, 0.32)
	# The companion sprite renders at ~82 px (WALK_DRAW_SIZE), far larger than the
	# 16 px gameplay hit radius, so the glow must be sized off the VISIBLE body
	# extent (body_r) -- sizing it off `radius` blooms the whole halo behind the
	# sprite and reads as nothing. Three concentric, fully overlapping layers form
	# ONE smooth fluorescent halo (no discrete dots / bubbles): a wide faint rim,
	# a mid body, and a slightly whiter core, brightest hugging the body and
	# fading out well past its silhouette.
	var body_r: float = radius + 14.0
	var core_r: float = body_r + lerpf(13.0, 17.0, breath)
	var core_a: float = lerpf(0.17, 0.22, breath)
	var mid_r: float = body_r + lerpf(24.0, 30.0, breath)
	var mid_a: float = lerpf(0.115, 0.150, breath)
	var outer_r: float = body_r + lerpf(37.0, 45.0, breath)
	var outer_a: float = lerpf(0.060, 0.085, breath)
	_blit_soft_glow(canvas, tex, center, outer_r, Color(0.20, 1.0, 0.72, outer_a))
	_blit_soft_glow(canvas, tex, center, mid_r, Color(0.34, 1.0, 0.80, mid_a))
	_blit_soft_glow(canvas, tex, center, core_r, Color(0.66, 1.0, 0.92, core_a))


func _blit_soft_glow(canvas: CanvasItem, tex: Texture2D, center: Vector2, glow_radius: float, color: Color) -> void:
	var r: float = maxf(1.0, glow_radius)
	canvas.draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, color)


# Cached soft radial-falloff glow sprite, shared with player_state_glow_renderer
# through the common SoftGlowTexture util (cos^2 feathered alpha, project halo
# convention). One-time small CPU build, cached by size off the per-frame hot
# path. cos^2 stays gentle at the rim but keeps real alpha through the mid-radius
# so the glow has visible substance OUTSIDE the sprite silhouette.
static func _get_or_create_soft_glow_texture() -> Texture2D:
	return SoftGlowTexture.get_texture(_SOFT_GLOW_TEX_SIZE)


func _draw_companion_sprite(canvas: CanvasItem, center: Vector2, config: Dictionary, alpha: float = 1.0) -> void:
	var animator: Object = config.get("animator", null) as Object
	if animator == null:
		return
	var mode: String = LingpetCompanionSpriteAnimator.MODE_WALK
	var tex: Texture2D = config.get("walk_texture", null) as Texture2D
	if bool(config.get("casting_windup", false)):
		mode = LingpetCompanionSpriteAnimator.MODE_CAST
		tex = config.get("cast_texture", null) as Texture2D
	elif bool(config.get("attacking", false)):
		mode = LingpetCompanionSpriteAnimator.MODE_STRIKE
		tex = config.get("strike_texture", null) as Texture2D
	if tex == null:
		return
	var draw_size_override: Vector2 = _get_draw_size_override(config, mode)
	var rects: Dictionary = animator.build_draw_rects(
		tex,
		mode,
		center,
		float(config.get("patrol_pause", 0.0)),
		float(config.get("windup_elapsed", 0.0)),
		float(config.get("windup_seconds", 0.0)),
		float(config.get("motion_speed_ratio", 0.0)),
		draw_size_override
	)
	if rects.is_empty():
		return
	var dest_rect: Rect2 = rects.get("dest", Rect2())
	var source_rect: Rect2 = rects.get("source", Rect2())
	var modulate := Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	# The walk sheet faces the direction of travel (iso_walk_northeast = rightward
	# 3/4 back). When the companion moves left, mirror it by swapping UVs across the
	# same positive destination rect. Passing a negative Rect2 width to
	# draw_texture_rect_region can shift the visible sheet away from the collision
	# center on some draw paths.
	if bool(config.get("face_left", false)):
		_draw_flipped_texture_region(canvas, tex, source_rect, dest_rect, modulate)
	else:
		canvas.draw_texture_rect_region(tex, dest_rect, source_rect, modulate, false, true)


func _get_draw_size_override(config: Dictionary, mode: String) -> Vector2:
	var key := "walk_draw_size"
	match mode:
		LingpetCompanionSpriteAnimator.MODE_CAST:
			key = "cast_draw_size"
		LingpetCompanionSpriteAnimator.MODE_STRIKE:
			key = "strike_draw_size"
	var draw_size: float = float(config.get(key, 0.0))
	if draw_size <= 0.0:
		return Vector2.ZERO
	return Vector2(draw_size, draw_size)


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


func _draw_burst(
	canvas: CanvasItem,
	center: Vector2,
	flash_ratio: float,
	particle_count: int,
	trigger_count: int,
	tint: Color,
	is_gauge: bool
) -> void:
	var safe_count: int = maxi(1, particle_count)
	var expansion: float = 1.0 - flash_ratio
	var phase_offset: float = float(trigger_count % 5) * (0.19 if is_gauge else 0.17)
	var start_min: float = 8.0 if is_gauge else 10.0
	var start_max: float = 16.0 if is_gauge else 20.0
	var end_min: float = 18.0 if is_gauge else 22.0
	var end_max: float = 42.0 if is_gauge else 52.0
	var alpha: float = (0.58 if is_gauge else 0.62) * flash_ratio
	var line_width: float = (2.0 if is_gauge else 2.2) * flash_ratio
	var dot_radius: float = (2.4 if is_gauge else 2.6) * flash_ratio
	for i in range(safe_count):
		var angle: float = TAU * float(i) / float(safe_count) + phase_offset
		var dir := Vector2(cos(angle), sin(angle))
		var ray_start: Vector2 = center + dir * lerpf(start_min, start_max, expansion)
		var ray_end: Vector2 = center + dir * lerpf(end_min, end_max, expansion)
		var line_color := Color(tint.r, tint.g, tint.b, alpha)
		var dot_color := Color(1.0, 0.98, 0.62, alpha) if is_gauge else Color(0.88, 1.0, 1.0, alpha)
		canvas.draw_line(ray_start, ray_end, line_color, maxf(1.0, line_width), true)
		canvas.draw_circle(ray_end, maxf(1.1 if is_gauge else 1.2, dot_radius), dot_color)


func _draw_switch_transition(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	switch_ratio: float,
	particle_count: int,
	trigger_count: int
) -> void:
	var ratio := clampf(switch_ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var progress := 1.0 - ratio
	var eased := progress * progress * (3.0 - 2.0 * progress)
	var pulse := sin(progress * PI)
	var ring_radius := lerpf(radius + 58.0, radius + 18.0, eased)
	var ring_alpha := 0.16 + 0.28 * ratio + 0.14 * pulse
	canvas.draw_circle(center, ring_radius, Color(0.08, 0.64, 0.72, 0.10 * ratio))
	canvas.draw_arc(center, ring_radius, -PI * 0.5 + progress * TAU, PI * 1.35 + progress * TAU, 36, Color(0.42, 1.0, 0.96, ring_alpha), 2.4, true)
	canvas.draw_arc(center, ring_radius * 0.62, PI * 0.25 - progress * TAU, PI * 1.55 - progress * TAU, 32, Color(0.72, 1.0, 0.82, 0.32 * ratio), 1.8, true)
	var safe_count := maxi(4, particle_count)
	var phase_offset := float(trigger_count % 7) * 0.31
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count) + phase_offset
		var dir := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-dir.y, dir.x)
		var scatter := lerpf(radius + 66.0, radius + 10.0, eased)
		var wobble := sin(progress * TAU * 2.1 + float(i) * 1.77 + phase_offset) * lerpf(8.0, 2.0, eased)
		var shard_pos := center + dir * scatter + tangent * wobble
		var shard_target := center + dir * lerpf(radius + 18.0, radius + 4.0, eased)
		var shard_alpha := (0.26 + 0.34 * pulse) * ratio
		var shard_size := lerpf(3.0, 1.4, eased)
		canvas.draw_line(shard_pos, shard_target, Color(0.38, 1.0, 0.94, shard_alpha), maxf(1.0, 1.7 * ratio), true)
		canvas.draw_circle(shard_pos, maxf(1.0, shard_size), Color(0.82, 1.0, 0.88, minf(0.88, shard_alpha + 0.18)))


func _draw_switch_label(canvas: CanvasItem, center: Vector2, display_name: String, switch_ratio: float) -> void:
	var name := display_name.strip_edges()
	if name == "":
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var ratio := clampf(switch_ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var progress := 1.0 - ratio
	var alpha := clampf(sin(progress * PI) * 1.35, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var font_size := 14
	var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var pos := center + Vector2(-width * 0.5, -62.0 - 8.0 * sin(progress * PI))
	var bg_rect := Rect2(pos + Vector2(-8.0, -font_size - 6.0), Vector2(width + 16.0, float(font_size) + 12.0))
	canvas.draw_rect(bg_rect, Color(0.015, 0.035, 0.052, 0.58 * alpha))
	canvas.draw_rect(bg_rect, Color(0.42, 1.0, 0.94, 0.62 * alpha), false, 1.4)
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.58 * alpha))
	canvas.draw_string(font, pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.78, 1.0, 0.95, 0.96 * alpha))
