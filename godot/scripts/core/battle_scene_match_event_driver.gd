extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneBossHealthFlow := preload("res://scripts/core/battle_scene_boss_health_flow.gd")
const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")

# Engine code-stage id where the demo sequence stops advancing automatically.
# Keep this as a code-stage boundary; public stage numbering can differ from
# the internal stage id mapping documented in AGENTS.md.
const DEMO_STAGE_SEQUENCE_END := 8
const STAGE_TRANSITION_LOADING_MIN_SECONDS := 2.20
const STAGE_TRANSITION_LOADING_START_PROGRESS := 0.0
const STAGE_TRANSITION_LOADING_PRE_COMPLETE_PROGRESS := 0.92
const STAGE_TRANSITION_LOADING_FINAL_REVEAL_SECONDS := 0.24
const STAGE_TRANSITION_WORK_STEP_DONE := 10

var _fallback_boss_health_flow: Object = BattleSceneBossHealthFlow.new()
var _stage_transition_loading_active := false
var _stage_transition_loading_next_stage := 0
var _stage_transition_loading_elapsed_sec := 0.0
var _stage_transition_loading_final_reveal_elapsed_sec := 0.0
var _stage_transition_loading_work_done := false
var _stage_transition_loading_drawn_once := false
var _stage_transition_loading_final_reveal_active := false
var _stage_transition_loading_work_step := 0
var _stage_transition_round_dep_prewarm_keys: Array[String] = []
var _stage_transition_round_dep_prewarm_index := 0


func handle_score_event(scoring_side: String, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var current_stage := int(_get_owner_value(owner, "current_stage", 1))
	var sample_start: int = _perf_begin(perf_logger)
	_restore_pending_active_item_throw(owner, registry)
	_perf_end(perf_logger, "physics.score_event.restore_pending_throw", sample_start)
	var match_flow_driver: Object = _get_match_flow_driver(registry)
	if match_flow_driver != null and match_flow_driver.has_method("handle_score_event"):
		sample_start = _perf_begin(perf_logger)
		var reset_ball_callback := Callable(self, "_reset_ball").bind(owner, registry)
		if _method_accepts_argument_count(match_flow_driver, "handle_score_event", 5):
			match_flow_driver.handle_score_event(registry, scoring_side, reset_ball_callback, current_stage, owner)
		else:
			match_flow_driver.handle_score_event(registry, scoring_side, reset_ball_callback, current_stage)
		_perf_end(perf_logger, "physics.score_event.match_flow_driver", sample_start)


func handle_round_restart_event(reason: String, owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var sample_start: int = _perf_begin(perf_logger)
	_restore_pending_active_item_throw(owner, registry)
	_perf_end(perf_logger, "physics.round_restart.restore_pending_throw", sample_start)
	var match_flow_driver: Object = _get_match_flow_driver(registry)
	if match_flow_driver != null and match_flow_driver.has_method("handle_round_restart"):
		sample_start = _perf_begin(perf_logger)
		match_flow_driver.handle_round_restart(registry, reason, Callable(self, "_reset_ball").bind(owner, registry))
		_perf_end(perf_logger, "physics.round_restart.match_flow_driver", sample_start)


func update_scoreboard(delta: float, owner: Object, registry: Object) -> void:
	var match_flow_driver: Object = _get_match_flow_driver(registry)
	if match_flow_driver != null and match_flow_driver.has_method("update_scoreboard"):
		var reset_game_callback := Callable(self, "_reset_game").bind(owner, registry)
		var reset_ball_callback := Callable(self, "_reset_ball").bind(owner, registry)
		var reset_drive_input_callback := Callable(self, "_reset_drive_input_frames").bind(registry)
		if _method_accepts_argument_count(match_flow_driver, "update_scoreboard", 6):
			match_flow_driver.update_scoreboard(
				registry,
				delta,
				reset_game_callback,
				reset_ball_callback,
				owner,
				reset_drive_input_callback
			)
		elif _method_accepts_argument_count(match_flow_driver, "update_scoreboard", 5):
			match_flow_driver.update_scoreboard(
				registry,
				delta,
				reset_game_callback,
				reset_ball_callback,
				owner
			)
		else:
			match_flow_driver.update_scoreboard(
				registry,
				delta,
				reset_game_callback,
				reset_ball_callback
			)


func handle_scoreboard_update_result(update_result: int, owner: Object, registry: Object) -> void:
	var match_flow_driver: Object = _get_match_flow_driver(registry)
	if match_flow_driver == null or not match_flow_driver.has_method("apply_scoreboard_update_result"):
		return
	var reset_game_callback := Callable(self, "_reset_game").bind(owner, registry)
	var reset_ball_callback := Callable(self, "_reset_ball").bind(owner, registry)
	var reset_drive_input_callback := Callable(self, "_reset_drive_input_frames").bind(registry)
	if _method_accepts_argument_count(match_flow_driver, "apply_scoreboard_update_result", 6):
		match_flow_driver.apply_scoreboard_update_result(
			update_result,
			registry,
			owner,
			reset_game_callback,
			reset_ball_callback,
			reset_drive_input_callback
		)
	elif _method_accepts_argument_count(match_flow_driver, "apply_scoreboard_update_result", 5):
		match_flow_driver.apply_scoreboard_update_result(
			update_result,
			registry,
			owner,
			reset_game_callback,
			reset_ball_callback
		)
	else:
		match_flow_driver.apply_scoreboard_update_result(
			update_result,
			registry,
			reset_game_callback,
			reset_ball_callback
		)


func reset_after_stage_clear_result(owner: Object, registry: Object) -> void:
	_reset_game(owner, registry)


func is_stage_transition_loading_active() -> bool:
	return _stage_transition_loading_active


func update_stage_transition_loading(delta: float, owner: Object, registry: Object) -> void:
	if not _stage_transition_loading_active:
		return
	if not _stage_transition_loading_drawn_once:
		_queue_redraw(owner)
		return
	var safe_delta: float = max(0.0, delta)
	if _stage_transition_loading_final_reveal_active:
		_stage_transition_loading_final_reveal_elapsed_sec += safe_delta
		if _stage_transition_loading_final_reveal_elapsed_sec >= STAGE_TRANSITION_LOADING_FINAL_REVEAL_SECONDS:
			var finish_perf_logger: Object = _get_instance(registry, "battle_perf_logger")
			var finish_start: int = _perf_begin(finish_perf_logger)
			_finish_stage_transition_loading(owner, registry)
			_perf_end(finish_perf_logger, "process.frame.stage_transition_loading.finish", finish_start)
			return
		_queue_redraw(owner)
		return

	_stage_transition_loading_elapsed_sec += safe_delta
	if not _stage_transition_loading_work_done:
		var work_perf_logger: Object = _get_instance(registry, "battle_perf_logger")
		var work_step: int = _stage_transition_loading_work_step
		var work_start: int = _perf_begin(work_perf_logger)
		_stage_transition_loading_work_done = _run_stage_transition_loading_work_step(
			owner,
			registry,
			_stage_transition_loading_next_stage
		)
		_perf_end(
			work_perf_logger,
			"process.frame.stage_transition_loading.step.%d" % work_step,
			work_start
		)
		_queue_redraw(owner)
		return
	if _stage_transition_loading_elapsed_sec >= STAGE_TRANSITION_LOADING_MIN_SECONDS:
		_stage_transition_loading_final_reveal_active = true
		_stage_transition_loading_final_reveal_elapsed_sec = 0.0
		_queue_redraw(owner)
		return
	_queue_redraw(owner)


func draw_stage_transition_loading(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	if not _stage_transition_loading_active:
		return false
	var renderer: Object = _get_instance(registry, "battle_loading_screen_renderer")
	if renderer != null and renderer.has_method("draw"):
		renderer.draw(
			canvas,
			owner,
			module_getter,
			view_size,
			_build_stage_transition_loading_context()
		)
	else:
		_draw_stage_transition_loading_fallback(canvas, view_size)
	_stage_transition_loading_drawn_once = true
	return true


func _reset_game(owner: Object, registry: Object) -> void:
	if _stage_transition_loading_active:
		return
	if _try_advance_demo_stage(owner, registry):
		return
	_reset_current_match(owner, registry)


func _reset_current_match(owner: Object, registry: Object) -> void:
	var match_flow_driver: Object = _get_match_flow_driver(registry)
	if match_flow_driver != null and match_flow_driver.has_method("reset_game"):
		match_flow_driver.reset_game(
			owner,
			registry,
			Callable(self, "_reset_drive_input_frames").bind(registry),
			Callable(self, "_reset_ball").bind(owner, registry)
		)


func _reset_match_for_stage_transition(owner: Object, registry: Object) -> void:
	_refill_guardian_for_stage_transition(registry)
	var match_flow_driver: Object = _get_match_flow_driver(registry)
	if match_flow_driver == null:
		return
	var reset_drive_input_callback := Callable(self, "_reset_drive_input_frames").bind(registry)
	var reset_ball_callback := Callable(self, "_reset_ball").bind(owner, registry)
	if match_flow_driver.has_method("reset_for_stage_transition"):
		match_flow_driver.reset_for_stage_transition(
			owner,
			registry,
			reset_drive_input_callback,
			reset_ball_callback
		)
	elif match_flow_driver.has_method("reset_game"):
		match_flow_driver.reset_game(
			owner,
			registry,
			reset_drive_input_callback,
			reset_ball_callback
		)


func _refill_guardian_for_stage_transition(registry: Object) -> void:
	var runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if runtime == null:
		return
	# Real stage advance only: ordinary round reset never calls this driver hook.
	if runtime.has_method("refill_guardian_duration_for_stage_transition"):
		runtime.refill_guardian_duration_for_stage_transition()


func _try_advance_demo_stage(owner: Object, registry: Object) -> bool:
	var next_stage := _get_demo_next_stage(owner, registry)
	if next_stage <= 0:
		return false
	_begin_stage_transition_loading(owner, registry, next_stage)
	return true


func _get_demo_next_stage(owner: Object, registry: Object) -> int:
	if owner == null:
		return 0
	var current_stage: int = int(_get_owner_value(owner, "current_stage", 1))
	if current_stage < 1 or current_stage >= DEMO_STAGE_SEQUENCE_END:
		return 0
	if _get_scoreboard_last_scoring_side(registry) != "player":
		return 0
	return current_stage + 1


func _begin_stage_transition_loading(owner: Object, registry: Object, next_stage: int) -> void:
	_stage_transition_loading_active = true
	_set_top_mini_scoreboard_visible(owner, registry, false)
	_stage_transition_loading_next_stage = next_stage
	_stage_transition_loading_elapsed_sec = 0.0
	_stage_transition_loading_final_reveal_elapsed_sec = 0.0
	_stage_transition_loading_work_done = false
	_stage_transition_loading_drawn_once = false
	_stage_transition_loading_final_reveal_active = false
	_stage_transition_loading_work_step = 0
	_stage_transition_round_dep_prewarm_keys.clear()
	_stage_transition_round_dep_prewarm_index = 0
	if owner != null:
		owner.set("current_stage", next_stage)
	_clear_owner_weather(owner)
	_clear_weather_runtime_state_for_stage_transition(registry)
	_sync_selection_stage(owner, next_stage)
	var resources: Object = _get_instance(registry, "battle_resources")
	if resources != null and resources.has_method("reset_transition_texture_prewarm"):
		resources.reset_transition_texture_prewarm()
	_request_stage_transition_round_dep_scripts(registry, next_stage)
	_prewarm_stage_transition_loading_assets(registry)
	_queue_redraw(owner)


func _apply_demo_stage_transition(owner: Object, registry: Object, next_stage: int) -> void:
	owner.set("current_stage", next_stage)
	_clear_owner_weather(owner)
	_clear_weather_runtime_state_for_stage_transition(registry)
	_sync_selection_stage(owner, next_stage)
	_configure_ball_physics(owner, registry, next_stage)
	_reset_match_for_stage_transition(owner, registry)
	_prepare_stage_start(owner, registry, next_stage)
	_reload_battle_textures(owner, registry, next_stage)
	_restart_stage_audio(registry, next_stage)
	_queue_redraw(owner)


func _run_stage_transition_loading_work_step(owner: Object, registry: Object, next_stage: int) -> bool:
	owner.set("current_stage", next_stage)
	_clear_owner_weather(owner)
	_clear_weather_runtime_state_for_stage_transition(registry)
	_sync_selection_stage(owner, next_stage)
	match _stage_transition_loading_work_step:
		0:
			_configure_ball_physics(owner, registry, next_stage)
		1:
			if not _prewarm_stage_transition_round_deps(registry, next_stage):
				return false
		2:
			_reset_match_for_stage_transition(owner, registry)
		3:
			_prepare_stage_start(owner, registry, next_stage)
		4:
			if not _reload_battle_textures(owner, registry, next_stage):
				return false
		5:
			if not _prewarm_stage_transition_runtime_resources(owner, registry):
				return false
		6:
			if not _prewarm_stage_clear_result_transition_resources(owner, registry):
				return false
		7:
			_stop_stage_gameplay_audio(registry)
		8:
			_stop_stage_bgm(registry)
		9:
			# 스테이지 7은 전환 직후 프리배틀 영상이 오디오를 대체하므로 여기서
			# BGM을 선재생하지 않는다(선재생→영상 시작 시 단절→영상음→재시작
			# 왕복 방지). 영상 종료(또는 로드 실패 degradation) 후 랜딩
			# lifecycle의 start_battle_bgm이 1회 시작한다 — BGM 래치는
			# _replay_ball_spawn_intro_for_stage_transition에서 해제된다.
			if next_stage != 7:
				_play_stage_bgm(registry, next_stage)
		_:
			return true
	_stage_transition_loading_work_step += 1
	return _stage_transition_loading_work_step >= STAGE_TRANSITION_WORK_STEP_DONE


func _finish_stage_transition_loading(owner: Object, registry: Object) -> void:
	var loading_renderer: Object = _get_instance(registry, "battle_loading_screen_renderer")
	if loading_renderer != null and loading_renderer.has_method("hide_loading"):
		loading_renderer.hide_loading()
	if loading_renderer != null and loading_renderer.has_method("release_stained_glass_hosts"):
		loading_renderer.release_stained_glass_hosts(owner)
	_stage_transition_loading_active = false
	_stage_transition_loading_next_stage = 0
	_stage_transition_loading_elapsed_sec = 0.0
	_stage_transition_loading_final_reveal_elapsed_sec = 0.0
	_stage_transition_loading_work_done = false
	_stage_transition_loading_drawn_once = false
	_stage_transition_loading_final_reveal_active = false
	_stage_transition_loading_work_step = 0
	_stage_transition_round_dep_prewarm_keys.clear()
	_stage_transition_round_dep_prewarm_index = 0
	_set_top_mini_scoreboard_visible(owner, registry, true)
	_replay_ball_spawn_intro_for_stage_transition(owner, registry)
	_queue_redraw(owner)


func _set_top_mini_scoreboard_visible(owner: Object, registry: Object, is_visible: bool) -> void:
	var scoreboard_renderer: Object = _get_instance(registry, "scoreboard_renderer")
	if scoreboard_renderer != null and scoreboard_renderer.has_method("set_top_mini_visible"):
		scoreboard_renderer.set_top_mini_visible(owner, is_visible)


func _replay_ball_spawn_intro_for_stage_transition(owner: Object, registry: Object) -> void:
	var flow: Object = _get_instance(registry, "battle_scene_flow_controller")
	if flow == null:
		return
	var stage_id: int = int(owner.get("current_stage")) if owner != null else 0
	if stage_id == 7:
		# 스테이지 6→7 전환은 볼 스폰만 재생하면 아카무 인트로 영상이 통째로
		# 건너뛰어진다 — 프리배틀 엔트리를 재무장하고 전체 인트로 체인을
		# 다시 시작한다. 전환 워크스텝 9는 스테이지 7에서 BGM을 틀지 않고
		# 유예하므로(선재생→단절 왕복 방지), 여기서 BGM 래치를 풀어 영상
		# 종료(또는 로드 실패 degradation) 후 랜딩 lifecycle이 정확히 1회
		# 시작하게 한다.
		var presentation: Object = _get_instance(registry, "stage7_akamu_prebattle_presentation")
		if presentation != null and presentation.has_method("reset_for_stage_entry"):
			presentation.reset_for_stage_entry(stage_id)
		flow.set("_stage_landing_intro_started", false)
		flow.set("_ball_spawn_intro_started", false)
		flow.set("_battle_bgm_started", false)
		if flow.has_method("begin_stage_landing_intro"):
			flow.begin_stage_landing_intro(
				owner,
				registry,
				Callable(registry, "get_instance"),
				Callable(registry, "get_cached_instance")
			)
			return
	flow.set("_ball_spawn_intro_started", false)
	if not flow.has_method("begin_ball_spawn_intro"):
		return
	flow.begin_ball_spawn_intro(owner, registry, Callable(registry, "get_instance"))


func _build_stage_transition_loading_context() -> Dictionary:
	return {
		"battle_initialized": true,
		"stage_landing_intro_started": false,
		"loading_progress": _get_stage_transition_loading_progress(),
		"loading_title": LanguageSettings.translate_text("스테이지 전환 중"),
		"loading_subtitle": LanguageSettings.format_stage_transition_subtitle(_stage_transition_loading_next_stage),
		"loading_status": LanguageSettings.format_stage_transition_status(_stage_transition_loading_next_stage),
	}


func _get_stage_transition_loading_progress() -> float:
	if not _stage_transition_loading_drawn_once:
		return STAGE_TRANSITION_LOADING_START_PROGRESS
	if _stage_transition_loading_final_reveal_active:
		return 1.0
	var duration: float = max(0.001, STAGE_TRANSITION_LOADING_MIN_SECONDS)
	var elapsed_ratio: float = clampf(_stage_transition_loading_elapsed_sec / duration, 0.0, 1.0)
	var eased := elapsed_ratio * elapsed_ratio * (3.0 - 2.0 * elapsed_ratio)
	return lerpf(STAGE_TRANSITION_LOADING_START_PROGRESS, STAGE_TRANSITION_LOADING_PRE_COMPLETE_PROGRESS, eased)


func _draw_stage_transition_loading_fallback(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas == null:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color.BLACK)


func _get_scoreboard_last_scoring_side(registry: Object) -> String:
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state != null and scoreboard_state.has_method("get_last_scoring_side"):
		return str(scoreboard_state.get_last_scoring_side())
	return ""


func _clear_owner_weather(owner: Object) -> void:
	if owner == null:
		return
	owner.set("weather_type", "")
	owner.set("weather_event_active", false)
	owner.set("weather_event_context", {})


func _clear_weather_runtime_state_for_stage_transition(registry: Object) -> void:
	var weather_state: Object = _get_instance(registry, "weather_event_state")
	if weather_state == null:
		return
	if weather_state.has_method("reset"):
		weather_state.reset()


func _sync_selection_stage(owner: Object, stage_id: int) -> void:
	if owner == null or not owner.has_method("get_node_or_null"):
		return
	var selection_state: Node = owner.get_node_or_null("/root/GameSelectionState")
	if selection_state != null and selection_state.has_method("set_stage"):
		selection_state.set_stage(stage_id)


func _configure_ball_physics(owner: Object, registry: Object, stage_id: int) -> void:
	var ball_physics: Object = _get_instance(registry, "ball_physics")
	if ball_physics == null or not ball_physics.has_method("configure_context"):
		return
	ball_physics.configure_context(
		stage_id,
		str(_get_owner_value(owner, "ai_mode", "champion")),
		bool(_get_owner_value(owner, "arena_mode_enabled", false)),
		str(_get_owner_value(owner, "weather_type", ""))
	)


func _prepare_stage_start(owner: Object, registry: Object, stage_id: int) -> void:
	var commando_weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if commando_weapon_controller != null and commando_weapon_controller.has_method("prepare_stage_start"):
		commando_weapon_controller.prepare_stage_start(stage_id, true)
	var result_screen: Object = _get_instance(registry, "stage_clear_result_screen")
	if result_screen != null and result_screen.has_method("prepare_stage_start"):
		result_screen.prepare_stage_start(owner, registry, stage_id)


func _reload_battle_textures(owner: Object, registry: Object, stage_id: int) -> bool:
	var resources: Object = _get_instance(registry, "battle_resources")
	if resources == null:
		return true
	var context := {
		"selected_character_type": str(_get_owner_value(owner, "selected_character_type", "smasher")),
		"current_stage": stage_id,
		"include_result_sheets": true,
		"include_all_characters": false,
		"include_all_stages": false,
	}
	var textures: Variant = {}
	if resources.has_method("prewarm_transition_textures_step"):
		if not bool(resources.prewarm_transition_textures_step(context)):
			return false
		if resources.has_method("get_resource_cache"):
			textures = resources.get_resource_cache()
		elif resources.has_method("load_all"):
			textures = resources.load_all(context)
	elif resources.has_method("load_all"):
		textures = resources.load_all(context)
	else:
		return true
	if textures is Dictionary:
		var texture_dict: Dictionary = textures
		owner.set("battle_textures", texture_dict)
		owner.set("smasher_skill_icon_textures", _get_dictionary(texture_dict.get("smasher_skill_icon_textures", {})))
		owner.set("viper_skill_icon_textures", _get_dictionary(texture_dict.get("viper_skill_icon_textures", {})))
		owner.set("commando_skill_icon_textures", _get_dictionary(texture_dict.get("commando_skill_icon_textures", {})))
	return true


func _prewarm_stage_transition_loading_assets(registry: Object) -> void:
	var loading_renderer: Object = _get_instance(registry, "battle_loading_screen_renderer")
	if loading_renderer != null and loading_renderer.has_method("prewarm_stage_assets"):
		loading_renderer.prewarm_stage_assets(_stage_transition_loading_next_stage)
	elif loading_renderer != null and loading_renderer.has_method("prewarm_assets"):
		loading_renderer.prewarm_assets()


func _prewarm_stage_transition_round_deps(registry: Object, next_stage: int) -> bool:
	if registry == null or not registry.has_method("get_instance"):
		return true
	if _stage_transition_round_dep_prewarm_keys.is_empty() and _stage_transition_round_dep_prewarm_index <= 0:
		_stage_transition_round_dep_prewarm_keys = BallDependencyContext.get_stage_round_dep_keys(next_stage)
	if _stage_transition_round_dep_prewarm_index >= _stage_transition_round_dep_prewarm_keys.size():
		return true

	var module_key: String = _stage_transition_round_dep_prewarm_keys[_stage_transition_round_dep_prewarm_index]
	if registry.has_method("request_threaded_script"):
		registry.request_threaded_script(module_key)
	if registry.has_method("is_threaded_script_ready") and not bool(registry.is_threaded_script_ready(module_key)):
		return false
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var sample_start := _perf_begin(perf_logger)
	registry.get_instance(module_key)
	_perf_end(
		perf_logger,
		"process.frame.stage_transition_loading.step.1.round_dep.%s" % module_key,
		sample_start
	)
	_stage_transition_round_dep_prewarm_index += 1
	return _stage_transition_round_dep_prewarm_index >= _stage_transition_round_dep_prewarm_keys.size()


func _request_stage_transition_round_dep_scripts(registry: Object, next_stage: int) -> void:
	if registry == null or not registry.has_method("request_threaded_script"):
		return
	for module_key in BallDependencyContext.get_stage_round_dep_keys(next_stage):
		registry.request_threaded_script(str(module_key))


func _prewarm_stage_transition_runtime_resources(owner: Object, registry: Object) -> bool:
	var prewarm_controller: Object = _get_instance(registry, "battle_boot_resource_prewarm_controller")
	if prewarm_controller == null:
		return true
	if registry == null or not registry.has_method("get_instance"):
		return true
	if prewarm_controller.has_method("prewarm_stage_runtime_resources_step"):
		return bool(prewarm_controller.prewarm_stage_runtime_resources_step(owner, Callable(registry, "get_instance")))
	if not prewarm_controller.has_method("prewarm_stage_runtime_resources"):
		return true
	prewarm_controller.prewarm_stage_runtime_resources(owner, Callable(registry, "get_instance"))
	return true


func _prewarm_stage_clear_result_transition_resources(owner: Object, registry: Object) -> bool:
	var prewarm_controller: Object = _get_instance(registry, "battle_boot_resource_prewarm_controller")
	if prewarm_controller == null:
		return true
	if registry == null or not registry.has_method("get_instance"):
		return true
	if prewarm_controller.has_method("prewarm_stage_clear_result_resources_step"):
		return bool(prewarm_controller.prewarm_stage_clear_result_resources_step(Callable(registry, "get_instance"), owner))
	if not prewarm_controller.has_method("prewarm_stage_clear_result_resources"):
		return true
	prewarm_controller.prewarm_stage_clear_result_resources(Callable(registry, "get_instance"), owner)
	return true


func _restart_stage_audio(registry: Object, stage_id: int) -> void:
	_stop_stage_gameplay_audio(registry)
	_stop_stage_bgm(registry)
	_play_stage_bgm(registry, stage_id)


func _stop_stage_gameplay_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	GameplayLoopAudioCleanup.stop_all(audio)


func _stop_stage_bgm(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("stop_bgm"):
		audio.stop_bgm()


func _play_stage_bgm(registry: Object, stage_id: int) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_stage_bgm"):
		audio.play_stage_bgm(stage_id)


# Score / scoreboard-result / match-reset events reach this helper from
# physics ticks; see battle_scene_shell.request_battle_redraw.
func _queue_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.request_battle_redraw()
		return
	if owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _reset_drive_input_frames(registry: Object) -> void:
	var ball_driver: Object = _get_instance(registry, "battle_scene_ball_update_driver")
	if ball_driver != null:
		ball_driver.reset_drive_input_frames(registry)


func _reset_ball(owner: Object, registry: Object) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var ball_driver: Object = _get_instance(registry, "battle_scene_ball_update_driver")
	if ball_driver != null:
		var ball_start: int = _perf_begin(perf_logger)
		ball_driver.reset_ball(owner, registry)
		_perf_end(perf_logger, "physics.reset_ball.ball_driver", ball_start)
	# 융합 점수손실 부산물(정전기장/절처봉생)은 볼 리셋(구 라운드
	# 상태 정리) 뒤에 정확히 1회 적용된다 — reset_ball 이전에 적용하면
	# status_effect_state.reset_round()가 새로 깐 슬로우를 지운다.
	var fusion_start: int = _perf_begin(perf_logger)
	_apply_pending_perk_fusion_round_start(registry)
	_perf_end(perf_logger, "physics.reset_ball.perk_fusion_round_start", fusion_start)
	var health_start: int = _perf_begin(perf_logger)
	_reset_boss_round_health(owner, registry)
	_perf_end(perf_logger, "physics.reset_ball.boss_health", health_start)
	var mythic_start: int = _perf_begin(perf_logger)
	_notify_mythic_round_start(owner, registry)
	_perf_end(perf_logger, "physics.reset_ball.mythic_round_start", mythic_start)
	var weather_driver: Object = _get_instance(registry, "battle_scene_weather_update_driver")
	if weather_driver != null and weather_driver.has_method("on_round_start"):
		var weather_start: int = _perf_begin(perf_logger)
		weather_driver.on_round_start(owner, registry)
		_perf_end(perf_logger, "physics.reset_ball.weather_round_start", weather_start)


# 융합 점수손실 부산물의 새 라운드 적용(정확히 1회 — pending은 소비형):
# 정전기장=보스 slow 채널(60fps 프레임 환산, 공용 WEAK 배수),
# 절처봉생=대시 토큰 전량 리필+HUD 오브 동기.
func _apply_pending_perk_fusion_round_start(registry: Object) -> void:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null or not runtime_perk_state.has_method("consume_pending_perk_fusion_point_loss_effects"):
		return
	var pending: Dictionary = runtime_perk_state.consume_pending_perk_fusion_point_loss_effects()
	if pending.is_empty():
		return
	var static_field: Dictionary = pending.get("static_field", {}) as Dictionary
	if not static_field.is_empty():
		var status_state: Object = _get_instance(registry, "status_effect_state")
		if status_state != null and status_state.has_method("apply_status"):
			status_state.apply_status(
				"boss",
				"slow",
				maxf(0.0, float(static_field.get("duration_sec", 0.0))) * 60.0,
				{
					"multiplier": float(static_field.get("boss_slow_multiplier", 1.0)),
					# The scoreboard has already closed, but the serve banner plus the
					# player's manual/auto serve delay can consume nearly all four
					# seconds while the ball is still parked. Preserve four seconds of
					# actual rally pressure instead of four seconds of menu waiting.
					"pause_while_ball_inactive": true,
				},
				"perk_fusion_static_field"
			)
			var game_audio: Object = _get_instance(registry, "game_audio")
			if game_audio != null and game_audio.has_method("play_mini_spark"):
				game_audio.play_mini_spark()
	if bool(pending.get("restore_dash_tokens", false)):
		var dash_state: Object = _get_instance(registry, "smasher_dash_state")
		if dash_state != null and dash_state.has_method("refill_tokens"):
			dash_state.refill_tokens()
			var orb_hud_state: Object = _get_instance(registry, "orb_hud_state")
			if orb_hud_state != null and orb_hud_state.has_method("reset_dash_tokens") and dash_state.has_method("get_snapshot"):
				orb_hud_state.reset_dash_tokens(int((dash_state.get_snapshot() as Dictionary).get("tokens", 0)))


func _notify_mythic_round_start(owner: Object, registry: Object) -> void:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("on_round_start"):
		mythic_item_runtime.on_round_start(owner, registry)


func _restore_pending_active_item_throw(owner: Object, registry: Object) -> void:
	var item_driver: Object = _get_instance(registry, "battle_scene_item_update_driver")
	if item_driver != null and item_driver.has_method("restore_pending_throw_item_on_round_end"):
		item_driver.restore_pending_throw_item_on_round_end(owner, registry)


func _get_match_flow_driver(registry: Object) -> Object:
	return _get_instance(registry, "battle_scene_match_flow_driver")


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


func _reset_boss_round_health(owner: Object, registry: Object) -> void:
	var flow: Object = _get_instance(registry, "battle_scene_boss_health_flow")
	if flow == null or not flow.has_method("reset_round_health"):
		flow = _fallback_boss_health_flow
	flow.reset_round_health(owner)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
