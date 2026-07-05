extends SceneTree

const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")
const ViperPlayerController := preload("res://scripts/characters/viper_player_controller.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")


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


class CapturingMotionStepper:
	var captured_context := {}

	func step(ball_pos: Vector2, _effective_move: Vector2, _ball_vel: Vector2, context: Dictionary) -> Dictionary:
		captured_context = context.duplicate(true)
		return {"event": "none", "ball_pos": ball_pos}


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name in ["blade_rush", "dark_blade", "marshal_kick"]

	func get_skill_cost(skill_name: String) -> float:
		if skill_name == "blade_rush":
			return 200.0
		if skill_name == "dark_blade":
			return 150.0
		if skill_name == "marshal_kick":
			return 80.0
		return 0.0


class FakeSkillState:
	var triggered: Array = []

	func trigger_configured_cooldown(skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		triggered.append(skill_name)

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakeAudio:
	var blade_spin := 0
	var blade_spin_stops := 0
	var blade_fire := 0
	var dash_start := 0
	var dash_delay := 0
	var dash_delay_stops := 0
	var dash_charge := 0

	func play_viper_blade_spin() -> void:
		blade_spin += 1

	func stop_viper_blade_spin() -> void:
		blade_spin_stops += 1

	func play_viper_blade() -> void:
		blade_fire += 1

	func play_dash_start(_is_half: bool) -> void:
		dash_start += 1

	func play_dash_delay() -> void:
		dash_delay += 1

	func stop_dash_delay() -> void:
		dash_delay_stops += 1

	func play_dash_charge() -> void:
		dash_charge += 1


class FakeOrbHud:
	var spins := 0
	var dash_spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1

	func trigger_dash_token_spin(_now_msec: int) -> void:
		dash_spins += 1


class FakeFeedback:
	var shakes := 0

	func set_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class FakeJetpack:
	var airborne := true
	var force_lands := 0
	# Mirrors viper_jetpack_state: the collision context Y is floor_y+offset_y. During blade
	# motion the real jetpack is not ticked, so these hold the FROZEN values from blade start.
	var stale_floor_y := 680.0
	var stale_offset_y := 0.0

	func is_airborne(_threshold: float = 10.0) -> bool:
		return airborne

	func force_land(_deps: Dictionary = {}) -> void:
		airborne = false
		force_lands += 1

	func get_ball_collision_context(player_pos: Vector2 = Vector2.ZERO, _paddle_size: Vector2 = Vector2.ZERO) -> Dictionary:
		var collision_pos: Vector2 = player_pos
		if player_pos != Vector2.ZERO:
			collision_pos = Vector2(player_pos.x, stale_floor_y + stale_offset_y)
		return {
			"player_pos": collision_pos,
			"player_y": collision_pos.y,
			"viper_jetpack_offset_y": stale_offset_y,
			"viper_jetpack_floor_y": stale_floor_y,
		}


class FakePerkState:
	var gold := 0
	var levels := {"blade_amp": 0}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(levels.get(skill_id, 0))

	func award_gold(amount: int) -> int:
		gold += max(0, amount)
		return gold


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


func _init() -> void:
	_test_dark_blade_unlock_catalog_wiring()
	_test_blade_touch_ball_sound_route_removed()
	_test_marshal_hit_dark_blade_window_and_handoff()
	_test_air_blade_activation_hit_and_dark_combo()
	_test_blade_prep_movement_fall_and_launch_jump()
	_test_dark_blade_rising_body_contact_accepts_upward_ball()
	_test_air_blade_descent_hit_point_follows_character()
	_test_blade_prep_actor_spin_context()
	_test_blade_amp_cost_homing_and_followup()
	_test_air_blade_dash_after_launch_delay()
	_test_air_blade_reset_round_stops_spin_sound()
	_test_dark_blade_post_fire_lateral_scale_geometry()
	_test_dark_blade_post_fire_lateral_halved_runtime()
	print("viper_blade_rush_port_smoke: ok")
	quit(0)


func _test_dark_blade_unlock_catalog_wiring() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var perk_state: Object = RuntimePerkState.new()
	var skill_config: Object = ViperSkillConfig.new()
	var owner := FakeOwner.new()
	var registry := RealViperRegistry.new(perk_state, skill_config)
	var unlock_data: Dictionary = catalog.get_perk_data("dark_blade")
	_expect(not unlock_data.is_empty(), "dark_blade should exist as the Dark Blade unlock perk")
	_expect(str(unlock_data.get("unlocks_skill", "")) == "dark_blade", "dark_blade perk should unlock the runtime dark_blade orb")
	_expect(str(unlock_data.get("name", "")) == "다크 블레이드", "dark_blade perk should use the Korean display name")
	_expect(not skill_config.is_skill_equipped("dark_blade"), "dark_blade should not be equipped before unlock")
	var icon_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/skills/viper_dark_blade_skill_orb.png")
	_expect(icon_texture != null, "Dark Blade orb PNG should load from Godot skill assets")

	unlock_data["id"] = "dark_blade"
	_expect(perk_state.apply_choice(unlock_data, owner, registry), "selecting dark_blade should apply cleanly")
	_expect(perk_state.get_runtime_skill_level("dark_blade") == 1, "Dark Blade unlock should set the runtime perk level gate")
	_expect(skill_config.is_skill_equipped("dark_blade"), "Dark Blade unlock should equip the runtime dark_blade skill")
	_expect(abs(skill_config.get_skill_cost("dark_blade") - 150.0) < 0.01, "Dark Blade gauge cost should be 150")
	_expect(abs(float(skill_config.get_skill_data("dark_blade").get("cost", 0.0)) - 150.0) < 0.01, "Dark Blade tooltip cost should be 150")


func _test_blade_touch_ball_sound_route_removed() -> void:
	var audio_source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	var router_source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_audio_router.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_runtime.gd")
	_expect(audio_source.find("bladetouchball.wav") < 0, "removed Viper blade ball-touch SFX should not be loaded by GameAudio")
	_expect(router_source.find("play_blade_touch_ball_sound") < 0, "Viper audio router should not expose the removed ball-touch cue")
	_expect(runtime_source.find("play_blade_touch_ball_sound") < 0, "Viper blade hit path should not call the removed ball-touch cue")


func _test_marshal_hit_dark_blade_window_and_handoff() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var jetpack := FakeJetpack.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, jetpack, perk_state)
	var config := _base_config()
	config["boss_pos"] = Vector2(330.0, 25.0)
	config["boss_paddle_width"] = 100.0
	config["ball_pos"] = Vector2(640.0, 350.0)
	config["ball_vel"] = Vector2(0.0, -8.0)
	config["ball_impact_boost"] = 1.0
	var player_pos := Vector2(302.5, 680.0)
	var gauge := 450.0
	runtime.open_marshal_kick_window()

	input.snapshot["down_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	_expect(bool(result.get("activated", false)), "marshal kick should activate from the chained S window")
	_expect(str(result.get("skill_name", "")) == "marshal_kick", "first chained activation should use marshal_kick")
	_expect(skill_state.triggered.back() == "marshal_kick", "marshal kick should trigger its configured cooldown")
	input.snapshot["down_pressed"] = false
	player_pos = _get_vector2(result, "player_pos", player_pos)
	gauge = float(result.get("special_gauge", gauge))

	var hit_result: Dictionary = {}
	for _i in range(90):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		gauge = float(result.get("special_gauge", gauge))
		if result.has("ball_vel"):
			hit_result = result
			break
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	_expect(hit_result.has("ball_vel"), "marshal kick should hit the live-tracked ball")
	var snap: Dictionary = runtime.get_snapshot()
	_expect(bool(snap.get("dark_blade_window", false)), "marshal hit should open the Dark Blade follow-up window")
	_expect(bool(snap.get("marshal_active", false)), "marshal should still be active before the Dark Blade handoff")

	jetpack.airborne = false
	input.snapshot["up_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	_expect(bool(result.get("activated", false)), "W during Marshal return should hand off into Dark Blade even without jetpack airborne state")
	_expect(str(result.get("skill_name", "")) == "dark_blade", "marshal handoff should activate dark_blade")
	_expect(skill_state.triggered.back() == "dark_blade", "marshal handoff should trigger dark_blade cooldown")
	snap = runtime.get_snapshot()
	_expect(not bool(snap.get("marshal_active", true)), "Dark Blade handoff should cancel the Marshal runtime")
	_expect(not bool(snap.get("dark_blade_window", true)), "Dark Blade handoff should consume the combo window")
	_expect(bool(snap.get("blade_motion_active", false)), "Dark Blade handoff should enter blade motion")
	_expect(bool(snap.get("blade_dark_mode", false)), "Dark Blade handoff should use the dark blade variant")
	input.snapshot["up_pressed"] = false


func _test_air_blade_activation_hit_and_dark_combo() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var jetpack := FakeJetpack.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, jetpack, perk_state)
	var config := _base_config()
	var player_pos := Vector2(302.5, 560.0)

	input.snapshot["up_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "air blade should activate on an airborne W edge")
	_expect(str(result.get("skill_name", "")) == "blade_rush", "normal airborne W should use blade_rush")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 300.0) < 0.01, "air blade should spend the original 200 gauge")
	_expect(skill_state.triggered.back() == "blade_rush", "air blade should trigger its own cooldown")
	_expect(audio.blade_spin == 1, "air blade startup should play bladeafter.wav")
	_expect(audio.blade_spin_stops == 0, "air blade startup should keep bladeafter.wav alive during the rolling prep")
	_expect(orb.spins == 1, "air blade should spin the skill orb once")

	input.snapshot["up_pressed"] = false
	player_pos = _get_vector2(result, "player_pos", player_pos)
	for _i in range(36):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 300.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
	var snap: Dictionary = runtime.get_snapshot()
	_expect(bool(snap.get("blade_motion_active", false)), "air blade should keep the player in the launch motion")
	_expect(int(snap.get("blade_motion_phase", -1)) == 2, "air blade should enter phase 2 after spin and decel")
	_expect(bool(snap.get("blade_projectile_active", false)), "air blade should fire the projectile after the decel")
	_expect(audio.blade_spin_stops == 1, "air blade should stop bladeafter.wav when the rolling prep ends")
	_expect(audio.blade_fire == 1, "projectile launch should play blade.wav")
	_expect(abs(float(snap.get("blade_projectile_width", 0.0)) - 350.0) < 0.01, "normal blade width should match the Python 350px base")

	var projectile_pos: Vector2 = _get_vector2(snap, "blade_projectile_pos", Vector2.ZERO)
	var scene := {
		"ball_pos": projectile_pos + Vector2(0.0, -24.0),
		"ball_vel": Vector2(0.0, -30.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}
	var motion_context: Dictionary = config.duplicate(true)
	motion_context.merge(scene, true)
	result = runtime.apply_blade_rush_ball_motion(1.0, scene, motion_context, deps)
	_expect(result.has("ball_vel"), "blade hitbox should strike the ball once")
	_expect(abs(_get_vector2(result, "ball_vel", Vector2.ZERO).length() - 40.0) <= 0.001, "air blade should cap ball speed at 40 regardless of league")
	_expect(float(runtime.get_blade_hit_speed_cap()) == 40.0, "air blade cap should remain active after the blade hit")
	_expect(_get_vector2(result, "ball_vel", Vector2.ZERO).y < 0.0, "air blade should force the ball upward")
	_expect(perk_state.gold == 30, "air blade ball hit should grant 30 skill gold")
	_expect(audio.blade_fire == 1, "air blade ball hit should not replay projectile-launch audio")
	_expect(not bool(runtime.get_snapshot().get("marshal_ready", false)), "normal air blade should not directly open marshal kick")

	for _i in range(30):
		runtime.update_effects(1.0, Time.get_ticks_msec(), motion_context, deps)
	_expect(bool(runtime.get_snapshot().get("blade_air_combo_window", false)), "air blade should open the dark-blade follow-up window after 0.5s")
	input.snapshot["up_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 300.0, config, deps)
	_expect(bool(result.get("activated", false)), "air blade phase 2 W should chain into dark blade when equipped")
	_expect(str(result.get("skill_name", "")) == "dark_blade", "air blade follow-up should activate dark_blade")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 150.0) < 0.01, "dark blade follow-up should spend 150 gauge")
	_expect(skill_state.triggered.back() == "dark_blade", "dark blade follow-up should trigger dark_blade cooldown")
	_expect(audio.blade_spin == 2, "dark blade follow-up should replay the spin sound")
	_expect(not bool(runtime.get_snapshot().get("blade_projectile_active", true)), "dark blade follow-up should clear the previous air blade projectile")
	input.snapshot["up_pressed"] = false
	player_pos = _get_vector2(result, "player_pos", player_pos)
	for _i in range(90):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 150.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
	snap = runtime.get_snapshot()
	_expect(bool(snap.get("blade_projectile_active", false)), "dark blade should fire its projectile after the dark prep")
	projectile_pos = _get_vector2(snap, "blade_projectile_pos", Vector2.ZERO)
	scene = {
		"ball_pos": projectile_pos + Vector2(0.0, -24.0),
		"ball_vel": Vector2(0.0, -30.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}
	motion_context = config.duplicate(true)
	motion_context.merge(scene, true)
	result = runtime.apply_blade_rush_ball_motion(1.0, scene, motion_context, deps)
	_expect(result.has("ball_vel"), "dark blade hitbox should strike the ball once")
	_expect(abs(_get_vector2(result, "ball_vel", Vector2.ZERO).length() - 50.0) <= 0.001, "dark blade should cap ball speed at 50 regardless of league")
	_expect(float(runtime.get_blade_hit_speed_cap()) == 50.0, "dark blade cap should remain active after the blade hit")
	_expect(audio.blade_fire == 2, "dark blade ball hit should not replay projectile-launch audio")


func _test_blade_prep_movement_fall_and_launch_jump() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var jetpack := FakeJetpack.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, jetpack, perk_state)
	var config := _base_config()
	var player_pos := Vector2(302.5, 560.0)
	var player_speed := 0.0

	input.snapshot["up_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	player_pos = _get_vector2(result, "player_pos", player_pos)
	player_speed = float(result.get("player_speed", player_speed))
	input.snapshot["up_pressed"] = false
	input.snapshot["right_pressed"] = true
	input.snapshot["direction"] = 1.0
	var start_pos: Vector2 = player_pos

	for _i in range(12):
		config["player_speed"] = player_speed
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 300.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		player_speed = float(result.get("player_speed", player_speed))
	_expect(player_pos.x > start_pos.x + 6.0, "blade prep should keep original left/right air control")
	_expect(player_pos.y > start_pos.y + 25.0, "blade prep should slowly fall while jetpack input is blocked")
	_expect(player_speed > 0.5, "blade prep should preserve horizontal velocity instead of zero-locking")

	for _i in range(24):
		config["player_speed"] = player_speed
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 300.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		player_speed = float(result.get("player_speed", player_speed))
	var snap: Dictionary = runtime.get_snapshot()
	_expect(int(snap.get("blade_motion_phase", -1)) == 2, "blade should enter launch phase after spin and decel")
	var phase2_entry_y: float = player_pos.y
	config["player_speed"] = player_speed
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 300.0)), config, deps)
	player_pos = _get_vector2(result, "player_pos", player_pos)
	_expect(player_pos.y < phase2_entry_y, "blade launch should pop upward from the falling prep position")

	for _i in range(30):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	input.snapshot["up_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 300.0, config, deps)
	_expect(str(result.get("skill_name", "")) == "dark_blade", "air blade follow-up should still be available after mobile prep")
	_expect(_get_vector2(result, "player_pos", player_pos).y <= _get_blade_floor_y(config) - 120.0, "blade follow-up should add the original upward re-cast pop")


func _test_dark_blade_rising_body_contact_accepts_upward_ball() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var jetpack := FakeJetpack.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, jetpack, perk_state)
	var config := _base_config()
	var player_pos := Vector2(302.5, 560.0)
	var result: Dictionary = runtime._start_blade_motion(player_pos, 500.0, config, deps, true, Time.get_ticks_msec())
	player_pos = _get_vector2(result, "player_pos", player_pos)

	for _i in range(90):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 300.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		var snap: Dictionary = runtime.get_snapshot()
		if int(snap.get("blade_motion_phase", -1)) == 2 and float(snap.get("blade_motion_frames", 0.0)) > 1.0:
			break

	var collision_context: Dictionary = config.duplicate(true)
	collision_context["player_pos"] = player_pos
	collision_context.merge(runtime.get_ball_collision_context(), true)
	_expect(bool(collision_context.get("viper_dark_blade_rising_contact_active", false)), "dark blade launch rise should expose a body-contact collision flag")
	var actor_draw_context: Dictionary = config.duplicate(true)
	actor_draw_context["selected_character_type"] = "viper"
	actor_draw_context["player_pos"] = player_pos
	actor_draw_context["player_paddle_size"] = _get_vector2(collision_context, "player_paddle_size", Vector2(155.0, 50.0))
	var actor_context: Dictionary = BattleDrawActorContext.new().build(actor_draw_context, {"viper_skill_runtime": runtime})
	_expect(_same_vector2(_get_vector2(actor_context, "player_pos", Vector2.INF), _get_vector2(collision_context, "player_pos", Vector2.ZERO)), "dark blade rising draw position should match the ball-hit position")
	_expect(_same_vector2(_get_vector2(actor_context, "player_paddle_size", Vector2.ZERO), _get_vector2(collision_context, "player_paddle_size", Vector2.INF)), "dark blade rising draw size should match the ball-hit size")

	var processor := BallMotionEventProcessor.new()
	var capturing_stepper := CapturingMotionStepper.new()
	var scene := {
		"ball_pos": player_pos + Vector2(77.5, 25.0),
		"ball_vel": Vector2(0.0, -12.0),
		"player_collision_cooldown": 0.0,
	}
	processor.step_motion(scene, 1.0, collision_context, {"motion_stepper": capturing_stepper}, {})
	_expect(bool(capturing_stepper.captured_context.get("viper_dark_blade_rising_contact_active", false)), "ball event processor should preserve the dark-blade rise contact flag for collision")
	var test_ball_pos: Vector2 = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	var test_ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var step_result: Dictionary = BallMotionStepper.new().step(
		test_ball_pos,
		Vector2.ZERO,
		test_ball_vel,
		capturing_stepper.captured_context
	)
	_expect(str(step_result.get("event", "")) == "player_paddle", "dark blade rising body should count as a player hit even when the ball is moving upward")

	for _i in range(30):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 300.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
	collision_context = config.duplicate(true)
	collision_context["player_pos"] = player_pos
	collision_context.merge(runtime.get_ball_collision_context(), true)
	_expect(not bool(collision_context.get("viper_dark_blade_rising_contact_active", false)), "dark blade body-contact extension should close after the upward pop")


func _test_air_blade_descent_hit_point_follows_character() -> void:
	# Regression: air blade (blade_rush, NOT dark mode) entered from the air leaves the jetpack
	# offset_y FROZEN high (the jetpack is not ticked during blade motion). The ball-collision
	# frame context merges the stale jetpack Y FIRST, then the viper-skill context. Before the fix
	# the skill context did NOT re-anchor player_pos for air blade, so the paddle hit-point stayed
	# frozen above the descending character during the phase-2 come-down — the reported bug.
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var jetpack := FakeJetpack.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, jetpack, perk_state)
	var config := _base_config()
	var floor_y: float = _get_blade_floor_y(config)
	# Simulate "entered air blade from the air": the jetpack froze at a high (negative) offset.
	jetpack.stale_floor_y = floor_y
	jetpack.stale_offset_y = -150.0

	var player_pos := Vector2(302.5, 560.0)
	input.snapshot["up_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "air blade should activate for the descent hit-point regression")
	player_pos = _get_vector2(result, "player_pos", player_pos)
	input.snapshot["up_pressed"] = false

	# Advance into phase 2 well past the jump-up frames so the character is descending.
	var descent_reached := false
	for _i in range(120):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 300.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		var snap: Dictionary = runtime.get_snapshot()
		if int(snap.get("blade_motion_phase", -1)) == 2 and float(snap.get("blade_motion_frames", 0.0)) > 30.0:
			descent_reached = true
			break
	_expect(descent_reached, "air blade should reach the phase-2 descent window")
	var phase_snap: Dictionary = runtime.get_snapshot()
	_expect(not bool(phase_snap.get("blade_dark_mode", true)), "scenario must run as AIR blade, not dark blade")

	var arc_y: float = player_pos.y  # live drawn position (== blade_motion_pos.y)
	var stale_y: float = floor_y + jetpack.stale_offset_y

	# Replicate ball_update_controller._build_frame_context merge order exactly:
	# canonical owner pos -> jetpack collision context (stale) -> viper skill collision context.
	var frame_context: Dictionary = config.duplicate(true)
	frame_context["player_pos"] = player_pos
	frame_context["player_y"] = player_pos.y
	frame_context.merge(jetpack.get_ball_collision_context(player_pos, Vector2(155.0, 50.0)), true)
	var stomped_y: float = _get_vector2(frame_context, "player_pos", Vector2.ZERO).y
	_expect(abs(stomped_y - stale_y) < 1.0, "sanity: the stale jetpack must stomp the collision Y to its frozen airborne height")
	_expect(abs(stale_y - arc_y) > 40.0, "sanity: the stale jetpack Y must differ clearly from the live descending arc Y")

	frame_context.merge(runtime.get_ball_collision_context(), true)
	var final_y: float = _get_vector2(frame_context, "player_pos", Vector2.ZERO).y
	_expect(abs(final_y - arc_y) < 1.0, "air blade collision hit-point Y must follow the descending character, not the stale jetpack offset")
	_expect(not bool(frame_context.get("viper_dark_blade_rising_contact_active", false)), "air blade must not enable the dark-blade upward-contact path")

	# OUTCOME seal: a descending ball over the LIVE character band registers a player paddle hit.
	# Pre-fix the paddle rect sat ~76px above (stale Y) so this ball would miss entirely.
	var detector := BallMotionCollisionDetector.new()
	var ball_at_live := Vector2(player_pos.x + 77.5, arc_y + 25.0)
	var hit_live: Dictionary = detector.check_paddles(ball_at_live, Vector2(0.0, 12.0), 28.6, frame_context)
	_expect(str(hit_live.get("event", "")) == "player_paddle", "descending ball at the live character band must register a player paddle hit")
	# And the same descending ball at the STALE band must NOT hit the (now re-anchored) paddle.
	var ball_at_stale := Vector2(player_pos.x + 77.5, stale_y + 25.0)
	var hit_stale: Dictionary = detector.check_paddles(ball_at_stale, Vector2(0.0, 12.0), 28.6, frame_context)
	_expect(str(hit_stale.get("event", "")) != "player_paddle", "ball at the old stale jetpack band must no longer find the paddle")


func _test_blade_prep_actor_spin_context() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var jetpack := FakeJetpack.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, jetpack, perk_state)
	var config := _base_config()
	var player_pos := Vector2(302.5, 560.0)

	input.snapshot["up_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	player_pos = _get_vector2(result, "player_pos", player_pos)
	input.snapshot["up_pressed"] = false
	for _i in range(6):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 300.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)

	var runtime_actor_context: Dictionary = runtime.get_actor_draw_context()
	_expect(bool(runtime_actor_context.get("viper_blade_motion_active", false)), "blade prep should expose actor spin while active")
	_expect(float(runtime_actor_context.get("player_sprite_rotation_degrees", 0.0)) > 1.0, "blade prep should rotate the actual player sprite")

	var draw_context: Dictionary = config.duplicate(true)
	draw_context["player_pos"] = player_pos
	draw_context["selected_character_type"] = "viper"
	var actor_context: Dictionary = BattleDrawActorContext.new().build(draw_context, {"viper_skill_runtime": runtime})
	_expect(float(actor_context.get("player_sprite_rotation_degrees", 0.0)) > 1.0, "battle actor context should pass Viper blade spin to the renderer")

	for _i in range(32):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 300.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
	runtime_actor_context = runtime.get_actor_draw_context()
	_expect(int(runtime_actor_context.get("viper_blade_motion_phase", -1)) == 2, "blade launch phase should stop sprite spin like the original")
	_expect(not runtime_actor_context.has("player_sprite_rotation_degrees") or abs(float(runtime_actor_context.get("player_sprite_rotation_degrees", 0.0))) <= 0.01, "blade launch phase should reset the sprite rotation")


func _test_blade_amp_cost_homing_and_followup() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var jetpack := FakeJetpack.new()
	var perk_state := FakePerkState.new()
	perk_state.levels["blade_amp"] = 12
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, jetpack, perk_state)
	var config := _base_config()
	var player_pos := Vector2(302.5, 560.0)

	input.snapshot["up_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(abs(float(result.get("special_gauge", 0.0)) - 400.0) < 0.01, "blade_amp overflow should reduce blade cost down to the 100 minimum")
	input.snapshot["up_pressed"] = false
	player_pos = _get_vector2(result, "player_pos", player_pos)
	for _i in range(36):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 400.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
	var snap: Dictionary = runtime.get_snapshot()
	_expect(abs(float(snap.get("blade_projectile_width", 0.0)) - 525.0) < 0.01, "blade_amp width/range scaling should cap at Lv5 for +50% width")
	var start_pos: Vector2 = _get_vector2(snap, "blade_projectile_pos", Vector2.ZERO)
	var scene := {
		"ball_pos": start_pos + Vector2(220.0, -400.0),
		"ball_vel": Vector2(0.0, -8.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}
	var motion_context: Dictionary = config.duplicate(true)
	motion_context.merge(scene, true)
	runtime.apply_blade_rush_ball_motion(1.0, scene, motion_context, deps)
	snap = runtime.get_snapshot()
	_expect(_get_vector2(snap, "blade_projectile_pos", Vector2.ZERO).x > start_pos.x, "blade_amp Lv3+ should visibly home toward the ball X")

	scene["ball_pos"] = _get_vector2(snap, "blade_projectile_pos", Vector2.ZERO) + Vector2(0.0, -24.0)
	motion_context.merge(scene, true)
	result = runtime.apply_blade_rush_ball_motion(1.0, scene, motion_context, deps)
	_expect(result.has("ball_vel"), "amped blade should still hit through the enlarged hitbox")
	_expect(perk_state.gold == 30, "follow-up proc should not duplicate the primary blade gold")
	_expect((runtime.get_snapshot().get("blade_followup_projectiles", []) as Array).size() == 1, "blade_amp Lv12 should guarantee one non-recursive follow-up blade")


func _test_air_blade_dash_after_launch_delay() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var controller: Object = ViperPlayerController.new()
	var dash_state: Object = SmasherDashState.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var jetpack := FakeJetpack.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, jetpack, perk_state)
	deps["dash_state"] = dash_state
	deps["viper_skill_runtime"] = runtime
	var config := _base_config()
	var frame_counter := 0
	var player_pos := Vector2(302.5, 560.0)
	var player_speed := 0.0
	var special_gauge := 500.0

	input.snapshot["up_pressed"] = true
	var result: Dictionary = controller.update(1.0 / 60.0, frame_counter, player_pos, player_speed, config, deps)
	frame_counter = int(result.get("frame_counter", frame_counter + 1))
	player_pos = _get_vector2(result, "player_pos", player_pos)
	player_speed = float(result.get("player_speed", player_speed))
	special_gauge = float(result.get("special_gauge", special_gauge))
	input.snapshot["up_pressed"] = false

	for _i in range(36):
		config["special_gauge"] = special_gauge
		result = controller.update(1.0 / 60.0, frame_counter, player_pos, player_speed, config, deps)
		frame_counter = int(result.get("frame_counter", frame_counter + 1))
		player_pos = _get_vector2(result, "player_pos", player_pos)
		player_speed = float(result.get("player_speed", player_speed))
		special_gauge = float(result.get("special_gauge", special_gauge))
	var snap: Dictionary = runtime.get_snapshot()
	_expect(int(snap.get("blade_motion_phase", -1)) == 2, "controller path should enter air blade launch phase")
	_expect(bool(snap.get("blade_projectile_active", false)), "controller path should fire the blade before the dash window")

	input.snapshot["down_pressed"] = true
	input.snapshot["right_pressed"] = true
	input.snapshot["direction"] = 1.0
	for _i in range(17):
		config["special_gauge"] = special_gauge
		result = controller.update(1.0 / 60.0, frame_counter, player_pos, player_speed, config, deps)
		frame_counter = int(result.get("frame_counter", frame_counter + 1))
		player_pos = _get_vector2(result, "player_pos", player_pos)
		player_speed = float(result.get("player_speed", player_speed))
		special_gauge = float(result.get("special_gauge", special_gauge))
	_expect(not bool(dash_state.get_snapshot().get("active", false)), "air blade should not dash before the 0.3s post-fire delay")

	var pre_dash_x: float = player_pos.x
	config["special_gauge"] = special_gauge
	result = controller.update(1.0 / 60.0, frame_counter, player_pos, player_speed, config, deps)
	player_pos = _get_vector2(result, "player_pos", player_pos)
	player_speed = float(result.get("player_speed", player_speed))
	snap = runtime.get_snapshot()
	_expect(bool(dash_state.get_snapshot().get("active", false)), "air blade should allow dash 0.3s after projectile fire")
	_expect(audio.dash_start == 1, "air blade dash cancel should route through the normal dash audio path")
	_expect(player_pos.x > pre_dash_x + 10.0, "air blade dash cancel should move horizontally through the dash controller")
	_expect(bool(snap.get("blade_motion_active", false)), "dash cancel should keep air blade landing motion alive")
	_expect(player_pos.y < _get_blade_floor_y(config), "dash cancel should happen before Viper lands")


func _test_air_blade_reset_round_stops_spin_sound() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var jetpack := FakeJetpack.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, jetpack, perk_state)
	var config := _base_config()
	var player_pos := Vector2(302.5, 560.0)

	input.snapshot["up_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "air blade should activate before the round-boundary reset smoke")
	_expect(audio.blade_spin == 1, "air blade startup should play bladeafter.wav before reset")
	_expect(audio.blade_spin_stops == 0, "air blade spin should still be active before reset")

	runtime.reset_round(deps)
	_expect(audio.blade_spin_stops == 1, "Viper reset_round should stop bladeafter.wav through the stored audio fallback")
	_expect(not bool(runtime.get_snapshot().get("blade_motion_active", true)), "Viper reset_round should clear active blade motion")
	_expect(not runtime.blade_spin_sound_active, "Viper reset_round should clear blade spin sound state")
	_expect(runtime.blade_spin_audio == null, "Viper reset_round should release the stored blade spin audio owner")


func _test_dark_blade_post_fire_lateral_scale_geometry() -> void:
	# The geometry damp must scale BOTH cap and accel, so from rest the realized speed is
	# exactly 50% at every frame (saturated cap is exactly halved).
	var config := {
		"paddle_max_speed": 4.0,
		"paddle_speed": 4.0,
		"paddle_accel": 0.38,
		"paddle_decel": 0.38,
		"paddle_turn_decel": 1.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"width": 760.0,
	}
	var floor_y := 680.0
	var airborne_y := floor_y - 320.0  # Dark Blade jump peak, above the 200 jetpack ceiling
	var speed_full: float = _blade_lateral_speed_after(config, floor_y, airborne_y, 1.0, 40)
	var speed_half: float = _blade_lateral_speed_after(config, floor_y, airborne_y, 0.5, 40)
	_expect(speed_full > 30.0, "dark airborne lateral cap should saturate near the ~37.8px/frame stack")
	_expect(speed_half < speed_full, "post-fire scale 0.5 must reduce the dark lateral cap")
	_expect(abs(speed_half - speed_full * 0.5) < 0.001, "dark post-fire lateral cap should be exactly 50% of unscaled")


func _blade_lateral_speed_after(config: Dictionary, floor_y: float, y: float, scale: float, frames: int) -> float:
	var player_speed := 0.0
	var pos := Vector2(380.0, y)
	for _i in range(frames):
		var result: Dictionary = ViperSkillGeometry.blade_horizontal_control_motion(
			pos, player_speed, 1.0, 1.0, config, floor_y, 155.0, 200.0, 2.15, true, scale
		)
		player_speed = float(result.get("player_speed", player_speed))
	return player_speed


func _test_dark_blade_post_fire_lateral_halved_runtime() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var jetpack := FakeJetpack.new()
	var perk_state := FakePerkState.new()
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, jetpack, perk_state)
	var config := _base_config()
	var player_pos := Vector2(302.5, 560.0)
	var result: Dictionary = runtime._start_blade_motion(player_pos, 500.0, config, deps, true, Time.get_ticks_msec())
	player_pos = _get_vector2(result, "player_pos", player_pos)
	var player_speed := 0.0
	# Advance until the projectile has fired and the blade is in phase 2 (the "after fire" window).
	for _i in range(120):
		config["player_speed"] = player_speed
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 300.0)), config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		player_speed = float(result.get("player_speed", player_speed))
		var snap: Dictionary = runtime.get_snapshot()
		if int(snap.get("blade_motion_phase", -1)) == 2 and float(snap.get("blade_motion_frames", 0.0)) > 1.0:
			break
	var phase_snap: Dictionary = runtime.get_snapshot()
	_expect(int(phase_snap.get("blade_motion_phase", -1)) == 2, "dark blade should reach the post-fire phase 2")
	_expect(bool(phase_snap.get("blade_dark_mode", false)), "scenario should run in dark blade mode")
	_expect(bool(phase_snap.get("blade_projectile_active", false)), "dark blade should fire its projectile before lateral steering is measured")

	# Hold right for one frame and compare the realized lateral step against the scaled vs
	# unscaled geometry expectation for the exact same (pos, speed, height).
	input.snapshot["right_pressed"] = true
	input.snapshot["direction"] = 1.0
	var pos_before := player_pos
	var speed_before := player_speed
	config["player_speed"] = speed_before
	result = runtime.try_activate_before_movement(1.0 / 60.0, pos_before, float(result.get("special_gauge", 300.0)), config, deps)
	var realized_dx: float = _get_vector2(result, "player_pos", pos_before).x - pos_before.x
	input.snapshot["right_pressed"] = false
	input.snapshot["direction"] = 0.0

	var geom_config := {
		"paddle_max_speed": 4.0, "paddle_speed": 4.0, "paddle_accel": 0.38, "paddle_decel": 0.38,
		"paddle_turn_decel": 1.0, "play_left": 0.0, "play_right": 760.0, "width": 760.0,
	}
	var floor_y := float(config.get("player_floor_y", 680.0))
	var full: Dictionary = ViperSkillGeometry.blade_horizontal_control_motion(pos_before, speed_before, 1.0, 1.0, geom_config, floor_y, 155.0, 200.0, 2.15, true, 1.0)
	var half: Dictionary = ViperSkillGeometry.blade_horizontal_control_motion(pos_before, speed_before, 1.0, 1.0, geom_config, floor_y, 155.0, 200.0, 2.15, true, 0.5)
	var full_dx: float = _get_vector2(full, "player_pos", pos_before).x - pos_before.x
	var half_dx: float = _get_vector2(half, "player_pos", pos_before).x - pos_before.x
	_expect(full_dx > half_dx + 0.01, "unscaled vs scaled geometry expectations must diverge for a valid wiring check")
	_expect(abs(realized_dx - half_dx) < 0.05, "dark post-fire lateral step should match the 50%-scaled geometry, not full speed")
	_expect(abs(realized_dx - full_dx) > 0.05, "dark post-fire lateral step must NOT use the full (unscaled) lateral speed")

	# Gate guard: the damp must be scoped to dark mode AND phase 2 so air blade keeps full control.
	var motion_source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_blade_motion_runtime.gd")
	_expect(motion_source.find("runtime.blade_dark_mode and runtime.blade_motion_phase >= 2") >= 0, "post-fire lateral damp must be gated on dark mode AND phase 2 (air blade unaffected)")


func _deps(
	input: Object,
	skill_config: Object,
	skill_state: Object,
	audio: Object,
	orb: Object,
	feedback: Object,
	jetpack: Object,
	perk_state: Object
) -> Dictionary:
	return {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"audio": audio,
		"orb_hud_state": orb,
		"feedback": feedback,
		"viper_jetpack_state": jetpack,
		"viper_skill_runtime": null,
		"runtime_perk_state": perk_state,
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
		"player_floor_y": 680.0,
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_size": 28.6,
		"special_gauge": 500.0,
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


func _get_blade_floor_y(config: Dictionary) -> float:
	return float(config.get("player_floor_y", 680.0))


func _same_vector2(left: Vector2, right: Vector2, epsilon: float = 0.01) -> bool:
	return left.distance_to(right) <= epsilon
