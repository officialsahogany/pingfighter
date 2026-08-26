extends SceneTree

const BattleSceneActorUpdateDriver := preload("res://scripts/core/battle_scene_actor_update_driver.gd")
const BattleSceneBallUpdateDriver := preload("res://scripts/core/battle_scene_ball_update_driver.gd")
const BattleSceneMatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const CheongringwiVisionChosikState := preload("res://scripts/characters/cheongringwi_vision_chosik_state.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const DaljiVisionChosikState := preload("res://scripts/characters/dalji_vision_chosik_state.gd")
const GaksitalVisionChosikState := preload("res://scripts/characters/gaksital_vision_chosik_state.gd")
const HornStrawberryCommandListener := preload("res://scripts/items/horn_strawberry_command_listener.gd")
const HornStrawberryBombState := preload("res://scripts/items/horn_strawberry_bomb_state.gd")
const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")
const CommandoFirearmInputResolver := preload("res://scripts/characters/commando_firearm_input_resolver.gd")
const CommandoFirearmLingeringNetFieldState := preload("res://scripts/characters/commando_firearm_lingering_net_field_state.gd")
const SmasherDriveInputState := preload("res://scripts/characters/smasher_drive_input_state.gd")
const SmasherMagnumGripState := preload("res://scripts/characters/smasher_magnum_grip_state.gd")
const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")
const SmasherWheelState := preload("res://scripts/characters/smasher_wheel_state.gd")
const ViperSkillCommandTracker := preload("res://scripts/characters/viper_skill_command_tracker.gd")
const ViperSkillCoreFlipRuntime := preload("res://scripts/characters/viper_skill_core_flip_runtime.gd")
const VisionInputExclusivePolicy := preload("res://scripts/characters/vision_input_exclusive_policy.gd")
const VisionModifierInputProxy := preload("res://scripts/characters/vision_modifier_input_proxy.gd")
const YeonmyoVisionChosikState := preload("res://scripts/characters/yeonmyo_vision_chosik_state.gd")
const Stage3CurseControlInputProxy := preload("res://scripts/stages/stage3/stage3_curse_control_input_proxy.gd")

const MOVEMENT_LATCH_FIXTURE_ENV := "VISION_MOVEMENT_LATCH_EXEMPT_FIXTURE"
const DRIVE_BUFFER_FIXTURE_ENV := "VISION_DRIVE_BUFFER_DISCARD_FIXTURE"
const CORE_FLIP_GUARD_FIXTURE_ENV := "VISION_CORE_FLIP_GUARD_FIXTURE"
const STATUS_MOVEMENT_FIXTURE_ENV := "VISION_STATUS_MOVEMENT_TRANSFORM_FIXTURE"
const HORN_BOMB_GUARD_FIXTURE_ENV := "VISION_HORN_BOMB_GUARD_FIXTURE"
const SAME_FRAME_REBUILD_FIXTURE_ENV := "VISION_SAME_FRAME_REBUILD_FIXTURE"

var _failures: Array[String] = []


class FakeSkillConfig:
	extends RefCounted

	var equipped: Array[String] = []

	func _init(skill_ids: Array[String] = []) -> void:
		equipped = skill_ids.duplicate()

	func is_skill_equipped(skill_id: String) -> bool:
		return equipped.has(skill_id)


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}
	var calls := 0

	func get_snapshot() -> Dictionary:
		calls += 1
		return snapshot.duplicate(true)


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var special_gauge := 500.0
	var player_pos := Vector2(300.0, 680.0)
	var player_speed := 0.0
	var gameplay_frame_counter := 0


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeContextBuilder:
	extends RefCounted

	var deps: Dictionary = {}

	func build_player_control_deps(_registry: Object, _character_type: String) -> Dictionary:
		return deps.duplicate()


class FakeConfigBuilder:
	extends RefCounted

	func build_config(_owner: Object, _registry: Object, _character_type: String, _context_builder: Object) -> Dictionary:
		return {
			"special_gauge": 500.0,
			"ball_active": true,
			"player_skill_input_locked": false,
			"horizontal_input_locked": false,
		}


class FakeMatchContextBuilder:
	extends RefCounted

	func build_match_flow_deps(_registry: Object, _current_stage: int) -> Dictionary:
		return {}


class FakeController:
	extends RefCounted

	var input_reader: Object = null
	var dash_input_reader: Object = null
	var snapshot: Dictionary = {}
	var config: Dictionary = {}

	func update(
		_delta: float,
		frame_counter: int,
		player_pos: Vector2,
		player_speed: float,
		incoming_config: Dictionary,
		deps: Dictionary
	) -> Dictionary:
		input_reader = deps.get("input_reader", null)
		dash_input_reader = deps.get("dash_input_reader", null)
		snapshot = input_reader.get_snapshot() if input_reader != null else {}
		config = incoming_config.duplicate(true)
		return {
			"frame_counter": frame_counter + 1,
			"player_pos": player_pos,
			"player_speed": player_speed,
			"special_gauge": float(incoming_config.get("special_gauge", 0.0)),
		}


class FakeResultApplier:
	extends RefCounted

	func apply_player_result(owner: Object, _registry: Object, result: Dictionary) -> void:
		for key: String in result:
			owner.set(key, result[key])

	func apply_boss_result(_owner: Object, _result: Dictionary) -> void:
		pass


class FakeAudio:
	extends RefCounted

	var quake_play_calls := 0
	var quake_stop_calls := 0

	func play_stage2_quake_loop() -> void:
		quake_play_calls += 1

	func stop_stage2_quake_loop() -> void:
		quake_stop_calls += 1


class FakeViperVisibilityQuery:
	extends RefCounted

	func is_skill_equipped(_skill_config: Object, _skill_name: String) -> bool:
		return false

	func is_configured_skill_ready(_skill_name: String, _deps: Dictionary, _fallback_msec: int) -> bool:
		return false


class FakeViperCommandRuntime:
	extends RefCounted

	var input_sequence_frame := 0
	var previous_down_pressed := false
	var previous_up_pressed := false
	var previous_left_pressed := false
	var previous_right_pressed := false
	var dual_glitch_cmd_buffer: Array = [{"key": "a", "time": 1}]
	var chaos_cmd_buffer: Array = [{"key": "a", "time": 1}]
	var core_flip_left_press_frame := 10
	var core_flip_right_press_frame := 20
	var dual_glitch_state := "idle"
	var chaos_state := "idle"
	var visibility_query: Object = FakeViperVisibilityQuery.new()

	func _is_core_flip_ready_window_active(_now_msec: int) -> bool:
		return false


class FakeReverseStatus:
	extends RefCounted

	func is_player_reverse_active() -> bool:
		return true


class FakeCoreFlipVisibility:
	extends RefCounted

	func get_dash_snapshot(_dash_state: Object) -> Dictionary:
		return {"active": false}

	func is_control_locked(_deps: Dictionary) -> bool:
		return false

	func is_round_waiting_for_serve(_deps: Dictionary) -> bool:
		return false

	func get_viper_skill_config(_deps: Dictionary) -> Object:
		return null

	func is_skill_equipped(_skill_config: Object, _skill_name: String) -> bool:
		return true

	func is_configured_skill_ready(_skill_name: String, _deps: Dictionary, _now_msec: int) -> bool:
		return true


class FakeCoreFlipFeedbackRouter:
	extends RefCounted

	func trigger_feedback(_deps: Dictionary, _amount: float, _intensity: float) -> void:
		pass


class FakeCoreFlipAudioRouter:
	extends RefCounted

	func play_core_flip_spin_sound(_deps: Dictionary) -> void:
		pass


class FakeCoreFlipRuntime:
	extends RefCounted

	var input_sequence_frame := 10
	var core_flip_left_press_frame := -999999
	var core_flip_right_press_frame := -999999
	var core_flip_ready_msec := 1000
	var core_flip_buffered_until_msec := 0
	var shadow_hologram_active := false
	var chaos_state := "idle"
	var visibility_query: Object = FakeCoreFlipVisibility.new()
	var runtime_action_router: Object = FakeCoreFlipFeedbackRouter.new()
	var audio_router: Object = FakeCoreFlipAudioRouter.new()
	var core_flip_consumed := false
	var dash_origin_valid := true
	var dash_grace_frames := 5.0
	var core_flip_attack_active := false
	var core_flip_attack_phase := 0
	var core_flip_phase_frames := 0.0
	var core_flip_paddle_size := Vector2.ZERO
	var core_flip_origin_center := Vector2.ZERO
	var core_flip_target_center := Vector2.ZERO
	var core_flip_apex_center := Vector2.ZERO
	var core_flip_visual_pos := Vector2.ZERO
	var core_flip_return_start_center := Vector2.ZERO
	var core_flip_kick_dir := 1
	var core_flip_ball_hit := false
	var core_flip_spin_angle_degrees := 0.0
	var core_flip_spin_sound_started := false
	var core_flip_kick_sound_played := false
	var core_flip_web_lines: Array = []
	var shadow_marshal_delay_frames := 0.0
	var shadow_marshal_delay_from_shadow_step := false

	func _is_core_flip_ready_window_active(_now_msec: int) -> bool:
		return true

	func _has_viper_attack_motion_active(_include_dive: bool = false) -> bool:
		return false

	func _get_skill_cost_with_fallback(_config: Object, _skill_name: String, fallback: float) -> float:
		return fallback

	func _trigger_configured_skill_cooldown(_skill_name: String, _config: Object, _deps: Dictionary, _now_msec: int) -> void:
		pass

	func _trigger_orb_gauge_spin(_deps: Dictionary, _now_msec: int) -> void:
		pass

	func _cancel_dash_until_key_release(_dash_state: Object) -> void:
		pass

	func _clear_marshal_ready_window() -> void:
		pass

	func _clear_double_marshal_ready_window() -> void:
		pass

	func _clear_marshal_first_hit_pending() -> void:
		pass


class FakeBombRuntime:
	extends RefCounted

	func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
		if owner == null:
			return fallback
		var value: Variant = owner.get(key)
		return fallback if value == null else value


class FakeMovementState:
	extends RefCounted

	var last_direction := 0.0

	func update_horizontal(
		_delta: float,
		player_pos: Vector2,
		player_speed: float,
		direction: float,
		_play_left: float,
		_play_right: float,
		_paddle_width: float,
		_config: Dictionary
	) -> Dictionary:
		last_direction = direction
		return {
			"player_pos": player_pos + Vector2(direction * 10.0, 0.0),
			"player_speed": player_speed,
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment(MOVEMENT_LATCH_FIXTURE_ENV) == "1":
		print("[VisionMovementLatchCounterproof] MOVEMENT_LATCH_EXEMPT_REMOVED=EXPECTED_RED")
		_verify_release_restores_held_movement(true)
		_finish()
		return
	if OS.get_environment(DRIVE_BUFFER_FIXTURE_ENV) == "1":
		print("[VisionMovementLatchCounterproof] DRIVE_BUFFER_DISCARD_REMOVED=EXPECTED_RED")
		_verify_drive_buffer_discards_vision_directions(true)
		_finish()
		return
	if OS.get_environment(CORE_FLIP_GUARD_FIXTURE_ENV) == "1":
		print("[VisionMovementLatchCounterproof] F1_CORE_FLIP_GUARD_REMOVED=EXPECTED_RED")
		_verify_core_flip_guard(true)
		_finish()
		return
	if OS.get_environment(STATUS_MOVEMENT_FIXTURE_ENV) == "1":
		print("[VisionMovementLatchCounterproof] F2_STATUS_MOVEMENT_TRANSFORM_REMOVED=EXPECTED_RED")
		_verify_status_transformed_movement(true)
		_finish()
		return
	if OS.get_environment(HORN_BOMB_GUARD_FIXTURE_ENV) == "1":
		print("[VisionMovementLatchCounterproof] F3_HORN_BOMB_GUARD_REMOVED=EXPECTED_RED")
		_verify_horn_bomb_guard(true)
		_finish()
		return
	if OS.get_environment(SAME_FRAME_REBUILD_FIXTURE_ENV) == "1":
		print("[VisionMovementLatchCounterproof] G1_SAME_FRAME_IDEMPOTENCE_REMOVED=EXPECTED_RED")
		_verify_mythic_first_same_frame_rebuild(true)
		_finish()
		return

	_verify_loadout_channel_union()
	_verify_base_controller_uses_movement_lane()
	_verify_status_transformed_movement(false)
	_verify_mythic_first_same_frame_rebuild(false)
	_verify_cached_skill_config_fallback()
	_verify_release_restores_held_movement(false)
	_verify_edge_channels_keep_release_latch()
	_verify_horn_command_buffer_discards_vision_movement()
	_verify_other_command_consumers_discard_vision_movement()
	_verify_core_flip_guard(false)
	_verify_horn_bomb_guard(false)
	_verify_driver_horizontal_and_dash_boundaries()
	_verify_drive_buffer_discards_vision_directions(false)
	_verify_vision_cooldowns_and_quake_audio_tick()
	_verify_reset_lifecycle_owns_release_latch()
	Input.action_release("vision_modifier")
	if _failures.is_empty():
		print("[VisionMovementLatchSeal] M2=GREEN gaksital_horizontal=pass dalji_horizontal=pass cheongringwi_horizontal=blocked union=blocked mixed_input=coalesced")
		print("[VisionMovementLatchSeal] M3=GREEN release_movement=immediate edge_latch=preserved dash_reader=raw")
		print("[VisionMovementLatchSeal] DERIVED=GREEN power_smash=0 blacksmith_swing=0 drive_buffer=discarded command_buffers=discarded")
		print("[VisionMovementLatchSeal] FOLLOWUP=GREEN F1=core_flip_blocked F2=reverse_preserved F3=horn_bomb_blocked F4=split_channels movement_owner=passed F6=combat_steering_zero")
		print("[VisionMovementLatchSeal] LIFECYCLE=GREEN cooldowns=4/4 quake_loop=continuous score_reset=retained round_restart=cleared")
		print("[VisionMovementLatchSeal] FIX2=GREEN G1=mythic_first_idempotent release_edges=discarded combat_filter=true G2=skill_config_fallback G3=single_copy")
	_finish()


func _verify_loadout_channel_union() -> void:
	var horizontal_snapshot := {
		"left_pressed": true,
		"right_pressed": false,
		"direction": -1.0,
		"power_smash_direction": -1,
		"blacksmith_swing_direction": -1,
	}
	for skill_id: String in [
		CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID,
		CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID,
		CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID,
	]:
		var skill_config := FakeSkillConfig.new([skill_id])
		var blocked_channels := VisionInputExclusivePolicy.get_blocked_hold_channels(skill_config)
		var filtered: Dictionary = VisionModifierInputProxy.new().configure_snapshot(
			null,
			horizontal_snapshot,
			true,
			blocked_channels
		).get_snapshot()
		_expect(not bool(filtered.get("left_pressed", true)), "%s-only Vision command-left lane" % skill_id)
		_expect_close(float(filtered.get("direction", 1.0)), 0.0, "%s-only Vision command direction" % skill_id)
		_expect(bool(filtered.get("movement_left_pressed", false)), "%s-only Vision dedicated movement-left lane" % skill_id)
		_expect_close(float(filtered.get("movement_direction", 0.0)), -1.0, "%s-only Vision movement direction" % skill_id)
		_expect_eq(int(filtered.get("power_smash_direction", 1)), 0, "%s derived power-smash direction" % skill_id)
		_expect_eq(int(filtered.get("blacksmith_swing_direction", 1)), 0, "%s derived blacksmith direction" % skill_id)

	var cheong_config := FakeSkillConfig.new([CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID])
	var cheong_filtered: Dictionary = VisionModifierInputProxy.new().configure_snapshot(
		null,
		horizontal_snapshot,
		true,
		VisionInputExclusivePolicy.get_blocked_hold_channels(cheong_config)
	).get_snapshot()
	_expect(not bool(cheong_filtered.get("left_pressed", true)), "Cheongringwi-only Vision must still own left movement")
	_expect_close(float(cheong_filtered.get("direction", 1.0)), 0.0, "Cheongringwi-only Vision movement lock")
	_expect(not bool(cheong_filtered.get("movement_left_pressed", true)), "Cheongringwi-only Vision must block the dedicated movement lane")
	_expect_close(float(cheong_filtered.get("movement_direction", 1.0)), 0.0, "Cheongringwi-only dedicated movement lock")

	var union_config := FakeSkillConfig.new([
		CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID,
		CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID,
	])
	_expect(VisionInputExclusivePolicy.blocks_horizontal_movement(union_config), "Cheongringwi plus Dalji must union to horizontal ownership")

	# Character readers OR keyboard and gamepad sources into these same two
	# levels. Opposing mixed-device input therefore remains neutral for a
	# non-Cheongringwi loadout and remains fully blocked for Cheongringwi.
	var mixed_snapshot := {"left_pressed": true, "right_pressed": true, "direction": 0.0}
	var dalji_config := FakeSkillConfig.new([CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID])
	var mixed_dalji: Dictionary = VisionModifierInputProxy.new().configure_snapshot(
		null,
		mixed_snapshot,
		true,
		VisionInputExclusivePolicy.get_blocked_hold_channels(dalji_config)
	).get_snapshot()
	_expect(not bool(mixed_dalji.get("left_pressed", true)) and not bool(mixed_dalji.get("right_pressed", true)), "mixed keyboard and gamepad command levels must stay blocked")
	_expect_close(float(mixed_dalji.get("direction", 1.0)), 0.0, "opposing mixed-device movement must stay neutral")
	_expect(bool(mixed_dalji.get("movement_left_pressed", false)) and bool(mixed_dalji.get("movement_right_pressed", false)), "mixed keyboard and gamepad levels must pass only through the Dalji movement lane")
	var mixed_cheong: Dictionary = VisionModifierInputProxy.new().configure_snapshot(
		null,
		mixed_snapshot,
		true,
		VisionInputExclusivePolicy.get_blocked_hold_channels(cheong_config)
	).get_snapshot()
	_expect(not bool(mixed_cheong.get("left_pressed", true)) and not bool(mixed_cheong.get("right_pressed", true)), "Cheongringwi Vision must block both mixed-device movement levels")

	var steering_snapshot := horizontal_snapshot.duplicate(true)
	steering_snapshot["up_pressed"] = true
	var steering_filtered: Dictionary = VisionModifierInputProxy.new().configure_snapshot(
		null,
		steering_snapshot,
		true,
		VisionInputExclusivePolicy.get_blocked_hold_channels(dalji_config)
	).get_snapshot()
	_expect_eq(CommandoFirearmInputResolver.get_suicide_drone_input_vector(steering_filtered), Vector2.ZERO, "F6 suicide-drone steering must receive no partial direction")
	_expect_eq(CommandoFirearmLingeringNetFieldState.get_net_constrict_input_direction(steering_filtered), 0, "F6 lingering-net steering must receive no horizontal direction")


func _verify_release_restores_held_movement(remove_exemption: bool) -> void:
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID])
	var blocked_channels := VisionInputExclusivePolicy.get_blocked_hold_channels(skill_config)
	var proxy := VisionModifierInputProxy.new()
	if remove_exemption:
		proxy.set_movement_latch_exempt_channels_for_test([])
	var held_left := {"left_pressed": true, "direction": -1.0}
	var blocked: Dictionary = proxy.configure_snapshot(null, held_left, true, blocked_channels).get_snapshot()
	_expect(not bool(blocked.get("left_pressed", true)), "Cheongringwi Vision must block held left while Shift is down")
	var released: Dictionary = proxy.configure_snapshot(null, held_left, false, blocked_channels).get_snapshot()
	_expect(bool(released.get("left_pressed", false)), "held movement must return on the Shift release frame")
	_expect(float(released.get("direction", 0.0)) != 0.0, "movement direction must return on the Shift release frame")
	_expect(not proxy.should_filter_current_snapshot(), "movement-only Shift release must return the controller and dash lanes to raw input")


func _verify_base_controller_uses_movement_lane() -> void:
	var reader := FakeInputReader.new()
	reader.snapshot = {
		"left_pressed": false,
		"right_pressed": false,
		"direction": 0.0,
		"movement_left_pressed": true,
		"movement_right_pressed": false,
		"movement_direction": -1.0,
		"vision_input_exclusive": true,
	}
	var movement := FakeMovementState.new()
	var result: Dictionary = SmasherPlayerController.new().update(
		0.0,
		0,
		Vector2(300.0, 680.0),
		0.0,
		{
			"ball_active": true,
			"player_skill_input_locked": false,
			"special_gauge": 500.0,
			"play_left": 0.0,
			"play_right": 760.0,
			"paddle_width": 155.0,
			"paddle_height": 50.0,
			"vision_input_exclusive": true,
		},
		{
			"input_reader": reader,
			"dash_input_reader": reader,
			"movement_state": movement,
		}
	)
	_expect_close(movement.last_direction, -1.0, "F4 base movement owner must opt into movement_direction")
	_expect_close((result.get("player_pos", Vector2.ZERO) as Vector2).x, 290.0, "F4 dedicated movement lane must still translate the player")


func _verify_edge_channels_keep_release_latch() -> void:
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	var blocked_channels := VisionInputExclusivePolicy.get_blocked_hold_channels(skill_config)
	var proxy := VisionModifierInputProxy.new()
	var held := {
		"left_pressed": true,
		"direction": -1.0,
		"action_pressed": true,
		"action_just_pressed": true,
		"mouse_right_pressed": true,
		"secondary_action_pressed": true,
		"secondary_action_just_pressed": true,
	}
	proxy.configure_snapshot(null, held, true, blocked_channels)
	var released: Dictionary = proxy.configure_snapshot(null, held, false, blocked_channels).get_snapshot()
	_expect(bool(released.get("left_pressed", false)), "movement must pass while combat edges drain")
	for channel: String in ["action_pressed", "mouse_right_pressed", "secondary_action_pressed"]:
		_expect(not bool(released.get(channel, true)), "%s must remain suppressed until physical release" % channel)
	_expect(proxy.should_filter_current_snapshot(), "edge-release drain must keep the shared proxy active")


func _verify_horn_command_buffer_discards_vision_movement() -> void:
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	var blocked_channels := VisionInputExclusivePolicy.get_blocked_hold_channels(skill_config)
	var proxy := VisionModifierInputProxy.new()
	var listener := HornStrawberryCommandListener.new()
	var completed := false
	for snapshot: Dictionary in [
		{"left_pressed": true, "direction": -1.0},
		{},
		{"right_pressed": true, "direction": 1.0},
		{},
		{"left_pressed": true, "direction": -1.0},
		{},
		{"right_pressed": true, "direction": 1.0},
		{},
		{"left_pressed": true, "direction": -1.0},
		{},
		{"right_pressed": true, "direction": 1.0},
	]:
		var filtered: Dictionary = proxy.configure_snapshot(null, snapshot, true, blocked_channels).get_snapshot()
		completed = listener.feed_input_snapshot(filtered, 0.05) or completed
	_expect(not completed, "Vision movement must not complete the horn-strawberry transform command")
	_expect_eq(int(listener.get_context().get("buffer_size", -1)), 0, "Vision movement must leave the horn command buffer empty")


func _verify_other_command_consumers_discard_vision_movement() -> void:
	var magnum := SmasherMagnumGripState.new()
	var magnum_deps := {"skill_config": FakeSkillConfig.new(["magnum_grip"])}
	magnum.update_input({"left_pressed": true, "right_pressed": true, "vision_input_exclusive": true}, 1000, 500.0, magnum_deps)
	var magnum_held: Dictionary = magnum.update_input({"left_pressed": true, "right_pressed": true, "vision_input_exclusive": true}, 1400, 500.0, magnum_deps)
	_expect(not bool(magnum_held.get("activated", true)), "Vision movement must not activate Magnum Grip")
	var magnum_release: Dictionary = magnum.update_input({"left_pressed": true, "right_pressed": true}, 1800, 500.0, magnum_deps)
	_expect(not bool(magnum_release.get("activated", true)), "held Vision directions must not arm Magnum Grip after Shift release")

	var wheel := SmasherWheelState.new()
	var wheel_config := {"ball_active": true, "player_skill_input_locked": false}
	var wheel_deps := {"skill_config": FakeSkillConfig.new(["smasher_wheel"])}
	wheel.update_input({"left_pressed": true, "vision_input_exclusive": true}, 1000, 500.0, Vector2.ZERO, wheel_config, wheel_deps)
	wheel.update_input({"up_pressed": true, "vision_input_exclusive": true}, 1100, 500.0, Vector2.ZERO, wheel_config, wheel_deps)
	wheel.update_input({"right_pressed": true, "vision_input_exclusive": true}, 1200, 500.0, Vector2.ZERO, wheel_config, wheel_deps)
	_expect(wheel.command_buffer.is_empty(), "Vision movement must leave the Wheel command buffer empty")
	wheel.update_input({"right_pressed": true}, 1201, 500.0, Vector2.ZERO, wheel_config, wheel_deps)
	_expect(wheel.command_buffer.is_empty(), "held Vision direction must not become a Wheel edge after Shift release")

	var viper_runtime := FakeViperCommandRuntime.new()
	var viper_tracker := ViperSkillCommandTracker.new()
	var vision_result: Dictionary = viper_tracker.update_before_movement(
		viper_runtime,
		{"left_pressed": true, "vision_input_exclusive": true},
		null,
		{},
		1000,
		{}
	)
	_expect(bool(vision_result.get("left_pressed", false)), "Viper movement level must remain available during Vision")
	_expect(not bool(vision_result.get("left_edge", true)), "Viper command edge must be discarded during Vision")
	_expect(viper_runtime.dual_glitch_cmd_buffer.is_empty(), "Vision must clear the Viper dual-glitch command buffer")
	_expect(viper_runtime.chaos_cmd_buffer.is_empty(), "Vision must clear the Viper chaos command buffer")
	_expect_eq(viper_runtime.core_flip_left_press_frame, -999999, "Vision must clear the Viper core-flip left edge")
	_expect_eq(viper_runtime.core_flip_right_press_frame, -999999, "Vision must clear the Viper core-flip right edge")
	var viper_release: Dictionary = viper_tracker.update_before_movement(viper_runtime, {"left_pressed": true}, null, {}, 1001, {})
	_expect(not bool(viper_release.get("left_edge", true)), "held Vision direction must not become a Viper command edge after Shift release")


func _verify_driver_horizontal_and_dash_boundaries() -> void:
	var reader := FakeInputReader.new()
	reader.snapshot = {"left_pressed": true, "direction": -1.0}
	var original_dash_reader := FakeInputReader.new()
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	var controller := FakeController.new()
	var context_builder := FakeContextBuilder.new()
	context_builder.deps = {
		"input_reader": reader,
		"dash_input_reader": original_dash_reader,
		"skill_config": skill_config,
	}
	var actor_driver := BattleSceneActorUpdateDriver.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"battle_update_context": context_builder,
		"battle_scene_player_control_config_builder": FakeConfigBuilder.new(),
		"battle_scene_actor_update_result_applier": FakeResultApplier.new(),
		"smasher_input_reader": reader,
		"smasher_skill_config": skill_config,
		"smasher_player_controller": controller,
	})
	Input.action_press("vision_modifier")
	actor_driver.update_player_control(owner, registry, 0.0)
	_expect(controller.dash_input_reader == controller.input_reader, "Vision hold must share the filtered reader with the dash lane")
	_expect(not bool(controller.config.get("horizontal_input_locked", false)), "Gaksital-only Vision must leave gate B open")
	actor_driver.reset_vision_input_frame_cache_for_test()
	Input.action_release("vision_modifier")
	actor_driver.update_player_control(owner, registry, 0.0)
	_expect(controller.dash_input_reader == original_dash_reader, "movement-only release must not overwrite the raw dash reader")

	var cheong_result := _run_driver_loadout([CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID])
	_expect(bool(cheong_result.get("horizontal_input_locked", false)), "Cheongringwi-only Vision must retain gate B")
	var union_result := _run_driver_loadout([
		CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID,
		CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID,
	])
	_expect(bool(union_result.get("horizontal_input_locked", false)), "Cheongringwi loadout union must retain gate B")


func _run_driver_loadout(skill_ids: Array[String]) -> Dictionary:
	var reader := FakeInputReader.new()
	reader.snapshot = {"left_pressed": true, "direction": -1.0}
	var skill_config := FakeSkillConfig.new(skill_ids)
	var controller := FakeController.new()
	var context_builder := FakeContextBuilder.new()
	context_builder.deps = {"input_reader": reader, "skill_config": skill_config}
	var registry := FakeRegistry.new({
		"battle_update_context": context_builder,
		"battle_scene_player_control_config_builder": FakeConfigBuilder.new(),
		"battle_scene_actor_update_result_applier": FakeResultApplier.new(),
		"smasher_input_reader": reader,
		"smasher_skill_config": skill_config,
		"smasher_player_controller": controller,
	})
	Input.action_press("vision_modifier")
	BattleSceneActorUpdateDriver.new().update_player_control(FakeOwner.new(), registry, 0.0)
	Input.action_release("vision_modifier")
	return controller.config.duplicate(true)


func _verify_status_transformed_movement(disable_transform: bool) -> void:
	var raw_reader := FakeInputReader.new()
	raw_reader.snapshot = {"left_pressed": true, "right_pressed": false, "direction": -1.0}
	var status_reader: Object = Stage3CurseControlInputProxy.new().configure(
		raw_reader,
		null,
		FakeReverseStatus.new()
	)
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID])
	var actor_driver := BattleSceneActorUpdateDriver.new()
	if disable_transform:
		actor_driver.set_vision_status_movement_transform_enabled_for_test(false)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"smasher_input_reader": raw_reader,
		"smasher_skill_config": skill_config,
	})
	Input.action_press("vision_modifier")
	var frame: Dictionary = actor_driver.prepare_vision_input_frame(
		owner,
		registry,
		status_reader,
		skill_config,
		status_reader
	)
	var filtered: Dictionary = frame.get("input_reader", null).get_snapshot()
	Input.action_release("vision_modifier")
	_expect_eq(raw_reader.calls, 1, "F2 Vision status movement path must retain one raw read")
	_expect(not bool(filtered.get("left_pressed", true)) and not bool(filtered.get("right_pressed", true)), "F4 command lanes must remain zero after status transform")
	_expect(not bool(filtered.get("movement_left_pressed", true)), "F2 raw left must become reversed movement-right")
	_expect(bool(filtered.get("movement_right_pressed", false)), "F2 reverse curse must reach the dedicated movement lane")
	_expect_close(float(filtered.get("movement_direction", 0.0)), 1.0, "F2 reverse curse movement direction")


func _verify_mythic_first_same_frame_rebuild(disable_idempotence: bool) -> void:
	var raw_reader := FakeInputReader.new()
	var status_reader: Object = Stage3CurseControlInputProxy.new().configure(
		raw_reader,
		null,
		null
	)
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	var actor_driver := BattleSceneActorUpdateDriver.new()
	if disable_idempotence:
		actor_driver.set_vision_same_frame_rebuild_idempotence_enabled_for_test(false)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"smasher_input_reader": raw_reader,
		"smasher_skill_config": skill_config,
	})

	# Frame N-1 arms all three held-command latches.
	raw_reader.snapshot = {
		"action_pressed": true,
		"mouse_right_pressed": true,
		"secondary_action_pressed": true,
	}
	Input.action_press("vision_modifier")
	var armed_reader: Object = actor_driver.get_vision_aware_input_reader(
		owner,
		registry,
		raw_reader,
		skill_config
	)
	_expect(armed_reader.has_pending_release_suppression(), "G1 prior frame must arm held command latches")

	# Frame N mirrors production ordering: a three-argument mythic/raw caller
	# builds first, then player control enriches that cache with the status proxy.
	actor_driver.reset_vision_input_frame_cache_for_test()
	raw_reader.snapshot = {
		"action_pressed": false,
		"action_just_released": true,
		"mouse_right_pressed": false,
		"secondary_action_pressed": false,
		"secondary_action_just_pressed": true,
	}
	Input.action_release("vision_modifier")
	var calls_before_release := raw_reader.calls
	var mythic_reader: Object = actor_driver.get_vision_aware_input_reader(
		owner,
		registry,
		raw_reader
	)
	var refreshed_frame: Dictionary = actor_driver.prepare_vision_input_frame(
		owner,
		registry,
		status_reader,
		skill_config,
		status_reader
	)
	var refreshed_reader: Object = refreshed_frame.get("input_reader", null)
	var filtered: Dictionary = refreshed_reader.get_snapshot()
	_expect(mythic_reader == refreshed_reader, "G1 mythic-first and player-control callers must retain one proxy")
	_expect_eq(raw_reader.calls - calls_before_release, 1, "G1 mythic-first release frame must sample raw input once")
	_expect(bool(refreshed_frame.get("combat_input_filtered", false)), "G1 same-frame rebuild must retain combat_input_filtered=true")
	_expect(not bool(filtered.get("action_just_released", true)), "G1 action release edge must stay discarded after status rebuild")
	_expect(not bool(filtered.get("secondary_action_just_pressed", true)), "G1 secondary action edge must stay discarded after status rebuild")
	_expect(not refreshed_reader.has_pending_release_suppression(), "G1 physical release must still clear next-frame latch state")


func _verify_cached_skill_config_fallback() -> void:
	var raw_reader := FakeInputReader.new()
	raw_reader.snapshot = {"left_pressed": true, "direction": -1.0}
	var status_reader: Object = Stage3CurseControlInputProxy.new().configure(
		raw_reader,
		null,
		null
	)
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	var actor_driver := BattleSceneActorUpdateDriver.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"smasher_input_reader": raw_reader,
		"smasher_skill_config": skill_config,
	})
	Input.action_press("vision_modifier")
	actor_driver.get_vision_aware_input_reader(owner, registry, raw_reader)
	var refreshed_frame: Dictionary = actor_driver.prepare_vision_input_frame(
		owner,
		registry,
		status_reader,
		null,
		status_reader
	)
	Input.action_release("vision_modifier")
	var filtered: Dictionary = refreshed_frame.get("input_reader", null).get_snapshot()
	_expect(not bool(refreshed_frame.get("horizontal_input_blocked", true)), "G2 cached Gaksital config must keep horizontal movement unlocked")
	_expect(not bool(filtered.get("left_pressed", true)), "G2 command-left lane must remain Vision-owned")
	_expect(bool(filtered.get("movement_left_pressed", false)), "G2 null refresh must reuse cached Gaksital movement policy")
	_expect_close(float(filtered.get("movement_direction", 0.0)), -1.0, "G2 cached movement direction")


func _verify_core_flip_guard(disable_guard: bool) -> void:
	var runtime := FakeCoreFlipRuntime.new()
	var constants := {
		"vision_exclusive_guard_enabled": not disable_guard,
		"skill_name": "core_flip",
		"fallback_cost": 120.0,
	}
	var result: Dictionary = ViperSkillCoreFlipRuntime.try_ready_activation(
		runtime,
		{
			"left_pressed": true,
			"right_pressed": true,
			"vision_input_exclusive": true,
		},
		Vector2(300.0, 680.0),
		500.0,
		{
			"ball_active": true,
			"paddle_width": 155.0,
			"paddle_height": 50.0,
			"ball_pos": Vector2(380.0, 350.0),
		},
		{"dash_state": null},
		1000,
		constants
	)
	_expect(not bool(result.get("activated", false)), "F1 Shift Vision must not activate Hwarang Kick/Core Flip")
	_expect(not runtime.core_flip_attack_active, "F1 Core Flip attack state must remain inactive")
	_expect_close(float(result.get("special_gauge", 500.0)), 500.0, "F1 Core Flip guard must not consume gauge")


func _verify_horn_bomb_guard(disable_guard: bool) -> void:
	var bomb := HornStrawberryBombState.new()
	if disable_guard:
		bomb.set_vision_exclusive_guard_enabled_for_test(false)
	var owner := FakeOwner.new()
	owner.special_gauge = 500.0
	var activated := bomb.update_input(
		{
			"left_pressed": true,
			"right_pressed": true,
			"vision_input_exclusive": true,
		},
		0.6,
		owner,
		FakeBombRuntime.new()
	)
	_expect(not activated, "F3 Shift Vision must not activate the horn strawberry bomb")
	_expect(not bomb.holding and is_zero_approx(bomb.hold_timer_sec), "F3 guard must clear horn bomb hold state")
	_expect_close(owner.special_gauge, 500.0, "F3 horn bomb guard must not consume gauge")


func _verify_drive_buffer_discards_vision_directions(disable_guard: bool) -> void:
	var controller := SmasherPlayerController.new()
	var drive_input_state := SmasherDriveInputState.new()
	if disable_guard:
		drive_input_state.buffer_state.set_exclusive_discard_enabled_for_test(false)
	var reader := FakeInputReader.new()
	var deps := {"input_reader": reader, "drive_input_state": drive_input_state}
	var config := {
		"vision_input_exclusive": true,
		"ball_active": true,
		"player_skill_input_locked": false,
		"special_gauge": 500.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
	}
	for frame_data: Dictionary in [
		{"frame": 0, "left_pressed": true, "right_pressed": false, "direction": -1.0},
		{"frame": 1, "left_pressed": false, "right_pressed": false, "direction": 0.0},
		{"frame": 2, "left_pressed": false, "right_pressed": true, "direction": 1.0},
		{"frame": 3, "left_pressed": true, "right_pressed": false, "direction": -1.0},
	]:
		reader.snapshot = frame_data.duplicate(true)
		deps["vision_exclusive_raw_snapshot"] = reader.snapshot.duplicate(true)
		controller.update(0.0, int(frame_data.get("frame", 0)), Vector2.ZERO, 0.0, config, deps)

	config["vision_input_exclusive"] = false
	deps.erase("vision_exclusive_raw_snapshot")
	reader.snapshot = {"left_pressed": true, "direction": -1.0}
	controller.update(0.0, 4, Vector2.ZERO, 0.0, config, deps)
	reader.snapshot = {"left_pressed": true, "action_pressed": true, "direction": -1.0}
	controller.update(0.0, 7, Vector2.ZERO, 0.0, config, deps)
	_expect_eq(drive_input_state.consume_direction(8), 0, "Vision L-R-L must not leak into Drive after Shift release")


func _verify_vision_cooldowns_and_quake_audio_tick() -> void:
	var states: Array[Object] = [
		DaljiVisionChosikState.new(),
		GaksitalVisionChosikState.new(),
		CheongringwiVisionChosikState.new(),
		YeonmyoVisionChosikState.new(),
	]
	var audio := FakeAudio.new()
	for state: Object in states:
		state.cooldown_remaining = 2.0
	if states[2] is Object:
		states[2].phase = "quake"
		states[2].quake_timer = 1.0
	for state: Object in states:
		state.update(0.25, {}, true, Vector2.ZERO, _vision_runtime_config(), {"audio": audio})
		_expect_close(float(state.cooldown_remaining), 1.75, "Vision cooldown must tick while Shift owns input")
	_expect(audio.quake_play_calls > 0, "Cheongringwi quake loop sync must continue while Shift owns input")


func _verify_reset_lifecycle_owns_release_latch() -> void:
	var reader := FakeInputReader.new()
	reader.snapshot = {"up_pressed": true}
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID])
	var actor_driver := BattleSceneActorUpdateDriver.new()
	var registry := FakeRegistry.new({
		"battle_scene_actor_update_driver": actor_driver,
		"smasher_input_reader": reader,
		"smasher_skill_config": skill_config,
	})
	Input.action_press("vision_modifier")
	var held_frame := actor_driver.prepare_vision_input_frame(FakeOwner.new(), registry, reader, skill_config)
	var proxy: Object = held_frame.get("input_reader", null)
	_expect(proxy != null and proxy.has_pending_release_suppression(), "Dalji up hold must arm the release latch before reset")
	BattleSceneBallUpdateDriver.new().reset_ball(null, registry)
	_expect(proxy != null and proxy.has_pending_release_suppression(), "score/serve ball reset must retain the Vision release latch")
	registry.instances["battle_update_context"] = FakeMatchContextBuilder.new()
	registry.instances["match_flow_controller"] = MatchFlowController.new()
	BattleSceneMatchFlowDriver.new().handle_round_restart(
		registry,
		"rematch",
		Callable()
	)
	_expect(proxy != null and not proxy.has_pending_release_suppression(), "true round restart must clear the Vision release latch")
	Input.action_release("vision_modifier")


func _vision_runtime_config() -> Dictionary:
	return {
		"ball_active": true,
		"player_skill_input_locked": false,
		"special_gauge": 500.0,
		"width": 760.0,
		"height": 750.0,
		"boss_pos": Vector2(330.0, 30.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}


func _finish() -> void:
	Input.action_release("vision_modifier")
	if _failures.is_empty():
		print("vision_modifier_movement_latch_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.3f, got %.3f" % [message, expected, actual])
