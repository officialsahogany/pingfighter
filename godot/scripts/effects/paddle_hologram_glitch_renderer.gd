extends RefCounted

# Paddle hologram materialize / glitch reveal helper.
#
# Mirrors `apply_hologram_materialize_effect()` in pingfighter.py §122577.
# The original Python helper allocates a fresh SRCALPHA Surface every frame
# and writes per-row jitter, RGB ghost split, scanlines, noise particles,
# and edge glow lines into it. CLAUDE.md §Performance bans that pattern in
# pygame and only tolerates it because the materialize window is short.
#
# The Godot port reproduces the same visual classes (alpha fade, scanlines,
# RGB split, flicker, noise, edge glow) using procedural canvas draws on
# top of the multi-pass actor sprite render. The actor renderer is expected
# to:
#   1. Skip the entire actor draw when `should_draw == false`.
#   2. When `active == true`, call `compute_pass_plan()`, then run two ghost
#      passes (cyan / magenta) plus the main pass with the modulate the plan
#      provides, and finally call `draw_overlays()` on top of the visible
#      rect. If the plan reports `flicker_hidden = true`, skip every pass for
#      this frame — that is the original "fully invisible flicker beat".
#   3. When `active == false`, run the normal draw path.
#
# All numeric constants below come from the Python reference and were kept
# in sync. If the Python version is retuned, update the values here too.

const _NOISE_COUNT_MAX := 12


# Returns the per-frame materialize pass plan. The shape is intentionally
# verbose so the actor renderers do not need to re-derive any clamps.
#
# Keys returned:
#   flicker_hidden        : bool  — frame is fully invisible (skip all passes)
#   main_modulate         : Color — multiplied onto the existing player /
#                                    boss modulate for the main sprite pass
#   ghosts_active         : bool  — run the cyan / magenta passes this frame
#   color_shift_x         : float — horizontal offset for the ghost passes
#   cyan_modulate         : Color — modulate for the left-shifted cyan ghost
#   magenta_modulate      : Color — modulate for the right-shifted magenta
#                                    ghost
#   scanlines_active      : bool  — draw scanline rows in the overlay pass
#   scanline_spacing_px   : int   — vertical spacing between scanlines
#   scanline_alpha        : float — alpha multiplier for each scanline row
#   noise_active          : bool  — draw digital noise particles
#   noise_count           : int   — how many noise dots to draw this frame
#   noise_alpha_scale     : float — alpha multiplier for noise dots
#   edge_glow_active      : bool  — draw the top / bottom edge glow lines
#   edge_glow_alpha       : float — alpha for the edge glow lines
static func compute_pass_plan(progress: float, time_msec: int) -> Dictionary:
	var clamped_progress: float = clamp(progress, 0.0, 1.0)

	# Flicker (Python §122596-122605): for low progress the sprite occasionally
	# vanishes for a single frame.
	var flicker_hidden: bool = false
	if clamped_progress < 0.7:
		var flicker_frequency: float = 0.03 - clamped_progress * 0.025
		var flicker_visible: bool = sin(float(time_msec) * flicker_frequency * 10.0) > 0.0
		var random_flicker: bool = randf() < (0.3 - clamped_progress * 0.4)
		if random_flicker and not flicker_visible:
			flicker_hidden = true

	var base_alpha_normalized: float = (50.0 + clamped_progress * 205.0) / 255.0

	# RGB ghost split (Python §122642-122660). The ghost intensity fades out
	# as the sprite materializes. After progress >= 0.85 ghosts are off.
	var ghosts_active: bool = clamped_progress < 0.85
	var ghost_offset_strength: float = max(0.0, 1.0 - clamped_progress)
	var color_shift_x: float = ghost_offset_strength * 4.0
	var ghost_alpha_normalized: float = (50.0 / 255.0) * ghost_offset_strength
	var ghost_tint_strength: float = (30.0 / 255.0) * ghost_offset_strength

	var cyan_modulate := Color(
		max(0.0, 1.0 - ghost_tint_strength),
		1.0,
		1.0,
		ghost_alpha_normalized
	)
	var magenta_modulate := Color(
		1.0,
		max(0.0, 1.0 - ghost_tint_strength),
		1.0,
		ghost_alpha_normalized
	)

	# Scanlines (Python §122610-122624): spacing tightens from 8 px to 3 px.
	var scanlines_active: bool = clamped_progress < 0.9
	var scanline_spacing_px: int = max(2, int(round(8.0 - clamped_progress * 5.0)))
	var scanline_alpha: float = clamp((1.0 - clamped_progress) * 0.30, 0.0, 1.0)

	# Noise dots (Python §122662-122681): count drops to zero by progress 0.7.
	var noise_active: bool = clamped_progress < 0.7
	var noise_count: int = int(round((1.0 - clamped_progress) * float(_NOISE_COUNT_MAX)))
	var noise_alpha_scale: float = clamp(1.0 - clamped_progress, 0.0, 1.0)

	# Edge glow (Python §122683-122690): fades in after progress 0.3.
	var edge_glow_active: bool = clamped_progress > 0.3
	var edge_glow_alpha: float = clamp((clamped_progress - 0.3) * 0.40, 0.0, 0.40)

	return {
		"flicker_hidden": flicker_hidden,
		"main_modulate": Color(1.0, 1.0, 1.0, base_alpha_normalized),
		"ghosts_active": ghosts_active,
		"color_shift_x": color_shift_x,
		"cyan_modulate": cyan_modulate,
		"magenta_modulate": magenta_modulate,
		"scanlines_active": scanlines_active,
		"scanline_spacing_px": scanline_spacing_px,
		"scanline_alpha": scanline_alpha,
		"noise_active": noise_active,
		"noise_count": noise_count,
		"noise_alpha_scale": noise_alpha_scale,
		"edge_glow_active": edge_glow_active,
		"edge_glow_alpha": edge_glow_alpha,
	}


# Multiply the existing per-actor modulate by the materialize main-pass tint.
# Player paths build a modulate from slow + curse_reverse layers; boss path
# builds an EMP modulate. Both must run through this so the materialize alpha
# does not blow past upstream tint clamps.
static func combine_modulate(base: Color, plan: Dictionary) -> Color:
	var main_modulate: Color = plan.get("main_modulate", Color.WHITE)
	return Color(
		base.r * main_modulate.r,
		base.g * main_modulate.g,
		base.b * main_modulate.b,
		base.a * main_modulate.a
	)


# Top of the visible rect gets one bright glow line, bottom gets another;
# scanlines crawl down the rect every `scanline_spacing_px` rows; noise
# particles sprinkle inside.
static func draw_overlays(canvas: CanvasItem, visual_rect: Rect2, plan: Dictionary) -> void:
	if canvas == null or visual_rect.size.x <= 0.0 or visual_rect.size.y <= 0.0:
		return

	if bool(plan.get("scanlines_active", false)):
		var spacing: int = max(2, int(plan.get("scanline_spacing_px", 8)))
		var alpha: float = float(plan.get("scanline_alpha", 0.0))
		if alpha > 0.001:
			var scan_color := Color(0.0, 0.0, 0.0, alpha)
			var y: float = visual_rect.position.y
			var rect_bottom: float = visual_rect.position.y + visual_rect.size.y
			while y < rect_bottom:
				canvas.draw_rect(
					Rect2(visual_rect.position.x, y, visual_rect.size.x, 1.0),
					scan_color
				)
				y += float(spacing)

	if bool(plan.get("noise_active", false)):
		var count: int = int(plan.get("noise_count", 0))
		var alpha_scale: float = float(plan.get("noise_alpha_scale", 0.0))
		for _i in range(count):
			var nx: float = visual_rect.position.x + randf() * visual_rect.size.x
			var ny: float = visual_rect.position.y + randf() * visual_rect.size.y
			var noise_size: float = 1.0 + randf() * 2.0
			var color_choice: int = randi() % 3
			var noise_color: Color
			if color_choice == 0:
				noise_color = Color(0.0, 1.0, 1.0, 0.6 * alpha_scale)
			elif color_choice == 1:
				noise_color = Color(1.0, 0.0, 1.0, 0.6 * alpha_scale)
			else:
				noise_color = Color(1.0, 1.0, 1.0, 0.8 * alpha_scale)
			canvas.draw_rect(
				Rect2(nx, ny, noise_size, noise_size),
				noise_color
			)

	if bool(plan.get("edge_glow_active", false)):
		var glow_alpha: float = float(plan.get("edge_glow_alpha", 0.0))
		if glow_alpha > 0.001:
			var glow_color := Color(0.39, 0.78, 1.0, glow_alpha)
			var top_left := visual_rect.position
			var top_right := Vector2(visual_rect.position.x + visual_rect.size.x, visual_rect.position.y)
			var bottom_left := Vector2(visual_rect.position.x, visual_rect.position.y + visual_rect.size.y - 1.0)
			var bottom_right := visual_rect.position + visual_rect.size - Vector2(0.0, 1.0)
			canvas.draw_line(top_left, top_right, glow_color, 1.0)
			canvas.draw_line(bottom_left, bottom_right, glow_color, 1.0)
