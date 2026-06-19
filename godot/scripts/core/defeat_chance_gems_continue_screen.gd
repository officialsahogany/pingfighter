extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const BUTTON_SIZE := Vector2(330.0, 50.0)
const GEM_COUNT := 3
const GEM_TEXTURE_BOX_SIZE := Vector2(74.0, 96.0)
const GEM_SHATTER_SHEET_COLS := 8
const GEM_SHATTER_SHEET_ROWS := 8
const GEM_SHATTER_FRAME_COUNT := 64
const GEM_SHATTER_DURATION_SEC := 2.0
const REVEAL_DURATION_SEC := 1.05
const GEM_IMPACT_DURATION_SEC := 0.42
const CHANCE_GEM_FULL_TEXTURE_PATH := BattleCoreTexturePaths.CHANCE_GEM_FULL_TEXTURE_PATH
const CHANCE_GEM_BROKEN_TEXTURE_PATH := BattleCoreTexturePaths.CHANCE_GEM_BROKEN_TEXTURE_PATH
const CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH := BattleCoreTexturePaths.CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH
const DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH := BattleCoreTexturePaths.DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH

var active: bool = false
var remaining_gems: int = 0
var max_gems: int = GEM_COUNT
var elapsed_sec: float = 0.0
var reveal_elapsed: float = 0.0
var _pending_continue_callback: Callable = Callable()
var _pending_owner: Object = null
var _pending_registry: Object = null
var _prewarm_assets_step_index: int = 0


func show(owner: Object, registry: Object, continue_callback: Callable) -> bool:
	prewarm_assets()
	_pending_owner = owner
	_pending_registry = registry
	_pending_continue_callback = continue_callback
	max_gems = _read_int(owner, "chance_gems_max", GEM_COUNT)
	max_gems = clampi(max_gems, 1, GEM_COUNT)
	remaining_gems = clampi(_read_int(owner, "chance_gems_count", max_gems), 0, max_gems)
	elapsed_sec = 0.0
	reveal_elapsed = 0.0
	active = true
	_queue_redraw(owner)
	return true


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass
	_prewarm_liveliness_effects()


func prewarm_assets_step() -> bool:
	var paths := _get_texture_paths()
	if _prewarm_assets_step_index >= paths.size():
		_prewarm_assets_step_index = 0
		_prewarm_liveliness_effects()
		return true
	var path := str(paths[_prewarm_assets_step_index])
	ProjectResourceLoader.load_imported_texture(
		path,
		"Missing defeat continue texture at %s",
		"Failed to load defeat continue texture at %s"
	)
	_prewarm_assets_step_index += 1
	if _prewarm_assets_step_index >= paths.size():
		_prewarm_assets_step_index = 0
		_prewarm_liveliness_effects()
		return true
	return false


func prewarm_assets_threaded_step() -> bool:
	var paths := _get_texture_paths()
	if _prewarm_assets_step_index >= paths.size():
		_prewarm_assets_step_index = 0
		_prewarm_liveliness_effects()
		return true
	var path := str(paths[_prewarm_assets_step_index])
	var result := ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"Missing defeat continue texture at %s",
		"Failed to load defeat continue texture at %s",
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC,
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS,
		false,
		true
	)
	if not bool(result.get("done", true)):
		return false
	_prewarm_assets_step_index += 1
	if _prewarm_assets_step_index >= paths.size():
		_prewarm_assets_step_index = 0
		_prewarm_liveliness_effects()
		return true
	return false


func are_assets_ready() -> bool:
	return (
		_get_cached_backdrop_texture() != null
		and _get_cached_gem_texture(false) != null
		and _get_cached_gem_texture(true) != null
		and _get_cached_gem_shatter_texture() != null
	)


func is_active() -> bool:
	return active


func reset() -> void:
	active = false
	remaining_gems = 0
	max_gems = GEM_COUNT
	elapsed_sec = 0.0
	reveal_elapsed = 0.0
	_pending_continue_callback = Callable()
	_pending_owner = null
	_pending_registry = null


func update(delta: float) -> void:
	if not active:
		return
	var safe_delta: float = maxf(0.0, delta)
	elapsed_sec += safe_delta
	reveal_elapsed = minf(REVEAL_DURATION_SEC, reveal_elapsed + safe_delta)


func get_reveal_progress() -> float:
	return _ease_out_cubic(clampf(reveal_elapsed / REVEAL_DURATION_SEC, 0.0, 1.0))


func handle_input(event: InputEvent, owner: Object, _registry: Object, view_size: Vector2) -> bool:
	if not active:
		return false
	if _is_confirm_event(event, view_size):
		_continue(owner)
		return true
	return true


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if canvas == null or not active:
		return
	var ui_font := _get_ui_font()
	var center := view_size * 0.5
	var pulse: float = 0.5 + 0.5 * sin(elapsed_sec * TAU * 1.35)
	var reveal := get_reveal_progress()
	var accent := Color(0.35, 0.82, 1.0, 0.90)
	var gold := Color(0.92, 0.76, 0.38, 0.92)

	_draw_scene_backdrop(canvas, view_size)
	_draw_entry_reveal_glow(canvas, view_size, reveal, accent)
	_draw_boss_portal_figure(canvas, owner, registry, view_size, pulse)
	_draw_compass_sigil(canvas, center.x, _scaled_y(view_size, 58.0), accent)
	_draw_title_ornaments(canvas, center.x, _scaled_y(view_size, 115.0), minf(view_size.x * 0.33, 360.0), accent)
	_draw_centered_text(canvas, ui_font, "패배", Vector2(center.x, _scaled_y(view_size, 120.0)), _scaled_font(view_size, 44), Color(0.88, 0.94, 1.0, 0.98))
	_draw_centered_text(canvas, ui_font, "아쉽지만 다음 기회를 노려보세요.", Vector2(center.x, _scaled_y(view_size, 174.0)), _scaled_font(view_size, 18), Color(0.54, 0.67, 0.92, 0.92))

	_draw_centered_text_segments(
		canvas,
		ui_font,
		[
			{"text": "기회의 보석이 ", "color": Color(0.90, 0.92, 0.98, 0.96)},
			{"text": "1개", "color": Color(0.43, 0.78, 1.0, 0.98)},
			{"text": " 소모되었습니다.", "color": Color(0.90, 0.92, 0.98, 0.96)},
		],
		Vector2(center.x, _scaled_y(view_size, 470.0)),
		_scaled_font(view_size, 20)
	)

	var gem_center_y := _scaled_y(view_size, 540.0)
	var gem_gap := minf(view_size.x * 0.095, 122.0)
	var first_x := center.x - gem_gap
	_draw_gem_rail(canvas, center.x, gem_center_y, gem_gap, accent)
	var consumed: int = max_gems - remaining_gems
	for i in range(max_gems):
		var gem_center := Vector2(first_x + float(i) * gem_gap, gem_center_y)
		_draw_gem_slot(canvas, gem_center, 26.0, i < consumed, i == consumed - 1, pulse)

	var guide := "기회의 보석은 패배 시 1개가 소모됩니다.\n모든 보석이 소모되면 더 이상 도전할 수 없습니다."
	var guide_color := Color(0.70, 0.78, 0.90, 0.90)
	if remaining_gems <= 0:
		guide = "이번이 마지막 기회입니다.\n다음 패배 시 게임이 종료됩니다."
		guide_color = gold
	_draw_multiline_centered_text(canvas, ui_font, guide, Vector2(center.x, _scaled_y(view_size, 592.0)), _scaled_font(view_size, 15), guide_color, 24.0)

	var button_rect := _get_button_rect(view_size)
	_draw_button_frame(canvas, button_rect, accent, pulse)
	_draw_centered_text(canvas, ui_font, "확인", button_rect.get_center() + Vector2(0.0, 1.0), _scaled_font(view_size, 18), Color.WHITE)
	_draw_reveal_veil(canvas, view_size, reveal)


func _draw_scene_backdrop(canvas: CanvasItem, view_size: Vector2) -> void:
	var texture := _get_cached_backdrop_texture()
	if texture != null:
		var backdrop_rect := _cover_texture_rect(texture, Rect2(Vector2.ZERO, view_size))
		canvas.draw_texture_rect(texture, backdrop_rect, false, Color.WHITE)
	else:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.015, 0.020, 0.045, 1.0))
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.18))
	_draw_backdrop_vignette_bands(canvas, view_size)


func _draw_backdrop_vignette_bands(canvas: CanvasItem, view_size: Vector2) -> void:
	var top_height := view_size.y * 0.36
	var bottom_height := view_size.y * 0.34
	var side_width := view_size.x * 0.23
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(view_size.x, 0.0),
			Vector2(view_size.x, top_height),
			Vector2(0.0, top_height),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.36),
			Color(0.0, 0.0, 0.0, 0.36),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
		])
	)
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(0.0, view_size.y - bottom_height),
			Vector2(view_size.x, view_size.y - bottom_height),
			Vector2(view_size.x, view_size.y),
			Vector2(0.0, view_size.y),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.38),
			Color(0.0, 0.0, 0.0, 0.38),
		])
	)
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(side_width, 0.0),
			Vector2(side_width, view_size.y),
			Vector2(0.0, view_size.y),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.26),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.26),
		])
	)
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(view_size.x - side_width, 0.0),
			Vector2(view_size.x, 0.0),
			Vector2(view_size.x, view_size.y),
			Vector2(view_size.x - side_width, view_size.y),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.26),
			Color(0.0, 0.0, 0.0, 0.26),
			Color(0.0, 0.0, 0.0, 0.0),
		])
	)


func _draw_vignette_quad(canvas: CanvasItem, points: PackedVector2Array, colors: PackedColorArray) -> void:
	canvas.draw_polygon(points, colors)


func _draw_entry_reveal_glow(canvas: CanvasItem, view_size: Vector2, reveal: float, accent: Color) -> void:
	var inverse := 1.0 - clampf(reveal, 0.0, 1.0)
	if inverse <= 0.01:
		return
	var center := Vector2(view_size.x * 0.5, _scaled_y(view_size, 344.0))
	var bloom_alpha := 0.14 * inverse
	ImpactFlareTextureCache.draw_glow(canvas, center, minf(view_size.x, view_size.y) * (0.23 + 0.08 * inverse), accent, bloom_alpha)
	var wake := clampf(reveal_elapsed / maxf(REVEAL_DURATION_SEC, 0.001), 0.0, 1.0)
	var wake_alpha := sin(clampf(wake, 0.0, 0.5) * PI * 2.0) * 0.16
	if wake_alpha > 0.0:
		ImpactFlareTextureCache.draw_burst(canvas, center, minf(view_size.x, view_size.y) * (0.19 + wake * 0.08), Color(0.66, 0.86, 1.0, 1.0), wake_alpha)


func _draw_reveal_veil(canvas: CanvasItem, view_size: Vector2, reveal: float) -> void:
	var inverse := 1.0 - clampf(reveal, 0.0, 1.0)
	if inverse <= 0.01:
		return
	var veil_alpha := pow(inverse, 1.7) * 0.74
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, veil_alpha))


func _draw_boss_portal_figure(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2, pulse: float) -> void:
	var texture := _get_cached_boss_victory_texture(registry)
	if texture == null:
		return
	var stage_id: int = maxi(1, _read_int(owner, "current_stage", 1))
	var frame_index := int(floor(elapsed_sec / 0.12))
	var source_rect := _get_boss_victory_source_rect(texture, stage_id, frame_index)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var hover := sin(elapsed_sec * TAU * 0.16) * 5.0
	var center := Vector2(view_size.x * 0.5, _scaled_y(view_size, 342.0) + hover)
	var max_size := Vector2(minf(view_size.x * 0.30, 360.0), minf(view_size.y * 0.38, 274.0))
	var draw_rect := _fit_size_rect(source_rect.size, center, max_size)
	var aura_radius := maxf(draw_rect.size.x, draw_rect.size.y) * (0.48 + pulse * 0.03)
	canvas.draw_circle(center + Vector2(0.0, draw_rect.size.y * 0.10), aura_radius, Color(0.12, 0.24, 0.48, 0.18))
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, Color(0.0, 0.0, 0.0, 0.70), false, true)
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, Color(0.12, 0.22, 0.50, 0.16), false, true)


func _get_cached_boss_victory_texture(registry: Object) -> Texture2D:
	var resources := _get_registry_instance(registry, "battle_resources")
	if resources == null or not resources.has_method("get_resource_cache"):
		return null
	var cache_value: Variant = resources.get_resource_cache()
	if not (cache_value is Dictionary):
		return null
	var cache: Dictionary = cache_value
	var texture_value: Variant = cache.get("boss_victory_sheet", null)
	if texture_value is Texture2D:
		return texture_value
	return null


func _get_boss_victory_source_rect(texture: Texture2D, stage_id: int, frame_index: int) -> Rect2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var cols := 4
	var rows := 2
	if stage_id == 2:
		cols = 8
		rows = 8
	elif stage_id >= 4 and texture_size.x <= texture_size.y * 1.05:
		cols = 1
		rows = 1
	var frame_count := maxi(1, cols * rows)
	var frame := posmod(frame_index, frame_count)
	var cell_size := Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	var row := int(floor(float(frame) / float(cols)))
	return Rect2(Vector2(float(frame % cols) * cell_size.x, float(row) * cell_size.y), cell_size)


func _draw_compass_sigil(canvas: CanvasItem, x: float, y: float, accent: Color) -> void:
	var muted := Color(accent.r, accent.g, accent.b, 0.38)
	canvas.draw_line(Vector2(x, y - 31.0), Vector2(x, y + 31.0), muted, 1.2)
	canvas.draw_line(Vector2(x - 31.0, y), Vector2(x + 31.0, y), muted, 1.2)
	canvas.draw_line(Vector2(x - 21.0, y - 21.0), Vector2(x + 21.0, y + 21.0), Color(accent.r, accent.g, accent.b, 0.24), 1.0)
	canvas.draw_line(Vector2(x - 21.0, y + 21.0), Vector2(x + 21.0, y - 21.0), Color(accent.r, accent.g, accent.b, 0.24), 1.0)
	_draw_diamond_marker(canvas, Vector2(x, y), 12.0, Color(accent.r, accent.g, accent.b, 0.48), false)
	canvas.draw_circle(Vector2(x, y), 2.0, Color(0.80, 0.92, 1.0, 0.82))


func _draw_title_ornaments(canvas: CanvasItem, x: float, y: float, half_width: float, accent: Color) -> void:
	var line_color := Color(accent.r, accent.g, accent.b, 0.30)
	canvas.draw_line(Vector2(x - half_width, y), Vector2(x - 78.0, y), line_color, 1.0)
	canvas.draw_line(Vector2(x + 78.0, y), Vector2(x + half_width, y), line_color, 1.0)
	for side in [-1.0, 1.0]:
		_draw_diamond_marker(canvas, Vector2(x + side * 128.0, y), 5.0, Color(accent.r, accent.g, accent.b, 0.52), false)
		_draw_diamond_marker(canvas, Vector2(x + side * 250.0, y), 4.0, Color(accent.r, accent.g, accent.b, 0.38), false)


func _draw_gem_rail(canvas: CanvasItem, center_x: float, y: float, gem_gap: float, accent: Color) -> void:
	var rail_color := Color(0.68, 0.76, 0.88, 0.38)
	var left_end := center_x - gem_gap * 1.96
	var right_end := center_x + gem_gap * 1.96
	canvas.draw_line(Vector2(left_end, y), Vector2(center_x - gem_gap * 0.62, y), rail_color, 1.2)
	canvas.draw_line(Vector2(center_x + gem_gap * 0.62, y), Vector2(right_end, y), rail_color, 1.2)
	_draw_diamond_marker(canvas, Vector2(center_x - gem_gap * 1.54, y), 7.0, Color(accent.r, accent.g, accent.b, 0.36), false)
	_draw_diamond_marker(canvas, Vector2(center_x + gem_gap * 1.54, y), 7.0, Color(accent.r, accent.g, accent.b, 0.36), false)
	_draw_diamond_marker(canvas, Vector2(center_x - gem_gap * 1.22, y), 3.0, rail_color, true)
	_draw_diamond_marker(canvas, Vector2(center_x + gem_gap * 1.22, y), 3.0, rail_color, true)


func _draw_button_frame(canvas: CanvasItem, rect: Rect2, accent: Color, pulse: float) -> void:
	var corner := minf(rect.size.y * 0.48, 24.0)
	var points: PackedVector2Array = [
		Vector2(rect.position.x + corner, rect.position.y),
		Vector2(rect.end.x - corner, rect.position.y),
		Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5),
		Vector2(rect.end.x - corner, rect.end.y),
		Vector2(rect.position.x + corner, rect.end.y),
		Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5),
	]
	var outline := PackedVector2Array()
	for point in points:
		outline.append(point)
	outline.append(points[0])
	canvas.draw_colored_polygon(points, Color(0.035, 0.090, 0.180, 0.88))
	canvas.draw_polyline(outline, Color(accent.r, accent.g, accent.b, 0.58 + pulse * 0.24), 1.6)
	canvas.draw_line(Vector2(rect.position.x + corner + 8.0, rect.position.y + 5.0), Vector2(rect.end.x - corner - 8.0, rect.position.y + 5.0), Color(1.0, 1.0, 1.0, 0.08), 1.0)


func _draw_centered_text_segments(canvas: CanvasItem, font: Font, segments: Array, center: Vector2, font_size: int) -> void:
	if font == null or segments.is_empty():
		return
	var total_width := 0.0
	var max_height := 0.0
	for segment in segments:
		if not segment is Dictionary:
			continue
		var segment_dict: Dictionary = segment
		var segment_text := str(segment_dict.get("text", ""))
		var segment_size := font.get_string_size(segment_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		total_width += segment_size.x
		max_height = maxf(max_height, segment_size.y)
	var cursor := Vector2(center.x - total_width * 0.5, center.y - max_height * 0.5 + max_height * 0.78)
	for segment in segments:
		if not segment is Dictionary:
			continue
		var segment_dict: Dictionary = segment
		var text := str(segment_dict.get("text", ""))
		var color := Color.WHITE
		var color_value: Variant = segment_dict.get("color", Color.WHITE)
		if color_value is Color:
			color = color_value
		canvas.draw_string(font, cursor + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
		canvas.draw_string(font, cursor, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
		cursor.x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


func _draw_multiline_centered_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color, line_gap: float) -> void:
	var lines := text.split("\n")
	var start_y := center.y - (float(lines.size() - 1) * line_gap * 0.5)
	for i in range(lines.size()):
		_draw_centered_text(canvas, font, lines[i], Vector2(center.x, start_y + float(i) * line_gap), font_size, color)


func _draw_diamond_marker(canvas: CanvasItem, center: Vector2, radius: float, color: Color, filled: bool) -> void:
	var points: PackedVector2Array = [
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	]
	if filled:
		canvas.draw_colored_polygon(points, color)
	else:
		var outline := PackedVector2Array()
		for point in points:
			outline.append(point)
		outline.append(points[0])
		canvas.draw_polyline(outline, color, 1.1)


func _draw_gem_slot(canvas: CanvasItem, center: Vector2, _radius: float, broken: bool, breaking: bool, pulse: float) -> void:
	if breaking:
		_draw_gem_break_impact(canvas, center)
	if breaking and _draw_gem_shatter_sheet(canvas, center):
		return
	var texture: Texture2D = _get_cached_gem_texture(broken)
	if texture == null:
		return
	var rect := _fit_texture_rect(texture, center, GEM_TEXTURE_BOX_SIZE)
	if breaking:
		var glow_alpha := 0.10 + pulse * 0.10
		canvas.draw_circle(center, maxf(rect.size.x, rect.size.y) * 0.55, Color(0.20, 0.68, 1.0, glow_alpha))
	canvas.draw_texture_rect(texture, rect, false, Color.WHITE if not broken else Color(0.82, 0.90, 1.0, 0.76))


func _draw_gem_break_impact(canvas: CanvasItem, center: Vector2) -> void:
	var progress := clampf(elapsed_sec / GEM_IMPACT_DURATION_SEC, 0.0, 1.0)
	if progress >= 1.0:
		return
	var out := _ease_out_cubic(progress)
	var fade := pow(1.0 - progress, 1.55)
	var icy := Color(0.40, 0.82, 1.0, 1.0)
	ImpactFlareTextureCache.draw_glow(canvas, center, 78.0 + 36.0 * out, icy, 0.34 * fade)
	if progress <= 0.36:
		var burst_alpha := (1.0 - progress / 0.36) * 0.34
		ImpactFlareTextureCache.draw_burst(canvas, center, 78.0 + 70.0 * out, Color(0.78, 0.93, 1.0, 1.0), burst_alpha)
	var ring_radius := 42.0 + 58.0 * out
	var ring_rect := Rect2(center - Vector2(ring_radius, ring_radius * 0.66), Vector2(ring_radius * 2.0, ring_radius * 1.32))
	var arc_color := Color(0.58, 0.84, 1.0, 0.30 * fade)
	_draw_ellipse_arc(canvas, ring_rect, -PI * 0.04, PI * 0.82, arc_color, 1.4)
	_draw_ellipse_arc(canvas, ring_rect, PI * 1.06, PI * 1.78, Color(0.80, 0.94, 1.0, 0.22 * fade), 1.1)
	_draw_gem_break_sparkles(canvas, center, out, fade)


func _draw_gem_break_sparkles(canvas: CanvasItem, center: Vector2, out: float, fade: float) -> void:
	var offsets: Array[Vector2] = [
		Vector2(-28.0, -22.0),
		Vector2(34.0, -18.0),
		Vector2(-40.0, 10.0),
		Vector2(42.0, 17.0),
		Vector2(6.0, -38.0),
	]
	for i in range(offsets.size()):
		var offset: Vector2 = offsets[i]
		var travel := 0.35 + out * (0.92 + 0.10 * float(i % 2))
		var gravity := Vector2(0.0, 20.0 * out * out)
		var sparkle_center := center + offset * travel + gravity
		var sparkle_alpha := fade * (0.52 - float(i) * 0.055)
		if sparkle_alpha <= 0.0:
			continue
		ImpactFlareTextureCache.draw_sparkle(canvas, sparkle_center, 10.0 + 3.0 * float(i % 2), Color(0.70, 0.90, 1.0, 1.0), sparkle_alpha)


func _draw_gem_shatter_sheet(canvas: CanvasItem, center: Vector2) -> bool:
	var sheet := _get_cached_gem_shatter_texture()
	if sheet == null:
		return false
	var texture_size := sheet.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	if elapsed_sec >= GEM_SHATTER_DURATION_SEC:
		return false
	var cell_size := Vector2(texture_size.x / float(GEM_SHATTER_SHEET_COLS), texture_size.y / float(GEM_SHATTER_SHEET_ROWS))
	var progress := clampf(elapsed_sec / GEM_SHATTER_DURATION_SEC, 0.0, 1.0)
	var frame := clampi(int(floor(progress * float(GEM_SHATTER_FRAME_COUNT))), 0, GEM_SHATTER_FRAME_COUNT - 1)
	var col := frame % GEM_SHATTER_SHEET_COLS
	var row := int(floor(float(frame) / float(GEM_SHATTER_SHEET_COLS)))
	var source_rect := Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	var draw_rect := _fit_size_rect(cell_size, center, GEM_TEXTURE_BOX_SIZE)
	canvas.draw_texture_rect_region(sheet, draw_rect, source_rect, Color.WHITE, false, true)
	return true


func _get_texture_paths() -> Array:
	return [
		DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH,
		CHANCE_GEM_FULL_TEXTURE_PATH,
		CHANCE_GEM_BROKEN_TEXTURE_PATH,
		CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH,
	]


func _prewarm_liveliness_effects() -> void:
	ImpactFlareTextureCache.prewarm()


func _draw_ellipse_arc(canvas: CanvasItem, rect: Rect2, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radius_x := rect.size.x * 0.5
	var radius_y := rect.size.y * 0.5
	for i in range(28):
		var t := float(i) / 27.0
		var angle := start_angle + (end_angle - start_angle) * t
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	canvas.draw_polyline(points, color, width)


func _get_cached_backdrop_texture() -> Texture2D:
	return ProjectResourceLoader.get_cached_texture(DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH)


func _get_cached_gem_texture(broken: bool) -> Texture2D:
	var path := CHANCE_GEM_BROKEN_TEXTURE_PATH if broken else CHANCE_GEM_FULL_TEXTURE_PATH
	return ProjectResourceLoader.get_cached_texture(path)


func _get_cached_gem_shatter_texture() -> Texture2D:
	return ProjectResourceLoader.get_cached_texture(CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH)


func _fit_texture_rect(texture: Texture2D, center: Vector2, max_size: Vector2) -> Rect2:
	var texture_size := texture.get_size()
	return _fit_size_rect(texture_size, center, max_size)


func _fit_size_rect(source_size: Vector2, center: Vector2, max_size: Vector2) -> Rect2:
	var texture_size := source_size
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(center, Vector2.ZERO)
	var scale_factor := minf(max_size.x / texture_size.x, max_size.y / texture_size.y)
	var draw_size := texture_size * scale_factor
	return Rect2(center - draw_size * 0.5, draw_size)


func _cover_texture_rect(texture: Texture2D, target: Rect2) -> Rect2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or target.size.x <= 0.0 or target.size.y <= 0.0:
		return Rect2(target.position, Vector2.ZERO)
	var scale_factor := maxf(target.size.x / texture_size.x, target.size.y / texture_size.y)
	var draw_size := texture_size * scale_factor
	return Rect2(target.get_center() - draw_size * 0.5, draw_size)


func _is_confirm_event(event: InputEvent, view_size: Vector2) -> bool:
	if event == null:
		return false
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_SPACE]
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		return (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and _get_button_rect(view_size).has_point(mouse_event.position)
		)
	return false


func _continue(owner: Object) -> void:
	var callback := _pending_continue_callback
	reset()
	if callback.is_valid():
		callback.call()
	_queue_redraw(owner)


func _get_button_rect(view_size: Vector2) -> Rect2:
	var width_scale := clampf(view_size.x / 1280.0, 0.78, 1.08)
	var height_scale := clampf(view_size.y / 720.0, 0.90, 1.12)
	var scaled_size := Vector2(BUTTON_SIZE.x * width_scale, BUTTON_SIZE.y * height_scale)
	var top := minf(view_size.y - scaled_size.y - 26.0, _scaled_y(view_size, 676.0) - scaled_size.y * 0.5)
	return Rect2(Vector2(view_size.x * 0.5 - scaled_size.x * 0.5, top), scaled_size)


func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.78)
	canvas.draw_string(font, baseline + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _scaled_y(view_size: Vector2, base_y: float) -> float:
	return base_y * clampf(view_size.y / 720.0, 0.78, 1.28)


func _scaled_font(view_size: Vector2, base_size: int) -> int:
	return max(10, int(round(float(base_size) * clampf(view_size.y / 720.0, 0.86, 1.18))))


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _get_ui_font() -> Font:
	return ThemeDB.fallback_font


func _read_int(owner: Object, key: String, fallback: int) -> int:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return int(value)


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
