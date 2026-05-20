extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")


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
	var base_center: Vector2 = runtime.dual_glitch_base_pos + runtime.dual_glitch_paddle_size * 0.5 + shake_offset
	if runtime.dual_glitch_state == "startup":
		var prep_t: float = clamp(runtime.dual_glitch_phase_frames / max(1.0, float(constants.get("startup_frames", 48.0))), 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(tick * 0.022)
		ImpactFlareTextureCache.draw_glow(canvas, base_center, 42.0 + prep_t * 38.0 + pulse * 8.0, Color(0.26, 0.96, 1.0), 0.20 + prep_t * 0.16)
		for ring_index in range(3):
			var radius: float = 28.0 + prep_t * 72.0 + float(ring_index) * 16.0
			var alpha: float = (0.30 - float(ring_index) * 0.06) * (0.45 + pulse * 0.55)
			ImpactShockwaveTextureCache.draw_full_ring(canvas, base_center, radius, Color(0.75, 0.36, 1.0), alpha)
		var offset_x: float = max(1.0, runtime.dual_glitch_paddle_size.x + float(constants.get("offset_padding", -15.0)))
		for side in [-1, 1]:
			var clone_center: Vector2 = base_center + Vector2(float(side) * offset_x * prep_t, 0.0)
			canvas.draw_line(base_center, clone_center, Color(0.34, 0.95, 1.0, 0.22 + prep_t * 0.24), 2.0, true)
			canvas.draw_rect(
				Rect2(clone_center - runtime.dual_glitch_paddle_size * 0.5, runtime.dual_glitch_paddle_size),
				Color(0.56, 0.20, 0.92, 0.08 + prep_t * 0.14),
				false,
				2.0
			)

	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var rect: Rect2 = entry.get("rect", Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var state_alpha: float = float(constants.get("alpha", 0.63))
		if runtime.dual_glitch_state == "spawn":
			state_alpha *= clamp(runtime.dual_glitch_phase_frames / max(1.0, float(constants.get("spawn_frames", 22.8))), 0.0, 1.0)
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
