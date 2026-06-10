extends RefCounted

const PillarDashOrbBodyRenderer := preload("res://scripts/hud/pillar_dash_orb_body_renderer.gd")
const PillarDashTokenRenderer := preload("res://scripts/hud/pillar_dash_token_renderer.gd")

const IDLE_RING_SEGMENTS := 14
const BOOST_RING_ARC_COUNT := 3
const BOOST_RING_ARC_COUNT_LOD := 2
const BOOST_RING_ARC_POINTS := 6
const BOOST_RING_ARC_POINTS_LOD := 4
const RECOVERY_INNER_LAYER_COUNT := 3
const RECOVERY_INNER_LAYER_COUNT_LOD := 1
const RECOVERY_SPARK_COUNT := 4
const RECOVERY_SPARK_COUNT_LOD := 2
const RECOVERY_SPARK_SEGMENTS := 3
const RECOVERY_SPARK_SEGMENTS_LOD := 2
const RECOVERY_PULL_RING_POINTS := 24
const RECOVERY_PULL_RING_POINTS_LOD := 14
const RECOVERY_CHAIN_ARC_COUNT := 3
const RECOVERY_CHAIN_ARC_COUNT_LOD := 1
const RECOVERY_CHAIN_ARC_POINTS := 9
const RECOVERY_CHAIN_ARC_POINTS_LOD := 6
const RECOVERY_SEAL_OUTER_POINTS := 20
const RECOVERY_SEAL_OUTER_POINTS_LOD := 12
const RECOVERY_SEAL_INNER_POINTS := 14
const RECOVERY_SEAL_INNER_POINTS_LOD := 10

var body_renderer: Object = PillarDashOrbBodyRenderer.new()
var token_renderer: Object = PillarDashTokenRenderer.new()


func prewarm_caches(orb_radius: float, context: Dictionary = {}) -> void:
	body_renderer.prewarm_caches(max(16.0, orb_radius), context)
	token_renderer.prewarm_caches(max(16.0, orb_radius), context)


func draw(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	if canvas == null:
		return

	var pillar_drawer = context.get("pillar_drawer", null)
	if pillar_drawer == null:
		return

	var radius: float = max(16.0, orb_radius)
	var frame_width_base: float = float(context.get("frame_width_base", 7.0))
	var frame_width: float = max(4.0, frame_width_base * scale_factor)
	var lod_active: bool = _is_hud_lod_active(context)
	var static_hud_lod := bool(context.get("pillar_hud_static_lod", false))
	var max_tokens: int = max(1, int(context.get("max_tokens", 1)))
	var available_tokens: int = clamp(int(context.get("tokens", 0)), 0, max_tokens)
	var recharge_frames: float = max(0.001, float(context.get("recharge_frames", 1.0)))
	var charge_progress: float = 0.0
	if context.has("charge_progress"):
		charge_progress = clamp(float(context.get("charge_progress", 0.0)), 0.0, 1.0)
	elif float(context.get("charge_timer", 0.0)) > 0.0 and available_tokens < max_tokens:
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
		frame_texture,
		context
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
		sector_angle,
		context
	)

	if frame_texture is Texture2D:
		var texture: Texture2D = frame_texture
		var spin_angle: float = _get_frame_spin_angle(context)
		pillar_drawer.draw_rotating_orb_frame_texture(canvas, texture, center, radius, spin_angle)

	var glass_rim_color: Color = _get_color(context, "glass_rim_color", Color(1.0, 0.56, 0.50, 1.0))
	if static_hud_lod and pillar_drawer.has_method("draw_pillar_orb_glass_lod"):
		pillar_drawer.draw_pillar_orb_glass_lod(canvas, center, radius, glass_rim_color)
	else:
		pillar_drawer.draw_pillar_orb_glass(canvas, center, radius, glass_rim_color)
	# The rainbow ring + sector + half-ready + recovery (plasma ball) overlays
	# migrated to the GPU shader host. When the host is wired into the context
	# we hand it the current state and skip the legacy CPU draws. The CPU paths
	# stay as a runtime fallback if the host is absent (e.g. during early boot
	# frames before deferred add_child lands, or in headless tests).
	var boost_fx_host: Object = context.get("boost_fx_host", null) as Object
	var fx_host_owns_boost := _sync_boost_fx_host(boost_fx_host, center, radius, t, scale_factor, context)
	if not fx_host_owns_boost and _has_boost_charging_visual(context) and not static_hud_lod:
		_draw_boost_charging_rainbow_ring(canvas, center, radius, t, scale_factor, lod_active)
	if _is_dash_recovering(context) and not fx_host_owns_boost:
		_draw_recovery_lock_effect(canvas, center, radius, scale_factor, true if static_hud_lod else lod_active)

	if flash_timer > 0.0 and not static_hud_lod:
		token_renderer.draw_flash(canvas, center, radius, flash_timer / flash_duration, scale_factor, context)

	var ring_phase: float = fmod(t * 0.9, 1.0)
	var ring_r: float = radius * (0.5 + ring_phase * 0.5)
	var ring_alpha: float = 0.0 if static_hud_lod else 0.10 * (1.0 - ring_phase)
	if ring_alpha > 0.01:
		var ring_color: Color = _get_color(context, "idle_ring_color", Color(1.0, 0.50, 0.40, 1.0))
		var idle_ring_segments: int = 14 if _is_hud_lod_active(context) else IDLE_RING_SEGMENTS
		canvas.draw_arc(center, ring_r, 0.0, TAU, idle_ring_segments, Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha), 1.5)

	if bool(context.get("show_count_text", true)):
		var count_text := "%d/%d" % [available_tokens, max_tokens]
		var count_font_size: int = int(round(16.0 * scale_factor))
		if static_hud_lod and pillar_drawer.has_method("draw_pillar_text_centered_lod"):
			pillar_drawer.draw_pillar_text_centered_lod(canvas, center, count_text, count_font_size, Color.WHITE)
		else:
			pillar_drawer.draw_pillar_text_centered(canvas, center, count_text, count_font_size, Color.WHITE)
	if bool(context.get("show_half_label", true)) and available_tokens <= 0 and float(context.get("dash_available_timer", 0.0)) <= 0.0 and not bool(context.get("dash_active", false)):
		var half_alpha: float = 0.50 + 0.30 * sin(t * 8.0)
		pillar_drawer.draw_pillar_text_centered(canvas, center + Vector2(0.0, radius + 20.0 * scale_factor), "HALF", int(round(10.0 * scale_factor)), Color(0.72, 0.76, 1.0, half_alpha))


func _is_dash_recovering(context: Dictionary) -> bool:
	return bool(context.get("dash_recovering", false)) or float(context.get("dash_stun_timer", 0.0)) > 0.0


func _has_boost_charging_visual(context: Dictionary) -> bool:
	return (
		bool(context.get("boost_charging_pending_dash_refund", false))
		or bool(context.get("boost_charging_active", false))
		or int(context.get("boost_charging_token_index", -1)) >= 0
	)


func _get_color(context: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = context.get(key, fallback)
	if value is Color:
		return value
	return fallback


func _is_hud_lod_active(context: Dictionary) -> bool:
	return float(context.get("hud_lod_scale", 1.0)) < 0.85


func _get_frame_spin_angle(context: Dictionary) -> float:
	# Static HUD LOD keeps costly ornamentals off, while preserving the cheap
	# event-triggered frame texture rotation for dash-token feedback.
	return float(context.get("frame_spin_angle", 0.0))


# Push the orb's boost / half-ready state into the shader FX host. Returns true
# if the host is valid and consumed the state (so the CPU rainbow ring path can
# be skipped). The slot ordering is driven by the call order from
# stage1_pillar_ui_renderer (player dash, then boss dash).
func _sync_boost_fx_host(
	boost_fx_host: Object,
	center: Vector2,
	radius: float,
	t: float,
	scale_factor: float,
	context: Dictionary
) -> bool:
	if boost_fx_host == null or not is_instance_valid(boost_fx_host):
		return false
	if not boost_fx_host.has_method("sync_slot"):
		return false
	var static_hud_lod := bool(context.get("pillar_hud_static_lod", false))
	if static_hud_lod:
		# Static LOD path keeps the orb visible but suppresses heavy overlays.
		boost_fx_host.sync_slot(center, radius, scale_factor, {
			"elapsed": t,
			"sector_intensity": 0.0,
			"rainbow_intensity": 0.0,
			"half_ready_intensity": 0.0,
		})
		return true
	var max_tokens: int = max(1, int(context.get("max_tokens", 1)))
	var available_tokens: int = clamp(int(context.get("tokens", 0)), 0, max_tokens)
	var recharge_frames: float = max(0.001, float(context.get("recharge_frames", 1.0)))
	var charge_progress: float = 0.0
	if context.has("charge_progress"):
		charge_progress = clamp(float(context.get("charge_progress", 0.0)), 0.0, 1.0)
	elif float(context.get("charge_timer", 0.0)) > 0.0 and available_tokens < max_tokens:
		charge_progress = clamp(1.0 - (float(context.get("charge_timer", 0.0)) / recharge_frames), 0.0, 1.0)
	var has_boost: bool = _has_boost_charging_visual(context)
	var sector_intensity := 0.0
	var sector_start := 0.0
	var sector_end := TAU
	var sector_progress := 0.0
	if has_boost and charge_progress > 0.0 and available_tokens < max_tokens:
		sector_intensity = 1.0
		sector_progress = charge_progress
		if max_tokens == 1:
			sector_start = 0.0
			sector_end = TAU
		else:
			var slot_angle: float = TAU / float(max_tokens)
			sector_start = -PI * 0.5 + slot_angle * float(available_tokens)
			sector_end = sector_start + slot_angle
	var rainbow_intensity := 0.0
	var rainbow_rotation := 0.0
	if has_boost:
		rainbow_intensity = 1.0
		rainbow_rotation = t * 2.4
	# Plasma ball replaces the previous CPU recovery lock effect (sparse sparks
	# + chain arcs + center seal). Triggered for the entire dash-recovering
	# window (dash_recovering OR dash_stun_timer > 0). Driven by the renderer's
	# token color palette so each character's dash orb keeps its identity.
	var plasma_ball_intensity := 0.0
	if _is_dash_recovering(context):
		plasma_ball_intensity = 1.0
	# Half-ready blink mirrors the existing "HALF" label gating: empty tokens,
	# no half-dash already running, no active dash, and the renderer expects the
	# HALF label to be on.
	var half_ready_intensity := 0.0
	if (
		bool(context.get("show_half_label", true))
		and available_tokens <= 0
		and float(context.get("dash_available_timer", 0.0)) <= 0.0
		and not bool(context.get("dash_active", false))
		and not _is_dash_recovering(context)
	):
		half_ready_intensity = 1.0
	var base_token_color: Color = _get_color(context, "token_full_color", Color(0.78, 0.16, 0.20, 1.0))
	var plasma_core_color: Color = _get_color(context, "plasma_core_color", Color(1.0, 0.86, 1.0, 1.0))
	var plasma_tendril_color: Color = _get_color(context, "plasma_tendril_color", Color(0.96, 0.40, 1.0, 1.0))
	var plasma_tendril_count: int = clamp(int(context.get("plasma_tendril_count", 5)), 2, 8)
	boost_fx_host.sync_slot(center, radius, scale_factor, {
		"elapsed": t,
		"sector_intensity": sector_intensity,
		"sector_progress": sector_progress,
		"sector_start_angle": sector_start,
		"sector_end_angle": sector_end,
		"rainbow_intensity": rainbow_intensity,
		"rainbow_rotation": rainbow_rotation,
		"half_ready_intensity": half_ready_intensity,
		"plasma_ball_intensity": plasma_ball_intensity,
		"plasma_core_color": plasma_core_color,
		"plasma_tendril_color": plasma_tendril_color,
		"plasma_tendril_count": plasma_tendril_count,
		"base_token_color": base_token_color,
	})
	return true


func _draw_boost_charging_rainbow_ring(canvas: CanvasItem, center: Vector2, radius: float, t: float, scale_factor: float, lod_active: bool) -> void:
	var rotation: float = t * 2.4
	var ring_radius: float = radius + max(2.0, 2.0 * scale_factor)
	var arc_count: int = BOOST_RING_ARC_COUNT_LOD if lod_active else BOOST_RING_ARC_COUNT
	var arc_points: int = BOOST_RING_ARC_POINTS_LOD if lod_active else BOOST_RING_ARC_POINTS
	for i in range(arc_count):
		var start_angle: float = rotation + TAU * float(i) / float(arc_count)
		var end_angle: float = start_angle + TAU / 8.0
		var arc_color: Color = _rainbow_color(t * 0.45 + float(i) / 6.0, 0.58)
		canvas.draw_arc(center, ring_radius, start_angle, end_angle, arc_points, arc_color, max(1.5, 2.8 * scale_factor), true)
	var glow_layers: int = 1 if lod_active else 2
	for layer in range(glow_layers):
		var glow_radius: float = radius + 10.0 * scale_factor + float(layer) * 5.0 * scale_factor
		var glow_color: Color = _rainbow_color(t * 0.35 + float(layer) * 0.22, 0.10 - float(layer) * 0.03)
		canvas.draw_circle(center, glow_radius, glow_color)


func _rainbow_color(phase: float, alpha: float = 1.0) -> Color:
	var h: float = fmod(phase, 1.0)
	if h < 0.0:
		h += 1.0
	var scaled: float = h * 6.0
	var c: float = 1.0
	var x: float = c * (1.0 - abs(fmod(scaled, 2.0) - 1.0))
	var rgb := Color(c, x, 0.0, alpha)
	if scaled < 1.0:
		rgb = Color(c, x, 0.0, alpha)
	elif scaled < 2.0:
		rgb = Color(x, c, 0.0, alpha)
	elif scaled < 3.0:
		rgb = Color(0.0, c, x, alpha)
	elif scaled < 4.0:
		rgb = Color(0.0, x, c, alpha)
	elif scaled < 5.0:
		rgb = Color(x, 0.0, c, alpha)
	else:
		rgb = Color(c, 0.0, x, alpha)
	return Color(
		clamp(rgb.r * 0.84 + 0.16, 0.0, 1.0),
		clamp(rgb.g * 0.84 + 0.16, 0.0, 1.0),
		clamp(rgb.b * 0.84 + 0.16, 0.0, 1.0),
		alpha
	)


func _draw_recovery_lock_effect(canvas: CanvasItem, center: Vector2, radius: float, scale_factor: float, lod_active: bool) -> void:
	var now_msec: float = float(Time.get_ticks_msec())
	var stun_pulse: float = 0.5 + 0.5 * sin(now_msec * 0.012)
	var stun_pulse_fast: float = 0.5 + 0.5 * sin(now_msec * 0.025)

	var inner_layers: int = RECOVERY_INNER_LAYER_COUNT_LOD if lod_active else RECOVERY_INNER_LAYER_COUNT
	for i in range(inner_layers):
		var inner_alpha: float = ((40.0 + 30.0 * stun_pulse) * (1.0 - float(i) * 0.15)) / 255.0
		var inner_radius: float = radius - 5.0 * scale_factor - float(i) * 6.0 * scale_factor
		if inner_radius > 0.0:
			canvas.draw_circle(center, inner_radius, Color(60.0 / 255.0, 20.0 / 255.0, 40.0 / 255.0, inner_alpha))

	_draw_recovery_sparks(canvas, center, radius, scale_factor, now_msec, stun_pulse_fast, lod_active)
	_draw_recovery_pull_ring(canvas, center, radius, scale_factor, now_msec, lod_active)
	_draw_recovery_chain_arcs(canvas, center, radius, scale_factor, now_msec, lod_active)
	_draw_recovery_seal(canvas, center, radius, scale_factor, stun_pulse, lod_active)


func _draw_recovery_sparks(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	scale_factor: float,
	now_msec: float,
	stun_pulse_fast: float,
	lod_active: bool
) -> void:
	var spark_count: int = RECOVERY_SPARK_COUNT_LOD if lod_active else RECOVERY_SPARK_COUNT
	var spark_segments: int = RECOVERY_SPARK_SEGMENTS_LOD if lod_active else RECOVERY_SPARK_SEGMENTS
	for i in range(spark_count):
		var spark_angle: float = fmod(now_msec * 0.4 + float(i) * 60.0, 360.0)
		var spark_rad: float = deg_to_rad(spark_angle)
		var spark_points := PackedVector2Array([center])
		var spark_length: float = max(1.0, radius - 10.0 * scale_factor)
		for segment_index in range(spark_segments):
			var progress: float = float(segment_index + 1) / float(spark_segments)
			var offset_angle: float = spark_rad + deg_to_rad(90.0) * (1.0 if segment_index % 2 == 0 else -1.0)
			var offset_dist: float = 8.0 * scale_factor * (1.0 - progress) * stun_pulse_fast
			var point := center + Vector2(cos(spark_rad), sin(spark_rad)) * spark_length * progress
			point += Vector2(cos(offset_angle), sin(offset_angle)) * offset_dist
			spark_points.append(point)
		var spark_alpha: float = (120.0 + 80.0 * stun_pulse_fast) / 255.0
		canvas.draw_polyline(spark_points, Color(1.0, 150.0 / 255.0, 200.0 / 255.0, spark_alpha * 0.5), max(1.0, 4.0 * scale_factor), true)
		canvas.draw_polyline(spark_points, Color(1.0, 220.0 / 255.0, 1.0, spark_alpha), max(1.0, 2.0 * scale_factor), true)


func _draw_recovery_pull_ring(canvas: CanvasItem, center: Vector2, radius: float, scale_factor: float, now_msec: float, lod_active: bool) -> void:
	var ring_phase: float = fmod(now_msec, 1500.0) / 1500.0
	var ring_radius: float = radius * (1.3 - ring_phase * 0.4)
	var ring_alpha: float = (150.0 * (1.0 - ring_phase * 0.7)) / 255.0
	if ring_alpha > 0.0:
		var point_count: int = RECOVERY_PULL_RING_POINTS_LOD if lod_active else RECOVERY_PULL_RING_POINTS
		canvas.draw_arc(center, ring_radius, 0.0, TAU, point_count, Color(200.0 / 255.0, 80.0 / 255.0, 120.0 / 255.0, ring_alpha), max(1.0, 2.0 * scale_factor), true)


func _draw_recovery_chain_arcs(canvas: CanvasItem, center: Vector2, radius: float, scale_factor: float, now_msec: float, lod_active: bool) -> void:
	var chain_angle: float = fmod(now_msec * 0.15, 360.0)
	var arc_count: int = RECOVERY_CHAIN_ARC_COUNT_LOD if lod_active else RECOVERY_CHAIN_ARC_COUNT
	var arc_points: int = RECOVERY_CHAIN_ARC_POINTS_LOD if lod_active else RECOVERY_CHAIN_ARC_POINTS
	for j in range(2):
		var offset: float = float(j) * 180.0
		var alpha_mod: float = 1.0 if j == 0 else 0.7
		for i in range(arc_count):
			var start_deg: float = chain_angle + offset + float(i) * (360.0 / float(arc_count))
			var end_deg: float = start_deg + 60.0
			canvas.draw_arc(
				center,
				radius,
				deg_to_rad(start_deg),
				deg_to_rad(end_deg),
				arc_points,
				Color(180.0 / 255.0, 60.0 / 255.0, 100.0 / 255.0, (80.0 * alpha_mod) / 255.0),
				max(1.0, 5.0 * scale_factor),
				true
			)
			canvas.draw_arc(
				center,
				radius,
				deg_to_rad(start_deg),
				deg_to_rad(end_deg),
				arc_points,
				Color(1.0, 180.0 / 255.0, 200.0 / 255.0, (180.0 * alpha_mod) / 255.0),
				max(1.0, 2.0 * scale_factor),
				true
			)


func _draw_recovery_seal(canvas: CanvasItem, center: Vector2, radius: float, scale_factor: float, stun_pulse: float, lod_active: bool) -> void:
	var seal_alpha: float = (180.0 + 75.0 * stun_pulse) / 255.0
	var seal_radius: float = radius * 0.35
	var outer_points: int = RECOVERY_SEAL_OUTER_POINTS_LOD if lod_active else RECOVERY_SEAL_OUTER_POINTS
	var inner_points: int = RECOVERY_SEAL_INNER_POINTS_LOD if lod_active else RECOVERY_SEAL_INNER_POINTS
	canvas.draw_arc(center, seal_radius, 0.0, TAU, outer_points, Color(200.0 / 255.0, 100.0 / 255.0, 130.0 / 255.0, seal_alpha), max(1.0, 3.0 * scale_factor), true)
	canvas.draw_arc(center, seal_radius * 0.5, 0.0, TAU, inner_points, Color(1.0, 180.0 / 255.0, 200.0 / 255.0, seal_alpha), max(1.0, 2.0 * scale_factor), true)
	canvas.draw_circle(center, max(1.0, 3.0 * scale_factor), Color(1.0, 220.0 / 255.0, 230.0 / 255.0, seal_alpha))
