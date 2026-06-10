extends RefCounted

const PillarGaugeOrbRenderer := preload("res://scripts/hud/pillar_gauge_orb_renderer.gd")
const PillarDashOrbRenderer := preload("res://scripts/hud/pillar_dash_orb_renderer.gd")
const DashTokenBoostFxHost := preload("res://scripts/hud/dash_token_boost_fx_host.gd")
const Stage1PillarStatusOrbContextBuilder := preload("res://scripts/hud/stage1_pillar_status_orb_context_builder.gd")

# 79.2 / 105.6 = FHD(1080) / QHD(1440) 창 높이에서의 실제 라이브 오브 반경
# (55 * game_size.y / 750). 정적 레이어 캐시는 키가 정확히 일치해야 하므로
# 흔한 풀스크린 해상도의 정확한 반경을 프리웜 목록에 포함한다.
const DEFAULT_PREWARM_RADII := [55.0, 64.0, 72.0, 79.2, 80.0, 88.0, 96.0, 105.6, 112.0, 120.0]
const PREWARM_PASSES_PER_RADIUS := 3

var gauge_renderer: Object = PillarGaugeOrbRenderer.new()
var dash_renderer: Object = PillarDashOrbRenderer.new()
var _context_builder: Object = Stage1PillarStatusOrbContextBuilder.new()
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
	# 보스 대쉬 오브 프리웜 컨텍스트는 런타임과 같은 빌더에서 뽑아 캐시 키
	# (팔레트 / frame_width_base / max_tokens)가 실제 프레임과 일치하게 한다.
	var boss_dash_context: Dictionary = _context_builder.build_boss_dash_orb_context({}, null)
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
