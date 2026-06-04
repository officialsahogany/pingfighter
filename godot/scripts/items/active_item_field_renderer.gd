extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemFieldItemMotion := preload("res://scripts/items/active_item_field_item_motion.gd")

const UNKNOWN_ITEM_SHEET_PATH := "res://assets/sprites/items/unknown_item_hq_sprite_sheet.png"
const UNKNOWN_ITEM_FALLBACK_PATH := "res://assets/sprites/items/unknown_item_hq_sprite.png"
const UNKNOWN_ITEM_FRAME_MSEC := 140
const ITEM_SPAWN_PORTAL_SHEET_PATH := "res://assets/sprites/effects/item_spawn_portal_sheet_imagegen_v2_64f.png"
const FIELD_ITEM_DRAW_SIZE := 60.0
const SPAWN_SPARK_DURATION_SEC := 1.0
const ITEM_SPAWN_PORTAL_FRAME_COUNT := 64
const ITEM_SPAWN_PORTAL_SHEET_ROWS := 8
const ITEM_SPAWN_PORTAL_SHEET_COLS := 8
const ITEM_SPAWN_PORTAL_RELEASE_FRAME := 28
const ITEM_SPAWN_PORTAL_DURATION_MSEC := 1000
const ITEM_SPAWN_PORTAL_DRAW_SIZE := 104.0
const SUSTAINED_OPEN_FRAME_INDEX := ITEM_SPAWN_PORTAL_RELEASE_FRAME
const SUSTAINED_OPENING_DURATION_MSEC := 438
const SUSTAINED_CLOSING_DURATION_MSEC := 500
const ITEM_SPAWN_PORTAL_RENDER_LIMIT := 4
const FIELD_ITEM_SPAWN_SPARK_RENDER_LIMIT := 3
const SPAWN_SPARK_RAY_COUNT := 4
const SPAWN_SPARK_SEGMENT_COUNT := 2
const DIMENSION_GATE_ARC_POINT_COUNT := 14
const DIMENSION_GATE_RING_RENDER_LIMIT := 3
const LUCKY_COIN_BONUS_SPARK_COUNT := 3
const FIELD_ITEM_DETAIL_LOD_THRESHOLD := 12
const FIELD_ITEM_DECORATIVE_GLOW_RENDER_LIMIT := 12
const FIELD_ITEM_LUCKY_GLOW_RENDER_LIMIT := 4
const FIELD_ITEM_BREAK_EFFECT_RENDER_LIMIT := 6
const MILK_BOTTLE_BREAK_GRAVITY := 260.0
const MILK_BOTTLE_BREAK_ARC_POINT_COUNT := 24
const DIMENSION_GATE_RAINBOW_COLORS := [
	Color(1.0, 0.0, 0.0),
	Color(1.0, 127.0 / 255.0, 0.0),
	Color(1.0, 1.0, 0.0),
	Color(0.0, 1.0, 0.0),
	Color(0.0, 0.0, 1.0),
	Color(75.0 / 255.0, 0.0, 130.0 / 255.0),
	Color(148.0 / 255.0, 0.0, 211.0 / 255.0),
]

var portal_sheet_texture: Texture2D
var unknown_item_sheet_texture: Texture2D
var unknown_item_fallback_texture: Texture2D
var field_icon_textures: Dictionary = {}
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	match _prewarm_step_index:
		0:
			_touch_texture(_get_portal_sheet_texture())
		1:
			_touch_texture(_get_unknown_item_sheet_texture())
		2:
			_touch_texture(_get_unknown_item_fallback_texture())
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func draw(
	canvas: CanvasItem,
	portals: Array,
	field_items: Array,
	shake_offset: Vector2 = Vector2.ZERO,
	perf_logger: Object = null
) -> void:
	if canvas == null:
		return

	var now_msec: int = Time.get_ticks_msec()
	var remaining_spawn_sparks := FIELD_ITEM_SPAWN_SPARK_RENDER_LIMIT
	var detail_perf_logger: Object = perf_logger if _should_sample_detail(perf_logger, "active_item.field_items") else null
	var sample_start: int = _perf_begin(detail_perf_logger)
	_draw_item_spawn_portals(canvas, portals, shake_offset, now_msec)
	_perf_end(detail_perf_logger, "active_item.field_items.portals", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	var field_item_count: int = field_items.size()
	var decorative_glow_start: int = _recent_start(field_items, FIELD_ITEM_DECORATIVE_GLOW_RENDER_LIMIT) if field_item_count > FIELD_ITEM_DETAIL_LOD_THRESHOLD else 0
	var lucky_glow_remaining := FIELD_ITEM_LUCKY_GLOW_RENDER_LIMIT
	var item_index := -1
	for item_value in field_items:
		item_index += 1
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value
		if remaining_spawn_sparks > 0 and float(item.get("spawn_spark_timer", 0.0)) > 0.0:
			var spark_start: int = _perf_begin(detail_perf_logger)
			_draw_spawn_electric_spark(canvas, item, shake_offset, now_msec)
			_perf_end(detail_perf_logger, "active_item.field_items.spawn_sparks", spark_start)
			remaining_spawn_sparks -= 1
		var draw_decorative_glow: bool = item_index >= decorative_glow_start
		var draw_lucky_glow: bool = draw_decorative_glow and lucky_glow_remaining > 0
		_draw_field_item(canvas, item, shake_offset, now_msec, draw_decorative_glow, draw_lucky_glow)
		if draw_lucky_glow and bool(item.get("lucky_bonus", false)):
			lucky_glow_remaining -= 1
	_perf_end(detail_perf_logger, "active_item.field_items.items", sample_start)


func draw_field_item_break_effects(
	canvas: CanvasItem,
	break_effects: Array,
	shake_offset: Vector2 = Vector2.ZERO,
	perf_logger: Object = null
) -> void:
	if canvas == null or break_effects.is_empty():
		return
	var detail_perf_logger: Object = perf_logger if _should_sample_detail(perf_logger, "active_item.field_items.break") else null
	var sample_start: int = _perf_begin(detail_perf_logger)
	var start_index: int = _recent_start(break_effects, FIELD_ITEM_BREAK_EFFECT_RENDER_LIMIT)
	for effect_index in range(start_index, break_effects.size()):
		var effect_value: Variant = break_effects[effect_index]
		if effect_value is Dictionary:
			_draw_field_item_break_effect(canvas, effect_value, shake_offset)
	_perf_end(detail_perf_logger, "active_item.field_items.break_effects", sample_start)


func _draw_field_item(
	canvas: CanvasItem,
	field_item: Dictionary,
	shake_offset: Vector2,
	now_msec: int,
	draw_decorative_glow: bool = true,
	draw_lucky_glow: bool = true
) -> void:
	var center: Vector2 = _get_vector2(field_item, "position", Vector2.ZERO) + shake_offset
	var item_data: Dictionary = _get_dictionary(field_item, "item_data")
	var item_color: Color = _get_item_color(item_data)
	var t: float = float(now_msec) / 1000.0
	if draw_decorative_glow:
		var pulse: float = 0.5 + 0.5 * sin(t * 5.2)
		var glow_radius: float = FIELD_ITEM_DRAW_SIZE * (0.38 + pulse * 0.05)
		canvas.draw_circle(center, glow_radius, Color(item_color.r, item_color.g, item_color.b, 0.20))
	if draw_lucky_glow and bool(field_item.get("lucky_bonus", false)):
		_draw_lucky_coin_bonus_glow(canvas, center, t)
	canvas.draw_circle(center, FIELD_ITEM_DRAW_SIZE * 0.31, Color(0.08, 0.10, 0.18, 0.48))
	if _draw_field_icon_texture(canvas, item_data, center, now_msec):
		return
	_draw_unknown_item_icon(canvas, center, float(field_item.get("angle_degrees", 0.0)), now_msec)


func _draw_field_item_break_effect(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var age: float = max(0.0, float(effect.get("age", 0.0)))
	var duration: float = max(0.001, float(effect.get("duration", 0.56)))
	var progress: float = clamp(age / duration, 0.0, 1.0)
	var fade: float = pow(1.0 - progress, 0.72)
	if fade <= 0.01:
		return
	var center: Vector2 = _clamp_break_effect_center(_get_vector2(effect, "position", Vector2.ZERO)) + shake_offset
	_draw_milk_bottle_break_splash(canvas, center, progress, fade)
	_draw_milk_bottle_break_droplets(canvas, effect, center, age, fade)
	_draw_milk_bottle_break_shards(canvas, effect, center, age, fade)


func _draw_milk_bottle_break_splash(canvas: CanvasItem, center: Vector2, progress: float, fade: float) -> void:
	var ring_radius: float = 14.0 + 32.0 * progress
	canvas.draw_arc(
		center,
		ring_radius,
		-PI * 0.08,
		PI * 1.08,
		MILK_BOTTLE_BREAK_ARC_POINT_COUNT,
		Color(0.72, 0.96, 1.0, 0.58 * fade),
		2.5
	)
	canvas.draw_arc(
		center + Vector2(0.0, 4.0),
		10.0 + 24.0 * progress,
		PI * 0.12,
		PI * 0.88,
		18,
		Color(1.0, 1.0, 0.92, 0.56 * fade),
		2.0
	)
	var puddle_center: Vector2 = center + Vector2(0.0, 13.0 + 4.0 * progress)
	canvas.draw_circle(puddle_center + Vector2(-7.0, 0.0), 9.0 + 7.0 * progress, Color(0.94, 1.0, 0.93, 0.32 * fade))
	canvas.draw_circle(puddle_center + Vector2(8.0, 1.0), 7.0 + 5.0 * progress, Color(0.82, 0.96, 1.0, 0.24 * fade))
	canvas.draw_circle(center, 11.0 * (1.0 - progress * 0.25), Color(1.0, 1.0, 1.0, 0.20 * fade))


func _draw_milk_bottle_break_droplets(canvas: CanvasItem, effect: Dictionary, center: Vector2, age: float, fade: float) -> void:
	var droplets: Array = _get_array(effect, "droplets")
	for droplet_value in droplets:
		if not (droplet_value is Dictionary):
			continue
		var droplet: Dictionary = droplet_value
		var velocity: Vector2 = _get_vector2(droplet, "velocity", Vector2.ZERO)
		var pos: Vector2 = center + velocity * age + Vector2(0.0, MILK_BOTTLE_BREAK_GRAVITY * 0.38 * age * age)
		pos = _clamp_break_effect_point(pos, 4.0)
		var radius: float = max(0.5, float(droplet.get("radius", 2.5)) * (0.75 + 0.25 * fade))
		canvas.draw_circle(pos, radius, Color(0.94, 1.0, 0.94, 0.70 * fade))
		canvas.draw_circle(pos + Vector2(-radius * 0.25, -radius * 0.25), max(0.5, radius * 0.38), Color(1.0, 1.0, 1.0, 0.58 * fade))


func _draw_milk_bottle_break_shards(canvas: CanvasItem, effect: Dictionary, center: Vector2, age: float, fade: float) -> void:
	var shards: Array = _get_array(effect, "shards")
	for shard_value in shards:
		if not (shard_value is Dictionary):
			continue
		var shard: Dictionary = shard_value
		var velocity: Vector2 = _get_vector2(shard, "velocity", Vector2.ZERO)
		var pos: Vector2 = center + velocity * age + Vector2(0.0, MILK_BOTTLE_BREAK_GRAVITY * age * age)
		pos = _clamp_break_effect_point(pos, 5.0)
		var size: float = max(1.0, float(shard.get("size", 4.0)) * (0.9 + 0.18 * sin(age * 18.0 + float(shard.get("spin", 0.0)))))
		var angle: float = float(shard.get("spin", 0.0)) * age
		var dir := Vector2(cos(angle), sin(angle))
		var side := Vector2(-dir.y, dir.x)
		var points := PackedVector2Array([
			pos + dir * size * 1.25,
			pos - dir * size * 0.75 + side * size * 0.54,
			pos - dir * size * 0.42 - side * size * 0.62,
		])
		var color: Color = _get_break_shard_color(int(shard.get("tint", 0)), fade)
		canvas.draw_colored_polygon(points, color)


func _get_break_shard_color(tint: int, fade: float) -> Color:
	match tint:
		1:
			return Color(0.70, 0.96, 1.0, 0.62 * fade)
		2:
			return Color(0.90, 1.0, 1.0, 0.72 * fade)
		_:
			return Color(1.0, 1.0, 1.0, 0.66 * fade)


func _draw_field_icon_texture(canvas: CanvasItem, item_data: Dictionary, center: Vector2, _now_msec: int) -> bool:
	var field_icon_path: String = str(item_data.get("field_icon_path", "")).strip_edges()
	if field_icon_path == "":
		return false
	var texture: Texture2D = _get_field_icon_texture(field_icon_path)
	if texture == null:
		return false
	var icon_size := Vector2(FIELD_ITEM_DRAW_SIZE, FIELD_ITEM_DRAW_SIZE)
	_draw_rotated_texture_region(canvas, texture, Rect2(Vector2.ZERO, texture.get_size()), center, icon_size, 0.0)
	return true


func _draw_unknown_item_icon(canvas: CanvasItem, center: Vector2, angle_degrees: float, now_msec: int) -> void:
	var icon_size := Vector2(FIELD_ITEM_DRAW_SIZE, FIELD_ITEM_DRAW_SIZE)
	var sheet: Texture2D = _get_unknown_item_sheet_texture()
	if sheet != null:
		var sheet_size: Vector2 = sheet.get_size()
		var frame_size: float = sheet_size.y
		var frame_count: int = int(floor(sheet_size.x / frame_size)) if frame_size > 0.0 else 0
		if frame_count > 0:
			var frame_index: int = int(floor(float(now_msec) / float(UNKNOWN_ITEM_FRAME_MSEC))) % frame_count
			var source_rect := Rect2(float(frame_index) * frame_size, 0.0, frame_size, frame_size)
			_draw_rotated_texture_region(canvas, sheet, source_rect, center, icon_size, angle_degrees)
			return

	var fallback: Texture2D = _get_unknown_item_fallback_texture()
	if fallback != null:
		_draw_rotated_texture_region(canvas, fallback, Rect2(Vector2.ZERO, fallback.get_size()), center, icon_size, angle_degrees)
		return

	canvas.draw_circle(center, FIELD_ITEM_DRAW_SIZE * 0.33, Color(0.84, 0.68, 1.0, 0.96))
	canvas.draw_circle(center + Vector2(-8.0, -9.0), 6.0, Color(1.0, 1.0, 1.0, 0.30))


func _draw_lucky_coin_bonus_glow(canvas: CanvasItem, center: Vector2, t: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * 7.0)
	canvas.draw_circle(center, FIELD_ITEM_DRAW_SIZE * (0.48 + 0.06 * pulse), Color(1.0, 0.78, 0.14, 0.26))
	canvas.draw_circle(center, FIELD_ITEM_DRAW_SIZE * (0.40 + 0.04 * pulse), Color(1.0, 0.95, 0.35, 0.18))
	for i in range(LUCKY_COIN_BONUS_SPARK_COUNT):
		var angle: float = t * 2.4 + float(i) * TAU / float(LUCKY_COIN_BONUS_SPARK_COUNT)
		var spark_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * FIELD_ITEM_DRAW_SIZE * (0.43 + 0.05 * pulse)
		canvas.draw_circle(spark_pos, 2.0 + pulse * 1.2, Color(1.0, 0.92, 0.36, 0.72))


func _draw_item_spawn_portals(canvas: CanvasItem, portals: Array, shake_offset: Vector2, now_msec: int) -> void:
	if portals.is_empty():
		return
	var sheet: Texture2D = _get_portal_sheet_texture()
	for portal_index in range(_recent_start(portals, ITEM_SPAWN_PORTAL_RENDER_LIMIT), portals.size()):
		var portal_value: Variant = portals[portal_index]
		if not (portal_value is Dictionary):
			continue
		var portal: Dictionary = portal_value
		var start_msec: int = int(portal.get("start_msec", now_msec))
		var duration_msec: int = max(1, int(portal.get("duration_msec", ITEM_SPAWN_PORTAL_DURATION_MSEC)))
		var elapsed_msec: int = max(0, now_msec - start_msec)
		if bool(portal.get("dimension_gate", false)):
			_draw_dimension_gate_rainbow_effect(canvas, portal, now_msec, shake_offset)
		if sheet != null:
			_draw_item_spawn_portal_sprite(canvas, sheet, portal, now_msec, elapsed_msec, duration_msec, shake_offset)
		else:
			_draw_item_spawn_portal_fallback(canvas, portal, now_msec, elapsed_msec, duration_msec, shake_offset)


func _draw_item_spawn_portal_sprite(
	canvas: CanvasItem,
	sheet: Texture2D,
	portal: Dictionary,
	now_msec: int,
	elapsed_msec: int,
	duration_msec: int,
	shake_offset: Vector2
) -> void:
	var sheet_size: Vector2 = sheet.get_size()
	var frame_w: float = sheet_size.x / float(ITEM_SPAWN_PORTAL_SHEET_COLS)
	var frame_h: float = sheet_size.y / float(ITEM_SPAWN_PORTAL_SHEET_ROWS)
	if frame_w <= 0.0 or frame_h <= 0.0:
		return

	var frame_position: float = _get_portal_frame_position(portal, now_msec, elapsed_msec, duration_msec)
	var frame_index: int = min(ITEM_SPAWN_PORTAL_FRAME_COUNT - 1, int(frame_position))
	var col: int = frame_index % ITEM_SPAWN_PORTAL_SHEET_COLS
	var row: int = int(floor(float(frame_index) / float(ITEM_SPAWN_PORTAL_SHEET_COLS)))
	var source_rect := Rect2(float(col) * frame_w, float(row) * frame_h, frame_w, frame_h)
	var center: Vector2 = _get_vector2(portal, "position", Vector2.ZERO) + shake_offset
	var draw_extent: float = max(1.0, float(portal.get("draw_size", ITEM_SPAWN_PORTAL_DRAW_SIZE)))
	var draw_size: Vector2 = Vector2(draw_extent, draw_extent)
	var dest_rect := Rect2(center - draw_size * 0.5, draw_size)
	canvas.draw_texture_rect_region(sheet, dest_rect, source_rect)


func _draw_item_spawn_portal_fallback(
	canvas: CanvasItem,
	portal: Dictionary,
	now_msec: int,
	elapsed_msec: int,
	duration_msec: int,
	shake_offset: Vector2
) -> void:
	var center: Vector2 = _get_vector2(portal, "position", Vector2.ZERO) + shake_offset
	var open_factor: float = _portal_open_factor_for_portal(portal, now_msec, elapsed_msec, duration_msec)
	if bool(portal.get("sustained", false)):
		open_factor *= 0.94 + 0.06 * sin(float(now_msec) / 1000.0 * 7.0)
	if open_factor <= 0.001:
		return
	var draw_extent: float = max(ITEM_SPAWN_PORTAL_DRAW_SIZE, float(portal.get("draw_size", ITEM_SPAWN_PORTAL_DRAW_SIZE)))
	var rw: float = draw_extent * 0.21 * open_factor
	var rh: float = draw_extent * 0.35 * open_factor
	canvas.draw_circle(center, max(rw, rh) + 10.0, Color(180.0 / 255.0, 90.0 / 255.0, 1.0, 0.22))
	canvas.draw_circle(center, max(rw, rh), Color(28.0 / 255.0, 8.0 / 255.0, 56.0 / 255.0, 0.92))
	canvas.draw_arc(center, max(rw, rh), 0.0, TAU, 32, Color(1.0, 240.0 / 255.0, 1.0, 0.86), 2.0)


func _draw_dimension_gate_rainbow_effect(
	canvas: CanvasItem,
	portal: Dictionary,
	now_msec: int,
	shake_offset: Vector2
) -> void:
	var effect_end_msec: int = int(portal.get("effect_end_msec", now_msec))
	if now_msec > effect_end_msec:
		return
	var start_msec: int = int(portal.get("start_msec", now_msec))
	var animation_frame: float = max(0.0, float(now_msec - start_msec) * 0.06)
	var center: Vector2 = _get_vector2(portal, "position", Vector2.ZERO) + shake_offset
	var color_count: int = DIMENSION_GATE_RAINBOW_COLORS.size()
	var ring_count: int = min(DIMENSION_GATE_RING_RENDER_LIMIT, color_count)
	for ring_index in range(ring_count):
		var color_index: int = int(round(float(ring_index) * float(color_count - 1) / float(max(1, ring_count - 1))))
		var color: Color = DIMENSION_GATE_RAINBOW_COLORS[color_index]
		var angle: float = deg_to_rad(fmod(animation_frame * 3.0 + float(ring_index) * 360.0 / float(ring_count), 360.0))
		var pulse: float = sin(animation_frame * 0.1) * 10.0
		var radius: float = 50.0 + pulse + float(ring_index) * 9.5
		var alpha: float = (100.0 + 55.0 * sin(animation_frame * 0.05 + float(ring_index))) / 255.0
		var offset := Vector2(cos(angle), sin(angle)) * 20.0
		var ring_color := Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))
		canvas.draw_arc(center + offset, max(1.0, radius), 0.0, TAU, DIMENSION_GATE_ARC_POINT_COUNT, ring_color, 2.5)

	var glow_radius: float = 30.0 + sin(animation_frame * 0.15) * 10.0
	var glow_alpha: float = (150.0 + 50.0 * sin(animation_frame * 0.2)) / 255.0
	canvas.draw_circle(center, max(1.0, glow_radius), Color(1.0, 1.0, 1.0, clamp(glow_alpha, 0.0, 1.0)))


func _draw_spawn_electric_spark(canvas: CanvasItem, field_item: Dictionary, shake_offset: Vector2, now_msec: int) -> void:
	var remaining: float = float(field_item.get("spawn_spark_timer", 0.0))
	if remaining <= 0.0:
		return
	var progress: float = 1.0 - (remaining / SPAWN_SPARK_DURATION_SEC)
	var alpha_scale: float = pow(1.0 - clamp(progress, 0.0, 1.0), 0.65)
	var center: Vector2 = _get_vector2(field_item, "position", Vector2.ZERO) + shake_offset
	var now: float = float(now_msec) / 1000.0
	var ring_radius: float = 25.0 + 8.0 * sin(now * 35.0)
	canvas.draw_arc(center, max(18.0, ring_radius), 0.0, TAU, 34, Color(70.0 / 255.0, 210.0 / 255.0, 1.0, 0.34 * alpha_scale), 2.0)

	for i in range(SPAWN_SPARK_RAY_COUNT):
		var angle: float = now * 7.0 + float(i) * TAU / float(SPAWN_SPARK_RAY_COUNT) + sin(now * 3.0 + float(i)) * 0.18
		var inner: float = 16.0 + fmod(float(i) * 4.7, 11.0)
		var outer: float = 32.0 + fmod(float(i) * 6.1, 13.0)
		var prev: Vector2 = center + Vector2(cos(angle), sin(angle)) * inner
		for segment in range(1, SPAWN_SPARK_SEGMENT_COUNT + 1):
			var ratio: float = float(segment) / float(SPAWN_SPARK_SEGMENT_COUNT)
			var jitter: float = sin(now * 13.0 + float(i * 5 + segment)) * 0.22
			var point: Vector2 = center + Vector2(cos(angle + jitter), sin(angle + jitter)) * lerp(inner, outer, ratio)
			var spark_color: Color = Color(0.66, 0.86, 1.0, 0.72 * alpha_scale)
			if i % 3 == 0:
				spark_color = Color(0.92, 0.98, 1.0, 0.92 * alpha_scale)
			elif i % 3 == 1:
				spark_color = Color(0.68, 0.42, 1.0, 0.70 * alpha_scale)
			canvas.draw_line(prev, point, spark_color, 1.0 + float(i % 2))
			prev = point


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float
) -> void:
	var half_size: Vector2 = draw_size * 0.5
	var radians: float = deg_to_rad(angle_degrees)
	var cos_a: float = cos(radians)
	var sin_a: float = sin(radians)
	var offsets := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for offset in offsets:
		points.append(center + Vector2(
			offset.x * cos_a - offset.y * sin_a,
			offset.x * sin_a + offset.y * cos_a
		))

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	canvas.draw_polygon(points, colors, uvs, texture)


func _portal_open_factor(elapsed_msec: int, duration_msec: int) -> float:
	var t: float = float(elapsed_msec) / float(max(1, duration_msec))
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t < 0.40:
		var open_t: float = t / 0.40
		return 1.0 - pow(1.0 - open_t, 3.0)
	if t < 0.55:
		return 1.0
	var close_t: float = (t - 0.55) / 0.45
	return pow(1.0 - close_t, 2.0)


func _portal_open_factor_for_portal(portal: Dictionary, now_msec: int, elapsed_msec: int, duration_msec: int) -> float:
	if not bool(portal.get("sustained", false)):
		return _portal_open_factor(elapsed_msec, duration_msec)

	var phase: String = str(portal.get("phase", "holding"))
	var phase_start_msec: int = int(portal.get("phase_start_msec", portal.get("start_msec", now_msec)))
	var phase_elapsed_msec: int = max(0, now_msec - phase_start_msec)
	if phase == "opening":
		var open_t: float = clamp(float(phase_elapsed_msec) / float(SUSTAINED_OPENING_DURATION_MSEC), 0.0, 1.0)
		return 1.0 - pow(1.0 - open_t, 3.0)
	if phase == "closing":
		var close_t: float = clamp(float(phase_elapsed_msec) / float(SUSTAINED_CLOSING_DURATION_MSEC), 0.0, 1.0)
		return pow(1.0 - close_t, 2.0)
	return 1.0


func _get_portal_frame_position(portal: Dictionary, now_msec: int, elapsed_msec: int, duration_msec: int) -> float:
	if not bool(portal.get("sustained", false)):
		var progress: float = clamp(float(elapsed_msec) / float(duration_msec), 0.0, 0.999)
		return progress * float(ITEM_SPAWN_PORTAL_FRAME_COUNT)

	var phase: String = str(portal.get("phase", "holding"))
	var phase_start_msec: int = int(portal.get("phase_start_msec", portal.get("start_msec", now_msec)))
	var phase_elapsed_msec: int = max(0, now_msec - phase_start_msec)
	var per_frame_msec: float = float(duration_msec) / float(ITEM_SPAWN_PORTAL_FRAME_COUNT)
	if phase == "opening":
		return min(float(SUSTAINED_OPEN_FRAME_INDEX), float(phase_elapsed_msec) / per_frame_msec)
	if phase == "closing":
		var close_t: float = clamp(float(phase_elapsed_msec) / float(SUSTAINED_CLOSING_DURATION_MSEC), 0.0, 0.999)
		return lerp(float(SUSTAINED_OPEN_FRAME_INDEX), float(ITEM_SPAWN_PORTAL_FRAME_COUNT - 1), close_t)
	return float(SUSTAINED_OPEN_FRAME_INDEX)


func _get_portal_sheet_texture() -> Texture2D:
	if portal_sheet_texture == null:
		portal_sheet_texture = ProjectResourceLoader.load_texture(
			ITEM_SPAWN_PORTAL_SHEET_PATH,
			"Missing item spawn portal sheet at %s",
			"Failed to load item spawn portal sheet at %s"
		)
	return portal_sheet_texture


func _get_unknown_item_sheet_texture() -> Texture2D:
	if unknown_item_sheet_texture == null:
		unknown_item_sheet_texture = ProjectResourceLoader.load_texture(
			UNKNOWN_ITEM_SHEET_PATH,
			"Missing unknown item icon sheet at %s",
			"Failed to load unknown item icon sheet at %s"
		)
	return unknown_item_sheet_texture


func _get_unknown_item_fallback_texture() -> Texture2D:
	if unknown_item_fallback_texture == null:
		unknown_item_fallback_texture = ProjectResourceLoader.load_texture(
			UNKNOWN_ITEM_FALLBACK_PATH,
			"Missing unknown item fallback icon at %s",
			"Failed to load unknown item fallback icon at %s"
		)
	return unknown_item_fallback_texture


func _get_field_icon_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if field_icon_textures.has(path):
		var cached: Variant = field_icon_textures[path]
		if cached is Texture2D:
			return cached as Texture2D
		field_icon_textures.erase(path)
	var texture: Texture2D = ProjectResourceLoader.load_texture(
		path,
		"Missing active field item icon at %s",
		"Failed to load active field item icon at %s"
	)
	if texture != null:
		field_icon_textures[path] = texture
	return texture


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit <= 0:
		return source.size()
	return max(0, source.size() - render_limit)


func _get_item_color(item_data: Dictionary) -> Color:
	return _get_color(
		item_data.get("color", Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)),
		Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)
	)


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]) / 255.0, float(value[1]) / 255.0, float(value[2]) / 255.0, 1.0)
	return fallback


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _clamp_break_effect_center(center: Vector2) -> Vector2:
	const VISUAL_MARGIN := 34.0
	return Vector2(
		clamp(center.x, VISUAL_MARGIN, ActiveItemFieldItemMotion.FIELD_WIDTH - VISUAL_MARGIN),
		clamp(center.y, VISUAL_MARGIN, ActiveItemFieldItemMotion.FIELD_HEIGHT - VISUAL_MARGIN)
	)


func _clamp_break_effect_point(point: Vector2, margin: float) -> Vector2:
	return Vector2(
		clamp(point.x, margin, ActiveItemFieldItemMotion.FIELD_WIDTH - margin),
		clamp(point.y, margin, ActiveItemFieldItemMotion.FIELD_HEIGHT - margin)
	)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _should_sample_detail(perf_logger: Object, label: String) -> bool:
	if perf_logger == null or not perf_logger.has_method("should_sample_detail"):
		return false
	return bool(perf_logger.should_sample_detail(label))
