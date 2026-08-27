extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const DefeatContinueVisualProjection := preload("res://scripts/core/defeat_continue_visual_projection.gd")

const GEM_TEXTURE_BOX_SIZE := Vector2(60.0, 78.0)
const GEM_SHATTER_SHEET_COLS := 8
const GEM_SHATTER_SHEET_ROWS := 8
const GEM_SHATTER_FRAME_COUNT := 64
const GEM_SHATTER_DURATION_SEC := 2.0
const GEM_SHATTER_HANDOFF_SEC := 0.28
const GEM_SHATTER_ENERGY_BOX_SCALE := 0.58
const GEM_SHATTER_FALLBACK_FRAME_SIZE := Vector2(623.0, 1082.0)
const GEM_IMPACT_DURATION_SEC := 0.42
const JADE_GEM_ACTIVE_MODULATE := Color(0.96, 1.0, 0.96, 0.98)
const JADE_GEM_SPENT_MODULATE := Color(0.84, 0.86, 0.78, 0.86)
const JADE_SHATTER_ENERGY_MODULATE := Color(0.52, 0.94, 0.54, 0.34)
const CHANCE_GEM_FULL_TEXTURE_PATH := BattleCoreTexturePaths.CHANCE_GEM_FULL_TEXTURE_PATH
const CHANCE_GEM_BROKEN_TEXTURE_PATH := BattleCoreTexturePaths.CHANCE_GEM_BROKEN_TEXTURE_PATH
const CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH := BattleCoreTexturePaths.CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH

var _max_gems: int = 3
var _visual_remaining_gems: int = 3
var _breaking_gem_index: int = -1
var _shatter_window_active: bool = false
var _pulse: float = 0.0
var _confirm_elapsed: float = 0.0
var _confirm_shake_offset: Vector2 = Vector2.ZERO
var _shatter_progress: float = 0.0
var _pre_shatter_charge: float = 0.0
var _pre_shatter_crack: float = 0.0
var _chroma_split_strength: float = 0.0
var _impact_flash_alpha: float = 0.0
var _impact_ring_progress: float = 0.0
var _impact_ring_alpha: float = 0.0
var _impact_light_beam_alpha: float = 0.0
var _impact_shake_offset: Vector2 = Vector2.ZERO


func sync_gauge_state(
	max_gems: int,
	visual_remaining_gems: int,
	breaking_gem_index: int,
	shatter_window_active: bool,
	pulse: float,
	confirm_elapsed: float,
	confirm_shake_offset: Vector2,
	shatter_progress: float
) -> void:
	_max_gems = maxi(1, max_gems)
	_visual_remaining_gems = clampi(visual_remaining_gems, 0, _max_gems)
	_breaking_gem_index = breaking_gem_index
	_shatter_window_active = shatter_window_active
	_pulse = clampf(pulse, 0.0, 1.0)
	_confirm_elapsed = maxf(0.0, confirm_elapsed)
	_confirm_shake_offset = confirm_shake_offset
	_shatter_progress = clampf(shatter_progress, 0.0, 1.0)


func sync_impact_state(
	pre_shatter_charge: float,
	pre_shatter_crack: float,
	chroma_split_strength: float,
	impact_flash_alpha: float,
	impact_ring_progress: float,
	impact_ring_alpha: float,
	impact_light_beam_alpha: float,
	impact_shake_offset: Vector2
) -> void:
	_pre_shatter_charge = clampf(pre_shatter_charge, 0.0, 1.0)
	_pre_shatter_crack = clampf(pre_shatter_crack, 0.0, 1.0)
	_chroma_split_strength = clampf(chroma_split_strength, 0.0, 1.0)
	_impact_flash_alpha = clampf(impact_flash_alpha, 0.0, 1.0)
	_impact_ring_progress = clampf(impact_ring_progress, 0.0, 1.0)
	_impact_ring_alpha = clampf(impact_ring_alpha, 0.0, 1.0)
	_impact_light_beam_alpha = clampf(impact_light_beam_alpha, 0.0, 1.0)
	_impact_shake_offset = impact_shake_offset


func draw_gem_sequence(canvas: CanvasItem, view_size: Vector2, accent: Color) -> void:
	if canvas == null:
		return
	var center := view_size * 0.5
	var gem_center_y := _scaled_y(view_size, 528.0)
	var gem_gap := minf(view_size.x * 0.095, 122.0)
	var first_x := center.x - gem_gap
	_draw_gem_rail(canvas, center.x, gem_center_y, gem_gap, accent)
	var consumed := _max_gems - _visual_remaining_gems
	var breaking_center := Vector2.ZERO
	if _breaking_gem_index >= 0:
		breaking_center = Vector2(first_x + float(_breaking_gem_index) * gem_gap, gem_center_y)
	_draw_pre_shatter_charge(canvas, breaking_center, view_size)
	_draw_impact_chroma_split(canvas, breaking_center)
	for i in range(_max_gems):
		var gem_center := Vector2(first_x + float(i) * gem_gap, gem_center_y)
		if i == _breaking_gem_index:
			gem_center += _confirm_shake_offset
		var broken := i < consumed
		var breaking := i == _breaking_gem_index and _shatter_window_active
		_draw_gem_setting(canvas, gem_center, broken, breaking)
		_draw_gem_slot(canvas, gem_center, broken, breaking)
		if i == _breaking_gem_index:
			_draw_pre_shatter_cracks(canvas, gem_center)
	if _breaking_gem_index >= 0:
		_draw_shatter_impact_layers(canvas, breaking_center, view_size)


func get_cached_gem_texture(broken: bool) -> Texture2D:
	var path := CHANCE_GEM_BROKEN_TEXTURE_PATH if broken else CHANCE_GEM_FULL_TEXTURE_PATH
	return ProjectResourceLoader.get_cached_texture(path)


func get_cached_gem_shatter_texture() -> Texture2D:
	return ProjectResourceLoader.get_cached_texture(CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH)


func get_static_gem_frame_size() -> Vector2:
	var texture := get_cached_gem_texture(false)
	if texture == null:
		texture = get_cached_gem_texture(true)
	if texture == null:
		return GEM_SHATTER_FALLBACK_FRAME_SIZE
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return GEM_SHATTER_FALLBACK_FRAME_SIZE
	return texture_size


func get_consumed_gem_center(view_size: Vector2, max_gems: int, consumed: int) -> Vector2:
	return DefeatContinueVisualProjection.get_consumed_gem_center(view_size, consumed, maxi(1, max_gems))


func _draw_gem_rail(canvas: CanvasItem, center_x: float, y: float, gem_gap: float, accent: Color) -> void:
	var brass := Color(0.70, 0.55, 0.30, 0.42)
	var cord := Color(0.30, 0.10, 0.075, 0.64)
	var left_end := center_x - gem_gap * 1.96
	var right_end := center_x + gem_gap * 1.96
	var points := PackedVector2Array()
	for i in range(29):
		var ratio := float(i) / 28.0
		var x := lerpf(left_end, right_end, ratio)
		var wave := sin(ratio * TAU * 3.0) * 1.4
		points.append(Vector2(x, y + wave))
	canvas.draw_polyline(points, Color(0.0, 0.0, 0.0, 0.52), 4.4)
	canvas.draw_polyline(points, cord, 2.4)
	canvas.draw_polyline(points, brass, 0.9)
	_draw_cloud_knot_marker(canvas, Vector2(left_end + 9.0, y), -1.0, accent, brass)
	_draw_cloud_knot_marker(canvas, Vector2(right_end - 9.0, y), 1.0, accent, brass)


func _draw_pre_shatter_charge(canvas: CanvasItem, center: Vector2, view_size: Vector2) -> void:
	var charge := _pre_shatter_charge
	if charge <= 0.001:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.10 * charge))
	var jade := Color(0.34, 0.76, 0.60, 1.0)
	ImpactFlareTextureCache.draw_glow(canvas, center, 56.0 + 28.0 * charge, jade, 0.18 * charge)
	ImpactFlareTextureCache.draw_burst(canvas, center, 62.0 + 34.0 * charge, Color(0.86, 0.76, 0.48, 1.0), 0.08 * charge)
	for i in range(4):
		var angle := _confirm_elapsed * (1.9 + float(i) * 0.18) + float(i) * TAU * 0.25
		var radius := 34.0 + 24.0 * (1.0 - charge) + float(i % 2) * 9.0
		var start := center + Vector2(cos(angle), sin(angle)) * radius
		var end := center + Vector2(cos(angle + 0.42), sin(angle + 0.42)) * (radius * (0.58 + charge * 0.18))
		canvas.draw_line(start, end, Color(0.44, 0.78, 0.61, 0.26 * charge), 1.1 + charge * 0.6)


func _draw_pre_shatter_cracks(canvas: CanvasItem, center: Vector2) -> void:
	var crack := _pre_shatter_crack
	if crack <= 0.001:
		return
	var core := Color(0.86, 0.80, 0.58, 0.54 * crack)
	var shadow := Color(0.05, 0.035, 0.02, 0.42 * crack)
	var lines: Array = [
		[Vector2(-4.0, -34.0), Vector2(0.0, -14.0), Vector2(-9.0, 4.0)],
		[Vector2(2.0, -12.0), Vector2(12.0, 8.0), Vector2(4.0, 30.0)],
		[Vector2(-8.0, -2.0), Vector2(-22.0, 14.0)],
		[Vector2(8.0, 0.0), Vector2(24.0, -12.0)],
	]
	for entry in lines:
		var points := PackedVector2Array()
		for value in entry:
			var point: Vector2 = value
			points.append(center + point * (0.45 + crack * 0.55))
		canvas.draw_polyline(points, shadow, 3.0)
		canvas.draw_polyline(points, core, 1.1 + crack * 0.7)


func _draw_impact_chroma_split(canvas: CanvasItem, center: Vector2) -> void:
	var strength := _chroma_split_strength
	if strength <= 0.001:
		return
	var offset := 5.0 + 13.0 * strength
	var box := GEM_TEXTURE_BOX_SIZE * (1.10 + strength * 0.28)
	var rect_r := _fit_size_rect(get_static_gem_frame_size(), center + Vector2(offset, 0.0), box)
	var rect_b := _fit_size_rect(get_static_gem_frame_size(), center - Vector2(offset, 0.0), box)
	var texture := get_cached_gem_texture(false)
	if texture != null:
		canvas.draw_texture_rect(texture, rect_r, false, Color(0.90, 0.46, 0.20, 0.16 * strength))
		canvas.draw_texture_rect(texture, rect_b, false, Color(0.26, 0.68, 0.52, 0.24 * strength))


func _draw_shatter_impact_layers(canvas: CanvasItem, center: Vector2, view_size: Vector2) -> void:
	var flash := _impact_flash_alpha
	var ring := _impact_ring_alpha
	var beam := _impact_light_beam_alpha
	if flash <= 0.001 and ring <= 0.001 and beam <= 0.001:
		return
	var draw_center := center + _impact_shake_offset
	if flash > 0.001:
		ImpactFlareTextureCache.draw_glow(canvas, draw_center, 118.0 + 58.0 * flash, Color(0.52, 0.86, 0.68, 1.0), 0.34 * flash)
		ImpactFlareTextureCache.draw_burst(canvas, draw_center, 164.0 + 96.0 * flash, Color(0.92, 0.82, 0.56, 1.0), 0.42 * flash)
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.78, 0.91, 0.80, 0.08 * flash))
	if ring > 0.001:
		var out := _ease_out_cubic(_impact_ring_progress)
		var radius := 54.0 + 180.0 * out
		var ring_rect := Rect2(draw_center - Vector2(radius, radius * 0.58), Vector2(radius * 2.0, radius * 1.16))
		_draw_ellipse_arc(canvas, ring_rect, -PI * 0.06, PI * 0.86, Color(0.42, 0.78, 0.58, 0.48 * ring), 2.8)
		_draw_ellipse_arc(canvas, ring_rect, PI * 1.02, PI * 1.82, Color(0.84, 0.68, 0.38, 0.34 * ring), 1.8)
		_draw_impact_shards(canvas, draw_center, out, ring)
	if beam > 0.001:
		_draw_impact_light_beams(canvas, draw_center, view_size, beam)


func _draw_impact_shards(canvas: CanvasItem, center: Vector2, out: float, alpha: float) -> void:
	var shard_dirs: Array[Vector2] = [
		Vector2(-1.0, -0.55),
		Vector2(-0.48, -1.0),
		Vector2(0.42, -1.0),
		Vector2(1.0, -0.36),
		Vector2(-0.85, 0.42),
		Vector2(0.86, 0.55),
	]
	for i in range(shard_dirs.size()):
		var direction: Vector2 = shard_dirs[i].normalized()
		var travel := 40.0 + 108.0 * out + float(i % 3) * 12.0
		var gravity := Vector2(0.0, 26.0 * out * out)
		var pos := center + direction * travel + gravity
		var size := 12.0 + float(i % 2) * 4.0
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, size, Color(0.58, 0.82, 0.64, 1.0), alpha * (0.42 - float(i) * 0.035))


func _draw_impact_light_beams(canvas: CanvasItem, center: Vector2, view_size: Vector2, alpha: float) -> void:
	var reach := maxf(view_size.x, view_size.y) * (0.22 + 0.20 * alpha)
	var cool := Color(0.34, 0.74, 0.56, 0.34 * alpha)
	var core := Color(0.90, 0.82, 0.62, 0.68 * alpha)
	var horizontal := Vector2(reach, 0.0)
	var vertical := Vector2(0.0, reach * 0.66)
	canvas.draw_line(center - horizontal, center + horizontal, cool, 7.0)
	canvas.draw_line(center - horizontal, center + horizontal, core, 2.0)
	canvas.draw_line(center - vertical, center + vertical, cool, 5.5)
	canvas.draw_line(center - vertical, center + vertical, core, 1.7)
	var diag := reach * 0.52 * 0.7071
	var d1 := Vector2(diag, diag)
	var d2 := Vector2(diag, -diag)
	canvas.draw_line(center - d1, center + d1, Color(0.54, 0.78, 0.60, 0.22 * alpha), 3.2)
	canvas.draw_line(center - d2, center + d2, Color(0.80, 0.66, 0.40, 0.22 * alpha), 3.2)


func _draw_gem_slot(canvas: CanvasItem, center: Vector2, broken: bool, breaking: bool) -> void:
	if breaking:
		_draw_gem_break_impact(canvas, center)
	if breaking and _draw_gem_shatter_sheet(canvas, center):
		return
	var texture := get_cached_gem_texture(broken)
	if texture == null:
		return
	var rect := _fit_texture_rect(texture, center, GEM_TEXTURE_BOX_SIZE)
	if breaking:
		var glow_alpha := 0.10 + _pulse * 0.10
		canvas.draw_circle(center, maxf(rect.size.x, rect.size.y) * 0.55, Color(0.24, 0.66, 0.50, glow_alpha))
	var color := JADE_GEM_SPENT_MODULATE if broken else JADE_GEM_ACTIVE_MODULATE
	canvas.draw_texture_rect(texture, rect, false, color)
	if broken:
		_draw_spent_gem_cracks(canvas, center)


func _draw_spent_gem_cracks(canvas: CanvasItem, center: Vector2) -> void:
	var main_crack := PackedVector2Array([
		center + Vector2(-17.0, -26.0),
		center + Vector2(-8.0, -12.0),
		center + Vector2(2.0, 1.0),
		center + Vector2(8.0, 15.0),
		center + Vector2(17.0, 27.0),
	])
	var branch := PackedVector2Array([
		center + Vector2(2.0, 1.0),
		center + Vector2(13.0, -7.0),
		center + Vector2(20.0, -14.0),
	])
	canvas.draw_polyline(main_crack, Color(0.025, 0.035, 0.026, 0.92), 3.2)
	canvas.draw_polyline(branch, Color(0.025, 0.035, 0.026, 0.88), 2.6)
	canvas.draw_polyline(main_crack, Color(0.66, 0.76, 0.56, 0.52), 0.9)
	canvas.draw_polyline(branch, Color(0.70, 0.58, 0.34, 0.46), 0.8)


func _draw_gem_break_impact(canvas: CanvasItem, center: Vector2) -> void:
	var progress := clampf(_shatter_progress / maxf(GEM_IMPACT_DURATION_SEC / GEM_SHATTER_DURATION_SEC, 0.001), 0.0, 1.0)
	if progress >= 1.0:
		return
	var out := _ease_out_cubic(progress)
	var fade := pow(1.0 - progress, 1.55)
	var jade := Color(0.36, 0.78, 0.58, 1.0)
	ImpactFlareTextureCache.draw_glow(canvas, center, 78.0 + 36.0 * out, jade, 0.34 * fade)
	if progress <= 0.36:
		var burst_alpha := (1.0 - progress / 0.36) * 0.34
		ImpactFlareTextureCache.draw_burst(canvas, center, 78.0 + 70.0 * out, Color(0.90, 0.80, 0.54, 1.0), burst_alpha)
	var ring_radius := 42.0 + 58.0 * out
	var ring_rect := Rect2(center - Vector2(ring_radius, ring_radius * 0.66), Vector2(ring_radius * 2.0, ring_radius * 1.32))
	var arc_color := Color(0.42, 0.76, 0.57, 0.30 * fade)
	_draw_ellipse_arc(canvas, ring_rect, -PI * 0.04, PI * 0.82, arc_color, 1.4)
	_draw_ellipse_arc(canvas, ring_rect, PI * 1.06, PI * 1.78, Color(0.82, 0.68, 0.42, 0.22 * fade), 1.1)
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
		ImpactFlareTextureCache.draw_sparkle(canvas, sparkle_center, 10.0 + 3.0 * float(i % 2), Color(0.56, 0.82, 0.64, 1.0), sparkle_alpha)


func _draw_gem_shatter_sheet(canvas: CanvasItem, center: Vector2) -> bool:
	var sheet := get_cached_gem_shatter_texture()
	if sheet == null:
		return false
	var texture_size := sheet.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or not _shatter_window_active:
		return false
	var cell_size := Vector2(texture_size.x / float(GEM_SHATTER_SHEET_COLS), texture_size.y / float(GEM_SHATTER_SHEET_ROWS))
	var frame := clampi(int(floor(_shatter_progress * float(GEM_SHATTER_FRAME_COUNT))), 0, GEM_SHATTER_FRAME_COUNT - 1)
	var col := frame % GEM_SHATTER_SHEET_COLS
	var row := int(floor(float(frame) / float(GEM_SHATTER_SHEET_COLS)))
	var source_rect := Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	var static_rect := _fit_size_rect(get_static_gem_frame_size(), center, GEM_TEXTURE_BOX_SIZE)
	var energy_rect := _fit_size_rect(
		get_static_gem_frame_size(),
		center,
		GEM_TEXTURE_BOX_SIZE * GEM_SHATTER_ENERGY_BOX_SCALE
	)
	var handoff_start := maxf(1.0 - GEM_SHATTER_HANDOFF_SEC / maxf(GEM_SHATTER_DURATION_SEC, 0.001), 0.0)
	var handoff_progress := 0.0
	if _shatter_progress > handoff_start:
		handoff_progress = _ease_in_out_cubic((_shatter_progress - handoff_start) / maxf(1.0 - handoff_start, 0.001))
	_draw_static_gem_texture(canvas, center, false, 1.0 - handoff_progress)
	var sheet_alpha := JADE_SHATTER_ENERGY_MODULATE.a * (1.0 - handoff_progress)
	if sheet_alpha > 0.01:
		var energy_color := JADE_SHATTER_ENERGY_MODULATE
		energy_color.a = sheet_alpha
		canvas.draw_texture_rect_region(sheet, energy_rect, source_rect, energy_color, false, true)
	if handoff_progress > 0.0:
		var glow_alpha := 0.08 * (1.0 - handoff_progress)
		if glow_alpha > 0.001:
			canvas.draw_circle(center, maxf(static_rect.size.x, static_rect.size.y) * 0.48, Color(0.24, 0.66, 0.50, glow_alpha))
		_draw_static_gem_texture(canvas, center, true, handoff_progress)
	return true


func _draw_static_gem_texture(canvas: CanvasItem, center: Vector2, broken: bool, alpha: float) -> Rect2:
	var texture := get_cached_gem_texture(broken)
	if texture == null or alpha <= 0.0:
		return Rect2(center, Vector2.ZERO)
	var rect := _fit_texture_rect(texture, center, GEM_TEXTURE_BOX_SIZE)
	var color := JADE_GEM_SPENT_MODULATE if broken else JADE_GEM_ACTIVE_MODULATE
	color.a *= clampf(alpha, 0.0, 1.0)
	canvas.draw_texture_rect(texture, rect, false, color)
	return rect


func _draw_gem_setting(canvas: CanvasItem, center: Vector2, broken: bool, breaking: bool) -> void:
	var dim := 0.64 if broken else 1.0
	var pulse := (0.10 + _pulse * 0.08) if breaking else 0.0
	canvas.draw_circle(center, 32.0, Color(0.012, 0.020, 0.017, 0.82))
	canvas.draw_arc(center, 32.0, 0.0, TAU, 32, Color(0.66, 0.51, 0.28, 0.64 * dim), 2.0)
	canvas.draw_arc(center, 27.0, 0.0, TAU, 32, Color(0.22, 0.54, 0.43, (0.28 + pulse) * dim), 1.0)
	for i in range(4):
		var angle := PI * 0.25 + float(i) * PI * 0.5
		var radial := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-radial.y, radial.x)
		var anchor := center + radial * 29.0
		canvas.draw_line(anchor - tangent * 4.0, anchor + tangent * 4.0, Color(0.74, 0.58, 0.31, 0.58 * dim), 1.3)
		canvas.draw_circle(anchor, 1.5, Color(0.34, 0.68, 0.54, 0.54 * dim))


func _draw_cloud_knot_marker(canvas: CanvasItem, center: Vector2, side: float, accent: Color, brass: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(side * 14.0, 0.0),
		center + Vector2(side * 8.0, -6.0),
		center + Vector2(0.0, -4.0),
		center + Vector2(side * 4.0, 4.0),
		center + Vector2(side * 10.0, 5.0),
	])
	canvas.draw_polyline(points, brass, 1.2)
	canvas.draw_circle(center, 2.4, Color(accent.r, accent.g, accent.b, 0.46))


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


func _fit_texture_rect(texture: Texture2D, center: Vector2, max_size: Vector2) -> Rect2:
	return _fit_size_rect(texture.get_size(), center, max_size)


func _fit_size_rect(source_size: Vector2, center: Vector2, max_size: Vector2) -> Rect2:
	return DefeatContinueVisualProjection.fit_size_rect(source_size, center, max_size)


func _scaled_y(view_size: Vector2, base_y: float) -> float:
	return DefeatContinueVisualProjection.scaled_y(view_size, base_y)


func _ease_out_cubic(value: float) -> float:
	return DefeatContinueVisualProjection.ease_out_cubic(value)


func _ease_in_out_cubic(value: float) -> float:
	return DefeatContinueVisualProjection.ease_in_out_cubic(value)
