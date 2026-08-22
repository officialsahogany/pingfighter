extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")
const Stage1PlayfieldRenderer := preload("res://scripts/stages/stage1/stage1_playfield_renderer.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1BossActorRenderer := preload("res://scripts/stages/stage1/stage1_boss_actor_renderer.gd")
const Stage1DaljiSpinningTopRenderer := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_renderer.gd")
const Stage1GaksitalFanThrowRenderer := preload("res://scripts/stages/stage1/stage1_gaksital_fan_throw_renderer.gd")
const Stage1PododaejangSkillRenderer := preload("res://scripts/stages/stage1/stage1_pododaejang_skill_renderer.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")

var playfield_renderer: Object = Stage1PlayfieldRenderer.new()
var player_renderer: Object = Stage1PlayerActorRenderer.new()
var boss_renderer: Object = Stage1BossActorRenderer.new()
var spinning_top_renderer: Object = Stage1DaljiSpinningTopRenderer.new()
var fan_throw_renderer: Object = Stage1GaksitalFanThrowRenderer.new()
var pododaejang_skill_renderer: Object = Stage1PododaejangSkillRenderer.new()
var commando_firearm_renderer: Object = Stage1CommandoFirearmRenderer.new()
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	match _prewarm_step_index:
		0:
			if playfield_renderer != null and playfield_renderer.has_method("prewarm_runtime_assets_step"):
				if not bool(playfield_renderer.prewarm_runtime_assets_step()):
					return false
			elif playfield_renderer != null and playfield_renderer.has_method("prewarm_runtime_assets"):
				playfield_renderer.prewarm_runtime_assets()
		1:
			if player_renderer != null and player_renderer.has_method("prewarm_runtime_assets_step"):
				if not bool(player_renderer.prewarm_runtime_assets_step()):
					return false
			elif player_renderer != null and player_renderer.has_method("prewarm_runtime_assets"):
				player_renderer.prewarm_runtime_assets()
		2:
			if commando_firearm_renderer != null and commando_firearm_renderer.has_method("prewarm_assets_step"):
				if not bool(commando_firearm_renderer.prewarm_assets_step()):
					return false
			elif commando_firearm_renderer != null and commando_firearm_renderer.has_method("prewarm_runtime_assets"):
				commando_firearm_renderer.prewarm_runtime_assets()
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func draw(canvas: CanvasItem, context: Dictionary, perf_logger: Object = null) -> void:
	if canvas == null:
		return

	var shake_offset: Vector2 = _as_vector2(context.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	var sample_start: int = _perf_begin(perf_logger)
	playfield_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage1.playfield", sample_start)
	sample_start = _perf_begin(perf_logger)
	playfield_renderer.draw_dash_trail(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage1.dash_trail", sample_start)
	sample_start = _perf_begin(perf_logger)
	player_renderer.draw(canvas, context, shake_offset, perf_logger)
	_perf_end(perf_logger, "actors.stage1.player", sample_start)
	sample_start = _perf_begin(perf_logger)
	boss_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage1.boss", sample_start)
	sample_start = _perf_begin(perf_logger)
	commando_firearm_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage1.commando_firearm", sample_start)


func clear_transient_canvas_items() -> void:
	_clear_renderer_transients(player_renderer)
	_clear_renderer_transients(boss_renderer)
	_clear_renderer_transients(commando_firearm_renderer)


func draw_spinning_top(canvas: CanvasItem, context: Dictionary, perf_logger: Object = null) -> void:
	if canvas == null:
		return
	var shake_offset: Vector2 = _as_vector2(context.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	spinning_top_renderer.draw(canvas, context, shake_offset, perf_logger)
	fan_throw_renderer.draw(canvas, context, shake_offset, perf_logger)
	pododaejang_skill_renderer.draw(canvas, context, shake_offset, perf_logger)


func _as_vector2(value, fallback: Vector2) -> Vector2:
	return Stage1ContextReader.as_vector2(value, fallback)


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
