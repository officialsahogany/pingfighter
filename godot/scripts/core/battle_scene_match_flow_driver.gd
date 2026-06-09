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
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var sample_start: int = _perf_begin(perf_logger)
	var deps: Dictionary = _get_match_flow_deps(
		registry,
		current_stage,
		owner,
		"physics.score_event.match_flow.deps",
		false
	)
	_perf_end(perf_logger, "physics.score_event.match_flow.build_deps", sample_start)
	sample_start = _perf_begin(perf_logger)
	controller.handle_score_event(scoring_side, deps, {
		"reset_ball": reset_ball_callback,
	})
	_perf_end(perf_logger, "physics.score_event.match_flow.controller", sample_start)


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
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	if update_result == ScoreboardState.UPDATE_RESET_GAME:
		var show_result_start: int = _perf_begin(perf_logger)
		if _show_stage_clear_result(registry, reset_game_callback, owner):
			_perf_end(perf_logger, "physics.scoreboard_result.show_stage_clear", show_result_start)
			_perf_end(perf_logger, "physics.scoreboard_result.total", total_start)
			return
		_perf_end(perf_logger, "physics.scoreboard_result.show_stage_clear", show_result_start)
		var reset_game_start: int = _perf_begin(perf_logger)
		_call_callback(reset_game_callback)
		_perf_end(perf_logger, "physics.scoreboard_result.reset_game_callback", reset_game_start)
	elif update_result == ScoreboardState.UPDATE_START_SERVE:
		var current_stage: int = int(_get_owner_value(owner, "current_stage", 1))
		var deps_start: int = _perf_begin(perf_logger)
		var deps: Dictionary = _get_scoreboard_result_deps(registry, current_stage, owner)
		_perf_end(perf_logger, "physics.scoreboard_result.build_light_deps", deps_start)
		var reset_ball_start: int = _perf_begin(perf_logger)
		_call_callback(reset_ball_callback)
		_perf_end(perf_logger, "physics.scoreboard_result.reset_ball_callback", reset_ball_start)
		var prepare_serve_start: int = _perf_begin(perf_logger)
		var round_state: Object = deps.get("round_state", null)
		if round_state != null and round_state.has_method("prepare_serve_after_scoreboard"):
			round_state.prepare_serve_after_scoreboard()
		_perf_end(perf_logger, "physics.scoreboard_result.prepare_serve", prepare_serve_start)
		var stage4_start: int = _perf_begin(perf_logger)
		_start_stage4_pending_destruction(deps)
		_perf_end(perf_logger, "physics.scoreboard_result.stage4_prepare", stage4_start)
		var pandora_start: int = _perf_begin(perf_logger)
		_start_pending_pandora_legacy_selection(deps)
		_perf_end(perf_logger, "physics.scoreboard_result.pandora_selection", pandora_start)
	_perf_end(perf_logger, "physics.scoreboard_result.total", total_start)


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


func _get_match_flow_deps(
	registry: Object,
	current_stage: int = 1,
	owner: Object = null,
	perf_label_prefix: String = "",
	include_all_stage_deps: bool = true
) -> Dictionary:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return {}
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var context_perf_logger: Object = perf_logger if perf_label_prefix != "" else null
	var character_type := ""
	if owner != null:
		character_type = str(BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher"))
	var deps: Dictionary
	if _method_accepts_argument_count(context_builder, "build_match_flow_deps", 6):
		deps = context_builder.build_match_flow_deps(
			registry,
			current_stage,
			context_perf_logger,
			perf_label_prefix,
			include_all_stage_deps,
			character_type
		)
	elif _method_accepts_argument_count(context_builder, "build_match_flow_deps", 5):
		deps = context_builder.build_match_flow_deps(
			registry,
			current_stage,
			context_perf_logger,
			perf_label_prefix,
			include_all_stage_deps
		)
	elif _method_accepts_argument_count(context_builder, "build_match_flow_deps", 4):
		deps = context_builder.build_match_flow_deps(
			registry,
			current_stage,
			context_perf_logger,
			perf_label_prefix
		)
	elif _method_accepts_argument_count(context_builder, "build_match_flow_deps", 3):
		deps = context_builder.build_match_flow_deps(registry, current_stage, context_perf_logger)
	else:
		deps = context_builder.build_match_flow_deps(registry, current_stage)
	deps["registry"] = registry
	if perf_logger != null:
		deps["perf_logger"] = perf_logger
	if owner != null:
		var owner_start: int = _perf_begin(context_perf_logger)
		deps["owner"] = owner
		deps["starting_dash_tokens"] = _get_starting_dash_tokens(owner, registry)
		deps["league_player_paddle_scale"] = _get_league_player_paddle_scale(owner, registry)
		deps["league_boss_paddle_scale"] = _get_league_boss_paddle_scale(owner, registry)
		_perf_end(context_perf_logger, "%s.owner_extras" % perf_label_prefix, owner_start)
	return deps


func _get_scoreboard_result_deps(registry: Object, current_stage: int, owner: Object) -> Dictionary:
	var deps := {
		"current_stage": current_stage,
		"owner": owner,
		"registry": registry,
		"round_state": _get_instance(registry, "round_flow_state"),
		"mythic_item_runtime": _get_instance(registry, "mythic_item_runtime"),
	}
	if current_stage == 4:
		deps["stage4_map_state"] = _get_instance(registry, "stage4_map_state")
		deps["stage4_temple_destruction_event"] = _get_instance(registry, "stage4_temple_destruction_event")
		deps["audio"] = _get_instance(registry, "game_audio")
	return deps


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _method_accepts_argument_count(target: Object, method_name: String, argument_count: int) -> bool:
	if target == null:
		return false
	for method_value in target.get_method_list():
		var method_info: Dictionary = method_value if method_value is Dictionary else {}
		if str(method_info.get("name", "")) != method_name:
			continue
		var args: Array = method_info.get("args", [])
		return args.size() >= argument_count
	return false


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


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
