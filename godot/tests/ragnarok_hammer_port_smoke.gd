extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceRallyFeedbackRouter := preload("res://scripts/ball/paddle_bounce_rally_feedback_router.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var megingjord_equipped := false
	var dowsing_pendulum_equipped := false
	var dowsing_pendulum_range := 0.0
	var dowsing_pendulum_context: Dictionary = {}
	var slot_add_equipped := false
	var slot_add_active_item_slot_bonus := 0
	var active_item_slot_capacity_bonus := 0
	var active_item_slot_capacity := 3

	func queue_redraw() -> void:
		pass


class FakeAudio:
	var shot_count := 0
	var boom_count := 0
	var shock_play_count := 0
	var shock_stop_count := 0
	var shock_loop_active := false
	var electric_play_count := 0
	var electric_stop_count := 0
	var electric_loop_active := false

	func play_ragnarok_shot() -> void:
		shot_count += 1

	func play_ragnarok_boom() -> void:
		boom_count += 1

	func play_ragnarok_shock_loop() -> void:
		shock_loop_active = true
		shock_play_count += 1

	func stop_ragnarok_shock_loop() -> void:
		shock_loop_active = false
		shock_stop_count += 1

	func play_electric_shock_loop() -> void:
		electric_loop_active = true
		electric_play_count += 1

	func stop_electric_shock_loop() -> void:
		electric_loop_active = false
		electric_stop_count += 1


class FakeFeedback:
	var shake_amount := 0.0
	var shake_intensity := 0.0

	func max_screen_shake(amount: float, intensity: float) -> void:
		shake_amount = max(shake_amount, amount)
		shake_intensity = max(shake_intensity, intensity)

	func set_screen_shake(amount: float, intensity: float) -> void:
		shake_amount = amount
		shake_intensity = intensity


class FakeRegistry:
	var audio: Object
	var feedback: Object

	func _init(audio_ref: Object, feedback_ref: Object) -> void:
		audio = audio_ref
		feedback = feedback_ref

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "battle_feedback_state":
			return feedback
		return null


class FakeBossGuardMotionStepper:
	func step(ball_pos: Vector2, _motion_delta: Vector2, _ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		return {
			"ball_pos": ball_pos,
			"event": "boss_paddle",
			"paddle_x": 330.0,
			"paddle_w": 100.0,
			"is_player": false,
		}


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var hammer_data: Dictionary = catalog.build_item_by_name("ragnarok_hammer")
	_expect(not hammer_data.is_empty(), "ragnarok_hammer should be registered in the mythic catalog")
	_expect(str(hammer_data.get("slot", "")) == "arm", "Ragnarok Hammer should route through the shared arm equipment slots")
	_expect(str(hammer_data.get("icon_sheet_path", "")) != "", "Ragnarok Hammer should expose an animated icon sheet")
	_expect(int(hammer_data.get("icon_frame_count", 0)) == 32, "Ragnarok Hammer should expose 32 smooth icon frames")
	_expect(bool(hammer_data.get("icon_fill_slot", false)), "Ragnarok Hammer should fill the equipment slot box")
	var stun_option: Dictionary = _find_roll_option(hammer_data, "stun_duration")
	_expect(is_equal_approx(float(stun_option.get("min", 0.0)), 0.8), "Ragnarok Hammer stun-duration roll should start at 0.8 seconds")
	_expect(is_equal_approx(float(stun_option.get("max", 0.0)), 1.2), "Ragnarok Hammer stun-duration roll should cap at 1.2 seconds")
	_expect(is_equal_approx(float(stun_option.get("default", 0.0)), 1.0), "Ragnarok Hammer stun-duration default should be 1.0 seconds")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "ragnarok_hammer"), "Ragnarok Hammer should be in the field-spawn mythic pool")

	var icon_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/items/ragnarok_hammer.png")
	_expect(icon_texture != null, "Ragnarok Hammer icon should load from Godot assets")
	var icon_sheet: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/items/ragnarok_hammer_icon_sheet.png")
	_expect(icon_sheet != null and icon_sheet.get_size() == Vector2(1024.0, 32.0), "Ragnarok Hammer animated icon sheet should load as 32 smooth 32px frames")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/ragnarokshot.wav") != null, "Ragnarok shot sound should load")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/ragnarokboom.wav") != null, "Ragnarok boom sound should load")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/ragnarokshock.wav") != null, "Ragnarok shock loop should load")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/electricshock.wav") != null, "Lightning Fury electric-stun loop should load")

	var fresh_runtime: Object = MythicItemRuntime.new()
	_expect(not fresh_runtime.has_actor_draw_context(), "fresh mythic runtime should skip empty actor draw context")
	_expect(not fresh_runtime.has_ball_draw_context(), "fresh mythic runtime should skip empty ball draw context")
	_expect(fresh_runtime.get_actor_draw_context().is_empty(), "fresh mythic runtime should return empty actor draw context")
	_expect(fresh_runtime.get_ball_draw_context().is_empty(), "fresh mythic runtime should return empty ball draw context")

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(audio, feedback)
	_expect(runtime.equip_item(
		"ragnarok_hammer",
		owner,
		registry,
		{
			"trigger_chance": 100.0,
			"stun_duration": 1.0,
			"speed_boost": 25.0,
			"gauge_cost": 30.0,
		},
		false
	), "Ragnarok Hammer should equip through mythic_item_runtime")
	_expect(owner.equipment_slots.has("left_arm"), "first equipped arm item should occupy the left arm slot")
	_expect(str(owner.equipment_slots["left_arm"].get("_equipped_slot", "")) == "left_arm", "synced Ragnarok Hammer should expose the resolved left arm slot")

	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("ragnarok_hammer_equipped", false)), "snapshot should expose equipped Ragnarok Hammer")
	_expect(is_equal_approx(float(snapshot.get("ragnarok_hammer_gauge_cost", 0.0)), 30.0), "gauge-cost roll should be preserved")

	var deps := {
		"registry": registry,
		"feedback": feedback,
	}
	var player_result: Dictionary = runtime.try_apply_ragnarok_player_hit(
		Vector2(0.0, -10.0),
		100.0,
		{},
		deps
	)
	_expect(bool(player_result.get("activated", false)), "100% trigger roll should create a stun ball")
	_expect(is_equal_approx(float(player_result.get("special_gauge", 0.0)), 70.0), "Ragnarok Hammer should spend its gauge-cost roll")
	_expect(is_equal_approx(_get_vec(player_result, "ball_vel").length(), 12.5), "Ragnarok Hammer should apply the ball speed boost roll")
	_expect(not player_result.has("speed_limit_disabled"), "Ragnarok stun-ball launch should no longer fully disable the ball speed cap")
	var active_collision_context: Dictionary = runtime.get_ball_collision_context()
	_expect(not bool(active_collision_context.get("speed_limit_disabled", false)), "active Ragnarok stun ball should not expose fully uncapped ball physics")
	_expect(is_equal_approx(float(active_collision_context.get("ragnarok_hammer_speed_cap_bonus", 0.0)), 6.0), "active Ragnarok stun ball should expose the +6 league speed-cap bonus")
	_expect(is_equal_approx(runtime.get_ragnarok_speed_cap_bonus(), 6.0), "active Ragnarok stun ball should report a +6 speed-cap bonus")
	var uncapped_scene := {
		"ball_vel": Vector2(90.0, 0.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
	}
	BallFrameMotionController.new().apply_ball_speed_limits(uncapped_scene, {"ball_physics": BallPhysics.new(), "mythic_item_runtime": runtime})
	_expect(is_equal_approx(_get_vec(uncapped_scene, "ball_vel").length(), 32.0), "active Ragnarok stun ball should cap at the league limit +6 (26 -> 32) before the boss guards")
	_expect(audio.shot_count == 1, "stun-ball activation should play the shot cue")
	_expect(bool(runtime.get_ball_draw_context().get("ragnarok_hammer_ball_active", false)), "ball draw context should mark the charged ball")

	var boss_result: Dictionary = runtime.apply_ragnarok_boss_hit(
		Vector2(0.0, 12.0),
		{
			"boss_pos": Vector2(330.0, 25.0),
			"boss_paddle_size": Vector2(100.0, 40.0),
			"player_pos": Vector2(302.5, 680.0),
			"player_paddle_size": Vector2(155.0, 50.0),
			"width": 760.0,
			"boss_vel": 3.0,
		},
		deps
	)
	_expect(bool(boss_result.get("applied", false)), "boss counter should consume the charged Ragnarok ball")
	_expect(not boss_result.has("speed_limit_disabled"), "Ragnarok boss guard no longer toggles the global speed-limit flag")
	var guarded_ball_vel: Vector2 = _get_vec(boss_result, "ball_vel")
	_expect(guarded_ball_vel.length() <= 20.01, "Ragnarok boss guard should slow the counter ball below the normal speed cap")
	_expect(guarded_ball_vel.y > 0.0, "Ragnarok boss guard should reflect the counter ball back toward the player side")
	_expect(abs(guarded_ball_vel.x) <= guarded_ball_vel.length() * 0.43, "Ragnarok boss guard should limit sharp horizontal counter angles")
	_expect(is_equal_approx(runtime.get_ragnarok_speed_cap_bonus(), 0.0), "consumed Ragnarok stun ball should stop raising the speed cap")
	_expect(is_equal_approx(float(runtime.get_ball_collision_context().get("ragnarok_hammer_speed_cap_bonus", 0.0)), 0.0), "consumed Ragnarok stun ball should stop exposing the +6 cap bonus")
	var capped_scene := {
		"ball_vel": Vector2(90.0, 0.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
	}
	BallFrameMotionController.new().apply_ball_speed_limits(capped_scene, {"ball_physics": BallPhysics.new(), "mythic_item_runtime": runtime})
	_expect(_get_vec(capped_scene, "ball_vel").length() <= 26.01, "normal frame speed cap should return after Ragnarok boss guard")
	_expect(audio.boom_count == 1, "Ragnarok boss impact should play the boom cue")
	_expect(audio.electric_play_count == 1 and audio.electric_loop_active, "Ragnarok electric stun should start the Lightning Fury shock loop")
	_expect(feedback.shake_amount >= 1.38 and feedback.shake_intensity >= 22.0, "Ragnarok stun-ball boss impact should trigger the extended strong screen shake")
	var rally_feedback_router := PaddleBounceRallyFeedbackRouter.new()
	rally_feedback_router.register(Vector2(380.0, 65.0), Vector2(0.0, 10.0), false, false, deps)
	_expect(feedback.shake_amount >= 1.38 and feedback.shake_intensity >= 22.0, "basic paddle feedback should not overwrite Ragnarok impact shake")
	_expect(bool(runtime.get_boss_ai_context().get("ragnarok_hammer_boss_stun_active", false)), "boss AI context should receive Ragnarok stun")
	_expect(abs(float(runtime.get_boss_ai_context().get("ragnarok_hammer_boss_knockback_vel", 0.0))) >= 40.0, "Ragnarok boss knockback should use the increased impact distance")
	_expect(abs(float(runtime.get_boss_ai_context().get("ragnarok_hammer_electric_stun_drift_vel", 0.0))) > 0.0, "electric stun should preserve a tiny previous-direction drift")
	_expect(bool(runtime.get_actor_draw_context().get("ragnarok_hammer_electric_stun_active", false)), "actor draw context should expose the electric stun lane")
	_expect(bool(runtime.get_actor_draw_context().get("active_item_boss_stun_active", false)), "Ragnarok electric stun should still use the boss stun sheet motion")
	_expect(bool(runtime.get_actor_draw_context().get("active_item_boss_stun_stars_suppressed", false)), "Ragnarok electric stun should suppress only the normal stun-star overlay")

	var ai := BossAiState.new()
	var drift_result: Dictionary = ai.update(
		1.0 / 60.0,
		Vector2(330.0, 25.0),
		0.0,
		{
			"width": 760.0,
			"play_left": 0.0,
			"play_right": 760.0,
			"boss_paddle_width": 100.0,
			"ragnarok_hammer_boss_stun_active": true,
			"ragnarok_hammer_boss_knockback_active": false,
			"ragnarok_hammer_boss_knockback_vel": 0.0,
			"ragnarok_hammer_electric_stun_drift_vel": runtime.get_boss_ai_context().get("ragnarok_hammer_electric_stun_drift_vel", 0.0),
		}
	)
	_expect(abs(float(drift_result.get("boss_vel", 0.0))) > 0.0, "boss AI should keep slight movement during electric stun")

	runtime.update(owner, registry, 1.0)
	_expect(audio.electric_stop_count >= 1 and not audio.electric_loop_active, "Ragnarok electric shock loop should stop when stun expires")
	_expect(not bool(runtime.get_boss_ai_context().get("ragnarok_hammer_boss_stun_active", false)), "Ragnarok stun should expire through runtime update")

	_verify_speed_limit_lifecycle_through_ball_update()

	print("ragnarok_hammer_port_smoke: ok")
	quit(0)


func _verify_speed_limit_lifecycle_through_ball_update() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(audio, feedback)
	_expect(runtime.equip_item(
		"ragnarok_hammer",
		owner,
		registry,
		{
			"trigger_chance": 100.0,
			"stun_duration": 1.0,
			"speed_boost": 25.0,
			"gauge_cost": 0.0,
		},
		false
	), "Ragnarok Hammer speed-limit lifecycle test should equip the item")
	var activation_result: Dictionary = runtime.try_apply_ragnarok_player_hit(
		Vector2(80.0, 0.0),
		100.0,
		{},
		{"registry": registry, "feedback": feedback}
	)
	_expect(bool(activation_result.get("activated", false)), "Ragnarok speed-limit lifecycle test should arm a stun ball")
	_expect(is_equal_approx(runtime.get_ragnarok_speed_cap_bonus(), 6.0), "armed Ragnarok ball should raise the league speed cap by +6 before guard")
	var update_context := {
		"selected_character_type": "smasher",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"ball_size": 28.6,
		"ball_pos": Vector2(380.0, 58.0),
		"ball_vel": Vector2(90.0, 0.0),
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
	var ball_result: Dictionary = BallUpdateController.new().update(
		1.0 / 60.0,
		update_context,
		{
			"mythic_item_runtime": runtime,
			"ball_physics": BallPhysics.new(),
			"paddle_bounce_controller": PaddleBounceController.new(),
			"paddle_bounce_state": PaddleBounceState.new(),
			"motion_stepper": FakeBossGuardMotionStepper.new(),
			"registry": registry,
			"feedback": feedback,
		}
	)
	var snapshot: Dictionary = ball_result.get("snapshot", {})
	_expect(is_equal_approx(runtime.get_ragnarok_speed_cap_bonus(), 0.0), "boss guard should clear Ragnarok's raised speed cap")
	_expect(not bool(snapshot.get("speed_limit_disabled", false)), "boss guard frame should not leave the global speed-limit flag set")
	var guarded_snapshot_vel: Vector2 = _get_vec(snapshot, "ball_vel")
	_expect(guarded_snapshot_vel.length() <= 20.01, "boss-guarded Ragnarok ball should be slowed below the normal cap immediately")
	_expect(guarded_snapshot_vel.y > 0.0, "boss-guarded Ragnarok ball should travel back toward the player immediately")


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _find_roll_option(item_data: Dictionary, key: String) -> Dictionary:
	for option_value in item_data.get("roll_options", []):
		if option_value is Dictionary and str(option_value.get("key", "")) == key:
			return option_value
	return {}


func _get_vec(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
