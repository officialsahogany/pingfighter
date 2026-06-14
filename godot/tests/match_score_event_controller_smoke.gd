extends SceneTree

const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")

var _failures: Array[String] = []
var _reset_ball_calls := 0


class FakeScoreState:
	extends RefCounted

	var score_calls := 0
	var scoring_side := ""

	func score_for(side: String) -> Dictionary:
		score_calls += 1
		scoring_side = side
		return {
			"player_score": 3,
			"boss_score": 1,
			"match_finished": true,
			"win_goal": 7,
			"next_player_serves": false,
		}


class FakeCancelableScoreState:
	extends RefCounted

	var score_calls := 0
	var would_finish := true
	var deuce_mode := false

	func score_for(_side: String) -> Dictionary:
		score_calls += 1
		return {
			"player_score": 0,
			"boss_score": 0,
			"match_finished": false,
			"win_goal": 5,
			"next_player_serves": true,
		}

	func would_score_finish(_side: String) -> bool:
		return would_finish


class FakeRoundState:
	extends RefCounted

	var player_serves := true
	var set_player_serves_calls := 0
	var scoreboard_wait_calls := 0

	func set_player_serves(value: bool) -> void:
		player_serves = value
		set_player_serves_calls += 1

	func start_scoreboard_wait() -> void:
		scoreboard_wait_calls += 1


class FakeScoreboardState:
	extends RefCounted

	var sparkle_calls := 0
	var start_args: Array = []

	func trigger_top_mini_sparkle() -> void:
		sparkle_calls += 1

	func start(
		player_score: int,
		boss_score: int,
		match_finished: bool,
		scoring_side: String,
		win_goal: int = 5
	) -> void:
		start_args = [player_score, boss_score, match_finished, scoring_side, win_goal]


class FakeBattleResources:
	extends RefCounted

	var begin_calls := 0
	var queue_calls := 0
	var character_type := ""
	var current_stage := 0
	var result_context: Dictionary = {}

	func queue_result_texture_prewarm(
		new_character_type: String,
		new_current_stage: int,
		new_result_context: Dictionary
	) -> void:
		queue_calls += 1
		character_type = new_character_type
		current_stage = new_current_stage
		result_context = new_result_context.duplicate(true)

	func begin_result_texture_prewarm(
		new_character_type: String,
		new_current_stage: int,
		new_result_context: Dictionary
	) -> void:
		begin_calls += 1
		character_type = new_character_type
		current_stage = new_current_stage
		result_context = new_result_context.duplicate(true)


class FakeLingpetRuntime:
	extends RefCounted

	var score_event_calls := 0
	var scoring_sides: Array[String] = []
	var score_results: Array[Dictionary] = []

	func handle_score_event(scoring_side: String, score_result: Dictionary, _deps: Dictionary = {}) -> void:
		score_event_calls += 1
		scoring_sides.append(scoring_side)
		score_results.append(score_result.duplicate(true))


class FakeLingpetRegistry:
	extends RefCounted

	var lingpet_runtime: Object = null

	func _init(new_lingpet_runtime: Object = null) -> void:
		lingpet_runtime = new_lingpet_runtime

	func get_instance(key: String) -> Object:
		if key == "lingpet_egg_runtime":
			return lingpet_runtime
		return null


class FakeMythicItemRuntime:
	extends RefCounted

	var foul_whistle_active := false
	var revival_active := false
	var odins_eye_death_active := false
	var odins_eye_revival_active := false

	func try_trigger_foul_whistle(_loss_type: String, _deps: Dictionary) -> bool:
		return foul_whistle_active

	func try_trigger_revival(_loss_type: String, _deps: Dictionary) -> bool:
		return revival_active

	func is_odins_eye_penalty_active() -> bool:
		return odins_eye_death_active

	func begin_odins_eye_death_sequence(_loss_type: String) -> bool:
		return odins_eye_death_active

	func try_trigger_odins_eye_revival(_loss_type: String) -> bool:
		return odins_eye_revival_active


class FakeStageBackground:
	extends RefCounted

	var expression := ""

	func set_expression(next_expression: String) -> void:
		expression = next_expression


class FakeStage2Background:
	extends RefCounted

	var reset_round_calls := 0
	var saw_audio_dep := false

	func reset_round(deps: Dictionary = {}) -> void:
		reset_round_calls += 1
		saw_audio_dep = deps.get("audio", null) != null


class FakeAudio:
	extends RefCounted

	var stopped: Dictionary = {}
	var play_round_set_calls := 0

	func stop_dash_delay() -> void:
		stopped["dash"] = true

	func stop_boomerang_loop() -> void:
		stopped["boomerang"] = true

	func stop_spider_mine_walk_loop() -> void:
		stopped["spider_mine"] = true

	func stop_plasma_charge() -> void:
		stopped["plasma_charge"] = true

	func stop_plasma_shock() -> void:
		stopped["plasma_shock"] = true

	func stop_warp_gate_loop() -> void:
		stopped["warp"] = true

	func stop_magnum_grip() -> void:
		stopped["magnum"] = true

	func stop_viper_jetpack_loop() -> void:
		stopped["viper_jetpack"] = true

	func stop_chaos_spear_blackhole_loop() -> void:
		stopped["chaos_blackhole"] = true

	func stop_ragnarok_shock_loop() -> void:
		stopped["ragnarok_shock"] = true

	func stop_electric_shock_loop() -> void:
		stopped["electric_shock"] = true

	func stop_stage2_quake_loop() -> void:
		stopped["quake"] = true

	func stop_stage5_hongryun_fireball() -> void:
		stopped["stage5_fireball"] = true

	func stop_stage5_hongryun_charge() -> void:
		stopped["stage5_charge"] = true

	func stop_stage5_hongryun_shoot() -> void:
		stopped["stage5_shoot"] = true

	func play_round_set() -> void:
		play_round_set_calls += 1


class FakeStage4PonkSkillState:
	extends RefCounted

	var reset_round_calls := 0
	var saw_audio_dep := false

	func reset_round(deps: Dictionary = {}) -> void:
		reset_round_calls += 1
		saw_audio_dep = deps.get("audio", null) != null


class FakeStage5HongryunState:
	extends RefCounted

	var reset_round_calls := 0

	func reset_round() -> void:
		reset_round_calls += 1


class FakeStage5HongryunFireMachineEvent:
	extends RefCounted

	var reset_round_calls := 0

	func reset_round() -> void:
		reset_round_calls += 1


class FakeStage5HongryunActorRenderer:
	extends RefCounted

	var reset_round_fx_calls := 0

	func reset_round_fx() -> void:
		reset_round_fx_calls += 1


func _init() -> void:
	var controller: Object = MatchFlowController.new()
	var score := FakeScoreState.new()
	var round_state := FakeRoundState.new()
	var scoreboard := FakeScoreboardState.new()
	var stage_background := FakeStageBackground.new()
	var audio := FakeAudio.new()
	var battle_resources := FakeBattleResources.new()
	var lingpet_runtime := FakeLingpetRuntime.new()

	controller.handle_score_event("player", {
		"score_state": score,
		"round_state": round_state,
		"scoreboard_state": scoreboard,
		"stage_background": stage_background,
		"audio": audio,
		"battle_resources": battle_resources,
		"selected_character_type": "smasher",
		"current_stage": 1,
		"registry": FakeLingpetRegistry.new(lingpet_runtime),
	}, {
		"reset_ball": Callable(self, "_record_reset_ball"),
	})

	_expect(score.score_calls == 1 and score.scoring_side == "player", "score state should receive scoring side")
	_expect(lingpet_runtime.score_event_calls == 1 and lingpet_runtime.scoring_sides == ["player"], "lingpet affinity score hook should run once after a committed score")
	_expect(bool(lingpet_runtime.score_results[0].get("match_finished", false)), "lingpet affinity score hook should receive the committed score result")
	_expect(stage_background.expression == "sad", "player score should set sad stage expression")
	_expect(round_state.set_player_serves_calls == 1 and not round_state.player_serves, "next serve should sync from score result")
	_expect(scoreboard.sparkle_calls == 1, "scoreboard should trigger mini sparkle")
	_expect(scoreboard.start_args == [3, 1, true, "player", 7], "scoreboard should start from score result")
	_expect(battle_resources.queue_calls == 1 and battle_resources.begin_calls == 0, "score event should defer result texture prewarm until the scoreboard is visible")
	_expect(battle_resources.character_type == "smasher" and battle_resources.current_stage == 1, "score event should queue result texture prewarm for the current character and stage")
	_expect(bool(battle_resources.result_context.get("player_victory_active", false)) and bool(battle_resources.result_context.get("boss_defeat_active", false)), "player score should queue player victory and boss defeat result textures")
	_expect(round_state.scoreboard_wait_calls == 1, "round state should enter scoreboard wait")
	_expect(_reset_ball_calls == 0, "scoreboard flow should not reset ball immediately")
	_expect(audio.stopped.size() == 15 and bool(audio.stopped.get("boomerang", false)) and bool(audio.stopped.get("spider_mine", false)) and bool(audio.stopped.get("chaos_blackhole", false)) and bool(audio.stopped.get("stage5_charge", false)) and audio.play_round_set_calls == 1, "score audio should stop gameplay loops and play round set")

	var stage4_ponk_skill_state := FakeStage4PonkSkillState.new()
	controller.handle_score_event("player", {
		"score_state": FakeScoreState.new(),
		"round_state": FakeRoundState.new(),
		"scoreboard_state": FakeScoreboardState.new(),
		"audio": FakeAudio.new(),
		"current_stage": 4,
		"stage4_ponk_skill_state": stage4_ponk_skill_state,
	}, {
		"reset_ball": Callable(self, "_record_reset_ball"),
	})
	_expect(stage4_ponk_skill_state.reset_round_calls == 1, "Stage 4 score boundary should clear Ponk magnetic FX before result overlays")
	_expect(stage4_ponk_skill_state.saw_audio_dep, "Stage 4 score boundary should pass audio deps to Ponk FX cleanup")

	var stage2_background := FakeStage2Background.new()
	controller.handle_score_event("player", {
		"score_state": FakeScoreState.new(),
		"round_state": FakeRoundState.new(),
		"scoreboard_state": FakeScoreboardState.new(),
		"stage_background": stage2_background,
		"audio": FakeAudio.new(),
		"current_stage": 2,
	}, {
		"reset_ball": Callable(self, "_record_reset_ball"),
	})
	_expect(stage2_background.reset_round_calls == 1, "Stage 2 score boundary should clear jungle quake round effects before the next serve")
	_expect(stage2_background.saw_audio_dep, "Stage 2 score boundary should pass audio deps to quake cleanup")

	var stage5_hongryun_state := FakeStage5HongryunState.new()
	var stage5_hongryun_fire_machine_event := FakeStage5HongryunFireMachineEvent.new()
	var stage5_hongryun_actor_renderer := FakeStage5HongryunActorRenderer.new()
	controller.handle_score_event("player", {
		"score_state": FakeScoreState.new(),
		"round_state": FakeRoundState.new(),
		"scoreboard_state": FakeScoreboardState.new(),
		"audio": FakeAudio.new(),
		"current_stage": 5,
		"stage5_hongryun_state": stage5_hongryun_state,
		"stage5_hongryun_fire_machine_event": stage5_hongryun_fire_machine_event,
		"stage5_hongryun_actor_renderer": stage5_hongryun_actor_renderer,
	}, {
		"reset_ball": Callable(self, "_record_reset_ball"),
	})
	_expect(stage5_hongryun_state.reset_round_calls == 1, "Stage 5 score boundary should clear Hongryun inferno state before result overlays")
	_expect(stage5_hongryun_fire_machine_event.reset_round_calls == 1, "Stage 5 score boundary should clear Hongryun fire-machine zones before result overlays")
	_expect(stage5_hongryun_actor_renderer.reset_round_fx_calls == 1, "Stage 5 score boundary should hide Hongryun detached inferno FX hosts")

	var boss_stage_background := FakeStageBackground.new()
	controller.handle_score_event("boss", {
		"score_state": FakeScoreState.new(),
		"round_state": FakeRoundState.new(),
		"stage_background": boss_stage_background,
		"audio": FakeAudio.new(),
	}, {
		"reset_ball": Callable(self, "_record_reset_ball"),
	})
	_expect(boss_stage_background.expression == "happy", "boss score should set happy stage expression")
	_expect(_reset_ball_calls == 1, "missing scoreboard should reset ball immediately")

	var null_score_audio := FakeAudio.new()
	controller.handle_score_event("player", {
		"audio": null_score_audio,
	}, {
		"reset_ball": Callable(self, "_record_reset_ball"),
	})
	_expect(null_score_audio.play_round_set_calls == 0, "missing score state should skip score event side effects")
	_expect(_reset_ball_calls == 1, "missing score state should not reset ball")

	_verify_lingpet_affinity_skips_score_cancel_paths(controller)

	if _failures.is_empty():
		print("match_score_event_controller_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _record_reset_ball() -> void:
	_reset_ball_calls += 1


func _verify_lingpet_affinity_skips_score_cancel_paths(controller: Object) -> void:
	var foul_whistle := FakeMythicItemRuntime.new()
	foul_whistle.foul_whistle_active = true
	_expect_cancel_path_blocks_lingpet(controller, "foul whistle", "boss", foul_whistle, FakeCancelableScoreState.new())

	var revival := FakeMythicItemRuntime.new()
	revival.revival_active = true
	_expect_cancel_path_blocks_lingpet(controller, "revival", "boss", revival, FakeCancelableScoreState.new())

	var odins_eye_death := FakeMythicItemRuntime.new()
	odins_eye_death.odins_eye_death_active = true
	_expect_cancel_path_blocks_lingpet(controller, "Odin death", "boss", odins_eye_death, FakeCancelableScoreState.new())

	var odins_eye_revival := FakeMythicItemRuntime.new()
	odins_eye_revival.odins_eye_revival_active = true
	_expect_cancel_path_blocks_lingpet(controller, "Odin revival", "boss", odins_eye_revival, FakeCancelableScoreState.new())


func _expect_cancel_path_blocks_lingpet(
	controller: Object,
	path_name: String,
	scoring_side: String,
	mythic_runtime: Object,
	score_state: FakeCancelableScoreState
) -> void:
	var lingpet_runtime := FakeLingpetRuntime.new()
	controller.handle_score_event(scoring_side, {
		"score_state": score_state,
		"round_state": FakeRoundState.new(),
		"scoreboard_state": FakeScoreboardState.new(),
		"mythic_item_runtime": mythic_runtime,
		"lingpet_egg_runtime": lingpet_runtime,
		"audio": FakeAudio.new(),
	}, {
		"reset_ball": Callable(self, "_record_reset_ball"),
	})
	_expect(score_state.score_calls == 0, "%s should return before score_state.score_for commits a score" % path_name)
	_expect(lingpet_runtime.score_event_calls == 0, "%s should not grant lingpet affinity on a canceled score path" % path_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
