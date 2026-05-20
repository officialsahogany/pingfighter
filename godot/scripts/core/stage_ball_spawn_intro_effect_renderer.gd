extends RefCounted


func draw_vortex_ring(canvas: CanvasItem, r: Dictionary, alpha_mult: float) -> void:
	if r.radius < 5.0:
		return
	var dash_count: int = int(r.dash_count)
	var dash_slot: float = TAU / float(dash_count)
	var arc_len: float = dash_slot * float(r.dash_fill)
	var base_alpha: float = float(r.alpha) * alpha_mult
	var glow_thick: float = float(r.thickness) + 2.5
	var mid_thick: float = max(1.0, float(r.thickness) - 0.5)
	for i in range(dash_count):
		var shim: float = sin(float(r.time) * float(r.shimmer_freq) + float(r.shimmer_phase) + float(i) * 0.73)
		var shim_factor: float = 1.0 + shim * float(r.shimmer_amp)
		if shim_factor < 0.35:
			continue
		var start_a: float = float(r.angle) + float(i) * dash_slot
		var end_a: float = start_a + arc_len
		var ga: float = clamp(base_alpha * 0.45 * shim_factor, 0.0, 1.0)
		var ca: float = clamp(base_alpha * 1.10 * shim_factor, 0.0, 1.0)
		if ga > 0.015:
			canvas.draw_arc(r.center, r.radius, start_a, end_a, 8, Color(r.glow_color.r, r.glow_color.g, r.glow_color.b, ga), glow_thick)
		if ca > 0.015:
			canvas.draw_arc(r.center, r.radius, start_a, end_a, 8, Color(r.core_color.r, r.core_color.g, r.core_color.b, ca), mid_thick)
		var head: Vector2 = Vector2(
			float(r.center.x) + cos(end_a) * float(r.radius),
			float(r.center.y) + sin(end_a) * float(r.radius),
		)
		var head_alpha: float = clamp(base_alpha * 1.55 * shim_factor, 0.0, 1.0)
		if head_alpha > 0.025:
			var tip_r: float = max(2.0, float(r.thickness))
			canvas.draw_circle(head, tip_r, Color(r.core_color.r, r.core_color.g, r.core_color.b, head_alpha))


func draw_quantum_particle(
	canvas: CanvasItem,
	p: Dictionary,
	alpha_mult: float,
	glow_texture: Texture2D
) -> void:
	var brightness: float = 0.55 + 0.45 * sin(p.brightness_phase)
	var alpha: float = clamp(0.85 * brightness * alpha_mult, 0.0, 1.0)
	if alpha <= 0.005:
		return

	var pos: Vector2 = Vector2(p.x, p.y)
	var trail_arr: Array = p.trail
	var trail_len: int = trail_arr.size()
	if trail_len > 0:
		var inv_len: float = 1.0 / float(max(1, trail_len))
		for i in range(trail_len):
			var entry: Vector4 = trail_arr[i]
			var trail_ratio: float = float(i + 1) * inv_len
			var ta: float = clamp(0.55 * pow(trail_ratio, 1.5) * alpha_mult * float(entry.w), 0.0, 1.0)
			if ta < 0.012:
				continue
			var blend: float = pow(trail_ratio, 0.85)
			var inv_blend: float = 1.0 - blend
			var col: Color = Color(
				p.halo_color.r * inv_blend + p.color.r * blend,
				p.halo_color.g * inv_blend + p.color.g * blend,
				p.halo_color.b * inv_blend + p.color.b * blend,
				ta,
			)
			var ts: float = max(2.0, float(entry.z) * (0.6 + 0.6 * trail_ratio)) * 5.5
			canvas.draw_texture_rect(glow_texture, Rect2(entry.x - ts * 0.5, entry.y - ts * 0.5, ts, ts), false, col)

	var glow_diam: float = max(10.0, p.size * 11.5)
	canvas.draw_texture_rect(
		glow_texture,
		Rect2(pos.x - glow_diam * 0.5, pos.y - glow_diam * 0.5, glow_diam, glow_diam),
		false,
		Color(p.color.r, p.color.g, p.color.b, alpha),
	)

	var hot_r: float = max(1.5, p.size * 0.55)
	canvas.draw_circle(pos, hot_r, Color(1.0, 1.0, 1.0, min(1.0, alpha * 1.25)))

	if p.has_flare and alpha > 0.3:
		var flare_len: float = p.size * 2.4
		var fa: float = alpha * 0.32
		if flare_len > 2.0 and fa > 0.02:
			var dirv: Vector2 = Vector2(cos(p.flare_angle), sin(p.flare_angle))
			var flare_color: Color = Color(min(1.0, p.color.r * 1.2), min(1.0, p.color.g * 1.2), min(1.0, p.color.b * 1.2), fa)
			canvas.draw_line(pos + dirv * flare_len, pos - dirv * flare_len, flare_color, 1.0)


func draw_lightning_bolt(canvas: CanvasItem, bolt: Dictionary, alpha_mult: float) -> void:
	var elapsed_in: float = bolt.max_lifetime - bolt.lifetime
	var alpha: float
	if elapsed_in < bolt.fade_in_time:
		alpha = (elapsed_in / max(0.0001, bolt.fade_in_time)) * bolt.base_opacity
	else:
		var fade_dur: float = bolt.max_lifetime - bolt.fade_in_time
		var rr: float = clamp(bolt.lifetime / max(0.0001, fade_dur), 0.0, 1.0)
		alpha = bolt.base_opacity * sqrt(rr)
	alpha *= alpha_mult
	if alpha <= 0.01:
		return

	for b in bolt.branches:
		draw_lightning_bolt(canvas, b, alpha_mult * 0.6)

	var color: Color = bolt.color
	var brighter: Color = Color(min(1.0, color.r + 0.12), min(1.0, color.g + 0.12), min(1.0, color.b + 0.12), 1.0)
	var glow_alpha_outer: float = clamp(alpha * 0.18, 0.0, 1.0)
	var glow_thick_outer: float = bolt.thickness + 6.0
	if glow_alpha_outer > 0.015:
		for seg in bolt.segments:
			canvas.draw_line(Vector2(seg.x, seg.y), Vector2(seg.z, seg.w), Color(brighter.r, brighter.g, brighter.b, glow_alpha_outer), glow_thick_outer)
	var glow_alpha_inner: float = clamp(alpha * 0.42, 0.0, 1.0)
	var glow_thick_inner: float = bolt.thickness + 2.5
	if glow_alpha_inner > 0.015:
		for seg in bolt.segments:
			canvas.draw_line(Vector2(seg.x, seg.y), Vector2(seg.z, seg.w), Color(brighter.r, brighter.g, brighter.b, glow_alpha_inner), glow_thick_inner)
	var main_alpha: float = clamp(alpha * 0.78, 0.0, 1.0)
	for seg in bolt.segments:
		canvas.draw_line(Vector2(seg.x, seg.y), Vector2(seg.z, seg.w), Color(color.r, color.g, color.b, main_alpha), bolt.thickness + 1)
	var core_alpha: float = clamp(alpha * 0.95, 0.0, 1.0)
	for seg in bolt.segments:
		canvas.draw_line(Vector2(seg.x, seg.y), Vector2(seg.z, seg.w), Color(1.0, 1.0, 1.0, core_alpha), max(1.0, float(bolt.thickness - 1)))


func draw_electric_arc(canvas: CanvasItem, arc: Dictionary) -> void:
	var life_ratio: float = clamp(arc.lifetime / arc.max_lifetime, 0.0, 1.0)
	var alpha: float = clamp(life_ratio, 0.0, 1.0)
	if alpha < 0.02:
		return
	var num_segments: int = 10
	var pts: Array = []
	var noise_arr: Array = arc.noise
	for i in range(num_segments + 1):
		var t: float = float(i) / float(num_segments)
		var current_angle: float = arc.angle + t * arc.arc_length
		var noise_idx: int = clampi(int(t * float(noise_arr.size() - 1)), 0, noise_arr.size() - 1)
		var noise: float = float(noise_arr[noise_idx]) * (1.0 - abs(t - 0.5) * 2.0)
		var rr: float = arc.radius + noise
		pts.append(Vector2(arc.center.x + cos(current_angle) * rr, arc.center.y + sin(current_angle) * rr))
	if pts.size() < 2:
		return
	var glow_color: Color = Color(arc.color.r * 0.72, arc.color.g * 0.72, arc.color.b * 0.72, alpha * 0.55)
	var main_color: Color = Color(arc.color.r, arc.color.g, arc.color.b, alpha * 0.92)
	var core_color: Color = Color(1.0, 1.0, 1.0, alpha * 0.85)
	var thickness: int = arc.thickness
	for i in range(pts.size() - 1):
		canvas.draw_line(pts[i], pts[i + 1], glow_color, float(thickness + 3))
	for i in range(pts.size() - 1):
		canvas.draw_line(pts[i], pts[i + 1], main_color, float(thickness + 1))
	for i in range(pts.size() - 1):
		canvas.draw_line(pts[i], pts[i + 1], core_color, max(1.0, float(thickness - 1)))


func draw_hologram_ring(canvas: CanvasItem, rng: RandomNumberGenerator, h: Dictionary) -> void:
	var life_ratio: float = clamp(h.lifetime / h.max_lifetime, 0.0, 1.0)
	var flicker: float = 0.3 + 0.7 * (0.5 + 0.5 * sin(h.flicker_phase))
	if rng.randf() < 0.10:
		flicker *= rng.randf_range(0.2, 1.5)
	var alpha: float = clamp(0.78 * life_ratio * flicker, 0.0, 1.0)
	if alpha <= 0.02:
		return
	var seg_count: int = int(h.segments)
	var angle_step: float = TAU / float(seg_count)
	var distortion_arr: Array = h.distortion
	for i in range(seg_count):
		if rng.randf() < 0.05:
			continue
		var sa: float = float(i) * angle_step
		var ea: float = float(i + 0.8) * angle_step
		var rr: float = h.radius + float(distortion_arr[i])
		var sx: Vector2 = Vector2(h.center.x + cos(sa) * rr, h.center.y + sin(sa) * rr)
		var ex: Vector2 = Vector2(h.center.x + cos(ea) * rr, h.center.y + sin(ea) * rr)
		var color_shift: float = sin(h.flicker_phase + float(i) * 0.5) * 0.12
		var col: Color = Color(
			clamp(h.base_color.r + color_shift, 0.0, 1.0),
			clamp(h.base_color.g + color_shift, 0.0, 1.0),
			clamp(h.base_color.b + color_shift, 0.0, 1.0),
			alpha,
		)
		canvas.draw_line(sx, ex, col, h.thickness)


func draw_spark(canvas: CanvasItem, sp: Dictionary, glow_texture: Texture2D) -> void:
	var life_ratio: float = clamp(sp.lifetime / sp.max_lifetime, 0.0, 1.0)
	var alpha: float = clamp(life_ratio, 0.0, 1.0)
	if alpha <= 0.02:
		return
	var trail_arr: Array = sp.trail
	var trail_len: int = trail_arr.size()
	if trail_len > 1:
		for i in range(trail_len - 1):
			var ratio: float = float(i + 1) / float(trail_len)
			var ta: float = clamp(alpha * ratio * 0.55, 0.0, 1.0)
			if ta > 0.02:
				canvas.draw_line(trail_arr[i], trail_arr[i + 1], Color(sp.color.r, sp.color.g, sp.color.b, ta), max(1.0, sp.size * ratio))
	var glow_size: float = sp.size * 7.0
	canvas.draw_texture_rect(
		glow_texture,
		Rect2(sp.pos.x - glow_size * 0.5, sp.pos.y - glow_size * 0.5, glow_size, glow_size),
		false,
		Color(sp.color.r, sp.color.g, sp.color.b, alpha),
	)
	canvas.draw_circle(sp.pos, sp.size * 0.55, Color(1.0, 1.0, 1.0, alpha))


func draw_energy_ring(canvas: CanvasItem, ring: Dictionary) -> void:
	var life_ratio: float = clamp(ring.lifetime / ring.max_lifetime, 0.0, 1.0)
	var alpha: float = clamp(0.78 * life_ratio, 0.0, 1.0)
	if alpha <= 0.02 or ring.radius <= 0.0:
		return
	for i in range(2, 0, -1):
		var ring_alpha: float = clamp(alpha * 0.30 / float(i), 0.0, 1.0)
		canvas.draw_arc(ring.center, ring.radius + float(i) * 2.0, 0.0, TAU, 56, Color(ring.color.r, ring.color.g, ring.color.b, ring_alpha), float(ring.thickness + i))
	canvas.draw_arc(ring.center, ring.radius, 0.0, TAU, 64, Color(ring.color.r, ring.color.g, ring.color.b, alpha), float(ring.thickness))


func draw_core_glow(
	canvas: CanvasItem,
	start_pos: Vector2,
	core_glow_radius: float,
	core_glow_alpha: float,
	glow_texture: Texture2D
) -> void:
	var alpha_max: float = clamp(core_glow_alpha / 255.0, 0.0, 1.0)
	if alpha_max <= 0.01:
		return
	var diam: float = core_glow_radius * 4.0
	canvas.draw_texture_rect(
		glow_texture,
		Rect2(start_pos.x - diam * 0.5, start_pos.y - diam * 0.5, diam, diam),
		false,
		Color(0.78, 0.85, 1.0, alpha_max),
	)
	canvas.draw_circle(start_pos, max(2.0, core_glow_radius * 0.30), Color(1.0, 1.0, 1.0, alpha_max))
