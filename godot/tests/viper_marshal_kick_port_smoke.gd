extends SceneTree

const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const SkillCutinOverlayHost := preload("res://scripts/hud/skill_cutin_overlay_host.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ViperPhantomKickCutinState := preload("res://scripts/characters/viper_phantom_kick_cutin_state.gd")

const PHANTOM_CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/viper_phantom_kick_cutin_sheet.png"
const PHANTOM_CUTIN_SHEET_SIZE := 8192


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
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name in ["shadow_step", "marshal_kick", "phantom_kick", "dark_blade"]

	func get_skill_cost(skill_name: String) -> float:
		if skill_name == "phantom_kick":
			return 60.0
		if skill_name == "marshal_kick":
			return 80.0
		if skill_name == "dark_blade":
			return 150.0
		if skill_name == "shadow_step":
			return 100.0
		return 0.0


class FakeSkillState:
	var triggered: Array = []

	func trigger_configured_cooldown(skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		triggered.append(skill_name)

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakeAudio:
	var backstep := 0
	var marshal_charge := 0
	var phantom_show := 0
	var phantom_hit := 0
	var shadow_kick := 0
	var dash_start := 0

	func play_viper_backstep() -> void:
		backstep += 1

	func play_viper_marshal_kick() -> void:
		marshal_charge += 1

	func play_viper_shadow_kick() -> void:
		shadow_kick += 1

	func play_viper_phantom_show() -> void:
		phantom_show += 1

	func play_viper_phantom_kick_hit() -> void:
		phantom_hit += 1

	func play_dash_start(_is_half: bool) -> void:
		dash_start += 1


class FakeFeedback:
	var shakes := 0

	func set_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class FakeOrbHud:
	var spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1


class FakePerkState:
	var gold := 0
	var levels := {
		"double_marshal_kick": 1,
		"kick_enhance": 0,
	}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(levels.get(skill_id, 0))

	func award_gold(amount: int) -> int:
		gold += max(0, amount)
		return gold


class FakeStageBackground:
	var absorbed := 0

	func absorb_chaos_spear_objects(_center: Vector2, radius: float, _deps: Dictionary = {}) -> Array:
		absorbed += 1
		return [{"position": Vector2(640.0, 350.0), "strength": radius / 150.0}]


class FakeAiState:
	var knockback_vel := 0.0

	func start_paddle_hit_knockback(velocity: float, _frames: float = 36.0, _decay_per_frame: float = 0.88, _replace_current: bool = true) -> void:
		knockback_vel = velocity


class FakeBossGuardMotionStepper:
	func step(ball_pos: Vector2, _motion_delta: Vector2, _ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		return {
			"ball_pos": ball_pos,
			"event": "boss_paddle",
			"paddle_x": 330.0,
			"paddle_w": 100.0,
			"is_player": false,
		}


class FakeOwner:
	var selected_character_type := "viper"
	var player_pos := Vector2(302.5, 680.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
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
	_test_phantom_kick_cutin_state()
	_test_phantom_kick_cutin_host_prewarms_sheet()
	_test_phantom_kick_unlock_catalog_wiring()
	_test_phantom_kick_speed_limit_lifecycle()
	_test_shadow_chain_marshal_prep_retime()

	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var orb := FakeOrbHud.new()
	var perk_state := FakePerkState.new()
	var stage_background := FakeStageBackground.new()
	var ai_state := FakeAiState.new()
	var deps := {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"audio": audio,
		"feedback": feedback,
		"orb_hud_state": orb,
		"runtime_perk_state": perk_state,
		"stage_background": stage_background,
		"ai_state": ai_state,
	}
	var config := {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_floor_y": 680.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(380.0, 45.0),
		"boss_paddle_width": 100.0,
		"ball_pos": Vector2(640.0, 350.0),
		"ball_vel": Vector2(0.0, -8.0),
		"ball_impact_boost": 1.0,
	}
	var player_pos := Vector2(302.5, 680.0)
	var gauge := 200.0
	runtime.shadow_was_airborne = true
	runtime.open_marshal_kick_window()

	input.snapshot["down_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	_expect(bool(result.get("activated", false)), "marshal kick should activate from the chained S window")
	_expect(str(result.get("skill_name", "")) == "marshal_kick", "first chained activation should be marshal_kick")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 120.0) < 0.01, "marshal kick should spend 80 gauge")
	_expect(skill_state.triggered.back() == "marshal_kick", "marshal kick should trigger its own cooldown")
	_expect(audio.backstep == 1 and audio.dash_start == 0, "marshal kick startup should use the original backstep sound")
	var snap: Dictionary = runtime.get_snapshot()
	_expect(bool(snap.get("marshal_active", false)), "marshal kick should enter the wall-dive runtime")
	_expect(not bool(snap.get("marshal_is_double", false)), "first marshal kick should not be marked as phantom")
	_expect((snap.get("marshal_web_lines", []) as Array).size() == 1, "marshal kick should fire the wall rope line")

	player_pos = _get_vector2(result, "player_pos", player_pos)
	gauge = float(result.get("special_gauge", gauge))
	var hit_result: Dictionary = {}
	for _i in range(90):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		gauge = float(result.get("special_gauge", gauge))
		runtime.update_effects(1.0, Time.get_ticks_msec(), _context_with_gauge(config, gauge), deps)
		if result.has("ball_vel"):
			hit_result = result
			break
	_expect(hit_result.has("ball_vel"), "marshal kick should hit the live-tracked ball during the charge")
	_expect(_get_vector2(hit_result, "ball_vel", Vector2.ZERO).length() >= 17.5, "marshal kick should use the original 2.2x speed path")
	_expect(audio.marshal_charge == 1, "marshal charge should play the original marshal/shadowkick sound")
	_expect(perk_state.gold == 45, "airborne shadow-step chained marshal hit should grant 45 gold")
	snap = runtime.get_snapshot()
	_expect(bool(snap.get("marshal_first_hit_pending", false)), "airborne first marshal hit should arm the phantom delay")
	_expect(bool(snap.get("shadow_starburst_active", false)), "marshal hit should trigger the starburst")
	_expect(not bool(snap.get("shadow_starburst_is_double", true)), "first marshal starburst should be the normal variant")
	_expect(bool(snap.get("dark_blade_window", false)), "marshal hit should open the Dark Blade combo window when equipped")
	_expect(stage_background.absorbed > 0, "marshal hit should destroy nearby stage objects through the impact hook")

	input.snapshot["down_pressed"] = false
	for _i in range(48):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		runtime.update_effects(1.0, Time.get_ticks_msec(), _context_with_gauge(config, 200.0), deps)
	snap = runtime.get_snapshot()
	_expect(not bool(snap.get("marshal_active", false)), "first marshal kick should finish returning before the phantom input")
	_expect(bool(snap.get("double_marshal_ready", false)), "phantom kick should open after the original 200ms second-chain delay")

	gauge = 200.0
	input.snapshot["down_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	_expect(bool(result.get("activated", false)), "phantom kick should activate from the second chained S window")
	_expect(str(result.get("skill_name", "")) == "phantom_kick", "second chained activation should use phantom_kick")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 140.0) < 0.01, "phantom kick should spend 60 gauge")
	_expect(skill_state.triggered.back() == "phantom_kick", "phantom kick should trigger phantom cooldown")
	_expect(audio.backstep == 2, "phantom startup should also use backstep")
	snap = runtime.get_snapshot()
	_expect(bool(snap.get("marshal_is_double", false)), "phantom kick should mark the wall dive as double marshal")
	_expect(bool(snap.get("phantom_aura_active", false)), "phantom kick should enable the dark aura")

	player_pos = _get_vector2(result, "player_pos", player_pos)
	gauge = float(result.get("special_gauge", gauge))
	var phantom_hit_result: Dictionary = {}
	var phantom_freeze_checked := false
	# Budget must cover the phantom wall-brace freeze (now 99f = 1.65s to match
	# the power-smash cut-in length) + phantom delay + charge + travel-to-ball.
	# Loop breaks on the hit, so a generous cap is safe.
	for _i in range(230):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		runtime.update_effects(1.0, Time.get_ticks_msec(), _context_with_gauge(config, gauge), deps)
		if audio.phantom_show == 1 and not phantom_freeze_checked:
			_expect(runtime.is_cutin_active(), "phantom kick freeze entry should start the full-screen cut-in")
			_expect(runtime.cutin_state.get_skill_name() == "phantom_kick", "phantom kick cut-in should keep the Viper profile")
			_expect(bool(runtime.get_snapshot().get("cutin_active", false)), "phantom kick snapshot should expose the active cut-in")
			_expect_phantom_show_freezes_ball_and_boss(runtime, config)
			phantom_freeze_checked = true
		if result.has("ball_vel"):
			phantom_hit_result = result
			break
	_expect(audio.phantom_show == 1, "phantom kick should play the original show sound at freeze entry")
	_expect(phantom_freeze_checked, "phantom kick show text should expose the freeze window before charge")
	_expect(phantom_hit_result.has("ball_vel"), "phantom kick should charge after the freeze and hit the ball")
	_expect(not runtime.is_cutin_active(), "phantom kick cut-in should finish by the live kick hit")
	_expect(_get_vector2(phantom_hit_result, "ball_vel", Vector2.ZERO).length() >= 22.3, "phantom kick should use the original 2.8x speed path")
	_expect(audio.phantom_hit == 1, "phantom kick ball hit should play the original hit sound")
	_expect(perk_state.gold == 120, "airborne phantom chain should add the original 75 gold")
	snap = runtime.get_snapshot()
	_expect(bool(snap.get("shadow_starburst_is_double", false)), "phantom hit should use the stronger starburst variant")
	_expect(bool(snap.get("dark_blade_window", false)), "phantom kick hit should refresh the Dark Blade combo window when equipped")
	_expect(bool(snap.get("phantom_kick_knockback_pending", false)), "phantom hit should arm boss-paddle knockback")
	_expect(bool(snap.get("phantom_kick_speed_limit_disabled", false)), "phantom hit should remove the ball speed cap until the boss guards")
	var phantom_collision_context: Dictionary = runtime.get_ball_collision_context()
	_expect(bool(phantom_collision_context.get("speed_limit_disabled", false)), "phantom hit should expose the uncapped speed context to ball physics")
	var phantom_particles: Array = snap.get("phantom_hit_particles", []) as Array
	_expect(phantom_particles.size() == 85, "phantom hit should spawn the original 85 dark hit particles")
	var first_particle: Dictionary = phantom_particles[0] as Dictionary
	_expect(float(first_particle.get("max_life", 0.0)) >= 30.0, "phantom particles should use the original long minimum life")
	_expect(float(first_particle.get("size", 0.0)) >= 3.5, "phantom particles should use the original larger shard size")

	var knockback: Dictionary = runtime.consume_phantom_kick_knockback(
		Vector2(640.0, 80.0),
		Vector2(330.0, 25.0),
		100.0,
		deps
	)
	_expect(abs(float(knockback.get("boss_vel", 0.0))) == 18.0, "phantom boss hit should apply the original strong knockback")
	_expect(abs(ai_state.knockback_vel) == 18.0, "phantom knockback should route into boss AI knockback state")
	_expect(not bool(runtime.get_snapshot().get("phantom_kick_knockback_pending", true)), "phantom knockback should consume once")
	_expect(not bool(runtime.get_snapshot().get("phantom_kick_speed_limit_disabled", true)), "boss guard should restore the normal speed cap after Phantom Kick")

	print("viper_marshal_kick_port_smoke: ok")
	quit(0)


func _test_phantom_kick_cutin_state() -> void:
	var cutin := ViperPhantomKickCutinState.new()
	_expect(not cutin.is_active(), "phantom kick cut-in should start inactive")
	cutin.begin(1.0)
	_expect(cutin.is_active(), "phantom kick cut-in begin should activate")
	_expect(cutin.get_skill_name() == "phantom_kick", "phantom kick cut-in should default to phantom_kick")
	cutin.update(0.5)
	_expect(absf(cutin.get_progress() - 0.5) < 0.01, "phantom kick cut-in progress should track elapsed time")
	cutin.update(0.6)
	_expect(not cutin.is_active(), "phantom kick cut-in should auto-end")
	cutin.begin(1.0)
	cutin.reset()
	_expect(not cutin.is_active(), "phantom kick cut-in reset should clear active")


func _test_phantom_kick_cutin_host_prewarms_sheet() -> void:
	var host := SkillCutinOverlayHost.new()
	host.prewarm_assets()
	var texture := ProjectResourceLoader.get_cached_texture(PHANTOM_CUTIN_SHEET_PATH)
	_expect(texture != null, "Viper Phantom Kick cut-in sheet should prewarm into ProjectResourceLoader cache")
	if texture != null:
		_expect(texture.get_width() == PHANTOM_CUTIN_SHEET_SIZE, "Viper Phantom Kick cut-in sheet width should be %d" % PHANTOM_CUTIN_SHEET_SIZE)
		_expect(texture.get_height() == PHANTOM_CUTIN_SHEET_SIZE, "Viper Phantom Kick cut-in sheet height should be %d" % PHANTOM_CUTIN_SHEET_SIZE)
	var profile: Dictionary = host._get_cutin_profile("phantom_kick")
	_expect(str(profile.get("sheet_path", "")) == PHANTOM_CUTIN_SHEET_PATH, "phantom_kick cut-in profile should use the Viper sheet")


func _test_phantom_kick_unlock_catalog_wiring() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var perk_state: Object = RuntimePerkState.new()
	var skill_config: Object = ViperSkillConfig.new()
	var owner := FakeOwner.new()
	var registry := RealViperRegistry.new(perk_state, skill_config)
	var unlock_data: Dictionary = catalog.get_perk_data("double_marshal_kick")
	_expect(not unlock_data.is_empty(), "double_marshal_kick should exist as the Phantom Kick unlock perk")
	_expect(str(unlock_data.get("unlocks_skill", "")) == "phantom_kick", "double_marshal_kick should unlock the runtime phantom_kick orb")
	_expect(str(unlock_data.get("detail", "")).find("쿨타임 50초") >= 0, "Phantom Kick unlock detail should show the 50-second cooldown")
	_expect(is_equal_approx(skill_config.get_cooldown_seconds("phantom_kick"), 50.0), "Phantom Kick config cooldown should be 50 seconds")
	var phantom_data: Dictionary = skill_config.get_skill_data("phantom_kick")
	_expect(is_equal_approx(float(phantom_data.get("cooldown", 0.0)), 50.0), "Phantom Kick tooltip data should expose the 50-second cooldown")

	unlock_data["id"] = "double_marshal_kick"
	_expect(perk_state.apply_choice(unlock_data, owner, registry), "selecting double_marshal_kick should apply cleanly")
	_expect(perk_state.get_runtime_skill_level("double_marshal_kick") == 1, "Phantom Kick unlock should set the runtime perk level gate")
	_expect(skill_config.is_skill_equipped("phantom_kick"), "Phantom Kick unlock should equip the runtime phantom_kick skill")


func _test_phantom_kick_speed_limit_lifecycle() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	runtime.phantom_kick_knockback_pending = true
	runtime.phantom_kick_speed_limit_disabled = true
	var active_context: Dictionary = runtime.get_ball_collision_context()
	_expect(bool(active_context.get("speed_limit_disabled", false)), "active Phantom Kick ball should disable the frame speed limit")

	var update_context := {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"ball_size": 28.6,
		"ball_pos": Vector2(380.0, 58.0),
		"ball_vel": Vector2(80.0, 0.0),
		"ball_impact_boost": 1.0,
		"player_pos": Vector2(302.5, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_y": 25.0,
		"boss_hitbox_height": 40.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
		"min_ball_speed": 3.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"max_bounce_angle": 60.0,
		"rally_speed_cap_increase_per_hit": 0.0,
	}
	var deps := {
		"viper_skill_runtime": runtime,
		"ball_physics": BallPhysics.new(),
		"paddle_bounce_controller": PaddleBounceController.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
		"motion_stepper": FakeBossGuardMotionStepper.new(),
	}
	var ball_result: Dictionary = BallUpdateController.new().update(1.0 / 60.0, update_context, deps)
	var snapshot: Dictionary = ball_result.get("snapshot", {})
	_expect(not bool(runtime.is_phantom_kick_speed_limit_disabled()), "boss guard should clear Phantom Kick's uncapped speed state")
	_expect(not bool(snapshot.get("speed_limit_disabled", true)), "boss guard frame should publish restored speed-limit state")
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO).length() <= 26.01, "boss-guarded Phantom Kick ball should be capped again immediately")


func _test_shadow_chain_marshal_prep_retime() -> void:
	var shadow_setup: Dictionary = _start_marshal_prep_case(true)
	_advance_marshal_prep_frames(shadow_setup, 20)
	var shadow_runtime: Object = shadow_setup.get("runtime", null)
	_expect(shadow_runtime != null and int(shadow_runtime.marshal_phase) == 1, "shadow-step chained marshal wall-flight prep should finish in 20 frames after the 20 percent cut")

	var normal_setup: Dictionary = _start_marshal_prep_case(false)
	_advance_marshal_prep_frames(normal_setup, 20)
	var normal_runtime: Object = normal_setup.get("runtime", null)
	_expect(normal_runtime != null and int(normal_runtime.marshal_phase) == 0, "non-shadow marshal wall-flight prep should keep the original longer timing")


func _start_marshal_prep_case(from_shadow_step_chain: bool) -> Dictionary:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var orb := FakeOrbHud.new()
	var perk_state := FakePerkState.new()
	var deps := {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"audio": audio,
		"feedback": feedback,
		"orb_hud_state": orb,
		"runtime_perk_state": perk_state,
	}
	var config := {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_floor_y": 680.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(380.0, 45.0),
		"boss_paddle_width": 100.0,
		"ball_pos": Vector2(640.0, 350.0),
		"ball_vel": Vector2(0.0, -8.0),
		"ball_impact_boost": 1.0,
	}
	var player_pos := Vector2(302.5, 680.0)
	var gauge := 200.0
	runtime.shadow_was_airborne = true
	runtime.open_marshal_kick_window(from_shadow_step_chain)
	input.snapshot["down_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	input.snapshot["down_pressed"] = false
	_expect(bool(result.get("activated", false)), "marshal prep retime setup should activate marshal kick")
	_expect(bool(runtime.marshal_from_shadow_step_chain) == from_shadow_step_chain, "marshal prep retime setup should preserve the shadow-chain source flag")
	return {
		"runtime": runtime,
		"input": input,
		"deps": deps,
		"config": config,
		"player_pos": _get_vector2(result, "player_pos", player_pos),
		"gauge": float(result.get("special_gauge", gauge)),
	}


func _advance_marshal_prep_frames(setup: Dictionary, frames: int) -> void:
	var runtime: Object = setup.get("runtime", null)
	var input: Object = setup.get("input", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = setup.get("config", {})
	var player_pos: Vector2 = _get_vector2(setup, "player_pos", Vector2.ZERO)
	var gauge: float = float(setup.get("gauge", 0.0))
	_expect(runtime != null and input != null, "marshal prep retime setup should include runtime and input")
	input.snapshot["down_pressed"] = false
	for _i in range(frames):
		var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		gauge = float(result.get("special_gauge", gauge))
	setup["player_pos"] = player_pos
	setup["gauge"] = gauge


func _expect_phantom_show_freezes_ball_and_boss(runtime: Object, config: Dictionary) -> void:
	var freeze_context: Dictionary = runtime.get_ball_collision_context()
	_expect(bool(freeze_context.get("viper_dmk_freeze_active", false)), "phantom show text should mark Viper DMK freeze active")
	var ball_pos := Vector2(220.0, 360.0)
	var ball_vel := Vector2(5.0, -7.0)
	var ball_context := {
		"selected_character_type": "viper",
		"ball_active": true,
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"ball_impact_boost": 1.0,
		"player_pos": Vector2(302.5, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(330.0, 25.0),
		"boss_vel": 4.0,
		"current_stage": int(config.get("current_stage", 1)),
	}
	var ball_result: Dictionary = BallUpdateController.new().update(
		1.0 / 60.0,
		ball_context,
		{"viper_skill_runtime": runtime}
	)
	var snapshot: Dictionary = ball_result.get("snapshot", {})
	_expect(_get_vector2(snapshot, "ball_pos", Vector2.ZERO) == ball_pos, "phantom show freeze should hold the ball position")
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO) == ball_vel, "phantom show freeze should preserve the stored ball velocity")

	var boss_context: Dictionary = runtime.get_boss_ai_context()
	_expect(bool(boss_context.get("viper_dmk_freeze_active", false)), "phantom show text should mark boss AI freeze active")
	boss_context.merge({
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 100.0,
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
	}, true)
	var boss_pos := Vector2(330.0, 25.0)
	var boss_result: Dictionary = BossAiState.new().update(1.0 / 60.0, boss_pos, 6.0, boss_context)
	_expect(_get_vector2(boss_result, "boss_pos", Vector2.ZERO) == boss_pos, "phantom show freeze should hold the boss position")
	_expect(abs(float(boss_result.get("boss_vel", 1.0))) <= 0.01, "phantom show freeze should stop boss AI velocity")


func _context_with_gauge(config: Dictionary, gauge: float) -> Dictionary:
	var context: Dictionary = config.duplicate(true)
	context["special_gauge"] = gauge
	return context


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
