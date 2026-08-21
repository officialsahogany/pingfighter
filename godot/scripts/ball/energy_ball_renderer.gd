extends RefCounted

const EnergyBallOrbitRenderer := preload("res://scripts/ball/energy_ball_orbit_renderer.gd")
const EnergyBallFxHost := preload("res://scripts/ball/energy_ball_fx_host.gd")
const EnergyBallParticleRenderer := preload("res://scripts/ball/energy_ball_particle_renderer.gd")
const EnergyBallTextureCache := preload("res://scripts/ball/energy_ball_texture_cache.gd")
const BallDeformationTextureQuad := preload("res://scripts/ball/ball_deformation_texture_quad.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const BALL_VISUAL_SCALE := 1.575
const BALL_RENDER_RADIUS := 16.9 * BALL_VISUAL_SCALE
const BALL_BRIGHTNESS := 0.72
# Python renders the energy ball to an alpha surface and BLEND_ADDs it, so
# these are tuned brighter for Godot's direct alpha-blended draw calls.
const BALL_OUTER_COLOR := Color(135.0 / 255.0, 205.0 / 255.0, 255.0 / 255.0)
const BALL_INNER_COLOR := Color(225.0 / 255.0, 248.0 / 255.0, 255.0 / 255.0)
const BALL_RING_COLOR := Color(185.0 / 255.0, 232.0 / 255.0, 255.0 / 255.0)
const BALL_CORE_COLOR := Color(1.0, 1.0, 1.0)
const BALL_CORE_SCALE := 0.75
const BALL_SOLID_CORE_SCALE := 0.64
const BALL_CORE_HIGHLIGHT_SCALE := 0.82
const BALL_DIMENSIONAL_CORE_MAIN := Color(0.78, 0.96, 1.0, 0.96)
const BALL_DIMENSIONAL_CORE_CYAN := Color(0.58, 1.0, 0.94, 0.34)
const BALL_DIMENSIONAL_CORE_VIOLET := Color(0.80, 0.72, 1.0, 0.32)
const BALL_DIMENSIONAL_CORE_HIGHLIGHT := Color(0.86, 0.99, 1.0, 0.94)
const SATURN_RING_BASE_ALPHA := 0.34
const SATURN_RING_FRONT_ALPHA := 0.46
const SATURN_RING_SPIN_SPEEDS := [44.0, -31.0]
const SATURN_RING_BASE_ROTATIONS := [10.0, 102.0]
const SATURN_RING_RADIUS_MULTS := [1.02, 1.16]
const SATURN_RING_TILT_BASES := [0.90, 1.05]
const SATURN_RING_ALPHA_MULTS := [1.0, 0.70]
const DRIVE_OUTER_COLOR := Color(0.80, 1.0, 0.46)
const DRIVE_INNER_COLOR := Color(0.90, 1.0, 0.78)
const DRIVE_RING_COLOR := Color(1.0, 0.88, 0.32)
const POWER_OUTER_COLOR := Color(1.0, 0.34, 0.12)
const POWER_INNER_COLOR := Color(1.0, 0.78, 0.46)
const POWER_RING_COLOR := Color(1.0, 0.54, 0.18)
const GHOST_OUTER_COLOR := Color(0.10, 0.012, 0.20)
const GHOST_INNER_COLOR := Color(0.42, 0.10, 0.70)
const GHOST_RING_COLOR := Color(0.78, 0.23, 1.0)
const GHOST_CORE_COLOR := Color(0.18, 0.025, 0.28, 0.96)
const GHOST_HIGHLIGHT_COLOR := Color(0.86, 0.55, 1.0)
const SKILL_FX_NONE := ""
const SKILL_FX_DRIVE := "drive"
const SKILL_FX_POWER := "power_smashing"
const SKILL_FX_GHOST := "ghost_shot"
const SEVERE_LOD_PARTICLE_DRAW_MIN_SCALE := 0.50
const PREWARM_LOCAL_STEP_COUNT := 7
const RUNTIME_NODE_PREWARM_SCREEN_POS := Vector2(-100000.0, -100000.0)

var particle_renderer: Object = EnergyBallParticleRenderer.new()
var orbit_renderer: Object = EnergyBallOrbitRenderer.new()
var fx_host: Node = null
var fx_host_add_pending := false
var _prewarm_assets_step_index := 0
var _prewarm_runtime_nodes_step_index := 0
# draw() resets this before any private draw helper runs. Any future drawing
# entry point must set it explicitly too, so a prior phantom draw cannot leak.
var _draw_alpha := 1.0
var _draw_deformation: Dictionary = {}


func _init() -> void:
	pass


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_assets_step_index < PREWARM_LOCAL_STEP_COUNT:
		match _prewarm_assets_step_index:
			0:
				EnergyBallTextureCache.get_core_texture()
			1:
				EnergyBallTextureCache.get_highlight_texture()
			2:
				EnergyBallTextureCache.get_saturn_ring_texture(false)
			3:
				EnergyBallTextureCache.get_saturn_ring_texture(true)
			4:
				ImpactFlareTextureCache.get_glow_texture()
			5:
				ImpactFlareTextureCache.get_burst_texture()
			6:
				ImpactFlareTextureCache.get_sparkle_texture()
		_prewarm_assets_step_index += 1
		return false
	if not EnergyBallFxHost.prewarm_assets_step():
		return false
	_prewarm_assets_step_index += 1
	return true


func prewarm_runtime_nodes(owner: Object = null) -> void:
	while not prewarm_runtime_nodes_step(owner):
		pass


func prewarm_runtime_nodes_step(owner: Object = null) -> bool:
	if not _ensure_fx_host(owner):
		_prewarm_runtime_nodes_step_index = 0
		return true
	if _prewarm_runtime_nodes_step_index == 0:
		_sync_runtime_node_prewarm()
		_prewarm_runtime_nodes_step_index = 1
		return false
	_deactivate_fx_host()
	_prewarm_runtime_nodes_step_index = 0
	return true


func _ensure_fx_host(owner: Object = null) -> bool:
	if _is_valid_fx_host():
		return true
	if not (owner is Node):
		return false
	var parent := owner as Node
	var existing: Node = parent.get_node_or_null("EnergyBallFxHost")
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		fx_host = existing
	else:
		fx_host = EnergyBallFxHost.new()
		fx_host.name = "EnergyBallFxHost"
		parent.add_child(fx_host)
	fx_host_add_pending = false
	return _is_valid_fx_host()


func clear() -> void:
	_draw_deformation = {}
	particle_renderer.clear()
	hide_node_fx()


func draw(
	canvas: CanvasItem,
	pos: Vector2,
	boost_charging_active: bool,
	ball_vel: Vector2 = Vector2.ZERO,
	node_fx_layout: Dictionary = {},
	hit_pulse_event: Dictionary = {},
	skill_fx_mode: String = "",
	enable_node_fx: bool = true,
	fx_lod_scale: float = 1.0,
	visual_alpha: float = 1.0,
	contact_deformation: Dictionary = {}
) -> void:
	_draw_alpha = clampf(visual_alpha, 0.0, 1.0)
	_draw_deformation = contact_deformation if bool(contact_deformation.get("active", false)) else {}
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	var lod_radius_scale: float = lerp(0.80, 1.0, lod_scale)
	var current_time_ms: float = float(Time.get_ticks_msec())
	var t: float = current_time_ms / 1000.0
	var speed_pulse: float = clamp(ball_vel.length() / 24.0, 0.0, 1.0)
	var skill_mode: String = _normalize_skill_fx_mode(skill_fx_mode)
	var skill_strength: float = _get_skill_fx_strength(skill_mode, speed_pulse)
	var pulse: float = sin(t * 7.5) * 0.08 + 1.0
	var pulse2: float = sin(t * 10.0) * 0.06 + 1.0
	var core_pulse: float = 1.0 + sin(t * 9.0) * 0.012 + speed_pulse * 0.025 + skill_strength * 0.035
	var ball_outer_color: Color = BALL_OUTER_COLOR
	var ball_inner_color: Color = BALL_INNER_COLOR
	var ball_ring_color: Color = BALL_RING_COLOR
	var ball_core_color: Color = BALL_CORE_COLOR

	if boost_charging_active:
		var hue: float = fmod(current_time_ms * 0.003, 1.0)
		var rainbow: Color = _hsv_unit_to_rgb(hue)
		ball_outer_color = Color(
			(rainbow.r * 200.0 + 55.0) / 255.0,
			(rainbow.g * 200.0 + 55.0) / 255.0,
			(rainbow.b * 200.0 + 55.0) / 255.0
		)
		ball_inner_color = Color(
			(rainbow.r * 150.0 + 105.0) / 255.0,
			(rainbow.g * 150.0 + 105.0) / 255.0,
			(rainbow.b * 150.0 + 105.0) / 255.0
		)
		ball_ring_color = ball_outer_color
		ball_core_color = Color(
			(rainbow.r * 100.0 + 155.0) / 255.0,
			(rainbow.g * 100.0 + 155.0) / 255.0,
			(rainbow.b * 100.0 + 155.0) / 255.0
	)
	if skill_mode == SKILL_FX_DRIVE:
		var drive_mix: float = 0.42 + skill_strength * 0.16
		ball_outer_color = ball_outer_color.lerp(DRIVE_OUTER_COLOR, drive_mix)
		ball_inner_color = ball_inner_color.lerp(DRIVE_INNER_COLOR, 0.34 + skill_strength * 0.12)
		ball_ring_color = ball_ring_color.lerp(DRIVE_RING_COLOR, 0.52 + skill_strength * 0.16)
		ball_core_color = ball_core_color.lerp(Color(1.0, 0.96, 0.74), 0.24 + skill_strength * 0.08)
	elif skill_mode == SKILL_FX_POWER:
		var power_mix: float = 0.54 + skill_strength * 0.18
		ball_outer_color = ball_outer_color.lerp(POWER_OUTER_COLOR, power_mix)
		ball_inner_color = ball_inner_color.lerp(POWER_INNER_COLOR, 0.42 + skill_strength * 0.15)
		ball_ring_color = ball_ring_color.lerp(POWER_RING_COLOR, 0.60 + skill_strength * 0.16)
		ball_core_color = ball_core_color.lerp(Color(1.0, 0.88, 0.62), 0.30 + skill_strength * 0.10)
	elif skill_mode == SKILL_FX_GHOST:
		var ghost_mix: float = 0.66 + skill_strength * 0.12
		ball_outer_color = ball_outer_color.lerp(GHOST_OUTER_COLOR, ghost_mix)
		ball_inner_color = ball_inner_color.lerp(GHOST_INNER_COLOR, 0.60 + skill_strength * 0.14)
		ball_ring_color = ball_ring_color.lerp(GHOST_RING_COLOR, 0.72 + skill_strength * 0.14)
		ball_core_color = ball_core_color.lerp(GHOST_CORE_COLOR, 0.62 + skill_strength * 0.12)

	_draw_body_glow(canvas, pos, pos, BALL_RENDER_RADIUS * 0.88 * pulse * lod_radius_scale, ball_outer_color, 0.11 * BALL_BRIGHTNESS * _draw_alpha)
	_draw_skill_upgrade_aura(canvas, pos, t, ball_vel, skill_mode, skill_strength, ball_ring_color, ball_inner_color, lod_scale)
	_draw_saturn_ring_stack(
		canvas,
		pos,
		t,
		ball_vel,
		speed_pulse,
		ball_ring_color,
		ball_inner_color,
		false,
		skill_mode,
		skill_strength,
		lod_scale
	)

	orbit_renderer.draw(
		canvas,
		pos,
		current_time_ms,
		t,
		BALL_RENDER_RADIUS,
		ball_ring_color,
		ball_inner_color,
		lod_scale,
		_draw_alpha
	)

	var core_size: float = BALL_RENDER_RADIUS * BALL_CORE_SCALE
	var core_main: Color = Color(
		ball_core_color.r * 0.20 + BALL_DIMENSIONAL_CORE_MAIN.r * 0.80,
		ball_core_color.g * 0.20 + BALL_DIMENSIONAL_CORE_MAIN.g * 0.80,
		ball_core_color.b * 0.20 + BALL_DIMENSIONAL_CORE_MAIN.b * 0.80,
		BALL_DIMENSIONAL_CORE_MAIN.a
	)
	var chroma_cyan_color: Color = BALL_DIMENSIONAL_CORE_CYAN
	var chroma_violet_color: Color = BALL_DIMENSIONAL_CORE_VIOLET
	var highlight_color: Color = Color.WHITE
	var highlight_alpha: float = 0.50
	var core_spark_alpha: float = BALL_DIMENSIONAL_CORE_HIGHLIGHT.a
	if skill_mode == SKILL_FX_GHOST:
		core_main = GHOST_CORE_COLOR.lerp(GHOST_INNER_COLOR, 0.30)
		chroma_cyan_color = Color(0.36, 0.04, 0.66, 0.30)
		chroma_violet_color = Color(0.03, 0.0, 0.09, 0.48)
		highlight_color = GHOST_HIGHLIGHT_COLOR
		highlight_alpha = 0.30
		core_spark_alpha = 0.64
	var chroma_offset: Vector2 = Vector2(cos(t * 2.1), sin(t * 1.7)) * core_size * 0.12
	_draw_body_glow(canvas, pos, pos, BALL_RENDER_RADIUS * 0.52 * pulse2 * lod_radius_scale, ball_inner_color, 0.30 * BALL_BRIGHTNESS * _draw_alpha)
	if lod_scale >= 0.68:
		_draw_body_glow(canvas, pos + chroma_offset, pos, core_size * 0.70, chroma_cyan_color, chroma_cyan_color.a * BALL_BRIGHTNESS * _draw_alpha)
		_draw_body_glow(canvas, pos - chroma_offset * 0.75, pos, core_size * 0.56, chroma_violet_color, chroma_violet_color.a * BALL_BRIGHTNESS * _draw_alpha)
	_draw_body_core(
		canvas,
		pos,
		pos,
		BALL_RENDER_RADIUS * BALL_SOLID_CORE_SCALE * core_pulse,
		ball_inner_color,
		0.86 * BALL_BRIGHTNESS * _draw_alpha
	)
	_draw_body_core(
		canvas,
		pos,
		pos,
		BALL_RENDER_RADIUS * BALL_SOLID_CORE_SCALE * 0.64 * core_pulse,
		core_main,
		0.98 * BALL_BRIGHTNESS * _draw_alpha
	)
	_draw_body_highlight(
		canvas,
		pos + Vector2(-BALL_RENDER_RADIUS * 0.16, -BALL_RENDER_RADIUS * 0.16),
		pos,
		BALL_RENDER_RADIUS * 0.36 * core_pulse,
		highlight_color,
		highlight_alpha * BALL_BRIGHTNESS * _draw_alpha
	)
	_draw_body_sparkle(canvas, pos, pos, max(4.0, core_size * BALL_CORE_HIGHLIGHT_SCALE), core_main, core_spark_alpha * BALL_BRIGHTNESS * _draw_alpha)
	_draw_body_sparkle(canvas, pos + Vector2(-BALL_RENDER_RADIUS * 0.12, -BALL_RENDER_RADIUS * 0.12), pos, 3.0, highlight_color, 0.22 * BALL_BRIGHTNESS * _draw_alpha)
	_draw_saturn_ring_stack(
		canvas,
		pos,
		t,
		ball_vel,
		speed_pulse,
		ball_ring_color,
		ball_inner_color,
		true,
		skill_mode,
		skill_strength,
		lod_scale
	)
	_draw_skill_motion_accents(canvas, pos, t, ball_vel, skill_mode, skill_strength, ball_ring_color, ball_inner_color, lod_scale)

	if lod_scale >= SEVERE_LOD_PARTICLE_DRAW_MIN_SCALE:
		particle_renderer.draw(canvas, pos, lod_scale, _draw_alpha)
	else:
		particle_renderer.clear()
	if enable_node_fx:
		_sync_node_fx(
			canvas,
			pos,
			boost_charging_active,
			ball_vel,
			node_fx_layout,
			hit_pulse_event,
			skill_mode,
			fx_lod_scale,
			_draw_deformation
		)
	else:
		hide_node_fx()


func _draw_body_glow(
	canvas: CanvasItem,
	center: Vector2,
	pivot: Vector2,
	radius: float,
	color: Color,
	alpha: float
) -> void:
	if _draw_deformation.is_empty():
		ImpactFlareTextureCache.draw_glow(canvas, center, radius, color, alpha)
		return
	BallDeformationTextureQuad.draw_centered(
		canvas,
		ImpactFlareTextureCache.get_glow_texture(),
		center,
		radius * 2.0,
		color,
		alpha,
		pivot,
		_draw_deformation
	)


func _draw_body_core(
	canvas: CanvasItem,
	center: Vector2,
	pivot: Vector2,
	radius: float,
	color: Color,
	alpha: float
) -> void:
	if _draw_deformation.is_empty():
		EnergyBallTextureCache.draw_core(canvas, center, radius, color, alpha)
		return
	BallDeformationTextureQuad.draw_centered(
		canvas,
		EnergyBallTextureCache.get_core_texture(),
		center,
		radius * 2.0,
		color,
		alpha,
		pivot,
		_draw_deformation
	)


func _draw_body_highlight(
	canvas: CanvasItem,
	center: Vector2,
	pivot: Vector2,
	radius: float,
	color: Color,
	alpha: float
) -> void:
	if _draw_deformation.is_empty():
		EnergyBallTextureCache.draw_highlight(canvas, center, radius, color, alpha)
		return
	BallDeformationTextureQuad.draw_centered(
		canvas,
		EnergyBallTextureCache.get_highlight_texture(),
		center,
		radius * 2.0,
		color,
		alpha,
		pivot,
		_draw_deformation
	)


func _draw_body_sparkle(
	canvas: CanvasItem,
	center: Vector2,
	pivot: Vector2,
	radius: float,
	color: Color,
	alpha: float
) -> void:
	if _draw_deformation.is_empty():
		ImpactFlareTextureCache.draw_sparkle(canvas, center, radius, color, alpha)
		return
	BallDeformationTextureQuad.draw_centered(
		canvas,
		ImpactFlareTextureCache.get_sparkle_texture(),
		center,
		radius * 2.0,
		color,
		alpha,
		pivot,
		_draw_deformation
	)


func hide_node_fx() -> void:
	if _is_valid_fx_host():
		if fx_host.has_method("set_active"):
			fx_host.set_active(false)


func _sync_node_fx(
	canvas: CanvasItem,
	pos: Vector2,
	boost_charging_active: bool,
	ball_vel: Vector2,
	node_fx_layout: Dictionary,
	hit_pulse_event: Dictionary,
	skill_fx_mode: String = "",
	fx_lod_scale: float = 1.0,
	contact_deformation: Dictionary = {}
) -> void:
	var host: Node = _get_or_create_fx_host(canvas)
	if host == null or not host.has_method("sync_state"):
		return
	var screen_pos: Vector2 = _get_vector2(node_fx_layout.get("screen_pos", pos), pos)
	var render_scale: float = max(0.01, float(node_fx_layout.get("render_scale", 1.0)))
	var screen_hit_pulse_event: Dictionary = _with_hit_pulse_screen_pos(hit_pulse_event, node_fx_layout, render_scale)
	host.sync_state(
		screen_pos,
		render_scale,
		ball_vel,
		boost_charging_active,
		true,
		screen_hit_pulse_event,
		skill_fx_mode,
		fx_lod_scale
	)
	_apply_node_fx_deformation(host, render_scale, contact_deformation)


func _apply_node_fx_deformation(
	host: Node,
	render_scale: float,
	contact_deformation: Dictionary
) -> void:
	if not host is Node2D:
		return
	var host_2d := host as Node2D
	var base_scale: float = maxf(0.01, render_scale) * BALL_VISUAL_SCALE
	if not bool(contact_deformation.get("active", false)):
		host_2d.rotation = 0.0
		host_2d.scale = Vector2.ONE * base_scale
		return
	var axis_value: Variant = contact_deformation.get("axis", Vector2.UP)
	var axis: Vector2 = axis_value as Vector2 if axis_value is Vector2 else Vector2.UP
	if axis.length_squared() <= 0.001:
		axis = Vector2.UP
	axis = axis.normalized()
	host_2d.rotation = axis.angle()
	host_2d.scale = Vector2(
		base_scale * float(contact_deformation.get("axis_scale", 1.0)),
		base_scale * float(contact_deformation.get("perpendicular_scale", 1.0))
	)


func _get_or_create_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_fx_host():
		return fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null("EnergyBallFxHost")
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		fx_host = existing
		fx_host_add_pending = false
		return fx_host
	fx_host = EnergyBallFxHost.new()
	fx_host.name = "EnergyBallFxHost"
	fx_host.visible = false
	if not fx_host_add_pending:
		fx_host_add_pending = true
		parent.call_deferred("add_child", fx_host)
	return fx_host


func _is_valid_fx_host() -> bool:
	return fx_host != null and is_instance_valid(fx_host) and not fx_host.is_queued_for_deletion()


func _sync_runtime_node_prewarm() -> void:
	if not _is_valid_fx_host() or not fx_host.has_method("sync_state"):
		return
	fx_host.sync_state(
		RUNTIME_NODE_PREWARM_SCREEN_POS,
		1.0,
		Vector2(18.0, -10.0),
		false,
		true,
		{},
		SKILL_FX_NONE,
		0.55
	)


func _deactivate_fx_host() -> void:
	if not _is_valid_fx_host():
		return
	if fx_host.has_method("set_active"):
		fx_host.set_active(false)
	elif fx_host is CanvasItem:
		(fx_host as CanvasItem).visible = false


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _with_hit_pulse_screen_pos(hit_pulse_event: Dictionary, node_fx_layout: Dictionary, render_scale: float) -> Dictionary:
	if hit_pulse_event.is_empty() or not hit_pulse_event.has("pos"):
		return hit_pulse_event
	var event_pos: Variant = hit_pulse_event.get("pos", Vector2.ZERO)
	if not (event_pos is Vector2):
		return hit_pulse_event
	var game_offset: Vector2 = _get_vector2(node_fx_layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var shake_offset: Vector2 = _get_vector2(node_fx_layout.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	var event_with_screen := hit_pulse_event.duplicate()
	event_with_screen["screen_pos"] = game_offset + (event_pos + shake_offset) * render_scale
	return event_with_screen


func _draw_saturn_ring_stack(
	canvas: CanvasItem,
	pos: Vector2,
	time_seconds: float,
	ball_vel: Vector2,
	speed_pulse: float,
	ball_ring_color: Color,
	ball_inner_color: Color,
	front_half: bool,
	skill_fx_mode: String = "",
	skill_strength: float = 0.0,
	fx_lod_scale: float = 1.0
) -> void:
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	var base_alpha: float = SATURN_RING_FRONT_ALPHA if front_half else SATURN_RING_BASE_ALPHA
	var velocity_bias: float = clamp(ball_vel.x / 22.0, -1.0, 1.0) * 3.0
	var ring_count: int = SATURN_RING_SPIN_SPEEDS.size() if lod_scale >= 0.82 else 1
	for ring_idx in range(ring_count):
		var ring_t: float = float(ring_idx)
		var spin_speed: float = float(SATURN_RING_SPIN_SPEEDS[ring_idx])
		var base_rotation: float = float(SATURN_RING_BASE_ROTATIONS[ring_idx])
		var radius_mult: float = float(SATURN_RING_RADIUS_MULTS[ring_idx])
		var tilt_base: float = float(SATURN_RING_TILT_BASES[ring_idx])
		var alpha_mult: float = float(SATURN_RING_ALPHA_MULTS[ring_idx])
		var ring_color: Color = ball_ring_color.lerp(ball_inner_color, 0.22 + ring_t * 0.18)
		if ring_idx == 1:
			ring_color = ring_color.lerp(BALL_DIMENSIONAL_CORE_VIOLET, 0.24)
		if skill_fx_mode == SKILL_FX_POWER:
			ring_color = ring_color.lerp(POWER_RING_COLOR, 0.18 + skill_strength * 0.18)
		elif skill_fx_mode == SKILL_FX_DRIVE:
			ring_color = ring_color.lerp(DRIVE_RING_COLOR, 0.16 + skill_strength * 0.14)
		elif skill_fx_mode == SKILL_FX_GHOST:
			ring_color = ring_color.lerp(GHOST_RING_COLOR, 0.28 + skill_strength * 0.18)
		var skill_spin: float = 0.0
		var skill_radius_boost: float = 0.0
		var skill_alpha_boost: float = 1.0
		if skill_fx_mode == SKILL_FX_DRIVE:
			skill_spin = (18.0 if ring_idx == 0 else -14.0) * skill_strength
			skill_radius_boost = 0.035 * skill_strength
			skill_alpha_boost = 1.0 + 0.42 * skill_strength
		elif skill_fx_mode == SKILL_FX_POWER:
			skill_spin = (-10.0 if ring_idx == 0 else 16.0) * skill_strength
			skill_radius_boost = (0.060 + sin(time_seconds * 7.0 + ring_t) * 0.018) * skill_strength
			skill_alpha_boost = 1.0 + 0.62 * skill_strength
		elif skill_fx_mode == SKILL_FX_GHOST:
			skill_spin = (26.0 if ring_idx == 0 else -32.0) * skill_strength
			skill_radius_boost = (0.075 + sin(time_seconds * 8.4 + ring_t) * 0.022) * skill_strength
			skill_alpha_boost = 1.0 + 0.48 * skill_strength
		var rotation_deg: float = (
			base_rotation
			+ time_seconds * (spin_speed + skill_spin)
			+ sin(time_seconds * (0.70 + ring_t * 0.24) + ring_t * 1.7) * 3.5
			+ velocity_bias
		)
		var tilt_scale: float = tilt_base + sin(time_seconds * (0.55 + ring_t * 0.17) + ring_t) * 0.045
		var ring_radius: float = BALL_RENDER_RADIUS * (radius_mult + skill_radius_boost + speed_pulse * (0.05 + ring_t * 0.02))
		EnergyBallTextureCache.draw_saturn_ring(
			canvas,
			pos,
			ring_radius,
			deg_to_rad(rotation_deg),
			tilt_scale,
			ring_color,
			base_alpha * alpha_mult * skill_alpha_boost * BALL_BRIGHTNESS * _draw_alpha * (0.88 + lod_scale * 0.12),
			front_half
		)


func _draw_skill_upgrade_aura(
	canvas: CanvasItem,
	pos: Vector2,
	time_seconds: float,
	ball_vel: Vector2,
	skill_fx_mode: String,
	skill_strength: float,
	ball_ring_color: Color,
	ball_inner_color: Color,
	fx_lod_scale: float = 1.0
) -> void:
	if skill_fx_mode == SKILL_FX_NONE or skill_strength <= 0.0:
		return
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	var pulse_speed: float = 9.0 if skill_fx_mode == SKILL_FX_POWER else (8.2 if skill_fx_mode == SKILL_FX_GHOST else 6.5)
	var pulse: float = 0.5 + 0.5 * sin(time_seconds * pulse_speed)
	var aura_color: Color = DRIVE_RING_COLOR
	if skill_fx_mode == SKILL_FX_POWER:
		aura_color = POWER_RING_COLOR
	elif skill_fx_mode == SKILL_FX_GHOST:
		aura_color = GHOST_RING_COLOR
	var aura_radius: float = BALL_RENDER_RADIUS * (1.28 + skill_strength * 0.28 + pulse * 0.08)
	var aura_alpha: float = (0.075 + skill_strength * 0.045) * BALL_BRIGHTNESS * _draw_alpha
	ImpactFlareTextureCache.draw_glow(canvas, pos, aura_radius, aura_color.lerp(ball_inner_color, 0.18), aura_alpha * lod_scale)
	if skill_fx_mode == SKILL_FX_POWER:
		ImpactFlareTextureCache.draw_glow(canvas, pos, BALL_RENDER_RADIUS * (0.72 + pulse * 0.08), POWER_INNER_COLOR, 0.16 * skill_strength * BALL_BRIGHTNESS * _draw_alpha)
	elif skill_fx_mode == SKILL_FX_GHOST:
		ImpactFlareTextureCache.draw_glow(canvas, pos, BALL_RENDER_RADIUS * (1.02 + pulse * 0.10), GHOST_OUTER_COLOR, 0.22 * skill_strength * BALL_BRIGHTNESS * _draw_alpha)
		_draw_ghost_void_arcs(canvas, pos, time_seconds, skill_strength, aura_color, lod_scale)
	else:
		_draw_drive_curve_arc(canvas, pos, time_seconds, skill_strength, ball_ring_color, lod_scale)
	if ball_vel.length() > 0.05:
		_draw_skill_velocity_wake(canvas, pos, ball_vel, skill_fx_mode, skill_strength, aura_color, lod_scale)


func _draw_skill_motion_accents(
	canvas: CanvasItem,
	pos: Vector2,
	time_seconds: float,
	_ball_vel: Vector2,
	skill_fx_mode: String,
	skill_strength: float,
	ball_ring_color: Color,
	ball_inner_color: Color,
	fx_lod_scale: float = 1.0
) -> void:
	if skill_fx_mode == SKILL_FX_NONE or skill_strength <= 0.0:
		return
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	if skill_fx_mode == SKILL_FX_POWER:
		_draw_power_smash_crush_lines(canvas, pos, time_seconds, skill_strength, ball_ring_color, ball_inner_color, lod_scale)
	elif skill_fx_mode == SKILL_FX_DRIVE:
		_draw_drive_curve_arc(canvas, pos, time_seconds + 0.42, skill_strength * 0.84, ball_inner_color, lod_scale)
	elif skill_fx_mode == SKILL_FX_GHOST:
		_draw_ghost_void_arcs(canvas, pos, time_seconds + 0.18, skill_strength * 0.95, ball_ring_color, lod_scale)


func _draw_skill_velocity_wake(
	canvas: CanvasItem,
	pos: Vector2,
	ball_vel: Vector2,
	skill_fx_mode: String,
	skill_strength: float,
	color: Color,
	fx_lod_scale: float = 1.0
) -> void:
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	var speed: float = max(0.01, ball_vel.length())
	var direction: Vector2 = ball_vel / speed
	var perp := Vector2(-direction.y, direction.x)
	var tail_len: float = min(54.0, 22.0 + speed * 1.35) * (0.72 + skill_strength * 0.22)
	var base_line_count: int = 5 if skill_fx_mode == SKILL_FX_GHOST else (4 if skill_fx_mode == SKILL_FX_POWER else 3)
	var line_count: int = max(2, int(ceil(float(base_line_count) * lod_scale)))
	for i in range(line_count):
		var side: float = float(i) - float(line_count - 1) * 0.5
		var offset: Vector2 = perp * side * (4.5 + skill_strength * 2.0)
		var ghost_tail_boost: float = 1.24 if skill_fx_mode == SKILL_FX_GHOST else 1.0
		var start: Vector2 = pos - direction * tail_len * ghost_tail_boost + offset
		var finish: Vector2 = pos - direction * BALL_RENDER_RADIUS * 0.22 + offset * 0.35
		var alpha: float = (0.16 - abs(side) * 0.025 + skill_strength * 0.035) * BALL_BRIGHTNESS * _draw_alpha
		canvas.draw_line(start, finish, Color(color.r, color.g, color.b, alpha), 1.2 + skill_strength * 0.8, true)


func _draw_ghost_void_arcs(canvas: CanvasItem, pos: Vector2, time_seconds: float, skill_strength: float, color: Color, fx_lod_scale: float = 1.0) -> void:
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	var arc_count: int = 3 if lod_scale >= 0.82 else 2
	for i in range(arc_count):
		var ring_ratio: float = float(i)
		var radius: float = BALL_RENDER_RADIUS * (1.12 + ring_ratio * 0.18 + skill_strength * 0.08)
		var start_angle: float = -time_seconds * (2.1 + ring_ratio * 0.35) + ring_ratio * TAU / 3.0
		var sweep: float = PI * (0.46 + ring_ratio * 0.08)
		var alpha: float = (0.14 - ring_ratio * 0.026 + skill_strength * 0.035) * BALL_BRIGHTNESS * _draw_alpha
		_draw_arc_polyline(canvas, pos, radius, start_angle, sweep, Color(color.r, color.g, color.b, alpha), 1.2 + skill_strength * 0.4, lod_scale)
		if lod_scale >= 0.68:
			_draw_arc_polyline(canvas, pos, radius * 0.72, start_angle + PI * 0.72, -sweep * 0.62, Color(GHOST_OUTER_COLOR.r, GHOST_OUTER_COLOR.g, GHOST_OUTER_COLOR.b, alpha * 1.35), 1.0, lod_scale)


func _draw_drive_curve_arc(canvas: CanvasItem, pos: Vector2, time_seconds: float, skill_strength: float, color: Color, fx_lod_scale: float = 1.0) -> void:
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	var radius: float = BALL_RENDER_RADIUS * (1.34 + skill_strength * 0.10)
	var start_angle: float = time_seconds * 2.9
	var sweep: float = PI * 0.78
	_draw_arc_polyline(canvas, pos, radius, start_angle, sweep, Color(color.r, color.g, color.b, 0.24 * skill_strength * BALL_BRIGHTNESS * _draw_alpha), 1.6, lod_scale)
	if lod_scale >= 0.68:
		_draw_arc_polyline(canvas, pos, radius * 0.82, start_angle + PI, -sweep * 0.72, Color(DRIVE_INNER_COLOR.r, DRIVE_INNER_COLOR.g, DRIVE_INNER_COLOR.b, 0.16 * skill_strength * BALL_BRIGHTNESS * _draw_alpha), 1.2, lod_scale)


func _draw_power_smash_crush_lines(
	canvas: CanvasItem,
	pos: Vector2,
	time_seconds: float,
	skill_strength: float,
	ball_ring_color: Color,
	ball_inner_color: Color,
	fx_lod_scale: float = 1.0
) -> void:
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	var line_count: int = 6 if lod_scale >= 0.82 else 4
	for i in range(line_count):
		var angle: float = time_seconds * 1.8 + float(i) * TAU / float(line_count)
		var direction := Vector2(cos(angle), sin(angle))
		var inner: float = BALL_RENDER_RADIUS * (0.72 + 0.04 * sin(time_seconds * 8.0 + float(i)))
		var outer: float = BALL_RENDER_RADIUS * (1.42 + skill_strength * 0.18)
		var alpha: float = (0.14 + skill_strength * 0.05) * BALL_BRIGHTNESS * _draw_alpha
		canvas.draw_line(
			pos + direction * inner,
			pos + direction * outer,
			Color(ball_ring_color.r, ball_ring_color.g, ball_ring_color.b, alpha),
			1.2 + skill_strength * 0.6,
			true
		)
	ImpactFlareTextureCache.draw_sparkle(canvas, pos, BALL_RENDER_RADIUS * (0.58 + skill_strength * 0.06), ball_inner_color, 0.20 * skill_strength * BALL_BRIGHTNESS * _draw_alpha)


func _draw_arc_polyline(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	start_angle: float,
	sweep: float,
	color: Color,
	width: float,
	fx_lod_scale: float = 1.0
) -> void:
	if color.a <= 0.0 or radius <= 1.0:
		return
	var points := PackedVector2Array()
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	var segments: int = 14 if lod_scale >= 0.82 else 10
	for i in range(segments + 1):
		var ratio: float = float(i) / float(segments)
		var angle: float = start_angle + sweep * ratio
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_polyline(points, color, width, true)


func _normalize_skill_fx_mode(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == SKILL_FX_DRIVE or normalized == SKILL_FX_POWER or normalized == SKILL_FX_GHOST:
		return normalized
	return SKILL_FX_NONE


func _get_skill_fx_strength(skill_fx_mode: String, speed_pulse: float) -> float:
	if skill_fx_mode == SKILL_FX_NONE:
		return 0.0
	return clamp(0.62 + speed_pulse * 0.38, 0.0, 1.0)


func _hsv_unit_to_rgb(hue: float) -> Color:
	var h: float = fmod(hue, 1.0) * 6.0
	var c: float = 1.0
	var x: float = c * (1.0 - abs(fmod(h, 2.0) - 1.0))
	if h < 1.0:
		return Color(c, x, 0.0)
	if h < 2.0:
		return Color(x, c, 0.0)
	if h < 3.0:
		return Color(0.0, c, x)
	if h < 4.0:
		return Color(0.0, x, c)
	if h < 5.0:
		return Color(x, 0.0, c)
	return Color(c, 0.0, x)
