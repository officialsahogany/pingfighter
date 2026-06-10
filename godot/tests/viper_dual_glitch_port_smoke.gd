extends SceneTree

const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const TooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeSkillConfig:
	var equipped := ["dual_glitch", "blade_rush", "dive_strike"]

	func is_skill_equipped(skill_name: String) -> bool:
		return equipped.has(skill_name)

	func get_skill_cost(skill_name: String) -> float:
		match skill_name:
			"dual_glitch":
				return 220.0
			"blade_rush":
				return 200.0
			"dive_strike":
				return 150.0
		return 0.0

	func get_cooldown_seconds(skill_name: String) -> float:
		match skill_name:
			"dual_glitch":
				return 45.0
			"blade_rush":
				return 20.0
			"dive_strike":
				return 70.0
		return 0.0


class FakeSkillState:
	var triggered: Array[String] = []
	var cooldown_seconds: Dictionary = {}

	func trigger_configured_cooldown(skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		triggered.append(skill_name)

	func trigger_cooldown(skill_name: String, _now_msec: int, seconds: float) -> void:
		triggered.append(skill_name)
		cooldown_seconds[skill_name] = seconds

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakePerkState:
	var levels: Dictionary = {"four_poisons": 0, "blade_amp": 0}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(levels.get(skill_id, 0))


class FakeOrbHud:
	var spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1


class FakeFeedback:
	var shakes := 0

	func set_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class FakeAudio:
	var blade_fire := 0

	func play_viper_blade() -> void:
		blade_fire += 1


class FakeOwner:
	var selected_character_type := "viper"
	var runtime_accessory_slot_bonus := 0
	var runtime_paddle_scale := 1.0
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false


class RealViperRegistry:
	var perk_state: Object
	var skill_config: Object

	func _init(new_perk_state: Object, new_skill_config: Object) -> void:
		perk_state = new_perk_state
		skill_config = new_skill_config

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return perk_state
			"viper_skill_config":
				return skill_config
		return null


class FakeMotionStepper:
	var captured_context: Dictionary = {}

	func step(ball_pos: Vector2, _effective_move: Vector2, _ball_vel: Vector2, context: Dictionary) -> Dictionary:
		captured_context = context.duplicate(true)
		return {
			"event": "player_paddle",
			"ball_pos": ball_pos,
			"paddle_x": 12.0,
			"paddle_w": 155.0,
			"is_player": true,
			"viper_dual_glitch_clone_hit": true,
			"viper_dual_glitch_clone_index": 1,
			"viper_dual_glitch_clone_side": 1,
		}


class FakePaddleController:
	var captured_context: Dictionary = {}

	func bounce(
		_paddle_x: float,
		_paddle_w: float,
		_is_player: bool,
		context: Dictionary,
		_deps: Dictionary,
		_callbacks: Dictionary = {}
	) -> Dictionary:
		captured_context = context.duplicate(true)
		return {
			"ball_pos": context.get("ball_pos", Vector2.ZERO),
			"ball_vel": context.get("ball_vel", Vector2.ZERO),
		}


func _init() -> void:
	_test_catalog_unlock_wiring()
	_test_command_activation_clone_collision_and_hp()
	_test_actor_context_and_sprite_clone_geometry()
	_test_round_boundary_preserves_active_dual_glitch()
	_test_startup_cancel_and_four_poisons_super_armor()
	_test_four_poisons_duration_cooldown_and_replication()
	_test_four_poisons_emp_clone_replication()
	_test_motion_processor_forwards_clone_context()
	_test_tooltip_runtime_bonus()
	print("viper_dual_glitch_port_smoke: ok")
	quit(0)


func _test_catalog_unlock_wiring() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var perk_state: Object = RuntimePerkState.new()
	var skill_config: Object = ViperSkillConfig.new()
	var owner := FakeOwner.new()
	var registry := RealViperRegistry.new(perk_state, skill_config)
	var unlock_data: Dictionary = catalog.get_perk_data("unlock_dual_glitch")
	_expect(not unlock_data.is_empty(), "unlock_dual_glitch should exist in the Viper perk catalog")
	_expect(str(unlock_data.get("unlocks_skill", "")) == "dual_glitch", "unlock_dual_glitch should equip the dual_glitch orb")
	_expect(not skill_config.is_skill_equipped("dual_glitch"), "Dual Glitch should not be equipped before the unlock")
	unlock_data["id"] = "unlock_dual_glitch"
	_expect(perk_state.apply_choice(unlock_data, owner, registry), "selecting unlock_dual_glitch should apply cleanly")
	_expect(perk_state.get_runtime_skill_level("unlock_dual_glitch") == 1, "unlock perk level should be recorded")
	_expect(skill_config.is_skill_equipped("dual_glitch"), "Dual Glitch unlock should equip the runtime skill")


func _test_command_activation_clone_collision_and_hp() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var deps := _deps(input, skill_config, skill_state, perk_state, orb, feedback, FakeAudio.new())
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	var result: Dictionary = _activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "A-D-A-D should activate Dual Glitch")
	_expect(str(result.get("skill_name", "")) == "dual_glitch", "Dual Glitch activation should report its skill id")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 280.0) < 0.01, "Dual Glitch should spend 220 gauge")
	_expect(skill_state.triggered.back() == "dual_glitch", "Dual Glitch activation should trigger its cooldown")
	_expect(orb.spins == 1, "Dual Glitch activation should spin the skill orb")
	var snap: Dictionary = runtime.get_snapshot()
	_expect(str(snap.get("dual_glitch_state", "")) == "startup", "Dual Glitch should begin in startup")
	_expect((snap.get("dual_glitch_clones", []) as Array).size() == 2, "Dual Glitch should create two clones")
	_expect(int(((snap.get("dual_glitch_clones", []) as Array)[0] as Dictionary).get("hp", 0)) == 2, "base clone HP should be 2")

	var moved_pos := Vector2(420.0, player_pos.y)
	result = runtime.try_activate_before_movement(1.0 / 60.0, moved_pos, 280.0, config, deps)
	_expect(abs(_get_vector2(result, "player_pos", moved_pos).x - player_pos.x) < 0.01, "startup should lock Viper's X position")
	_advance_dual(runtime, config, deps, player_pos, 49)
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "spawn", "startup should advance into spawn")
	_advance_dual(runtime, config, deps, player_pos, 24)
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "active", "spawn should advance into active")

	var collision_context: Dictionary = config.duplicate(true)
	collision_context["player_pos"] = player_pos
	collision_context["player_collision_cooldown"] = 0.0
	collision_context.merge(runtime.get_ball_collision_context(), true)
	var clone_entries: Array = collision_context.get("viper_dual_glitch_clone_rects", [])
	_expect(clone_entries.size() == 2, "active Dual Glitch should expose two clone collision rects")
	var clone_rect: Rect2 = (clone_entries[0] as Dictionary).get("rect", Rect2())
	_expect(abs(clone_rect.position.x - (player_pos.x - 140.0)) < 0.01, "left clone offset should match Python's paddle width plus -15 padding")
	var detector: Object = BallMotionCollisionDetector.new()
	var collision: Dictionary = detector.check_paddles(clone_rect.get_center(), Vector2(0.0, 8.0), 28.6, collision_context)
	_expect(str(collision.get("event", "")) == "player_paddle", "clone rect should participate in player paddle collision")
	_expect(bool(collision.get("viper_dual_glitch_clone_hit", false)), "clone collision should be tagged for post-hit handling")

	var first_index: int = int(collision.get("viper_dual_glitch_clone_index", -1))
	var hp_result: Dictionary = runtime.apply_dual_glitch_clone_ball_hit(collision, deps)
	_expect(bool(hp_result.get("hit", false)) and int(hp_result.get("clone_hp", -1)) == 1, "first clone hit should reduce HP")
	hp_result = runtime.apply_dual_glitch_clone_ball_hit(collision, deps)
	_expect(bool(hp_result.get("clone_destroyed", false)), "second hit should destroy a base clone")
	var second_hit := {"viper_dual_glitch_clone_index": 1 if first_index == 0 else 0}
	runtime.apply_dual_glitch_clone_ball_hit(second_hit, deps)
	hp_result = runtime.apply_dual_glitch_clone_ball_hit(second_hit, deps)
	_expect(bool(hp_result.get("clone_destroyed", false)), "destroying the final clone should be detected")
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "fade", "Dual Glitch should fade after all clones are destroyed")


func _test_actor_context_and_sprite_clone_geometry() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, perk_state, FakeOrbHud.new(), FakeFeedback.new(), FakeAudio.new())
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	_activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_advance_dual(runtime, config, deps, player_pos, 49)
	_advance_dual(runtime, config, deps, player_pos, 24)
	var actor_context: Dictionary = runtime.get_actor_draw_context()
	_expect(str(actor_context.get("viper_dual_glitch_state", "")) == "active", "actor draw context should expose active Dual Glitch state")
	var clone_entries: Array = actor_context.get("viper_dual_glitch_clone_rects", [])
	_expect(clone_entries.size() == 2, "actor draw context should expose visible Dual Glitch clone entries")

	var renderer: Object = Stage1PlayerActorRenderer.new()
	var visual_rect := Rect2(Vector2(300.0, 582.0), Vector2(160.0, 160.0))
	actor_context["selected_character_type"] = "viper"
	actor_context["viper_dual_glitch_wiggle_amplitude"] = 0.0
	var clone_draws: Array = renderer.build_viper_dual_glitch_clone_sprite_draws(
		actor_context,
		visual_rect,
		false,
		player_pos,
		Vector2(155.0, 50.0),
		Vector2.ZERO
	)
	_expect(clone_draws.size() == 2, "player actor renderer should build two clone sprite draw passes")
	var first_draw: Dictionary = clone_draws[0]
	var first_visual_rect: Rect2 = first_draw.get("visual_rect", Rect2())
	var first_rect: Rect2 = (clone_entries[0] as Dictionary).get("rect", Rect2())
	_expect(first_visual_rect.size == visual_rect.size, "clone draw should reuse the full player sprite size instead of the paddle hitbox size")
	_expect(abs(first_visual_rect.position.y - visual_rect.position.y) < 0.01, "clone sprite should keep the live player sprite's vertical anchor")
	_expect(abs(first_visual_rect.position.x - (first_rect.position.x - 2.5)) < 0.01, "clone sprite should preserve the player sprite offset from the paddle rect")
	var main_modulate: Color = first_draw.get("main_modulate", Color.WHITE)
	_expect(main_modulate.a < 1.0, "clone sprite pass should render as a ghosted copied sprite")


func _test_round_boundary_preserves_active_dual_glitch() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, perk_state, FakeOrbHud.new(), FakeFeedback.new(), FakeAudio.new())
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	_activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_advance_dual(runtime, config, deps, player_pos, 49)
	_advance_dual(runtime, config, deps, player_pos, 24)
	var remaining_before_reset: float = float(runtime.get_snapshot().get("dual_glitch_remaining_frames", 0.0))
	runtime.reset_round(deps)
	var snap: Dictionary = runtime.get_snapshot()
	_expect(str(snap.get("dual_glitch_state", "")) == "active", "round reset should preserve active Dual Glitch for the next round")
	_expect((snap.get("dual_glitch_clones", []) as Array).size() == 2, "round reset should preserve living Dual Glitch clones")
	_expect(abs(float(snap.get("dual_glitch_remaining_frames", 0.0)) - remaining_before_reset) < 0.01, "round reset should preserve Dual Glitch's remaining duration")

	var waiting_context := _base_config()
	waiting_context["ball_active"] = false
	waiting_context["waiting_for_serve"] = true
	waiting_context["player_pos"] = Vector2(380.0, 680.0)
	waiting_context["player_paddle_size"] = Vector2(155.0, 50.0)
	runtime.update_effects(120.0, Time.get_ticks_msec(), waiting_context, deps)
	snap = runtime.get_snapshot()
	_expect(str(snap.get("dual_glitch_state", "")) == "active", "serve-wait frames should pause, not cancel, cross-round Dual Glitch")
	_expect(abs(float(snap.get("dual_glitch_remaining_frames", 0.0)) - remaining_before_reset) < 0.01, "serve-wait frames should not consume Dual Glitch's remaining duration")
	_expect(abs(_get_vector2(snap, "dual_glitch_base_pos", Vector2.ZERO).x - 380.0) < 0.01, "serve-wait frames should re-anchor carried Dual Glitch clones to the reset paddle")

	runtime.update_effects(10.0, Time.get_ticks_msec(), config, deps)
	_expect(float(runtime.get_snapshot().get("dual_glitch_remaining_frames", 0.0)) < remaining_before_reset, "next live round should resume Dual Glitch's countdown")
	var hard_reset_deps := deps.duplicate()
	hard_reset_deps["preserve_dual_glitch"] = false
	runtime.reset_round(hard_reset_deps)
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "idle", "explicit hard reset should still clear Dual Glitch")


func _test_startup_cancel_and_four_poisons_super_armor() -> void:
	var low_poison := _make_runtime_bundle(0)
	var runtime: Object = low_poison["runtime"]
	_activate_dual_glitch(runtime, low_poison["input"], Vector2(302.5, 680.0), 500.0, _base_config(), low_poison["deps"])
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "startup", "Dual Glitch startup should be active before contact")
	runtime.register_player_ball_contact(low_poison["deps"], _base_config())
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "idle", "Dual Glitch startup should cancel on player-ball contact without Four Poisons super armor")

	var armored := _make_runtime_bundle(3)
	runtime = armored["runtime"]
	_activate_dual_glitch(runtime, armored["input"], Vector2(302.5, 680.0), 500.0, _base_config(), armored["deps"])
	runtime.register_player_ball_contact(armored["deps"], _base_config())
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "startup", "Four Poisons Lv3 super armor should preserve Dual Glitch startup")


func _test_four_poisons_duration_cooldown_and_replication() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	perk_state.levels["four_poisons"] = 5
	var deps := _deps(input, skill_config, skill_state, perk_state, FakeOrbHud.new(), FakeFeedback.new(), FakeAudio.new())
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	var result: Dictionary = _activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "Four Poisons should not block Dual Glitch activation")
	var snap: Dictionary = runtime.get_snapshot()
	_expect(abs(float(snap.get("dual_glitch_active_total_frames", 0.0)) - 1197.0) < 0.01, "Four Poisons Lv5 should extend Dual Glitch active time by 33%")
	_expect(abs(float(skill_state.cooldown_seconds.get("dual_glitch", 0.0)) - 32.0) < 0.01, "Four Poisons Lv5 should reduce Dual Glitch cooldown by 20%")
	_expect(int(((snap.get("dual_glitch_clones", []) as Array)[0] as Dictionary).get("hp", 0)) == 4, "Four Poisons Lv5 should raise clone HP to 4")
	_advance_dual(runtime, config, deps, player_pos, 49)
	_advance_dual(runtime, config, deps, player_pos, 24)
	runtime._launch_blade_projectile(player_pos, config, deps)
	snap = runtime.get_snapshot()
	var followups: Array = snap.get("blade_followup_projectiles", [])
	_expect(followups.size() == 2, "Four Poisons Lv5 active Dual Glitch should replicate Blade Rush from both living clones")
	for projectile_value in followups:
		var projectile: Dictionary = projectile_value
		_expect(bool(projectile.get("dual_glitch_replica", false)), "replicated blades should be tagged as Dual Glitch replicas")


func _test_four_poisons_emp_clone_replication() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	perk_state.levels["four_poisons"] = 5
	var deps := _deps(input, skill_config, skill_state, perk_state, FakeOrbHud.new(), FakeFeedback.new(), FakeAudio.new())
	var config := _base_config()
	config["player_floor_y"] = 680.0
	var player_pos := Vector2(302.5, 680.0)
	_activate_dual_glitch(runtime, input, player_pos, 500.0, config, deps)
	_advance_dual(runtime, config, deps, player_pos, 49)
	_advance_dual(runtime, config, deps, player_pos, 24)
	_expect(str(runtime.get_snapshot().get("dual_glitch_state", "")) == "active", "Dual Glitch should be active before EMP replication")

	var dive_pos := Vector2(302.5, 560.0)
	runtime._start_dive_strike(dive_pos, 500.0, config, deps, Time.get_ticks_msec())
	var dive_result: Dictionary = {}
	for _i in range(32):
		dive_result = runtime._update_dive_strike(1.0 / 60.0, dive_pos, 350.0, config, deps)
		dive_pos = _get_vector2(dive_result, "player_pos", dive_pos)
	var snap: Dictionary = runtime.get_snapshot()
	_expect(int(snap.get("dive_phase", -1)) == 2, "EMP should land before checking clone shockwaves")
	_expect((snap.get("dual_glitch_clone_dive_entries", []) as Array).size() == 2, "Four Poisons Lv5 should schedule two clone EMP shockwaves")

	var scene := {
		"ball_pos": Vector2(380.0, 720.0),
		"ball_vel": Vector2(0.0, 8.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}
	var motion_context: Dictionary = config.duplicate(true)
	motion_context.merge(scene, true)
	var result: Dictionary = runtime.apply_emp_strike_ball_motion(1.0, scene, motion_context, deps)
	_expect(result.has("ball_vel") and not bool(result.get("viper_dual_glitch_clone_emp_hit", false)), "primary EMP should hit first and remain the gold-bearing hit")
	scene.merge(result, true)
	motion_context.merge(scene, true)
	for _i in range(13):
		runtime.update_effects(1.0, Time.get_ticks_msec(), motion_context, deps)
	result = runtime.apply_emp_strike_ball_motion(1.0, scene, motion_context, deps)
	_expect(bool(result.get("viper_dual_glitch_clone_emp_hit", false)), "left clone EMP should be able to refresh the ball hit after the stagger")
	_expect(not result.has("runtime_perk_gold") and not result.has("skill_gold_award"), "clone EMP replication should not duplicate EMP gold")


func _test_motion_processor_forwards_clone_context() -> void:
	var processor: Object = BallMotionEventProcessor.new()
	var stepper := FakeMotionStepper.new()
	var paddle_controller := FakePaddleController.new()
	var scene := {
		"ball_pos": Vector2(200.0, 690.0),
		"ball_vel": Vector2(0.0, 8.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	var context := _base_config()
	context["viper_dual_glitch_state"] = "active"
	context["viper_dual_glitch_clone_rects"] = [{
		"rect": Rect2(Vector2(162.5, 680.0), Vector2(155.0, 50.0)),
		"index": 1,
		"side": -1,
	}]
	processor.step_motion(scene, 1.0, context, {
		"motion_stepper": stepper,
		"paddle_bounce_controller": paddle_controller,
	}, {})
	_expect(stepper.captured_context.has("viper_dual_glitch_clone_rects"), "motion step context should preserve clone rects")
	_expect(bool(paddle_controller.captured_context.get("viper_dual_glitch_clone_hit", false)), "paddle bounce context should receive clone hit tag")
	_expect(int(paddle_controller.captured_context.get("viper_dual_glitch_clone_index", -1)) == 1, "paddle bounce context should receive clone index")


func _test_tooltip_runtime_bonus() -> void:
	var renderer: Object = TooltipRenderer.new()
	var skill_config: Object = ViperSkillConfig.new()
	var perk_state := FakePerkState.new()
	perk_state.levels["four_poisons"] = 5
	var skill_data: Dictionary = skill_config.get_skill_data("dual_glitch")
	var hover_context := {"runtime_perk_state": perk_state}
	var description: String = renderer._build_description_with_runtime_bonus(skill_data, hover_context)
	_expect(description.find("분신 HP 4") >= 0, "Dual Glitch tooltip should show Four Poisons clone HP")
	_expect(description.find("스킬 복제") >= 0, "Dual Glitch tooltip should show the Lv5 clone replication bonus")
	var cooldown: float = renderer._get_effective_skill_cooldown_seconds(skill_data, hover_context)
	_expect(abs(cooldown - 32.0) < 0.01, "Dual Glitch tooltip cooldown should include Four Poisons reduction")


func _activate_dual_glitch(
	runtime: Object,
	input: Object,
	player_pos: Vector2,
	gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	for key in ["left_pressed", "right_pressed", "left_pressed", "right_pressed"]:
		input.snapshot[key] = true
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		if bool(result.get("activated", false)):
			return result
		input.snapshot[key] = false
		runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	return result


func _advance_dual(runtime: Object, config: Dictionary, deps: Dictionary, player_pos: Vector2, frames: int) -> void:
	var effect_context: Dictionary = config.duplicate(true)
	effect_context["selected_character_type"] = "viper"
	effect_context["ball_active"] = true
	effect_context["player_pos"] = player_pos
	effect_context["player_paddle_size"] = Vector2(155.0, 50.0)
	for _i in range(frames):
		runtime.update_effects(1.0, Time.get_ticks_msec(), effect_context, deps)


func _make_runtime_bundle(four_poisons_level: int) -> Dictionary:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	perk_state.levels["four_poisons"] = four_poisons_level
	var deps := _deps(
		input,
		skill_config,
		skill_state,
		perk_state,
		FakeOrbHud.new(),
		FakeFeedback.new(),
		FakeAudio.new()
	)
	return {
		"runtime": runtime,
		"input": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"perk_state": perk_state,
		"deps": deps,
	}


func _deps(
	input: Object,
	skill_config: Object,
	skill_state: Object,
	perk_state: Object,
	orb: Object,
	feedback: Object,
	audio: Object
) -> Dictionary:
	return {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"runtime_perk_state": perk_state,
		"orb_hud_state": orb,
		"feedback": feedback,
		"audio": audio,
	}


func _base_config() -> Dictionary:
	return {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_size": 28.6,
		"hitbox_padding": 5.0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
