extends SceneTree

const BattleSceneMatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")
const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var selected_character_type := "viper"
	var ai_mode := "champion"
	var arena_mode_enabled := false
	var weather_type := ""
	var weather_event_active := false
	var weather_event_context := {}
	var battle_textures := {}
	var smasher_skill_icon_textures := {}
	var viper_skill_icon_textures := {}
	var commando_skill_icon_textures := {}
	var redraw_calls := 0

	func queue_redraw() -> void:
		redraw_calls += 1


class FakeScoreboardState:
	extends RefCounted

	var last_scoring_side := "player"

	func get_last_scoring_side() -> String:
		return last_scoring_side


class FakeMatchFlowDriver:
	extends RefCounted

	var reset_game_calls := 0
	var reset_for_stage_transition_calls := 0

	func reset_game(
		_owner: Object,
		_registry: Object,
		_reset_drive_input_frames_callback: Callable,
		_reset_ball_callback: Callable
	) -> void:
		reset_game_calls += 1

	func reset_for_stage_transition(
		_owner: Object,
		_registry: Object,
		_reset_drive_input_frames_callback: Callable,
		_reset_ball_callback: Callable
	) -> void:
		reset_for_stage_transition_calls += 1


class FakeBallPhysics:
	extends RefCounted

	var configure_calls := 0
	var last_stage := 0

	func configure_context(stage_id: int, _ai_mode: String, _arena_enabled: bool, _weather_type: String) -> void:
		configure_calls += 1
		last_stage = stage_id


class FakeCommandoWeaponController:
	extends RefCounted

	var prepare_calls := 0
	var last_stage := 0

	func prepare_stage_start(stage_id: int, _real_stage_transition: bool) -> void:
		prepare_calls += 1
		last_stage = stage_id


class FakeBattleResources:
	extends RefCounted

	var load_all_calls := 0
	var last_config: Dictionary = {}

	func load_all(config: Dictionary) -> Dictionary:
		load_all_calls += 1
		last_config = config.duplicate(true)
		return {
			"smasher_skill_icon_textures": {},
			"viper_skill_icon_textures": {},
			"commando_skill_icon_textures": {},
		}


class FakeGameAudio:
	extends RefCounted

	var gameplay_loop_stop_calls := 0
	var stop_bgm_calls := 0
	var play_stage_bgm_calls := 0
	var last_stage := 0

	func stop_dash_delay() -> void:
		gameplay_loop_stop_calls += 1

	func stop_bgm() -> void:
		stop_bgm_calls += 1

	func play_stage_bgm(stage_id: int) -> void:
		play_stage_bgm_calls += 1
		last_stage = stage_id


class FakeLoadingRenderer:
	extends RefCounted

	var draw_calls := 0
	var hide_loading_calls := 0
	var last_context: Dictionary = {}

	func draw(
		_canvas: CanvasItem,
		_owner: Object,
		_module_getter: Callable,
		_view_size: Vector2,
		context: Dictionary = {}
	) -> void:
		draw_calls += 1
		last_context = context.duplicate(true)

	func hide_loading() -> void:
		hide_loading_calls += 1


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakePrewarmController:
	extends RefCounted

	var step_calls := 0
	var monolithic_calls := 0
	var complete_after := 3
	var stage_clear_step_calls := 0
	var stage_clear_complete_after := 2
	var last_stage_clear_owner: Object = null

	func prewarm_stage_runtime_resources_step(_owner: Object, _module_getter: Callable) -> bool:
		step_calls += 1
		return step_calls >= complete_after

	func prewarm_stage_runtime_resources(_owner: Object, _module_getter: Callable) -> void:
		monolithic_calls += 1

	func prewarm_stage_clear_result_resources_step(_module_getter: Callable, owner: Object = null) -> bool:
		stage_clear_step_calls += 1
		last_stage_clear_owner = owner
		return stage_clear_step_calls >= stage_clear_complete_after


class FakeWeatherState:
	extends RefCounted

	var reset_calls := 0

	func reset() -> void:
		reset_calls += 1


class FakeLingpetRuntime:
	extends RefCounted

	var affinity_battle_reset_calls := 0

	func reset_affinity_for_new_battle() -> void:
		affinity_battle_reset_calls += 1


class FakeRegistry:
	extends RefCounted

	var requested_keys: Array[String] = []
	var instances: Dictionary = {}
	var scoreboard_state := FakeScoreboardState.new()
	var match_flow_driver := FakeMatchFlowDriver.new()
	var ball_physics := FakeBallPhysics.new()
	var commando_weapon_controller := FakeCommandoWeaponController.new()
	var battle_resources := FakeBattleResources.new()
	var game_audio := FakeGameAudio.new()
	var loading_renderer := FakeLoadingRenderer.new()
	var perf_logger := FakePerfLogger.new()
	var prewarm_controller := FakePrewarmController.new()
	var weather_state := FakeWeatherState.new()
	var lingpet_runtime := FakeLingpetRuntime.new()
	var threaded_script_requests: Array[String] = []
	var threaded_script_ready_delay_by_key: Dictionary = {}
	var threaded_script_ready_polls_by_key: Dictionary = {}

	func request_threaded_script(key: String) -> bool:
		if not threaded_script_requests.has(key):
			threaded_script_requests.append(key)
		return true

	func is_threaded_script_ready(key: String) -> bool:
		var delay := int(threaded_script_ready_delay_by_key.get(key, 0))
		var polls := int(threaded_script_ready_polls_by_key.get(key, 0))
		if polls < delay:
			threaded_script_ready_polls_by_key[key] = polls + 1
			return false
		return true

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		match key:
			"scoreboard_state":
				return scoreboard_state
			"battle_scene_match_flow_driver":
				return match_flow_driver
			"ball_physics":
				return ball_physics
			"commando_weapon_controller":
				return commando_weapon_controller
			"battle_resources":
				return battle_resources
			"game_audio":
				return game_audio
			"battle_loading_screen_renderer":
				return loading_renderer
			"battle_perf_logger":
				return perf_logger
			"battle_boot_resource_prewarm_controller":
				return prewarm_controller
			"weather_event_state":
				return weather_state
			"lingpet_egg_runtime":
				return lingpet_runtime
		if _is_stage_round_dep_key(key):
			if not instances.has(key):
				instances[key] = RefCounted.new()
			return instances[key]
		return null

	func get_cached_instance(key: String) -> Object:
		if instances.has(key):
			return instances[key]
		return null

	func _is_stage_round_dep_key(key: String) -> bool:
		return (
			key.begins_with("stage1_")
			or key.begins_with("stage2_")
			or key.begins_with("stage3_")
			or key.begins_with("stage4_")
			or key.begins_with("stage5_")
			or key.begins_with("stage6_")
		)


func _init() -> void:
	_verify_stage_clear_to_stage2_uses_loading_gate()
	_verify_stage2_round_dep_waits_for_threaded_script_before_instance()
	_verify_stage3_clear_to_stage4_warms_round_deps_before_reset()
	_verify_stage4_clear_to_stage5_uses_loading_gate()
	_verify_stage5_clear_to_stage6_uses_loading_gate()
	_verify_non_player_reset_keeps_immediate_match_reset()

	if _failures.is_empty():
		print("battle_scene_stage_transition_loading_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage_clear_to_stage2_uses_loading_gate() -> void:
	var driver: Object = BattleSceneMatchEventDriver.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	driver.reset_after_stage_clear_result(owner, registry)

	_expect(bool(driver.is_stage_transition_loading_active()), "player stage clear should enter stage-transition loading")
	_expect(owner.current_stage == 2, "stage-transition loading should switch the visible loading art to stage 2")
	_expect(owner.weather_type == "" and not owner.weather_event_active and owner.weather_event_context.is_empty(), "stage-transition loading should clear owner weather flags immediately")
	_expect(registry.weather_state.reset_calls == 1, "stage-transition loading should clear residual weather draw state immediately")
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "transition work should wait until loading was drawn once")
	_expect(registry.match_flow_driver.reset_game_calls == 0, "stage-clear advance should not invoke the full match reset path")
	_expect(registry.lingpet_runtime.affinity_battle_reset_calls == 0, "lingpet affinity battle budget should wait for the transition reset chunk")
	_expect(registry.battle_resources.load_all_calls == 0, "battle textures should not reload before the first loading draw")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "pre-draw update should only keep the loading screen alive")
	_expect(registry.match_flow_driver.reset_game_calls == 0, "pre-draw update should not call the full match reset")

	var canvas := Node2D.new()
	get_root().add_child(canvas)
	_expect(
		bool(driver.draw_stage_transition_loading(
			canvas,
			owner,
			registry,
			Callable(registry, "get_instance"),
			Vector2(1280.0, 720.0)
		)),
		"active stage-transition loading should consume the draw frame"
	)
	canvas.queue_free()

	_expect(registry.loading_renderer.draw_calls == 1, "stage-transition loading should draw through the shared loading renderer")
	_expect(str(registry.loading_renderer.last_context.get("loading_title", "")) == "스테이지 전환 중", "loading context should expose transition title")
	_expect(
		is_equal_approx(float(registry.loading_renderer.last_context.get("loading_progress", -1.0)), 0.0),
		"first visible transition-loading frame should start at 0 percent"
	)

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.ball_physics.configure_calls == 1 and registry.ball_physics.last_stage == 2, "transition work should start with the ball-physics stage chunk")
	_expect(registry.weather_state.reset_calls > 1, "transition work should keep residual weather state cleared during loading")
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "stage-transition reset should be split out of the first work chunk")
	_expect(registry.battle_resources.load_all_calls == 0, "battle textures should wait for their own transition work chunk")
	_expect(registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.0"), "transition work should expose the ball-physics chunk timing")

	var stage2_round_dep_keys: Array[String] = BallDependencyContext.get_stage_round_dep_keys(2)
	_expect(stage2_round_dep_keys.size() == 2, "stage 2 transition should expose its reset-time round deps")
	for key in stage2_round_dep_keys:
		_expect(registry.get_cached_instance(key) == null, "stage 2 round deps should not be warm before the split pre-reset chunk")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.get_cached_instance(stage2_round_dep_keys[0]) != null, "stage-transition round-dep chunk should warm one module on its first frame")
	_expect(registry.get_cached_instance(stage2_round_dep_keys[1]) == null, "stage-transition round-dep chunk should spread work across frames")
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "stage-transition reset should wait until stage round deps are warm")
	_expect(registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.1"), "transition work should expose the round-deps warmup chunk timing")
	_expect(
		registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.1.round_dep.%s" % stage2_round_dep_keys[0]),
		"transition round-dep warmup should expose the first module key timing"
	)
	driver.update_stage_transition_loading(0.05, owner, registry)
	for key in stage2_round_dep_keys:
		_expect(registry.get_cached_instance(key) != null, "stage-transition reset should only be reachable after all stage round deps are cached")
		_expect(
			registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.1.round_dep.%s" % key),
			"transition round-dep warmup should expose every stage 2 module key timing"
		)
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "stage-transition reset should not share a frame with the last round-dep instantiation")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 1, "stage-clear advance should run the perk/item-preserving stage-transition reset")
	_expect(registry.lingpet_runtime.affinity_battle_reset_calls == 1, "stage-clear advance should reset lingpet affinity battle budgets once before the next battle")
	_expect(registry.match_flow_driver.reset_game_calls == 0, "stage-clear advance must not wipe perks/items via the full match reset")
	_expect(registry.battle_resources.load_all_calls == 0, "stage-transition reset should run before the battle texture reload chunk")
	_expect(registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.2"), "transition work should expose stage-transition reset timing")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.commando_weapon_controller.prepare_calls == 1 and registry.commando_weapon_controller.last_stage == 2, "commando stage-start prep should run for stage 2")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.battle_resources.load_all_calls == 1, "transition work should reload battle textures once")
	_expect(int(registry.battle_resources.last_config.get("current_stage", 0)) == 2, "battle textures should reload for stage 2")
	_expect(bool(registry.battle_resources.last_config.get("include_result_sheets", false)), "stage-transition battle texture reload should include round-result sheets before the next first score")
	_expect(registry.prewarm_controller.step_calls == 0, "stage runtime prewarm should wait for its own loading-frame chunk")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.prewarm_controller.step_calls == 1, "stage runtime prewarm should run through the step API")
	_expect(registry.game_audio.play_stage_bgm_calls == 0, "stage audio restart should wait until staged prewarm completes")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.prewarm_controller.step_calls == 2, "incomplete staged prewarm should keep the transition work on the prewarm chunk")
	_expect(registry.game_audio.play_stage_bgm_calls == 0, "stage audio restart should still wait for staged prewarm")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.prewarm_controller.step_calls == 3, "staged prewarm should complete after the configured loading chunks")
	_expect(registry.prewarm_controller.stage_clear_step_calls == 0, "stage-clear result prewarm should wait until runtime prewarm completes")
	_expect(registry.game_audio.play_stage_bgm_calls == 0, "stage audio restart should wait until staged result prewarm completes")
	_expect(registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.5"), "transition work should expose staged runtime prewarm timing")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.prewarm_controller.stage_clear_step_calls == 1, "stage-clear result prewarm should run through the loading step API")
	_expect(registry.prewarm_controller.last_stage_clear_owner == owner, "stage-clear result prewarm should receive the transitioned battle owner")
	_expect(registry.game_audio.play_stage_bgm_calls == 0, "stage audio restart should wait for stage-clear result prewarm")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.prewarm_controller.stage_clear_step_calls == 2, "incomplete stage-clear result prewarm should hold the transition work chunk")
	_expect(registry.game_audio.play_stage_bgm_calls == 0, "stage audio restart should run after result prewarm is complete")
	_expect(registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.6"), "transition work should expose stage-clear result prewarm timing")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.game_audio.gameplay_loop_stop_calls == 1, "stage-transition work should stop gameplay audio loops separately")
	_expect(registry.game_audio.stop_bgm_calls == 0, "stage-transition BGM stop should wait for its own chunk")
	_expect(registry.game_audio.play_stage_bgm_calls == 0, "stage-transition BGM start should wait for its own chunk")
	_expect(registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.7"), "transition work should expose gameplay audio cleanup timing")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.game_audio.stop_bgm_calls == 1, "stage-transition work should stop the previous BGM separately")
	_expect(registry.game_audio.play_stage_bgm_calls == 0, "stage-transition BGM start should wait until old BGM is stopped")
	_expect(registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.8"), "transition work should expose BGM stop timing")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.game_audio.play_stage_bgm_calls == 1 and registry.game_audio.last_stage == 2, "stage-transition work should start stage 2 BGM")
	_expect(registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.9"), "transition work should expose stage BGM start timing")
	_expect(bool(driver.is_stage_transition_loading_active()), "stage-transition loading should stay visible for its minimum duration")

	var second_canvas := Node2D.new()
	get_root().add_child(second_canvas)
	driver.draw_stage_transition_loading(
		second_canvas,
		owner,
		registry,
		Callable(registry, "get_instance"),
		Vector2(1280.0, 720.0)
	)
	second_canvas.queue_free()
	_expect(
		float(registry.loading_renderer.last_context.get("loading_progress", 1.0)) < 0.30,
		"transition progress should not jump to late-stage values immediately after work completes"
	)

	driver.update_stage_transition_loading(2.25, owner, registry)
	_expect(bool(driver.is_stage_transition_loading_active()), "stage-transition loading should show a final 100 percent reveal before release")
	_expect(registry.loading_renderer.hide_loading_calls == 0, "final reveal should not hide the loading renderer immediately")

	var final_canvas := Node2D.new()
	get_root().add_child(final_canvas)
	driver.draw_stage_transition_loading(
		final_canvas,
		owner,
		registry,
		Callable(registry, "get_instance"),
		Vector2(1280.0, 720.0)
	)
	final_canvas.queue_free()
	_expect(
		is_equal_approx(float(registry.loading_renderer.last_context.get("loading_progress", 0.0)), 1.0),
		"final reveal frame should report 100 percent"
	)

	driver.update_stage_transition_loading(0.30, owner, registry)
	_expect(not bool(driver.is_stage_transition_loading_active()), "stage-transition loading should release after the final reveal")
	_expect(registry.loading_renderer.hide_loading_calls == 1, "finishing transition loading should hide the loading renderer")
	_expect(registry.perf_logger.labels.has("process.frame.stage_transition_loading.finish"), "transition finish should expose ball-spawn replay timing")


func _verify_stage2_round_dep_waits_for_threaded_script_before_instance() -> void:
	var driver: Object = BattleSceneMatchEventDriver.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var stage2_round_dep_keys: Array[String] = BallDependencyContext.get_stage_round_dep_keys(2)
	registry.threaded_script_ready_delay_by_key[stage2_round_dep_keys[0]] = 1

	driver.reset_after_stage_clear_result(owner, registry)
	_expect(
		registry.threaded_script_requests.has(stage2_round_dep_keys[0]),
		"stage-transition begin should request the first round-dep script on the threaded loader"
	)

	var canvas := Node2D.new()
	get_root().add_child(canvas)
	driver.draw_stage_transition_loading(
		canvas,
		owner,
		registry,
		Callable(registry, "get_instance"),
		Vector2(1280.0, 720.0)
	)
	canvas.queue_free()

	driver.update_stage_transition_loading(0.05, owner, registry)
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.get_cached_instance(stage2_round_dep_keys[0]) == null, "stage-transition should not instantiate a round dep before its threaded script is ready")
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "stage-transition reset should stay blocked while the first round-dep script is still loading")
	_expect(
		not registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.1.round_dep.%s" % stage2_round_dep_keys[0]),
		"round-dep instantiation label should only be emitted after the script is ready"
	)

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.get_cached_instance(stage2_round_dep_keys[0]) != null, "stage-transition should instantiate the round dep once its threaded script is ready")
	_expect(
		registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.1.round_dep.%s" % stage2_round_dep_keys[0]),
		"round-dep instantiation label should be emitted after threaded script readiness"
	)


func _verify_stage3_clear_to_stage4_warms_round_deps_before_reset() -> void:
	var driver: Object = BattleSceneMatchEventDriver.new()
	var owner := FakeOwner.new()
	owner.current_stage = 3
	var registry := FakeRegistry.new()

	driver.reset_after_stage_clear_result(owner, registry)
	_expect(bool(driver.is_stage_transition_loading_active()), "code stage 3 player clear should enter stage-transition loading for Stage 4")
	_expect(owner.current_stage == 4, "code stage 3 clear should advance the visible loading stage to code stage 4")

	var canvas := Node2D.new()
	get_root().add_child(canvas)
	driver.draw_stage_transition_loading(
		canvas,
		owner,
		registry,
		Callable(registry, "get_instance"),
		Vector2(1280.0, 720.0)
	)
	canvas.queue_free()

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.ball_physics.configure_calls == 1 and registry.ball_physics.last_stage == 4, "code stage 3 clear transition should configure ball physics for code stage 4")

	var stage4_round_dep_keys: Array[String] = BallDependencyContext.get_stage_round_dep_keys(4)
	_expect(stage4_round_dep_keys.has("stage4_bird_event"), "stage 4 round-dep key source should include the bird event")
	_expect(stage4_round_dep_keys.has("stage4_ponk_skill_state"), "stage 4 round-dep key source should include Ponk skill state")
	for key in stage4_round_dep_keys:
		_expect(registry.get_cached_instance(key) == null, "stage 4 round deps should not be warm before the pre-reset chunk")

	for index in range(stage4_round_dep_keys.size()):
		driver.update_stage_transition_loading(0.05, owner, registry)
		for warmed_index in range(index + 1):
			var warmed_key: String = stage4_round_dep_keys[warmed_index]
			_expect(registry.get_cached_instance(warmed_key) != null, "stage 4 transition should warm round deps one module per frame before reset")
		_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "stage 4 transition reset should wait until every round dep key is cached")

	for key in stage4_round_dep_keys:
		_expect(registry.get_cached_instance(key) != null, "stage 4 reset step should be reachable only after every round dep key is cached")
		_expect(
			registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.1.round_dep.%s" % key),
			"stage 4 transition should expose per-module round-dep timing"
		)
	_expect(registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.1"), "stage 4 transition should expose the split round-deps warmup timing")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 1, "stage 4 transition should reset only after stage round deps are warm")
	_expect(registry.lingpet_runtime.affinity_battle_reset_calls == 1, "stage 4 transition should reset lingpet affinity budgets after round-dep warmup")


func _verify_stage4_clear_to_stage5_uses_loading_gate() -> void:
	var driver: Object = BattleSceneMatchEventDriver.new()
	var owner := FakeOwner.new()
	owner.current_stage = 4
	var registry := FakeRegistry.new()

	driver.reset_after_stage_clear_result(owner, registry)

	_expect(bool(driver.is_stage_transition_loading_active()), "code stage 4 player clear should enter stage-transition loading")
	_expect(owner.current_stage == 5, "code stage 4 clear should advance the visible loading stage to code stage 5")
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "code stage 4 to code stage 5 transition work should wait until loading was drawn once")
	_expect(registry.match_flow_driver.reset_game_calls == 0, "code stage 4 to code stage 5 clear should not use the full match reset path")

	var canvas := Node2D.new()
	get_root().add_child(canvas)
	driver.draw_stage_transition_loading(
		canvas,
		owner,
		registry,
		Callable(registry, "get_instance"),
		Vector2(1280.0, 720.0)
	)
	canvas.queue_free()

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.ball_physics.configure_calls == 1 and registry.ball_physics.last_stage == 5, "code stage 4 clear transition should configure ball physics for code stage 5")
	var stage5_round_dep_keys: Array[String] = BallDependencyContext.get_stage_round_dep_keys(5)
	for key in stage5_round_dep_keys:
		_expect(registry.get_cached_instance(key) == null, "stage 5 round deps should not be warm before the split pre-reset chunk")
	for _index in range(stage5_round_dep_keys.size()):
		driver.update_stage_transition_loading(0.05, owner, registry)
	for key in stage5_round_dep_keys:
		_expect(registry.get_cached_instance(key) != null, "stage 5 transition should warm all stage round deps before reset")
		_expect(
			registry.perf_logger.labels.has("process.frame.stage_transition_loading.step.1.round_dep.%s" % key),
			"stage 5 transition should expose per-module round-dep timing"
		)
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "stage 5 transition reset should wait for all stage round deps")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 1, "stage 5 transition should reset only after stage round deps are warm")


func _verify_stage5_clear_to_stage6_uses_loading_gate() -> void:
	var driver: Object = BattleSceneMatchEventDriver.new()
	var owner := FakeOwner.new()
	owner.current_stage = 5
	var registry := FakeRegistry.new()

	driver.reset_after_stage_clear_result(owner, registry)

	_expect(bool(driver.is_stage_transition_loading_active()), "code stage 5 player clear should enter stage-transition loading for Stage 6")
	_expect(owner.current_stage == 6, "code stage 5 clear should advance the visible loading stage to code stage 6")
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "code stage 5 to code stage 6 transition work should wait until loading was drawn once")
	_expect(registry.match_flow_driver.reset_game_calls == 0, "code stage 5 to code stage 6 clear should not use the full match reset path")

	var canvas := Node2D.new()
	get_root().add_child(canvas)
	driver.draw_stage_transition_loading(
		canvas,
		owner,
		registry,
		Callable(registry, "get_instance"),
		Vector2(1280.0, 720.0)
	)
	canvas.queue_free()

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.ball_physics.configure_calls == 1 and registry.ball_physics.last_stage == 6, "code stage 5 clear transition should configure ball physics for code stage 6")
	var stage6_round_dep_keys: Array[String] = BallDependencyContext.get_stage_round_dep_keys(6)
	for key in stage6_round_dep_keys:
		_expect(registry.get_cached_instance(key) == null, "stage 6 round deps should not be warm before the split pre-reset chunk")
	for _index in range(stage6_round_dep_keys.size()):
		driver.update_stage_transition_loading(0.05, owner, registry)
	for key in stage6_round_dep_keys:
		_expect(registry.get_cached_instance(key) != null, "stage 6 transition should warm all stage round deps before reset")
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "stage 6 transition reset should wait for all stage round deps")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 1, "stage 6 transition should reset only after stage round deps are warm")


func _verify_non_player_reset_keeps_immediate_match_reset() -> void:
	var driver: Object = BattleSceneMatchEventDriver.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.scoreboard_state.last_scoring_side = "boss"

	driver.reset_after_stage_clear_result(owner, registry)

	_expect(not bool(driver.is_stage_transition_loading_active()), "boss-side reset should not enter stage-transition loading")
	_expect(registry.match_flow_driver.reset_game_calls == 1, "non-player stage-clear reset should keep the regular match reset path")
	_expect(registry.lingpet_runtime.affinity_battle_reset_calls == 0, "non-transition reset should not reset lingpet affinity battle budgets")
	_expect(owner.current_stage == 1, "non-player reset should not advance the stage")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
