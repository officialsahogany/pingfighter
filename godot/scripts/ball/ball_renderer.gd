extends RefCounted

const BallStatusOverlayRenderer := preload("res://scripts/ball/ball_status_overlay_renderer.gd")
const BombBallRenderer := preload("res://scripts/ball/bomb_ball_renderer.gd")
const EnergyBallRenderer := preload("res://scripts/ball/energy_ball_renderer.gd")
const PingpongBallRenderer := preload("res://scripts/ball/pingpong_ball_renderer.gd")
const PrismBallRenderer := preload("res://scripts/ball/prism_ball_renderer.gd")

const BALL_RENDER_RADIUS := 13.0

var bomb_renderer: Object = BombBallRenderer.new()
var energy_renderer: Object = EnergyBallRenderer.new()
var pingpong_renderer: Object = PingpongBallRenderer.new()
var prism_renderer: Object = PrismBallRenderer.new()
var status_overlay_renderer: Object = BallStatusOverlayRenderer.new()


func clear() -> void:
	energy_renderer.clear()
	pingpong_renderer.clear()


func draw_current(canvas: CanvasItem, pos: Vector2, context: Dictionary) -> void:
	if canvas == null:
		return

	var visual_type: String = str(context.get("ball_visual_type", "energy"))
	var draw_as_prism: bool = (
		bool(context.get("drive_ball_active", false))
		or bool(context.get("power_smashing_freeze_active", false))
		or bool(context.get("power_smashing_parabola_active", false))
		or visual_type == "prism"
	)
	if draw_as_prism:
		prism_renderer.draw(canvas, pos)
	elif visual_type == "pingpong":
		pingpong_renderer.draw(
			canvas,
			pos,
			context.get("pingpong_ball_texture", null),
			context.get("ball_vel", Vector2.ZERO)
		)
	elif bool(context.get("bomb_ball_loaded", false)):
		bomb_renderer.draw(canvas, pos)
	else:
		_draw_energy_ball(canvas, pos, bool(context.get("boost_charging_active", false)))

	status_overlay_renderer.draw(canvas, pos, context, BALL_RENDER_RADIUS)


func _draw_energy_ball(canvas: CanvasItem, pos: Vector2, boost_charging_active: bool) -> void:
	energy_renderer.draw(canvas, pos, boost_charging_active)
