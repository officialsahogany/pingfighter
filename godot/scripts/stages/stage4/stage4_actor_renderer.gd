extends RefCounted

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const Stage4PlayfieldRenderer := preload("res://scripts/stages/stage4/stage4_playfield_renderer.gd")
const Stage4PonkBossActorRenderer := preload("res://scripts/stages/stage4/stage4_ponk_boss_actor_renderer.gd")
const Stage4BirdEvent := preload("res://scripts/stages/stage4/stage4_bird_event.gd")
const Stage4BrazierMonkEvent := preload("res://scripts/stages/stage4/stage4_brazier_monk_event.gd")
const Stage4PonkSkillState := preload("res://scripts/stages/stage4/stage4_ponk_skill_state.gd")
const StatusEffectOverlayRenderer := preload("res://scripts/status/status_effect_overlay_renderer.gd")

var playfield_renderer: Object = Stage4PlayfieldRenderer.new()
var player_renderer: Object = Stage1PlayerActorRenderer.new()
var boss_renderer: Object = Stage4PonkBossActorRenderer.new()
var bird_event_renderer: Object = Stage4BirdEvent.new()
var monk_event_renderer: Object = Stage4BrazierMonkEvent.new()
var ponk_skill_renderer: Object = Stage4PonkSkillState.new()
var commando_firearm_renderer: Object = Stage1CommandoFirearmRenderer.new()
var status_overlay_renderer: Object = StatusEffectOverlayRenderer.new()
var _prewarm_assets_done := false
var _prewarm_step_index := 0
var _method_acceptance_cache: Dictionary = {}


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_assets_done:
		return true
	match _prewarm_step_index:
		0:
			if not _prewarm_renderer_step(playfield_renderer):
				return false
		1:
			if not _prewarm_renderer_step(boss_renderer):
				return false
		2:
			if not _prewarm_renderer_step(bird_event_renderer):
				return false
		3:
			if not _prewarm_renderer_step(monk_event_renderer):
				return false
		4:
			if not _prewarm_renderer_step(ponk_skill_renderer):
				return false
		5:
			if not _prewarm_renderer_step(commando_firearm_renderer):
				return false
		_:
			_prewarm_assets_done = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 5:
		_prewarm_assets_done = true
		_prewarm_step_index = 0
		return true
	return false


func prewarm_runtime_nodes_step(owner: Object) -> bool:
	if ponk_skill_renderer == null or not (owner is CanvasItem):
		return true
	if ponk_skill_renderer.has_method("prewarm_runtime_hosts_step"):
		return bool(ponk_skill_renderer.prewarm_runtime_hosts_step(owner as CanvasItem))
	if ponk_skill_renderer.has_method("prewarm_runtime_hosts"):
		ponk_skill_renderer.prewarm_runtime_hosts(owner as CanvasItem)
	return true


func reset() -> void:
	if playfield_renderer != null and playfield_renderer.has_method("reset"):
		playfield_renderer.reset()
	if boss_renderer != null and boss_renderer.has_method("reset"):
		boss_renderer.reset()
	if bird_event_renderer != null and bird_event_renderer.has_method("reset"):
		bird_event_renderer.reset()
	if monk_event_renderer != null and monk_event_renderer.has_method("reset"):
		monk_event_renderer.reset()
	if ponk_skill_renderer != null and ponk_skill_renderer.has_method("reset"):
		ponk_skill_renderer.reset()


func draw(canvas: CanvasItem, context: Dictionary, perf_logger: Object = null) -> void:
	if canvas == null:
		return
	var shake_offset: Vector2 = _as_vector2(context.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	var shake_intensity: float = float(context.get("stage4_screen_shake_intensity", 0.0))
	if shake_intensity > 0.01:
		@warning_ignore("shadowed_global_identifier")
		var seed: float = float(Time.get_ticks_msec()) * 0.051
		shake_offset += Vector2(sin(seed * 2.3), cos(seed * 1.7)) * shake_intensity * 0.45
	var sample_start: int = _perf_begin(perf_logger)
	playfield_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage4.playfield", sample_start)
	sample_start = _perf_begin(perf_logger)
	monk_event_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage4.brazier_monk", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_renderer(player_renderer, canvas, context, shake_offset, perf_logger)
	_perf_end(perf_logger, "actors.stage4.player", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_player_burn_overlay(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage4.player_burn_overlay", sample_start)
	sample_start = _perf_begin(perf_logger)
	boss_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage4.boss", sample_start)
	sample_start = _perf_begin(perf_logger)
	ponk_skill_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage4.ponk_skill", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_boss_status_overlays(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage4.status_overlays", sample_start)
	sample_start = _perf_begin(perf_logger)
	bird_event_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage4.bird_event", sample_start)
	if playfield_renderer != null and playfield_renderer.has_method("draw_moon_fragments"):
		sample_start = _perf_begin(perf_logger)
		playfield_renderer.draw_moon_fragments(canvas, context, shake_offset)
		_perf_end(perf_logger, "actors.stage4.moon_fragments", sample_start)
	sample_start = _perf_begin(perf_logger)
	commando_firearm_renderer.draw(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage4.commando_firearm", sample_start)


func clear_transient_canvas_items() -> void:
	_clear_renderer_transients(player_renderer)
	_clear_renderer_transients(boss_renderer)
	_clear_renderer_transients(bird_event_renderer)
	_clear_renderer_transients(monk_event_renderer)
	_clear_renderer_transients(ponk_skill_renderer)
	_clear_renderer_transients(commando_firearm_renderer)


func get_imagegen_asset_status() -> Dictionary:
	var result := {}
	if playfield_renderer != null and playfield_renderer.has_method("get_imagegen_asset_status"):
		result.merge(playfield_renderer.get_imagegen_asset_status(), true)
	if boss_renderer != null and boss_renderer.has_method("get_asset_status"):
		result.merge(boss_renderer.get_asset_status(), true)
	if monk_event_renderer != null and monk_event_renderer.has_method("get_asset_status"):
		result.merge(monk_event_renderer.get_asset_status(), true)
	if ponk_skill_renderer != null and ponk_skill_renderer.has_method("get_asset_status"):
		result.merge(ponk_skill_renderer.get_asset_status(), true)
	return result


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _draw_renderer(
	renderer: Object,
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2,
	perf_logger: Object
) -> void:
	if renderer == null or not renderer.has_method("draw"):
		return
	if _method_accepts_argument_count(renderer, "draw", 4):
		renderer.draw(canvas, context, shake_offset, perf_logger)
	else:
		renderer.draw(canvas, context, shake_offset)


func _method_accepts_argument_count(target: Object, method_name: String, requested_count: int) -> bool:
	if target == null:
		return false
	var cache_key := "%d:%s:%d" % [target.get_instance_id(), method_name, requested_count]
	if _method_acceptance_cache.has(cache_key):
		return bool(_method_acceptance_cache[cache_key])
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_value: Variant = method_info.get("args", [])
		var default_args_value: Variant = method_info.get("default_args", [])
		var method_arg_count: int = 0
		if args_value is Array:
			method_arg_count = int((args_value as Array).size())
		var default_count: int = 0
		if default_args_value is Array:
			default_count = int((default_args_value as Array).size())
		var accepts: bool = method_arg_count >= requested_count or method_arg_count + default_count >= requested_count
		_method_acceptance_cache[cache_key] = accepts
		return accepts
	_method_acceptance_cache[cache_key] = false
	return false


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


func _prewarm_renderer_step(renderer: Object) -> bool:
	if renderer == null:
		return true
	if renderer.has_method("prewarm_assets_step"):
		return bool(renderer.prewarm_assets_step())
	if renderer.has_method("prewarm_assets"):
		renderer.prewarm_assets()
	return true


func _draw_player_burn_overlay(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var burn_ratio: float = clampf(float(context.get("stage4_player_burn_ratio", context.get("status_player_burn_ratio", 0.0))), 0.0, 1.0)
	var burn_active: bool = bool(context.get("stage4_player_burn_active", context.get("status_player_burn_active", false))) or burn_ratio > 0.001
	if not burn_active:
		return
	if burn_ratio <= 0.001:
		burn_ratio = 1.0
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2(302.5, 690.0)), Vector2(302.5, 690.0))
	var paddle_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var center := player_pos + Vector2(paddle_size.x * 0.5, paddle_size.y * 0.50) + shake_offset
	var phase: float = float(Time.get_ticks_msec()) * 0.010
	var alpha: float = clampf(0.18 + burn_ratio * 0.34, 0.0, 0.56)
	canvas.draw_circle(center, maxf(paddle_size.x * 0.62, 58.0), Color(1.0, 0.18, 0.03, alpha * 0.32))
	canvas.draw_arc(center, maxf(paddle_size.x * 0.45, 44.0), phase, phase + PI * 1.38, 36, Color(1.0, 0.56, 0.12, alpha), 3.0, true)
	canvas.draw_arc(center + Vector2(0.0, -8.0), maxf(paddle_size.x * 0.34, 35.0), -phase * 0.8, -phase * 0.8 + PI, 32, Color(1.0, 0.86, 0.32, alpha * 0.70), 2.0, true)
	for idx in range(5):
		var x: float = player_pos.x + 18.0 + float(idx) * (paddle_size.x - 36.0) / 4.0
		var flicker: float = 0.5 + 0.5 * sin(phase * 1.9 + float(idx) * 1.3)
		var flame_h: float = (14.0 + flicker * 18.0) * burn_ratio
		var base := Vector2(x, player_pos.y + paddle_size.y * 0.85) + shake_offset
		var points := PackedVector2Array([
			base + Vector2(-5.0, 0.0),
			base + Vector2(0.0, -flame_h),
			base + Vector2(5.0, 0.0),
		])
		canvas.draw_colored_polygon(points, Color(1.0, 0.26 + flicker * 0.20, 0.04, alpha * 0.78))


func _draw_boss_status_overlays(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if status_overlay_renderer == null:
		return
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 18.0)), Vector2(100.0, 18.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", 40.0))
	var options := {"cooldown_pause_center_y_offset": -30.0}
	if status_overlay_renderer.has_method("draw_boss_status_overlays"):
		status_overlay_renderer.draw_boss_status_overlays(
			canvas,
			context,
			boss_pos,
			boss_size,
			boss_hitbox_height,
			shake_offset,
			options
		)
	elif status_overlay_renderer.has_method("draw_boss_cooldown_pause_marker"):
		status_overlay_renderer.draw_boss_cooldown_pause_marker(
			canvas,
			context,
			boss_pos,
			boss_size,
			boss_hitbox_height,
			shake_offset,
			options
		)
