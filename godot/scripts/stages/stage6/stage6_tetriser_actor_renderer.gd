extends RefCounted

# Stage 6 테트리서 actor renderer (SCAFFOLD).
#
# 기획: docs/stage6_tetriser_port_plan.md §3
# Stage 5 홍련 actor renderer 구조를 미러링한다. 플레이어와 코만도 화기는
# 공유 Stage1 렌더러로 그대로 그리고, 테트리서 전투 VFX(playfield)와 보스
# 스프라이트는 stage6 전용 모듈로 위임한다(현재 placeholder).
#
# 이 모듈이 stage6의 메인 draw 엔트리다(battle_playfield_effects_drawer가
# actor_renderer.draw를 가드 없이 호출). no-op로 두면 플레이어가 사라지므로
# 공유 렌더러 위임을 유지한다.

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const Stage6TetriserPlayfieldRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_playfield_renderer.gd")
const Stage6TetriserBossActorRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_boss_actor_renderer.gd")

var playfield_renderer: Object = Stage6TetriserPlayfieldRenderer.new()
var player_renderer: Object = Stage1PlayerActorRenderer.new()
var boss_renderer: Object = Stage6TetriserBossActorRenderer.new()
var commando_firearm_renderer: Object = Stage1CommandoFirearmRenderer.new()


func prewarm_assets() -> void:
	pass


func prewarm_assets_step() -> bool:
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
