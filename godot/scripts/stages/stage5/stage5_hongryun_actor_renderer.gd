extends RefCounted

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const Stage5HongryunPlayfieldRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_playfield_renderer.gd")
const Stage5HongryunBossActorRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_boss_actor_renderer.gd")

var playfield_renderer: Object = Stage5HongryunPlayfieldRenderer.new()
var player_renderer: Object = Stage1PlayerActorRenderer.new()
var boss_renderer: Object = Stage5HongryunBossActorRenderer.new()
var commando_firearm_renderer: Object = Stage1CommandoFirearmRenderer.new()


func prewarm_assets() -> void:
	if playfield_renderer != null and playfield_renderer.has_method("prewarm_assets"):
		playfield_renderer.prewarm_assets()
	if boss_renderer != null and boss_renderer.has_method("prewarm_assets"):
		boss_renderer.prewarm_assets()
	if commando_firearm_renderer != null and commando_firearm_renderer.has_method("prewarm_assets"):
		commando_firearm_renderer.prewarm_assets()


func reset() -> void:
	if playfield_renderer != null and playfield_renderer.has_method("reset"):
		playfield_renderer.reset()
	if boss_renderer != null and boss_renderer.has_method("reset"):
		boss_renderer.reset()


func draw(canvas: CanvasItem, context: Dictionary, perf_logger: Object = null) -> void:
	if canvas == null:
		return
	var shake_offset: Vector2 = _as_vector2(context.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	var sample_start: int = _perf_begin(perf_logger)
	playfield_renderer.draw(canvas, context, shake_offset, perf_logger)
	_perf_end(perf_logger, "actors.stage5.playfield", sample_start)
	sample_start = _perf_begin(perf_logger)
	player_renderer.draw(canvas, context, shake_offset, perf_logger)
	_perf_end(perf_logger, "actors.stage5.player", sample_start)
	sample_start = _perf_begin(perf_logger)
	boss_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage5.boss", sample_start)
	sample_start = _perf_begin(perf_logger)
	commando_firearm_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage5.commando_firearm", sample_start)


func get_imagegen_asset_status() -> Dictionary:
	var result := {}
	if playfield_renderer != null and playfield_renderer.has_method("get_imagegen_asset_status"):
		result.merge(playfield_renderer.get_imagegen_asset_status(), true)
	if boss_renderer != null and boss_renderer.has_method("get_asset_status"):
		result.merge(boss_renderer.get_asset_status(), true)
	return result


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
