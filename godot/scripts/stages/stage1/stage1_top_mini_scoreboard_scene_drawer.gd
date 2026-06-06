extends RefCounted

const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	states: Dictionary,
	game_offset: Vector2,
	game_size: Vector2,
	time_seconds: float
) -> void:
	var scoreboard_renderer: Object = registry.get_instance("scoreboard_renderer")
	if scoreboard_renderer == null:
		return
	var score_state: Object = registry.get_instance("match_score_state")
	var scoreboard_state: Object = states.get("scoreboard_state", null)
	var score_snapshot: Dictionary = score_state.get_snapshot() if score_state != null and score_state.has_method("get_snapshot") else {}
	var stakes: Dictionary = _build_stakes(score_state)
	scoreboard_renderer.draw_top_mini(
		canvas,
		game_offset,
		game_size,
		float(context.get("width", 760.0)),
		int(score_snapshot.get("player_score", 0)),
		int(score_snapshot.get("boss_score", 0)),
		bool(score_snapshot.get("deuce_mode", false)),
		scoreboard_state.get_top_mini_score_sparkle_timer() if scoreboard_state != null else 0.0,
		float(context.get("top_mini_score_sparkle_duration", 0.35)),
		time_seconds,
		_get_top_mini_quality_scale(context),
		stakes
	)


func _get_top_mini_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _build_stakes(score_state: Object) -> Dictionary:
	if score_state == null:
		return {}
	return {
		"player_can_win": _would_score_finish(score_state, "player"),
		"boss_can_win": _is_player_in_danger(score_state),
	}


func _would_score_finish(score_state: Object, scoring_side: String) -> bool:
	if score_state != null and score_state.has_method("would_score_finish"):
		return bool(score_state.would_score_finish(scoring_side))
	return false


func _is_player_in_danger(score_state: Object) -> bool:
	if score_state != null and score_state.has_method("is_player_in_danger"):
		return bool(score_state.is_player_in_danger())
	return _would_score_finish(score_state, "boss")
