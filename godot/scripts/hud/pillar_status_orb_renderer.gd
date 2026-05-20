extends RefCounted

const PillarGaugeOrbRenderer := preload("res://scripts/hud/pillar_gauge_orb_renderer.gd")
const PillarDashOrbRenderer := preload("res://scripts/hud/pillar_dash_orb_renderer.gd")
const DashTokenBoostFxHost := preload("res://scripts/hud/dash_token_boost_fx_host.gd")

const DEFAULT_PREWARM_RADII := [55.0, 64.0, 72.0, 80.0, 88.0, 96.0, 112.0, 120.0]
const PREWARM_PASSES_PER_RADIUS := 3

var gauge_renderer: Object = PillarGaugeOrbRenderer.new()
var dash_renderer: Object = PillarDashOrbRenderer.new()
var _prewarm_cache_step_index := 0


func prewarm_caches(radii: Array = []) -> void:
	while not prewarm_caches_step(radii):
		pass


func prewarm_caches_step(radii: Array = []) -> bool:
	var requested_radii: Array = _get_requested_radii(radii)
	if requested_radii.is_empty():
		_prewarm_cache_step_index = 0
		return true
	# Static asset prewarm (shader resource load, white texture build) is cheap
	# and idempotent, so we run it on every step entry. The expensive offscreen
	# shader draw (PSO compile) lives in battle_pso_prewarmer; this only makes
	# the boost FX host's static fields ready before the first real frame uses
	# it from stage1_pillar_ui_renderer.
	DashTokenBoostFxHost.prewarm_assets()
	var total_steps: int = requested_radii.size() * PREWARM_PASSES_PER_RADIUS
	if _prewarm_cache_step_index >= total_steps:
		_prewarm_cache_step_index = 0
		return true
	var radius_index: int = floori(float(_prewarm_cache_step_index) / float(PREWARM_PASSES_PER_RADIUS))
	var pass_index: int = _prewarm_cache_step_index % PREWARM_PASSES_PER_RADIUS
	var radius: float = max(16.0, float(requested_radii[radius_index]))
	var boss_dash_context := {
		"compact_fallback_frame": true,
		"orb_background_outer": Color(0.08, 0.04, 0.14, 1.0),
		"orb_background_inner": Color(0.22, 0.11, 0.34, 1.0),
	}
	match pass_index:
		0:
			gauge_renderer.prewarm_caches(radius)
		1:
			dash_renderer.prewarm_caches(radius)
		2:
			dash_renderer.prewarm_caches(radius, boss_dash_context)
	_prewarm_cache_step_index += 1
	if _prewarm_cache_step_index >= total_steps:
		_prewarm_cache_step_index = 0
		return true
	return false


# Pipeline status surfaces what the boost FX host shader / texture cache has
# completed so smoke tests and prewarm verifiers can assert readiness without
# exposing the host's internals.
func get_boost_fx_host_pipeline_status() -> Dictionary:
	return DashTokenBoostFxHost.build_pipeline_status()


func _get_requested_radii(radii: Array) -> Array:
	if radii.is_empty():
		return DEFAULT_PREWARM_RADII
	return radii


func draw_gauge_orb(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	gauge_renderer.draw(canvas, center, orb_radius, t, scale_factor, context)


func draw_dash_orb(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	dash_renderer.draw(canvas, center, orb_radius, t, scale_factor, context)
