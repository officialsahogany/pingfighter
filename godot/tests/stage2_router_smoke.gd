extends SceneTree

const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const BattleDrawPillarContext := preload("res://scripts/core/battle_draw_pillar_context.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")
const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const PaddleBounceBossPostHitHandler := preload("res://scripts/ball/paddle_bounce_boss_post_hit_handler.gd")
const PaddleBouncePlayerPostHitHandler := preload("res://scripts/ball/paddle_bounce_player_post_hit_handler.gd")


class FakeAudio:
	var hydro_count := 0
	var stonebreak_count := 0
	var rockhit_count := 0
	var rock_spawn_count := 0
	var quake_start_count := 0
	var quake_stop_count := 0
	var boss_cry_count := 0
	var banana_throw_count := 0
	var banana_slip_count := 0

	func update(_delta: float) -> void:
		pass

	func play_stage2_hydro() -> void:
		hydro_count += 1

	func play_stage2_stonebreak() -> void:
		stonebreak_count += 1

	func play_stage2_rockhit() -> void:
		rockhit_count += 1

	func play_stage2_rock_spawn() -> void:
		rock_spawn_count += 1

	func play_stage2_quake_loop() -> void:
		quake_start_count += 1

	func stop_stage2_quake_loop() -> void:
		quake_stop_count += 1

	func play_stage2_boss_cry() -> void:
		boss_cry_count += 1

	func play_banana_throw() -> void:
		banana_throw_count += 1

	func play_banana_slip() -> void:
		banana_slip_count += 1


class FakeMovementState:
	var knockback_count := 0
	var last_velocity := 0.0

	func start_knockback(velocity: float, _frames: float = 18.0, _decay: float = 0.92, _replace: bool = false) -> bool:
		knockback_count += 1
		last_velocity = velocity
		return true


class FakeFeedback:
	var shake_count := 0
	var fixed_offset_count := 0
	var last_fixed_offset := Vector2.ZERO

	func reset_round(_dash_token_max: int) -> void:
		pass

	func max_screen_shake(_amount: float, _duration: float) -> void:
		shake_count += 1

	func push_fixed_shake_offset(offset: Vector2) -> void:
		fixed_offset_count += 1
		last_fixed_offset = offset


class FakeBallIntensity:
	var last_hit_by := "boss"

	func get_last_hit_by() -> String:
		return last_hit_by


func _init() -> void:
	var registry: Object = GameplayModuleRegistry.new()
	var router: Object = registry.get_instance("stage_runtime_router")
	_expect(router != null, "stage runtime router should load from the stage catalog")
	_expect(
		str(router.get_module_key(2, "actor_renderer")) == "stage2_actor_renderer",
		"stage 2 should route actor drawing to the Stage 2 actor renderer"
	)
	_expect(
		str(router.get_module_key(2, "pillar_scene_drawer")) == "stage2_pillar_scene_drawer",
		"stage 2 should route pillar drawing to the Stage 2 pillar scene drawer"
	)
	_expect(
		str(router.get_module_key(2, "stage_background")) == "stage2_pillar_background",
		"stage 2 should route stage background state to the Stage 2 pillar background"
	)

	var actor_renderer: Object = registry.get_instance("stage2_actor_renderer")
	_expect(actor_renderer != null and actor_renderer.has_method("draw"), "stage2 actor renderer should be constructible")
	var pillar_scene_drawer: Object = registry.get_instance("stage2_pillar_scene_drawer")
	_expect(
		pillar_scene_drawer != null and pillar_scene_drawer.has_method("draw_post_playfield_hud"),
		"stage2 pillar scene drawer should expose the post-playfield HUD pass"
	)
	var stage2_hud_renderer: Object = registry.get_instance("stage2_boss_skill_hud_renderer")
	_expect(stage2_hud_renderer != null and stage2_hud_renderer.has_method("draw"), "Stage 2 boss skill HUD renderer should be constructible")

	var pillar_context: Object = BattleDrawPillarContext.new()
	var pillar_states: Dictionary = pillar_context.build_scene_states(registry, 2)
	_expect(
		pillar_states.get("stage_background", null) == registry.get_instance("stage2_pillar_background"),
		"pillar draw states should use the Stage 2 background when current_stage is 2"
	)

	var effects_context: Object = BattleUpdateEffectsContext.new()
	var effects_deps: Dictionary = effects_context.build_deps(registry, 2)
	_expect(
		effects_deps.get("stage_background", null) == registry.get_instance("stage2_pillar_background"),
		"effects deps should use the Stage 2 background when current_stage is 2"
	)
	_expect(
		effects_deps.get("stage2_boss_skill_state", null) == registry.get_instance("stage2_boss_skill_state"),
		"effects deps should include the Stage 2 boss skill scheduler"
	)
	var monkey_event: Object = registry.get_instance("stage2_monkey_banana_event")
	_expect(monkey_event != null and monkey_event.has_method("update"), "Stage 2 monkey banana event should be constructible")
	_expect(
		effects_deps.get("stage2_monkey_banana_event", null) == monkey_event,
		"effects deps should include the Stage 2 monkey banana event"
	)
	monkey_event.sync_layout({
		"view_size": Vector2(1488.0, 918.0),
		"game_offset": Vector2(364.0, 84.0),
		"game_size": Vector2(760.0, 750.0),
	})
	var monkey_snapshot: Dictionary = monkey_event.get_debug_snapshot()
	_expect(abs(float(monkey_snapshot.get("first_event_min", 0.0)) - 5.0) <= 0.001, "Stage 2 monkey first spawn minimum should match the original")
	_expect(abs(float(monkey_snapshot.get("first_event_max", 0.0)) - 10.0) <= 0.001, "Stage 2 monkey first spawn maximum should match the original")
	_expect(abs(float(monkey_snapshot.get("repeat_event_min", 0.0)) - 15.0) <= 0.001, "Stage 2 monkey repeat spawn minimum should match the original")
	_expect(abs(float(monkey_snapshot.get("repeat_event_max", 0.0)) - 30.0) <= 0.001, "Stage 2 monkey repeat spawn maximum should match the original")
	_expect(abs(float(monkey_snapshot.get("player_target_probability", 0.0)) - 0.4) <= 0.001, "Stage 2 monkey bananas should target the player 40 percent of the time")
	_expect(abs(float(monkey_snapshot.get("boss_target_probability", 0.0)) - 0.6) <= 0.001, "Stage 2 monkey bananas should target the boss 60 percent of the time")
	_expect(abs(float(monkey_snapshot.get("throw_delay_min", 0.0)) - 1.5) <= 0.001, "Stage 2 monkey throw delay minimum should match the original")
	_expect(abs(float(monkey_snapshot.get("throw_delay_max", 0.0)) - 3.0) <= 0.001, "Stage 2 monkey throw delay maximum should match the original")
	var monkey_audio := FakeAudio.new()
	var monkey_context := {
		"current_stage": 2,
		"width": 760.0,
		"height": 750.0,
		"view_size": Vector2(1488.0, 918.0),
		"game_offset": Vector2(364.0, 84.0),
		"game_size": Vector2(760.0, 750.0),
		"player_pos": Vector2(280.0, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"dash_snapshot": {"active": false, "direction": 0},
		"boss_pos": Vector2(320.0, 25.0),
		"boss_vel": 0.0,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"special_gauge": 0.0,
	}
	monkey_event.reset()
	_expect(monkey_event.force_spawn_monkey("left"), "Stage 2 monkey event should force-spawn on the left tree for smoke coverage")
	monkey_snapshot = monkey_event.get_debug_snapshot()
	_expect(int(monkey_snapshot.get("active_monkey_count", 0)) == 1, "Stage 2 forced monkey spawn should create one active monkey")
	for _frame in range(10 * 60):
		monkey_event.update(1.0 / 60.0, monkey_context, {"audio": monkey_audio})
	_expect(monkey_audio.banana_throw_count >= 1, "Stage 2 monkey should throw a banana after the original climb and wait window")
	monkey_event.reset()
	var slip_audio := FakeAudio.new()
	monkey_event.debug_spawn_landed_banana(Vector2(320.0, 700.0), true)
	var slip_result: Dictionary = monkey_event.update(1.0 / 60.0, monkey_context, {"audio": slip_audio})
	_expect(slip_audio.banana_slip_count == 1, "Stage 2 player stepping on a monkey banana should play the slip sound")
	_expect(slip_result.has("player_pos"), "Stage 2 monkey banana player slip should return an updated player position")
	monkey_event.reset()
	var boss_slip_audio := FakeAudio.new()
	monkey_event.debug_spawn_landed_banana(Vector2(340.0, 50.0), false)
	monkey_context["boss_vel"] = 5.0
	monkey_event.update(1.0 / 60.0, monkey_context, {"audio": boss_slip_audio})
	var monkey_ai_context: Dictionary = monkey_event.get_boss_ai_context()
	_expect(bool(monkey_ai_context.get("stage2_monkey_banana_boss_slip_active", false)), "Stage 2 boss stepping on a monkey banana should expose boss slip AI context")
	var boss_ai_state_for_monkey: Object = registry.get_instance("boss_ai_state")
	var monkey_boss_result: Dictionary = boss_ai_state_for_monkey.update(1.0 / 60.0, Vector2(300.0, 25.0), 5.0, monkey_ai_context)
	_expect(float(monkey_boss_result.get("boss_vel", 0.0)) > 0.0, "boss AI should slide with the Stage 2 monkey banana slip direction")

	var stage2_background: Object = registry.get_instance("stage2_pillar_background")
	_expect(stage2_background.has_method("trigger_tree_shake"), "Stage 2 background should receive wall-hit reactions")
	var asset_status: Dictionary = stage2_background.get_imagegen_asset_status()
	_expect(bool(asset_status.get("base", false)), "Stage 2 original pillar base image should load")
	_expect(bool(asset_status.get("tree", false)), "Stage 2 original pillar tree sprites should load")
	_expect(bool(asset_status.get("rock", false)), "Stage 2 latest imagegen rock atlas should load")
	_expect(bool(asset_status.get("rock_debris", false)), "Stage 2 imagegen rock debris atlas should load")
	_expect(bool(asset_status.get("game_frame", false)), "Stage 2 original pillar game frame should load")
	_expect(bool(asset_status.get("leaf", false)), "Stage 2 original ambient leaf sprites should load")
	var ambient_snapshot: Dictionary = stage2_background.get_ambient_visual_snapshot()
	_expect(int(ambient_snapshot.get("falling_leaf_count", 0)) == 3, "Stage 2 original pillar ambient leaves should initialize")
	_expect(int(ambient_snapshot.get("firefly_count", 0)) == 6, "Stage 2 original pillar fireflies should initialize")
	_expect(int(ambient_snapshot.get("leaf_sprite_count", 0)) == 6, "Stage 2 original ambient leaf sheet should expose six sprites")
	stage2_background.trigger_tree_shake("left", 280.0, 620.0, 750.0)
	_expect(stage2_background.has_visible_effects(), "Stage 2 wall hit should create visible jungle feedback")
	_expect(stage2_background.get_leaf_particle_count() == 0, "Stage 2 middle side-wall hit should not drop bush leaves")
	stage2_background.trigger_tree_shake("left", 80.0, 620.0, 750.0)
	_expect(stage2_background.get_leaf_particle_count() > 0, "Stage 2 bush-side wall hit should drop leaf particles")
	stage2_background.update(2.0)
	_expect(not stage2_background.has_visible_effects(), "Stage 2 jungle feedback should expire after update")

	stage2_background.reset()
	var rustle_context := {
		"current_stage": 2,
		"width": 760.0,
		"height": 750.0,
		"boss_pos": Vector2(300.0, 25.0),
		"boss_paddle_width": 100.0,
		"player_pos": Vector2(280.0, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"dash_snapshot": {"active": false},
	}
	stage2_background.update(0.016, rustle_context, {})
	rustle_context["boss_pos"] = Vector2(365.0, 25.0)
	rustle_context["boss_vel"] = 16.0
	rustle_context["player_pos"] = Vector2(345.0, 690.0)
	rustle_context["dash_snapshot"] = {"active": true}
	stage2_background.update(0.016, rustle_context, {})
	var rustle_snapshot: Dictionary = stage2_background.get_rustle_snapshot()
	_expect(int(rustle_snapshot.get("active_player_bush_count", 0)) > 0, "Stage 2 player paddle movement should rustle nearby bushes")
	_expect(int(rustle_snapshot.get("active_boss_bush_count", 0)) > 0, "Stage 2 boss paddle movement should rustle nearby bushes")
	_expect(int(rustle_snapshot.get("active_vine_count", 0)) > 0, "Stage 2 boss paddle movement should sway nearby vines")
	stage2_background.update(2.0, rustle_context, {})
	rustle_snapshot = stage2_background.get_rustle_snapshot()
	_expect(int(rustle_snapshot.get("active_bush_count", 0)) == 0, "Stage 2 bush rustle should decay after update")
	_expect(int(rustle_snapshot.get("active_vine_count", 0)) == 0, "Stage 2 vine rustle should decay after update")

	stage2_background.reset()
	var match_controller: Object = registry.get_instance("match_flow_controller")
	var score_state: Object = registry.get_instance("match_score_state")
	score_state.reset()
	match_controller.handle_score_event("player", {
		"score_state": score_state,
		"stage_background": stage2_background,
	}, {})
	var expression_snapshot: Dictionary = stage2_background.get_expression_snapshot()
	_expect(str(expression_snapshot.get("expression", "")) == "sad", "Stage 2 player score should make the boss sad")
	var expression_draw_context: Dictionary = stage2_background.get_actor_draw_context()
	_expect(str(expression_draw_context.get("stage2_boss_expression", "")) == "sad", "Stage 2 boss expression should reach actor draw context")
	stage2_background.update(2.1, {"current_stage": 2}, {})
	expression_snapshot = stage2_background.get_expression_snapshot()
	_expect(str(expression_snapshot.get("expression", "")) == "neutral", "Stage 2 boss expression should return to neutral after its timer")
	match_controller.handle_score_event("boss", {
		"score_state": score_state,
		"stage_background": stage2_background,
	}, {})
	expression_snapshot = stage2_background.get_expression_snapshot()
	_expect(str(expression_snapshot.get("expression", "")) == "happy", "Stage 2 boss score should make the boss happy")
	score_state.reset()

	var quake_audio := FakeAudio.new()
	stage2_background.activate_quake(0.5, 2, true, false, {"audio": quake_audio})
	_expect(stage2_background.get_rock_count() == 2, "Stage 2 quake should spawn the requested rock count")
	_expect(quake_audio.rock_spawn_count == 1, "Stage 2 quake should play the rock-spawn sound once")
	_expect(quake_audio.quake_start_count == 1, "Stage 2 quake should start its loop sound on activation")
	var falling_rocks: Array = stage2_background.get_rocks_snapshot()
	_expect(bool(falling_rocks[0].get("falling", false)), "Stage 2 quake rocks should begin in a falling state")
	_expect(str(falling_rocks[0].get("style_type", "")) != "", "Stage 2 quake rocks should carry original rock style data")
	var falling_outline: Array = falling_rocks[0].get("fixed_points", [])
	_expect(
		falling_outline.size() >= 12,
		"Stage 2 quake rocks should carry original irregular outline points"
	)
	_expect(
		_as_vector2(falling_rocks[0].get("pos", Vector2.ZERO), Vector2.ZERO).y
			< _as_vector2(falling_rocks[0].get("target_pos", Vector2.ZERO), Vector2.ZERO).y,
		"Stage 2 falling rocks should start above their target position"
	)
	var quake_warning: Dictionary = stage2_background.get_skill_warning_snapshot()
	_expect(bool(quake_warning.get("active", false)), "Stage 2 quake should show a boss skill warning")
	_expect(str(quake_warning.get("kind", "")) == "quake", "Stage 2 quake warning should identify the quake skill")
	var quake_feedback := FakeFeedback.new()
	stage2_background.update(1.0 / 60.0, {"current_stage": 2, "ball_active": true}, {
		"audio": quake_audio,
		"feedback": quake_feedback,
	})
	_expect(quake_feedback.fixed_offset_count >= 1, "Stage 2 quake should push original screen shake offsets")
	_expect(quake_feedback.last_fixed_offset.length() > 0.0, "Stage 2 quake screen shake offset should be visible")
	stage2_background.update(4.0, {"current_stage": 2, "ball_active": true}, {"audio": quake_audio})
	var landed_rocks: Array = stage2_background.get_rocks_snapshot()
	_expect(not bool(landed_rocks[0].get("falling", true)), "Stage 2 quake rocks should land after the original falling/bounce window")
	var quake_motion_scene := {
		"ball_pos": Vector2(330.0, 52.0),
		"ball_vel": Vector2(2.0, -5.0),
	}
	var quake_motion_context := {
		"current_stage": 2,
		"base_ball_speed": 8.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(320.0, 25.0),
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}
	stage2_background.activate_quake(0.5, 2, false, true)
	_expect(
		stage2_background.apply_quake_ball_motion(quake_motion_scene, quake_motion_context, {}, 1.0),
		"Stage 2 quake should perturb active ball motion"
	)
	_expect(
		_as_vector2(quake_motion_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO).y > 0.0,
		"Stage 2 quake boss-launch guard should push boss-hit balls downward"
	)
	_expect(
		_as_vector2(quake_motion_scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO).y > 80.0,
		"Stage 2 quake boss-launch guard should keep the ball below the boss"
	)
	var backstop_scene := {
		"ball_pos": Vector2(330.0, 4.0),
		"ball_vel": Vector2(1.0, -7.0),
	}
	_expect(
		stage2_background.resolve_quake_boss_backstop(backstop_scene, quake_motion_context, {"ball_intensity": FakeBallIntensity.new()}),
		"Stage 2 quake should backstop boss-hit balls before top scoring"
	)
	_expect(
		_as_vector2(backstop_scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO).y > 0.0,
		"Stage 2 quake backstop should relaunch boss-hit balls downward"
	)
	# Displaced-boss regression: with the boss held mid-field (lingpet puppet
	# grab), the backstop must re-place the ball at the HOME top band, not
	# teleport it below the displaced paddle into the player band.
	var displaced_backstop_scene := {
		"ball_pos": Vector2(330.0, 4.0),
		"ball_vel": Vector2(1.0, -7.0),
	}
	var displaced_backstop_context: Dictionary = quake_motion_context.duplicate()
	displaced_backstop_context["boss_pos"] = Vector2(320.0, 634.0)
	displaced_backstop_context["boss_y"] = 25.0
	_expect(
		stage2_background.resolve_quake_boss_backstop(displaced_backstop_scene, displaced_backstop_context, {"ball_intensity": FakeBallIntensity.new()}),
		"Stage 2 quake backstop should still fire while the boss is displaced"
	)
	_expect(
		_as_vector2(displaced_backstop_scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO).y < 120.0,
		"Stage 2 quake backstop must anchor to the home top band while the boss is puppeted mid-field"
	)
	var player_hit_handler := PaddleBouncePlayerPostHitHandler.new()
	stage2_background.activate_quake(0.5, 2)
	player_hit_handler.apply(
		Vector2(300.0, 680.0),
		0.0,
		false,
		false,
		0.0,
		{"current_stage": 2, "player_y": 700.0, "ball_size": 28.6},
		{"stage_background": stage2_background, "audio": quake_audio},
		null
	)
	_expect(not stage2_background.is_quake_active(), "Stage 2 quake should end when the player paddle hits the ball")
	_expect(quake_audio.quake_stop_count >= 1, "Stage 2 quake should stop its loop sound on player-hit cancellation")
	stage2_background.update(4.0, {"current_stage": 2, "ball_active": true}, {"audio": quake_audio})
	var rocks: Array = stage2_background.get_rocks_snapshot()
	var first_rock: Dictionary = rocks[0]
	var rock_pos: Vector2 = first_rock.get("pos", Vector2.ZERO)
	var scene := {
		"previous_ball_pos": rock_pos + Vector2(-80.0, 0.0),
		"ball_pos": rock_pos + Vector2(80.0, 0.0),
		"ball_vel": Vector2(9.0, 0.0),
	}
	var collision_context := {
		"current_stage": 2,
		"ball_size": 28.6,
	}
	var rock_break_audio := FakeAudio.new()
	_expect(stage2_background.resolve_ball_collision(scene, collision_context, {"audio": rock_break_audio}), "Stage 2 rocks should resolve ball collision")
	_expect(_as_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO).x < 0.0, "rock collision should reflect the ball")
	_expect(rock_break_audio.stonebreak_count == 1, "Stage 2 rock collision should play the stone-break sound")
	_expect(stage2_background.get_rock_fragment_count() >= 8, "Stage 2 rock collision should spawn original break debris fragments")

	stage2_background.reset()
	var water_audio := FakeAudio.new()
	var water_context := {
		"current_stage": 2,
		"ball_active": true,
		"boss_pos": Vector2(320.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	stage2_background.activate_quake(0.5, 2)
	_expect(
		stage2_background.activate_water_cannon(water_context, {"audio": water_audio}),
		"Stage 2 water cannon should be able to target quake rocks while they are still falling"
	)
	stage2_background.reset()
	water_audio = FakeAudio.new()
	stage2_background.activate_quake(0.5, 2)
	stage2_background.update(4.0, water_context, {"audio": water_audio})
	_expect(
		stage2_background.activate_water_cannon(water_context, {"audio": water_audio}),
		"Stage 2 water cannon should start when quake rocks exist"
	)
	_expect(stage2_background.get_water_cannon_phase() == "charging", "water cannon should begin in charge phase")
	var water_charge_warning: Dictionary = stage2_background.get_skill_warning_snapshot()
	_expect(str(water_charge_warning.get("text", "")) == "물대포 조준!", "water cannon charge should show Korean warning copy")
	stage2_background.update(0.81, water_context, {"audio": water_audio})
	_expect(stage2_background.get_water_cannon_phase() == "firing", "water cannon should fire after charging")
	var water_fire_warning: Dictionary = stage2_background.get_skill_warning_snapshot()
	_expect(str(water_fire_warning.get("kind", "")) == "water_fire", "water cannon firing should refresh the boss skill warning")
	_expect(water_audio.hydro_count == 1, "water cannon should play the hydro sound when firing starts")
	var rocks_before_break: int = stage2_background.get_rock_count()
	stage2_background.update(0.55, water_context, {"audio": water_audio})
	_expect(stage2_background.get_water_cannon_phase() == "idle", "water cannon should return to idle after firing")
	var fragment_warning: Dictionary = stage2_background.get_skill_warning_snapshot()
	_expect(str(fragment_warning.get("kind", "")) == "fragment", "water cannon finish should warn about rock fragments")
	_expect(stage2_background.get_rock_count() == rocks_before_break - 1, "water cannon should break its target rock")
	_expect(water_audio.stonebreak_count == 1, "water cannon should play the stone break sound")
	_expect(stage2_background.get_rock_fragment_count() >= 8, "water cannon should also spawn visible rock debris fragments")
	_expect(stage2_background.get_water_splash_count() > 0, "water cannon should spawn splash fragments")
	var water_fragments_snapshot: Array = stage2_background.get_water_splashes_snapshot()
	_expect(
		water_fragments_snapshot.size() >= 35 and water_fragments_snapshot.size() <= 45,
		"water cannon should spawn Python-parity rock fragments plus water splashes"
	)
	var water_fragment_render_limit: int = int(stage2_background.get_render_budget_status().get("water_splash_render_limit", 0))
	_expect(
		_count_stone_fragments_in_tail(water_fragments_snapshot, water_fragment_render_limit) >= mini(4, water_fragment_render_limit),
		"water cannon render cap should keep broken rock fragments visible after decorative splashes are capped"
	)
	var hittable_count := 0
	var hittable_fragment_pos := Vector2.ZERO
	for fragment in water_fragments_snapshot:
		if bool(fragment.get("can_hit_player", false)):
			hittable_count += 1
			hittable_fragment_pos = _as_vector2(fragment.get("pos", Vector2.ZERO), Vector2.ZERO)
	_expect(
		hittable_count >= 20 and hittable_count <= 25,
		"water cannon should spawn 20-25 hittable rock fragments"
	)
	_expect(hittable_fragment_pos != Vector2.ZERO, "water cannon should spawn hittable rock fragments")
	var movement_state := FakeMovementState.new()
	var hit_feedback := FakeFeedback.new()
	water_context["player_pos"] = hittable_fragment_pos - Vector2(20.0, 20.0)
	water_context["player_paddle_size"] = Vector2(40.0, 40.0)
	stage2_background.update(0.0, water_context, {
		"audio": water_audio,
		"movement_state": movement_state,
		"feedback": hit_feedback,
	})
	_expect(movement_state.knockback_count >= 1, "hittable water-cannon fragments should knock the player back")
	_expect(abs(movement_state.last_velocity) > 0.0, "fragment knockback should have a horizontal direction")
	_expect(abs(abs(movement_state.last_velocity) - 20.0) <= 0.01, "fragment knockback should use the original 20-speed fire-style push")
	_expect(water_audio.rockhit_count >= 1, "fragment hit should play the rock-hit sound")
	_expect(hit_feedback.shake_count > 0, "fragment hit should trigger feedback shake")
	_expect(stage2_background.get_fragment_hit_flash_timer() > 0.0, "fragment hit should trigger red flash feedback")

	stage2_background.reset()
	var rage_skill_state: Object = registry.get_instance("stage2_boss_skill_state")
	rage_skill_state.reset()
	rage_skill_state.water_cannon_delay = 0.0
	var rage_audio := FakeAudio.new()
	var rage_feedback := FakeFeedback.new()
	stage2_background.update(0.0, {
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
	}, {})
	_expect(stage2_background.is_boss_rage_pending(), "Stage 2 should reserve boss rage when the player reaches crisis score")
	var round_cleanup := BallRoundActorCleanup.new()
	round_cleanup.reset_actor_round_state({
		"stage2_pillar_background": stage2_background,
		"stage2_boss_skill_state": rage_skill_state,
		"audio": rage_audio,
		"feedback": rage_feedback,
	})
	_expect(stage2_background.is_boss_rage_active(), "Stage 2 round reset should start pending boss rage")
	stage2_background.update(0.26, {"current_stage": 2, "player_score": 4, "boss_score": 2}, {
		"audio": rage_audio,
		"feedback": rage_feedback,
	})
	_expect(rage_audio.boss_cry_count >= 1, "Stage 2 boss rage stomp should play the cry sound")
	_expect(rage_feedback.shake_count > 0, "Stage 2 boss rage should request feedback shake")
	var rage_draw_context: Dictionary = stage2_background.get_actor_draw_context()
	_expect(float(rage_draw_context.get("stage2_boss_rage_tint", 0.0)) > 0.0, "Stage 2 boss rage should expose red actor tint")
	stage2_background.update(1.12, {"current_stage": 2, "player_score": 4, "boss_score": 2}, {
		"stage2_boss_skill_state": rage_skill_state,
		"audio": rage_audio,
		"feedback": rage_feedback,
	})
	var rage_snapshot: Dictionary = stage2_background.get_boss_rage_snapshot()
	_expect(bool(rage_snapshot.get("final_stomp_done", false)), "Stage 2 boss rage should trigger a final stomp")
	_expect(stage2_background.is_quake_active(), "Stage 2 boss rage final stomp should start quake feedback")
	_expect(stage2_background.get_rock_count() >= 3, "Stage 2 boss rage final stomp should drop a defensive rock wall")
	_expect(rage_skill_state.get_water_cannon_delay() > 6.0, "Stage 2 rage wall should defer water cannon instead of firing immediately")
	_expect(rage_audio.rock_spawn_count >= 1, "Stage 2 boss rage rock wall should play rock-spawn audio")

	# Regression: production effects controller sets effect_deps.audio = null while
	# waiting_for_serve, but the rage starts in that exact pre-rally moment. The cached
	# rage_audio fallback must still drive the cry SFX so the original Python behavior
	# (cry.wav per stomp + quake loop on final stomp) survives the silent effect_deps.
	stage2_background.reset()
	rage_skill_state.reset()
	rage_skill_state.water_cannon_delay = 0.0
	var rage_audio_b := FakeAudio.new()
	var rage_feedback_b := FakeFeedback.new()
	stage2_background.update(0.0, {
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
	}, {})
	_expect(stage2_background.is_boss_rage_pending(), "Regression: rage should still pend on player_score=4")
	round_cleanup.reset_actor_round_state({
		"stage2_pillar_background": stage2_background,
		"stage2_boss_skill_state": rage_skill_state,
		"audio": rage_audio_b,
		"feedback": rage_feedback_b,
	})
	_expect(stage2_background.is_boss_rage_active(), "Regression: round reset should arm boss rage")
	# Simulate the controller's effect_deps with audio=null (waiting_for_serve gate).
	stage2_background.update(0.26, {
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
		"waiting_for_serve": true,
	}, {
		"audio": null,
		"feedback": rage_feedback_b,
	})
	_expect(rage_audio_b.boss_cry_count >= 1, "Regression: rage cry SFX must fire even when effect_deps.audio is null")
	stage2_background.update(1.12, {
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
		"waiting_for_serve": true,
	}, {
		"stage2_boss_skill_state": rage_skill_state,
		"audio": null,
		"feedback": rage_feedback_b,
	})
	_expect(rage_audio_b.quake_start_count >= 1, "Regression: rage final stomp must start the quake loop even when effect_deps.audio is null")

	stage2_background.reset()
	var stage2_skill_state: Object = registry.get_instance("stage2_boss_skill_state")
	_expect(stage2_skill_state != null and stage2_skill_state.has_method("update"), "Stage 2 boss skill state should be constructible")
	var ball_update_context: Object = registry.get_instance("ball_update_context")
	var ball_deps: Dictionary = ball_update_context.build_update_deps(registry)
	_expect(
		ball_deps.get("stage2_boss_skill_state", null) == stage2_skill_state,
		"ball update deps should expose the Stage 2 boss skill state for auto skill scheduling"
	)
	stage2_skill_state.reset()
	var pattern_audio := FakeAudio.new()
	var pattern_context := {
		"current_stage": 2,
		"ball_active": true,
		"waiting_for_serve": false,
		"player_score": 3,
		"ai_mode": "champion",
		"boss_pos": Vector2(320.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	var pattern_deps := {
		"stage_background": stage2_background,
		"stage2_boss_skill_state": stage2_skill_state,
		"audio": pattern_audio,
	}
	stage2_skill_state.update(4.1, pattern_context, pattern_deps)
	_expect(stage2_background.get_rock_count() == 0, "Stage 2 boss quake should wait for its 40-second auto cooldown")
	var boss_hit_handler := PaddleBounceBossPostHitHandler.new()
	var boss_hit_context: Dictionary = pattern_context.duplicate()
	boss_hit_context["boss_y"] = 25.0
	boss_hit_context["ball_size"] = 28.6
	stage2_skill_state.register_boss_hit(Vector2(4.0, 8.0), boss_hit_context, {})
	stage2_skill_state.reset_round()
	_expect(stage2_skill_state.get_boss_special_gauge() <= 0.001, "Stage 2 boss hit gauge should stay disabled for auto cooldown skills")
	stage2_skill_state.reset()
	stage2_background.reset()
	stage2_skill_state.update(39.9, pattern_context, pattern_deps)
	_expect(stage2_background.get_rock_count() == 0, "Stage 2 boss quake should not cast before 40 seconds")
	for hit_index in range(8):
		boss_hit_handler.apply(
			Vector2(320.0 + float(hit_index), 60.0),
			Vector2(4.0, 8.0),
			0.0,
			0.0,
			false,
			false,
			false,
			boss_hit_context,
			{"stage2_boss_skill_state": stage2_skill_state},
			null
		)
	var almost_ready_gauge: float = stage2_skill_state.get_boss_special_gauge()
	_expect(almost_ready_gauge <= 0.001, "Stage 2 boss quake should ignore boss paddle-hit gauge gain")
	stage2_skill_state.update(0.2, pattern_context, pattern_deps)
	_expect(stage2_background.is_quake_active(), "Stage 2 boss skill scheduler should auto-trigger quake at 40 seconds")
	_expect(stage2_background.get_rock_count() >= 2 and stage2_background.get_rock_count() <= 4, "Stage 2 champion quake should roll the original 2-4 rocks")
	_expect(stage2_skill_state.get_boss_special_gauge() <= 0.001, "Stage 2 auto quake should not use the boss hit gauge")
	_expect(abs(stage2_skill_state.get_quake_cooldown() - 40.0) <= 0.001, "Stage 2 quake cooldown should reset to 40 seconds")
	_expect(stage2_skill_state.get_water_cannon_delay() > 6.0, "Stage 2 quake rocks should apply a short water-cannon grace delay")
	boss_hit_handler.apply(
		Vector2(330.0, 60.0),
		Vector2(4.0, 8.0),
		0.0,
		0.0,
		false,
		false,
		false,
		boss_hit_context,
		{
			"stage2_boss_skill_state": stage2_skill_state,
			"stage_background": stage2_background,
			"audio": pattern_audio,
		},
		null
	)
	_expect(stage2_skill_state.get_boss_special_gauge() <= 0.001, "Stage 2 boss hits should not retrigger quake while auto cooldown is active")
	stage2_background.update(2.0, pattern_context, pattern_deps)
	var pressure_snapshot: Dictionary = stage2_skill_state.get_pressure_snapshot(pattern_context)
	_expect(int(pressure_snapshot.get("level", 0)) >= 1, "Stage 2 boss pressure should rise after player score unlock")
	_expect(abs(float(pressure_snapshot.get("quake_repeat_cooldown", 0.0)) - 40.0) <= 0.001, "Stage 2 quake cooldown should stay at 40 seconds")
	_expect(abs(float(pressure_snapshot.get("water_delay_min", 0.0)) - 30.0) <= 0.001, "Stage 2 water cannon minimum delay should match the 30-second auto cooldown")
	_expect(abs(float(pressure_snapshot.get("water_delay_max", 0.0)) - 30.0) <= 0.001, "Stage 2 water cannon maximum delay should match the 30-second auto cooldown")
	_expect(int(pressure_snapshot.get("rock_count_min", 0)) == 2 and int(pressure_snapshot.get("rock_count_max", 0)) == 4, "Stage 2 champion quake rock range should match the original")
	_expect(
		abs(stage2_skill_state.get_quake_cooldown() - float(pressure_snapshot.get("quake_repeat_cooldown", 0.0))) <= 0.001,
		"Stage 2 scheduler should apply the 40-second quake cooldown after casting"
	)
	stage2_skill_state.update(7.1, pattern_context, pattern_deps)
	_expect(stage2_background.get_water_cannon_phase() == "charging", "Stage 2 boss skill scheduler should start water cannon from the ready auto cooldown")
	var ai_context: Dictionary = stage2_skill_state.get_boss_ai_context(stage2_background)
	_expect(bool(ai_context.get("stage2_boss_movement_locked", false)), "water cannon should lock Stage 2 boss movement")
	var hud_context: Dictionary = stage2_skill_state.get_hud_context(stage2_background, pattern_context)
	_expect(bool(hud_context.get("stage2_boss_skill_hud_active", false)), "Stage 2 boss skill HUD context should be active")
	_expect(str(hud_context.get("stage2_boss_skill_hud_boss_name", "")) == "악어장군", "Stage 2 boss skill HUD should use Korean boss copy")
	var hud_skills: Array = hud_context.get("stage2_boss_skill_hud_skills", [])
	_expect(_has_skill_label(hud_skills, "정글지진"), "Stage 2 boss skill HUD should expose jungle quake")
	_expect(_has_skill_label(hud_skills, "물대포"), "Stage 2 boss skill HUD should expose water cannon")
	_expect(_has_skill_label(hud_skills, "스피드디펜스"), "Stage 2 boss skill HUD should expose speed defense")
	var boss_ai_state: Object = registry.get_instance("boss_ai_state")
	var locked_ai_result: Dictionary = boss_ai_state.update(0.016, Vector2(250.0, 25.0), 5.0, ai_context)
	_expect(float(locked_ai_result.get("boss_vel", 1.0)) == 0.0, "boss AI should stop while Stage 2 water cannon is charging or firing")

	stage2_background.reset()
	stage2_skill_state.reset()
	var round_win_context: Dictionary = pattern_context.duplicate()
	round_win_context["player_score"] = 0
	round_win_context["round_wins"] = 3
	stage2_background.activate_quake(0.5, 2, false, false, {"audio": pattern_audio})
	stage2_background.update(4.0, round_win_context, pattern_deps)
	stage2_skill_state.water_cannon_delay = 0.0
	stage2_skill_state.update(0.1, round_win_context, pattern_deps)
	_expect(stage2_background.get_water_cannon_phase() == "charging", "Stage 2 water cannon should auto-trigger from cooldown regardless of score unlock")

	var mythic_pressure_context: Dictionary = pattern_context.duplicate()
	mythic_pressure_context["player_score"] = 5
	mythic_pressure_context["ai_mode"] = "mythic"
	var mythic_pressure: Dictionary = stage2_skill_state.get_pressure_snapshot(mythic_pressure_context)
	_expect(int(mythic_pressure.get("level", 0)) >= 2, "Stage 2 mythic late score should enter high pressure")
	_expect(int(mythic_pressure.get("rock_count_min", 0)) == 2 and int(mythic_pressure.get("rock_count_max", 0)) == 4, "Stage 2 mythic normal quake should match the original 2-4 rock range")
	_expect(
		abs(float(mythic_pressure.get("quake_repeat_cooldown", 0.0)) - float(pressure_snapshot.get("quake_repeat_cooldown", 0.0))) <= 0.001,
		"Stage 2 mythic pressure should keep the original quake cooldown"
	)
	mythic_pressure_context["enraged_boss_active"] = true
	var enraged_mythic_pressure: Dictionary = stage2_skill_state.get_pressure_snapshot(mythic_pressure_context)
	_expect(int(enraged_mythic_pressure.get("rock_count_min", 0)) == 4 and int(enraged_mythic_pressure.get("rock_count_max", 0)) == 8, "Stage 2 mythic enraged quake should match the original 4-8 rock range")

	print("stage2_router_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _count_stone_fragments_in_tail(fragments: Array, render_limit: int) -> int:
	var count := 0
	for idx in range(max(0, fragments.size() - max(0, render_limit)), fragments.size()):
		var fragment_value: Variant = fragments[idx]
		if fragment_value is Dictionary and bool((fragment_value as Dictionary).get("stone", false)):
			count += 1
	return count


func _has_skill_label(skills: Array, label: String) -> bool:
	for skill in skills:
		if skill is Dictionary and str(skill.get("label", "")) == label:
			return true
	return false
