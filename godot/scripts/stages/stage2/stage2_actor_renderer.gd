extends RefCounted

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const Stage2PlayfieldRenderer := preload("res://scripts/stages/stage2/stage2_playfield_renderer.gd")
const Stage2BossActorRenderer := preload("res://scripts/stages/stage2/stage2_boss_actor_renderer.gd")
const Stage2VariantBossRenderer := preload("res://scripts/stages/stage2/stage2_variant_boss_renderer.gd")

var playfield_renderer: Object = Stage2PlayfieldRenderer.new()
var player_renderer: Object = Stage1PlayerActorRenderer.new()
var boss_renderer: Object = Stage2BossActorRenderer.new()
var variant_boss_renderer: Object = Stage2VariantBossRenderer.new()
var commando_firearm_renderer: Object = Stage1CommandoFirearmRenderer.new()
var prewarm_done := false
var prewarm_step_index := 0
var _method_argument_count_cache: Dictionary = {}


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if prewarm_done:
		return true
	match prewarm_step_index:
		0:
			if playfield_renderer != null:
				if playfield_renderer.has_method("prewarm_assets_step"):
					if not bool(playfield_renderer.prewarm_assets_step()):
						return false
				elif playfield_renderer.has_method("prewarm_assets"):
					playfield_renderer.prewarm_assets()
		1:
			var selected_boss_renderer: Object = variant_boss_renderer if variant_boss_renderer != null else boss_renderer
			if selected_boss_renderer != null:
				if selected_boss_renderer.has_method("prewarm_assets_step"):
					if not bool(selected_boss_renderer.prewarm_assets_step()):
						return false
				elif selected_boss_renderer.has_method("prewarm_assets"):
					selected_boss_renderer.prewarm_assets()
			if boss_renderer != null and boss_renderer != selected_boss_renderer and boss_renderer.has_method("prewarm_assets"):
				boss_renderer.prewarm_assets()
		2:
			if commando_firearm_renderer != null:
				if commando_firearm_renderer.has_method("prewarm_assets_step"):
					if not bool(commando_firearm_renderer.prewarm_assets_step()):
						return false
				elif commando_firearm_renderer.has_method("prewarm_assets"):
					commando_firearm_renderer.prewarm_assets()
		_:
			prewarm_done = true
			prewarm_step_index = 0
			return true
	prewarm_step_index += 1
	if prewarm_step_index > 2:
		prewarm_done = true
		prewarm_step_index = 0
		return true
	return false


func draw(canvas: CanvasItem, context: Dictionary, perf_logger: Object = null) -> void:
	if canvas == null:
		return
	var shake_offset: Vector2 = _as_vector2(context.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	var sample_start: int = _perf_begin(perf_logger)
	if _get_method_argument_count(playfield_renderer, "draw") >= 4:
		playfield_renderer.draw(canvas, context, shake_offset, perf_logger)
	else:
		playfield_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage2.playfield", sample_start)
	sample_start = _perf_begin(perf_logger)
	player_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage2.player", sample_start)
	sample_start = _perf_begin(perf_logger)
	if str(context.get("stage_boss_variant", "cheongringwi")) in ["molewang", "arachne"]:
		variant_boss_renderer.draw(canvas, context, shake_offset)
	else:
		boss_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage2.boss", sample_start)
	sample_start = _perf_begin(perf_logger)
	commando_firearm_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage2.commando_firearm", sample_start)


func clear_transient_canvas_items() -> void:
	_clear_renderer_transients(player_renderer)
	_clear_renderer_transients(boss_renderer)
	_clear_renderer_transients(variant_boss_renderer)
	_clear_renderer_transients(commando_firearm_renderer)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _clear_renderer_transients(renderer: Object) -> void:
	if renderer != null and renderer.has_method("clear_transient_canvas_items"):
		renderer.clear_transient_canvas_items()


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
		if str(method_info.get("name", "")) == method_name:
			var args: Array = method_info.get("args", [])
			var args_count: int = args.size()
			_method_argument_count_cache[cache_key] = args_count
			return args_count
	_method_argument_count_cache[cache_key] = 0
	return 0
