extends RefCounted

const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")


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
	var bob: float = sin(float(Time.get_ticks_msec()) * 0.0048) * 2.6
	var draw_center: Vector2 = center + Vector2(0.0, bob)
	var glow_alpha: float = 0.17 + 0.07 * sin(float(Time.get_ticks_msec()) * 0.006)
	canvas.draw_circle(draw_center, radius + 13.0, Color(0.22, 1.0, 0.78, glow_alpha))
	if switch_transition > 0.0:
		_draw_switch_transition(canvas, draw_center, radius, switch_transition, int(config.get("switch_particles", 12)), int(config.get("switch_trigger_count", 0)))
	var sprite_alpha: float = 1.0 if switch_transition <= 0.0 else lerpf(0.42, 1.0, 1.0 - switch_transition)
	_draw_companion_sprite(canvas, draw_center, config, sprite_alpha)
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
	var rects: Dictionary = animator.build_draw_rects(
		tex,
		mode,
		center,
		float(config.get("patrol_pause", 0.0)),
		float(config.get("windup_elapsed", 0.0)),
		float(config.get("windup_seconds", 0.0)),
		float(config.get("motion_speed_ratio", 0.0))
	)
	if rects.is_empty():
		return
	var dest_rect: Rect2 = rects.get("dest", Rect2())
	var source_rect: Rect2 = rects.get("source", Rect2())
	canvas.draw_texture_rect_region(tex, dest_rect, source_rect, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))


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
