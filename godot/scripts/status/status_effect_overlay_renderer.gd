extends RefCounted

const BossHealthBarRenderer := preload("res://scripts/status/boss_health_bar_renderer.gd")

const STUN_STAR_FILL := Color(1.0, 1.0, 100.0 / 255.0, 1.0)
const STUN_STAR_OUTLINE := Color(1.0, 200.0 / 255.0, 0.0, 1.0)
const STUN_STAR_GLOW_OUTER := Color(1.0, 0.92, 0.20, 0.14)
const STUN_STAR_GLOW_INNER := Color(1.0, 1.0, 0.52, 0.20)
const SPIDER_WAVE_SEGMENTS := 20

var _unit_stun_star_points := PackedVector2Array()
var _question_size_cache: Dictionary = {}
var boss_health_bar_renderer: Object = BossHealthBarRenderer.new()


func draw_boss_status_overlays(
	canvas: CanvasItem,
	context: Dictionary,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2,
	options: Dictionary = {}
) -> void:
	if canvas == null:
		return
	if bool(context.get("active_item_boss_stun_active", false)) and not bool(context.get("active_item_boss_stun_stars_suppressed", false)):
		_draw_boss_stun_stars(canvas, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset, options)
	if bool(context.get("active_item_boss_confusion_active", false)):
		_draw_boss_confusion_questions(canvas, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset, options)
	if bool(context.get("active_item_boss_spider_slow_active", false)):
		_draw_boss_slow_wave(
			canvas,
			boss_pos,
			boss_paddle_size,
			boss_hitbox_height,
			shake_offset,
			float(context.get("active_item_boss_spider_slow_ratio", context.get("status_boss_slow_ratio", 1.0))),
			options
		)
	draw_boss_cooldown_pause_marker(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset, options)
	boss_health_bar_renderer.draw(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)


func draw_player_status_overlays(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	player_paddle_size: Vector2,
	player_visual_rect: Rect2,
	shake_offset: Vector2,
	options: Dictionary = {}
) -> void:
	if canvas == null:
		return
	if bool(context.get("status_player_stun_active", false)) and not bool(context.get("status_player_stun_stars_suppressed", false)):
		_draw_player_stun_stars(canvas, player_pos, player_paddle_size, player_visual_rect, shake_offset, options)


func draw_boss_cooldown_pause_marker(
	canvas: CanvasItem,
	context: Dictionary,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2,
	options: Dictionary = {}
) -> void:
	if canvas == null or not _is_boss_cooldown_pause_marker_active(context):
		return
	_draw_boss_cooldown_pause_marker(canvas, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset, options)


func _is_boss_cooldown_pause_marker_active(context: Dictionary) -> bool:
	return (
		bool(context.get("active_item_boss_tear_gas_pause_active", false))
		or bool(context.get("active_item_boss_skill_cooldown_paused", false))
		or bool(context.get("active_item_tear_gas_cooldown_pause_active", false))
	)


func _draw_boss_stun_stars(
	canvas: CanvasItem,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2,
	options: Dictionary
) -> void:
	var center := boss_pos + Vector2(
		boss_paddle_size.x * 0.5,
		boss_hitbox_height * 0.5 + float(options.get("stun_center_y_offset", -22.0))
	) + shake_offset + Vector2(0.0, float(options.get("extra_y_offset", 0.0)))
	var angle_base: float = float(Time.get_ticks_msec()) * 0.006
	for idx in range(3):
		var angle: float = angle_base + TAU * float(idx) / 3.0
		_draw_stun_star(canvas, center + Vector2(cos(angle) * 22.0, sin(angle) * 8.0), 8.0)


func _draw_player_stun_stars(
	canvas: CanvasItem,
	player_pos: Vector2,
	player_paddle_size: Vector2,
	player_visual_rect: Rect2,
	shake_offset: Vector2,
	options: Dictionary
) -> void:
	var center: Vector2
	if player_visual_rect.size.x > 0.0 and player_visual_rect.size.y > 0.0:
		center = Vector2(
			player_visual_rect.get_center().x,
			player_visual_rect.position.y + float(options.get("stun_center_y_offset", 8.0))
		)
	else:
		center = player_pos + Vector2(
			player_paddle_size.x * 0.5,
			float(options.get("fallback_stun_center_y_offset", -40.0))
		) + shake_offset
	var angle_base: float = float(Time.get_ticks_msec()) * 0.006
	for idx in range(3):
		var angle: float = angle_base + TAU * float(idx) / 3.0
		_draw_stun_star(canvas, center + Vector2(cos(angle) * 20.0, sin(angle) * 8.0), 8.0)


func _draw_stun_star(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	if _unit_stun_star_points.is_empty():
		_unit_stun_star_points = _build_unit_stun_star_points()
	canvas.draw_circle(center, radius * 2.0, STUN_STAR_GLOW_OUTER)
	canvas.draw_circle(center, radius * 1.35, STUN_STAR_GLOW_INNER)
	var points := PackedVector2Array()
	for point in _unit_stun_star_points:
		points.append(center + point * radius)
	canvas.draw_colored_polygon(points, STUN_STAR_FILL)
	for idx in range(points.size()):
		canvas.draw_line(points[idx], points[(idx + 1) % points.size()], STUN_STAR_OUTLINE, 1.2, true)


func _build_unit_stun_star_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for idx in range(10):
		var point_angle: float = deg_to_rad(float(idx) * 36.0 - 90.0)
		var point_radius: float = 1.0 if idx % 2 == 0 else 0.4
		points.append(Vector2(cos(point_angle), sin(point_angle)) * point_radius)
	return points


func _draw_boss_confusion_questions(
	canvas: CanvasItem,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2,
	options: Dictionary
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var current_msec: int = Time.get_ticks_msec()
	var orbit_rotation: float = float(current_msec) * 0.005
	var orbit_center := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5 + shake_offset.x,
		boss_pos.y + boss_hitbox_height * 0.5 + float(options.get("confusion_center_y_offset", -25.0)) + shake_offset.y + float(options.get("extra_y_offset", 0.0))
	)
	var orbit_radius: float = float(options.get("confusion_orbit_radius", 40.0))
	for idx in range(3):
		var angle: float = orbit_rotation + float(idx) * TAU / 3.0
		var center := Vector2(
			orbit_center.x + orbit_radius * cos(angle),
			orbit_center.y + orbit_radius * sin(angle) * 0.5
		)
		var size_factor: float = 0.8 + 0.2 * sin(angle)
		var color: Color = Color(1.0, 1.0, 100.0 / 255.0, 1.0)
		if sin(float(current_msec) * 0.01 + float(idx)) <= 0.0:
			color = Color(1.0, 200.0 / 255.0, 50.0 / 255.0, 1.0)
		_draw_centered_question(canvas, font, center, max(18, int(28.0 * size_factor)), color, Color(50.0 / 255.0, 50.0 / 255.0, 0.0, 1.0), Vector2(2.0, 2.0))

	var center_color: Color = Color(1.0, 1.0, 150.0 / 255.0, 1.0)
	if sin(float(current_msec) * 0.015) <= 0.0:
		center_color = Color(1.0, 220.0 / 255.0, 100.0 / 255.0, 1.0)
	_draw_centered_question(canvas, font, orbit_center, 45, center_color, Color(100.0 / 255.0, 100.0 / 255.0, 50.0 / 255.0, 1.0), Vector2(3.0, 3.0))


func _draw_centered_question(
	canvas: CanvasItem,
	font: Font,
	center: Vector2,
	font_size: int,
	color: Color,
	shadow_color: Color,
	shadow_offset: Vector2
) -> void:
	var text := "?"
	var text_size: Vector2 = _get_question_text_size(font, font_size)
	var pos := center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.75)
	canvas.draw_string(font, pos + shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_question_text_size(font: Font, font_size: int) -> Vector2:
	if _question_size_cache.has(font_size):
		return _question_size_cache[font_size]
	var text_size: Vector2 = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_question_size_cache[font_size] = text_size
	return text_size


func _draw_boss_slow_wave(
	canvas: CanvasItem,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2,
	ratio: float,
	options: Dictionary
) -> void:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	var intensity: float = 0.45 + 0.55 * clamped_ratio
	var center := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5 + shake_offset.x,
		boss_pos.y + boss_hitbox_height * 0.5 + float(options.get("slow_center_y_offset", -18.0)) + shake_offset.y + float(options.get("extra_y_offset", 0.0))
	)
	var time_phase: float = float(Time.get_ticks_msec()) * 0.006
	for idx in range(4):
		var wave_ratio: float = float(idx) / 3.0
		var wave_width: float = 66.0 * (1.0 - wave_ratio * 0.12)
		var wave_height: float = 18.0 + wave_ratio * 9.0
		var y_offset: float = -20.0 - float(idx) * 7.0 + sin(time_phase + float(idx) * 0.8) * 2.5
		var alpha: float = (0.20 - wave_ratio * 0.035) * intensity
		_draw_ellipse_outline(
			canvas,
			Rect2(center + Vector2(-wave_width * 0.5, y_offset), Vector2(wave_width, wave_height)),
			Color(110.0 / 255.0, 170.0 / 255.0, 1.0, alpha),
			2.0
		)
	canvas.draw_line(
		center + Vector2(-44.0, -12.0),
		center + Vector2(44.0, -12.0),
		Color(110.0 / 255.0, 170.0 / 255.0, 1.0, 0.18 * intensity),
		3.0
	)


func _draw_boss_cooldown_pause_marker(
	canvas: CanvasItem,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2,
	options: Dictionary
) -> void:
	var center := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5 + shake_offset.x,
		boss_pos.y
		+ boss_hitbox_height * 0.5
		+ float(options.get("cooldown_pause_center_y_offset", -30.0))
		+ shake_offset.y
		+ float(options.get("extra_y_offset", 0.0))
	)
	var phase: float = float(Time.get_ticks_msec()) * 0.006
	var pulse: float = 0.55 + 0.45 * sin(phase)
	canvas.draw_circle(center, 19.0 + pulse * 3.0, Color(0.56, 0.75, 0.42, 0.16))
	canvas.draw_circle(center, 16.0, Color(0.12, 0.16, 0.12, 0.62))
	canvas.draw_arc(center, 18.0, -PI * 0.5 + phase, PI * 1.5 + phase, 32, Color(0.78, 0.95, 0.52, 0.76), 2.5)
	var bar_color := Color(0.84, 1.0, 0.64, 0.92)
	canvas.draw_rect(Rect2(center + Vector2(-6.0, -8.0), Vector2(4.0, 16.0)), bar_color)
	canvas.draw_rect(Rect2(center + Vector2(2.0, -8.0), Vector2(4.0, 16.0)), bar_color)


func _draw_ellipse_outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius: Vector2 = rect.size * 0.5
	for idx in range(SPIDER_WAVE_SEGMENTS):
		var angle: float = TAU * float(idx) / float(SPIDER_WAVE_SEGMENTS)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	for idx in range(points.size()):
		canvas.draw_line(points[idx], points[(idx + 1) % points.size()], color, width)
