extends Node2D

const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const BallRenderInterpolation := preload("res://scripts/ball/ball_render_interpolation.gd")

var scene_state: Object = BattleSceneState.new()
var gameplay_modules: Object = GameplayModuleRegistry.new()
var _battle_redraw_requested := false


func _ready() -> void:
	var startup_controller: Object = _get_battle_startup_controller()
	if startup_controller != null and startup_controller.has_method("ready"):
		startup_controller.ready(self, gameplay_modules, Callable(self, "_get_module"), _get_startup_callbacks())


func _exit_tree() -> void:
	var startup_controller: Object = _get_cached_module("battle_scene_startup_controller")
	if startup_controller == null:
		startup_controller = _get_battle_startup_controller()
	if startup_controller != null and startup_controller.has_method("exit_tree"):
		startup_controller.exit_tree(self, gameplay_modules, Callable(self, "_get_cached_module"), _get_startup_callbacks())
	elif gameplay_modules != null and gameplay_modules.has_method("clear_all"):
		gameplay_modules.clear_all()


func _initialize_battle(play_stage_bgm: bool = true) -> void:
	var flow: Object = _get_battle_flow_controller()
	if flow != null and flow.has_method("initialize_battle"):
		flow.initialize_battle(self, gameplay_modules, Callable(self, "_get_module"), play_stage_bgm)


func _begin_stage_landing_intro() -> void:
	var flow: Object = _get_battle_flow_controller()
	if flow != null and flow.has_method("begin_stage_landing_intro"):
		flow.begin_stage_landing_intro(self, gameplay_modules, Callable(self, "_get_module"), Callable(self, "_get_cached_module"))


func _begin_ball_spawn_intro() -> void:
	var flow: Object = _get_battle_flow_controller()
	if flow != null and flow.has_method("begin_ball_spawn_intro"):
		flow.begin_ball_spawn_intro(self, gameplay_modules, Callable(self, "_get_module"))


func _run_boot_warmup_step() -> void:
	var warmup: Object = _get_boot_warmup_controller()
	if warmup == null:
		return
	if warmup.has_method("run_boot_warmup_steps_budgeted"):
		warmup.run_boot_warmup_steps_budgeted(
			self,
			Callable(self, "_get_module"),
			Callable(self, "_initialize_battle"),
			Callable(self, "queue_redraw")
		)
		return
	if warmup.has_method("run_boot_warmup_step"):
		warmup.run_boot_warmup_step(
			self,
			Callable(self, "_get_module"),
			Callable(self, "_initialize_battle"),
			Callable(self, "queue_redraw")
		)


func _run_logo_intro_warmup_step() -> void:
	var warmup: Object = _get_boot_warmup_controller()
	if warmup != null and warmup.has_method("run_logo_intro_warmup_step"):
		warmup.run_logo_intro_warmup_step(Callable(self, "_get_module"))


func _is_boot_warmup_finished() -> bool:
	return _call_readiness_bool("is_boot_warmup_finished", true)


func _get_boot_warmup_controller() -> Object:
	return _get_module("battle_boot_warmup_controller")


func _get_module(key: String) -> Object:
	if gameplay_modules == null or not gameplay_modules.has_method("get_instance"):
		return null
	var module: Variant = gameplay_modules.get_instance(key)
	if typeof(module) == TYPE_OBJECT and is_instance_valid(module):
		return module as Object
	return null


func _get_cached_module(key: String) -> Object:
	if gameplay_modules == null or not gameplay_modules.has_method("get_cached_instance"):
		return null
	var module: Variant = gameplay_modules.get_cached_instance(key)
	if typeof(module) == TYPE_OBJECT and is_instance_valid(module):
		return module as Object
	return null


func request_threaded_script(key: String) -> bool:
	if gameplay_modules == null or not gameplay_modules.has_method("request_threaded_script"):
		return true
	return bool(gameplay_modules.request_threaded_script(key))


func is_threaded_script_ready(key: String) -> bool:
	if gameplay_modules == null or not gameplay_modules.has_method("is_threaded_script_ready"):
		return true
	return bool(gameplay_modules.is_threaded_script_ready(key))


func _get(property: StringName) -> Variant:
	var key: String = str(property)
	if scene_state.has_key(key):
		return scene_state.get_value(key)
	return null


func _set(property: StringName, value: Variant) -> bool:
	var key: String = str(property)
	if not scene_state.has_key(key):
		return false
	scene_state.set_value(key, value)
	return true


func configure_ball_physics_context(
	stage: int,
	league_mode: String = "champion",
	arena_enabled: bool = false,
	active_weather_type: String = ""
) -> void:
	var api: Object = _get_battle_scene_api()
	if api != null:
		api.configure_ball_physics_context(self, gameplay_modules, stage, league_mode, arena_enabled, active_weather_type)


func configure_ball_visual_state(
	visual_type: String = "energy",
	boost_active: bool = false,
	poisoned: bool = false,
	viper_knockback: bool = false,
	bomb_loaded: bool = false
) -> void:
	var api: Object = _get_battle_scene_api()
	if api != null:
		api.configure_ball_visual_state(self, gameplay_modules, visual_type, boost_active, poisoned, viper_knockback, bomb_loaded)


func reset_ball_interpolation() -> void:
	BallRenderInterpolation.reset_ball_interpolation_on_owner(self)


func configure_player_character(character_type: String = "smasher") -> void:
	var api: Object = _get_battle_scene_api()
	if api != null:
		api.configure_player_character(self, gameplay_modules, character_type)


func activate_drive_ball(
	direction: int,
	spin_strength: float,
	speed_multiplier: float = 1.015,
	speed_bypass_bonus: float = 0.0
) -> void:
	var api: Object = _get_battle_scene_api()
	if api != null:
		api.activate_drive_ball(self, gameplay_modules, direction, spin_strength, speed_multiplier, speed_bypass_bonus)


func collect_star_point(amount: int = 1) -> void:
	var api: Object = _get_battle_scene_api()
	if api != null and api.has_method("collect_star_point"):
		api.collect_star_point(self, gameplay_modules, amount)


func debug_equip_megingjord() -> bool:
	var api: Object = _get_battle_scene_api()
	if api == null or not api.has_method("debug_equip_megingjord"):
		return false
	return bool(api.debug_equip_megingjord(self, gameplay_modules))


func _unhandled_input(event: InputEvent) -> void:
	var input_controller: Object = _get_battle_input_controller()
	if input_controller == null or not input_controller.has_method("handle_unhandled_input"):
		return
	input_controller.handle_unhandled_input(
		event,
		self,
		gameplay_modules,
		Callable(self, "_get_module"),
		{
			"battle_initialized": _is_battle_initialized(),
			"stage_landing_intro_started": _is_stage_landing_intro_started(),
			"mobile_touch_scene_ready": _is_mobile_touch_scene_ready(),
			"begin_ball_spawn_intro": Callable(self, "_begin_ball_spawn_intro"),
			"collect_star_point": Callable(self, "collect_star_point"),
			"reset_game_after_stage_clear": Callable(self, "_reset_game_after_stage_clear"),
			"exit_to_menu_after_stage_clear": Callable(self, "_exit_to_main_menu_after_stage_clear"),
		}
	)


func _process(delta: float) -> void:
	var perf_logger: Object = _get_perf_logger()
	_record_perf_value(perf_logger, "process.shell.delta", int(delta * 1000000.0))
	var shell_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var frame_controller: Object = _get_battle_frame_controller()
	_perf_end(perf_logger, "process.shell.lookup_frame_controller", sample_start)
	if frame_controller == null or not frame_controller.has_method("process_idle"):
		_flush_battle_redraw_request()
		_perf_end(perf_logger, "process.shell.total", shell_start)
		return
	sample_start = _perf_begin(perf_logger)
	var frame_callbacks: Dictionary = _get_frame_callbacks()
	_perf_end(perf_logger, "process.shell.build_callbacks", sample_start)
	sample_start = _perf_begin(perf_logger)
	frame_controller.process_idle(delta, self, gameplay_modules, Callable(self, "_get_module"), frame_callbacks)
	_perf_end(perf_logger, "process.shell.frame_controller", sample_start)
	_flush_battle_redraw_request()
	_perf_end(perf_logger, "process.shell.total", shell_start)


# Physics-tick code must not call queue_redraw() directly: Godot flushes the
# MessageQueue after every physics tick, so each tick's queued redraw runs the
# full immediate-mode _draw again. During physics catch-up that multiplies the
# draw cost per rendered frame (the frame-drop spiral; see the BattlePerf
# draw==proc+phys identity). Tick-side code requests here instead, and
# _process flushes at most one queue_redraw per rendered frame.
func request_battle_redraw() -> void:
	_battle_redraw_requested = true


func _flush_battle_redraw_request() -> bool:
	if not _battle_redraw_requested:
		return false
	_battle_redraw_requested = false
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	var perf_logger: Object = _get_perf_logger()
	_record_perf_value(perf_logger, "physics.shell.delta", int(delta * 1000000.0))
	var shell_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var frame_controller: Object = _get_battle_frame_controller()
	_perf_end(perf_logger, "physics.shell.lookup_frame_controller", sample_start)
	if frame_controller == null or not frame_controller.has_method("process_physics"):
		_perf_end(perf_logger, "physics.shell.total", shell_start)
		return
	sample_start = _perf_begin(perf_logger)
	var frame_callbacks: Dictionary = _get_frame_callbacks()
	_perf_end(perf_logger, "physics.shell.build_callbacks", sample_start)
	sample_start = _perf_begin(perf_logger)
	frame_controller.process_physics(delta, self, gameplay_modules, Callable(self, "_get_module"), frame_callbacks)
	_perf_end(perf_logger, "physics.shell.frame_controller", sample_start)
	_perf_end(perf_logger, "physics.shell.total", shell_start)


func _draw() -> void:
	var perf_logger: Object = _get_perf_logger()
	var shell_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var frame_controller: Object = _get_battle_frame_controller()
	_perf_end(perf_logger, "draw.shell.lookup_frame_controller", sample_start)
	if frame_controller == null or not frame_controller.has_method("draw"):
		_perf_end(perf_logger, "draw.shell.total", shell_start)
		return
	sample_start = _perf_begin(perf_logger)
	var frame_callbacks: Dictionary = _get_frame_callbacks()
	_perf_end(perf_logger, "draw.shell.build_callbacks", sample_start)
	sample_start = _perf_begin(perf_logger)
	frame_controller.draw(self, self, gameplay_modules, Callable(self, "_get_module"), frame_callbacks)
	_perf_end(perf_logger, "draw.shell.frame_controller", sample_start)
	_perf_end(perf_logger, "draw.shell.total", shell_start)
	_perf_maybe_log(perf_logger)


func _draw_battle_scene() -> void:
	var drawer: Object = _get_module("battle_scene_drawer")
	if drawer != null:
		drawer.draw(self, gameplay_modules)


func _draw_battle_playfield_scene() -> void:
	var drawer: Object = _get_module("battle_scene_drawer")
	if drawer != null and drawer.has_method("draw_playfield_underlay"):
		drawer.draw_playfield_underlay(self, gameplay_modules)


func _draw_battle_pillar_overlay() -> void:
	var drawer: Object = _get_module("battle_scene_drawer")
	if drawer != null and drawer.has_method("draw_pillar_overlay"):
		drawer.draw_pillar_overlay(self, gameplay_modules)


func _sync_mobile_touch_controls_enabled() -> void:
	var mobile_touch: Object = _get_mobile_touch_controller()
	if mobile_touch != null and mobile_touch.has_method("sync_controls_enabled"):
		mobile_touch.sync_controls_enabled(self, Callable(self, "_get_module"), _is_mobile_touch_scene_ready())


func _draw_mobile_touch_controls() -> void:
	var mobile_touch: Object = _get_mobile_touch_controller()
	if mobile_touch != null and mobile_touch.has_method("draw"):
		mobile_touch.draw(self, self, Callable(self, "_get_module"), _is_mobile_touch_scene_ready())


func _get_startup_callbacks() -> Dictionary:
	return {
		"initialize_battle": Callable(self, "_initialize_battle"),
		"begin_stage_landing_intro": Callable(self, "_begin_stage_landing_intro"),
		"clear_module_cache": Callable(self, "_clear_module_cache"),
	}


func _get_frame_callbacks() -> Dictionary:
	return {
		"sync_mobile_touch_controls_enabled": Callable(self, "_sync_mobile_touch_controls_enabled"),
		"run_boot_warmup_step": Callable(self, "_run_boot_warmup_step"),
		"run_logo_intro_warmup_step": Callable(self, "_run_logo_intro_warmup_step"),
		"initialize_battle": Callable(self, "_initialize_battle"),
		"begin_stage_landing_intro": Callable(self, "_begin_stage_landing_intro"),
		"begin_ball_spawn_intro": Callable(self, "_begin_ball_spawn_intro"),
		"is_battle_initialized": Callable(self, "_is_battle_initialized"),
		"is_stage_landing_intro_started": Callable(self, "_is_stage_landing_intro_started"),
		"draw_battle_scene": Callable(self, "_draw_battle_scene"),
		"draw_battle_playfield_scene": Callable(self, "_draw_battle_playfield_scene"),
		"draw_battle_pillar_overlay": Callable(self, "_draw_battle_pillar_overlay"),
		"draw_mobile_touch_controls": Callable(self, "_draw_mobile_touch_controls"),
	}


func _reset_game_after_stage_clear() -> void:
	var match_event_driver: Object = _get_module("battle_scene_match_event_driver")
	if match_event_driver != null and match_event_driver.has_method("reset_after_stage_clear_result"):
		match_event_driver.reset_after_stage_clear_result(self, gameplay_modules)


func _exit_to_main_menu_after_stage_clear() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var error: int = tree.change_scene_to_file("res://scenes/character_select.tscn")
	if error != OK:
		push_warning("Failed to change scene to character_select.tscn (error %d)" % error)


func _clear_module_cache() -> void:
	if gameplay_modules != null and gameplay_modules.has_method("clear_instances"):
		gameplay_modules.clear_instances()


func _is_mobile_touch_scene_ready() -> bool:
	var readiness: Object = _get_battle_readiness_controller()
	if readiness == null or not readiness.has_method("is_mobile_touch_scene_ready"):
		return false
	return bool(readiness.is_mobile_touch_scene_ready(
		Callable(self, "_get_module"),
		_is_battle_initialized(),
		_is_stage_landing_intro_started()
	))


func _get_mobile_touch_controller() -> Object:
	return _get_module("battle_mobile_touch_controller")


func _get_battle_input_controller() -> Object:
	return _get_module("battle_scene_input_controller")


func _get_battle_frame_controller() -> Object:
	return _get_module("battle_scene_frame_controller")


func _get_battle_scene_api() -> Object:
	return _get_module("battle_scene_api")


func _get_battle_flow_controller() -> Object:
	return _get_module("battle_scene_flow_controller")


func _get_battle_readiness_controller() -> Object:
	return _get_module("battle_scene_readiness_controller")


func _get_battle_startup_controller() -> Object:
	return _get_module("battle_scene_startup_controller")


func _get_perf_logger() -> Object:
	var logger: Object = _get_cached_module("battle_perf_logger")
	if logger == null:
		logger = _get_module("battle_perf_logger")
	if logger != null and logger.has_method("set_scene_owner"):
		logger.set_scene_owner(self)
	return logger


func _is_battle_initialized() -> bool:
	var flow: Object = _get_battle_flow_controller()
	if flow == null or not flow.has_method("is_battle_initialized"):
		return false
	return bool(flow.is_battle_initialized())


func _is_stage_landing_intro_started() -> bool:
	var flow: Object = _get_battle_flow_controller()
	if flow == null or not flow.has_method("is_stage_landing_intro_started"):
		return false
	return bool(flow.is_stage_landing_intro_started())


func _call_readiness_bool(method_name: String, fallback: bool = false) -> bool:
	var readiness: Object = _get_battle_readiness_controller()
	if readiness == null or not readiness.has_method(method_name):
		return fallback
	return bool(readiness.call(method_name, Callable(self, "_get_module")))


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _record_perf_value(perf_logger: Object, label: String, elapsed_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("record_value_sample"):
		perf_logger.record_value_sample(label, elapsed_usec)


func _perf_maybe_log(perf_logger: Object) -> void:
	if perf_logger != null and perf_logger.has_method("maybe_log"):
		perf_logger.maybe_log()
