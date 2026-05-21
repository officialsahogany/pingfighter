extends SceneTree

const BattleSceneMatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")

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

	var stop_bgm_calls := 0
	var play_stage_bgm_calls := 0
	var last_stage := 0

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


class FakePrewarmController:
	extends RefCounted

	var step_calls := 0
	var monolithic_calls := 0
	var complete_after := 3

	func prewarm_stage_runtime_resources_step(_owner: Object, _module_getter: Callable) -> bool:
		step_calls += 1
		return step_calls >= complete_after

	func prewarm_stage_runtime_resources(_owner: Object, _module_getter: Callable) -> void:
		monolithic_calls += 1


class FakeRegistry:
	extends RefCounted

	var scoreboard_state := FakeScoreboardState.new()
	var match_flow_driver := FakeMatchFlowDriver.new()
	var ball_physics := FakeBallPhysics.new()
	var commando_weapon_controller := FakeCommandoWeaponController.new()
	var battle_resources := FakeBattleResources.new()
	var game_audio := FakeGameAudio.new()
	var loading_renderer := FakeLoadingRenderer.new()
	var prewarm_controller := FakePrewarmController.new()

	func get_instance(key: String) -> Object:
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
			"battle_boot_resource_prewarm_controller":
				return prewarm_controller
		return null


func _init() -> void:
	_verify_stage_clear_to_stage2_uses_loading_gate()
	_verify_stage4_clear_to_stage5_uses_loading_gate()
	_verify_stage5_clear_ends_demo_sequence()
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
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "transition work should wait until loading was drawn once")
	_expect(registry.match_flow_driver.reset_game_calls == 0, "stage-clear advance should not invoke the full match reset path")
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
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 0, "stage-transition reset should be split out of the first work chunk")
	_expect(registry.battle_resources.load_all_calls == 0, "battle textures should wait for their own transition work chunk")

	for _step in range(3):
		driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.match_flow_driver.reset_for_stage_transition_calls == 1, "stage-clear advance should run the perk/item-preserving stage-transition reset")
	_expect(registry.match_flow_driver.reset_game_calls == 0, "stage-clear advance must not wipe perks/items via the full match reset")
	_expect(registry.battle_resources.load_all_calls == 1, "transition work should reload battle textures once")
	_expect(int(registry.battle_resources.last_config.get("current_stage", 0)) == 2, "battle textures should reload for stage 2")
	_expect(registry.commando_weapon_controller.prepare_calls == 1 and registry.commando_weapon_controller.last_stage == 2, "commando stage-start prep should run for stage 2")
	_expect(registry.prewarm_controller.step_calls == 0, "stage runtime prewarm should wait for its own loading-frame chunk")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.prewarm_controller.step_calls == 1, "stage runtime prewarm should run through the step API")
	_expect(registry.game_audio.play_stage_bgm_calls == 0, "stage audio restart should wait until staged prewarm completes")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.prewarm_controller.step_calls == 2, "incomplete staged prewarm should keep the transition work on the prewarm chunk")
	_expect(registry.game_audio.play_stage_bgm_calls == 0, "stage audio restart should still wait for staged prewarm")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.prewarm_controller.step_calls == 3, "staged prewarm should complete after the configured loading chunks")
	_expect(registry.game_audio.play_stage_bgm_calls == 0, "stage audio restart should run on the next chunk after staged prewarm")
	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.game_audio.stop_bgm_calls == 1, "stage-transition work should stop the previous BGM")
	_expect(registry.game_audio.play_stage_bgm_calls == 1 and registry.game_audio.last_stage == 2, "stage-transition work should start stage 2 BGM")
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
		float(registry.loading_renderer.last_context.get("loading_progress", 1.0)) < 0.15,
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


func _verify_stage5_clear_ends_demo_sequence() -> void:
	var driver: Object = BattleSceneMatchEventDriver.new()
	var owner := FakeOwner.new()
	owner.current_stage = 5
	var registry := FakeRegistry.new()

	driver.reset_after_stage_clear_result(owner, registry)

	_expect(not bool(driver.is_stage_transition_loading_active()), "code stage 5 player clear should not advance to an unimplemented next demo stage")
	_expect(registry.match_flow_driver.reset_game_calls == 1, "code stage 5 clear should fall back to the regular match reset path")
	_expect(owner.current_stage == 5, "code stage 5 clear should leave the current stage id unchanged for the regular reset path")


func _verify_non_player_reset_keeps_immediate_match_reset() -> void:
	var driver: Object = BattleSceneMatchEventDriver.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.scoreboard_state.last_scoring_side = "boss"

	driver.reset_after_stage_clear_result(owner, registry)

	_expect(not bool(driver.is_stage_transition_loading_active()), "boss-side reset should not enter stage-transition loading")
	_expect(registry.match_flow_driver.reset_game_calls == 1, "non-player stage-clear reset should keep the regular match reset path")
	_expect(owner.current_stage == 1, "non-player reset should not advance the stage")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
