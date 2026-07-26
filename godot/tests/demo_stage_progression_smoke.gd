extends SceneTree

const MatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")

var _failures: Array[String] = []


class FakeSelectionState:
	extends Node

	var stage_id := 1

	func set_stage(stage: int) -> void:
		stage_id = stage


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {
		"current_stage": 1,
		"ai_mode": "champion",
		"arena_mode_enabled": false,
		"weather_type": "rain",
		"weather_event_active": true,
		"weather_event_context": {"kind": "rain"},
		"selected_character_type": "smasher",
		"battle_textures": {},
		"smasher_skill_icon_textures": {},
		"viper_skill_icon_textures": {},
		"commando_skill_icon_textures": {},
	}
	var selection_state := FakeSelectionState.new()
	var redraw_count := 0

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true

	func get_node_or_null(_path: NodePath) -> Node:
		return selection_state

	func queue_redraw() -> void:
		redraw_count += 1


class FakeScoreboardState:
	extends RefCounted

	var last_scoring_side := "player"

	func get_last_scoring_side() -> String:
		return last_scoring_side


class FakeMatchFlowDriver:
	extends RefCounted

	var reset_game_calls := 0
	var reset_for_stage_transition_calls := 0
	var reset_stage_seen := 0
	var transition_reset_stage_seen := 0
	var scoreboard_delta := 0.0

	func update_scoreboard(
		_registry: Object,
		delta: float,
		reset_game_callback: Callable,
		_reset_ball_callback: Callable,
		_owner: Object = null
	) -> void:
		scoreboard_delta = delta
		reset_game_callback.call()

	func reset_game(owner: Object, _registry: Object, reset_drive_input_callback: Callable, reset_ball_callback: Callable) -> void:
		reset_game_calls += 1
		reset_stage_seen = int(owner.get("current_stage"))
		if reset_drive_input_callback.is_valid():
			reset_drive_input_callback.call()
		if reset_ball_callback.is_valid():
			reset_ball_callback.call()

	func reset_for_stage_transition(owner: Object, _registry: Object, reset_drive_input_callback: Callable, reset_ball_callback: Callable) -> void:
		reset_for_stage_transition_calls += 1
		transition_reset_stage_seen = int(owner.get("current_stage"))
		if reset_drive_input_callback.is_valid():
			reset_drive_input_callback.call()
		if reset_ball_callback.is_valid():
			reset_ball_callback.call()


class FakeBallDriver:
	extends RefCounted

	var reset_calls := 0
	var drive_reset_calls := 0

	func reset_ball(_owner: Object, _registry: Object) -> void:
		reset_calls += 1

	func reset_drive_input_frames(_registry: Object) -> void:
		drive_reset_calls += 1


class FakeBossHealthFlow:
	extends RefCounted

	var reset_calls := 0

	func reset_round_health(_owner: Object) -> void:
		reset_calls += 1


class FakeAudio:
	extends RefCounted

	var stopped: Array[String] = []
	var played_stage := 0

	func stop_dash_delay() -> void:
		stopped.append("dash_delay")

	func stop_stage2_quake_loop() -> void:
		stopped.append("stage2_quake")

	func stop_bgm() -> void:
		stopped.append("bgm")

	func play_stage_bgm(stage_id: int) -> bool:
		played_stage = stage_id
		return true


class FakeBallPhysics:
	extends RefCounted

	var configured_stage := 0
	var configured_weather := "unset"

	func configure_context(stage_id: int, _ai_mode: String, _arena_enabled: bool, weather_type: String) -> void:
		configured_stage = stage_id
		configured_weather = weather_type


class FakeBattleResources:
	extends RefCounted

	var loaded_stage := 0

	func load_all(context: Dictionary = {}) -> Dictionary:
		loaded_stage = int(context.get("current_stage", 0))
		return {
			"loaded_stage": loaded_stage,
			"smasher_skill_icon_textures": {"drive": "drive_icon"},
			"viper_skill_icon_textures": {},
			"commando_skill_icon_textures": {},
		}


class FakeCommandoWeaponController:
	extends RefCounted

	var prepared_stage := 0
	var forced := false

	func prepare_stage_start(stage_id: int, force: bool = false) -> Dictionary:
		prepared_stage = stage_id
		forced = force
		return {}


class FakeLoadingRenderer:
	extends RefCounted

	var draw_calls := 0
	var hide_loading_calls := 0

	func draw(
		_canvas: CanvasItem,
		_owner: Object,
		_module_getter: Callable,
		_view_size: Vector2,
		_context: Dictionary = {}
	) -> void:
		draw_calls += 1

	func hide_loading() -> void:
		hide_loading_calls += 1


class FakeRegistry:
	extends RefCounted

	var scoreboard := FakeScoreboardState.new()
	var match_flow := FakeMatchFlowDriver.new()
	var ball := FakeBallDriver.new()
	var boss_health := FakeBossHealthFlow.new()
	var audio := FakeAudio.new()
	var ball_physics := FakeBallPhysics.new()
	var resources := FakeBattleResources.new()
	var commando_weapon := FakeCommandoWeaponController.new()
	var loading_renderer := FakeLoadingRenderer.new()

	func get_instance(key: String) -> Object:
		match key:
			"scoreboard_state":
				return scoreboard
			"battle_scene_match_flow_driver":
				return match_flow
			"battle_scene_ball_update_driver":
				return ball
			"battle_scene_boss_health_flow":
				return boss_health
			"game_audio":
				return audio
			"ball_physics":
				return ball_physics
			"battle_resources":
				return resources
			"commando_weapon_controller":
				return commando_weapon
			"battle_loading_screen_renderer":
				return loading_renderer
		return null


func _init() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var driver: Object = MatchEventDriver.new()

	driver.update_scoreboard(0.25, owner, registry)
	_expect(registry.match_flow.scoreboard_delta == 0.25, "scoreboard update should be forwarded")
	_expect(int(owner.data.get("current_stage", 0)) == 2, "player stage clear should advance Stage 1 to Stage 2")
	_expect(owner.selection_state.stage_id == 2, "selection state should persist the advanced stage")
	_expect(not bool(owner.data.get("weather_event_active", true)), "stage transition should clear weather event state")
	_expect(str(owner.data.get("weather_type", "rain")) == "", "stage transition should clear weather type")
	_expect(bool(driver.is_stage_transition_loading_active()), "stage transition should enter the loading gate")
	_expect(registry.match_flow.reset_for_stage_transition_calls == 0, "stage transition work should wait until loading was drawn once")
	_expect(registry.match_flow.reset_game_calls == 0, "stage transition should not run the full match reset")
	_expect(registry.resources.loaded_stage == 0, "battle resources should wait until the loading gate is visible")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.match_flow.reset_for_stage_transition_calls == 0, "pre-draw loading update should not run transition work")

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
		"active stage transition should consume a loading draw"
	)
	canvas.queue_free()

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.ball_physics.configured_stage == 2, "ball physics should be reconfigured for the next stage")
	_expect(registry.ball_physics.configured_weather == "", "ball physics should use cleared weather")
	_expect(registry.match_flow.reset_for_stage_transition_calls == 0, "stage transition reset should wait for its own staged chunk")

	# Round dependencies now prewarm one module per loading-frame chunk. Keep the
	# progression smoke independent from the exact dependency count while still
	# proving the preserving reset cannot run before that staged work completes.
	for _round_dep_frame: int in range(256):
		if int(driver.get("_stage_transition_loading_work_step")) >= 2:
			break
		driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(int(driver.get("_stage_transition_loading_work_step")) >= 2, "round dependency prewarm should complete within the bounded loading window")
	_expect(registry.match_flow.reset_for_stage_transition_calls == 0, "round dependency prewarm should finish before the preserving reset chunk")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.match_flow.reset_for_stage_transition_calls == 1, "stage transition should run the preserving reset once")
	_expect(registry.match_flow.reset_game_calls == 0, "stage transition preserving reset should not call reset_game")
	_expect(registry.match_flow.transition_reset_stage_seen == 2, "stage transition reset should see the next stage")
	_expect(registry.ball.drive_reset_calls == 1 and registry.ball.reset_calls == 1, "stage transition reset should reset drive and ball")
	_expect(registry.boss_health.reset_calls == 1, "stage transition ball reset should refresh boss health")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.commando_weapon.prepared_stage == 2 and registry.commando_weapon.forced, "commando stage prep should run for the next stage")
	_expect(registry.resources.loaded_stage == 0, "battle resources should wait for their own staged chunk")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.resources.loaded_stage == 2, "battle resources should reload for the next stage")
	_expect(int(owner.data.get("battle_textures", {}).get("loaded_stage", 0)) == 2, "owner textures should receive the next-stage cache")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(not registry.audio.stopped.has("bgm"), "stage transition audio should wait until staged prewarm completes")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(not registry.audio.stopped.has("dash_delay") and not registry.audio.stopped.has("bgm"), "stage transition audio should wait until stage-clear result prewarm completes")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.audio.stopped.has("dash_delay") and not registry.audio.stopped.has("bgm"), "stage transition should stop gameplay loops before old BGM")
	_expect(registry.audio.played_stage == 0, "stage transition should wait to start BGM until cleanup chunks finish")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.audio.stopped.has("bgm"), "stage transition should stop old BGM after gameplay loops")
	_expect(registry.audio.played_stage == 0, "stage transition should wait one more chunk before starting next-stage BGM")

	driver.update_stage_transition_loading(0.05, owner, registry)
	_expect(registry.audio.played_stage == 2, "stage transition should start next-stage BGM")
	_expect(owner.redraw_count >= 3, "stage transition loading should queue redraws through the gate")

	driver.update_stage_transition_loading(2.25, owner, registry)
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
	driver.update_stage_transition_loading(0.30, owner, registry)
	_expect(not bool(driver.is_stage_transition_loading_active()), "stage transition loading should finish after the final reveal")

	registry.scoreboard.last_scoring_side = "boss"
	registry.audio.played_stage = 0
	driver.update_scoreboard(0.1, owner, registry)
	_expect(int(owner.data.get("current_stage", 0)) == 2, "boss match win should not advance the demo stage")
	_expect(registry.audio.played_stage == 0, "non-advance reset should not restart stage BGM from progression logic")

	registry.scoreboard.last_scoring_side = "player"
	owner.set("current_stage", 4)
	driver.update_scoreboard(0.1, owner, registry)
	_expect(int(owner.data.get("current_stage", 0)) == 5, "Stage 4 clear should advance to the Hongryun demo stage")
	_expect(bool(driver.is_stage_transition_loading_active()), "Stage 4 clear should enter the Stage 5 loading gate")

	owner.set("current_stage", 7)
	_expect(int(driver.call("_get_demo_next_stage", owner, registry)) == 8, "Stage 7 clear should advance into the routed Stage 8 Minotaur encounter")
	owner.set("current_stage", 8)
	_expect(int(driver.call("_get_demo_next_stage", owner, registry)) == 0, "Stage 8 should remain the current demo sequence endpoint")

	if _failures.is_empty():
		print("demo_stage_progression_smoke: ok")
		owner.selection_state.free()
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		owner.selection_state.free()
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
