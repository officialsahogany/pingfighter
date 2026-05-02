extends RefCounted


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
	var score_snapshot: Dictionary = score_state.get_snapshot() if score_state != null else {}
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
		time_seconds
	)
