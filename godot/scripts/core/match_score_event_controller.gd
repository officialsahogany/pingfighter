extends RefCounted

const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")


func handle_score_event(scoring_side: String, deps: Dictionary, callbacks: Dictionary) -> void:
	var perf_logger: Object = _get_perf_logger(deps)
	var score_state: Object = deps.get("score_state", null)
	if score_state == null:
		return
	var odins_eye_death_finalize_score := bool(deps.get("odins_eye_death_finalize_score", false))
	var sample_start: int = _perf_begin(perf_logger)
	if not odins_eye_death_finalize_score and _try_start_odins_eye_death_sequence(scoring_side, score_state, deps):
		_perf_end(perf_logger, "physics.score_event.odins_eye_death", sample_start)
		return
	_perf_end(perf_logger, "physics.score_event.odins_eye_death", sample_start)
	sample_start = _perf_begin(perf_logger)
	if not odins_eye_death_finalize_score and _try_negate_boss_score(scoring_side, score_state, deps, callbacks):
		_perf_end(perf_logger, "physics.score_event.negate_boss_score", sample_start)
		return
	_perf_end(perf_logger, "physics.score_event.negate_boss_score", sample_start)
	sample_start = _perf_begin(perf_logger)
	if not odins_eye_death_finalize_score and _try_trigger_revival(scoring_side, score_state, deps, callbacks):
		_perf_end(perf_logger, "physics.score_event.revival", sample_start)
		return
	_perf_end(perf_logger, "physics.score_event.revival", sample_start)
	sample_start = _perf_begin(perf_logger)
	if not odins_eye_death_finalize_score and _try_trigger_odins_eye_revival(scoring_side, score_state, deps):
		_perf_end(perf_logger, "physics.score_event.odins_eye_revival", sample_start)
		return
	_perf_end(perf_logger, "physics.score_event.odins_eye_revival", sample_start)

	sample_start = _perf_begin(perf_logger)
	_clear_odins_eye_penalty_after_player_victory(scoring_side, deps)
	_perf_end(perf_logger, "physics.score_event.odins_eye_victory_clear", sample_start)

	sample_start = _perf_begin(perf_logger)
	var score_result: Dictionary = score_state.score_for(scoring_side)
	_perf_end(perf_logger, "physics.score_event.score_state.score_for", sample_start)
	sample_start = _perf_begin(perf_logger)
	_queue_pandora_legacy_selection(scoring_side, deps)
	_perf_end(perf_logger, "physics.score_event.mythic.pandora_queue", sample_start)
	sample_start = _perf_begin(perf_logger)
	_queue_adversity_armor_after_loss(scoring_side, score_result, deps)
	_perf_end(perf_logger, "physics.score_event.mythic.adversity_queue", sample_start)
	sample_start = _perf_begin(perf_logger)
	_apply_stage_score_reaction(scoring_side, deps)
	_perf_end(perf_logger, "physics.score_event.stage_reaction.background", sample_start)
	sample_start = _perf_begin(perf_logger)
	_apply_stage3_kuromi_score_reaction(scoring_side, score_result, deps)
	_perf_end(perf_logger, "physics.score_event.stage_reaction.stage3", sample_start)
	sample_start = _perf_begin(perf_logger)
	_apply_stage4_score_reaction(scoring_side, score_result, deps)
	_perf_end(perf_logger, "physics.score_event.stage_reaction.stage4", sample_start)
	sample_start = _perf_begin(perf_logger)
	_clear_stage2_round_boundary_fx(deps)
	_perf_end(perf_logger, "physics.score_event.round_boundary.stage2_fx", sample_start)
	sample_start = _perf_begin(perf_logger)
	_clear_stage4_round_boundary_fx(deps)
	_perf_end(perf_logger, "physics.score_event.round_boundary.stage4_fx", sample_start)
	sample_start = _perf_begin(perf_logger)
	_clear_stage5_round_boundary_fx(deps)
	_perf_end(perf_logger, "physics.score_event.round_boundary.stage5_fx", sample_start)
	sample_start = _perf_begin(perf_logger)
	_start_score_result_texture_prewarm(scoring_side, deps)
	_perf_end(perf_logger, "physics.score_event.result_texture_queue", sample_start)
	sample_start = _perf_begin(perf_logger)
	_sync_next_server(scoring_side, score_result, deps)
	_perf_end(perf_logger, "physics.score_event.round_state.next_server", sample_start)
	sample_start = _perf_begin(perf_logger)
	_start_scoreboard_or_reset_ball(scoring_side, score_result, deps, callbacks)
	_perf_end(perf_logger, "physics.score_event.scoreboard_start", sample_start)
	sample_start = _perf_begin(perf_logger)
	_start_scoreboard_wait(deps)
	_perf_end(perf_logger, "physics.score_event.round_state.scoreboard_wait", sample_start)
	sample_start = _perf_begin(perf_logger)
	_play_score_audio(deps)
	_perf_end(perf_logger, "physics.score_event.audio.total", sample_start)


func _start_score_result_texture_prewarm(scoring_side: String, deps: Dictionary) -> void:
	var resources: Object = _get_battle_resources(deps)
	if resources == null:
		return
	var result_context: Dictionary = _build_score_result_texture_context(scoring_side)
	if result_context.is_empty():
		return
	if resources.has_method("queue_result_texture_prewarm"):
		resources.queue_result_texture_prewarm(
			_get_selected_character_type(deps),
			_get_current_stage(deps),
			result_context
		)
		return
	if not resources.has_method("begin_result_texture_prewarm"):
		return
	resources.begin_result_texture_prewarm(
		_get_selected_character_type(deps),
		_get_current_stage(deps),
		result_context
	)


func _build_score_result_texture_context(scoring_side: String) -> Dictionary:
	if scoring_side == "player":
		return {
			"player_victory_active": true,
			"boss_defeat_active": true,
		}
	if scoring_side == "boss":
		return {
			"player_defeat_active": true,
			"boss_victory_active": true,
		}
	return {}


func _sync_next_server(scoring_side: String, score_result: Dictionary, deps: Dictionary) -> void:
	var round_state: Object = deps.get("round_state", null)
	if round_state != null and round_state.has_method("set_player_serves"):
		round_state.set_player_serves(bool(score_result.get("next_player_serves", scoring_side == "boss")))


func _start_scoreboard_or_reset_ball(
	scoring_side: String,
	score_result: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary
) -> void:
	var scoreboard_state: Object = deps.get("scoreboard_state", null)
	if scoreboard_state == null:
		_call_callback(callbacks, "reset_ball")
		return
	if scoreboard_state.has_method("trigger_top_mini_sparkle"):
		scoreboard_state.trigger_top_mini_sparkle()
	if scoreboard_state.has_method("start"):
		var player_score := int(score_result.get("player_score", 0))
		var boss_score := int(score_result.get("boss_score", 0))
		var match_finished := bool(score_result.get("match_finished", false))
		var win_goal := int(score_result.get("win_goal", 5))
		if _method_accepts_argument_count(scoreboard_state, "start", 5):
			scoreboard_state.start(player_score, boss_score, match_finished, scoring_side, win_goal)
		else:
			scoreboard_state.start(player_score, boss_score, match_finished, scoring_side)


func _start_scoreboard_wait(deps: Dictionary) -> void:
	var round_state: Object = deps.get("round_state", null)
	if round_state != null and round_state.has_method("start_scoreboard_wait"):
		round_state.start_scoreboard_wait()


func _play_score_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	var perf_logger: Object = _get_perf_logger(deps)
	_stop_score_audio_loops(audio, perf_logger, "physics.score_event.audio.cleanup")
	var sample_start: int = _perf_begin(perf_logger)
	if audio.has_method("play_round_set"):
		audio.play_round_set()
	_perf_end(perf_logger, "physics.score_event.audio.round_set", sample_start)


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


func _stop_score_audio_loops(
	audio: Object,
	perf_logger: Object = null,
	label: String = "physics.score_event.audio.cleanup"
) -> void:
	var sample_start: int = _perf_begin(perf_logger)
	GameplayLoopAudioCleanup.stop_all(audio)
	_perf_end(perf_logger, label, sample_start)


func _queue_pandora_legacy_selection(scoring_side: String, deps: Dictionary) -> void:
	if scoring_side != "player":
		return
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_queue_pandora_legacy_round_win"):
		return
	mythic_item_runtime.try_queue_pandora_legacy_round_win(deps)


func _queue_adversity_armor_after_loss(scoring_side: String, score_result: Dictionary, deps: Dictionary) -> void:
	if scoring_side != "boss":
		return
	if bool(score_result.get("match_finished", false)):
		return
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_queue_adversity_armor_after_loss"):
		return
	mythic_item_runtime.try_queue_adversity_armor_after_loss(deps)


func _try_negate_boss_score(scoring_side: String, score_state: Object, deps: Dictionary, callbacks: Dictionary) -> bool:
	if scoring_side != "boss":
		return false
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_trigger_foul_whistle"):
		return false
	var loss_type: String = "deuce" if _is_deuce_mode(score_state) else "round"
	if not bool(mythic_item_runtime.try_trigger_foul_whistle(loss_type, deps)):
		return false
	var audio: Object = deps.get("audio", null)
	if audio != null:
		_stop_score_audio_loops(audio)
	_start_boss_score_cancel_round_hold(deps, callbacks)
	return true


func _try_trigger_revival(scoring_side: String, score_state: Object, deps: Dictionary, callbacks: Dictionary) -> bool:
	if scoring_side != "boss" or not _would_score_finish(score_state, scoring_side):
		return false
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_trigger_revival"):
		return false
	var loss_type: String = "deuce" if _is_deuce_mode(score_state) else "round"
	if not bool(mythic_item_runtime.try_trigger_revival(loss_type, deps)):
		return false
	var audio: Object = deps.get("audio", null)
	if audio != null:
		_stop_score_audio_loops(audio)
	_start_boss_score_cancel_stage_hold(deps, callbacks)
	return true


func _try_start_odins_eye_death_sequence(scoring_side: String, score_state: Object, deps: Dictionary) -> bool:
	if scoring_side != "boss":
		return false
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null:
		return false
	if not (
		mythic_item_runtime.has_method("is_odins_eye_penalty_active")
		and mythic_item_runtime.has_method("begin_odins_eye_death_sequence")
	):
		return false
	if not bool(mythic_item_runtime.is_odins_eye_penalty_active()):
		return false
	var loss_type: String = "deuce" if _is_deuce_mode(score_state) else "round"
	if not bool(mythic_item_runtime.begin_odins_eye_death_sequence(loss_type)):
		return false
	var audio: Object = deps.get("audio", null)
	if audio != null:
		_stop_score_audio_loops(audio)
	_hide_ball_for_odins_eye_event(deps)
	_sync_mythic_owner(mythic_item_runtime, deps)
	return true


func _try_trigger_odins_eye_revival(scoring_side: String, score_state: Object, deps: Dictionary) -> bool:
	if scoring_side != "boss":
		return false
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_trigger_odins_eye_revival"):
		return false
	var loss_type: String = "deuce" if _is_deuce_mode(score_state) else "round"
	if not bool(mythic_item_runtime.try_trigger_odins_eye_revival(loss_type)):
		return false
	var audio: Object = deps.get("audio", null)
	if audio != null:
		_stop_score_audio_loops(audio)
	_hide_ball_for_odins_eye_event(deps)
	_sync_mythic_owner(mythic_item_runtime, deps)
	return true


func _clear_odins_eye_penalty_after_player_victory(scoring_side: String, deps: Dictionary) -> void:
	# §8 boundary policy (docs/odins_eye_port_plan.md): a player rally win during
	# the Odin penalty form clears the penalty AND re-arms revival
	# (clear_after_victory -> revival_used = false). Gated on penalty_active so a
	# normal player score never touches Odin state. Without this, the penalty
	# leaks past the rally win and the next boss score routes into the death
	# sequence even though the player had scored in between.
	if scoring_side != "player":
		return
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null:
		return
	if not (
		mythic_item_runtime.has_method("is_odins_eye_penalty_active")
		and mythic_item_runtime.has_method("clear_odins_eye_after_victory")
	):
		return
	if not bool(mythic_item_runtime.is_odins_eye_penalty_active()):
		return
	mythic_item_runtime.clear_odins_eye_after_victory()
	_sync_mythic_owner(mythic_item_runtime, deps)


func _hide_ball_for_odins_eye_event(deps: Dictionary) -> void:
	var owner_value: Variant = deps.get("owner", null)
	if not (typeof(owner_value) == TYPE_OBJECT and is_instance_valid(owner_value)):
		return
	var owner: Object = owner_value as Object
	var hidden_pos := Vector2(-100.0, -100.0)
	owner.set("ball_pos", hidden_pos)
	owner.set("ball_pos_prev", hidden_pos)
	owner.set("ball_vel", Vector2.ZERO)
	owner.set("ball_active", false)
	if owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _sync_mythic_owner(mythic_item_runtime: Object, deps: Dictionary) -> void:
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("_sync_owner"):
		return
	var owner: Object = deps.get("owner", null)
	if owner == null:
		return
	mythic_item_runtime._sync_owner(owner, deps.get("registry", null))


func _would_score_finish(score_state: Object, scoring_side: String) -> bool:
	if score_state != null and score_state.has_method("would_score_finish"):
		return bool(score_state.would_score_finish(scoring_side))
	var snapshot: Dictionary = score_state.get_snapshot() if score_state != null and score_state.has_method("get_snapshot") else {}
	var player_score := int(snapshot.get("player_score", 0))
	var boss_score := int(snapshot.get("boss_score", 0))
	var win_goal := int(snapshot.get("win_goal", 5))
	var deuce_goal := int(snapshot.get("deuce_goal", 6))
	if scoring_side == "player":
		player_score += 1
	elif scoring_side == "boss":
		boss_score += 1
	if bool(snapshot.get("deuce_mode", false)):
		if player_score == 5 and boss_score == 5:
			deuce_goal = 7
		return player_score >= deuce_goal or boss_score >= deuce_goal
	return player_score >= win_goal or boss_score >= win_goal


func _is_deuce_mode(score_state: Object) -> bool:
	if score_state != null and score_state.has_method("get_snapshot"):
		var snapshot: Dictionary = score_state.get_snapshot()
		return bool(snapshot.get("deuce_mode", false))
	var value: Variant = score_state.get("deuce_mode") if score_state != null else false
	return bool(value) if value != null else false


func _start_boss_score_cancel_round_hold(deps: Dictionary, callbacks: Dictionary) -> void:
	var round_state: Object = deps.get("round_state", null)
	if round_state == null:
		_call_callback(callbacks, "reset_ball")
		return
	if round_state.has_method("set_player_serves"):
		round_state.set_player_serves(true)
	if round_state.has_method("reset_round_wait"):
		round_state.reset_round_wait()
	if round_state.has_method("start_round_restart_notice"):
		round_state.start_round_restart_notice()


func _start_boss_score_cancel_stage_hold(deps: Dictionary, callbacks: Dictionary) -> void:
	# Pygame canonical 윤회의 부적: revert the lethal point, then call
	# main(restart_stage) which resets player_score / boss_score / round_wins /
	# round_losses to 0 and clears stage-level skill / weather state, while
	# leaving inventory, equipment, perks, and dash tokens intact.
	var score_state: Object = deps.get("score_state", null)
	if score_state != null and score_state.has_method("reset"):
		score_state.reset()
	var scoreboard_state: Object = deps.get("scoreboard_state", null)
	if scoreboard_state != null and scoreboard_state.has_method("reset"):
		scoreboard_state.reset()
	var match_reset_controller: Object = deps.get("match_reset_controller", null)
	if match_reset_controller != null and match_reset_controller.has_method("reset_stage_state"):
		match_reset_controller.reset_stage_state(deps)
	var round_state: Object = deps.get("round_state", null)
	if round_state != null:
		if round_state.has_method("set_player_serves"):
			round_state.set_player_serves(true)
		if round_state.has_method("reset_round_wait"):
			round_state.reset_round_wait()
		if round_state.has_method("start_round_restart_notice"):
			round_state.start_round_restart_notice()
	_call_callback(callbacks, "reset_ball")


func _apply_stage_score_reaction(scoring_side: String, deps: Dictionary) -> void:
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background == null or not stage_background.has_method("set_expression"):
		return
	if scoring_side == "player":
		stage_background.set_expression("sad")
	elif scoring_side == "boss":
		stage_background.set_expression("happy")


func _apply_stage3_kuromi_score_reaction(scoring_side: String, score_result: Dictionary, deps: Dictionary) -> void:
	if int(deps.get("current_stage", 1)) != 3:
		return
	var stage3_boss_skill_state: Object = deps.get("stage3_boss_skill_state", null)
	if stage3_boss_skill_state != null and stage3_boss_skill_state.has_method("handle_score_event"):
		stage3_boss_skill_state.handle_score_event(scoring_side, score_result, deps)


func _apply_stage4_score_reaction(scoring_side: String, score_result: Dictionary, deps: Dictionary) -> void:
	if int(deps.get("current_stage", 1)) != 4:
		return
	var stage4_map_state: Object = deps.get("stage4_map_state", null)
	if stage4_map_state != null and stage4_map_state.has_method("handle_score_event"):
		stage4_map_state.handle_score_event(scoring_side, score_result, deps)


func _clear_stage4_round_boundary_fx(deps: Dictionary) -> void:
	if int(deps.get("current_stage", 1)) != 4:
		return
	var stage4_ponk_skill_state: Object = deps.get("stage4_ponk_skill_state", null)
	if stage4_ponk_skill_state != null and stage4_ponk_skill_state.has_method("reset_round"):
		stage4_ponk_skill_state.reset_round(deps)


func _clear_stage2_round_boundary_fx(deps: Dictionary) -> void:
	if int(deps.get("current_stage", 1)) != 2:
		return
	var stage2_background: Object = deps.get("stage_background", null)
	if stage2_background == null:
		stage2_background = deps.get("stage2_pillar_background", null)
	if stage2_background != null and stage2_background.has_method("reset_round"):
		stage2_background.reset_round(deps)


func _clear_stage5_round_boundary_fx(deps: Dictionary) -> void:
	if int(deps.get("current_stage", 1)) != 5:
		return
	var stage5_hongryun_state: Object = deps.get("stage5_hongryun_state", null)
	if stage5_hongryun_state != null and stage5_hongryun_state.has_method("reset_round"):
		stage5_hongryun_state.reset_round()
	var stage5_hongryun_actor_renderer: Object = deps.get("stage5_hongryun_actor_renderer", null)
	if stage5_hongryun_actor_renderer == null:
		return
	if stage5_hongryun_actor_renderer.has_method("reset_round_fx"):
		stage5_hongryun_actor_renderer.reset_round_fx()
	elif stage5_hongryun_actor_renderer.has_method("reset"):
		stage5_hongryun_actor_renderer.reset()


func _get_battle_resources(deps: Dictionary) -> Object:
	var resources_value: Variant = deps.get("battle_resources", null)
	if typeof(resources_value) == TYPE_OBJECT and is_instance_valid(resources_value):
		return resources_value as Object
	var registry_value: Variant = deps.get("registry", null)
	if typeof(registry_value) == TYPE_OBJECT and is_instance_valid(registry_value):
		var registry: Object = registry_value as Object
		if registry.has_method("get_instance"):
			var registry_resources: Variant = registry.get_instance("battle_resources")
			if typeof(registry_resources) == TYPE_OBJECT and is_instance_valid(registry_resources):
				return registry_resources as Object
	return null


func _get_selected_character_type(deps: Dictionary) -> String:
	var explicit_value: String = str(deps.get("selected_character_type", "")).strip_edges().to_lower()
	if explicit_value != "":
		return explicit_value
	return str(_get_owner_value(deps, "selected_character_type", "smasher")).strip_edges().to_lower()


func _get_current_stage(deps: Dictionary) -> int:
	if deps.has("current_stage"):
		return int(deps.get("current_stage", 1))
	return int(_get_owner_value(deps, "current_stage", 1))


func _get_owner_value(deps: Dictionary, key: String, fallback: Variant) -> Variant:
	var owner_value: Variant = deps.get("owner", null)
	if not (typeof(owner_value) == TYPE_OBJECT and is_instance_valid(owner_value)):
		return fallback
	var owner: Object = owner_value as Object
	var value: Variant = owner.get(key)
	return value if value != null else fallback


func _call_callback(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()


func _get_perf_logger(deps: Dictionary) -> Object:
	var perf_logger: Variant = deps.get("perf_logger", null)
	if typeof(perf_logger) == TYPE_OBJECT and is_instance_valid(perf_logger):
		return perf_logger as Object
	return null


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
