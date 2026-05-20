extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


func get_draw_constants(
	hologram_frames: float,
	base_visual_size: Vector2,
	base_paddle_width: float,
	feet_offset: float,
	starburst_frames: int
) -> Dictionary:
	return {
		"hologram_frames": hologram_frames,
		"base_visual_size": base_visual_size,
		"base_paddle_width": base_paddle_width,
		"feet_offset": feet_offset,
		"starburst_frames": starburst_frames,
	}


func draw_shadow_step_wave(canvas: CanvasItem, shake_offset: Vector2, runtime: Object) -> void:
	for i in range(runtime.shadow_wave_trail.size()):
		var pos: Vector2 = _get_vector2(runtime.shadow_wave_trail[i], Vector2.ZERO) + shake_offset
		var ratio: float = float(i + 1) / max(1.0, float(runtime.shadow_wave_trail.size()))
		var alpha: float = 0.08 + 0.26 * ratio
		var radius: float = 8.0 + 16.0 * ratio
		canvas.draw_circle(pos, radius, Color(0.42 + 0.18 * ratio, 0.18 * ratio, 0.96, alpha))
		canvas.draw_line(
			pos - Vector2(float(runtime.shadow_wave_dir) * radius * 1.5, 0.0),
			pos + Vector2(float(runtime.shadow_wave_dir) * radius * 1.5, 0.0),
			Color(0.70, 0.38, 1.0, alpha * 1.3),
			max(2.0, 5.0 * ratio),
			true
		)
	if not runtime.shadow_wave_active:
		return
	var center: Vector2 = runtime.shadow_wave_pos + shake_offset
	var dir := Vector2(float(runtime.shadow_wave_dir), 0.0)
	var perp := Vector2(0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.035)
	canvas.draw_circle(center, 34.0 + pulse * 5.0, Color(0.35, 0.02, 0.70, 0.22))
	canvas.draw_circle(center, 20.0 + pulse * 4.0, Color(0.86, 0.40, 1.0, 0.40))
	canvas.draw_line(center - dir * 40.0, center + dir * 32.0, Color(0.78, 0.28, 1.0, 0.60), 16.0, true)
	canvas.draw_line(center - dir * 30.0 + perp * 7.0, center + dir * 24.0 - perp * 4.0, Color(1.0, 0.78, 1.0, 0.78), 3.0, true)
	for i in range(4):
		var offset: float = 12.0 + float(i) * 11.0
		var spark_pos: Vector2 = center + dir * offset + perp * sin(float(i) + Time.get_ticks_msec() * 0.02) * 12.0
		canvas.draw_circle(spark_pos, 2.0 + float(i % 2), Color(1.0, 0.78, 1.0, 0.78))


func draw_shadow_step_hologram(canvas: CanvasItem, shake_offset: Vector2, runtime: Object, constants: Dictionary) -> void:
	if not runtime.shadow_hologram_active:
		return
	var t: float = clamp(runtime.shadow_hologram_frames / max(1.0, float(constants.get("hologram_frames", 30.0))), 0.0, 1.0)
	var ease_value: float = t * t * (3.0 - 2.0 * t)
	var paddle_scale: float = max(1.0, runtime.shadow_paddle_size.x / float(constants.get("base_paddle_width", 155.0)))
	var visual_size: Vector2 = _get_vector2(constants.get("base_visual_size", Vector2(160.0, 160.0)), Vector2(160.0, 160.0)) * paddle_scale
	var center_x: float = runtime.shadow_hologram_target.x
	var paddle_bottom_y: float = runtime.shadow_hologram_target.y + runtime.shadow_paddle_size.y * 0.5
	var visual_top_y: float = paddle_bottom_y + float(constants.get("feet_offset", 12.0)) - visual_size.y
	var attack_sheet: Texture2D = runtime._get_viper_hologram_attack_sheet(runtime.shadow_hologram_kick_dir)
	if attack_sheet == null:
		return
	var source_region: Rect2 = runtime._get_viper_hologram_attack_source_region(t)
	var now_ms: int = Time.get_ticks_msec()
	var shimmer: float = 1.0 - ease_value
	var shimmer_offset := Vector2(
		sin(float(now_ms) * 0.015) * 3.0 * shimmer,
		cos(float(now_ms) * 0.012) * 2.0 * shimmer
	)

	if t > 0.15:
		for i in range(8):
			var g_delay: float = float(i) * 0.02
			var g_local_t: float = (t - 0.15 - g_delay) / 0.25
			if g_local_t <= 0.0 or g_local_t > 1.0:
				continue
			var g_ease: float = min(1.0, g_local_t * g_local_t * 4.0)
			var g_offset_x: float = float(runtime.shadow_hologram_kick_dir) * g_ease * (8.0 + float(i) * 18.0)
			var g_fade: float = 1.0 - max(0.0, (g_local_t - 0.7) * 3.3)
			var g_alpha_byte: float = min(180.0, (120.0 - float(i) * 8.0) * min(1.0, g_local_t * 4.0) * g_fade)
			if g_alpha_byte <= 0.0:
				continue
			var ghost_rect := Rect2(
				center_x - visual_size.x * 0.5 + g_offset_x + shake_offset.x,
				visual_top_y + shake_offset.y,
				visual_size.x,
				visual_size.y
			)
			canvas.draw_texture_rect_region(
				attack_sheet,
				ghost_rect,
				source_region,
				Color(1.0, 1.0, 1.0, g_alpha_byte / 255.0),
				false,
				true
			)

	var main_alpha: float = ease_value
	if main_alpha <= 0.0:
		return
	var main_rect := Rect2(
		center_x - visual_size.x * 0.5 + shimmer_offset.x + shake_offset.x,
		visual_top_y + shimmer_offset.y + shake_offset.y,
		visual_size.x,
		visual_size.y
	)
	canvas.draw_texture_rect_region(
		attack_sheet,
		main_rect,
		source_region,
		Color(1.0, 1.0, 1.0, main_alpha),
		false,
		true
	)


func draw_shadow_starburst(canvas: CanvasItem, shake_offset: Vector2, runtime: Object, constants: Dictionary) -> void:
	if not runtime.shadow_starburst_active:
		return
	var frame_count: int = int(constants.get("starburst_frames", 5))
	var progress: float = clamp(float(runtime.shadow_starburst_frame) / max(1.0, float(frame_count - 1)), 0.0, 1.0)
	var center: Vector2 = runtime.shadow_starburst_pos + shake_offset
	var alpha: float = [0.78, 1.0, 0.86, 0.55, 0.24][clamp(runtime.shadow_starburst_frame, 0, frame_count - 1)]
	var max_radius: float = (90.0 if runtime.shadow_starburst_is_double else 50.0) + 12.0 * progress
	var burst_color := Color(0.96, 0.16, 1.0) if runtime.shadow_starburst_is_double else Color(0.86, 0.20, 1.0)
	ImpactFlareTextureCache.draw_burst(canvas, center, max_radius, burst_color, alpha * (0.72 - progress * 0.16))
	ImpactFlareTextureCache.draw_glow(canvas, center, max_radius * 0.58, Color(0.70, 0.0, 1.0), alpha * 0.36)
	ImpactFlareTextureCache.draw_sparkle(canvas, center, max_radius * 0.30, Color(1.0, 0.86, 1.0), alpha * 0.86)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, center, max_radius * 0.48, burst_color, alpha * 0.24)


func get_viper_hologram_attack_sheet(
	runtime: Object,
	kick_dir: int,
	left_sheet_path: String,
	right_sheet_path: String
) -> Texture2D:
	if kick_dir < 0:
		if runtime.viper_hologram_attack_left_sheet == null:
			runtime.viper_hologram_attack_left_sheet = ProjectResourceLoader.load_texture(
				left_sheet_path,
				"Missing Viper shadow-step hologram sheet at %s",
				"Failed to load Viper shadow-step hologram sheet at %s"
			)
		return runtime.viper_hologram_attack_left_sheet
	if runtime.viper_hologram_attack_right_sheet == null:
		runtime.viper_hologram_attack_right_sheet = ProjectResourceLoader.load_texture(
			right_sheet_path,
			"Missing Viper shadow-step hologram sheet at %s",
			"Failed to load Viper shadow-step hologram sheet at %s"
		)
	return runtime.viper_hologram_attack_right_sheet


func get_viper_hologram_attack_source_region(
	progress: float,
	frame_count: int,
	grid_columns: int,
	frame_size: Vector2
) -> Rect2:
	var frame: int = clamp(
		int(floor(clamp(progress, 0.0, 1.0) * float(frame_count))),
		0,
		frame_count - 1
	)
	var col: int = frame % grid_columns
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_columns)
	return Rect2(
		float(col) * frame_size.x,
		float(row) * frame_size.y,
		frame_size.x,
		frame_size.y
	)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
