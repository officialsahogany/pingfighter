extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneMatchResetResultApplier := preload("res://scripts/core/battle_scene_match_reset_result_applier.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")

var _fallback_scene_config: Object = BattleSceneConfig.new()
var _fallback_reset_result_applier: Object = BattleSceneMatchResetResultApplier.new()


func handle_score_event(
	registry: Object,
	scoring_side: String,
	reset_ball_callback: Callable,
	current_stage: int = 1,
	owner: Object = null
) -> void:
	var controller: Object = _get_instance(registry, "match_flow_controller")
	if controller == null:
		return
	controller.handle_score_event(scoring_side, _get_match_flow_deps(registry, current_stage, owner), {
		"reset_ball": reset_ball_callback,
	})


func handle_round_restart(registry: Object, reason: String, reset_ball_callback: Callable) -> void:
	var controller: Object = _get_instance(registry, "match_flow_controller")
	if controller == null:
		return
	controller.handle_round_restart(reason, _get_match_flow_deps(registry), {
		"reset_ball": reset_ball_callback,
	})


func update_scoreboard(
	registry: Object,
	delta: float,
	reset_game_callback: Callable,
	reset_ball_callback: Callable,
	owner: Object = null
) -> void:
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state != null and scoreboard_state.has_method("update_scoreboard"):
		var update_result: int = int(scoreboard_state.update_scoreboard(delta))
		if update_result == ScoreboardState.UPDATE_NONE:
			return
		_apply_scoreboard_update_result(
			update_result,
			registry,
			owner,
			reset_game_callback,
			reset_ball_callback
		)
		return

	var controller: Object = _get_instance(registry, "match_flow_controller")
	if controller == null:
		return
	controller.update_scoreboard(
		delta,
		_get_match_flow_deps(registry, int(_get_owner_value(owner, "current_stage", 1)), owner),
		{
			"reset_game": reset_game_callback,
			"reset_ball": reset_ball_callback,
			"show_stage_clear_result": Callable(self, "_show_stage_clear_result").bind(registry, reset_game_callback, owner),
		},
		{
			"update_reset_game": ScoreboardState.UPDATE_RESET_GAME,
			"update_start_serve": ScoreboardState.UPDATE_START_SERVE,
		}
	)


func apply_scoreboard_update_result(
	update_result: int,
	registry: Object,
	owner: Object,
	reset_game_callback: Callable,
	reset_ball_callback: Callable
) -> void:
	_apply_scoreboard_update_result(
		update_result,
		registry,
		owner,
		reset_game_callback,
		reset_ball_callback
	)


func _apply_scoreboard_update_result(
	update_result: int,
	registry: Object,
	owner: Object,
	reset_game_callback: Callable,
	reset_ball_callback: Callable
) -> void:
	var deps: Dictionary = _get_match_flow_deps(registry, int(_get_owner_value(owner, "current_stage", 1)), owner)
	if update_result == ScoreboardState.UPDATE_RESET_GAME:
		if _show_stage_clear_result(registry, reset_game_callback, owner):
			return
		_call_callback(reset_game_callback)
	elif update_result == ScoreboardState.UPDATE_START_SERVE:
		_call_callback(reset_ball_callback)
		var round_state: Object = deps.get("round_state", null)
		if round_state != null and round_state.has_method("prepare_serve_after_scoreboard"):
			round_state.prepare_serve_after_scoreboard()
		_start_stage4_pending_destruction(deps)
		_start_pending_pandora_legacy_selection(deps)


func _call_callback(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()


func _start_pending_pandora_legacy_selection(deps: Dictionary) -> void:
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("start_pending_pandora_legacy_selection"):
		return
	mythic_item_runtime.start_pending_pandora_legacy_selection(
		deps.get("owner", null),
		deps.get("registry", null)
	)


func _start_stage4_pending_destruction(deps: Dictionary) -> void:
	if int(deps.get("current_stage", 1)) != 4:
		return
	var stage4_map_state: Object = deps.get("stage4_map_state", null)
	if stage4_map_state != null and stage4_map_state.has_method("handle_scoreboard_serve_prepare"):
		stage4_map_state.handle_scoreboard_serve_prepare(deps)


func _show_stage_clear_result(registry: Object, reset_game_callback: Callable, owner: Object) -> bool:
	var result_screen: Object = _get_instance(registry, "stage_clear_result_screen")
	if result_screen == null or not result_screen.has_method("show_from_scoreboard"):
		return false
	var exit_callback := Callable(self, "_exit_to_main_menu").bind(owner)
	return bool(result_screen.show_from_scoreboard(owner, registry, reset_game_callback, exit_callback))


func _exit_to_main_menu(owner: Object) -> void:
	if not (owner is Node):
		return
	var owner_node: Node = owner as Node
	var tree: SceneTree = owner_node.get_tree()
	if tree == null:
		return
	var error: int = tree.change_scene_to_file("res://scenes/character_select.tscn")
	if error != OK:
		push_warning("Failed to change scene to character_select.tscn (error %d)" % error)


func reset_game(
	owner: Object,
	registry: Object,
	reset_drive_input_callback: Callable,
	reset_ball_callback: Callable
) -> void:
	var controller: Object = _get_instance(registry, "match_flow_controller")
	if controller == null or owner == null:
		return
	var result: Dictionary = controller.reset_game(_get_match_flow_deps(
		registry,
		int(_get_owner_value(owner, "current_stage", 1)),
		owner
	), {
		"reset_drive_input": reset_drive_input_callback,
		"reset_ball": reset_ball_callback,
	})
	_get_reset_result_applier(registry).apply_reset_result(owner, result)


func reset_for_stage_transition(
	owner: Object,
	registry: Object,
	reset_drive_input_callback: Callable,
	reset_ball_callback: Callable
) -> void:
	var controller: Object = _get_instance(registry, "match_flow_controller")
	if controller == null or owner == null:
		return
	if not controller.has_method("reset_for_stage_transition"):
		reset_game(owner, registry, reset_drive_input_callback, reset_ball_callback)
		return
	var result: Dictionary = controller.reset_for_stage_transition(_get_match_flow_deps(
		registry,
		int(_get_owner_value(owner, "current_stage", 1)),
		owner
	), {
		"reset_drive_input": reset_drive_input_callback,
		"reset_ball": reset_ball_callback,
	})
	_get_reset_result_applier(registry).apply_reset_result(owner, result)
	_reset_active_item_cooldowns_for_stage_transition(owner, registry)
	_notify_mythic_stage_advance(owner, registry)


func _get_match_flow_deps(registry: Object, current_stage: int = 1, owner: Object = null) -> Dictionary:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return {}
	var deps: Dictionary = context_builder.build_match_flow_deps(registry, current_stage)
	deps["registry"] = registry
	if owner != null:
		deps["owner"] = owner
		deps["starting_dash_tokens"] = _get_starting_dash_tokens(owner, registry)
		deps["league_player_paddle_scale"] = _get_league_player_paddle_scale(owner, registry)
		deps["league_boss_paddle_scale"] = _get_league_boss_paddle_scale(owner, registry)
	return deps


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_reset_result_applier(registry: Object) -> Object:
	var applier: Object = _get_instance(registry, "battle_scene_match_reset_result_applier")
	if applier != null and applier.has_method("apply_reset_result"):
		return applier
	return _fallback_reset_result_applier


func _get_starting_dash_tokens(owner: Object, registry: Object) -> int:
	if owner == null:
		return 1
	var owner_value: Variant = owner.get("starting_dash_tokens")
	if owner_value != null:
		return max(1, int(owner_value))
	var config: Object = _get_instance(registry, "battle_scene_config")
	if config == null:
		config = _fallback_scene_config
	if config != null and config.has_method("get_starting_dash_tokens"):
		return max(1, int(config.get_starting_dash_tokens(owner)))
	return 1


func _get_league_player_paddle_scale(owner: Object, registry: Object) -> float:
	if owner == null:
		return 1.0
	var config: Object = _get_instance(registry, "battle_scene_config")
	if config == null:
		config = _fallback_scene_config
	if config != null and config.has_method("get_league_player_paddle_scale"):
		return max(0.1, float(config.get_league_player_paddle_scale(owner)))
	return 1.0


func _get_league_boss_paddle_scale(owner: Object, registry: Object) -> float:
	if owner == null:
		return 1.0
	var config: Object = _get_instance(registry, "battle_scene_config")
	if config == null:
		config = _fallback_scene_config
	if config != null and config.has_method("get_league_boss_paddle_scale"):
		return max(0.1, float(config.get_league_boss_paddle_scale(owner)))
	return 1.0


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _reset_active_item_cooldowns_for_stage_transition(owner: Object, registry: Object) -> void:
	if owner == null:
		return
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime == null:
		return
	if active_item_runtime.has_method("reset_for_stage_transition"):
		active_item_runtime.reset_for_stage_transition(owner, registry)
		return
	var slot_controller_value: Variant = active_item_runtime.get("slot_controller")
	if not (slot_controller_value is Object):
		return
	var slot_controller: Object = slot_controller_value
	if not slot_controller.has_method("reset_cooldowns_for_stage_transition"):
		return
	var current_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	var cleaned_slots: Array = slot_controller.reset_cooldowns_for_stage_transition(current_slots)
	owner.set("active_item_slots", cleaned_slots)


func _notify_mythic_stage_advance(owner: Object, registry: Object) -> void:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("on_stage_advance"):
		return
	mythic_item_runtime.on_stage_advance(owner, registry)
