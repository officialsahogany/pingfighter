extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

# 원본 VIPER_DUAL_GLITCH_RGB_SPLIT = ((255,70,120), (70,255,150), (70,180,255)) 정규화.
const DUAL_GLITCH_RGB_SPLIT: Array[Color] = [
	Color(1.0, 0.275, 0.471),
	Color(0.275, 1.0, 0.588),
	Color(0.275, 0.706, 1.0),
]


func get_draw_constants(
	startup_frames: float,
	spawn_frames: float,
	fade_frames: float,
	evaporation_frames: float,
	offset_padding: float,
	alpha: float,
	wiggle_amplitude: float
) -> Dictionary:
	return {
		"startup_frames": startup_frames,
		"spawn_frames": spawn_frames,
		"fade_frames": fade_frames,
		"evaporation_frames": evaporation_frames,
		"offset_padding": offset_padding,
		"alpha": alpha,
		"wiggle_amplitude": wiggle_amplitude,
	}


static func compute_dual_glitch_spawn_alpha_factor(phase_frames: float, spawn_frames: float = 22.8) -> float:
	var progress: float = clamp(phase_frames / max(1.0, spawn_frames), 0.0, 1.0)
	var pulse_amp: float = pow(1.0 - progress, 0.7) * 0.7
	var pulse: float = abs(sin(progress * TAU * 2.0))
	return clamp(progress * (1.0 - pulse_amp * (1.0 - pulse)), 0.0, 1.0)


func draw_dual_glitch_runtime_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	runtime: Object,
	entries: Array,
	startup_frames: float,
	spawn_frames: float,
	fade_frames: float,
	evaporation_frames: float,
	offset_padding: float,
	alpha: float,
	wiggle_amplitude: float
) -> void:
	if runtime.dual_glitch_state == "idle" and runtime.dual_glitch_clones.is_empty():
		return
	draw_dual_glitch_effects(
		canvas,
		shake_offset,
		runtime,
		entries,
		get_draw_constants(
			startup_frames,
			spawn_frames,
			fade_frames,
			evaporation_frames,
			offset_padding,
			alpha,
			wiggle_amplitude
		)
	)


func draw_dual_glitch_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	runtime: Object,
	entries: Array,
	constants: Dictionary
) -> void:
	if runtime.dual_glitch_state == "idle" and runtime.dual_glitch_clones.is_empty():
		return
	var tick: float = float(Time.get_ticks_msec())
	if runtime.dual_glitch_state == "startup":
		# 원본 draw_viper_dual_glitch_effect() startup 브랜치 복원:
		# 플레이어 발밑 기준 RGB 분리 차징 링 3겹 + 발밑을 도는 8개 스파크.
		var prep_t: float = clamp(runtime.dual_glitch_phase_frames / max(1.0, float(constants.get("startup_frames", 48.0))), 0.0, 1.0)
		var foot: Vector2 = runtime.dual_glitch_base_pos + Vector2(runtime.dual_glitch_paddle_size.x * 0.5, runtime.dual_glitch_paddle_size.y) + shake_offset
		# 동심 RGB 분리 윤곽 링: ring_r 18 -> 36, idx별 반지름/알파 스텝.
		# 원본 blit: (foot_y - ring_r + 6) + local center (ring_r + 4) = foot_y + 10.
		var ring_center: Vector2 = foot + Vector2(0.0, 10.0)
		var ring_r: float = 18.0 + prep_t * 18.0
		for idx in range(DUAL_GLITCH_RGB_SPLIT.size()):
			var ring_radius: float = max(4.0, ring_r - float(idx) * 4.0)
			var ring_alpha: float = max(30.0, 110.0 - float(idx) * 25.0) / 255.0
			var ring_color: Color = DUAL_GLITCH_RGB_SPLIT[idx]
			canvas.draw_arc(ring_center, ring_radius, 0.0, TAU, 48, Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha), 2.0, true)
		# 발밑을 회전하며 확장하는 8개 RGB 스파크(짧은 세로선).
		for spark_idx in range(8):
			var angle: float = (float(spark_idx) / 8.0) * TAU + tick * 0.01
			var spark_radius: float = 10.0 + prep_t * 20.0 + sin(tick * 0.02 + float(spark_idx)) * 3.0
			var sx: float = foot.x + cos(angle) * spark_radius
			var sy: float = foot.y - 6.0 + sin(angle * 1.4) * 6.0
			var line_len: float = max(2.0, 3.0 + prep_t * 4.0)
			canvas.draw_line(Vector2(sx, sy), Vector2(sx, sy - line_len), DUAL_GLITCH_RGB_SPLIT[spark_idx % DUAL_GLITCH_RGB_SPLIT.size()], 2.0, true)
	elif runtime.dual_glitch_state == "fade":
		# 원본 draw_viper_dual_glitch_effect() fade 브랜치 복원:
		# 발밑에서 흩어지는 6개 RGB 분리 글리치 블록(소멸 연출).
		var foot: Vector2 = runtime.dual_glitch_base_pos + Vector2(runtime.dual_glitch_paddle_size.x * 0.5, runtime.dual_glitch_paddle_size.y) + shake_offset
		var fade_progress: float = clamp(runtime.dual_glitch_phase_frames / max(1.0, float(constants.get("fade_frames", 18.0))), 0.0, 1.0)
		var fade_alpha: float = float(constants.get("alpha", 0.63)) * (1.0 - fade_progress)
		var block_alpha: float = max(25.0 / 255.0, fade_alpha * 0.5)
		for block_idx in range(6):
			var block_w: float = 6.0 + float(block_idx) * 2.0
			var block_h: float = 2.0 + float(block_idx % 2)
			var bx: float = foot.x - 18.0 + float(block_idx) * 6.0
			var by: float = foot.y - 16.0 + float(block_idx % 3) * 4.0
			var block_color: Color = DUAL_GLITCH_RGB_SPLIT[block_idx % DUAL_GLITCH_RGB_SPLIT.size()]
			canvas.draw_rect(Rect2(Vector2(bx, by), Vector2(block_w, block_h)), Color(block_color.r, block_color.g, block_color.b, block_alpha), true)

	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var rect: Rect2 = entry.get("rect", Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var state_alpha: float = float(constants.get("alpha", 0.63))
		if runtime.dual_glitch_state == "spawn":
			state_alpha *= compute_dual_glitch_spawn_alpha_factor(runtime.dual_glitch_phase_frames, float(constants.get("spawn_frames", 22.8)))
		elif runtime.dual_glitch_state == "fade":
			state_alpha *= 1.0 - clamp(runtime.dual_glitch_phase_frames / max(1.0, float(constants.get("fade_frames", 18.0))), 0.0, 1.0)
		if bool(entry.get("evaporating", false)):
			state_alpha *= 1.0 - clamp(float(entry.get("evaporation_frames", 0.0)) / max(1.0, float(constants.get("evaporation_frames", 13.2))), 0.0, 1.0)
		if state_alpha <= 0.02:
			continue
		var side: int = int(entry.get("side", 0))
		var index: int = int(entry.get("index", 0))
		var jitter_x: float = sin(tick * 0.035 + float(index) * 1.7) * float(constants.get("wiggle_amplitude", 3.0))
		rect.position += shake_offset + Vector2(jitter_x, 0.0)
		var center: Vector2 = rect.get_center()
		var accent_color := Color(0.32, 1.0, 0.94, state_alpha)
		var split_color := Color(1.0, 0.28, 0.92, state_alpha)
		if side < 0:
			accent_color = Color(0.86, 0.32, 1.0, state_alpha)
			split_color = Color(0.22, 1.0, 0.96, state_alpha)
		ImpactFlareTextureCache.draw_glow(canvas, center, max(28.0, rect.size.y * 0.64), accent_color, state_alpha * 0.10)
		canvas.draw_circle(center + Vector2(-rect.size.x * 0.18, -2.0), 3.0, Color(accent_color.r, accent_color.g, accent_color.b, state_alpha * 0.42))
		canvas.draw_circle(center + Vector2(rect.size.x * 0.18, 2.0), 2.0, Color(split_color.r, split_color.g, split_color.b, state_alpha * 0.36))
