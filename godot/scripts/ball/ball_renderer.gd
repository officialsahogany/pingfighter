extends RefCounted

const BallStatusOverlayRenderer := preload("res://scripts/ball/ball_status_overlay_renderer.gd")
const BallContactDeformationState := preload("res://scripts/ball/ball_contact_deformation_state.gd")
const BombBallRenderer := preload("res://scripts/ball/bomb_ball_renderer.gd")
const EnergyBallRenderer := preload("res://scripts/ball/energy_ball_renderer.gd")
const PingpongBallRenderer := preload("res://scripts/ball/pingpong_ball_renderer.gd")
const PrismBallRenderer := preload("res://scripts/ball/prism_ball_renderer.gd")
const SmasherOverdriveBallTrailRenderer := preload("res://scripts/ball/smasher_overdrive_ball_trail_renderer.gd")
const SmasherWheelReboundBallTrailRenderer := preload("res://scripts/ball/smasher_wheel_rebound_ball_trail_renderer.gd")

const BALL_VISUAL_SCALE := 1.575
const BALL_RENDER_RADIUS := 16.9 * BALL_VISUAL_SCALE
const GROUND_SHADOW_ALPHAS := [0.045, 0.078]
const GROUND_SHADOW_SEGMENTS := 12

var bomb_renderer: Object = BombBallRenderer.new()
var contact_deformation_state: Object = BallContactDeformationState.new()
var energy_renderer: Object = EnergyBallRenderer.new()
var pingpong_renderer: Object = PingpongBallRenderer.new()
var prism_renderer: Object = PrismBallRenderer.new()
var status_overlay_renderer: Object = BallStatusOverlayRenderer.new()
var overdrive_trail_renderer: Object = SmasherOverdriveBallTrailRenderer.new()
var wheel_rebound_trail_renderer: Object = SmasherWheelReboundBallTrailRenderer.new()
var _unit_ellipse_points_cache: Dictionary = {}


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if energy_renderer != null and energy_renderer.has_method("prewarm_assets_step"):
		return bool(energy_renderer.prewarm_assets_step())
	return true


func prewarm_runtime_nodes(owner: Object = null) -> void:
	if energy_renderer != null and energy_renderer.has_method("prewarm_runtime_nodes"):
		energy_renderer.prewarm_runtime_nodes(owner)


func prewarm_runtime_nodes_step(owner: Object = null) -> bool:
	if energy_renderer != null and energy_renderer.has_method("prewarm_runtime_nodes_step"):
		return bool(energy_renderer.prewarm_runtime_nodes_step(owner))
	prewarm_runtime_nodes(owner)
	return true


func clear() -> void:
	contact_deformation_state.clear()
	energy_renderer.clear()
	pingpong_renderer.clear()
	status_overlay_renderer.clear()
	overdrive_trail_renderer.clear()
	wheel_rebound_trail_renderer.clear()


func draw_current(
	canvas: CanvasItem,
	pos: Vector2,
	context: Dictionary,
	perf_logger: Object = null,
	enable_node_fx: bool = true
) -> void:
	if canvas == null:
		return

	var visual_type: String = str(context.get("ball_visual_type", "energy"))
	var draw_as_prism: bool = visual_type == "prism"
	var skill_fx_mode: String = _get_skill_fx_mode(context)
	var render_alpha: float = clampf(float(context.get("ball_render_alpha", 1.0)), 0.0, 1.0)
	var hit_pulse_event: Dictionary = _get_dict(context.get("hit_pulse_event", {}))
	var deformation_now_msec: float = float(context.get(
		"ball_contact_deformation_now_msec",
		Time.get_ticks_msec()
	))
	var contact_deformation: Dictionary = _resolve_contact_deformation(
		context,
		visual_type,
		draw_as_prism,
		skill_fx_mode,
		hit_pulse_event,
		deformation_now_msec
	)
	var sample_start: int = _perf_begin(perf_logger)
	_draw_ground_shadow(canvas, pos, context)
	_perf_end(perf_logger, "ball.ground_shadow", sample_start)

	sample_start = _perf_begin(perf_logger)
	if draw_as_prism:
		energy_renderer.hide_node_fx()
		prism_renderer.draw(canvas, pos, render_alpha)
		_perf_end(perf_logger, "ball.visual.prism", sample_start)
	elif visual_type == "pingpong":
		energy_renderer.hide_node_fx()
		pingpong_renderer.draw(
			canvas,
			pos,
			context.get("pingpong_ball_texture", null),
			context.get("ball_vel", Vector2.ZERO),
			render_alpha
		)
		_perf_end(perf_logger, "ball.visual.pingpong", sample_start)
	elif bool(context.get("bomb_ball_loaded", false)):
		energy_renderer.hide_node_fx()
		bomb_renderer.draw(canvas, pos, render_alpha)
		_perf_end(perf_logger, "ball.visual.bomb", sample_start)
	else:
		_draw_energy_ball(
			canvas,
			pos,
			bool(context.get("boost_charging_active", false)),
			context.get("ball_vel", Vector2.ZERO),
			_get_dict(context.get("node_fx_layout", {})),
			hit_pulse_event,
			skill_fx_mode,
			clamp(float(context.get("effect_lod_scale", 1.0)), 0.25, 1.0),
			enable_node_fx,
			render_alpha,
			contact_deformation
		)
		_perf_end(perf_logger, "ball.visual.energy", sample_start)

	sample_start = _perf_begin(perf_logger)
	overdrive_trail_renderer.draw(
		canvas,
		pos,
		_get_dict(context.get("smasher_overdrive_fx", {})),
		_as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO),
		clamp(float(context.get("effect_lod_scale", 1.0)), 0.25, 1.0),
		render_alpha
	)
	_perf_end(perf_logger, "ball.overdrive_trail", sample_start)

	sample_start = _perf_begin(perf_logger)
	wheel_rebound_trail_renderer.draw(
		canvas,
		pos,
		_get_dict(context.get("smasher_wheel_rebound_fx", {})),
		_as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO),
		clamp(float(context.get("effect_lod_scale", 1.0)), 0.25, 1.0),
		render_alpha
	)
	_perf_end(perf_logger, "ball.wheel_rebound_trail", sample_start)

	sample_start = _perf_begin(perf_logger)
	status_overlay_renderer.draw(canvas, pos, context, BALL_RENDER_RADIUS, render_alpha)
	_perf_end(perf_logger, "ball.status_overlay", sample_start)


func _draw_ground_shadow(canvas: CanvasItem, pos: Vector2, context: Dictionary) -> void:
	if not bool(context.get("ball_ground_shadow_enabled", true)):
		return
	var lod_scale: float = clamp(float(context.get("effect_lod_scale", 1.0)), 0.25, 1.0)
	var visual_scale: float = _get_ground_shadow_visual_scale(context)
	var ball_vel: Vector2 = _as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var speed_ratio: float = clamp(ball_vel.length() / 30.0, 0.0, 1.0)
	var shadow_width: float = BALL_RENDER_RADIUS * (1.54 + speed_ratio * 0.18) * visual_scale
	var shadow_height: float = BALL_RENDER_RADIUS * (0.33 - speed_ratio * 0.035) * visual_scale
	var center := pos + Vector2(0.0, BALL_RENDER_RADIUS * 0.56)
	var layer_count: int = GROUND_SHADOW_ALPHAS.size()
	var alpha_scale: float = 0.80 + lod_scale * 0.20
	var render_alpha: float = clampf(float(context.get("ball_render_alpha", 1.0)), 0.0, 1.0)
	for layer in range(layer_count):
		var layer_t: float = float(layer_count - 1 - layer)
		var rect := Rect2(
			center - Vector2((shadow_width + layer_t * 6.0) * 0.5, (shadow_height + layer_t * 1.8) * 0.5),
			Vector2(shadow_width + layer_t * 6.0, shadow_height + layer_t * 1.8)
		)
		var alpha: float = float(GROUND_SHADOW_ALPHAS[layer]) * alpha_scale * render_alpha
		canvas.draw_colored_polygon(
			_build_ellipse_points(rect, GROUND_SHADOW_SEGMENTS),
			Color(0.0, 0.0, 0.0, alpha)
		)


func _get_ground_shadow_visual_scale(context: Dictionary) -> float:
	if bool(context.get("bomb_ball_loaded", false)):
		return 1.08
	var visual_type: String = str(context.get("ball_visual_type", "energy")).strip_edges().to_lower()
	if visual_type == "pingpong":
		return 1.18
	if visual_type == "prism":
		return 1.22
	return 1.0


func _build_ellipse_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius := rect.size * 0.5
	var unit_points: PackedVector2Array = _get_unit_ellipse_points(max(8, segments))
	for point in unit_points:
		points.append(center + Vector2(point.x * radius.x, point.y * radius.y))
	return points


func _get_unit_ellipse_points(segments: int) -> PackedVector2Array:
	if _unit_ellipse_points_cache.has(segments):
		return _unit_ellipse_points_cache[segments]
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)))
	_unit_ellipse_points_cache[segments] = points
	return points


func _draw_energy_ball(
	canvas: CanvasItem,
	pos: Vector2,
	boost_charging_active: bool,
	ball_vel: Vector2,
	node_fx_layout: Dictionary,
	hit_pulse_event: Dictionary,
	skill_fx_mode: String = "",
	fx_lod_scale: float = 1.0,
	enable_node_fx: bool = true,
	visual_alpha: float = 1.0,
	contact_deformation: Dictionary = {}
) -> void:
	energy_renderer.draw(
		canvas,
		pos,
		boost_charging_active,
		ball_vel,
		node_fx_layout,
		hit_pulse_event,
		skill_fx_mode,
		enable_node_fx,
		fx_lod_scale,
		visual_alpha,
		contact_deformation
	)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_skill_fx_mode(context: Dictionary) -> String:
	if bool(context.get("perk_fusion_thunder_drive_active", false)):
		return "thunder_drive"
	if (
		bool(context.get("ghost_shot_motion_active", false))
		or bool(context.get("ghost_shot_active", false))
		or bool(context.get("ghost_shot_pending_teleport", false))
	):
		return "ghost_shot"
	if (
		bool(context.get("power_smashing_freeze_active", false))
		or bool(context.get("power_smashing_parabola_active", false))
	):
		return "power_smashing"
	if bool(context.get("drive_ball_active", false)):
		return "drive"
	return ""


func _resolve_contact_deformation(
	context: Dictionary,
	visual_type: String,
	draw_as_prism: bool,
	skill_fx_mode: String,
	hit_pulse_event: Dictionary,
	now_msec: float
) -> Dictionary:
	contact_deformation_state.sync_event(hit_pulse_event, now_msec)
	if (
		not bool(context.get("ball_contact_deformation_enabled", true))
		or draw_as_prism
		or visual_type == "pingpong"
		or bool(context.get("bomb_ball_loaded", false))
		or skill_fx_mode != ""
	):
		return {}
	return contact_deformation_state.get_snapshot(now_msec)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
