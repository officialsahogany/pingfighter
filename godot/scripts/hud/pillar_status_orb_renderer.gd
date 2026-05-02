extends RefCounted

const PillarGaugeOrbRenderer := preload("res://scripts/hud/pillar_gauge_orb_renderer.gd")
const PillarDashOrbRenderer := preload("res://scripts/hud/pillar_dash_orb_renderer.gd")

var gauge_renderer: Object = PillarGaugeOrbRenderer.new()
var dash_renderer: Object = PillarDashOrbRenderer.new()


func draw_gauge_orb(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	gauge_renderer.draw(canvas, center, orb_radius, t, scale_factor, context)


func draw_dash_orb(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	dash_renderer.draw(canvas, center, orb_radius, t, scale_factor, context)
