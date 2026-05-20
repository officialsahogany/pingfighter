extends RefCounted

const DEFAULT_WATER_TRAIL_LIFE_SEC := 0.38
const DEFAULT_WATER_SPLASH_LIFE_SEC := 1.0
const DEFAULT_WATER_CANNON_CHARGE_SEC := 0.80
const DEFAULT_WATER_FRAGMENT_HIT_FLASH_SEC := 0.24
const TARGET_BRACKET_MIN_LENGTH := 8.0
const TARGET_BRACKET_MAX_LENGTH := 16.0
const TARGET_BRACKET_SCALE := 0.34


func draw_fragment_hit_flash(
	canvas: CanvasItem,
	width: float,
	height: float,
	shake_offset: Vector2,
	timer: float,
	duration: float = DEFAULT_WATER_FRAGMENT_HIT_FLASH_SEC
) -> void:
	if timer <= 0.0:
		return
	var ratio: float = clamp(timer / max(0.001, duration), 0.0, 1.0)
	var alpha: float = 0.18 * ratio * ratio
	canvas.draw_rect(Rect2(shake_offset, Vector2(width, height)), Color(1.0, 0.08, 0.03, alpha))
	canvas.draw_rect(Rect2(shake_offset + Vector2(4.0, 4.0), Vector2(width - 8.0, height - 8.0)), Color(1.0, 0.22, 0.08, alpha * 1.35), false, 5.0)


func draw_target_highlight(canvas: CanvasItem, target_rock: Dictionary, phase: String, shake_offset: Vector2) -> void:
	if target_rock.is_empty():
		return
	var center: Vector2 = _get_rock_center(target_rock) + shake_offset
	var radius: float = float(target_rock.get("radius", 28.0))
	var time: float = float(Time.get_ticks_msec()) / 1000.0
	var alpha: float = 0.36
	if phase == "charging":
		alpha = 0.42 + 0.20 * sin(time * 16.0)
	var inner_radius: float = radius + 8.0
	var outer_radius: float = radius + 17.0 + sin(time * 8.0) * 2.0
	var bracket_length: float = clampf(
		radius * TARGET_BRACKET_SCALE,
		TARGET_BRACKET_MIN_LENGTH,
		TARGET_BRACKET_MAX_LENGTH
	)
	var inner_rect := Rect2(
		center - Vector2(inner_radius, inner_radius),
		Vector2(inner_radius * 2.0, inner_radius * 2.0)
	)
	canvas.draw_rect(inner_rect, Color(0.72, 1.0, 1.0, alpha * 0.34), false, 1.5)
	_draw_corner_brackets(
		canvas,
		center,
		outer_radius,
		bracket_length,
		Color(0.20, 0.92, 1.0, alpha),
		2.0
	)


func draw_cannon(canvas: CanvasItem, visual_state: Dictionary, water_trail: Array, shake_offset: Vector2) -> void:
	var trail_life_sec: float = float(visual_state.get("trail_life_sec", DEFAULT_WATER_TRAIL_LIFE_SEC))
	for trail in water_trail:
		var life: float = clamp(float(trail.get("life", 0.0)), 0.0, float(trail.get("max_life", trail_life_sec)))
		var fade: float = life / max(0.001, float(trail.get("max_life", trail_life_sec)))
		var pos: Vector2 = _get_vector2(trail.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var radius: float = float(trail.get("radius", 8.0))
		canvas.draw_circle(pos, radius * fade, Color(0.38, 0.86, 1.0, 0.26 * fade))

	var phase: String = str(visual_state.get("phase", "idle"))
	if phase == "idle":
		return
	var start: Vector2 = _get_vector2(visual_state.get("start", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var target: Vector2 = _get_vector2(visual_state.get("target", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var current: Vector2 = _get_vector2(visual_state.get("current", Vector2.ZERO), Vector2.ZERO) + shake_offset
	if phase == "charging":
		var timer: float = float(visual_state.get("timer", 0.0))
		var charge_sec: float = float(visual_state.get("charge_sec", DEFAULT_WATER_CANNON_CHARGE_SEC))
		var charge_ratio: float = 1.0 - timer / max(0.001, charge_sec)
		var pulse: float = 0.70 + 0.30 * sin(float(Time.get_ticks_msec()) * 0.022)
		canvas.draw_line(start, target, Color(0.20, 0.86, 1.0, 0.12 + 0.14 * charge_ratio), 2.0, true)
		canvas.draw_circle(start, 12.0 + charge_ratio * 16.0 * pulse, Color(0.24, 0.82, 1.0, 0.35 + charge_ratio * 0.24))
		canvas.draw_circle(start, 5.0 + charge_ratio * 6.0, Color(0.84, 1.0, 1.0, 0.78))
		return

	var progress: float = float(visual_state.get("progress", 0.0))
	var beam_width: float = 14.0 + 6.0 * sin(float(Time.get_ticks_msec()) * 0.030)
	canvas.draw_line(start, current, Color(0.12, 0.58, 1.0, 0.35), beam_width + 8.0, true)
	canvas.draw_line(start, current, Color(0.32, 0.88, 1.0, 0.76), beam_width, true)
	canvas.draw_line(start, current, Color(0.88, 1.0, 1.0, 0.86), 4.0, true)
	canvas.draw_circle(current, 17.0 + progress * 8.0, Color(0.54, 0.94, 1.0, 0.42))


func draw_splash(
	canvas: CanvasItem,
	splash: Dictionary,
	shake_offset: Vector2,
	debris_renderer: Object,
	rock_visual_assets: Dictionary,
	water_splash_life_sec: float = DEFAULT_WATER_SPLASH_LIFE_SEC
) -> void:
	var life: float = clamp(float(splash.get("life", 0.0)), 0.0, float(splash.get("max_life", water_splash_life_sec)))
	if life <= 0.0:
		return
	var fade: float = life / max(0.001, float(splash.get("max_life", water_splash_life_sec)))
	var pos: Vector2 = _get_vector2(splash.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var radius: float = float(splash.get("radius", 4.0))
	if bool(splash.get("stone", false)):
		if _draw_stone_splash_sprite(canvas, splash, pos, radius, fade, debris_renderer, rock_visual_assets):
			if bool(splash.get("can_hit_player", false)):
				canvas.draw_arc(pos, radius * 1.9, 0.0, TAU, 18, Color(1.0, 0.34, 0.08, 0.50 * fade), 1.5)
			return
		_draw_stone_splash_fallback(canvas, splash, pos, radius, fade)
		return
	canvas.draw_circle(pos, radius * (0.72 + fade * 0.45), Color(0.42, 0.88, 1.0, 0.54 * fade))
	canvas.draw_circle(pos + Vector2(-radius * 0.22, -radius * 0.22), radius * 0.34, Color(0.90, 1.0, 1.0, 0.48 * fade))


func _draw_stone_splash_sprite(
	canvas: CanvasItem,
	splash: Dictionary,
	pos: Vector2,
	radius: float,
	fade: float,
	debris_renderer: Object,
	rock_visual_assets: Dictionary
) -> bool:
	if debris_renderer == null or not debris_renderer.has_method("draw_imagegen_debris_sprite"):
		return false
	return bool(debris_renderer.draw_imagegen_debris_sprite(canvas, {
		"sprite_index": int(splash.get("sprite_index", -1)),
		"rotation": float(splash.get("rot", 0.0)),
	}, pos, radius, fade, rock_visual_assets))


func _draw_stone_splash_fallback(canvas: CanvasItem, splash: Dictionary, pos: Vector2, radius: float, fade: float) -> void:
	var angle: float = float(splash.get("rot", 0.0))
	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	if bool(splash.get("can_hit_player", false)):
		canvas.draw_circle(pos, radius * 2.45, Color(1.0, 0.18, 0.04, 0.16 * fade))
	var points := PackedVector2Array([
		pos + forward * radius * 1.5,
		pos + side * radius,
		pos - forward * radius * 1.2,
		pos - side * radius * 0.8,
	])
	canvas.draw_colored_polygon(points, Color(0.22, 0.23, 0.17, 0.90 * fade))
	if bool(splash.get("can_hit_player", false)):
		canvas.draw_arc(pos, radius * 1.9, 0.0, TAU, 18, Color(1.0, 0.34, 0.08, 0.50 * fade), 1.5)


func _draw_corner_brackets(
	canvas: CanvasItem,
	center: Vector2,
	half_size: float,
	length: float,
	color: Color,
	width: float
) -> void:
	var left: float = center.x - half_size
	var right: float = center.x + half_size
	var top: float = center.y - half_size
	var bottom: float = center.y + half_size
	canvas.draw_line(Vector2(left, top), Vector2(left + length, top), color, width)
	canvas.draw_line(Vector2(left, top), Vector2(left, top + length), color, width)
	canvas.draw_line(Vector2(right, top), Vector2(right - length, top), color, width)
	canvas.draw_line(Vector2(right, top), Vector2(right, top + length), color, width)
	canvas.draw_line(Vector2(left, bottom), Vector2(left + length, bottom), color, width)
	canvas.draw_line(Vector2(left, bottom), Vector2(left, bottom - length), color, width)
	canvas.draw_line(Vector2(right, bottom), Vector2(right - length, bottom), color, width)
	canvas.draw_line(Vector2(right, bottom), Vector2(right, bottom - length), color, width)


func _get_rock_target_pos(rock: Dictionary) -> Vector2:
	var fallback: Vector2 = _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)
	return _get_vector2(rock.get("target_pos", fallback), fallback)


func _get_rock_center(rock: Dictionary) -> Vector2:
	if rock.has("fall_y"):
		var target_pos: Vector2 = _get_rock_target_pos(rock)
		var y: float = float(rock.get("fall_y", target_pos.y)) if bool(rock.get("falling", false)) else target_pos.y
		return Vector2(target_pos.x, y) + _get_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)
	var pos: Vector2 = _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)
	return pos + _get_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
