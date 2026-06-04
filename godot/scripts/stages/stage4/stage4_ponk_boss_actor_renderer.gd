extends RefCounted

const ElectricStunVisual := preload("res://scripts/status/boss_electric_stun_visual.gd")
const ElectrocutionFieldHost := preload("res://scripts/effects/boss_electrocution_field_fx_host.gd")

const SHEET_PATH := "res://assets/sprites/stage4/stage4_ponk_idle_sheet_imagegen_v1.png"
const SHEET_COLS := 4
const SHEET_ROWS := 2
const FRAME_COUNT := 8
const FRAME_DURATION_MS := 250
const DRAW_LEGACY_PADDLE_WITH_SHEET := false

const ROBE := Color(0.34, 0.19, 0.14, 1.0)
const ROBE_DARK := Color(0.17, 0.10, 0.09, 1.0)
const ROBE_LIGHT := Color(0.58, 0.34, 0.20, 1.0)
const GOLD := Color(0.95, 0.70, 0.26, 1.0)
const CHI := Color(0.42, 0.95, 1.0, 0.72)

var _sheet: Texture2D = null
var _cell_size_px: Vector2 = Vector2.ZERO


func prewarm_assets() -> void:
	if _sheet == null:
		_sheet = load(SHEET_PATH)
		if _sheet != null:
			var tex_size := _sheet.get_size()
			_cell_size_px = Vector2(
				tex_size.x / float(SHEET_COLS),
				tex_size.y / float(SHEET_ROWS)
			)


func reset() -> void:
	pass


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	if _sheet == null:
		prewarm_assets()
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 18.0)), Vector2(100.0, 18.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", 40.0))
	var center := Vector2(
		boss_pos.x + boss_size.x * 0.5,
		boss_pos.y + boss_hitbox_height * 0.5 + 34.0
	) + shake_offset
	var hit_active: bool = bool(context.get("boss_hit_active", false))
	var meditation_active: bool = bool(context.get("stage4_meditation_active", false))
	var red: float = clampf(float(context.get("stage4_moon_red_intensity", 0.0)), 0.0, 1.0)
	var bob: float = sin(float(Time.get_ticks_msec()) * 0.0038) * (4.0 if meditation_active else 2.2)
	center.y += bob
	center += ElectricStunVisual.body_jitter(context)
	ElectrocutionFieldHost.drive_from_context(canvas, center, context)
	_draw_shadow(canvas, center + Vector2(0.0, 46.0), 58.0 + abs(bob) * 2.0)
	_draw_chi_orbit(canvas, center, red, meditation_active)
	var has_sprite_sheet := _sheet != null and _cell_size_px != Vector2.ZERO
	if has_sprite_sheet:
		_draw_body_sheet(canvas, center, hit_active, red, ElectricStunVisual.body_modulate(context))
	else:
		_draw_robes_fallback(canvas, center, hit_active, red)
		_draw_head_fallback(canvas, center, hit_active, red)
		_draw_prayer_beads_fallback(canvas, center, red)
	if not has_sprite_sheet or bool(context.get("stage4_ponk_show_legacy_paddle", DRAW_LEGACY_PADDLE_WITH_SHEET)):
		_draw_paddle(canvas, boss_pos, boss_size, shake_offset, red)


func get_asset_status() -> Dictionary:
	if _sheet == null:
		prewarm_assets()
	return {
		"ponk_boss_sheet": _sheet != null,
		"ponk_boss_draws_legacy_paddle_with_sheet": DRAW_LEGACY_PADDLE_WITH_SHEET,
	}


func _draw_shadow(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for idx in range(28):
		var angle: float = TAU * float(idx) / 28.0
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.22))
	canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.22))


func _draw_chi_orbit(canvas: CanvasItem, center: Vector2, red: float, meditation_active: bool) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.004
	var orbit_radius: float = 58.0 + (10.0 if meditation_active else 0.0)
	var color := Color(0.40 + red * 0.55, 0.92 - red * 0.50, 1.0 - red * 0.75, 0.42 + red * 0.20)
	canvas.draw_arc(center, orbit_radius, t, t + PI * 1.35, 64, color, 2.0, true)
	canvas.draw_arc(center, orbit_radius * 0.74, -t * 0.8, -t * 0.8 + PI * 1.1, 48, Color(CHI.r, CHI.g, CHI.b, 0.24), 1.6, true)
	for idx in range(3):
		var angle: float = t + TAU * float(idx) / 3.0
		var orb_pos := center + Vector2(cos(angle) * orbit_radius, sin(angle) * orbit_radius * 0.55)
		canvas.draw_circle(orb_pos, 5.0, color)
		canvas.draw_circle(orb_pos, 2.2, Color(1.0, 0.92, 0.55, 0.80))


func _draw_body_sheet(canvas: CanvasItem, center: Vector2, hit_active: bool, red: float, electric_modulate: Color = Color.WHITE) -> void:
	@warning_ignore("integer_division")
	var frame_idx := int(Time.get_ticks_msec() / FRAME_DURATION_MS) % FRAME_COUNT
	var col := frame_idx % SHEET_COLS
	@warning_ignore("integer_division")
	var row := frame_idx / SHEET_COLS
	var src_rect := Rect2(
		float(col) * _cell_size_px.x,
		float(row) * _cell_size_px.y,
		_cell_size_px.x,
		_cell_size_px.y
	)
	var dest_size := Vector2(64.0, 86.0)
	var dest_offset := Vector2(0.0, 2.0)
	var dest_rect := Rect2(center - dest_size * 0.5 + dest_offset, dest_size)
	var modulate := Color(1.0, 1.0, 1.0, 1.0)
	if hit_active or red > 0.5:
		var tint: float = 1.0 if hit_active else red
		modulate = Color(1.0, 1.0 - 0.35 * tint, 1.0 - 0.45 * tint, 1.0)
	canvas.draw_texture_rect_region(_sheet, dest_rect, src_rect, modulate * electric_modulate)


func _draw_paddle(canvas: CanvasItem, boss_pos: Vector2, boss_size: Vector2, shake_offset: Vector2, red: float) -> void:
	var rect := Rect2(boss_pos + shake_offset, boss_size)
	canvas.draw_rect(rect, Color(0.14 + red * 0.30, 0.10, 0.08, 0.95))
	canvas.draw_rect(rect.grow(2.0), Color(0.92, 0.65, 0.22, 0.80), false, 2.0, true)


func _draw_robes_fallback(canvas: CanvasItem, center: Vector2, hit_active: bool, red: float) -> void:
	var lean: float = 8.0 if hit_active else sin(float(Time.get_ticks_msec()) * 0.004) * 2.0
	var main_color := ROBE.lerp(Color(0.55, 0.08, 0.05, 1.0), red * 0.35)
	var body := PackedVector2Array([
		center + Vector2(-29.0 + lean, -12.0),
		center + Vector2(27.0 + lean * 0.4, -11.0),
		center + Vector2(48.0, 42.0),
		center + Vector2(20.0, 62.0),
		center + Vector2(-25.0, 60.0),
		center + Vector2(-48.0, 41.0),
	])
	canvas.draw_colored_polygon(body, main_color)
	canvas.draw_polyline(body, Color(0.10, 0.06, 0.05, 0.85), 2.0, true)
	canvas.draw_line(center + Vector2(-8.0, -4.0), center + Vector2(-20.0, 52.0), ROBE_DARK, 3.0, true)
	canvas.draw_line(center + Vector2(9.0, -3.0), center + Vector2(22.0, 49.0), ROBE_LIGHT, 2.0, true)
	canvas.draw_rect(Rect2(center + Vector2(-35.0, 38.0), Vector2(70.0, 9.0)), Color(0.10, 0.06, 0.05, 0.55))


func _draw_head_fallback(canvas: CanvasItem, center: Vector2, hit_active: bool, red: float) -> void:
	var head_center := center + Vector2(0.0, -30.0)
	canvas.draw_circle(head_center, 18.0, Color(0.74, 0.55, 0.39, 1.0))
	canvas.draw_circle(head_center + Vector2(0.0, -10.0), 11.0, Color(0.19, 0.12, 0.10, 1.0))
	var eye_color := Color(1.0, 0.24 + red * 0.42, 0.13, 1.0) if hit_active or red > 0.5 else Color(0.08, 0.05, 0.03, 1.0)
	canvas.draw_line(head_center + Vector2(-8.0, 0.0), head_center + Vector2(-2.0, -1.0), eye_color, 2.0, true)
	canvas.draw_line(head_center + Vector2(2.0, -1.0), head_center + Vector2(8.0, 0.0), eye_color, 2.0, true)
	canvas.draw_arc(head_center + Vector2(0.0, 5.0), 6.0, 0.18, PI - 0.18, 16, Color(0.18, 0.08, 0.05, 0.85), 1.5, true)


func _draw_prayer_beads_fallback(canvas: CanvasItem, center: Vector2, red: float) -> void:
	for idx in range(11):
		var angle: float = PI * (0.08 + float(idx) / 10.0 * 0.84)
		var pos := center + Vector2(cos(angle) * 24.0, sin(angle) * 13.0 + 2.0)
		canvas.draw_circle(pos, 2.8, GOLD.lerp(Color(1.0, 0.20, 0.12, 1.0), red * 0.30))


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
