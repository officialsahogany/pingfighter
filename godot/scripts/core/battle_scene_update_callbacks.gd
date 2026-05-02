extends RefCounted

const BattleSceneEffectsUpdateDriver := preload("res://scripts/core/battle_scene_effects_update_driver.gd")
const BattleSceneMatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")

var _owner: Object
var _registry: Object
var _effects_driver: Object = BattleSceneEffectsUpdateDriver.new()
var _match_flow_driver: Object = BattleSceneMatchFlowDriver.new()


func bind(owner: Object, registry: Object) -> void:
	_owner = owner
	_registry = registry


func clear() -> void:
	_owner = null
	_registry = null


func build_frame_callbacks(owner: Object) -> Dictionary:
	return {
		"update_scoreboard": Callable(self, "_update_scoreboard"),
		"update_effects": Callable(self, "_update_effects"),
		"update_ball": Callable(self, "_update_ball"),
		"update_player_control": Callable(self, "_update_player_control"),
		"update_boss_ai": Callable(self, "_update_boss_ai"),
		"serve_ball": Callable(self, "_serve_ball"),
		"queue_redraw": Callable(owner, "queue_redraw"),
	}


func reset_ball(owner: Object, registry: Object) -> void:
	var ball_driver: Object = _get_instance(registry, "battle_scene_ball_update_driver")
	if ball_driver != null:
		ball_driver.reset_ball(owner, registry)


func _reset_drive_input_frames() -> void:
	var ball_driver: Object = _get_instance(_registry, "battle_scene_ball_update_driver")
	if ball_driver != null:
		ball_driver.reset_drive_input_frames(_registry)


func _update_player_control(delta: float) -> void:
	var actor_driver: Object = _get_instance(_registry, "battle_scene_actor_update_driver")
	if actor_driver != null:
		actor_driver.update_player_control(_owner, _registry, delta)


func _update_boss_ai(delta: float) -> void:
	var actor_driver: Object = _get_instance(_registry, "battle_scene_actor_update_driver")
	if actor_driver != null:
		actor_driver.update_boss_ai(_owner, _registry, delta)


func _reset_ball() -> void:
	var ball_driver: Object = _get_instance(_registry, "battle_scene_ball_update_driver")
	if ball_driver != null:
		ball_driver.reset_ball(_owner, _registry)


func _serve_ball() -> void:
	var ball_driver: Object = _get_instance(_registry, "battle_scene_ball_update_driver")
	if ball_driver != null:
		ball_driver.serve_ball(_owner, _registry)


func _update_ball(delta: float) -> void:
	var ball_driver: Object = _get_instance(_registry, "battle_scene_ball_update_driver")
	if ball_driver != null:
		ball_driver.update_ball(_owner, _registry, delta, Callable(self, "_handle_score_event"))


func _update_effects(delta: float) -> void:
	_effects_driver.update_effects(_owner, _registry, delta)


func _handle_score_event(scoring_side: String) -> void:
	_match_flow_driver.handle_score_event(_registry, scoring_side, Callable(self, "_reset_ball"))


func _update_scoreboard(delta: float) -> void:
	_match_flow_driver.update_scoreboard(_registry, delta, Callable(self, "_reset_game"))


func _reset_game() -> void:
	_match_flow_driver.reset_game(
		_owner,
		_registry,
		Callable(self, "_reset_drive_input_frames"),
		Callable(self, "_reset_ball")
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
