extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const BallSpeedDebugOverlay := preload("res://scripts/hud/ball_speed_debug_overlay.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleDrawSceneContext := preload("res://scripts/core/battle_draw_scene_context.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherWheelState := preload("res://scripts/characters/smasher_wheel_state.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "smasher_wheel"

	func get_skill_cost(skill_name: String) -> float:
		return 200.0 if skill_name == "smasher_wheel" else 0.0

	func get_cooldown_seconds(skill_name: String) -> float:
		return 25.0 if skill_name == "smasher_wheel" else 0.0


class FakeSkillState:
	var triggered_skill := ""
	var triggered_cooldown_seconds := -1.0

	func get_configured_cooldown_remaining(_skill_name: String, _current_msec: int, _skill_config: Object) -> float:
		return 0.0

	func trigger_configured_cooldown(skill_name: String, _current_msec: int, skill_config: Object) -> void:
		triggered_skill = skill_name
		if skill_config != null and skill_config.has_method("get_cooldown_seconds"):
			triggered_cooldown_seconds = float(skill_config.get_cooldown_seconds(skill_name))


class FakeRuntimePerkState:
	var gold := 0

	func award_gold(amount: int) -> int:
		gold += amount
		return gold


class FakeFeedback:
	var flash_triggered := false
	var shake_intensity := 0.0

	func set_screen_shake(_amount: float, intensity: float) -> void:
		shake_intensity = max(shake_intensity, intensity)

	func max_screen_shake(_amount: float, intensity: float) -> void:
		shake_intensity = max(shake_intensity, intensity)

	func trigger_gauge_flash() -> void:
		flash_triggered = true


class FakeImpactEffects:
	var drive_particle_count := 0
	var paddle_hit_count := 0
	var explosion_count := 0

	func spawn_drive_particles(_pos: Vector2, count: int = 4) -> void:
		drive_particle_count += count

	func spawn_paddle_hit_particles(_pos: Vector2, _is_player: bool, _ball_vel: Vector2 = Vector2.ZERO, _intensity: float = 0.0) -> void:
		paddle_hit_count += 1

	func create_energy_explosion(_pos: Vector2, _scale: float, _intensity: float) -> void:
		explosion_count += 1


class FakeBallEffects:
	var pulse_kind := ""

	func register_hit_pulse(_pos: Vector2, _velocity: Vector2, _intensity: float = 0.0, kind: String = "hit") -> void:
		pulse_kind = kind


class FakeBallIntensity:
	var last_hit := ""

	func register_hit(hit_by: String) -> void:
		last_hit = hit_by


class FakeBallPhysics:
	func enforce_minimum_rally_speed(ball_vel: Vector2) -> Vector2:
		return ball_vel


class FakePaddleBounceState:
	func get_initial_speed(ball_velocity: Vector2) -> float:
		return ball_velocity.length()

	func resolve_velocity(
		_ball_velocity: Vector2,
		_hit_pos: float,
		is_player: bool,
		_incoming_dx: float,
		_outgoing_direction: float,
		_speed: float,
		_angle_rad: float,
		_drive_activated: bool,
		_accel_scale: float,
		vertical_bounce_count: int,
		_physics: Object,
		_drive_bounce_state: Object,
		drive_speed_increase: float,
		ball_spin_strength: float,
		_min_ball_speed: float,
		_max_ball_speed: float
	) -> Dictionary:
		return {
			"ball_vel": Vector2(0.0, -8.0 if is_player else 8.0),
			"vertical_bounce_count": vertical_bounce_count,
			"drive_speed_increase": drive_speed_increase,
			"ball_spin_strength": ball_spin_strength,
		}


class FakeDrawRegistry:
	var instances := {}

	func _init(new_instances: Dictionary) -> void:
		instances = new_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var real_skill_config: Object = SmasherSkillConfig.new()
	_expect(is_equal_approx(real_skill_config.get_skill_cost("smasher_wheel"), 200.0), "smasher wheel should cost 200 gauge")
	_expect(is_equal_approx(real_skill_config.get_cooldown_seconds("smasher_wheel"), 25.0), "smasher wheel should expose the 25-second cooldown")
	var skill_data: Dictionary = real_skill_config.get_skill_data("smasher_wheel")
	_expect(str(skill_data.get("effect_type", "")) == "wheel_spin", "smasher wheel tooltip should use the wheel_spin effect type")
	_expect(str(skill_data.get("description", "")).find("공속 상한 60") >= 0, "smasher wheel tooltip should mention the 60 speed cap")

	var catalog: Object = RuntimePerkCatalog.new()
	var unlock_data: Dictionary = catalog.get_perk_data("unlock_smasher_wheel")
	_expect(str(unlock_data.get("unlocks_skill", "")) == "smasher_wheel", "unlock_smasher_wheel should register the runtime skill unlock")

	var wheel_audio: AudioStream = ProjectResourceLoader.load_audio_stream(GameAudio.SMASHER_WHEEL_SOUND_PATH)
	_expect(wheel_audio != null, "smasher wheel loop sound should load from Godot assets")
	var resources: Object = BattleResources.new()
	var runtime_textures: Dictionary = resources.load_all({
		"selected_character_type": "smasher",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	_expect(runtime_textures.get("player_wheel_spin_sheet", null) is Texture2D, "smasher wheel should load its body spin sheet without result prewarm")
	var wheel_spin_texture: Texture2D = runtime_textures["player_wheel_spin_sheet"]
	_expect(wheel_spin_texture.get_size() == Vector2(640.0, 640.0), "smasher wheel body spin sheet should use the dedicated 4x4 flame-blade spin sheet")

	var scene_state := BattleSceneState.new()
	_expect(scene_state.has_key("smasher_wheel_speed_cap"), "battle scene state should preserve smasher wheel speed cap")
	var update_controller := BallUpdateController.new()
	var frame_motion := BallFrameMotionController.new()
	var wheel_scene: Dictionary = update_controller._build_scene_snapshot({
		"ball_vel": Vector2(120.0, 0.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"smasher_wheel_speed_cap": 60.0,
	})
	_expect(is_equal_approx(float(wheel_scene.get("smasher_wheel_speed_cap", 0.0)), 60.0), "ball update scene should carry smasher wheel speed cap")
	frame_motion.apply_ball_speed_limits(wheel_scene, {"ball_physics": FakeBallPhysics.new()})
	_expect(abs(Vector2(wheel_scene["ball_vel"]).length() - 60.0) <= 0.001, "smasher wheel cap should allow speed up to 60")
	wheel_scene = {
		"ball_vel": Vector2(120.0, 0.0),
		"ball_impact_boost": 2.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"smasher_wheel_speed_cap": 60.0,
	}
	frame_motion.apply_ball_speed_limits(wheel_scene, {"ball_physics": FakeBallPhysics.new()})
	_expect(abs(Vector2(wheel_scene["ball_vel"]).length() - 30.0) <= 0.001, "smasher wheel cap should clamp effective speed to 60")
	var debug_overlay := BallSpeedDebugOverlay.new()
	_expect(is_equal_approx(debug_overlay._get_max_ball_speed(false, 1.0, "champion", null, 60.0), 60.0), "F9 speed overlay should show wheel cap during normal motion")
	_expect(is_equal_approx(debug_overlay._get_max_ball_speed(true, 1.0, "mythic", null, 60.0), 60.0), "F9 speed overlay should show wheel cap over power-smash cap")
	var bounce_controller := PaddleBounceController.new()
	var boss_guard_result: Dictionary = bounce_controller.bounce(
		300.0,
		100.0,
		false,
		{
			"ball_pos": Vector2(350.0, 60.0),
			"ball_vel": Vector2(0.0, -60.0),
			"ball_impact_boost": 1.0,
			"ball_boost_decay_rate": 0.975,
			"ball_min_boost": 0.70,
			"boss_y": 25.0,
			"boss_hitbox_height": 40.0,
			"boss_vel": 0.0,
			"max_bounce_angle": 60.0,
			"min_ball_speed": 3.0,
			"max_ball_speed": 26.0,
			"smasher_wheel_speed_cap": 60.0,
		},
		{
			"paddle_bounce_state": FakePaddleBounceState.new(),
			"ball_physics": FakeBallPhysics.new(),
		}
	)
	_expect(boss_guard_result.has("smasher_wheel_speed_cap"), "boss guard should explicitly return a wheel cap clear")
	_expect(is_equal_approx(float(boss_guard_result.get("smasher_wheel_speed_cap", -1.0)), 0.0), "boss guard should restore the original league speed cap")

	var wheel_state: Object = SmasherWheelState.new()
	_expect(wheel_state.has_method("prewarm_assets"), "smasher wheel should expose a loading-screen prewarm hook")
	wheel_state.prewarm_assets()
	_expect(wheel_state.get("_timer_font") is Font, "smasher wheel prewarm should resolve the timer font before first activation draw")
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var runtime_perk_state := FakeRuntimePerkState.new()
	var feedback := FakeFeedback.new()
	var impact_effects := FakeImpactEffects.new()
	var ball_effects := FakeBallEffects.new()
	var ball_intensity := FakeBallIntensity.new()
	var deps := {
		"skill_config": skill_config,
		"skill_state": skill_state,
		"runtime_perk_state": runtime_perk_state,
		"feedback": feedback,
		"impact_effects": impact_effects,
		"ball_effects": ball_effects,
		"ball_intensity": ball_intensity,
	}
	var config := {
		"ball_active": true,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"paddle_max_speed": 6.0,
		"paddle_accel": 0.5,
		"paddle_turn_decel": 0.45,
	}

	var result: Dictionary = wheel_state.update_input({"left_pressed": true}, 1000, 250.0, Vector2(300.0, 700.0), config, deps)
	_expect(not bool(result.get("activated", false)), "first A command edge should not activate the wheel yet")
	result = wheel_state.update_input({"left_pressed": false, "up_pressed": true}, 1250, 250.0, Vector2(300.0, 700.0), config, deps)
	_expect(not bool(result.get("activated", false)), "A->W should still wait for the final command edge")
	result = wheel_state.update_input({"up_pressed": false, "right_pressed": true}, 1500, 250.0, Vector2(300.0, 700.0), config, deps)
	_expect(bool(result.get("activated", false)), "A->W->D should activate right Smasher Wheel")
	_expect(is_equal_approx(float(result.get("special_gauge", -1.0)), 50.0), "activation should spend 200 gauge")
	_expect(is_equal_approx(float(result.get("player_speed", 0.0)), 5.1), "activation should launch the paddle in the wheel direction")
	_expect(wheel_state.is_active(), "smasher wheel should become active immediately")
	_expect(int(wheel_state.get_body_spin_frame(1500)) == SmasherWheelState.BODY_SPIN_FRAME_START, "wheel body spin should start on the first dedicated spin frame")
	_expect(int(wheel_state.get_body_spin_frame(1500 + int(ceil(SmasherWheelState.BODY_SPIN_FRAME_MSEC * 15.0)))) == SmasherWheelState.BODY_SPIN_FRAME_END, "wheel body spin should include the final dedicated spin frame")
	_expect(int(wheel_state.get_body_spin_frame(1500 + int(ceil(SmasherWheelState.BODY_SPIN_FRAME_MSEC * 16.0)))) == SmasherWheelState.BODY_SPIN_FRAME_START, "wheel body spin should loop all 16 dedicated frames while active")
	_expect(skill_state.triggered_skill == "smasher_wheel", "activation should trigger the shared cooldown")
	_expect(is_equal_approx(skill_state.triggered_cooldown_seconds, 25.0), "activation should request the configured 25-second cooldown")
	_expect(feedback.flash_triggered and feedback.shake_intensity > 0.0, "activation should trigger gauge and shake feedback")

	var actor_context: Dictionary = BattleDrawActorContext.new().build(
		{
			"textures": runtime_textures,
			"selected_character_type": "smasher",
			"player_pos": Vector2(300.0, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
			"player_speed": 5.1,
		},
		{"smasher_wheel_state": wheel_state}
	)
	_expect(bool(actor_context.get("player_wheel_spin_active", false)), "actor draw context should expose the wheel spin body override")
	_expect(actor_context.get("player_wheel_spin_sheet", null) == runtime_textures.get("player_wheel_spin_sheet", null), "wheel spin body override should draw the loaded dedicated spin sheet")
	var draw_scene_context: Object = BattleDrawSceneContext.new()
	var live_draw_deps: Dictionary = draw_scene_context.build_scene_deps(FakeDrawRegistry.new({"smasher_wheel_state": wheel_state}), null, null)
	_expect(live_draw_deps.get("smasher_wheel_state", null) == wheel_state, "live battle draw deps should include smasher wheel state")
	var live_actor_context: Dictionary = BattleDrawActorContext.new().build(
		{
			"textures": runtime_textures,
			"selected_character_type": "smasher",
			"player_pos": Vector2(300.0, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
			"player_speed": 5.1,
		},
		live_draw_deps
	)
	_expect(bool(live_actor_context.get("player_wheel_spin_active", false)), "live battle actor context should expose wheel spin through draw deps")
	var spin_frame: int = int(actor_context.get("player_wheel_spin_frame", -1))
	_expect(spin_frame >= SmasherWheelState.BODY_SPIN_FRAME_START and spin_frame <= SmasherWheelState.BODY_SPIN_FRAME_END, "wheel spin frame should stay inside the dedicated 0..15 loop")
	var sprite_renderer: Object = Stage1PlayerSpriteRenderer.new()
	var spin_region: Rect2 = sprite_renderer.call("_get_player_wheel_spin_sprite_region", {
		"player_wheel_spin_frame": SmasherWheelState.BODY_SPIN_FRAME_END,
		"player_wheel_spin_cell_width": 160.0,
		"player_wheel_spin_cell_height": 160.0,
		"player_wheel_spin_grid_cols": SmasherWheelState.BODY_SPIN_GRID_COLS,
		"player_wheel_spin_frame_count": SmasherWheelState.BODY_SPIN_SHEET_FRAME_COUNT,
	})
	_expect(spin_region == Rect2(480.0, 480.0, 160.0, 160.0), "wheel spin frame 15 should slice the final dedicated 4x4 cell")
	_expect(sprite_renderer.has_method("_prewarm_wheel_spin_sheet_draw"), "stage1 sprite renderer should prewarm the wheel spin sheet before activation draw")
	var prewarm_region: Rect2 = sprite_renderer.call("_get_player_wheel_spin_prewarm_source_rect", {
		"player_wheel_spin_frame": SmasherWheelState.BODY_SPIN_FRAME_START,
		"player_wheel_spin_cell_width": 160.0,
		"player_wheel_spin_cell_height": 160.0,
		"player_wheel_spin_grid_cols": SmasherWheelState.BODY_SPIN_GRID_COLS,
		"player_wheel_spin_frame_count": SmasherWheelState.BODY_SPIN_SHEET_FRAME_COUNT,
	})
	_expect(prewarm_region == Rect2(0.0, 0.0, 160.0, 160.0), "wheel spin prewarm should prime the first dedicated spin cell")
	var start_draw_context: Dictionary = wheel_state.get_actor_draw_context(1500)
	_expect(int(start_draw_context.get("player_wheel_spin_frame", -1)) == SmasherWheelState.BODY_SPIN_FRAME_START, "wheel draw context should accept a shared timestamp for the activation frame")

	_expect(is_equal_approx(float(wheel_state.get_movement_direction(0.0)), 1.0), "active wheel should auto-roll when no direction is held")
	var motion_config: Dictionary = wheel_state.apply_movement_config(config, 5.1, -1.0)
	_expect(is_equal_approx(float(motion_config.get("paddle_max_speed", 0.0)), 5.1), "active wheel should reduce max paddle speed by 15 percent")
	_expect(is_equal_approx(float(motion_config.get("paddle_accel", 0.0)), 0.09), "opposite input should use the wheel reverse-accel penalty")
	_expect(is_equal_approx(float(motion_config.get("paddle_turn_decel", 1.0)), 0.0), "active wheel should disable instant turn decel")

	var hit_context := {
		"player_y": 700.0,
		"ball_size": 28.6,
		"base_ball_speed": 9.0,
	}
	var hit_result: Dictionary = wheel_state.consume_ball_hit(Vector2(350.0, 690.0), Vector2(30.0, 40.0), hit_context, deps)
	_expect(bool(hit_result.get("smasher_wheel_hit", false)), "active wheel should consume one ball hit")
	var next_vel: Vector2 = hit_result.get("ball_vel", Vector2.ZERO)
	_expect(next_vel.y < 0.0, "wheel hit should relaunch the ball upward")
	_expect(next_vel.length() >= 59.9 and next_vel.length() <= 60.1, "wheel hit should clamp launch speed to the 60 cap")
	_expect(is_equal_approx(float(hit_result.get("smasher_wheel_speed_cap", 0.0)), 60.0), "wheel hit should expose the 60 speed cap")
	_expect(is_equal_approx(float(hit_result.get("ball_spin_strength", 0.0)), 0.62), "wheel hit should apply the Python-parity spin strength")
	_expect(int(hit_result.get("ball_spin_direction", 0)) != 0, "wheel hit should pick a random spin direction")
	_expect(not bool(hit_result.get("drive_ball_active", true)), "wheel hit should not enable drive_ball_active")
	_expect(int(hit_result.get("runtime_perk_gold", 0)) == 30 and runtime_perk_state.gold == 30, "wheel hit should award 30 skill gold")
	_expect(impact_effects.drive_particle_count >= 18 and impact_effects.paddle_hit_count == 1 and impact_effects.explosion_count == 1, "wheel hit should spawn impact and drive particles")
	_expect(ball_effects.pulse_kind == "smasher_wheel" and ball_intensity.last_hit == "player", "wheel hit should register player ball feedback")
	var second_hit: Dictionary = wheel_state.consume_ball_hit(Vector2(350.0, 690.0), Vector2(4.0, 5.0), hit_context, deps)
	_expect(second_hit.is_empty(), "active wheel should only consume one ball hit")

	print("smasher_wheel_port_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
