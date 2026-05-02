extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneUpdateCallbacks := preload("res://scripts/core/battle_scene_update_callbacks.gd")

var _callbacks: Object = BattleSceneUpdateCallbacks.new()


func update(owner: Object, registry: Object, delta: float) -> void:
	if owner == null or registry == null:
		return
	var flow_controller: Object = _get_instance(registry, "battle_frame_flow_controller")
	if flow_controller == null:
		return

	_callbacks.bind(owner, registry)
	flow_controller.update(delta, {
		"scoreboard_state": _get_instance(registry, "scoreboard_state"),
		"power_state": _get_instance(registry, "smasher_power_smash_state"),
		"round_state": _get_instance(registry, "round_flow_state"),
		"serve_flow_controller": _get_instance(registry, "serve_flow_controller"),
		"serve_context": _build_serve_context(owner),
	}, _callbacks.build_frame_callbacks(owner))
	_callbacks.clear()


func update_scoreboard_overlay(owner: Object, registry: Object, delta: float) -> void:
	if owner == null or registry == null:
		return
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state == null or not scoreboard_state.is_active():
		return

	_callbacks.bind(owner, registry)
	var callbacks: Dictionary = _callbacks.build_frame_callbacks(owner)
	var update_scoreboard_callback: Callable = callbacks.get("update_scoreboard", Callable())
	if update_scoreboard_callback.is_valid():
		update_scoreboard_callback.call(delta)
	var redraw_callback: Callable = callbacks.get("queue_redraw", Callable())
	if redraw_callback.is_valid():
		redraw_callback.call()
	_callbacks.clear()


func update_scoreboard_visuals(owner: Object, registry: Object, delta: float) -> void:
	if owner == null or registry == null:
		return
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state == null:
		return

	var had_top_mini_sparkle := false
	if scoreboard_state.has_method("get_top_mini_score_sparkle_timer"):
		had_top_mini_sparkle = float(scoreboard_state.get_top_mini_score_sparkle_timer()) > 0.0
	if had_top_mini_sparkle and scoreboard_state.has_method("update_top_mini_sparkle"):
		scoreboard_state.update_top_mini_sparkle(delta)

	if had_top_mini_sparkle or _is_top_mini_deuce_mode(registry):
		owner.queue_redraw()


func reset_ball(owner: Object, registry: Object) -> void:
	_callbacks.reset_ball(owner, registry)


func prewarm_ball_update(owner: Object, registry: Object) -> void:
	var ball_driver: Object = _get_instance(registry, "battle_scene_ball_update_driver")
	if ball_driver != null and ball_driver.has_method("prewarm_update"):
		ball_driver.prewarm_update(owner, registry)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _build_serve_context(owner: Object) -> Dictionary:
	return {
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
	}


func _is_top_mini_deuce_mode(registry: Object) -> bool:
	var score_state: Object = _get_instance(registry, "match_score_state")
	if score_state == null or not score_state.has_method("get_snapshot"):
		return false
	var score_snapshot: Dictionary = score_state.get_snapshot()
	return bool(score_snapshot.get("deuce_mode", false))


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)
