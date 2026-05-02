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
	if _is_dash_recovering(context):
		_draw_recovery_lock_effect(canvas, center, radius, scale_factor)

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


func _is_dash_recovering(context: Dictionary) -> bool:
	return bool(context.get("dash_recovering", false)) or float(context.get("dash_stun_timer", 0.0)) > 0.0


func _draw_recovery_lock_effect(canvas: CanvasItem, center: Vector2, radius: float, scale_factor: float) -> void:
	var now_msec: float = float(Time.get_ticks_msec())
	var stun_pulse: float = 0.5 + 0.5 * sin(now_msec * 0.012)
	var stun_pulse_fast: float = 0.5 + 0.5 * sin(now_msec * 0.025)

	for i in range(5):
		var inner_alpha: float = ((40.0 + 30.0 * stun_pulse) * (1.0 - float(i) * 0.15)) / 255.0
		var inner_radius: float = radius - 5.0 * scale_factor - float(i) * 6.0 * scale_factor
		if inner_radius > 0.0:
			canvas.draw_circle(center, inner_radius, Color(60.0 / 255.0, 20.0 / 255.0, 40.0 / 255.0, inner_alpha))

	_draw_recovery_sparks(canvas, center, radius, scale_factor, now_msec, stun_pulse_fast)
	_draw_recovery_pull_ring(canvas, center, radius, scale_factor, now_msec)
	_draw_recovery_chain_arcs(canvas, center, radius, scale_factor, now_msec)
	_draw_recovery_seal(canvas, center, radius, scale_factor, stun_pulse)


func _draw_recovery_sparks(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	scale_factor: float,
	now_msec: float,
	stun_pulse_fast: float
) -> void:
	for i in range(6):
		var spark_angle: float = fmod(now_msec * 0.4 + float(i) * 60.0, 360.0)
		var spark_rad: float = deg_to_rad(spark_angle)
		var spark_points := PackedVector2Array([center])
		var spark_length: float = max(1.0, radius - 10.0 * scale_factor)
		for segment_index in range(4):
			var progress: float = float(segment_index + 1) / 4.0
			var offset_angle: float = spark_rad + deg_to_rad(90.0) * (1.0 if segment_index % 2 == 0 else -1.0)
			var offset_dist: float = 8.0 * scale_factor * (1.0 - progress) * stun_pulse_fast
			var point := center + Vector2(cos(spark_rad), sin(spark_rad)) * spark_length * progress
			point += Vector2(cos(offset_angle), sin(offset_angle)) * offset_dist
			spark_points.append(point)
		var spark_alpha: float = (120.0 + 80.0 * stun_pulse_fast) / 255.0
		canvas.draw_polyline(spark_points, Color(1.0, 150.0 / 255.0, 200.0 / 255.0, spark_alpha * 0.5), max(1.0, 4.0 * scale_factor), true)
		canvas.draw_polyline(spark_points, Color(1.0, 220.0 / 255.0, 1.0, spark_alpha), max(1.0, 2.0 * scale_factor), true)


func _draw_recovery_pull_ring(canvas: CanvasItem, center: Vector2, radius: float, scale_factor: float, now_msec: float) -> void:
	var ring_phase: float = fmod(now_msec, 1500.0) / 1500.0
	var ring_radius: float = radius * (1.3 - ring_phase * 0.4)
	var ring_alpha: float = (150.0 * (1.0 - ring_phase * 0.7)) / 255.0
	if ring_alpha > 0.0:
		canvas.draw_arc(center, ring_radius, 0.0, TAU, 64, Color(200.0 / 255.0, 80.0 / 255.0, 120.0 / 255.0, ring_alpha), max(1.0, 2.0 * scale_factor), true)


func _draw_recovery_chain_arcs(canvas: CanvasItem, center: Vector2, radius: float, scale_factor: float, now_msec: float) -> void:
	var chain_angle: float = fmod(now_msec * 0.15, 360.0)
	for j in range(2):
		var offset: float = float(j) * 180.0
		var alpha_mod: float = 1.0 if j == 0 else 0.7
		for i in range(4):
			var start_deg: float = chain_angle + offset + float(i) * 90.0
			var end_deg: float = start_deg + 60.0
			canvas.draw_arc(
				center,
				radius,
				deg_to_rad(start_deg),
				deg_to_rad(end_deg),
				18,
				Color(180.0 / 255.0, 60.0 / 255.0, 100.0 / 255.0, (80.0 * alpha_mod) / 255.0),
				max(1.0, 5.0 * scale_factor),
				true
			)
			canvas.draw_arc(
				center,
				radius,
				deg_to_rad(start_deg),
				deg_to_rad(end_deg),
				18,
				Color(1.0, 180.0 / 255.0, 200.0 / 255.0, (180.0 * alpha_mod) / 255.0),
				max(1.0, 2.0 * scale_factor),
				true
			)


func _draw_recovery_seal(canvas: CanvasItem, center: Vector2, radius: float, scale_factor: float, stun_pulse: float) -> void:
	var seal_alpha: float = (180.0 + 75.0 * stun_pulse) / 255.0
	var seal_radius: float = radius * 0.35
	canvas.draw_arc(center, seal_radius, 0.0, TAU, 48, Color(200.0 / 255.0, 100.0 / 255.0, 130.0 / 255.0, seal_alpha), max(1.0, 3.0 * scale_factor), true)
	canvas.draw_arc(center, seal_radius * 0.5, 0.0, TAU, 36, Color(1.0, 180.0 / 255.0, 200.0 / 255.0, seal_alpha), max(1.0, 2.0 * scale_factor), true)
	canvas.draw_circle(center, max(1.0, 3.0 * scale_factor), Color(1.0, 220.0 / 255.0, 230.0 / 255.0, seal_alpha))
