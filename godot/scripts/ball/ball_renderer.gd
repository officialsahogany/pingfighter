extends RefCounted

const BallStatusOverlayRenderer := preload("res://scripts/ball/ball_status_overlay_renderer.gd")
const BombBallRenderer := preload("res://scripts/ball/bomb_ball_renderer.gd")
const EnergyBallRenderer := preload("res://scripts/ball/energy_ball_renderer.gd")
const PingpongBallRenderer := preload("res://scripts/ball/pingpong_ball_renderer.gd")
const PrismBallRenderer := preload("res://scripts/ball/prism_ball_renderer.gd")

const BALL_VISUAL_SCALE := 1.575
const BALL_RENDER_RADIUS := 16.9 * BALL_VISUAL_SCALE

var bomb_renderer: Object = BombBallRenderer.new()
var energy_renderer: Object = EnergyBallRenderer.new()
var pingpong_renderer: Object = PingpongBallRenderer.new()
var prism_renderer: Object = PrismBallRenderer.new()
var status_overlay_renderer: Object = BallStatusOverlayRenderer.new()


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if energy_renderer != null and energy_renderer.has_method("prewarm_assets_step"):
		return bool(energy_renderer.prewarm_assets_step())
	return true


func clear() -> void:
	energy_renderer.clear()
	pingpong_renderer.clear()
	status_overlay_renderer.clear()


func draw_current(canvas: CanvasItem, pos: Vector2, context: Dictionary, perf_logger: Object = null) -> void:
	if canvas == null:
		return

	var visual_type: String = str(context.get("ball_visual_type", "energy"))
	var draw_as_prism: bool = visual_type == "prism"
	var skill_fx_mode: String = _get_skill_fx_mode(context)
	var sample_start: int = _perf_begin(perf_logger)
	if draw_as_prism:
		energy_renderer.hide_node_fx()
		prism_renderer.draw(canvas, pos)
		_perf_end(perf_logger, "ball.visual.prism", sample_start)
	elif visual_type == "pingpong":
		energy_renderer.hide_node_fx()
		pingpong_renderer.draw(
			canvas,
			pos,
			context.get("pingpong_ball_texture", null),
			context.get("ball_vel", Vector2.ZERO)
		)
		_perf_end(perf_logger, "ball.visual.pingpong", sample_start)
	elif bool(context.get("bomb_ball_loaded", false)):
		energy_renderer.hide_node_fx()
		bomb_renderer.draw(canvas, pos)
		_perf_end(perf_logger, "ball.visual.bomb", sample_start)
	else:
		_draw_energy_ball(
			canvas,
			pos,
			bool(context.get("boost_charging_active", false)),
			context.get("ball_vel", Vector2.ZERO),
			_get_dict(context.get("node_fx_layout", {})),
			_get_dict(context.get("hit_pulse_event", {})),
			skill_fx_mode,
			clamp(float(context.get("effect_lod_scale", 1.0)), 0.25, 1.0)
		)
		_perf_end(perf_logger, "ball.visual.energy", sample_start)

	sample_start = _perf_begin(perf_logger)
	status_overlay_renderer.draw(canvas, pos, context, BALL_RENDER_RADIUS)
	_perf_end(perf_logger, "ball.status_overlay", sample_start)


func _draw_energy_ball(
	canvas: CanvasItem,
	pos: Vector2,
	boost_charging_active: bool,
	ball_vel: Vector2,
	node_fx_layout: Dictionary,
	hit_pulse_event: Dictionary,
	skill_fx_mode: String = "",
	fx_lod_scale: float = 1.0
) -> void:
	energy_renderer.draw(
		canvas,
		pos,
		boost_charging_active,
		ball_vel,
		node_fx_layout,
		hit_pulse_event,
		skill_fx_mode,
		true,
		fx_lod_scale
	)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_skill_fx_mode(context: Dictionary) -> String:
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


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
