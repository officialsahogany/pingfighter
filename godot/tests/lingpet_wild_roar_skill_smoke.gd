extends SceneTree

const LingpetWildRoarSkill := preload("res://scripts/lingpet/lingpet_wild_roar_skill.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const PaddleBounceBossPostHitHandler := preload("res://scripts/ball/paddle_bounce_boss_post_hit_handler.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const SKILL_ID := "monkeyring_wild_roar"
const CARD_PATH := "res://assets/sprites/lingpet/monkeyring_wild_roar_skillcard_imagegen_v1.png"
const ICON_PATH := "res://assets/sprites/lingpet/monkeyring_wild_roar_skill_icon_imagegen_v1.png"
const CAST_PATH := "res://assets/sprites/lingpet/monkeyring_companion_wild_roar_cast.png"
const AUDIO_PATH := "res://assets/sounds/lingpet/monkeyshouting.wav"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var ai_mode := "champion"
	var selected_character_type := "smasher"
	var ball_active := true
	var skip_ball_motion_step := false
	var ball_pos := Vector2(300.0, 390.0)
	var ball_vel := Vector2(0.0, 26.0)
	var ball_size := 28.6
	var ball_impact_boost := 1.0
	var ball_boost_decay_rate := 0.975
	var ball_min_boost := 0.70
	var rally_speed_cap_bonus := 0.0
	var player_collision_cooldown := 0.0
	var boss_collision_cooldown := 0.0
	var vertical_bounce_count := 0
	var ball_spin_strength := 0.0
	var ball_spin_direction := 0
	var drive_ball_active := false
	var drive_hit_boss := false
	var drive_speed_increase := 0.0
	var drive_text_timer_frames := 0.0
	var special_gauge := 0.0
	var player_speed := 0.0
	var boss_vel := 0.0
	var boss_pos := Vector2(210.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var player_pos := Vector2(300.0, 675.0)
	var weather_type := ""
	var weather_active := false
	var weather_event_active := false
	var commando_bowling_trap_guard_armed := false
	var commando_bowling_trap_guard_source := ""
	var commando_bowling_trap_guard_knockback_power := 0.0
	var commando_bowling_trap_guard_stun_frames := 0.0
	var commando_bowling_trap_guard_restore_speed := 0.0
	var commando_suicide_drone_ball_boost_active := false
	var commando_suicide_drone_ball_restore_speed := 0.0
	var commando_suicide_drone_ball_boosted_speed := 0.0
	var lingpet_wild_roar_ball_boost_active := false
	var lingpet_wild_roar_ball_restore_speed := 0.0


class FakeAudio:
	extends RefCounted

	var wild_roar_count := 0
	var active_item_fallback_count := 0

	func play_lingpet_wild_roar() -> void:
		wild_roar_count += 1

	func play_active_item() -> void:
		active_item_fallback_count += 1


class FakeFeedback:
	extends RefCounted

	var shake_count := 0
	var last_amount := 0.0
	var last_intensity := 0.0

	func max_screen_shake(amount: float, intensity: float) -> void:
		shake_count += 1
		last_amount = amount
		last_intensity = intensity


class FakeRegistry:
	extends RefCounted

	var game_audio: Object = null
	var battle_feedback_state: Object = null

	func _init(audio: Object = null, feedback: Object = null) -> void:
		game_audio = audio
		battle_feedback_state = feedback

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		match key:
			"game_audio":
				return game_audio
			"battle_feedback_state":
				return battle_feedback_state
		return null


class FakeBallPhysics:
	extends RefCounted

	func enforce_minimum_rally_speed(velocity: Vector2) -> Vector2:
		return velocity

	func get_minimum_effective_boost(_velocity: Vector2) -> float:
		return 1.0

	func get_minimum_rally_speed() -> float:
		return 3.0

	func compute_dynamic_impact_boost(_ball_vel: Vector2, _current_speed: float, _launch_angle_rad: float) -> Dictionary:
		return {
			"boost": 1.0,
			"decay_rate": 0.975,
			"min_boost": 0.70,
		}


class FakePaddleBounceState:
	extends RefCounted

	func get_initial_speed(ball_velocity: Vector2) -> float:
		return ball_velocity.length()

	func resolve_velocity(
		_ball_velocity: Vector2,
		_hit_pos: float,
		is_player: bool,
		_incoming_dx: float,
		_outgoing_direction: float,
		speed: float,
		_angle_rad: float,
		_drive_activated: bool,
		_accel_scale: float,
		vertical_bounce_count: int,
		_physics: Object,
		_drive_bounce_state: Object,
		drive_speed_increase: float,
		ball_spin_strength: float,
		_min_ball_speed: float,
		max_ball_speed: float
	) -> Dictionary:
		var uncapped_speed := speed if is_inf(max_ball_speed) else minf(speed, max_ball_speed)
		return {
			"ball_vel": Vector2(0.0, -maxf(8.0, uncapped_speed)) if is_player else Vector2(0.0, maxf(8.0, uncapped_speed)),
			"vertical_bounce_count": vertical_bounce_count,
			"drive_speed_increase": drive_speed_increase,
			"ball_spin_strength": ball_spin_strength,
		}


func _init() -> void:
	seed(20260612)
	_verify_catalog_dispatcher_assets_and_audio()
	_verify_dynamic_arm_gap_blocks_fast_body_hit_race()
	_verify_launch_reflects_upward_and_caps_at_60()
	_verify_launch_rejects_near_horizontal_wall_pingpong()
	_verify_whiff_consumes_launch_without_owner_boost()
	_verify_speed_limit_context_and_boss_return_restore()
	_verify_round_reset_clears_wild_roar_boost()
	_verify_allowlist_chain_preserves_wild_roar_consume()
	_verify_apply_ball_speed_limits_on_off()
	_verify_trigger_distance_roll_is_per_cycle()
	_verify_schema_reset_and_host_wiring()
	_verify_source_wiring_surfaces()

	if _failures.is_empty():
		print("lingpet_wild_roar_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_dispatcher_assets_and_audio() -> void:
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_wild_roar_skill.gd"), "Wild Roar skill module should exist")
	_expect(FileAccess.file_exists(CARD_PATH), "Wild Roar skill card PNG should exist")
	_expect(FileAccess.file_exists(ICON_PATH), "Wild Roar skill icon PNG should exist")
	_expect(FileAccess.file_exists(CAST_PATH), "Wild Roar companion cast PNG should exist")
	_expect(FileAccess.file_exists("%s.import" % CARD_PATH), "Wild Roar skill card should commit its .png.import sidecar")
	_expect(FileAccess.file_exists("%s.import" % ICON_PATH), "Wild Roar skill icon should commit its .png.import sidecar")
	_expect(FileAccess.file_exists("%s.import" % CAST_PATH), "Wild Roar companion cast should commit its .png.import sidecar")
	var card := ProjectResourceLoader.load_texture(CARD_PATH)
	var icon := ProjectResourceLoader.load_texture(ICON_PATH)
	var cast := ProjectResourceLoader.load_texture(CAST_PATH)
	_expect(card != null and card.get_width() == 1720 and card.get_height() == 541, "Wild Roar skill card should load at 1720x541")
	_expect(icon != null and icon.get_width() == 1254 and icon.get_height() == 1254, "Wild Roar skill icon should load at 1254x1254")
	_expect(cast != null and cast.get_width() == 1280 and cast.get_height() == 1280, "Wild Roar companion cast should load as a 5x5 256px sheet")
	_expect(FileAccess.file_exists(AUDIO_PATH), "Wild Roar should ship the original monkeyshouting.wav")
	_expect(FileAccess.file_exists("%s.import" % AUDIO_PATH), "Wild Roar wav should commit its .wav.import sidecar")
	_expect(GameAudio.LINGPET_WILD_ROAR_SOUND_PATH == AUDIO_PATH, "GameAudio should expose the Wild Roar sound path")

	var default_skill: Dictionary = LingpetCatalog.get_active_skill("monkeyring")
	_expect(str(default_skill.get("id", "")) == "monkeyring_banana_slice", "Ppanamong default active skill should remain Banana Slice")
	var lv1_skill: Dictionary = LingpetCatalog.get_active_skill("monkeyring", SKILL_ID, 1)
	var lv5_skill: Dictionary = LingpetCatalog.get_active_skill("monkeyring", SKILL_ID, 5)
	_expect(str(lv1_skill.get("runtime_kind", "")) == "wild_roar", "Wild Roar catalog entry should use wild_roar runtime kind")
	_expect(str(lv1_skill.get("name", "")) == "야생의 포효", "Wild Roar should use the requested Korean skill name")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "companion_cast") == CAST_PATH, "Wild Roar should route Monkeyring companion cast to the rear roar pose sheet")
	_expect(is_equal_approx(float(lv1_skill.get("cooldown", 0.0)), 27.0), "Wild Roar base cooldown should be 27 seconds")
	_expect(is_equal_approx(float(lv1_skill.get("windup_seconds", -1.0)), 0.0), "Wild Roar windup should be explicitly zero")
	_expect(is_equal_approx(float(lv5_skill.get("base_cooldown", 27.0)), 27.0), "Wild Roar Lv.5 should preserve 27 seconds as base cooldown before shared reduction")
	_expect(is_equal_approx(float(lv5_skill.get("roar_radius", 0.0)), 252.0), "Wild Roar Lv.5 radius should flatten to 252")
	_expect(is_equal_approx(float(lv5_skill.get("ball_boost", 0.0)), 3.6), "Wild Roar Lv.5 boost should flatten to 3.6")
	_expect(LingpetSkillDispatcher.is_wild_roar(SKILL_ID), "dispatcher should expose Wild Roar helper")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "live lingpet catalog should validate with Wild Roar card/icon art")


func _verify_dynamic_arm_gap_blocks_fast_body_hit_race() -> void:
	var owner := FakeOwner.new()
	var skill := LingpetWildRoarSkill.new()
	owner.ball_pos = Vector2(300.0, 439.0)
	owner.ball_vel = Vector2(0.0, 26.0)
	var params := _base_can_arm_params(owner, Vector2(300.0, 500.0))
	skill.set_trigger_distances_for_tests([120.0])
	_expect(not bool(skill.can_arm(params)), "gap 61 with vy 26 should be below dynamic arm_min_gap and must not arm")
	_expect(skill.get_last_arm_min_gap_for_tests() > 61.0, "dynamic arm_min_gap should include body-hit threshold plus vy travel")

	var safe_skill := LingpetWildRoarSkill.new()
	owner.ball_pos = Vector2(300.0, 410.0)
	owner.ball_vel = Vector2(0.0, 26.0)
	var safe_params := _base_can_arm_params(owner, Vector2(300.0, 500.0))
	safe_skill.set_trigger_distances_for_tests([120.0])
	_expect(bool(safe_skill.can_arm(safe_params)), "gap 90 with vy 26 should still fit Lv.1 trigger window after dynamic arm_min_gap")


func _verify_launch_reflects_upward_and_caps_at_60() -> void:
	var owner := FakeOwner.new()
	owner.ball_pos = Vector2(300.0, 390.0)
	owner.ball_vel = Vector2(0.0, 26.0)
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(audio, feedback)
	var skill := LingpetWildRoarSkill.new()
	skill.set_trigger_distances_for_tests([150.0])
	skill.set_jitter_degrees_for_tests([0.0])
	_expect(bool(skill.launch(Vector2(300.0, 500.0), owner, {"registry": registry, "active_skill_level": 5})), "Wild Roar launch should return true")
	_expect(skill.get_reflect_count_for_tests() == 1, "Wild Roar should reflect when the ball is inside the shockwave radius")
	_expect(owner.ball_vel.y < 0.0, "Wild Roar should force the reflected ball upward")
	_expect(owner.ball_vel.length() <= 60.001, "Wild Roar launch write should apply the 60 px/frame backstop itself")
	_expect(is_equal_approx(owner.ball_vel.length(), 60.0), "cap-speed Wild Roar should clamp boosted speed to 60 on launch")
	_expect(owner.lingpet_wild_roar_ball_boost_active, "Wild Roar should mark the owner ball boost active")
	_expect(is_equal_approx(owner.lingpet_wild_roar_ball_restore_speed, 26.0), "Wild Roar should store the pre-boost restore speed")
	_expect(audio.wild_roar_count == 1, "Wild Roar should play its dedicated roar cue")
	_expect(feedback.shake_count == 1 and feedback.last_intensity > 1.0, "reflected Wild Roar should trigger strong feedback shake")
	var snap := skill.get_snapshot()
	_expect(is_equal_approx(float(snap.get("wild_roar_screen_flash_state_alpha", 0.0)), 200.0 / 255.0), "flash state alpha should remain 200/255")
	_expect(is_equal_approx(float(snap.get("wild_roar_screen_flash_draw_alpha_cap", 0.0)), 120.0 / 255.0), "flash draw cap should remain 120/255")


func _verify_launch_rejects_near_horizontal_wall_pingpong() -> void:
	var owner := FakeOwner.new()
	owner.ball_pos = Vector2(130.0, 400.0)
	owner.ball_vel = Vector2(0.0, 26.0)
	var skill := LingpetWildRoarSkill.new()
	skill.set_trigger_distances_for_tests([150.0])
	skill.set_jitter_degrees_for_tests([30.0])
	_expect(bool(skill.launch(Vector2(300.0, 500.0), owner, {"active_skill_level": 5})), "near-horizontal Wild Roar launch should still fire")
	_expect(skill.get_reflect_count_for_tests() == 1, "near-horizontal Wild Roar should reflect the ball")
	_expect(is_equal_approx(owner.ball_vel.length(), 60.0), "near-horizontal Wild Roar should keep the launch speed backstop")
	_expect(owner.ball_vel.y <= -15.0, "near-horizontal Wild Roar should keep enough upward speed to avoid side-wall ping-pong")
	_expect(absf(owner.ball_vel.x) >= 50.0, "near-horizontal Wild Roar should preserve a shallow diagonal instead of forcing a vertical shot")
	var reflect_dir: Vector2 = skill.get_snapshot().get("wild_roar_last_reflect_dir", Vector2.ZERO)
	_expect(reflect_dir.y <= -0.25, "Wild Roar snapshot should expose the anti-horizontal upward component")


func _verify_whiff_consumes_launch_without_owner_boost() -> void:
	var owner := FakeOwner.new()
	owner.ball_pos = Vector2(300.0, 40.0)
	owner.ball_vel = Vector2(0.0, 20.0)
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var skill := LingpetWildRoarSkill.new()
	_expect(bool(skill.launch(Vector2(300.0, 500.0), owner, {"registry": FakeRegistry.new(audio, feedback), "active_skill_level": 1})), "Wild Roar whiff should still consume the launch")
	_expect(skill.get_whiff_count_for_tests() == 1, "Wild Roar should record a whiff outside the radius")
	_expect(not owner.lingpet_wild_roar_ball_boost_active, "Wild Roar whiff should not set owner boost active")
	_expect(audio.wild_roar_count == 1, "Wild Roar whiff should still play the roar cue")
	_expect(feedback.shake_count == 1 and feedback.last_intensity < 1.0, "Wild Roar whiff should trigger weak feedback shake")


func _verify_speed_limit_context_and_boss_return_restore() -> void:
	var owner := FakeOwner.new()
	owner.ai_mode = "mythic"
	owner.weather_type = "fire"
	owner.weather_active = true
	owner.lingpet_wild_roar_ball_boost_active = true
	owner.lingpet_wild_roar_ball_restore_speed = 26.0
	var context_builder := BallUpdateContext.new()
	var context := context_builder.build_update_context(owner)
	_expect(bool(context.get("lingpet_wild_roar_speed_limit_disabled", false)), "Wild Roar context should expose its speed-limit-disabled flag")
	_expect(bool(context.get("speed_limit_disabled", false)), "Wild Roar speed policy should run after mythic/fire cap policy and force speed_limit_disabled true")

	var handler := PaddleBounceBossPostHitHandler.new()
	var result: Dictionary = handler._consume_lingpet_wild_roar_ball_boost(Vector2(0.0, -60.0), {
		"lingpet_wild_roar_ball_boost_active": true,
		"lingpet_wild_roar_ball_restore_speed": 26.0,
	})
	var restored_vel: Vector2 = result.get("ball_vel", Vector2.ZERO)
	_expect(is_equal_approx(restored_vel.length(), 26.0), "boss return should restore Wild Roar ball speed while preserving direction")
	_expect(restored_vel.y < 0.0, "boss return restore should preserve post-bounce direction")
	_expect(not bool(result.get("lingpet_wild_roar_ball_boost_active", true)), "boss return should clear Wild Roar boost active")
	_expect(is_equal_approx(float(result.get("lingpet_wild_roar_ball_restore_speed", -1.0)), 0.0), "boss return should clear Wild Roar restore speed")
	_expect(bool(result.get("lingpet_wild_roar_ball_boost_consumed", false)), "boss return should report Wild Roar boost consumed")
	_expect(not result.has("lingpet_wild_roar_ball_boosted_speed"), "Wild Roar should use the 2-field owner schema, not a boosted-speed side channel")
	_expect(not bool(result.get("speed_limit_disabled", true)), "boss return should clear speed_limit_disabled after consuming Wild Roar")


func _verify_round_reset_clears_wild_roar_boost() -> void:
	var round_state := BallRoundState.new()
	var common := round_state.build_common_snapshot()
	_expect(common.has("lingpet_wild_roar_ball_boost_active"), "round common snapshot should include Wild Roar boost active reset")
	_expect(common.has("lingpet_wild_roar_ball_restore_speed"), "round common snapshot should include Wild Roar restore-speed reset")
	_expect(not bool(common.get("lingpet_wild_roar_ball_boost_active", true)), "round common snapshot should clear Wild Roar boost active")
	_expect(is_equal_approx(float(common.get("lingpet_wild_roar_ball_restore_speed", -1.0)), 0.0), "round common snapshot should clear Wild Roar restore speed")
	var reset := round_state.build_reset_snapshot(760.0, 750.0)
	_expect(not bool(reset.get("lingpet_wild_roar_ball_boost_active", true)), "round reset snapshot should keep Wild Roar boost inactive")
	_expect(is_equal_approx(float(reset.get("lingpet_wild_roar_ball_restore_speed", -1.0)), 0.0), "round reset snapshot should keep Wild Roar restore speed at zero")


func _verify_allowlist_chain_preserves_wild_roar_consume() -> void:
	var controller := PaddleBounceController.new()
	var context := _base_bounce_context()
	context["ball_vel"] = Vector2(0.0, -60.0)
	context["lingpet_wild_roar_ball_boost_active"] = true
	context["lingpet_wild_roar_ball_restore_speed"] = 26.0
	context["speed_limit_disabled"] = true
	var result: Dictionary = controller.bounce(
		300.0,
		100.0,
		false,
		context,
		{
			"ball_physics": FakeBallPhysics.new(),
			"paddle_bounce_state": FakePaddleBounceState.new(),
		}
	)
	_expect(result.has("lingpet_wild_roar_ball_boost_active"), "paddle bounce controller should preserve Wild Roar boost-active key")
	_expect(result.has("lingpet_wild_roar_ball_restore_speed"), "paddle bounce controller should preserve Wild Roar restore-speed key")
	_expect(result.has("lingpet_wild_roar_ball_boost_consumed"), "paddle bounce controller should preserve Wild Roar consumed key")
	_expect(result.has("lingpet_wild_roar_ball_restored_speed"), "paddle bounce controller should preserve Wild Roar restored-speed key")
	_expect(not bool(result.get("lingpet_wild_roar_ball_boost_active", true)), "allowlist chain should clear Wild Roar boost active")
	_expect(is_equal_approx(float(result.get("lingpet_wild_roar_ball_restore_speed", -1.0)), 0.0), "allowlist chain should clear Wild Roar restore speed")
	_expect(bool(result.get("lingpet_wild_roar_ball_boost_consumed", false)), "allowlist chain should report Wild Roar boost consumed")
	_expect(is_equal_approx(float(result.get("lingpet_wild_roar_ball_restored_speed", 0.0)), 26.0), "allowlist chain should preserve Wild Roar restored speed")
	_expect(not bool(result.get("speed_limit_disabled", true)), "allowlist chain should preserve speed_limit_disabled clear")


func _verify_apply_ball_speed_limits_on_off() -> void:
	var controller := BallFrameMotionController.new()
	var deps := {"ball_physics": FakeBallPhysics.new()}
	var capped_scene := {
		"ball_vel": Vector2(60.0, 0.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"lingpet_wild_roar_ball_boost_active": false,
		"speed_limit_disabled": false,
	}
	controller.apply_ball_speed_limits(capped_scene, deps)
	_expect(is_equal_approx((_get_vector2(capped_scene, "ball_vel", Vector2.ZERO)).length(), 26.0), "normal ball speed limit should clamp 60 to 26")
	var uncapped_scene := capped_scene.duplicate(true)
	uncapped_scene["ball_vel"] = Vector2(60.0, 0.0)
	uncapped_scene["lingpet_wild_roar_ball_boost_active"] = true
	controller.apply_ball_speed_limits(uncapped_scene, deps)
	_expect(is_equal_approx((_get_vector2(uncapped_scene, "ball_vel", Vector2.ZERO)).length(), 60.0), "Wild Roar boost active should bypass apply_ball_speed_limits clamp")
	uncapped_scene["lingpet_wild_roar_ball_boost_active"] = false
	controller.apply_ball_speed_limits(uncapped_scene, deps)
	_expect(is_equal_approx((_get_vector2(uncapped_scene, "ball_vel", Vector2.ZERO)).length(), 26.0), "clearing Wild Roar boost should restore normal apply_ball_speed_limits clamp")


func _verify_trigger_distance_roll_is_per_cycle() -> void:
	var owner := FakeOwner.new()
	owner.ball_pos = Vector2(300.0, 410.0)
	owner.ball_vel = Vector2(0.0, 26.0)
	var skill := LingpetWildRoarSkill.new()
	skill.set_trigger_distances_for_tests([118.0, 140.0])
	var params := _base_can_arm_params(owner, Vector2(300.0, 500.0))
	_expect(bool(skill.can_arm(params)), "first Wild Roar can_arm should consume the first trigger-distance roll")
	var first_distance := float(skill.get_snapshot().get("wild_roar_trigger_distance", 0.0))
	_expect(bool(skill.can_arm(params)), "second Wild Roar can_arm in the same cooldown-ready cycle should reuse the trigger window")
	var second_distance := float(skill.get_snapshot().get("wild_roar_trigger_distance", 0.0))
	_expect(is_equal_approx(first_distance, 118.0), "first trigger-distance roll should use the injected value")
	_expect(is_equal_approx(second_distance, first_distance), "trigger-distance roll should be one per cycle, not one per can_arm frame")
	_expect(bool(skill.launch(Vector2(300.0, 500.0), owner, {"active_skill_level": 1})), "launch should finish the current Wild Roar trigger-distance cycle")
	skill.update(2.0, owner, null)
	owner.ball_pos = Vector2(300.0, 385.0)
	owner.ball_vel = Vector2(0.0, 26.0)
	var next_params := _base_can_arm_params(owner, Vector2(300.0, 500.0))
	_expect(bool(skill.can_arm(next_params)), "next Wild Roar cycle should roll a fresh trigger window")
	_expect(is_equal_approx(float(skill.get_snapshot().get("wild_roar_trigger_distance", 0.0)), 140.0), "next trigger-distance cycle should consume the next injected roll")


func _verify_schema_reset_and_host_wiring() -> void:
	var state := BattleSceneState.new()
	_expect(state.has_key("lingpet_wild_roar_ball_boost_active"), "BattleSceneState should declare Wild Roar boost active key")
	_expect(state.has_key("lingpet_wild_roar_ball_restore_speed"), "BattleSceneState should declare Wild Roar restore-speed key")
	state.set_value("lingpet_wild_roar_ball_boost_active", true)
	state.set_value("lingpet_wild_roar_ball_restore_speed", 42.0)
	_expect(bool(state.get_value("lingpet_wild_roar_ball_boost_active")), "BattleSceneState should round-trip Wild Roar boost active")
	_expect(is_equal_approx(float(state.get_value("lingpet_wild_roar_ball_restore_speed")), 42.0), "BattleSceneState should round-trip Wild Roar restore speed")

	var owner := FakeOwner.new()
	var host := LingpetSkillRuntimeHost.new()
	owner.ball_pos = Vector2(300.0, 410.0)
	var params := _base_can_arm_params(owner, Vector2(300.0, 500.0))
	host.get_wild_roar_snapshot_for_tests()
	_expect(bool(host.can_arm(SKILL_ID, params)), "skill runtime host should dispatch Wild Roar can_arm")
	_expect(bool(host.launch(SKILL_ID, Vector2(300.0, 500.0), owner, {"active_skill_level": 5})), "skill runtime host should launch Wild Roar")
	_expect(bool(host.is_launch_blocked(SKILL_ID)), "Wild Roar should block re-arm while VFX is visible")
	_expect((host.get_boss_ai_context() as Dictionary).is_empty(), "Wild Roar must not contribute boss AI context")
	host.reset(owner, null)
	_expect(not owner.lingpet_wild_roar_ball_boost_active, "host reset should clear Wild Roar owner boost")


func _verify_source_wiring_surfaces() -> void:
	var egg_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(egg_src.find("\"roar_radius\"") >= 0 and egg_src.find("\"ball_boost\"") >= 0, "egg runtime should pass Wild Roar flattened level values")
	_expect(egg_src.find("\"companion_catch_height\"") >= 0, "egg runtime should pass catch height for dynamic arm_min_gap")
	var skill_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_wild_roar_skill.gd")
	_expect(skill_src.find("ROAR_ARM_TRAVEL_FACTOR := 1.5") >= 0, "Wild Roar can_arm should keep the low-tick dynamic travel factor")
	_expect(skill_src.find("ROAR_LAUNCH_SPEED_MAX := 60.0") >= 0, "Wild Roar module should own the 60 launch backstop")
	_expect(skill_src.find("ROAR_REFLECT_MIN_UPWARD_COMPONENT := 0.25") >= 0, "Wild Roar should only trim near-horizontal launch angles")
	_expect(skill_src.find("wild_roar_reflect_min_upward_component") >= 0, "Wild Roar snapshot should publish the anti-horizontal reflect contract")
	var frame_src := FileAccess.get_file_as_string("res://scripts/ball/ball_frame_motion_controller.gd")
	_expect(frame_src.find("ROAR_LAUNCH_SPEED_MAX") < 0, "apply_ball_speed_limits surface should not own Wild Roar's 60 backstop")
	var audio_src := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(audio_src.find("LINGPET_WILD_ROAR_SOUND_PATH") >= 0, "GameAudio should declare Wild Roar sound const")
	_expect(audio_src.find("LingpetWildRoarSfx") >= 0, "GameAudio setup should create the Wild Roar SFX player")
	_expect(audio_src.find("func play_lingpet_wild_roar") >= 0, "GameAudio should expose Wild Roar play method")


func _base_can_arm_params(owner: FakeOwner, companion_pos: Vector2) -> Dictionary:
	return {
		"owner": owner,
		"skill_id": SKILL_ID,
		"ball_active": owner.ball_active,
		"ball_pos": owner.ball_pos,
		"ball_vel": owner.ball_vel,
		"ball_size": owner.ball_size,
		"companion_visible": true,
		"companion_pos": companion_pos,
		"companion_radius": 24.0,
		"companion_catch_height": 54.0,
		"active_skill_level": 1,
		"roar_radius": 180.0,
		"ball_boost": 2.6,
	}


func _base_bounce_context() -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"ball_active": true,
		"ball_pos": Vector2(350.0, 65.0),
		"ball_vel": Vector2(0.0, -60.0),
		"ball_size": 28.6,
		"player_pos": Vector2(300.0, 700.0),
		"boss_pos": Vector2(300.0, 25.0),
		"player_y": 700.0,
		"boss_y": 25.0,
		"paddle_width": 100.0,
		"paddle_height": 50.0,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"max_bounce_angle": 60.0,
		"min_ball_speed": 3.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"base_ball_speed": 8.0,
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
		"vertical_bounce_count": 0,
		"ball_spin_strength": 0.0,
		"ball_spin_direction": 0,
		"drive_speed_increase": 0.0,
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"drive_text_timer_frames": 0.0,
		"special_gauge": 0.0,
		"player_speed": 0.0,
		"boss_vel": 0.0,
		"rally_speed_cap_increase_per_hit": 0.0,
		"smasher_wheel_speed_cap": 0.0,
		"commando_bowling_trap_guard_armed": false,
		"commando_suicide_drone_ball_boost_active": false,
		"lingpet_wild_roar_ball_boost_active": false,
		"lingpet_wild_roar_ball_restore_speed": 0.0,
		"speed_limit_disabled": false,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value if value is Vector2 else fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
