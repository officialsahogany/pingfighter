extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")


func draw_core_flip_effects(canvas: CanvasItem, shake_offset: Vector2, runtime: Object, phase0_frames: float, phase2_frames: float) -> void:
	for line_value in runtime.core_flip_web_lines:
		if not (line_value is Dictionary):
			continue
		var line: Dictionary = line_value
		var from_pos: Vector2 = _get_vector2(line.get("from", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var to_pos: Vector2 = _get_vector2(line.get("to", Vector2.ZERO), Vector2.ZERO) + shake_offset
		canvas.draw_line(from_pos, to_pos, Color(0.34, 0.03, 0.20, 0.30), 10.0, true)
		canvas.draw_line(from_pos, to_pos, Color(0.86, 0.18, 0.55, 0.64), 4.0, true)
		canvas.draw_line(from_pos, to_pos, Color(1.0, 0.66, 0.92, 0.88), 1.4, true)
	if not runtime.core_flip_attack_active:
		return
	var center: Vector2 = runtime.core_flip_visual_pos + runtime.core_flip_paddle_size * 0.5 + shake_offset
	var phase_t: float = clamp(runtime.core_flip_phase_frames / max(1.0, phase2_frames if runtime.core_flip_attack_phase == 2 else phase0_frames), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018)
	var color := Color(1.0, 0.28, 0.72, 0.32 + pulse * 0.12)
	if runtime.core_flip_attack_phase == 0:
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, 40.0 + phase_t * 34.0, Color(1.0, 0.36, 0.78), 0.35)
		for i in range(3):
			var angle: float = deg_to_rad(runtime.core_flip_spin_angle_degrees + float(i) * 120.0)
			canvas.draw_line(center, center + Vector2(cos(angle), sin(angle) * 0.45) * (34.0 + pulse * 8.0), color, 4.0, true)
	elif runtime.core_flip_attack_phase == 2:
		ImpactFlareTextureCache.draw_glow(canvas, center, 54.0 + pulse * 8.0, Color(1.0, 0.18, 0.58), 0.28)
		var dir := Vector2(float(runtime.core_flip_kick_dir), -0.28).normalized()
		canvas.draw_line(center - dir * 44.0, center + dir * 58.0, Color(1.0, 0.52, 0.90, 0.74), 7.0, true)
		canvas.draw_line(center - dir * 18.0, center + dir * 62.0, Color(1.0, 0.92, 1.0, 0.84), 2.0, true)


func draw_marshal_effects(canvas: CanvasItem, shake_offset: Vector2, runtime: Object) -> void:
	if runtime.phantom_aura_active and runtime.marshal_active:
		var aura_center: Vector2 = runtime.marshal_visual_pos + runtime.marshal_paddle_size * 0.5 + shake_offset
		var pulse: float = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.0045)
		canvas.draw_circle(aura_center, 54.0 * pulse, Color(0.20, 0.02, 0.31, 0.33))
		canvas.draw_arc(aura_center, 66.0 + 8.0 * pulse, 0.0, TAU, 48, Color(0.45, 0.08, 0.65, 0.55), 3.0, true)
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0 + Time.get_ticks_msec() * 0.0025
			var spiral_pos: Vector2 = aura_center + Vector2(cos(angle), sin(angle)) * (22.0 + 34.0 * pulse)
			canvas.draw_circle(spiral_pos, 4.0, Color(0.55, 0.15, 0.78, 0.72))
	for line_value in runtime.marshal_web_lines:
		if not (line_value is Dictionary):
			continue
		var line: Dictionary = line_value
		var from_pos: Vector2 = _get_vector2(line.get("from", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var to_pos: Vector2 = _get_vector2(line.get("to", Vector2.ZERO), Vector2.ZERO) + shake_offset
		canvas.draw_line(from_pos, to_pos, Color(0.20, 0.02, 0.32, 0.28), 10.0, true)
		canvas.draw_line(from_pos, to_pos, Color(0.35, 0.06, 0.52, 0.50), 6.0, true)
		canvas.draw_line(from_pos, to_pos, Color(0.64, 0.22, 0.92, 0.92), 2.5, true)
	if runtime.marshal_active and runtime.marshal_phase == 1:
		var cling_center: Vector2 = runtime.marshal_wall_pos + runtime.marshal_paddle_size * 0.5 + shake_offset
		var cling_pulse: float = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.02)
		canvas.draw_circle(cling_center, 35.0 * cling_pulse, Color(0.34, 0.05, 0.60, 0.32))
	if runtime.marshal_active and runtime.marshal_phase == 2:
		var charge_center: Vector2 = runtime.marshal_visual_pos + runtime.marshal_paddle_size * 0.5 + shake_offset
		var start_center: Vector2 = runtime.marshal_charge_start_pos + runtime.marshal_paddle_size * 0.5 + shake_offset
		canvas.draw_line(start_center, charge_center, Color(0.42, 0.08, 0.65, 0.75), 3.0, true)
		canvas.draw_circle(charge_center, 28.0, Color(0.45, 0.05, 0.72, 0.30))


func draw_marshal_effect_stack(
	canvas: CanvasItem,
	shake_offset: Vector2,
	runtime: Object,
	particle_drawer: Object,
	hit_particle_glow_size_threshold: float,
	freeze_frames: float,
	text_frames: float,
	effect_lod_scale: float = 1.0
) -> void:
	draw_marshal_effects(canvas, shake_offset, runtime)
	particle_drawer.draw_hit_particle_list(
		canvas,
		runtime.marshal_particles,
		shake_offset,
		false,
		hit_particle_glow_size_threshold,
		effect_lod_scale
	)
	particle_drawer.draw_hit_particle_list(
		canvas,
		runtime.phantom_hit_particles,
		shake_offset,
		true,
		hit_particle_glow_size_threshold,
		effect_lod_scale
	)
	if runtime.dmk_freeze_active or runtime.dmk_text_active:
		draw_phantom_kick_show_overlay(
			canvas,
			shake_offset,
			runtime,
			freeze_frames,
			text_frames
		)


func draw_phantom_kick_show_overlay(
	canvas: CanvasItem,
	shake_offset: Vector2,
	runtime: Object,
	freeze_frames: float,
	text_frames: float
) -> void:
	var field_size := Vector2(760.0, 750.0)
	var now_msec: int = Time.get_ticks_msec()
	var freeze_elapsed: float = freeze_frames - runtime.dmk_freeze_frames
	if runtime.dmk_freeze_active:
		var dim_alpha: float = 0.55 * clamp(freeze_elapsed / 5.0, 0.0, 1.0)
		canvas.draw_rect(Rect2(Vector2.ZERO, field_size), Color(0.02, 0.0, 0.05, dim_alpha))
		var vignette_alpha: float = 0.24 * clamp(freeze_elapsed / 8.0, 0.0, 1.0)
		for ring in range(3):
			var inset: float = float(ring) * 40.0
			var rect_size: Vector2 = field_size - Vector2(inset * 2.0, inset * 2.0)
			if rect_size.x <= 0.0 or rect_size.y <= 0.0:
				continue
			var ring_alpha: float = vignette_alpha * (1.0 - float(ring) * 0.3)
			if ring_alpha > 0.01:
				var width: float = max(30.0, 50.0 - float(ring) * 15.0)
				canvas.draw_rect(Rect2(Vector2(inset, inset), rect_size), Color(0.08, 0.0, 0.14, ring_alpha), false, width)
	var text_alpha: float = 0.0
	var y_offset: float = 0.0
	@warning_ignore("shadowed_global_identifier")
	var ease: float = 1.0
	if runtime.dmk_freeze_active:
		var freeze_t: float = clamp(freeze_elapsed / max(1.0, freeze_frames), 0.0, 1.0)
		ease = clamp(freeze_t * 5.0, 0.0, 1.0)
		text_alpha = ease
	else:
		var post_t: float = 1.0 - runtime.dmk_text_frames / max(1.0, text_frames)
		post_t = clamp(post_t, 0.0, 1.0)
		text_alpha = clamp(1.0 - post_t * 1.5, 0.0, 1.0)
		y_offset = -20.0 * post_t
	if text_alpha <= 0.04:
		return
	var center: Vector2 = field_size * 0.5 + Vector2(0.0, y_offset) + shake_offset
	var text_shake := Vector2.ZERO
	if runtime.dmk_freeze_active and ease < 0.5:
		var tick: int = int(float(now_msec) / 33.0)
		text_shake = Vector2(float((tick % 5) - 2), float((int(float(tick) / 5.0) % 3) - 1))
	var pulse: float = 0.7 + 0.3 * sin(float(now_msec) * 0.005)
	for radius in range(30, 5, -3):
		var r: float = float(radius)
		var glow_alpha: float = 0.10 * (1.0 - r / 30.0) * pulse * text_alpha
		if glow_alpha > 0.005:
			canvas.draw_circle(center + text_shake, r * 2.9, Color(0.20, 0.03, 0.29, glow_alpha * 0.46))
			canvas.draw_circle(center + text_shake, r * 1.2, Color(0.31, 0.05, 0.46, glow_alpha * 0.32))
	var font: Font = ThemeDB.fallback_font
	var text_width := 240.0
	var text_origin := Vector2(center.x - text_width * 0.5, center.y + text_shake.y)
	var label := LanguageSettings.translate_text("환영연각")
	canvas.draw_string(font, text_origin + Vector2(text_shake.x + 3.0, 3.0), label, HORIZONTAL_ALIGNMENT_CENTER, text_width, 36, Color(0.04, 0.0, 0.06, text_alpha))
	canvas.draw_string(font, text_origin + Vector2(text_shake.x, 0.0), label, HORIZONTAL_ALIGNMENT_CENTER, text_width, 36, Color(0.63, 0.20, 0.78, text_alpha))
	canvas.draw_string(font, text_origin + Vector2(text_shake.x - 1.0, -1.0), label, HORIZONTAL_ALIGNMENT_CENTER, text_width, 36, Color(0.78, 0.47, 0.90, text_alpha * 0.18))
	if runtime.dmk_freeze_active:
		for i in range(14):
			var angle: float = TAU * float(i) / 14.0 + float(now_msec) * 0.002
			var orbit_radius: float = 50.0 + sin(float(now_msec) * 0.004 + float(i) * 1.2) * 20.0
			var pos := Vector2(
				field_size.x * 0.5 + cos(angle) * orbit_radius,
				field_size.y * 0.5 + y_offset + sin(angle) * orbit_radius * 0.4
			) + shake_offset
			var particle_alpha: float = (70.0 / 255.0) * pulse * text_alpha
			if particle_alpha > 0.015:
				canvas.draw_circle(pos, 2.0 + float(i % 3), Color(0.18, 0.02, 0.25, particle_alpha))


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
