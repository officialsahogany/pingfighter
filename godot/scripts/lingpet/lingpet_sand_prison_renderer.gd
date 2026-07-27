extends RefCounted

const CHU_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const WALL_ALPHA_CAP := 200.0 / 255.0
const WALL_GRAIN_STEP := 3
const WALL_GRAIN_WIDTH := 6.0
const WALL_SURFACE_WIDTH := 8.0
const WALL_GLOW_WIDTH := 24.0
const WALL_GLOW_MAX_HEIGHT := 30.0
const DECOR_BAR_HEIGHT := 5.0
const TOP_BAR_REVEAL_RATIO := 0.9
const CORNER_REVEAL_RATIO := 0.8
const CORNER_RADIUS := 6.0
const MISS_TEXT := "MISS"
const MISS_FONT_SIZE := 32
const BODY_COLOR_BRIGHT := Color(0.902, 0.784, 0.431, 1.0)
const BODY_COLOR_DARK := Color(0.784, 0.686, 0.353, 1.0)


func prewarm() -> void:
	pass


func draw_sand_prison(
	canvas: CanvasItem,
	shake_offset: Vector2,
	active: bool,
	creating: bool,
	dissolving: bool,
	missing: bool,
	retry_wait: bool,
	phase_timer: float,
	anim_time: float,
	creation_seconds: float,
	dissolve_seconds: float,
	miss_seconds: float,
	cage_left: float,
	cage_right: float,
	cage_top: float,
	cage_bottom: float,
	wash_dir: float,
	sand_particles: Array[Dictionary],
	body_particles: Array[Dictionary]
) -> void:
	if canvas == null:
		return
	_draw_sand_particles(canvas, sand_particles, shake_offset)
	if not active:
		return
	_draw_cage(
		canvas,
		shake_offset,
		creating,
		dissolving,
		missing,
		retry_wait,
		phase_timer,
		anim_time,
		creation_seconds,
		dissolve_seconds,
		miss_seconds,
		cage_left,
		cage_right,
		cage_top,
		cage_bottom,
		wash_dir
	)
	_draw_body_particles(canvas, body_particles, shake_offset)
	if missing:
		_draw_miss_text(canvas, shake_offset, phase_timer, miss_seconds, cage_left, cage_right, cage_top, cage_bottom)


func get_visual_tuning_for_tests() -> Dictionary:
	return {
		"wall_alpha_cap": WALL_ALPHA_CAP,
		"wall_grain_step": WALL_GRAIN_STEP,
		"wall_grain_width": WALL_GRAIN_WIDTH,
		"wall_surface_width": WALL_SURFACE_WIDTH,
		"wall_glow_width": WALL_GLOW_WIDTH,
		"decor_bar_height": DECOR_BAR_HEIGHT,
		"top_bar_reveal_ratio": TOP_BAR_REVEAL_RATIO,
		"corner_reveal_ratio": CORNER_REVEAL_RATIO,
		"corner_radius": CORNER_RADIUS,
		"floor_alpha_cap": 22.0 / 255.0,
	}


func get_grain_projection_for_tests(anim_time: float, wall_index: int, y: int, alpha: float) -> Dictionary:
	var frame_seed := int(floor(maxf(0.0, anim_time) * 18.0))
	var seed := frame_seed * 131 + wall_index * 997 + y * 17
	return {
		"seed": seed,
		"segment_height": 2.0 + _grain_unit(seed + 4) * 2.0,
		"color": _grain_color(seed, alpha),
	}


func _draw_cage(
	canvas: CanvasItem,
	shake_offset: Vector2,
	creating: bool,
	dissolving: bool,
	missing: bool,
	retry_wait: bool,
	phase_timer: float,
	anim_time: float,
	creation_seconds: float,
	dissolve_seconds: float,
	miss_seconds: float,
	cage_left: float,
	cage_right: float,
	cage_top: float,
	cage_bottom: float,
	wash_dir: float
) -> void:
	var alpha := WALL_ALPHA_CAP
	var visible_ratio := 1.0
	var wash_progress := 0.0
	if creating:
		var create_progress := clampf(phase_timer / maxf(0.01, creation_seconds), 0.0, 1.0)
		visible_ratio = 1.0 - pow(1.0 - create_progress, 2.5)
		alpha = WALL_ALPHA_CAP * visible_ratio
	elif dissolving:
		var dissolve_progress := clampf(phase_timer / maxf(0.01, dissolve_seconds), 0.0, 1.0)
		visible_ratio = maxf(0.0, 1.0 - dissolve_progress * dissolve_progress)
		alpha = WALL_ALPHA_CAP * visible_ratio
	elif missing:
		wash_progress = clampf(phase_timer / maxf(0.01, miss_seconds), 0.0, 1.0)
		visible_ratio = 1.0
		alpha = WALL_ALPHA_CAP * (1.0 - 0.4 * wash_progress)
	elif retry_wait:
		return
	var top := lerpf(cage_bottom, cage_top, visible_ratio)
	var draw_height := cage_bottom - top
	if draw_height < 2.0 or alpha <= 0.02:
		return
	var floor_alpha := (22.0 / 255.0) * clampf(visible_ratio, 0.0, 1.0) * (1.0 - wash_progress)
	canvas.draw_rect(Rect2(Vector2(cage_left, top) + shake_offset, Vector2(cage_right - cage_left, draw_height)), Color(0.824, 0.706, 0.392, floor_alpha), true)
	for wall_index in range(2):
		var wall_x := cage_left if wall_index == 0 else cage_right
		_draw_wall_grain(canvas, wall_x, top, draw_height, alpha, wall_index, shake_offset, anim_time, wash_progress, wash_dir)
		_draw_wall_glow(canvas, wall_x, top, draw_height, alpha * clampf(1.0 - wash_progress * 2.0, 0.0, 1.0), shake_offset)
	if draw_height > DECOR_BAR_HEIGHT:
		if visible_ratio > TOP_BAR_REVEAL_RATIO:
			_draw_grain_bar(canvas, top, alpha, 11, shake_offset, anim_time, cage_left, cage_right, wash_progress, wash_dir)
		_draw_grain_bar(canvas, cage_bottom - DECOR_BAR_HEIGHT, alpha, 29, shake_offset, anim_time, cage_left, cage_right, wash_progress, wash_dir)
	if visible_ratio > CORNER_REVEAL_RATIO:
		var corner_fade := clampf((visible_ratio - CORNER_REVEAL_RATIO) / (1.0 - CORNER_REVEAL_RATIO), 0.0, 1.0)
		var corner_alpha := alpha * 0.7 * corner_fade * clampf(1.0 - wash_progress * 2.5, 0.0, 1.0)
		if corner_alpha > 0.01:
			var corner_color := Color(0.784, 0.667, 0.353, corner_alpha)
			for corner_x in [cage_left, cage_right]:
				for corner_y in [top, cage_bottom]:
					canvas.draw_circle(Vector2(corner_x, corner_y) + shake_offset, CORNER_RADIUS, corner_color)


func _draw_wall_grain(
	canvas: CanvasItem,
	wall_x: float,
	top: float,
	draw_height: float,
	alpha: float,
	wall_index: int,
	shake_offset: Vector2,
	anim_time: float,
	wash_progress: float,
	wash_dir: float
) -> void:
	var draw_height_int := int(ceil(draw_height))
	var surface_x := wall_x - WALL_SURFACE_WIDTH * 0.5
	var grain_x := surface_x + (WALL_SURFACE_WIDTH - WALL_GRAIN_WIDTH) * 0.5
	var frame_seed := int(floor(anim_time * 18.0))
	for y in range(0, draw_height_int, WALL_GRAIN_STEP):
		var seed := frame_seed * 131 + wall_index * 997 + y * 17
		var y_value := float(y)
		var segment_height := minf(draw_height - y_value, 2.0 + _grain_unit(seed + 4) * 2.0)
		if segment_height <= 0.0:
			continue
		var grain_alpha := alpha
		var wash_offset := Vector2.ZERO
		if wash_progress > 0.0:
			var wash_seed := wall_index * 997 + y * 17
			var vanish := clampf((wash_progress * 1.25 - _grain_unit(wash_seed + 8)) / 0.25, 0.0, 1.0)
			if vanish >= 1.0:
				continue
			grain_alpha = alpha * (1.0 - vanish)
			wash_offset = Vector2(wash_dir * (26.0 + 60.0 * _grain_unit(wash_seed + 9)), 12.0 + 22.0 * _grain_unit(wash_seed + 10)) * vanish
		canvas.draw_rect(Rect2(Vector2(grain_x, top + y_value) + wash_offset + shake_offset, Vector2(WALL_GRAIN_WIDTH, segment_height)), _grain_color(seed, grain_alpha), true)


func _draw_wall_glow(canvas: CanvasItem, wall_x: float, top: float, draw_height: float, alpha: float, shake_offset: Vector2) -> void:
	if draw_height <= 20.0:
		return
	var glow_height := minf(WALL_GLOW_MAX_HEIGHT, draw_height - 5.0)
	var glow_top := top + draw_height * 0.5 - glow_height * 0.5
	var glow_lines := int(ceil(glow_height))
	for glow_index in range(glow_lines):
		var ratio := float(glow_index) / maxf(1.0, float(glow_lines))
		var glow_alpha := alpha * 0.3 * (1.0 - ratio)
		var y := glow_top + float(glow_index)
		canvas.draw_line(
			Vector2(wall_x - WALL_GLOW_WIDTH * 0.5, y) + shake_offset,
			Vector2(wall_x + WALL_GLOW_WIDTH * 0.5, y) + shake_offset,
			Color(0.863, 0.745, 0.471, glow_alpha),
			1.0
		)


func _draw_grain_bar(
	canvas: CanvasItem,
	bar_y: float,
	alpha: float,
	bar_seed: int,
	shake_offset: Vector2,
	anim_time: float,
	cage_left: float,
	cage_right: float,
	wash_progress: float,
	wash_dir: float
) -> void:
	var bar_width := (cage_right - cage_left) + 8.0
	var bar_width_int := int(ceil(bar_width))
	var start_x := cage_left - 4.0
	var frame_seed := int(floor(anim_time * 18.0))
	for x in range(0, bar_width_int, WALL_GRAIN_STEP):
		var segment_width := minf(float(WALL_GRAIN_STEP), bar_width - float(x))
		if segment_width <= 0.0:
			continue
		var seed := frame_seed * 149 + bar_seed * 577 + x * 19
		var grain_alpha := alpha
		var wash_offset := Vector2.ZERO
		if wash_progress > 0.0:
			var wash_seed := bar_seed * 577 + x * 19
			var vanish := clampf((wash_progress * 1.25 - _grain_unit(wash_seed + 8)) / 0.25, 0.0, 1.0)
			if vanish >= 1.0:
				continue
			grain_alpha = alpha * (1.0 - vanish)
			wash_offset = Vector2(wash_dir * (26.0 + 60.0 * _grain_unit(wash_seed + 9)), 12.0 + 22.0 * _grain_unit(wash_seed + 10)) * vanish
		canvas.draw_rect(Rect2(Vector2(start_x + float(x), bar_y) + wash_offset + shake_offset, Vector2(segment_width, DECOR_BAR_HEIGHT)), _grain_color(seed, grain_alpha), true)


func _grain_color(seed: int, alpha: float) -> Color:
	var red := lerpf(185.0, 220.0, _grain_unit(seed + 1)) / 255.0
	var green := lerpf(155.0, 180.0, _grain_unit(seed + 2)) / 255.0
	var blue := lerpf(80.0, 110.0, _grain_unit(seed + 3)) / 255.0
	return Color(red, green, blue, alpha)


func _grain_unit(seed: int) -> float:
	var raw := sin(float(seed) * 12.9898 + 78.233) * 43758.5453
	return raw - floor(raw)


func _draw_sand_particles(canvas: CanvasItem, sand_particles: Array[Dictionary], shake_offset: Vector2) -> void:
	for particle in sand_particles:
		var pos := _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var life := float(particle.get("life", 0.0))
		var max_life := maxf(0.01, float(particle.get("max_life", 1.0)))
		var alpha := clampf(life / max_life, 0.0, 1.0)
		var color: Color = particle.get("color", Color(0.86, 0.64, 0.33, 1.0))
		color.a *= alpha
		canvas.draw_circle(pos, float(particle.get("radius", 2.0)) * (0.65 + 0.35 * alpha), color)


func _draw_body_particles(canvas: CanvasItem, body_particles: Array[Dictionary], shake_offset: Vector2) -> void:
	for particle in body_particles:
		var max_life := maxf(0.01, float(particle.get("max_life", 1.0)))
		var life := float(particle.get("life", 0.0))
		var progress := clampf(1.0 - life / max_life, 0.0, 1.0)
		var envelope := 1.0
		if progress < 0.2:
			envelope = progress / 0.2
		elif progress > 0.75:
			envelope = (1.0 - progress) / 0.25
		var alpha := clampf(float(particle.get("init_alpha", 0.8)) * envelope, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var base_size := float(particle.get("size", 2.0))
		var size := base_size
		if progress > 0.8:
			size = base_size * lerpf(1.0, 0.5, clampf((progress - 0.8) / 0.2, 0.0, 1.0))
		var color := BODY_COLOR_BRIGHT.lerp(BODY_COLOR_DARK, progress)
		color.a = alpha
		var pos := _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		canvas.draw_circle(pos, maxf(0.5, size), color)
		if base_size > 1.0 and progress < 0.8:
			var velocity := _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
			if velocity.length() > 1.0:
				var tail_color := color
				tail_color.a = alpha / 3.0
				canvas.draw_circle(pos - velocity.normalized() * size * 1.5, maxf(0.5, size - 1.0), tail_color)


func _draw_miss_text(
	canvas: CanvasItem,
	shake_offset: Vector2,
	phase_timer: float,
	miss_seconds: float,
	cage_left: float,
	cage_right: float,
	cage_top: float,
	cage_bottom: float
) -> void:
	var fade := 1.0 - clampf(phase_timer / maxf(0.01, miss_seconds), 0.0, 1.0)
	var cage_center := (cage_left + cage_right) * 0.5
	var cage_mid_y := (cage_top + cage_bottom) * 0.5
	var pos := Vector2(cage_center - 38.0, cage_mid_y - 12.0 - (1.0 - fade) * 18.0) + shake_offset
	canvas.draw_string(CHU_FONT, pos + Vector2(2.0, 2.0), MISS_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, MISS_FONT_SIZE, Color(0.0, 0.0, 0.0, 0.65 * fade))
	canvas.draw_string(CHU_FONT, pos, MISS_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, MISS_FONT_SIZE, Color(1.0, 0.88, 0.52, 0.95 * fade))


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
