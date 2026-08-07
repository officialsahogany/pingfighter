extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneMatchResetResultApplier := preload("res://scripts/core/battle_scene_match_reset_result_applier.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
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
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var sample_start: int = _perf_begin(perf_logger)
	var deps: Dictionary = _get_match_flow_deps(registry)
	_perf_end(perf_logger, "physics.round_restart.match_flow.build_deps", sample_start)
	sample_start = _perf_begin(perf_logger)
	controller.handle_round_restart(reason, deps, {
		"reset_ball": reset_ball_callback,
	})
	_perf_end(perf_logger, "physics.round_restart.match_flow.controller", sample_start)


func update_scoreboard(
	registry: Object,
	delta: float,
	reset_game_callback: Callable,
	reset_ball_callback: Callable,
	owner: Object = null,
	reset_drive_input_callback: Callable = Callable()
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
			reset_ball_callback,
			reset_drive_input_callback
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
			"resolve_match_defeat": Callable(self, "_resolve_match_defeat").bind(
				registry,
				owner,
				reset_drive_input_callback,
				reset_ball_callback
			),
			"try_start_victory_presentation": Callable(self, "_try_start_victory_presentation").bind(registry, owner, reset_game_callback),
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
	reset_ball_callback: Callable,
	reset_drive_input_callback: Callable = Callable()
) -> void:
	_apply_scoreboard_update_result(
		update_result,
		registry,
		owner,
		reset_game_callback,
		reset_ball_callback,
		reset_drive_input_callback
	)


func _apply_scoreboard_update_result(
	update_result: int,
	registry: Object,
	owner: Object,
	reset_game_callback: Callable,
	reset_ball_callback: Callable,
	reset_drive_input_callback: Callable = Callable()
) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	if update_result == ScoreboardState.UPDATE_RESET_GAME:
		# 파워로스 진동 럼블(퀘이크 루프)의 종료 엣지 — 진동 창은 최종 스코어보드
		# 와 함께 끝난다(승/패 무관 no-op 안전).
		_stop_victory_power_loss_rumble(registry)
		var defeat_start: int = _perf_begin(perf_logger)
		if _resolve_match_defeat(registry, owner, reset_drive_input_callback, reset_ball_callback):
			_perf_end(perf_logger, "physics.scoreboard_result.resolve_defeat", defeat_start)
			_perf_end(perf_logger, "physics.scoreboard_result.total", total_start)
			return
		_perf_end(perf_logger, "physics.scoreboard_result.resolve_defeat", defeat_start)
		var victory_presentation_start: int = _perf_begin(perf_logger)
		if _try_start_victory_presentation(registry, owner, reset_game_callback):
			_perf_end(perf_logger, "physics.scoreboard_result.victory_presentation", victory_presentation_start)
			_perf_end(perf_logger, "physics.scoreboard_result.total", total_start)
			return
		_perf_end(perf_logger, "physics.scoreboard_result.victory_presentation", victory_presentation_start)
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


func _resolve_match_defeat(
	registry: Object,
	owner: Object,
	reset_drive_input_callback: Callable,
	reset_ball_callback: Callable
) -> bool:
	if owner == null or not _is_scoreboard_player_defeat(registry):
		return false
	var chance_gems_count: int = _get_chance_gems_count(owner, registry)
	if chance_gems_count <= 0:
		return _show_defeat_settlement(registry, owner)
	if _show_defeat_continue_screen(registry, owner, reset_drive_input_callback, reset_ball_callback):
		return true
	_consume_chance_gem(owner, registry, chance_gems_count)
	reset_for_continue(owner, registry, reset_drive_input_callback, reset_ball_callback)
	return true


func _show_defeat_continue_screen(
	registry: Object,
	owner: Object,
	reset_drive_input_callback: Callable,
	reset_ball_callback: Callable
) -> bool:
	var continue_screen: Object = _get_instance(registry, "defeat_chance_gems_continue_screen")
	if continue_screen == null:
		continue_screen = _get_instance(registry, "defeat_chance_gems_soft_defeat_screen")
	if continue_screen == null:
		return false
	if continue_screen.has_method("prewarm_assets"):
		continue_screen.prewarm_assets()
	var continue_callback := Callable(self, "reset_for_continue").bind(
		owner,
		registry,
		reset_drive_input_callback,
		reset_ball_callback
	)
	var consume_callback := Callable(self, "_consume_chance_gem_for_continue").bind(owner, registry)
	if continue_screen.has_method("show_with_consume"):
		var show_with_consume_result: Variant = continue_screen.show_with_consume(owner, registry, continue_callback, consume_callback)
		return true if show_with_consume_result == null else bool(show_with_consume_result)
	if continue_screen.has_method("show"):
		_consume_chance_gem_for_continue(owner, registry)
		var show_result: Variant = continue_screen.show(owner, registry, continue_callback)
		return true if show_result == null else bool(show_result)
	return false


func _show_defeat_settlement(registry: Object, owner: Object) -> bool:
	var settlement_screen: Object = _get_instance(registry, "defeat_settlement_screen")
	if settlement_screen == null:
		settlement_screen = _get_instance(registry, "defeat_chance_gems_settlement_screen")
	if settlement_screen == null:
		return false
	var exit_callback := Callable(self, "_exit_to_main_menu").bind(owner)
	if settlement_screen.has_method("show"):
		var show_result: Variant = settlement_screen.show(owner, registry, exit_callback)
		return true if show_result == null else bool(show_result)
	if settlement_screen.has_method("show_from_scoreboard"):
		return bool(settlement_screen.show_from_scoreboard(owner, registry, exit_callback))
	return false


func _is_scoreboard_player_defeat(registry: Object) -> bool:
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state == null:
		return false
	var player_points: int = _call_scoreboard_int(scoreboard_state, "get_player_points", 0)
	var boss_points: int = _call_scoreboard_int(scoreboard_state, "get_boss_points", 0)
	var win_goal: int = max(1, _call_scoreboard_int(scoreboard_state, "get_win_goal", 5))
	if boss_points < win_goal:
		return false
	if scoreboard_state.has_method("get_last_scoring_side"):
		return str(scoreboard_state.get_last_scoring_side()) == "boss"
	return boss_points >= player_points


func _get_chance_gems_count(owner: Object, registry: Object = null) -> int:
	var store: Object = _get_chance_gem_store(registry)
	if store != null and store.has_method("get_chance_gems"):
		var count: int = maxi(0, int(store.get_chance_gems()))
		_sync_owner_chance_gems(owner, count, _get_chance_gems_max(store))
		return count
	return max(0, int(_get_owner_value(owner, "chance_gems_count", 0)))


func _consume_chance_gem(owner: Object, registry: Object, current_count: int) -> int:
	var store: Object = _get_chance_gem_store(registry)
	if store != null and store.has_method("consume_chance_gem"):
		var remaining: int = maxi(0, int(store.consume_chance_gem()))
		_sync_owner_chance_gems(owner, remaining, _get_chance_gems_max(store))
		return remaining
	var fallback_remaining: int = maxi(0, current_count - 1)
	_sync_owner_chance_gems(owner, fallback_remaining)
	return fallback_remaining


func _consume_chance_gem_for_continue(owner: Object, registry: Object) -> int:
	var current_count := _get_chance_gems_count(owner, registry)
	if current_count <= 0:
		return 0
	return _consume_chance_gem(owner, registry, current_count)


func _get_chance_gem_store(registry: Object) -> Object:
	var store: Object = _get_instance(registry, "plaza_save_store")
	if store != null:
		return store
	return null


func _get_chance_gems_max(store: Object = null) -> int:
	if store != null and store.has_method("get_max_chance_gems"):
		return maxi(1, int(store.get_max_chance_gems()))
	return PlazaSaveStore.MAX_CHANCE_GEMS


func _sync_owner_chance_gems(owner: Object, count: int, max_count: int = PlazaSaveStore.MAX_CHANCE_GEMS) -> void:
	if owner == null:
		return
	owner.set("chance_gems_count", clampi(count, 0, max_count))
	owner.set("chance_gems_max", max_count)


func _call_scoreboard_int(scoreboard_state: Object, method_name: String, fallback: int) -> int:
	if scoreboard_state != null and scoreboard_state.has_method(method_name):
		return int(scoreboard_state.call(method_name))
	return fallback


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
	# Stage-clear (win) exit returns to character select to start the next run.
	var exit_callback := Callable(self, "_exit_to_character_select").bind(owner)
	return bool(result_screen.show_from_scoreboard(owner, registry, reset_game_callback, exit_callback))


func _stop_victory_power_loss_rumble(registry: Object) -> void:
	var game_audio: Object = _get_instance(registry, "game_audio")
	if game_audio != null and game_audio.has_method("stop_stage2_quake_loop"):
		game_audio.stop_stage2_quake_loop()


func _try_start_victory_presentation(
	registry: Object,
	owner: Object,
	reset_game_callback: Callable
) -> bool:
	var recorder: Object = _get_instance(registry, "victory_highlight_recorder")
	var playback: Object = _get_instance(registry, "victory_highlight_playback_state")
	if (
		recorder != null
		and recorder.has_method("get_selected_victory_clips")
		and playback != null
		and playback.has_method("start")
		and (not playback.has_method("is_active") or not bool(playback.is_active()))
	):
		var clips: Array[Dictionary] = recorder.get_selected_victory_clips()
		if not clips.is_empty():
			var finish_callback := Callable(self, "_finish_victory_highlight").bind(
				registry,
				reset_game_callback,
				owner
			)
			if bool(playback.start(owner, registry, clips, finish_callback)):
				return true
	if recorder != null and recorder.has_method("release_match_clips"):
		recorder.release_match_clips()
	return _try_start_victory_loot_phase(registry, owner, reset_game_callback)


func _finish_victory_highlight(
	registry: Object,
	reset_game_callback: Callable,
	owner: Object
) -> void:
	if _try_start_victory_loot_phase(registry, owner, reset_game_callback):
		return
	if _show_stage_clear_result(registry, reset_game_callback, owner):
		return
	_call_callback(reset_game_callback)


func _try_start_victory_loot_phase(registry: Object, owner: Object, reset_game_callback: Callable) -> bool:
	# 승리 시 결과화면 직행 대신 보스 드랍 전리품 페이즈를 먼저 연다. 시작에
	# 실패하면 false를 돌려 기존 결과화면 래더가 그대로 이어진다.
	var loot_state: Object = _get_instance(registry, "victory_loot_phase_state")
	if loot_state == null or not loot_state.has_method("start"):
		return false
	if loot_state.has_method("is_active") and bool(loot_state.is_active()):
		return false
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state == null or not scoreboard_state.has_method("get_player_points"):
		return false
	var player_points: int = int(scoreboard_state.get_player_points())
	var boss_points: int = int(scoreboard_state.get_boss_points()) if scoreboard_state.has_method("get_boss_points") else 0
	if player_points <= boss_points:
		return false
	var finish_callback := Callable(self, "_finish_victory_loot_phase").bind(registry, reset_game_callback, owner)
	return bool(loot_state.start(owner, registry, player_points, boss_points, finish_callback))


func _finish_victory_loot_phase(registry: Object, reset_game_callback: Callable, owner: Object) -> void:
	# 전리품 페이즈 종료 = 기존 스코어보드 승리 래더의 나머지 절반을 그대로 실행.
	if _show_stage_clear_result(registry, reset_game_callback, owner):
		return
	_call_callback(reset_game_callback)


func exit_to_main_menu(owner: Object) -> void:
	# Public entry for non-defeat run-ending exits (pause menu 나가기). Same
	# semantics as the settlement exit: rewind to Stage 1 + return to title.
	_exit_to_main_menu(owner)


func _exit_to_main_menu(owner: Object) -> void:
	# True defeat (chance gems exhausted) returns to the main menu / title.
	_reset_run_selection_state(owner)
	_change_to_scene(owner, "res://scenes/main_menu.tscn")


func _exit_to_character_select(owner: Object) -> void:
	_reset_run_selection_state(owner)
	_change_to_scene(owner, "res://scenes/character_select.tscn")


func _reset_run_selection_state(owner: Object) -> void:
	# Roguelike run grammar: every run-ending exit starts the NEXT run from
	# Stage 1. Mid-run stage advances persist the reached stage into
	# GameSelectionState (battle_scene_match_event_driver._sync_selection_stage),
	# so without this rewind the next character-select entry re-enters the
	# stage the player was defeated on. Resolve through tree.root (relative
	# lookup, same as ExhibitionResetHandler) -- absolute get_node paths error
	# outside the active scene tree.
	if not (owner is Node):
		return
	var tree: SceneTree = (owner as Node).get_tree()
	if tree == null or tree.root == null:
		return
	var selection_state: Node = tree.root.get_node_or_null("GameSelectionState")
	if selection_state != null and selection_state.has_method("set_stage"):
		selection_state.set_stage(1)


func _change_to_scene(owner: Object, scene_path: String) -> void:
	if not (owner is Node):
		return
	var tree: SceneTree = (owner as Node).get_tree()
	if tree == null:
		return
	var error: int = tree.change_scene_to_file(scene_path)
	if error != OK:
		push_warning("Failed to change scene to %s (error %d)" % [scene_path, error])


func reset_game(
	owner: Object,
	registry: Object,
	reset_drive_input_callback: Callable,
	reset_ball_callback: Callable
) -> void:
	var controller: Object = _get_instance(registry, "match_flow_controller")
	if controller == null or owner == null:
		return
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var sample_start: int = _perf_begin(perf_logger)
	var deps: Dictionary = _get_match_flow_deps(
		registry,
		int(_get_owner_value(owner, "current_stage", 1)),
		owner,
		"physics.match_reset.deps"
	)
	_perf_end(perf_logger, "physics.match_reset.build_deps", sample_start)
	sample_start = _perf_begin(perf_logger)
	var result: Dictionary = controller.reset_game(deps, {
		"reset_drive_input": reset_drive_input_callback,
		"reset_ball": reset_ball_callback,
	})
	_perf_end(perf_logger, "physics.match_reset.controller_total", sample_start)
	sample_start = _perf_begin(perf_logger)
	_get_reset_result_applier(registry).apply_reset_result(owner, result)
	_perf_end(perf_logger, "physics.match_reset.apply_result", sample_start)


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


func reset_for_continue(
	owner: Object,
	registry: Object,
	reset_drive_input_callback: Callable,
	reset_ball_callback: Callable
) -> void:
	var controller: Object = _get_instance(registry, "match_flow_controller")
	if controller == null or owner == null:
		return
	if not controller.has_method("reset_for_stage_transition"):
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
