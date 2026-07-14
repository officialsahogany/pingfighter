extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")
const StageRuntimeRouter := preload("res://scripts/stages/stage_runtime_router.gd")
const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const StageRuntimeDepsBuilder := preload("res://scripts/core/battle_update_stage_runtime_deps_builder.gd")
const EffectsDepsBuilder := preload("res://scripts/core/battle_update_effects_deps_builder.gd")
const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const FrameFlowDepsBuilder := preload("res://scripts/core/battle_frame_flow_deps_builder.gd")
const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")
const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BossAIState := preload("res://scripts/ai/boss_ai_state.gd")
const BossAIContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")
const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const BattleBootResourcePrewarmController := preload("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
const StageClearResultRuntimeContextData := preload("res://scripts/core/stage_clear_result_runtime_context_data.gd")

const STAGE7_ROUTE_EXPECTATIONS := {
	"actor_renderer": "stage7_akamu_actor_renderer",
	"boss_actor_renderer": "stage7_akamu_boss_actor_renderer",
	"pillar_scene_drawer": "stage7_akamu_pillar_scene_drawer",
	"stage_background": "stage7_akamu_pillar_background",
	"playfield_renderer": "stage7_akamu_playfield_renderer",
	"boss_skill_hud_renderer": "stage7_akamu_boss_skill_hud_renderer",
}

const STAGE7_CATALOG_KEYS := [
	"stage7_akamu_state",
	"stage7_akamu_actor_renderer",
	"stage7_akamu_boss_actor_renderer",
	"stage7_akamu_playfield_renderer",
	"stage7_akamu_pillar_background",
	"stage7_akamu_pillar_scene_drawer",
	"stage7_akamu_boss_skill_hud_renderer",
]

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 7


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []
	var peeked_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		peeked_keys.append(key)
		return instances.get(key, null)


class FlowProbe:
	extends RefCounted

	var calls: Array[String] = []
	var stage7_state: Object = null

	func update_weather(_delta: float) -> void:
		calls.append("update_weather")

	func update_mythic_items(_delta: float) -> void:
		calls.append("update_mythic_items")

	func update_player_control(_delta: float) -> void:
		calls.append("update_player_control")

	func update_runtime_perk_resume(_delta: float) -> void:
		calls.append("update_runtime_perk_resume")

	func update_active_items(_delta: float) -> void:
		calls.append("update_active_items")

	func update_boss_ai(_delta: float) -> void:
		calls.append("update_boss_ai")

	func update_ball(_delta: float) -> void:
		calls.append("update_ball")

	func update_lingpet(_delta: float) -> void:
		calls.append("update_lingpet")

	func update_effects(delta: float) -> void:
		calls.append("update_effects")
		if stage7_state != null:
			stage7_state.update(delta, {
				"current_stage": 7,
				"ball_active": true,
				"waiting_for_serve": false,
			})

	func queue_redraw() -> void:
		calls.append("queue_redraw")


class FakeScoreState:
	extends RefCounted

	var player_score := 0
	var boss_score := 0

	func score_for(scoring_side: String) -> Dictionary:
		if scoring_side == "player":
			player_score += 1
		else:
			boss_score += 1
		return {
			"player_score": player_score,
			"boss_score": boss_score,
			"match_finished": false,
			"next_player_serves": scoring_side == "boss",
			"win_goal": 5,
		}


class RoundResetProbe:
	extends RefCounted

	var state: Object = null
	var reset_calls := 0

	func reset_ball() -> void:
		reset_calls += 1
		BallRoundActorCleanup.new().reset_actor_round_state({
			"stage7_akamu_state": state,
		})


class FakeStageBackground:
	extends RefCounted

	var excitement_calls := 0

	func trigger_excitement(_level: float = 1.0) -> void:
		excitement_calls += 1


class FakeStage7CollisionState:
	extends RefCounted

	var intangible := false
	var boss_hit_calls := 0
	var seen_scene: Dictionary = {}
	var post_collision_calls := 0

	func is_boss_ball_intangible() -> bool:
		return intangible

	func handle_boss_paddle_hit(scene: Dictionary, _context: Dictionary, _deps: Dictionary = {}) -> void:
		boss_hit_calls += 1
		seen_scene = scene.duplicate(true)

	func resolve_ball_collision(_scene: Dictionary, _context: Dictionary, _deps: Dictionary = {}) -> void:
		post_collision_calls += 1


class FakeOverdriveState:
	extends RefCounted

	var reflect_calls := 0

	func notify_ball_reflected(_ball_vel: Vector2, _impact_pos: Vector2) -> void:
		reflect_calls += 1


class FakeResultStage7State:
	extends RefCounted

	var reset_for_result_calls := 0

	func reset_for_result() -> void:
		reset_for_result_calls += 1


class FakePaddleBounceController:
	extends RefCounted

	var calls := 0
	var return_empty := false
	var return_uncommitted := false

	func bounce(
		_paddle_x: float,
		_paddle_w: float,
		_is_player: bool,
		context: Dictionary,
		_deps: Dictionary,
		_callbacks: Dictionary = {}
	) -> Dictionary:
		calls += 1
		if return_empty:
			return {}
		if return_uncommitted:
			return {
				"ball_pos": context.get("ball_pos", Vector2.ZERO),
				"ball_vel": Vector2(3.0, 12.0),
			}
		return {
			"ball_pos": context.get("ball_pos", Vector2.ZERO),
			"ball_vel": Vector2(3.0, 12.0),
			"boss_collision_cooldown": 10.0,
			"normal_boss_bounce_committed": true,
		}


class FakePlayerPaddleMotionStepper:
	extends RefCounted

	func step(ball_pos: Vector2, _effective_move: Vector2, _ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		return {
			"event": "player_paddle",
			"is_player": true,
			"paddle_x": 302.5,
			"paddle_w": 155.0,
			"impact_pos": ball_pos,
			"ball_pos": ball_pos,
		}


class FakeWallMotionStepper:
	extends RefCounted

	func step(ball_pos: Vector2, _effective_move: Vector2, _ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		return {
			"event": "wall",
			"side": "left",
			"impact_pos": ball_pos,
			"ball_pos": ball_pos,
		}


class FakeWallBounceController:
	extends RefCounted

	var calls := 0

	func process(
		ball_vel: Vector2,
		_ball_impact_boost: float,
		_side: String,
		_impact_pos: Vector2,
		_height: float,
		_deps: Dictionary
	) -> Dictionary:
		calls += 1
		return {"ball_vel": Vector2(absf(ball_vel.x), ball_vel.y)}


class FakePrewarmModule:
	extends RefCounted

	var calls := 0

	func prewarm_assets_step() -> bool:
		calls += 1
		return true


class FakeEntryPrewarmModule:
	extends RefCounted

	var calls := 0

	func prewarm_stage_entry_step(_owner: Object) -> bool:
		calls += 1
		return true


class FakePillarPrewarmModule:
	extends RefCounted

	var calls := 0
	var character_type := ""

	func prewarm_assets_step(_module_getter: Callable, selected_character_type: String = "smasher") -> bool:
		calls += 1
		character_type = selected_character_type
		return true


func _init() -> void:
	_verify_legacy_frame_conversion()
	_verify_round_reset_and_score_carry_are_separate()
	_verify_accepted_score_event_owns_round_carry()
	_verify_state_freeze_advances_without_ticking_transients()
	_verify_frame_flow_freezes_motion_but_advances_stage_effects()
	_verify_stage7_router_and_catalog()
	_verify_stage7_dependency_surfaces()
	_verify_effects_controller_ticks_stage7_state()
	_verify_boss_intangible_gate_precedes_paddle_detection()
	_verify_post_bounce_hook_is_boss_paddle_only()
	_verify_post_motion_collision_hook_is_wired()
	_verify_stage7_boot_prewarm_dispatch()
	_verify_scripted_ai_position_bypasses_shared_postprocessors()
	_verify_overdrive_reflection_requires_committed_bounce()
	_verify_result_reset_reaches_stage7_owner()

	if _failures.is_empty():
		print("stage7_akamu_slice1_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_legacy_frame_conversion() -> void:
	_expect_close(Stage7AkamuState.fps_scale(1.0 / 30.0), 2.0, "30 Hz delta should equal two legacy frames")
	_expect_close(Stage7AkamuState.fps_scale(1.0 / 60.0), 1.0, "60 Hz delta should equal one legacy frame")
	_expect_close(Stage7AkamuState.fps_scale(1.0 / 120.0), 0.5, "120 Hz delta should equal half a legacy frame")
	_expect_close(Stage7AkamuState.fps_scale(-1.0), 0.0, "negative delta should not move legacy actors")
	_expect_close(Stage7AkamuState.fps_scale(1.0), 6.0, "legacy frame scale should clamp a hitch to 100 ms")

	var distances: Dictionary = {}
	for hz in [30, 60, 120]:
		var distance := 0.0
		var delta := 1.0 / float(hz)
		for _tick in range(int(round(float(hz) * 0.1))):
			distance += Stage7AkamuState.legacy_motion_step(20.0, delta)
		distances[hz] = distance
	_expect_close(float(distances[30]), 120.0, "30 Hz should travel 120 px in 100 ms at 20 px/frame")
	_expect_close(float(distances[60]), 120.0, "60 Hz should travel the same real-time distance")
	_expect_close(float(distances[120]), 120.0, "120 Hz should travel the same real-time distance")


func _verify_round_reset_and_score_carry_are_separate() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(400.0)
	state.debug_set_awakened(true)
	state.debug_begin_gameplay_freeze(3.0)
	state.debug_set_boss_ball_intangible(true)
	state.debug_set_scripted_boss_position(true, Vector2(123.0, 45.0))
	state.set("_clones", [{"id": 1}])
	state.set("_shurikens", [{"position": Vector2(300.0, 200.0)}])
	state.set("_afterimages", [{"alpha": 1.0}])
	state.set("_particles", [{"life": 1.0}])
	state.set("_cloud_draw_context", {"active": true})
	state.set("_aura_draw_context", {"active": true})

	state.reset_round()
	var actor_context: Dictionary = state.get_actor_draw_context()
	var ai_context: Dictionary = state.get_boss_ai_context()
	_expect_close(state.debug_get_gauge(), 400.0, "generic round reset must not decay the persistent Stage 7 gauge")
	_expect(state.debug_is_awakened(), "generic round reset should preserve awakening")
	_expect((actor_context.get("stage7_akamu_clones", []) as Array).is_empty(), "round reset should clear clones")
	_expect((actor_context.get("stage7_akamu_shurikens", []) as Array).is_empty(), "round reset should clear shurikens")
	_expect((actor_context.get("stage7_akamu_afterimages", []) as Array).is_empty(), "round reset should clear afterimages")
	_expect((actor_context.get("stage7_akamu_particles", []) as Array).is_empty(), "round reset should clear particles")
	_expect((actor_context.get("stage7_akamu_cloud", {}) as Dictionary).is_empty(), "round reset should clear cloud draw state")
	_expect((actor_context.get("stage7_akamu_aura", {}) as Dictionary).is_empty(), "round reset should clear aura draw state")
	_expect(not bool(actor_context.get("stage7_akamu_gameplay_freeze_active", true)), "round reset should release the gameplay freeze")
	_expect(not bool(actor_context.get("stage7_akamu_boss_ball_intangible", true)), "round reset should release boss-ball intangibility")
	_expect(not bool(ai_context.get("stage7_akamu_scripted_motion_active", true)), "round reset should release scripted boss motion")

	_expect(state.apply_score_round_carry(1), "the first committed score generation should apply carry")
	_expect_close(state.debug_get_gauge(), 280.0, "score carry should convert 400 gauge to int(400 * 0.7) = 280")
	state.reset_round()
	_expect_close(state.debug_get_gauge(), 280.0, "the later generic ball reset must not apply carry a second time")
	_expect(not state.apply_score_round_carry(1), "the same score generation should be idempotent")
	_expect_close(state.debug_get_gauge(), 280.0, "duplicate score generation must leave carried gauge unchanged")
	_expect(state.apply_score_round_carry(2), "a later committed point should apply one new carry")
	_expect_close(state.debug_get_gauge(), 196.0, "a second real point should carry 280 gauge to 196")

	state.reset()
	_expect_close(state.debug_get_gauge(), 0.0, "full reset should clear Stage 7 gauge")
	_expect(not state.debug_is_awakened(), "full reset should clear awakening")
	_expect(state.apply_score_round_carry(1), "full reset should clear the score-generation guard for a new match")


func _verify_accepted_score_event_owns_round_carry() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(400.0)
	state.debug_begin_gameplay_freeze(3.0)
	state.set("_clones", [{"id": 1}])
	var score_state := FakeScoreState.new()
	var reset_probe := RoundResetProbe.new()
	var stage_background := FakeStageBackground.new()
	reset_probe.state = state

	MatchScoreEventController.new().handle_score_event("player", {
		"score_state": score_state,
		"current_stage": 7,
		"stage7_akamu_state": state,
		"stage_background": stage_background,
	}, {
		"reset_ball": Callable(reset_probe, "reset_ball"),
	})

	_expect(score_state.player_score == 1 and score_state.boss_score == 0, "score flow should commit exactly one point before deriving the Stage 7 generation")
	_expect(reset_probe.reset_calls == 1, "score flow should reach the generic ball-reset callback once")
	_expect(stage_background.excitement_calls == 1, "accepted Stage 7 score should trigger the pillar excitement hook once")
	_expect_close(state.debug_get_gauge(), 280.0, "accepted score should carry 400 gauge to 280 exactly once")
	_expect(not state.is_gameplay_freeze_active(), "accepted score boundary should clear the Stage 7 gameplay freeze")
	_expect((state.get_actor_draw_context().get("stage7_akamu_clones", []) as Array).is_empty(), "accepted score boundary should clear Stage 7 transients")
	BallRoundActorCleanup.new().reset_actor_round_state({"stage7_akamu_state": state})
	_expect_close(state.debug_get_gauge(), 280.0, "a later generic cleanup must not decay the carried gauge again")


func _verify_state_freeze_advances_without_ticking_transients() -> void:
	var state: Object = Stage7AkamuState.new()
	var shuriken_payload := [{
		"position": Vector2(320.0, 180.0),
		"timer": 9.0,
	}]
	state.set("_shurikens", shuriken_payload.duplicate(true))
	state.debug_begin_gameplay_freeze(0.05)

	var before: Array = state.get_actor_draw_context().get("stage7_akamu_shurikens", [])
	state.update(1.0 / 60.0, _active_stage7_context())
	var after_context: Dictionary = state.get_actor_draw_context()
	var after: Array = after_context.get("stage7_akamu_shurikens", [])
	_expect(before == after, "awakening freeze should not advance existing Stage 7 projectiles")
	_expect_close(
		float(after_context.get("stage7_akamu_gameplay_freeze_remaining", 0.0)),
		0.05 - 1.0 / 60.0,
		"freeze owner should advance only its own intro clock"
	)

	for _tick in range(3):
		state.update(1.0 / 60.0, _active_stage7_context())
	_expect(not state.is_gameplay_freeze_active(), "freeze should finish once its timer is exhausted")
	_expect(
		state.get_actor_draw_context().get("stage7_akamu_shurikens", []) == shuriken_payload,
		"projectile payload should remain unchanged through the whole freeze"
	)


func _verify_frame_flow_freezes_motion_but_advances_stage_effects() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_begin_gameplay_freeze(0.05)
	state.set("_shurikens", [{"position": Vector2(320.0, 180.0), "timer": 9.0}])
	var frozen_projectiles: Array = state.get_actor_draw_context().get("stage7_akamu_shurikens", [])
	var probe := FlowProbe.new()
	probe.stage7_state = state

	BattleFrameFlowController.new().update(1.0 / 60.0, {
		"current_stage": 7,
		"stage7_akamu_state": state,
		"scoreboard_state": null,
		"skill_orb_tooltip_active": false,
		"power_state": null,
		"round_state": null,
		"mythic_item_runtime": null,
	}, _flow_callbacks(probe))

	_expect(
		probe.calls == ["queue_redraw"],
		"Stage 7 gameplay freeze should advance its owner directly, then only request redraw; got %s" % str(probe.calls)
	)
	for forbidden_callback in [
		"update_weather",
		"update_mythic_items",
		"update_player_control",
		"update_runtime_perk_resume",
		"update_active_items",
		"update_boss_ai",
		"update_ball",
		"update_lingpet",
		"update_effects",
	]:
		_expect(
			not probe.calls.has(forbidden_callback),
			"Stage 7 gameplay freeze must not call unrelated callback %s" % forbidden_callback
		)
	_expect_close(
		float(state.get_actor_draw_context().get("stage7_akamu_gameplay_freeze_remaining", 0.0)),
		0.05 - 1.0 / 60.0,
		"frame flow should advance the Stage 7 freeze exactly once"
	)
	_expect(
		state.get_actor_draw_context().get("stage7_akamu_shurikens", []) == frozen_projectiles,
		"frame-flow freeze should keep existing Stage 7 projectile state fixed"
	)

	var live_state: Object = Stage7AkamuState.new()
	var live_probe := FlowProbe.new()
	live_probe.stage7_state = live_state
	BattleFrameFlowController.new().update(1.0 / 60.0, {
		"current_stage": 7,
		"stage7_akamu_state": live_state,
		"scoreboard_state": null,
		"skill_orb_tooltip_active": false,
		"power_state": null,
		"round_state": null,
		"mythic_item_runtime": null,
	}, _flow_callbacks(live_probe))
	_expect(live_probe.calls.has("update_player_control"), "inactive Stage 7 freeze should allow player control")
	_expect(live_probe.calls.has("update_boss_ai"), "inactive Stage 7 freeze should allow boss AI")
	_expect(live_probe.calls.has("update_ball"), "inactive Stage 7 freeze should allow ball motion")


func _verify_stage7_router_and_catalog() -> void:
	var router: Object = StageRuntimeRouter.new()
	for role in STAGE7_ROUTE_EXPECTATIONS.keys():
		var expected_key: String = str(STAGE7_ROUTE_EXPECTATIONS[role])
		_expect(
			router.get_module_key(7, str(role)) == expected_key,
			"Stage 7 %s route should resolve to %s" % [str(role), expected_key]
		)

	var catalog: Object = GameplayStageModuleCatalog.new()
	for key in STAGE7_CATALOG_KEYS:
		var spec: Dictionary = catalog.get_spec(str(key))
		var path := str(spec.get("path", ""))
		_expect(path != "", "Stage 7 catalog should register %s" % str(key))
		_expect(FileAccess.file_exists(path), "Stage 7 catalog path should exist for %s: %s" % [str(key), path])


func _verify_stage7_dependency_surfaces() -> void:
	var state: Object = Stage7AkamuState.new()
	var background := RefCounted.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"stage_runtime_router": StageRuntimeRouter.new(),
		"stage7_akamu_state": state,
		"stage7_akamu_pillar_background": background,
		"weather_event_state": RefCounted.new(),
	}

	var stage_deps: Dictionary = StageRuntimeDepsBuilder.new().build_deps(registry, 7)
	_expect(stage_deps.get("stage7_akamu_state", null) == state, "scoped stage deps should include the Stage 7 owner")
	_expect(stage_deps.get("stage_background", null) == background, "scoped stage deps should route the Stage 7 background")

	registry.requested_keys.clear()
	registry.peeked_keys.clear()
	var all_stage_deps: Dictionary = StageRuntimeDepsBuilder.new().build_deps(registry, 1, true)
	_expect(all_stage_deps.get("stage7_akamu_state", null) == state, "include-all reset deps should retain an existing Stage 7 owner")
	_expect(registry.peeked_keys.has("stage7_akamu_state"), "include-all reset deps should peek the Stage 7 owner")
	_expect(not registry.requested_keys.has("stage7_akamu_state"), "include-all reset deps must not cold-instantiate Stage 7")

	var effects_deps: Dictionary = EffectsDepsBuilder.new().build_deps(registry, 7, "smasher")
	_expect(effects_deps.get("stage7_akamu_state", null) == state, "effects deps should include the Stage 7 owner")

	var ball_context := BallDependencyContext.new()
	var ball_update_deps: Dictionary = ball_context.build_update_deps(registry, {
		"current_stage": 7,
		"selected_character_type": "smasher",
	})
	_expect(ball_update_deps.get("stage7_akamu_state", null) == state, "ball update deps should include the Stage 7 collision owner")
	var ball_round_deps: Dictionary = ball_context.build_round_deps(registry, {
		"current_stage": 7,
		"selected_character_type": "smasher",
	})
	_expect(ball_round_deps.get("stage7_akamu_state", null) == state, "ball round deps should include the Stage 7 cleanup owner")
	_expect(
		BallDependencyContext.get_stage_round_dep_keys(7) == ["stage7_akamu_state"],
		"Stage 7 round dependency key list should contain only its state owner"
	)

	var frame_deps: Dictionary = FrameFlowDepsBuilder.new().build_deps(FakeOwner.new(), registry)
	_expect(frame_deps.get("stage7_akamu_state", null) == state, "frame-flow deps should include the Stage 7 freeze owner")
	_expect(int(frame_deps.get("current_stage", 0)) == 7, "frame-flow deps should preserve Stage 7")


func _verify_effects_controller_ticks_stage7_state() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_begin_gameplay_freeze(0.05)
	var context: Dictionary = _active_stage7_context()
	BattleEffectsUpdateController.new().update(1.0 / 60.0, context, {
		"stage7_akamu_state": state,
	})
	_expect_close(
		float(state.get_actor_draw_context().get("stage7_akamu_gameplay_freeze_remaining", 0.0)),
		0.05 - 1.0 / 60.0,
		"effects controller should tick the Stage 7 owner once per live frame"
	)


func _verify_boss_intangible_gate_precedes_paddle_detection() -> void:
	var stage_state := FakeStage7CollisionState.new()
	stage_state.intangible = true
	var bounce := FakePaddleBounceController.new()
	var scene := _boss_collision_scene()
	var processor: Object = BallMotionEventProcessor.new()
	var score_event: String = processor.step_motion(
		scene,
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"paddle_bounce_controller": bounce,
			"stage7_akamu_state": stage_state,
		},
		{}
	)
	_expect(score_event == "", "intangible boss overlap should not create a score event")
	_expect(bounce.calls == 0, "boss intangibility should suppress the paddle event before normal bounce handling")
	_expect(stage_state.boss_hit_calls == 0, "an intangible overlap must not notify the post-bounce Stage 7 hook")
	_expect((scene.get("ball_vel", Vector2.ZERO) as Vector2).y < 0.0, "intangible overlap should preserve the incoming upward velocity")


func _verify_post_bounce_hook_is_boss_paddle_only() -> void:
	var stage_state := FakeStage7CollisionState.new()
	var bounce := FakePaddleBounceController.new()
	var scene := _boss_collision_scene()
	var processor: Object = BallMotionEventProcessor.new()
	processor.step_motion(
		scene,
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"paddle_bounce_controller": bounce,
			"stage7_akamu_state": stage_state,
		},
		{}
	)
	_expect(bounce.calls == 1, "tangible Stage 7 boss contact should use the shared paddle bounce exactly once")
	_expect(stage_state.boss_hit_calls == 1, "normal boss reflection should notify the Stage 7 hook exactly once")
	_expect(
		bool(stage_state.seen_scene.get("normal_boss_bounce_committed", false)),
		"Stage 7 hook should observe the already-committed normal bounce result"
	)
	_expect(
		(stage_state.seen_scene.get("ball_vel", Vector2.ZERO) as Vector2).y > 0.0,
		"Stage 7 hook should receive outgoing downward velocity"
	)
	var empty_stage_state := FakeStage7CollisionState.new()
	var empty_bounce := FakePaddleBounceController.new()
	empty_bounce.return_empty = true
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"paddle_bounce_controller": empty_bounce,
			"stage7_akamu_state": empty_stage_state,
		},
		{}
	)
	_expect(empty_bounce.calls == 1, "empty-bounce guard should still attempt the shared controller")
	_expect(empty_stage_state.boss_hit_calls == 0, "Stage 7 hit hook must not run when the shared bounce produced no committed result")

	var wall_controller := FakeWallBounceController.new()
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": FakeWallMotionStepper.new(),
			"wall_bounce_controller": wall_controller,
			"stage7_akamu_state": stage_state,
		},
		{}
	)
	_expect(wall_controller.calls == 1, "wall control leg should process one real wall bounce")
	_expect(stage_state.boss_hit_calls == 1, "wall bounce must not call the Stage 7 boss-paddle hook")


func _verify_post_motion_collision_hook_is_wired() -> void:
	var stage_state := FakeStage7CollisionState.new()
	var controller: Object = BallUpdateController.new()
	controller._process_stage7_akamu_collision({}, {"current_stage": 7}, {
		"stage7_akamu_state": stage_state,
	})
	_expect(stage_state.post_collision_calls == 1, "Stage 7 post-motion collision helper should call the Akamu owner once")
	controller._process_stage7_akamu_collision({}, {"current_stage": 6}, {
		"stage7_akamu_state": stage_state,
	})
	_expect(stage_state.post_collision_calls == 1, "non-Stage 7 frames must not call the Akamu post-motion collision owner")
	var source := FileAccess.get_file_as_string("res://scripts/ball/ball_update_controller.gd")
	_expect(
		source.find("_process_stage7_akamu_collision(scene, frame_context, frame_deps)") >= 0,
		"live ball update flow should dispatch the Stage 7 post-motion collision helper"
	)


func _verify_stage7_boot_prewarm_dispatch() -> void:
	# 프리배틀 영상 스텝(5번째, 최우선)은 재생 lifecycle과 함께 프리배틀 완결
	# 슬라이스에서 복원한다 — 현재 계약은 렌더 모듈 4스텝.
	var background := FakePrewarmModule.new()
	var actor := FakePrewarmModule.new()
	var pillar := FakePillarPrewarmModule.new()
	var hud := FakePrewarmModule.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"stage7_akamu_pillar_background": background,
		"stage7_akamu_actor_renderer": actor,
		"stage7_akamu_pillar_scene_drawer": pillar,
		"stage7_akamu_boss_skill_hud_renderer": hud,
	}
	var controller: Object = BattleBootResourcePrewarmController.new()
	var step_count := int(controller._get_stage_specific_runtime_prewarm_step_count(FakeOwner.new(), 7))
	_expect(step_count == 4, "Stage 7 boot prewarm should expose four staged module steps (prebattle video step returns with its lifecycle slice)")
	for stage_step in range(step_count):
		_expect(
			bool(controller._run_stage7_runtime_prewarm_step(
				FakeOwner.new(), Callable(registry, "get_instance"), stage_step
			)),
			"Stage 7 boot prewarm step %d should complete" % stage_step
		)
	_expect(background.calls == 1, "Stage 7 boot prewarm should warm the pillar background")
	_expect(actor.calls == 1, "Stage 7 boot prewarm should warm the actor renderer")
	_expect(pillar.calls == 1 and pillar.character_type == "smasher", "Stage 7 boot prewarm should warm the pillar scene for the selected character")
	_expect(hud.calls == 1, "Stage 7 boot prewarm should warm the boss skill HUD")


func _verify_scripted_ai_position_bypasses_shared_postprocessors() -> void:
	var state: Object = Stage7AkamuState.new()
	var scripted_pos := Vector2(620.0, 25.0)
	state.debug_set_scripted_boss_position(true, scripted_pos)
	var registry := FakeRegistry.new()
	registry.instances = {
		"stage7_akamu_state": state,
	}
	var context: Dictionary = BossAIContextBuilder.new().build_context(FakeOwner.new(), registry)
	_expect(bool(context.get("stage7_akamu_boss_ai_frozen", false)), "Stage 7 AI context should expose scripted freeze")
	_expect(context.get("stage7_akamu_scripted_boss_pos", Vector2.ZERO) == scripted_pos, "Stage 7 AI context should expose the authored boss position")

	context.merge({
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 100.0,
		"active_item_molotov_fire_barriers": [{
			"center_x": 400.0,
			"center_y": 45.0,
		}],
		"lingpet_sand_prison_clamp_active": true,
		"lingpet_sand_prison_cage_left": 100.0,
		"lingpet_sand_prison_cage_right": 300.0,
	}, true)
	var result: Dictionary = BossAIState.new().update(1.0 / 60.0, Vector2(100.0, 25.0), 9.0, context)
	_expect(result.get("boss_pos", Vector2.ZERO) == scripted_pos, "scripted Stage 7 position should bypass molotov and sand-prison postprocessors")
	_expect_close(float(result.get("boss_vel", 99.0)), 0.0, "scripted Stage 7 motion should zero boss velocity")

	state.debug_set_scripted_boss_position(false)
	state.debug_begin_gameplay_freeze(0.1)
	context = BossAIContextBuilder.new().build_context(FakeOwner.new(), registry)
	var held_pos := Vector2(330.0, 25.0)
	result = BossAIState.new().update(1.0 / 60.0, held_pos, 7.0, context)
	_expect(result.get("boss_pos", Vector2.ZERO) == held_pos, "gameplay freeze without scripted motion should hold the live boss position")
	_expect_close(float(result.get("boss_vel", 99.0)), 0.0, "gameplay freeze should stop boss velocity")


func _verify_overdrive_reflection_requires_committed_bounce() -> void:
	# 코덱스 봉인: 오버드라이브 반사 통지는 "실제 커밋된 반사"에서만 나가야
	# 한다 — 무형화 무시·빈 bounce 결과에서 가짜 통지가 나가면 RED.
	var committed_overdrive := FakeOverdriveState.new()
	var processor: Object = BallMotionEventProcessor.new()
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"paddle_bounce_controller": FakePaddleBounceController.new(),
			"stage7_akamu_state": FakeStage7CollisionState.new(),
			"smasher_overdrive_state": committed_overdrive,
		},
		{}
	)
	_expect(committed_overdrive.reflect_calls == 1, "committed boss bounce should notify overdrive reflection exactly once")

	var intangible_overdrive := FakeOverdriveState.new()
	var intangible_state := FakeStage7CollisionState.new()
	intangible_state.intangible = true
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"paddle_bounce_controller": FakePaddleBounceController.new(),
			"stage7_akamu_state": intangible_state,
			"smasher_overdrive_state": intangible_overdrive,
		},
		{}
	)
	_expect(intangible_overdrive.reflect_calls == 0, "intangible boss overlap must not fake an overdrive reflection")

	var empty_overdrive := FakeOverdriveState.new()
	var empty_bounce := FakePaddleBounceController.new()
	empty_bounce.return_empty = true
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"paddle_bounce_controller": empty_bounce,
			"stage7_akamu_state": FakeStage7CollisionState.new(),
			"smasher_overdrive_state": empty_overdrive,
		},
		{}
	)
	_expect(empty_overdrive.reflect_calls == 0, "empty bounce result must not fake an overdrive reflection")

	var uncommitted_overdrive := FakeOverdriveState.new()
	var uncommitted_state := FakeStage7CollisionState.new()
	var uncommitted_bounce := FakePaddleBounceController.new()
	uncommitted_bounce.return_uncommitted = true
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"paddle_bounce_controller": uncommitted_bounce,
			"stage7_akamu_state": uncommitted_state,
			"smasher_overdrive_state": uncommitted_overdrive,
		},
		{}
	)
	_expect(uncommitted_overdrive.reflect_calls == 0, "non-empty but uncommitted bounce result must not fake an overdrive reflection")
	_expect(uncommitted_state.boss_hit_calls == 0, "non-empty but uncommitted bounce result must not fire the Stage 7 boss hook")

	var player_overdrive := FakeOverdriveState.new()
	var player_bounce := FakePaddleBounceController.new()
	player_bounce.return_uncommitted = true
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": FakePlayerPaddleMotionStepper.new(),
			"paddle_bounce_controller": player_bounce,
			"stage7_akamu_state": FakeStage7CollisionState.new(),
			"smasher_overdrive_state": player_overdrive,
		},
		{}
	)
	_expect(
		player_overdrive.reflect_calls == 1,
		"committed player-paddle bounce should notify overdrive even without the boss-commit flag"
	)

	var no_controller_overdrive := FakeOverdriveState.new()
	processor.step_motion(
		_boss_collision_scene(),
		1.0,
		_boss_collision_context(),
		{
			"motion_stepper": BallMotionStepper.new(),
			"smasher_overdrive_state": no_controller_overdrive,
		},
		{}
	)
	_expect(no_controller_overdrive.reflect_calls == 0, "missing bounce controller must not fake an overdrive reflection")


func _verify_result_reset_reaches_stage7_owner() -> void:
	# 코덱스 봉인: 결과화면 정리 fanout이 stage7 오너의 reset_for_result에
	# 실제로 도달하고, 타 스테이지 id에서는 도달하지 않아야 한다.
	var fake_state := FakeResultStage7State.new()
	var registry := FakeRegistry.new()
	registry.instances["stage7_akamu_state"] = fake_state
	StageClearResultRuntimeContextData.reset_stage7_for_result(registry, 6)
	_expect(fake_state.reset_for_result_calls == 0, "non-stage7 result must not reset the Akamu owner")
	StageClearResultRuntimeContextData.reset_stage_for_result(registry, 7)
	_expect(fake_state.reset_for_result_calls == 1, "stage7 result fanout should reset the Akamu owner exactly once")

	var real_state: Object = Stage7AkamuState.new()
	real_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	real_state.reset_for_result()
	var post_reset_hit: bool = real_state.resolve_ball_collision({
		"previous_ball_pos": Vector2(380.0, 310.0),
		"ball_pos": Vector2(380.0, 130.0),
		"ball_vel": Vector2(0.0, -12.0),
	}, _active_stage7_context(), {})
	_expect(not post_reset_hit, "reset_for_result should clear live clones so no collision survives into the result screen")


func _boss_collision_scene() -> Dictionary:
	return {
		"ball_pos": Vector2(380.0, 80.0),
		"ball_vel": Vector2(0.0, -20.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}


func _boss_collision_context() -> Dictionary:
	return {
		"current_stage": 7,
		"selected_character_type": "smasher",
		"ball_size": 20.0,
		"width": 760.0,
		"height": 750.0,
		"max_step_distance": 12.0,
		"hitbox_padding": 5.0,
		"player_pos": Vector2(300.0, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}


func _flow_callbacks(probe: FlowProbe) -> Dictionary:
	return {
		"update_weather": Callable(probe, "update_weather"),
		"update_mythic_items": Callable(probe, "update_mythic_items"),
		"update_player_control": Callable(probe, "update_player_control"),
		"update_runtime_perk_resume": Callable(probe, "update_runtime_perk_resume"),
		"update_active_items": Callable(probe, "update_active_items"),
		"update_boss_ai": Callable(probe, "update_boss_ai"),
		"update_ball": Callable(probe, "update_ball"),
		"update_lingpet": Callable(probe, "update_lingpet"),
		"update_effects": Callable(probe, "update_effects"),
		"queue_redraw": Callable(probe, "queue_redraw"),
	}


func _active_stage7_context() -> Dictionary:
	return {
		"current_stage": 7,
		"selected_character_type": "smasher",
		"ball_active": true,
		"waiting_for_serve": false,
	}


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (expected %.5f, got %.5f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
