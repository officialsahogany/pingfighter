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
const ILLUSION_AURA := Color(0.64, 0.36, 1.0, 1.0)
const ILLUSION_AURA_CORE := Color(0.94, 0.74, 1.0, 1.0)

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
	var illusion_aura_intensity := _get_illusion_awaken_aura_intensity(context)
	var modular_aura_ready: bool = bool(context.get("stage4_illusion_awaken_aura_modular_ready", false))
	_draw_shadow(canvas, center + Vector2(0.0, 46.0), 58.0 + abs(bob) * 2.0)
	if not modular_aura_ready:
		_draw_illusion_awaken_aura(canvas, center, red, illusion_aura_intensity)
	_draw_illusion_awaken_burst(canvas, center, context)
	_draw_chi_orbit(canvas, center, red, meditation_active, 0.0 if modular_aura_ready else illusion_aura_intensity)
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


func _get_illusion_awaken_aura_intensity(context: Dictionary) -> float:
	if bool(context.get("stage4_illusion_active", false)):
		return 1.0
	if not bool(context.get("stage4_illusion_unlocked", false)):
		return 0.0
	var awaken_stage := int(context.get("stage4_illusion_awaken_stage", 0))
	if awaken_stage < 2:
		return 0.0
	if awaken_stage == 2:
		return 0.42
	if awaken_stage == 3:
		var total: float = maxf(1.0, float(context.get("stage4_illusion_first_cast_delay_total", 180.0)))
		var remaining: float = clampf(float(context.get("stage4_illusion_first_cast_delay", total)), 0.0, total)
		return clampf(0.34 + (1.0 - remaining / total) * 0.66, 0.0, 1.0)
	return 0.55


func _draw_illusion_awaken_aura(canvas: CanvasItem, center: Vector2, red: float, intensity: float) -> void:
	if intensity <= 0.0:
		return
	var t: float = float(Time.get_ticks_msec()) * 0.0036
	var pulse: float = 0.5 + sin(t * 1.8) * 0.5
	var aura_color := ILLUSION_AURA.lerp(Color(1.0, 0.28, 0.52, 1.0), red * 0.25)
	var flare: float = clampf(intensity, 0.0, 1.0)
	var base_radius: float = 63.0 + flare * 16.0 + pulse * 5.0
	canvas.draw_circle(center, base_radius, Color(aura_color.r, aura_color.g, aura_color.b, 0.055 + 0.075 * flare))
	canvas.draw_circle(center, base_radius * 0.72, Color(ILLUSION_AURA_CORE.r, ILLUSION_AURA_CORE.g, ILLUSION_AURA_CORE.b, 0.035 + 0.050 * flare))
	canvas.draw_arc(center, base_radius, t, t + PI * 1.42, 72, Color(aura_color.r, aura_color.g, aura_color.b, 0.30 + 0.24 * flare), 2.0 + flare * 1.2, true)
	canvas.draw_arc(center, base_radius * 0.84, -t * 1.12, -t * 1.12 + PI * 1.18, 64, Color(ILLUSION_AURA_CORE.r, ILLUSION_AURA_CORE.g, ILLUSION_AURA_CORE.b, 0.22 + 0.18 * flare), 1.6 + flare, true)
	canvas.draw_arc(center, base_radius * 1.13, t * 0.62 + PI * 0.32, t * 0.62 + PI * 1.36, 52, Color(0.42, 0.12, 0.92, 0.16 + 0.18 * flare), 1.2 + flare * 0.8, true)
	_draw_illusion_light_crown(canvas, center, base_radius, t, flare)


func _draw_illusion_light_crown(canvas: CanvasItem, center: Vector2, base_radius: float, t: float, flare: float) -> void:
	for idx in range(6):
		var angle: float = t * 0.30 + TAU * float(idx) / 6.0
		var pulse: float = 0.5 + 0.5 * sin(t * 1.15 + float(idx) * 1.7)
		var inner_radius: float = base_radius * 1.05
		var outer_radius: float = base_radius * (1.18 + pulse * 0.27)
		var color := ILLUSION_AURA_CORE.lerp(GOLD, 0.38 + pulse * 0.22)
		color.a = 0.10 + 0.14 * flare
		var dir := Vector2(cos(angle), sin(angle))
		canvas.draw_line(center + dir * inner_radius, center + dir * outer_radius, color, 1.4 + flare * 0.9, true)


func _draw_illusion_awaken_burst(canvas: CanvasItem, center: Vector2, context: Dictionary) -> void:
	var total: float = maxf(1.0, float(context.get("stage4_illusion_awaken_burst_total", 90.0)))
	var remaining: float = clampf(float(context.get("stage4_illusion_awaken_burst", 0.0)), 0.0, total)
	if remaining <= 0.0:
		return
	var elapsed: float = maxf(0.0, (total - remaining) / 60.0)
	var life: float = clampf(elapsed / 1.5, 0.0, 1.0)
	if elapsed < 0.35:
		var flash_t: float = clampf(elapsed / 0.35, 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - flash_t, 2.0)
		var alpha: float = 0.85 * pow(1.0 - flash_t, 1.5)
		canvas.draw_circle(center, lerpf(40.0, 140.0, ease_out), Color(0.97, 0.90, 1.0, alpha))
	for idx in range(3):
		var ring_t: float = clampf((elapsed - float(idx) * 0.12) / 0.70, 0.0, 1.0)
		if ring_t <= 0.0 or ring_t >= 1.0:
			continue
		var eased: float = 1.0 - pow(1.0 - ring_t, 2.0)
		var radius: float = lerpf(24.0, 210.0, eased)
		var width: float = lerpf(6.0, 1.5, ring_t)
		var color := ILLUSION_AURA.lerp(GOLD, float(idx) / 2.0)
		color.a = (1.0 - ring_t) * 0.65
		canvas.draw_arc(center, radius, 0.0, TAU, 96, color, width, true)
	for idx in range(10):
		var angle: float = TAU * float(idx) / 10.0 + elapsed * 0.4
		var ray_shape: float = pow(sin(elapsed * 3.0 + float(idx)), 2.0)
		var length: float = (90.0 + 70.0 * ray_shape) * (1.0 - life)
		if length <= 0.5:
			continue
		var color := GOLD.lerp(ILLUSION_AURA_CORE, 0.55)
		color.a = (1.0 - life) * 0.50
		var dir := Vector2(cos(angle), sin(angle))
		canvas.draw_line(center + dir * 18.0, center + dir * length, color, 2.2, true)
	for idx in range(14):
		var seed_a: float = _hash01(float(idx))
		var seed_b: float = _hash01(float(idx * 7 + 3))
		var seed_c: float = _hash01(float(idx * 11 + 5))
		var mote_pos := center + Vector2(seed_a * 80.0 - 40.0, -elapsed * (30.0 + seed_b * 40.0) + seed_c * 18.0 - 9.0)
		var mote_color := ILLUSION_AURA_CORE.lerp(GOLD, seed_b)
		mote_color.a = (1.0 - life) * 0.70
		canvas.draw_circle(mote_pos, 2.0 + seed_c * 2.0, mote_color)


func _draw_chi_orbit(canvas: CanvasItem, center: Vector2, red: float, meditation_active: bool, illusion_aura_intensity: float = 0.0) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.004
	var aura_boost: float = clampf(illusion_aura_intensity, 0.0, 1.0)
	var orbit_radius: float = 58.0 + (10.0 if meditation_active else 0.0) + aura_boost * 9.0
	var color := Color(0.40 + red * 0.55 + aura_boost * 0.20, 0.92 - red * 0.50 - aura_boost * 0.22, 1.0 - red * 0.75, 0.42 + red * 0.20 + aura_boost * 0.26)
	canvas.draw_arc(center, orbit_radius, t, t + PI * 1.35, 64, color, 2.0 + aura_boost * 1.2, true)
	canvas.draw_arc(center, orbit_radius * 0.74, -t * 0.8, -t * 0.8 + PI * 1.1, 48, Color(CHI.r, CHI.g, CHI.b, 0.24 + aura_boost * 0.18), 1.6 + aura_boost * 0.8, true)
	var orb_count: int = 3 + int(round(aura_boost * 2.0))
	for idx in range(orb_count):
		var angle: float = t + TAU * float(idx) / float(orb_count)
		var orb_pos := center + Vector2(cos(angle) * orbit_radius, sin(angle) * orbit_radius * 0.55)
		canvas.draw_circle(orb_pos, 5.0 + aura_boost * 1.7, color)
		canvas.draw_circle(orb_pos, 2.2 + aura_boost * 0.8, Color(1.0, 0.92 - aura_boost * 0.12, 0.55 + aura_boost * 0.35, 0.80))


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


func _hash01(seed: float) -> float:
	var value: float = sin(seed * 12.9898 + 78.233) * 43758.5453
	return value - floor(value)


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
