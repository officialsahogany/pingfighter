extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")


func draw_chaos_startup(
	canvas: CanvasItem,
	shake_offset: Vector2,
	current: Vector2,
	target: Vector2,
	phase_frames: float,
	startup_frames: float,
	visual_length: float
) -> void:
	var startup_t: float = clamp(phase_frames / max(1.0, startup_frames), 0.0, 1.0)
	var spear_pos: Vector2 = current + Vector2(0.0, -10.0 - 18.0 * startup_t) + shake_offset
	var angle: float = (target - current).angle()
	var glow_radius: float = 16.0 + 24.0 * startup_t
	ImpactFlareTextureCache.draw_glow(canvas, spear_pos, glow_radius, Color(0.55, 0.18, 1.0), 0.22 + startup_t * 0.18)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, spear_pos, glow_radius + 8.0, Color(0.82, 0.56, 1.0), 0.48)
	draw_chaos_spear(canvas, spear_pos, angle, 0.55 + startup_t * 0.45, 0.88 + startup_t * 0.18, visual_length)
	for i in range(6):
		var spark_angle: float = TAU * float(i) / 6.0 + phase_frames * 0.18
		var inner: Vector2 = spear_pos + Vector2(cos(spark_angle), sin(spark_angle)) * (10.0 + 8.0 * startup_t)
		var outer: Vector2 = spear_pos + Vector2(cos(spark_angle + 0.24), sin(spark_angle + 0.24)) * (28.0 + 22.0 * startup_t)
		canvas.draw_line(inner, outer, Color(0.90, 0.70, 1.0, 0.30 + startup_t * 0.35), 1.5, true)


func draw_chaos_spear(
	canvas: CanvasItem,
	tip: Vector2,
	angle: float,
	alpha: float,
	scale: float,
	visual_length: float
) -> void:
	if alpha <= 0.0:
		return
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var dir_s := dir * scale
	var perp_s := perp * scale
	var L: float = visual_length
	var blade_back_lx: float = -22.0
	var crossguard_lx: float = -22.0
	var shaft_end_lx: float = -L
	var proj := func(lx: float, ly: float) -> Vector2:
		return tip + dir_s * lx + perp_s * ly

	# === Big purple glow aura along the spear's major axis (4-layer ellipse) ===
	var glow_w: float = (L + 32.0) * scale
	var glow_h: float = 30.0 * scale
	if glow_w > 4.0 and glow_h > 4.0:
		var mid_lx: float = -L * 0.5
		var glow_center: Vector2 = tip + dir_s * mid_lx
		var segs: int = 24
		for i in range(4):
			var r_w: float = max(4.0, glow_w - i * 8.0)
			var r_h: float = max(2.0, glow_h - i * 4.0)
			var layer_a: float = min(alpha, (28.0 + i * 22.0) / 255.0)
			var glow_color := Color(0.667, 0.353, 1.0, layer_a)
			var pts := PackedVector2Array()
			var color_arr := PackedColorArray()
			pts.resize(segs)
			color_arr.resize(segs)
			for j in range(segs):
				var t: float = TAU * float(j) / float(segs)
				pts[j] = glow_center + dir * cos(t) * r_w * 0.5 + perp * sin(t) * r_h * 0.5
				color_arr[j] = glow_color
			canvas.draw_polygon(pts, color_arr)

	# === Shaft (dark chrome polygon) ===
	var sh_thick: float = max(1.0, 6.0 * scale)
	var sh_v0: Vector2 = proj.call(blade_back_lx, -sh_thick * 0.5)
	var sh_v1: Vector2 = proj.call(blade_back_lx, sh_thick * 0.5)
	var sh_v2: Vector2 = proj.call(shaft_end_lx + 5.0, sh_thick * 0.5)
	var sh_v3: Vector2 = proj.call(shaft_end_lx + 5.0, -sh_thick * 0.5)
	var sh_pts := PackedVector2Array([sh_v0, sh_v1, sh_v2, sh_v3])
	var sh_fill := Color(0.149, 0.141, 0.220, alpha)
	canvas.draw_polygon(sh_pts, PackedColorArray([sh_fill, sh_fill, sh_fill, sh_fill]))
	canvas.draw_polyline(
		PackedVector2Array([sh_v0, sh_v1, sh_v2, sh_v3, sh_v0]),
		Color(0.353, 0.314, 0.471, alpha), 1.0, true)
	# Top metal highlight
	canvas.draw_line(
		proj.call(blade_back_lx, -sh_thick * 0.5 + 1.0),
		proj.call(shaft_end_lx + 5.0, -sh_thick * 0.5 + 1.0),
		Color(0.784, 0.765, 0.902, alpha), 1.0, true)
	# Rune deco (3 short glowing perpendicular lines)
	var rune_color := Color(0.863, 0.588, 1.0, alpha)
	for i in range(3):
		var rl: float = blade_back_lx - 12.0 - float(i) * 16.0
		canvas.draw_line(
			proj.call(rl, -sh_thick * 0.5 - 1.0),
			proj.call(rl, sh_thick * 0.5 + 1.0),
			rune_color, 1.0, true)

	# === Crossguard (thick perpendicular bar with end triangles) ===
	var cg_v0: Vector2 = proj.call(crossguard_lx + 2.0, -16.0)
	var cg_v1: Vector2 = proj.call(crossguard_lx + 7.0, -16.0)
	var cg_v2: Vector2 = proj.call(crossguard_lx + 7.0, 16.0)
	var cg_v3: Vector2 = proj.call(crossguard_lx + 2.0, 16.0)
	var cg_pts := PackedVector2Array([cg_v0, cg_v1, cg_v2, cg_v3])
	var cg_fill := Color(0.549, 0.549, 0.659, alpha)
	canvas.draw_polygon(cg_pts, PackedColorArray([cg_fill, cg_fill, cg_fill, cg_fill]))
	canvas.draw_polyline(
		PackedVector2Array([cg_v0, cg_v1, cg_v2, cg_v3, cg_v0]),
		Color(0.922, 0.922, 1.0, alpha), 1.0, true)
	# Crossguard end decorations (top + bottom triangles)
	var cg_end_color := Color(0.706, 0.392, 0.902, alpha)
	var cg_end_color_arr := PackedColorArray([cg_end_color, cg_end_color, cg_end_color])
	for ly_end in [-16.0, 16.0]:
		var off: float = -3.0 if ly_end < 0.0 else 3.0
		var tip_off: float = -7.0 if ly_end < 0.0 else 7.0
		var end_tri := PackedVector2Array([
			proj.call(crossguard_lx + 2.0, ly_end + off),
			proj.call(crossguard_lx + 7.0, ly_end + off),
			proj.call(crossguard_lx + 4.0, ly_end + tip_off),
		])
		canvas.draw_polygon(end_tri, cg_end_color_arr)

	# === Energy core (purple diamond gem with white inner highlight) ===
	var core_v0: Vector2 = proj.call(crossguard_lx + 4.0, -8.0)
	var core_v1: Vector2 = proj.call(crossguard_lx + 14.0, 0.0)
	var core_v2: Vector2 = proj.call(crossguard_lx + 4.0, 8.0)
	var core_v3: Vector2 = proj.call(crossguard_lx - 6.0, 0.0)
	var core_pts := PackedVector2Array([core_v0, core_v1, core_v2, core_v3])
	var core_fill := Color(0.706, 0.314, 0.961, alpha)
	canvas.draw_polygon(core_pts, PackedColorArray([core_fill, core_fill, core_fill, core_fill]))
	canvas.draw_polyline(
		PackedVector2Array([core_v0, core_v1, core_v2, core_v3, core_v0]),
		Color(1.0, 0.941, 1.0, alpha), 1.0, true)
	var inner_core_pts := PackedVector2Array([
		proj.call(crossguard_lx + 4.0, -3.0),
		proj.call(crossguard_lx + 9.0, 0.0),
		proj.call(crossguard_lx + 4.0, 3.0),
		proj.call(crossguard_lx - 1.0, 0.0),
	])
	var inner_white := Color(1.0, 1.0, 1.0, alpha)
	canvas.draw_polygon(inner_core_pts, PackedColorArray([inner_white, inner_white, inner_white, inner_white]))

	# === Blade (refined hexagonal lozenge) ===
	var bl_v0: Vector2 = proj.call(0.0, 0.0)
	var bl_v1: Vector2 = proj.call(-7.0, -10.0)
	var bl_v2: Vector2 = proj.call(blade_back_lx + 3.0, -7.0)
	var bl_v3: Vector2 = proj.call(blade_back_lx, 0.0)
	var bl_v4: Vector2 = proj.call(blade_back_lx + 3.0, 7.0)
	var bl_v5: Vector2 = proj.call(-7.0, 10.0)
	var blade_pts := PackedVector2Array([bl_v0, bl_v1, bl_v2, bl_v3, bl_v4, bl_v5])
	var blade_fill := Color(0.961, 0.941, 1.0, alpha)
	canvas.draw_polygon(blade_pts, PackedColorArray([blade_fill, blade_fill, blade_fill, blade_fill, blade_fill, blade_fill]))
	canvas.draw_polyline(
		PackedVector2Array([bl_v0, bl_v1, bl_v2, bl_v3, bl_v4, bl_v5, bl_v0]),
		Color(0.510, 0.510, 0.686, alpha), 1.0, true)
	# Midrib center highlight
	canvas.draw_line(
		proj.call(blade_back_lx + 1.0, 0.0),
		bl_v0,
		Color(1.0, 1.0, 1.0, alpha), 1.0, true)
	# Tip glow point
	canvas.draw_circle(bl_v0, max(1.0, 2.0 * scale), Color(1.0, 1.0, 1.0, alpha))

	# === Pommel (3-layer purple gem: outer fill / inner white / outline ring) ===
	var pommel_center: Vector2 = proj.call(shaft_end_lx, 0.0)
	var pr: float = max(2.0, 7.0 * scale)
	canvas.draw_circle(pommel_center, pr, Color(0.706, 0.314, 0.941, alpha))
	canvas.draw_circle(pommel_center, max(1.0, pr * 0.5), Color(1.0, 1.0, 1.0, alpha))
	canvas.draw_arc(pommel_center, pr, 0.0, TAU, 32, Color(0.941, 0.784, 1.0, alpha), 1.0, true)


func draw_chaos_impact(canvas: CanvasItem, center: Vector2, progress: float, alpha: float) -> void:
	ImpactFlareTextureCache.draw_burst(canvas, center, 118.0 + progress * 42.0, Color(0.80, 0.43, 1.0), alpha * (0.56 - progress * 0.18))
	ImpactFlareTextureCache.draw_glow(canvas, center, 74.0 + progress * 26.0, Color(0.60, 0.20, 1.0), alpha * 0.34)
	for i in range(3):
		var ring_t: float = clamp(progress + float(i) * 0.12, 0.0, 1.0)
		var radius: float = 24.0 + ring_t * 135.0
		var ring_alpha: float = max(0.0, (1.0 - ring_t) * alpha)
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius, Color(0.80, 0.43, 1.0), ring_alpha)
	ImpactFlareTextureCache.draw_sparkle(canvas, center, 44.0 + progress * 30.0, Color(0.96, 0.82, 1.0), alpha * (1.0 - progress * 0.35))


func draw_chaos_blackhole(
	canvas: CanvasItem,
	center: Vector2,
	phase_frames: float,
	orbit_seed: float,
	alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var pulse: float = 0.5 + 0.5 * sin(phase_frames * 0.17)
	ImpactFlareTextureCache.draw_glow(canvas, center, 58.0 + pulse * 8.0, Color(0.20, 0.04, 0.34), 0.42 * alpha)
	canvas.draw_circle(center, 26.0 + pulse * 4.0, Color(0.0, 0.0, 0.0, 0.92 * alpha))
	for i in range(3):
		var radius: float = 58.0 + float(i) * 30.0 + sin(phase_frames * 0.08 + float(i)) * 5.0
		var start_angle: float = phase_frames * (0.035 + float(i) * 0.005) + float(i) * 0.8
		var sweep: float = PI * (1.04 + float(i) * 0.06)
		var ring_alpha: float = (0.38 - float(i) * 0.060) * alpha
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius, Color(0.35, 0.11, 0.58), ring_alpha * 0.18)
		canvas.draw_arc(center, radius, start_angle, start_angle + sweep, 32, Color(0.66, 0.25, 1.0, ring_alpha), 2.2, true)
		canvas.draw_arc(center, radius * 0.82, start_angle + PI, start_angle + PI + sweep * 0.72, 24, Color(0.32, 0.84, 1.0, ring_alpha * 0.45), 1.5, true)
	for i in range(8):
		var angle: float = orbit_seed + phase_frames * 0.11 + TAU * float(i) / 8.0
		var dist: float = 74.0 + 38.0 * sin(phase_frames * 0.04 + float(i) * 1.7)
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle * 1.18)) * dist
		canvas.draw_circle(pos, 2.0 + float(i % 3), Color(0.88, 0.72, 1.0, 0.65 * alpha))


func draw_chaos_fallback_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	runtime: Object,
	chaos_fx_synced: bool,
	startup_frames: float,
	impact_frames: float,
	fade_frames: float,
	visual_length: float
) -> void:
	if chaos_fx_synced:
		return
	var center: Vector2 = runtime.chaos_target + shake_offset
	match runtime.chaos_state:
		"startup":
			draw_chaos_startup(
				canvas,
				shake_offset,
				runtime.chaos_current,
				runtime.chaos_target,
				runtime.chaos_phase_frames,
				max(1.0, startup_frames),
				visual_length
			)
		"flying":
			draw_chaos_spear(canvas, runtime.chaos_current + shake_offset, runtime.chaos_flight_angle, 1.0, 1.0, visual_length)
		"impact":
			draw_chaos_impact(
				canvas,
				center,
				clamp(runtime.chaos_phase_frames / max(1.0, impact_frames), 0.0, 1.0),
				1.0
			)
			draw_chaos_spear(canvas, center, runtime.chaos_flight_angle, 0.92, 1.05, visual_length)
		"blackhole":
			draw_chaos_blackhole(
				canvas,
				center,
				runtime.chaos_phase_frames,
				runtime.chaos_orbit_seed,
				1.0
			)
		"fade":
			var fade_alpha: float = 1.0 - clamp(runtime.chaos_phase_frames / max(1.0, fade_frames), 0.0, 1.0)
			draw_chaos_blackhole(
				canvas,
				center,
				runtime.chaos_phase_frames,
				runtime.chaos_orbit_seed,
				fade_alpha
			)


func draw_chaos_cancel_flash(canvas: CanvasItem, cancel_flash_frames: float) -> void:
	if cancel_flash_frames <= 0.0:
		return
	var flash_alpha: float = clamp(cancel_flash_frames / 16.0, 0.0, 1.0) * 0.22
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(760.0, 750.0)), Color(0.64, 0.16, 1.0, flash_alpha))


func update_chaos_absorb_pulses(pulses: Array, center: Vector2, fps_scale: float) -> void:
	var write_index := 0
	for read_index in range(pulses.size()):
		var pulse: Dictionary = pulses[read_index]
		var life: float = float(pulse.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			continue
		pulse["life"] = life
		var size: float = float(pulse.get("size", 8.0))
		if bool(pulse.get("consumed", false)):
			size = max(0.0, size - 1.6 * fps_scale)
			if size <= 0.5:
				continue
			pulse["size"] = size
			pulses[write_index] = pulse
			write_index += 1
			continue
		var pos: Vector2 = _get_vector2(pulse.get("pos", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = _get_vector2(pulse.get("vel", Vector2.ZERO), Vector2.ZERO)
		var delta: Vector2 = center - pos
		var dist: float = max(6.0, delta.length())
		var dir: Vector2 = delta / dist
		var accel: float = min(2.4, 110.0 / dist) * fps_scale
		velocity += dir * accel
		var tan_factor: float = max(0.0, 0.6 - dist / 200.0) * fps_scale
		velocity += Vector2(-dir.y, dir.x) * tan_factor
		velocity *= pow(0.93, fps_scale)
		pos += velocity * fps_scale
		if center.distance_to(pos) < 14.0:
			pulse["consumed"] = true
			pulse["size"] = float(pulse.get("base_size", size)) * 1.6
			pulse["life"] = min(life, 8.0)
		pulse["pos"] = pos
		pulse["vel"] = velocity
		pulses[write_index] = pulse
		write_index += 1
	if write_index < pulses.size():
		pulses.resize(write_index)


func draw_chaos_absorb_pulses(canvas: CanvasItem, center: Vector2, pulses: Array, shake_offset: Vector2) -> void:
	for pulse_value in pulses:
		if not (pulse_value is Dictionary):
			continue
		var pulse: Dictionary = pulse_value
		var pos: Vector2 = _get_vector2(pulse.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = float(pulse.get("size", 8.0))
		var life: float = float(pulse.get("life", 0.0))
		var max_life: float = max(1.0, float(pulse.get("max_life", 60.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		var color: Color = pulse.get("color", Color(0.78, 0.48, 1.0, 1.0))
		canvas.draw_line(pos, center, Color(color.r, color.g, color.b, 0.16 * alpha), 1.5, true)
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.28 * alpha))
		canvas.draw_circle(pos, max(1.5, size * 0.35), Color(1.0, 1.0, 1.0, 0.58 * alpha))


func build_chaos_fx_state(
	runtime: Object,
	shake_offset: Vector2,
	node_fx_layout: Dictionary,
	phase_total_frames: float,
	disk_height: float
) -> Dictionary:
	var render_scale: float = 1.0
	var game_offset := Vector2.ZERO
	if not node_fx_layout.is_empty():
		render_scale = max(0.01, float(node_fx_layout.get("render_scale", 1.0)))
		game_offset = _get_vector2(node_fx_layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var enraged: bool = bool(node_fx_layout.get("enraged_boss_active", node_fx_layout.get("boss_enraged", false)))
	var phase_progress: float = clamp(runtime.chaos_phase_frames / max(1.0, phase_total_frames), 0.0, 1.0)
	var blackhole_progress: float = 0.0
	var alpha: float = 1.0
	if runtime.chaos_state == "blackhole":
		blackhole_progress = phase_progress
	elif runtime.chaos_state == "fade":
		blackhole_progress = 1.0
		alpha = 1.0 - phase_progress
	var screen_center: Vector2 = game_offset + (runtime.chaos_target + shake_offset) * render_scale
	var screen_current: Vector2 = game_offset + (runtime.chaos_current + shake_offset) * render_scale
	var screen_origin: Vector2 = game_offset + (runtime.chaos_origin + shake_offset) * render_scale
	var screen_player_center: Vector2 = screen_current
	if runtime.chaos_state in ["flying", "impact", "blackhole", "fade"]:
		screen_player_center = screen_origin
	var screen_size: float = disk_height * render_scale
	return {
		"phase": runtime.chaos_state,
		"screen_center": screen_center,
		"screen_current": screen_current,
		"screen_origin": screen_origin,
		"screen_player_center": screen_player_center,
		"screen_size": screen_size,
		"alpha": alpha,
		"progress": blackhole_progress,
		"phase_progress": phase_progress,
		"phase_frames": runtime.chaos_phase_frames,
		"phase_total_frames": phase_total_frames,
		"render_scale": render_scale,
		"flight_angle": runtime.chaos_flight_angle,
		"enraged": enraged,
		"spawn_msec": runtime.chaos_fx_spawn_msec_seed,
	}


func get_chaos_phase_total_frames(
	chaos_state: String,
	startup_frames: float,
	travel_frames: float,
	impact_frames: float,
	blackhole_frames: float,
	fade_frames: float
) -> float:
	match chaos_state:
		"startup":
			return startup_frames
		"flying":
			return travel_frames
		"impact":
			return impact_frames
		"blackhole":
			return blackhole_frames
		"fade":
			return fade_frames
	return 1.0


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
