extends RefCounted

const MatchScoreStateScript := preload("res://scripts/core/match_score_state.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")


func draw_skill_banners(
	canvas: CanvasItem,
	registry: Object,
	draw_context_builder: Object,
	draw_context: Dictionary,
	draw_deps: Dictionary,
	width: float,
	height: float
) -> void:
	var skill_feedback_renderer: Object = _get_instance(registry, "smasher_skill_feedback_renderer")
	if skill_feedback_renderer != null and draw_context_builder != null:
		skill_feedback_renderer.draw_banners(
			canvas,
			width,
			height,
			draw_context_builder.build_banner_context(draw_context, draw_deps)
		)
	var serve_wait_renderer: Object = _get_instance(registry, "serve_wait_indicator_renderer")
	if serve_wait_renderer != null:
		serve_wait_renderer.draw(canvas, width, height, draw_context, draw_deps)


func draw_scoreboard_overlay(
	canvas: CanvasItem,
	registry: Object,
	width: float,
	height: float,
	draw_context: Dictionary = {},
	perf_logger: Object = null
) -> void:
	if _is_stage_clear_result_active(registry):
		return
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state == null or not scoreboard_state.is_active():
		return
	var scoreboard_renderer: Object = _get_instance(registry, "scoreboard_renderer")
	if scoreboard_renderer == null:
		return
	var match_score_state: Object = _get_instance(registry, "match_score_state")
	scoreboard_renderer.draw_overlay(
		canvas,
		scoreboard_state,
		width,
		height,
		match_score_state.get_win_goal() if match_score_state != null else MatchScoreStateScript.WIN_GOAL,
		ScoreboardState.SCOREBOARD_FADE_IN_DURATION,
		draw_context,
		perf_logger
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _is_stage_clear_result_active(registry: Object) -> bool:
	var result_screen: Object = _get_instance(registry, "stage_clear_result_screen")
	return result_screen != null and result_screen.has_method("is_active") and bool(result_screen.is_active())
