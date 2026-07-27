extends RefCounted

# Stage 6 Tetriser actor renderer.
#
# Planning: docs/stage6_tetriser_port_plan.md
# Main Stage 6 draw entry. It keeps the shared Stage 1 player/Commando firearm
# renderers in the actor pass, then delegates Tetriser playfield mechanics and
# the real Stage 6 boss sprite sheets to dedicated Stage 6 modules.

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const Stage6TetriserPlayfieldRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_playfield_renderer.gd")
const Stage6TetriserBossActorRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_boss_actor_renderer.gd")

var playfield_renderer: Object = Stage6TetriserPlayfieldRenderer.new()
var player_renderer: Object = Stage1PlayerActorRenderer.new()
var boss_renderer: Object = Stage6TetriserBossActorRenderer.new()
var commando_firearm_renderer: Object = Stage1CommandoFirearmRenderer.new()
var _prewarm_step_index := 0
var _prewarmed := false


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


# 자식 렌더러로 스텝 위임(Stage 5 패턴). 위임이 없던 동안 boss_renderer의
# 768x768 시트 7장이 `_ensure_textures()` -> 동기 while 루프로 첫 전투 draw
# 프레임 안에서 디코드됐다(actors.renderer_draw 51.7ms 실측).
func prewarm_assets_step() -> bool:
	if _prewarmed:
		return true
	var done := true
	match _prewarm_step_index:
		0:
			done = _prewarm_module_assets_step(playfield_renderer)
		1:
			done = _prewarm_module_assets_step(boss_renderer)
		2:
			done = _prewarm_module_assets_step(commando_firearm_renderer)
		_:
			_prewarmed = true
			_prewarm_step_index = 0
			return true
	if not done:
		return false
	_prewarm_step_index += 1
	return false


func _prewarm_module_assets_step(module: Object) -> bool:
	if module == null:
		return true
	if module.has_method("prewarm_assets_step"):
		return bool(module.prewarm_assets_step())
	if module.has_method("prewarm_assets"):
		module.prewarm_assets()
	return true


func reset() -> void:
	reset_round_fx()
	if boss_renderer != null and boss_renderer.has_method("reset"):
		boss_renderer.reset()


func reset_round_fx() -> void:
	if playfield_renderer != null and playfield_renderer.has_method("reset"):
		playfield_renderer.reset()


func draw(canvas: CanvasItem, context: Dictionary, perf_logger: Object = null) -> void:
	if canvas == null:
		return
	var shake_offset: Vector2 = _as_vector2(context.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	playfield_renderer.draw(canvas, context, shake_offset, perf_logger)
	player_renderer.draw(canvas, context, shake_offset, perf_logger)
	boss_renderer.draw(canvas, context, shake_offset)
	commando_firearm_renderer.draw(canvas, context, shake_offset)


func clear_transient_canvas_items() -> void:
	_clear_renderer_transients(playfield_renderer)
	_clear_renderer_transients(player_renderer)
	_clear_renderer_transients(boss_renderer)
	_clear_renderer_transients(commando_firearm_renderer)


func get_imagegen_asset_status() -> Dictionary:
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _clear_renderer_transients(renderer: Object) -> void:
	if renderer != null and renderer.has_method("clear_transient_canvas_items"):
		renderer.clear_transient_canvas_items()
