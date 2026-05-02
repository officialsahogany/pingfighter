extends RefCounted

const PillarDashOrbBodyRenderer := preload("res://scripts/hud/pillar_dash_orb_body_renderer.gd")
const PillarDashTokenRenderer := preload("res://scripts/hud/pillar_dash_token_renderer.gd")

var body_renderer: Object = PillarDashOrbBodyRenderer.new()
var token_renderer: Object = PillarDashTokenRenderer.new()


func draw(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	if canvas == null:
		return

	var pillar_drawer = context.get("pillar_drawer", null)
	if pillar_drawer == null:
		return

	var radius: float = max(16.0, orb_radius)
	var frame_width_base: float = float(context.get("frame_width_base", 7.0))
	var frame_width: float = max(4.0, frame_width_base * scale_factor)
	var max_tokens: int = max(1, int(context.get("max_tokens", 1)))
	var available_tokens: int = clamp(int(context.get("tokens", 0)), 0, max_tokens)
	var recharge_frames: float = max(0.001, float(context.get("recharge_frames", 1.0)))
	var charge_progress: float = 0.0
	if float(context.get("charge_timer", 0.0)) > 0.0 and available_tokens < max_tokens:
		charge_progress = clamp(1.0 - (float(context.get("charge_timer", 0.0)) / recharge_frames), 0.0, 1.0)

	var flash_duration: float = max(0.001, float(context.get("flash_duration", 1.0)))
	var flash_timer: float = max(0.0, float(context.get("flash_timer", 0.0)))
	var frame_texture = context.get("frame_texture", null)
	body_renderer.draw(
		canvas,
		pillar_drawer,
		center,
		radius,
		frame_width,
		t,
		available_tokens,
		max_tokens,
		flash_timer,
		flash_duration,
		frame_texture
	)

	var inner_radius: float = radius - 5.0 * scale_factor
	var start_angle_offset: float = -PI * 0.5
	var sector_angle: float = TAU / float(max_tokens)

	token_renderer.draw_tokens(
		canvas,
		pillar_drawer,
		center,
		inner_radius,
		max_tokens,
		available_tokens,
		charge_progress,
		t,
		scale_factor,
		float(context.get("dash_divider_anim_progress", 1.0)),
		start_angle_offset,
		sector_angle
	)

	if frame_texture is Texture2D:
		var texture: Texture2D = frame_texture
		pillar_drawer.draw_rotating_orb_frame_texture(canvas, texture, center, radius, float(context.get("frame_spin_angle", 0.0)))

	pillar_drawer.draw_pillar_orb_glass(canvas, center, radius, Color(1.0, 0.56, 0.50, 1.0))

	if flash_timer > 0.0:
		token_renderer.draw_flash(canvas, center, radius, flash_timer / flash_duration, scale_factor)

	var ring_phase: float = fmod(t * 0.9, 1.0)
	var ring_r: float = radius * (0.5 + ring_phase * 0.5)
	var ring_alpha: float = 0.10 * (1.0 - ring_phase)
	if ring_alpha > 0.01:
		canvas.draw_arc(center, ring_r, 0.0, TAU, 32, Color(1.0, 0.50, 0.40, ring_alpha), 1.5)

	pillar_drawer.draw_pillar_text_centered(canvas, center, "%d/%d" % [available_tokens, max_tokens], int(round(16.0 * scale_factor)), Color.WHITE)
	if available_tokens <= 0 and float(context.get("dash_available_timer", 0.0)) <= 0.0 and not bool(context.get("dash_active", false)):
		var half_alpha: float = 0.50 + 0.30 * sin(t * 8.0)
		pillar_drawer.draw_pillar_text_centered(canvas, center + Vector2(0.0, radius + 20.0 * scale_factor), "HALF", int(round(10.0 * scale_factor)), Color(0.72, 0.76, 1.0, half_alpha))
