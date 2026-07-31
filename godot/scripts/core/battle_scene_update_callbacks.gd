extends RefCounted

const BattleSceneBossHealthFlow := preload("res://scripts/core/battle_scene_boss_health_flow.gd")

var _fallback_boss_health_flow: Object = BattleSceneBossHealthFlow.new()
var _cached_owner: Object = null
var _cached_registry: Object = null
var _cached_frame_callbacks: Dictionary = {}
var _cached_score_event_callback: Callable = Callable()
var _cached_round_restart_callback: Callable = Callable()


func build_frame_callbacks(owner: Object, registry: Object) -> Dictionary:
	if owner == _cached_owner and registry == _cached_registry and not _cached_frame_callbacks.is_empty():
		return _cached_frame_callbacks
	_cached_owner = owner
	_cached_registry = registry
	_rebuild_ball_event_callbacks(owner, registry)
	_cached_frame_callbacks = {
		"update_scoreboard": Callable(self, "_update_scoreboard").bind(owner, registry),
		"handle_scoreboard_update_result": Callable(self, "_handle_scoreboard_update_result").bind(owner, registry),
		"update_weather": Callable(self, "_update_weather").bind(owner, registry),
		"update_effects": Callable(self, "_update_effects").bind(owner, registry),
		"update_ball": Callable(self, "_update_ball").bind(owner, registry),
		"update_runtime_perk_resume": Callable(self, "_update_runtime_perk_resume").bind(owner, registry),
		"update_player_control": Callable(self, "_update_player_control").bind(owner, registry),
		"update_mythic_items": Callable(self, "_update_mythic_items").bind(owner, registry),
		"update_active_items": Callable(self, "_update_active_items").bind(owner, registry),
		"update_boss_ai": Callable(self, "_update_boss_ai").bind(owner, registry),
		"observe_viper_wall_leap_ball_availability": Callable(self, "_observe_viper_wall_leap_ball_availability").bind(owner, registry),
		"update_lingpet": Callable(self, "_update_lingpet").bind(owner, registry),
		"serve_ball": Callable(self, "_serve_ball").bind(owner, registry),
		"queue_redraw": _build_queue_redraw_callable(owner),
		"queue_skill_orb_tooltip_overlay_redraw": Callable(self, "_queue_skill_orb_tooltip_overlay_redraw").bind(owner, registry),
		"hide_skill_orb_tooltip_overlay": Callable(self, "_hide_skill_orb_tooltip_overlay").bind(registry),
		"pause_skill_cooldowns": Callable(self, "_pause_skill_cooldowns").bind(owner, registry),
		"resume_skill_cooldowns": Callable(self, "_resume_skill_cooldowns").bind(owner, registry),
	}
	return _cached_frame_callbacks


func reset_ball(owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var ball_driver: Object = _get_instance(registry, "battle_scene_ball_update_driver")
	if ball_driver != null:
		var sample_start: int = _perf_begin(perf_logger)
		ball_driver.reset_ball(owner, registry)
		_perf_end(perf_logger, "process.reset_ball.callback.ball_driver", sample_start)
	var health_start: int = _perf_begin(perf_logger)
	_reset_boss_round_health(owner, registry)
	_perf_end(perf_logger, "process.reset_ball.callback.boss_health", health_start)


func _update_player_control(delta: float, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var actor_driver: Object = _get_instance(registry, "battle_scene_actor_update_driver")
	if actor_driver != null:
		actor_driver.update_player_control(owner, registry, delta)
	_perf_end(perf_logger, "physics.callback.player_control", sample_start)


func _update_weather(delta: float, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var weather_driver: Object = _get_instance(registry, "battle_scene_weather_update_driver")
	if weather_driver != null and weather_driver.has_method("update_weather"):
		weather_driver.update_weather(owner, registry, delta)
	_perf_end(perf_logger, "physics.callback.weather", sample_start)


func _update_mythic_items(delta: float, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var item_driver: Object = _get_instance(registry, "battle_scene_item_update_driver")
	if item_driver != null and item_driver.has_method("update_mythic_items"):
		item_driver.update_mythic_items(owner, registry, delta)
	_perf_end(perf_logger, "physics.callback.mythic_items", sample_start)


func _update_active_items(delta: float, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var item_driver: Object = _get_instance(registry, "battle_scene_item_update_driver")
	if item_driver != null and item_driver.has_method("update_items"):
		item_driver.update_items(owner, registry, delta)
	_perf_end(perf_logger, "physics.callback.active_items", sample_start)


func _update_runtime_perk_resume(delta: float, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var runtime_perk_driver: Object = _get_runtime_perk_update_driver(registry)
	if runtime_perk_driver != null and runtime_perk_driver.has_method("update_runtime_perk_resume"):
		runtime_perk_driver.update_runtime_perk_resume(owner, registry, delta)
	_perf_end(perf_logger, "physics.callback.runtime_perk_resume", sample_start)


func _pause_skill_cooldowns(owner: Object, registry: Object) -> void:
	var skill_tooltip_driver: Object = _get_skill_tooltip_driver(registry)
	if skill_tooltip_driver != null and skill_tooltip_driver.has_method("pause_skill_cooldowns"):
		skill_tooltip_driver.pause_skill_cooldowns(owner, registry)


func _resume_skill_cooldowns(owner: Object, registry: Object) -> void:
	var skill_tooltip_driver: Object = _get_skill_tooltip_driver(registry)
	if skill_tooltip_driver != null and skill_tooltip_driver.has_method("resume_skill_cooldowns"):
		skill_tooltip_driver.resume_skill_cooldowns(owner, registry)


func _queue_skill_orb_tooltip_overlay_redraw(owner: Object, registry: Object) -> void:
	var skill_tooltip_driver: Object = _get_skill_tooltip_driver(registry)
	if skill_tooltip_driver != null and skill_tooltip_driver.has_method("queue_tooltip_overlay_redraw"):
		skill_tooltip_driver.queue_tooltip_overlay_redraw(owner, registry)


func _hide_skill_orb_tooltip_overlay(registry: Object) -> void:
	var skill_tooltip_driver: Object = _get_skill_tooltip_driver(registry)
	if skill_tooltip_driver != null and skill_tooltip_driver.has_method("hide_tooltip_overlay"):
		skill_tooltip_driver.hide_tooltip_overlay(registry)


func _update_boss_ai(delta: float, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var actor_driver: Object = _get_instance(registry, "battle_scene_actor_update_driver")
	if actor_driver != null:
		actor_driver.update_boss_ai(owner, registry, delta)
	_perf_end(perf_logger, "physics.callback.boss_ai", sample_start)


func _observe_viper_wall_leap_ball_availability(owner: Object, registry: Object) -> void:
	var runtime: Object = _get_instance(registry, "viper_skill_runtime")
	if runtime != null and runtime.has_method("observe_wall_leap_ball_availability_from_owner"):
		runtime.observe_wall_leap_ball_availability_from_owner(owner, registry)


func _update_lingpet(delta: float, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if runtime != null and runtime.has_method("update"):
		# Split sub-labels: the 50~54ms one-shot on the first update after the
		# acquire-cutin modal closes needs update-vs-save attribution (the save
		# branch is a synchronous ConfigFile disk write).
		var update_start: int = _perf_begin(perf_logger)
		var should_save: bool = bool(runtime.update(delta, owner, registry))
		_perf_end(perf_logger, "physics.callback.lingpet.update", update_start)
		if should_save:
			var save_start: int = _perf_begin(perf_logger)
			_save_lingpet_runtime(owner, registry)
			_perf_end(perf_logger, "physics.callback.lingpet.save", save_start)
	_perf_end(perf_logger, "physics.callback.lingpet", sample_start)


func _serve_ball(owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var ball_driver: Object = _get_instance(registry, "battle_scene_ball_update_driver")
	if ball_driver != null:
		ball_driver.serve_ball(owner, registry)
	_perf_end(perf_logger, "physics.callback.serve_ball", sample_start)


func _save_lingpet_runtime(owner: Object, registry: Object) -> void:
	var save_store: Object = _get_instance(registry, "lingpet_save_store")
	if save_store != null and save_store.has_method("save_runtime"):
		save_store.save_runtime(owner, registry)


func _update_ball(delta: float, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var ball_driver: Object = _get_instance(registry, "battle_scene_ball_update_driver")
	if ball_driver != null:
		ball_driver.update_ball(
			owner,
			registry,
			delta,
			_get_score_event_callback(owner, registry),
			_get_round_restart_callback(owner, registry)
		)
	_perf_end(perf_logger, "physics.callback.ball", sample_start)


func _update_effects(delta: float, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var effects_driver: Object = _get_effects_driver(registry)
	if effects_driver != null and effects_driver.has_method("update_effects"):
		effects_driver.update_effects(owner, registry, delta)
	var defeat_sample_start: int = _perf_begin(perf_logger)
	_consume_boss_health_defeat(owner, registry)
	_perf_end(perf_logger, "physics.effects.consume_boss_health_defeat", defeat_sample_start)
	_perf_end(perf_logger, "physics.callback.effects", sample_start)


func _handle_score_event(scoring_side: String, owner: Object, registry: Object) -> void:
	var match_event_driver: Object = _get_match_event_driver(registry)
	if match_event_driver != null and match_event_driver.has_method("handle_score_event"):
		match_event_driver.handle_score_event(scoring_side, owner, registry)


func _handle_round_restart_event(reason: String, owner: Object, registry: Object) -> void:
	var match_event_driver: Object = _get_match_event_driver(registry)
	if match_event_driver != null and match_event_driver.has_method("handle_round_restart_event"):
		match_event_driver.handle_round_restart_event(reason, owner, registry)


func _update_scoreboard(delta: float, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	var match_event_driver: Object = _get_match_event_driver(registry)
	if match_event_driver != null and match_event_driver.has_method("update_scoreboard"):
		match_event_driver.update_scoreboard(delta, owner, registry)
	_perf_end(perf_logger, "physics.callback.scoreboard", sample_start)


func _handle_scoreboard_update_result(update_result: int, owner: Object, registry: Object) -> void:
	var match_event_driver: Object = _get_match_event_driver(registry)
	if match_event_driver != null and match_event_driver.has_method("handle_scoreboard_update_result"):
		match_event_driver.handle_scoreboard_update_result(update_result, owner, registry)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_skill_tooltip_driver(registry: Object) -> Object:
	return _get_instance(registry, "battle_scene_skill_tooltip_driver")


func _get_runtime_perk_update_driver(registry: Object) -> Object:
	return _get_instance(registry, "battle_scene_runtime_perk_update_driver")


func _get_effects_driver(registry: Object) -> Object:
	return _get_instance(registry, "battle_scene_effects_update_driver")


func _get_match_event_driver(registry: Object) -> Object:
	return _get_instance(registry, "battle_scene_match_event_driver")


func _get_score_event_callback(owner: Object, registry: Object) -> Callable:
	_ensure_ball_event_callbacks(owner, registry)
	return _cached_score_event_callback


func _get_round_restart_callback(owner: Object, registry: Object) -> Callable:
	_ensure_ball_event_callbacks(owner, registry)
	return _cached_round_restart_callback


func _ensure_ball_event_callbacks(owner: Object, registry: Object) -> void:
	if (
		owner == _cached_owner
		and registry == _cached_registry
		and not _cached_score_event_callback.is_null()
		and not _cached_round_restart_callback.is_null()
	):
		return
	_cached_owner = owner
	_cached_registry = registry
	_cached_frame_callbacks = {}
	_rebuild_ball_event_callbacks(owner, registry)


func _rebuild_ball_event_callbacks(owner: Object, registry: Object) -> void:
	_cached_score_event_callback = Callable(self, "_handle_score_event").bind(owner, registry)
	_cached_round_restart_callback = Callable(self, "_handle_round_restart_event").bind(owner, registry)


# This dict is dispatched from physics ticks; binding owner.queue_redraw
# directly makes every catch-up tick redraw the scene (see
# battle_scene_shell.request_battle_redraw). Owners without the request API
# (tests, legacy shells) keep the direct path.
func _build_queue_redraw_callable(owner: Object) -> Callable:
	if owner != null and owner.has_method("request_battle_redraw"):
		return Callable(owner, "request_battle_redraw")
	if owner != null and owner.has_method("queue_redraw"):
		return Callable(owner, "queue_redraw")
	return Callable()


func _get_boss_health_flow(registry: Object) -> Object:
	var flow: Object = _get_instance(registry, "battle_scene_boss_health_flow")
	if flow != null and flow.has_method("consume_defeat_score_event"):
		return flow
	return _fallback_boss_health_flow


func _consume_boss_health_defeat(owner: Object, registry: Object) -> void:
	var flow: Object = _get_boss_health_flow(registry)
	if flow != null and flow.has_method("consume_defeat_score_event"):
		flow.consume_defeat_score_event(owner, Callable(self, "_handle_score_event").bind(owner, registry))


func _reset_boss_round_health(owner: Object, registry: Object) -> void:
	var flow: Object = _get_boss_health_flow(registry)
	if flow != null and flow.has_method("reset_round_health"):
		flow.reset_round_health(owner)


func _get_perf_logger(registry: Object) -> Object:
	return _get_instance(registry, "battle_perf_logger")


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
