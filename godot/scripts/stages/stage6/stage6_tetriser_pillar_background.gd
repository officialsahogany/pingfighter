extends RefCounted

# Stage 6 Tetriser pillar background.
#
# Fresh Godot-native visual pass inspired by early arcade/console Tetris side
# furniture: black wells, beveled stone columns, blocky score plinths, a small
# palace marquee, and Ringpia cyan/gold ring accents. Gameplay tetrominoes and
# the central cube remain owned by stage6_tetriser_state/playfield_renderer.

const LOGICAL := Vector2(760.0, 750.0)

const VOID_COLOR := Color(0.005, 0.006, 0.015, 1.0)
const FIELD_COLOR := Color(0.010, 0.012, 0.026, 1.0)
const GRID_COLOR := Color(0.05, 0.14, 0.20, 0.20)
const STONE := Color(0.55, 0.56, 0.68, 1.0)
const STONE_DARK := Color(0.24, 0.25, 0.42, 1.0)
const STONE_SHADOW := Color(0.08, 0.08, 0.18, 1.0)
const STONE_LIGHT := Color(0.78, 0.80, 0.92, 1.0)
const PURPLE_EDGE := Color(0.38, 0.34, 0.84, 1.0)
const BLUE_EDGE := Color(0.18, 0.42, 0.92, 1.0)
const RED_CLOTH := Color(0.86, 0.04, 0.10, 1.0)
const GOLD := Color(1.0, 0.68, 0.16, 1.0)
const RING_CYAN := Color(0.05, 0.84, 1.0, 1.0)
const RING_BLUE := Color(0.18, 0.35, 1.0, 1.0)
const NEON_RED := Color(1.0, 0.08, 0.16, 1.0)

var _time := 0.0
var _last_draw_msec := 0
var _ready := false


func prewarm_assets() -> void:
	_ready = true


func prewarm_assets_step() -> bool:
	_ready = true
	return true


func reset() -> void:
	_time = 0.0
	_last_draw_msec = 0
	_ready = false


func update(_delta: float, _context: Dictionary = {}, _deps: Dictionary = {}) -> void:
	# Time advances from draw() to match the existing controller-driven pillar
	# background path and avoid double-speed animation.
	pass


func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	quality_scale: float = 1.0
) -> bool:
	if canvas == null:
		return false
	if not _ready:
		prewarm_assets()
	var dt := _consume_draw_delta()
	_time += dt

	var target_size := view_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = game_offset * 2.0 + game_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = LOGICAL
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		game_offset = Vector2.ZERO
		game_size = target_size

	canvas.draw_rect(Rect2(Vector2.ZERO, target_size), VOID_COLOR)
	_draw_scan_grid(canvas, target_size, quality_scale)
	_draw_playfield_backplate(canvas, game_offset, game_size, quality_scale)
	_draw_letterbox_architecture(canvas, target_size, game_offset, game_size, quality_scale)
	_draw_central_marquee(canvas, game_offset, game_size, quality_scale)
	_draw_ringpia_orbits(canvas, game_offset, game_size, quality_scale)
	return true


func draw_pillar_background_overlay(
	_canvas: CanvasItem,
	_view_size: Vector2,
	_game_offset: Vector2,
	_game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	_quality_scale: float = 1.0
) -> void:
	pass


func get_asset_status() -> Dictionary:
	return {
		"theme": "retro_tetris_ringpia",
		"uses_runtime_textures": false,
		"draws_old_tetris_columns": true,
		"dense_cabinet_fill": false,
	}


func _draw_scan_grid(canvas: CanvasItem, target_size: Vector2, quality_scale: float) -> void:
	var gap := 78.0
	var phase := fmod(_time * 10.0, gap)
	var alpha := 0.16 if quality_scale > 0.55 else 0.08
	var line_color := Color(GRID_COLOR.r, GRID_COLOR.g, GRID_COLOR.b, alpha)
	var x := -target_size.y * 0.16 - phase
	while x < target_size.x + target_size.y * 0.16:
		canvas.draw_line(Vector2(x, 0.0), Vector2(x + target_size.y * 0.16, target_size.y), line_color, 1.0, true)
		x += gap
	var y := 112.0
	while y < target_size.y:
		canvas.draw_line(Vector2(0.0, y), Vector2(target_size.x, y), Color(0.70, 0.55, 0.12, 0.055), 1.0, true)
		y += 92.0


func _draw_playfield_backplate(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, quality_scale: float) -> void:
	var play_rect := Rect2(game_offset, game_size)
	canvas.draw_rect(play_rect, FIELD_COLOR)
	var border_w := maxf(2.0, game_size.x / LOGICAL.x * 3.0)
	canvas.draw_rect(play_rect.grow(2.0), Color(0.03, 0.06, 0.12, 0.95), false, border_w + 2.0, true)
	canvas.draw_rect(play_rect, Color(0.11, 0.18, 0.34, 0.88), false, border_w, true)
	canvas.draw_line(play_rect.position + Vector2(0.0, border_w), play_rect.position + Vector2(game_size.x, border_w), Color(0.34, 0.54, 0.92, 0.48), 1.0, true)
	if quality_scale > 0.52:
		var band_w := game_size.x * 0.18
		var sweep_x := game_offset.x + fmod(_time * 68.0, game_size.x + band_w) - band_w
		var band_rect := Rect2(Vector2(sweep_x, game_offset.y + game_size.y * 0.58), Vector2(band_w, game_size.y * 0.28))
		canvas.draw_rect(band_rect, Color(0.12, 0.35, 0.58, 0.18))


func _draw_letterbox_architecture(
	canvas: CanvasItem,
	target_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	quality_scale: float
) -> void:
	var left_rect := Rect2(Vector2.ZERO, Vector2(maxf(0.0, game_offset.x), target_size.y))
	var right_x := game_offset.x + game_size.x
	var right_rect := Rect2(Vector2(right_x, 0.0), Vector2(maxf(0.0, target_size.x - right_x), target_size.y))
	if left_rect.size.x >= 46.0:
		_draw_side_architecture(canvas, left_rect, false, quality_scale)
	if right_rect.size.x >= 46.0:
		_draw_side_architecture(canvas, right_rect, true, quality_scale)


func _draw_side_architecture(canvas: CanvasItem, rect: Rect2, right_side: bool, _quality_scale: float) -> void:
	# Single focal panel rule: the live Tetris well (stage6_tetriser_pillar_tetris)
	# owns the framed cabinet, NEXT preview, STATS, and score plinth. The background
	# only contributes the side stone columns + bottom plinth so the two layers do
	# not stack into competing frames / duplicate STATS / clashing block grids.
	canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 1.0))
	var inner := rect.grow(-maxf(5.0, rect.size.x * 0.022))
	inner.size.y = maxf(1.0, inner.size.y)
	var column_w := clampf(rect.size.x * 0.10, 18.0, 42.0)
	_draw_stone_column(canvas, Rect2(inner.position, Vector2(column_w, inner.size.y)), right_side)
	_draw_stone_column(canvas, Rect2(Vector2(inner.end.x - column_w, inner.position.y), Vector2(column_w, inner.size.y)), right_side)
	_draw_bottom_plinth(canvas, Rect2(Vector2(inner.position.x, inner.end.y - 104.0), Vector2(inner.size.x, 94.0)), right_side)


func _draw_stone_column(canvas: CanvasItem, rect: Rect2, right_side: bool) -> void:
	canvas.draw_rect(rect, STONE_DARK)
	canvas.draw_rect(rect.grow(-2.0), STONE)
	var segment_h := maxf(36.0, rect.size.y / 9.0)
	var y := rect.position.y + 14.0
	while y < rect.end.y - 24.0:
		var seg := Rect2(Vector2(rect.position.x + 3.0, y), Vector2(rect.size.x - 6.0, segment_h * 0.64))
		canvas.draw_rect(seg, Color(0.66, 0.66, 0.76, 1.0))
		canvas.draw_line(seg.position, Vector2(seg.end.x, seg.position.y), STONE_LIGHT, 1.0, true)
		canvas.draw_line(Vector2(seg.position.x, seg.end.y), seg.end, STONE_SHADOW, 1.0, true)
		y += segment_h
	var edge_x := rect.end.x - 2.0 if right_side else rect.position.x + 2.0
	canvas.draw_line(Vector2(edge_x, rect.position.y), Vector2(edge_x, rect.end.y), BLUE_EDGE, 2.0, true)


func _draw_bottom_plinth(canvas: CanvasItem, rect: Rect2, right_side: bool) -> void:
	canvas.draw_rect(rect, STONE_SHADOW)
	var body := rect.grow(-4.0)
	canvas.draw_rect(body, Color(0.12, 0.13, 0.32, 1.0))
	canvas.draw_rect(body, PURPLE_EDGE, false, 2.0, true)
	var stripe_w := maxf(5.0, body.size.x * 0.035)
	var stripe_x := body.end.x - stripe_w - 4.0 if right_side else body.position.x + 4.0
	canvas.draw_rect(Rect2(Vector2(stripe_x, body.position.y + 6.0), Vector2(stripe_w, body.size.y - 12.0)), NEON_RED)
	var ring_center := body.get_center() + Vector2(0.0, -body.size.y * 0.04)
	canvas.draw_arc(ring_center, minf(body.size.x, body.size.y) * 0.31, 0.0, TAU, 32, Color(RING_CYAN.r, RING_CYAN.g, RING_CYAN.b, 0.26), 2.0, true)


func _draw_central_marquee(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, quality_scale: float) -> void:
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		return
	var scale := game_size.x / LOGICAL.x
	var top_center := game_offset + Vector2(game_size.x * 0.5, maxf(28.0 * scale, 22.0))
	var arch_w := clampf(game_size.x * 0.26, 150.0 * scale, 230.0 * scale)
	var arch_h := clampf(game_size.y * 0.11, 56.0 * scale, 92.0 * scale)
	var arch_rect := Rect2(top_center + Vector2(-arch_w * 0.5, 0.0), Vector2(arch_w, arch_h))
	canvas.draw_rect(Rect2(arch_rect.position + Vector2(0.0, arch_h * 0.45), Vector2(arch_w, arch_h * 0.55)), STONE)
	canvas.draw_arc(arch_rect.position + Vector2(arch_w * 0.5, arch_h * 0.50), arch_w * 0.5, PI, TAU, 36, STONE_LIGHT, 8.0 * scale, true)
	canvas.draw_arc(arch_rect.position + Vector2(arch_w * 0.5, arch_h * 0.50), arch_w * 0.5, PI, TAU, 36, PURPLE_EDGE, 3.0 * scale, true)
	_draw_turret(canvas, arch_rect.position + Vector2(18.0 * scale, arch_h * 0.22), scale)
	_draw_turret(canvas, arch_rect.position + Vector2(arch_w - 18.0 * scale, arch_h * 0.22), scale)
	var font: Font = ThemeDB.fallback_font
	if font != null and quality_scale > 0.45:
		var font_size: int = maxi(12, int(round(22.0 * scale)))
		var text: String = "TETRISER"
		var text_pos: Vector2 = arch_rect.position + Vector2(arch_w * 0.5 - float(font_size) * 2.65, arch_h * 0.58)
		canvas.draw_string(font, text_pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, arch_w, font_size, Color(0.0, 0.0, 0.0, 0.65))
		canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, arch_w, font_size, Color(1.0, 0.12, 0.18, 0.86))
	var cloth_rect := Rect2(arch_rect.position + Vector2(arch_w * 0.18, arch_h * 0.74), Vector2(arch_w * 0.64, 7.0 * scale))
	canvas.draw_rect(cloth_rect, RED_CLOTH)
	for i in range(4):
		var cx := cloth_rect.position.x + cloth_rect.size.x * (float(i) + 0.5) / 4.0
		canvas.draw_circle(Vector2(cx, cloth_rect.end.y), 5.0 * scale, RED_CLOTH)


func _draw_turret(canvas: CanvasItem, pos: Vector2, scale: float) -> void:
	var body := Rect2(pos + Vector2(-8.0, 4.0) * scale, Vector2(16.0, 28.0) * scale)
	canvas.draw_rect(body, STONE)
	canvas.draw_rect(body, PURPLE_EDGE, false, 2.0 * scale, true)
	canvas.draw_circle(pos + Vector2(0.0, 0.0) * scale, 9.0 * scale, GOLD)
	canvas.draw_rect(Rect2(pos + Vector2(-5.0, -10.0) * scale, Vector2(10.0, 12.0) * scale), GOLD)


func _draw_ringpia_orbits(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, quality_scale: float) -> void:
	if quality_scale <= 0.5:
		return
	var center := game_offset + game_size * Vector2(0.5, 0.64)
	var radius := minf(game_size.x, game_size.y) * 0.18
	var spin := _time * 0.65
	canvas.draw_arc(center, radius, spin, spin + PI * 1.28, 64, Color(RING_CYAN.r, RING_CYAN.g, RING_CYAN.b, 0.22), 3.0, true)
	canvas.draw_arc(center, radius * 0.72, -spin * 1.3, -spin * 1.3 + PI * 1.15, 54, Color(GOLD.r, GOLD.g, GOLD.b, 0.18), 2.0, true)
	canvas.draw_circle(center, radius * 0.18, Color(RING_BLUE.r, RING_BLUE.g, RING_BLUE.b, 0.045))


func _consume_draw_delta() -> float:
	var now := Time.get_ticks_msec()
	if _last_draw_msec <= 0:
		_last_draw_msec = now
		return 1.0 / 60.0
	var delta := clampf(float(now - _last_draw_msec) / 1000.0, 0.0, 0.1)
	_last_draw_msec = now
	return delta
