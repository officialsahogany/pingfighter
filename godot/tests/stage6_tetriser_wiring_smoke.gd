extends SceneTree

const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")
const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const BattleDrawContext := preload("res://scripts/core/battle_draw_context.gd")
const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const BattleUpdateEffectsDepsBuilder := preload("res://scripts/core/battle_update_effects_deps_builder.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")
const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")
const Stage6TetriserState := preload("res://scripts/stages/stage6/stage6_tetriser_state.gd")

var _failures: Array[String] = []


class FakeStageRouter:
	extends RefCounted

	func get_module_key(stage: int, role: String) -> String:
		if role == "stage_background" and stage == 6:
			return "stage6_tetriser_pillar_background"
		return ""


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func _init() -> void:
		instances["stage_runtime_router"] = FakeStageRouter.new()
		instances["stage6_tetriser_pillar_background"] = RefCounted.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)


class FakeStatusEffectState:
	extends RefCounted

	var calls: Array = []

	func update(_fps_scale: float, _context: Dictionary, _deps: Dictionary) -> void:
		pass

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		calls.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data,
			"source": source,
		})
		return {}


class FakeMovementState:
	extends RefCounted

	var calls: Array = []

	func start_knockback(velocity: float, frames: float, decay: float, interrupt_dash: bool = false, stun_locked: bool = false) -> void:
		calls.append({
			"velocity": velocity,
			"frames": frames,
			"decay": decay,
			"interrupt_dash": interrupt_dash,
			"stun_locked": stun_locked,
		})


class FakeCleanseState:
	extends RefCounted

	var immune := false

	func is_immune() -> bool:
		return immune


class FakeMythicItemRuntime:
	extends RefCounted

	var should_consume_celestial_armor := false
	var calls: Array = []

	func try_consume_celestial_armor_immunity(source: String, effect_type: String, deps: Dictionary) -> bool:
		calls.append({
			"source": source,
			"effect_type": effect_type,
			"context": deps.get("context", {}),
		})
		return should_consume_celestial_armor


class FakeScoreState:
	extends RefCounted

	var player_score := 0
	var boss_score := 0

	func get_snapshot() -> Dictionary:
		return {
			"player_score": player_score,
			"boss_score": boss_score,
			"win_goal": 5,
			"deuce_goal": 6,
			"deuce_mode": false,
		}

	func score_for(scoring_side: String) -> Dictionary:
		if scoring_side == "player":
			player_score += 1
		elif scoring_side == "boss":
			boss_score += 1
		return {
			"player_score": player_score,
			"boss_score": boss_score,
			"match_finished": false,
			"win_goal": 5,
			"next_player_serves": scoring_side == "boss",
		}


class FakeBallIntensity:
	extends RefCounted

	var rally_count := 0
	var last_hit_by := ""

	func _init(new_rally_count: int = 0, new_last_hit_by: String = "") -> void:
		rally_count = new_rally_count
		last_hit_by = new_last_hit_by

	func get_rally_count() -> int:
		return rally_count

	func get_last_hit_by() -> String:
		return last_hit_by


class FakePowerState:
	extends RefCounted

	var parabola_active := false

	func _init(new_parabola_active: bool = false) -> void:
		parabola_active = new_parabola_active

	func is_freeze_active() -> bool:
		return false

	func is_parabola_active() -> bool:
		return parabola_active


class FakeRuntimePerkState:
	extends RefCounted

	var calls: Array = []
	var expected_catalog: Object = null
	var expected_owner: Object = null

	func collect_star_points(amount: int, character_type: String, runtime_perk_catalog: Object, owner: Object, registry: Object) -> bool:
		calls.append({
			"amount": amount,
			"character_type": character_type,
			"catalog_matches": runtime_perk_catalog == expected_catalog,
			"owner_matches": owner == expected_owner,
			"registry_owns_runtime_state": registry != null and registry.has_method("get_instance") and registry.get_instance("runtime_perk_state") == self,
		})
		return true


class FakeOwner:
	extends RefCounted

	var redraws := 0

	func queue_redraw() -> void:
		redraws += 1


func _init() -> void:
	_verify_stage6_ball_update_deps_drive_tetriser_collision()
	_verify_stage6_live_boss_serve_penetrates_from_ball_intensity()
	_verify_stage6_live_post_rally_collides_from_ball_intensity()
	_verify_stage6_live_power_smash_reaches_tetriser()
	_verify_stage6_effect_deps_feed_immunity_gate()
	_verify_stage6_starpoint_collect_uses_live_effect_deps()
	_verify_stage6_draw_deps_feed_actor_context()
	_verify_stage6_round_deps_feed_round_cleanup()
	_verify_stage6_score_boundary_clears_round_state()
	_verify_stage6_full_and_result_resets_clear_match_state()

	if _failures.is_empty():
		print("stage6_tetriser_wiring_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage6_ball_update_deps_drive_tetriser_collision() -> void:
	var state: Object = Stage6TetriserState.new()
	var registry := FakeRegistry.new()
	registry.instances["stage6_tetriser_state"] = state

	var deps: Dictionary = BallDependencyContext.new().build_update_deps(registry, {
		"selected_character_type": "smasher",
		"current_stage": 6,
	})
	_expect(deps.get("stage6_tetriser_state", null) == state, "Stage 6 ball update deps should include Tetriser state")

	var legacy_deps: Dictionary = BallDependencyContext.new().build_update_deps(registry)
	_expect(legacy_deps.get("stage6_tetriser_state", null) == state, "legacy ball update deps should include Tetriser state")

	state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", false)
	var scene := {
		"ball_pos": Vector2(310.0, 305.0),
		"previous_ball_pos": Vector2(310.0, 280.0),
		"ball_vel": Vector2(0.0, 8.0),
	}
	BallUpdateController.new()._process_stage6_tetromino_collision(
		scene,
		{"current_stage": 6, "ball_size": 20.0},
		deps
	)
	_expect(state.debug_get_tetromino_count() == 0, "ball controller should destroy a Stage 6 tetromino through built deps")
	_expect((scene.get("ball_vel", Vector2.ZERO) as Vector2).y < 0.0, "ball controller should reflect the ball off a Stage 6 tetromino")


func _verify_stage6_live_boss_serve_penetrates_from_ball_intensity() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", false)
	var deps := _stage6_live_ball_deps(state, FakeBallIntensity.new(0, "boss"))
	var result: Dictionary = BallUpdateController.new().update(0.0, _stage6_live_ball_context(), deps)
	_expect(not result.is_empty(), "live ball update should produce a snapshot for the Stage 6 serve-penetration smoke")
	_expect(state.debug_get_tetromino_count() == 1, "live boss serve should penetrate Stage 6 tetrominoes through ball_intensity context")
	if result.has("snapshot"):
		var snapshot: Dictionary = result["snapshot"]
		_expect((snapshot.get("ball_vel", Vector2.ZERO) as Vector2) == Vector2(0.0, 8.0), "live boss serve penetration should not reflect the ball")


func _verify_stage6_live_post_rally_collides_from_ball_intensity() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", false)
	var deps := _stage6_live_ball_deps(state, FakeBallIntensity.new(1, "player"))
	BallUpdateController.new().update(0.0, _stage6_live_ball_context(), deps)
	_expect(state.debug_get_tetromino_count() == 0, "live post-rally ball should collide with and destroy Stage 6 tetrominoes")


func _verify_stage6_live_power_smash_reaches_tetriser() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", true)
	var deps := _stage6_live_ball_deps(state, FakeBallIntensity.new(1, "player"), FakePowerState.new(true))
	var result: Dictionary = BallUpdateController.new().update(0.0, _stage6_live_ball_context(), deps)
	_expect(state.debug_get_tetromino_count() == 0, "live power smash should destroy even super Stage 6 tetrominoes")
	if result.has("snapshot"):
		var snapshot: Dictionary = result["snapshot"]
		_expect((snapshot.get("ball_vel", Vector2.ZERO) as Vector2) == Vector2(0.0, 8.0), "live power smash tetromino hit should not reflect the ball")


func _verify_stage6_effect_deps_feed_immunity_gate() -> void:
	var cleanse_state := Stage6TetriserState.new()
	var cleanse_status := FakeStatusEffectState.new()
	var cleanse_movement := FakeMovementState.new()
	var cleanse_immunity := FakeCleanseState.new()
	cleanse_immunity.immune = true
	var cleanse_mythic := FakeMythicItemRuntime.new()
	var cleanse_registry := FakeRegistry.new()
	cleanse_registry.instances["stage6_tetriser_state"] = cleanse_state
	cleanse_registry.instances["status_effect_state"] = cleanse_status
	cleanse_registry.instances["player_movement_state"] = cleanse_movement
	cleanse_registry.instances["smasher_cleanse_state"] = cleanse_immunity
	cleanse_registry.instances["mythic_item_runtime"] = cleanse_mythic

	var cleanse_deps: Dictionary = BattleUpdateEffectsDepsBuilder.new().build_deps(cleanse_registry, 6, "smasher")
	_expect(cleanse_deps.get("stage6_tetriser_state", null) == cleanse_state, "Stage 6 effects deps should include Tetriser state")
	_expect(cleanse_deps.get("status_effect_state", null) == cleanse_status, "Stage 6 effects deps should include status state")
	_expect(cleanse_deps.get("movement_state", null) == cleanse_movement, "Stage 6 effects deps should include movement state")
	_expect(cleanse_deps.get("smasher_cleanse_state", null) == cleanse_immunity, "Stage 6 effects deps should include Smasher cleanse state")
	_expect(cleanse_deps.get("mythic_item_runtime", null) == cleanse_mythic, "Stage 6 effects deps should include mythic runtime")
	_expect(cleanse_deps.get("registry", null) == cleanse_registry, "Stage 6 effects deps should include the registry fallback")

	cleanse_state.debug_spawn_tetromino_at(Vector2(300.0, 690.0), "O", true)
	_advance_effects(0.110, _explosion_context(), cleanse_deps)
	_expect(cleanse_state.debug_get_tetromino_count() == 0, "effects controller should drive the Stage 6 landing explosion")
	_expect(cleanse_status.calls.is_empty(), "live effects deps should let cleanse immunity block explosion stun")
	_expect(cleanse_movement.calls.is_empty(), "live effects deps should let cleanse immunity block explosion knockback")
	_expect(cleanse_mythic.calls.is_empty(), "cleanse immunity should short-circuit mythic consumption on the live effects path")

	var mythic_state := Stage6TetriserState.new()
	var mythic_status := FakeStatusEffectState.new()
	var mythic_movement := FakeMovementState.new()
	var mythic_runtime := FakeMythicItemRuntime.new()
	mythic_runtime.should_consume_celestial_armor = true
	var mythic_registry := FakeRegistry.new()
	mythic_registry.instances["stage6_tetriser_state"] = mythic_state
	mythic_registry.instances["status_effect_state"] = mythic_status
	mythic_registry.instances["player_movement_state"] = mythic_movement
	mythic_registry.instances["mythic_item_runtime"] = mythic_runtime

	var mythic_deps: Dictionary = BattleUpdateEffectsDepsBuilder.new().build_deps(mythic_registry, 6, "smasher")
	_expect(mythic_deps.get("mythic_item_runtime", null) == mythic_runtime, "Stage 6 effects deps should carry Celestial Armor runtime")
	mythic_state.debug_spawn_tetromino_at(Vector2(300.0, 690.0), "O", true)
	_advance_effects(0.110, _explosion_context(), mythic_deps)
	_expect(mythic_status.calls.is_empty(), "live effects deps should let Celestial Armor block explosion stun")
	_expect(mythic_movement.calls.is_empty(), "live effects deps should let Celestial Armor block explosion knockback")
	_expect(mythic_runtime.calls.size() == 1, "Stage 6 live explosion should ask Celestial Armor to consume once")
	if mythic_runtime.calls.size() == 1:
		var call: Dictionary = mythic_runtime.calls[0]
		_expect(str(call.get("source", "")) == "stage6_tetro_explosion", "Stage 6 live explosion should identify its Celestial Armor source")
		_expect(str(call.get("effect_type", "")) == "stun", "Stage 6 live explosion should consume Celestial Armor with the stun key")


func _verify_stage6_starpoint_collect_uses_live_effect_deps() -> void:
	var state := Stage6TetriserState.new()
	state.debug_spawn_starpoint_drop_at(Vector2(380.0, 705.0))
	var runtime_state := FakeRuntimePerkState.new()
	var runtime_catalog := RefCounted.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	runtime_state.expected_catalog = runtime_catalog
	runtime_state.expected_owner = owner
	registry.instances["stage6_tetriser_state"] = state
	registry.instances["runtime_perk_state"] = runtime_state
	registry.instances["runtime_perk_catalog"] = runtime_catalog

	var deps: Dictionary = BattleUpdateEffectsDepsBuilder.new().build_deps(registry, 6, "smasher")
	_expect(deps.get("stage6_tetriser_state", null) == state, "Stage 6 effects deps should include Tetriser state for starpoint collection")
	_expect(deps.get("runtime_perk_state", null) == runtime_state, "Stage 6 effects deps should include runtime perk state for starpoint collection")
	_expect(deps.get("runtime_perk_catalog", null) == runtime_catalog, "Stage 6 effects deps should include runtime perk catalog for starpoint collection")
	_expect(deps.get("registry", null) == registry, "Stage 6 effects deps should include registry fallback for starpoint collection")

	var context := _explosion_context()
	context["owner"] = owner
	context["registry"] = registry
	context["player_pos"] = Vector2(350.0, 690.0)
	context["player_paddle_size"] = Vector2(70.0, 40.0)
	_advance_effects(0.016, context, deps)
	_expect(state.debug_get_starpoint_drop_count() == 0, "live effects path should collect overlapping Stage 6 starpoint drops")
	_expect(runtime_state.calls.size() == 1, "live Stage 6 starpoint collection should call runtime perk state once")
	if runtime_state.calls.size() == 1:
		var call: Dictionary = runtime_state.calls[0]
		_expect(int(call.get("amount", 0)) == 1, "live Stage 6 starpoint collection should grant exactly one star")
		_expect(bool(call.get("catalog_matches", false)), "live Stage 6 starpoint collection should forward catalog from deps builder")
		_expect(bool(call.get("owner_matches", false)), "live Stage 6 starpoint collection should forward owner from context")
		_expect(bool(call.get("registry_owns_runtime_state", false)), "live Stage 6 starpoint collection should forward the live registry from deps builder/context")
	_expect(owner.redraws == 1, "live Stage 6 starpoint collection should request owner redraw")


func _verify_stage6_draw_deps_feed_actor_context() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", false)
	state.debug_spawn_guard_at(Vector2(300.0, 100.0), "left")
	state.debug_force_spawn_wall()
	for _i in range(12):
		state.update(0.1, {"current_stage": 6, "ball_active": true, "waiting_for_serve": false})
	state.debug_spawn_starpoint_drop_at(Vector2(380.0, 375.0))
	var registry := FakeRegistry.new()
	registry.instances["stage6_tetriser_state"] = state

	var draw_context_builder := BattleDrawContext.new()
	var context := {
		"current_stage": 6,
		"selected_character_type": "smasher",
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(60.0, 30.0),
		"boss_pos": Vector2(330.0, 30.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
	}
	var draw_deps: Dictionary = draw_context_builder.build_scene_deps(registry, null, null, context)
	_expect(draw_deps.get("stage6_tetriser_state", null) == state, "Stage 6 draw deps should include Tetriser state")
	var actor_context: Dictionary = draw_context_builder.build_actor_context(context, draw_deps)
	_expect((actor_context.get("stage6_tetriser_tetrominoes", []) as Array).size() == 1, "Stage 6 actor draw context should expose tetrominoes")
	_expect((actor_context.get("stage6_tetriser_guard_blocks", []) as Array).size() == 1, "Stage 6 actor draw context should expose guard blocks")
	_expect((actor_context.get("stage6_tetriser_wall_cells", []) as Array).size() > 0, "Stage 6 actor draw context should expose wall cells")
	_expect(not (actor_context.get("stage6_tetriser_cube", {}) as Dictionary).is_empty(), "Stage 6 actor draw context should expose the center cube")
	_expect((actor_context.get("stage6_tetriser_starpoint_drops", []) as Array).size() == 1, "Stage 6 actor draw context should expose starpoint drops")

	var full_draw_deps: Dictionary = draw_context_builder.build_scene_deps(registry, null, null)
	_expect(full_draw_deps.get("stage6_tetriser_state", null) == state, "full draw deps should include Stage 6 Tetriser state")


func _verify_stage6_round_deps_feed_round_cleanup() -> void:
	var state: Object = Stage6TetriserState.new()
	var registry := FakeRegistry.new()
	registry.instances["stage6_tetriser_state"] = state

	var deps: Dictionary = BallDependencyContext.new().build_round_deps(registry, {
		"selected_character_type": "smasher",
		"current_stage": 6,
	})
	_expect(deps.get("stage6_tetriser_state", null) == state, "Stage 6 round deps should include Tetriser state")
	var legacy_deps: Dictionary = BallDependencyContext.new().build_round_deps(registry)
	_expect(legacy_deps.get("stage6_tetriser_state", null) == state, "legacy round deps should include Tetriser state")

	state.debug_set_gauge(240.0)
	state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", false)
	state.debug_start_crystal_shield(Vector2(380.0, 75.0), true)
	BallRoundActorCleanup.new().reset_actor_round_state({"stage6_tetriser_state": state})
	_expect(state.debug_get_tetromino_count() == 0, "round actor cleanup should clear Stage 6 tetrominoes")
	_expect(is_equal_approx(state.debug_get_gauge(), 240.0), "round actor cleanup should preserve Stage 6 gauge")
	_expect(state.debug_is_crystal_shield_active(), "round actor cleanup should preserve active Stage 6 crystal shield")
	_expect(state.debug_get_crystal_shield_block_count() == 24, "round actor cleanup should preserve crystal shield blocks")


func _verify_stage6_score_boundary_clears_round_state() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_set_gauge(180.0)
	state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", false)
	state.debug_start_crystal_shield(Vector2(380.0, 75.0), true)

	MatchScoreEventController.new().handle_score_event("player", {
		"current_stage": 6,
		"score_state": FakeScoreState.new(),
		"stage6_tetriser_state": state,
	}, {})
	_expect(state.debug_get_tetromino_count() == 0, "score boundary should clear Stage 6 tetrominoes")
	_expect(is_equal_approx(state.debug_get_gauge(), 180.0), "score boundary should preserve Stage 6 gauge")
	_expect(state.debug_is_crystal_shield_active(), "score boundary should preserve active Stage 6 crystal shield")
	_expect(state.debug_get_crystal_shield_block_count() == 24, "score boundary should preserve crystal shield blocks")


func _verify_stage6_full_and_result_resets_clear_match_state() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_set_gauge(210.0)
	state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", false)
	state.debug_start_crystal_shield(Vector2(380.0, 75.0), true)
	MatchResetController.new().reset_stage_state({"stage6_tetriser_state": state})
	_expect(state.debug_get_tetromino_count() == 0, "full stage reset should clear Stage 6 tetrominoes")
	_expect(state.debug_get_gauge() == 0.0, "full stage reset should clear Stage 6 gauge")
	_expect(not state.debug_is_crystal_shield_active(), "full stage reset should clear Stage 6 crystal shield")
	_expect(state.debug_get_crystal_shield_block_count() == 0, "full stage reset should remove crystal shield blocks")

	state.debug_set_gauge(210.0)
	state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", false)
	state.debug_start_crystal_shield(Vector2(380.0, 75.0), true)
	var registry := FakeRegistry.new()
	registry.instances["stage6_tetriser_state"] = state
	StageClearResultScreen.new()._reset_stage6_for_result(registry, 6)
	_expect(state.debug_get_tetromino_count() == 0, "stage-clear result reset should clear Stage 6 tetrominoes")
	_expect(state.debug_get_gauge() == 0.0, "stage-clear result reset should clear Stage 6 gauge")
	_expect(not state.debug_is_crystal_shield_active(), "stage-clear result reset should clear Stage 6 crystal shield")
	_expect(state.debug_get_crystal_shield_block_count() == 0, "stage-clear result reset should remove crystal shield blocks")


func _advance_effects(seconds: float, context: Dictionary, deps: Dictionary) -> void:
	var controller := BattleEffectsUpdateController.new()
	var remaining: float = seconds
	while remaining > 0.0001:
		var step: float = minf(0.100, remaining)
		controller.update(step, context, deps)
		remaining -= step


func _explosion_context() -> Dictionary:
	return {
		"current_stage": 6,
		"selected_character_type": "smasher",
		"ball_active": true,
		"waiting_for_serve": false,
		"player_pos": Vector2(302.0, 700.0),
		"player_paddle_size": Vector2(60.0, 30.0),
	}


func _stage6_live_ball_context() -> Dictionary:
	return {
		"current_stage": 6,
		"selected_character_type": "smasher",
		"ball_active": true,
		"ball_size": 20.0,
		"ball_pos": Vector2(310.0, 305.0),
		"ball_pos_prev": Vector2(310.0, 280.0),
		"ball_vel": Vector2(0.0, 8.0),
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(60.0, 30.0),
		"boss_pos": Vector2(330.0, 30.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
	}


func _stage6_live_ball_deps(state: Object, ball_intensity: Object, power_state: Object = null) -> Dictionary:
	var registry := FakeRegistry.new()
	registry.instances["stage6_tetriser_state"] = state
	registry.instances["ball_intensity"] = ball_intensity
	if power_state != null:
		registry.instances["smasher_power_smash_state"] = power_state
	var deps: Dictionary = BallDependencyContext.new().build_update_deps(registry, {
		"selected_character_type": "smasher",
		"current_stage": 6,
	})
	_expect(deps.get("stage6_tetriser_state", null) == state, "live Stage 6 update deps should include Tetriser state")
	_expect(deps.get("ball_intensity", null) == ball_intensity, "live Stage 6 update deps should include ball intensity")
	if power_state != null:
		_expect(deps.get("power_state", null) == power_state, "live Stage 6 update deps should include power smash state")
	return deps


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
