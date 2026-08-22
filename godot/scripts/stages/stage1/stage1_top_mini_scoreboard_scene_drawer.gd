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
		stakes,
		_should_show_top_mini_scoreboard(registry)
	)


func _should_show_top_mini_scoreboard(registry: Object) -> bool:
	# 탑의 생산 비전투 노드(shop/training/fallen_monk/guardian_spring/rest)는
	# 모두 NODE_MODAL 한 경계에서 물리를 막는다. 그 모달이 실제로 열린 동안만
	# 전투 점수를 숨기고, COMBAT/지도/경로 및 비탑 캠페인에는 손대지 않는다.
	# common_shell fixture도 같은 모달 경계를 따르므로 미래/호환 폴백 누수를 막는다.
	if registry == null or not registry.has_method("get_cached_instance"):
		return true
	var flow_owner: Object = registry.get_cached_instance("tower_ascent_flow_owner")
	if flow_owner == null or not flow_owner.has_method("is_active") or not flow_owner.has_method("get_phase_name"):
		return true
	return not (bool(flow_owner.is_active()) and str(flow_owner.get_phase_name()) == "NODE_MODAL")


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
