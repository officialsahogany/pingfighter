extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")
const BallRenderInterpolation := preload("res://scripts/ball/ball_render_interpolation.gd")


func draw_ball_effects(
	canvas: CanvasItem,
	registry: Object,
	draw_context_builder: Object,
	draw_context: Dictionary,
	draw_deps: Dictionary,
	shake_offset: Vector2,
	perf_logger: Object = null
) -> void:
	if not bool(canvas.get("ball_active")) or str(canvas.get("ball_visual_type")) == "pingpong":
		return
	var ball_effects_renderer: Object = _get_instance(registry, "ball_effects_renderer")
	if ball_effects_renderer != null and draw_context_builder != null:
		ball_effects_renderer.draw_active_effects(
			canvas,
			shake_offset,
			draw_context_builder.build_ball_effects_context(draw_context, draw_deps),
			perf_logger
		)


func draw_ball(
	canvas: CanvasItem,
	registry: Object,
	draw_context_builder: Object,
	draw_context: Dictionary,
	draw_deps: Dictionary,
	shake_offset: Vector2,
	width: float = 760.0,
	height: float = 750.0,
	perf_logger: Object = null
) -> void:
	if draw_context_builder == null:
		return
	var sample_start: int = _perf_begin(perf_logger)
	var ball_draw: Dictionary = draw_context_builder.build_ball_draw(draw_context, draw_deps)
	_perf_end(perf_logger, "ball.build_draw", sample_start)
	if not bool(ball_draw.get("should_draw", false)):
		return
	var ball_renderer: Object = _get_instance(registry, "ball_renderer")
	if ball_renderer == null:
		return
	var ball_renderer_context: Dictionary = _get_dict(ball_draw.get("context", {}))
	var draw_pos: Vector2 = _get_vector2(
		ball_draw,
		"draw_pos",
		_get_canvas_vector2(canvas, "ball_pos", Vector2.ZERO) + shake_offset
	)
	sample_start = _perf_begin(perf_logger)
	ball_renderer_context["node_fx_layout"] = _build_node_fx_layout(
		canvas,
		registry,
		draw_pos,
		shake_offset,
		width,
		height
	)
	_perf_end(perf_logger, "ball.node_fx_layout", sample_start)
	# Opus 비주얼 레인: 배선이 노출한 오버드라이브 신호 스냅샷을 렌더 컨텍스트로
	# 전달(구독자). 활성일 때만 실제 스냅샷을 실어 비활성 프레임의 duplicate 비용을
	# 피하고, 렌더러는 비활성/부재를 소멸 페이드로 처리한다.
	ball_renderer_context["smasher_overdrive_fx"] = _build_overdrive_fx(registry)
	sample_start = _perf_begin(perf_logger)
	ball_renderer.draw_current(
		canvas,
		draw_pos,
		ball_renderer_context,
		perf_logger
	)
	_perf_end(perf_logger, "ball.renderer_draw", sample_start)
	BallRenderInterpolation.consume_reset_on_owner(canvas)


func _build_overdrive_fx(registry: Object) -> Dictionary:
	var overdrive_state: Object = _get_instance(registry, "smasher_overdrive_state")
	if overdrive_state == null or not overdrive_state.has_method("is_active"):
		return {}
	if bool(overdrive_state.is_active()) and overdrive_state.has_method("get_snapshot"):
		var snapshot: Variant = overdrive_state.get_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return {"smasher_overdrive_active": false}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_canvas_vector2(canvas: CanvasItem, key: String, fallback: Vector2) -> Vector2:
	if canvas == null:
		return fallback
	var value: Variant = canvas.get(key)
	if value is Vector2:
		return value
	return fallback


func _get_dict(value: Variant) -> Dictionary:
	return BattleContextReader.get_dictionary(value)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BattleContextReader.get_vector2(source, key, fallback)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _build_node_fx_layout(
	canvas: CanvasItem,
	registry: Object,
	draw_pos: Vector2,
	shake_offset: Vector2,
	width: float,
	height: float
) -> Dictionary:
	var render_scale: float = 1.0
	var game_offset := Vector2.ZERO
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module != null and layout_module.has_method("build_game_layout"):
		var layout: Dictionary = layout_module.build_game_layout(canvas.get_viewport_rect().size, width, height)
		render_scale = max(0.01, float(layout.get("render_scale", 1.0)))
		game_offset = _get_vector2(layout, "game_offset", Vector2.ZERO)
	return {
		"screen_pos": game_offset + (draw_pos + shake_offset) * render_scale,
		"render_scale": render_scale,
		"game_offset": game_offset,
		"shake_offset": shake_offset,
	}
