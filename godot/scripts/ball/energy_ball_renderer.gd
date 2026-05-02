extends RefCounted

const EnergyBallOrbitRenderer := preload("res://scripts/ball/energy_ball_orbit_renderer.gd")
const EnergyBallParticleRenderer := preload("res://scripts/ball/energy_ball_particle_renderer.gd")

const BALL_RENDER_RADIUS := 13.0
const BALL_OUTER_COLOR := Color(30.0 / 255.0, 100.0 / 255.0, 200.0 / 255.0)
const BALL_INNER_COLOR := Color(100.0 / 255.0, 180.0 / 255.0, 255.0 / 255.0)
const BALL_RING_COLOR := Color(80.0 / 255.0, 160.0 / 255.0, 255.0 / 255.0)
const BALL_CORE_COLOR := Color(1.0, 1.0, 1.0)

var particle_renderer: Object = EnergyBallParticleRenderer.new()
var orbit_renderer: Object = EnergyBallOrbitRenderer.new()


func clear() -> void:
	particle_renderer.clear()


func draw(canvas: CanvasItem, pos: Vector2, boost_charging_active: bool) -> void:
	var current_time_ms: float = float(Time.get_ticks_msec())
	var t: float = current_time_ms / 1000.0
	var pulse: float = sin(t * 7.5) * 0.08 + 1.0
	var pulse2: float = sin(t * 10.0) * 0.06 + 1.0
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

	for i in range(3):
		var glow_radius: float = BALL_RENDER_RADIUS * (0.795 - float(i) * 0.11) * pulse
		var glow_alpha: float = (8.0 - float(i) * 2.0) / 255.0
		canvas.draw_circle(pos, glow_radius, Color(ball_outer_color.r, ball_outer_color.g, ball_outer_color.b, glow_alpha))

	orbit_renderer.draw(
		canvas,
		pos,
		current_time_ms,
		t,
		BALL_RENDER_RADIUS,
		ball_ring_color,
		ball_inner_color
	)

	canvas.draw_circle(pos, BALL_RENDER_RADIUS * 0.361 * pulse2, Color(ball_inner_color.r, ball_inner_color.g, ball_inner_color.b, 25.0 / 255.0))
	canvas.draw_circle(pos, BALL_RENDER_RADIUS * 0.289 * pulse, Color(0.76, 0.91, 1.0, 40.0 / 255.0))
	canvas.draw_circle(pos, BALL_RENDER_RADIUS * 0.255, Color(0.72, 0.88, 1.0, 60.0 / 255.0))
	var core_size: float = BALL_RENDER_RADIUS * 0.178
	canvas.draw_circle(pos, core_size + 2.0, Color(ball_ring_color.r * 0.5 + 0.5, ball_ring_color.g * 0.5 + 0.5, ball_ring_color.b * 0.5 + 0.5, 80.0 / 255.0))
	canvas.draw_circle(pos, core_size, Color(ball_core_color.r, ball_core_color.g, ball_core_color.b, 150.0 / 255.0))
	canvas.draw_circle(pos, max(2.0, core_size * 0.5), Color(1.0, 1.0, 1.0, 200.0 / 255.0))
	canvas.draw_circle(
		pos + Vector2(-BALL_RENDER_RADIUS * 0.11, -BALL_RENDER_RADIUS * 0.11),
		max(1.0, BALL_RENDER_RADIUS * 0.072),
		Color(1.0, 1.0, 1.0, 80.0 / 255.0)
	)
	canvas.draw_circle(
		pos + Vector2(-BALL_RENDER_RADIUS * 0.11 - 1.0, -BALL_RENDER_RADIUS * 0.11 - 1.0),
		max(2.0, BALL_RENDER_RADIUS * 0.072 + 1.0),
		Color(1.0, 1.0, 1.0, 40.0 / 255.0)
	)

	particle_renderer.draw(canvas, pos)


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
