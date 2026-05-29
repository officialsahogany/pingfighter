extends RefCounted

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const Stage5HongryunPlayfieldRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_playfield_renderer.gd")
const Stage5HongryunBossActorRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_boss_actor_renderer.gd")

var playfield_renderer: Object = Stage5HongryunPlayfieldRenderer.new()
var player_renderer: Object = Stage1PlayerActorRenderer.new()
var boss_renderer: Object = Stage5HongryunBossActorRenderer.new()
var commando_firearm_renderer: Object = Stage1CommandoFirearmRenderer.new()
var _prewarm_step_index := 0
var _prewarmed := false


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


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


func clear_transient_canvas_items() -> void:
	_clear_renderer_transients(playfield_renderer)
	_clear_renderer_transients(player_renderer)
	_clear_renderer_transients(boss_renderer)
	_clear_renderer_transients(commando_firearm_renderer)


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


func _clear_renderer_transients(renderer: Object) -> void:
	if renderer != null and renderer.has_method("clear_transient_canvas_items"):
		renderer.clear_transient_canvas_items()
