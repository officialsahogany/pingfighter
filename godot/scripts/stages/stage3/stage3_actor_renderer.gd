extends RefCounted

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const Stage3PlayfieldRenderer := preload("res://scripts/stages/stage3/stage3_playfield_renderer.gd")
const Stage3MenheraBossActorRenderer := preload("res://scripts/stages/stage3/stage3_menhera_boss_actor_renderer.gd")
const Stage3MenheraSkillEffectRenderer := preload("res://scripts/stages/stage3/stage3_menhera_skill_effect_renderer.gd")

var playfield_renderer: Object = Stage3PlayfieldRenderer.new()
var player_renderer: Object = Stage1PlayerActorRenderer.new()
var boss_renderer: Object = Stage3MenheraBossActorRenderer.new()
var skill_effect_renderer: Object = Stage3MenheraSkillEffectRenderer.new()
var commando_firearm_renderer: Object = Stage1CommandoFirearmRenderer.new()
var _prewarm_assets_done: bool = false
var _prewarm_step_index: int = 0
var _method_argument_count_cache: Dictionary = {}


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_assets_done:
		return true
	match _prewarm_step_index:
		0:
			if playfield_renderer != null:
				if playfield_renderer.has_method("prewarm_assets_step"):
					if not bool(playfield_renderer.prewarm_assets_step()):
						return false
				elif playfield_renderer.has_method("prewarm_assets"):
					playfield_renderer.prewarm_assets()
		1:
			if boss_renderer != null:
				if boss_renderer.has_method("prewarm_assets_step"):
					if not bool(boss_renderer.prewarm_assets_step()):
						return false
				elif boss_renderer.has_method("prewarm_assets"):
					boss_renderer.prewarm_assets()
		2:
			if skill_effect_renderer != null and skill_effect_renderer.has_method("prewarm_assets"):
				skill_effect_renderer.prewarm_assets()
		3:
			if commando_firearm_renderer != null and commando_firearm_renderer.has_method("prewarm_assets"):
				commando_firearm_renderer.prewarm_assets()
		_:
			_prewarm_assets_done = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 3:
		_prewarm_assets_done = true
		_prewarm_step_index = 0
		return true
	return false


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
	if _get_method_argument_count(playfield_renderer, "draw") >= 4:
		playfield_renderer.draw(canvas, context, shake_offset, perf_logger)
	else:
		playfield_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage3.playfield", sample_start)
	sample_start = _perf_begin(perf_logger)
	skill_effect_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage3.skill_effect", sample_start)
	sample_start = _perf_begin(perf_logger)
	player_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage3.player", sample_start)
	sample_start = _perf_begin(perf_logger)
	boss_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage3.boss", sample_start)
	sample_start = _perf_begin(perf_logger)
	commando_firearm_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage3.commando_firearm", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_kuromi_awakening_overlay(canvas, context)
	_perf_end(perf_logger, "actors.stage3.awakening_overlay", sample_start)


func _draw_kuromi_awakening_overlay(canvas: CanvasItem, context: Dictionary) -> void:
	if not bool(context.get("stage3_kuromi_awakening", false)):
		return
	var width: float = maxf(1.0, float(context.get("width", 760.0)))
	var height: float = maxf(1.0, float(context.get("height", 750.0)))
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), Color(0.0, 0.0, 0.0, 100.0 / 255.0))


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


func _get_method_argument_count(target: Object, method_name: String) -> int:
	if target == null:
		return 0
	var cache_key := "%d:%s" % [target.get_instance_id(), method_name]
	if _method_argument_count_cache.has(cache_key):
		return int(_method_argument_count_cache[cache_key])
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			var args_count: int = args_value.size()
			_method_argument_count_cache[cache_key] = args_count
			return args_count
	_method_argument_count_cache[cache_key] = 0
	return 0
