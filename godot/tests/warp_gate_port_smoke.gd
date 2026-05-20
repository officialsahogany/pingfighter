extends SceneTree

const WarpGateState := preload("res://scripts/characters/smasher_warp_gate_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "warp_gate"

	func get_skill_cost(skill_name: String) -> float:
		return 100.0 if skill_name == "warp_gate" else 0.0

	func get_cooldown_seconds(skill_name: String) -> float:
		return 50.0 if skill_name == "warp_gate" else 0.0


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
	func get_runtime_skill_level(skill_id: String) -> int:
		return 2 if skill_id == "extension_gear" else 0


class FakeAudio:
	var loop_active := false
	var played_count := 0
	var stopped_count := 0

	func play_warp_gate_loop() -> void:
		loop_active = true
		played_count += 1

	func stop_warp_gate_loop() -> void:
		loop_active = false
		stopped_count += 1

	func sync_warp_gate_loop(active: bool) -> void:
		if active and not loop_active:
			play_warp_gate_loop()
		elif not active and loop_active:
			stop_warp_gate_loop()


class FakeFeedback:
	var gauge_flash_triggered := false
	var shake_strength := 0.0

	func set_screen_shake(_duration: float, strength: float) -> void:
		shake_strength = max(shake_strength, strength)

	func trigger_gauge_flash() -> void:
		gauge_flash_triggered = true


class FakeOwner:
	var player_pos := Vector2.ZERO
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_scale := 1.0


class FakeRegistry:
	var instances: Dictionary = {}

	func _init(initial_instances: Dictionary = {}) -> void:
		instances = initial_instances

	func get_instance(key: String) -> Object:
		var instance: Variant = instances.get(key, null)
		return instance if instance is Object else null


func _init() -> void:
	var real_skill_config: Object = SmasherSkillConfig.new()
	_expect(is_equal_approx(real_skill_config.get_cooldown_seconds("warp_gate"), 50.0), "warp gate base cooldown should be 50 seconds")
	var real_skill_data: Dictionary = real_skill_config.get_skill_data("warp_gate")
	_expect(is_equal_approx(float(real_skill_data.get("cooldown", 0.0)), 50.0), "warp gate tooltip data should expose the 50-second cooldown")

	var catalog: Object = RuntimePerkCatalog.new()
	var unlock_data: Dictionary = catalog.get_perk_data("unlock_warp_gate")
	_expect(str(unlock_data.get("unlocks_skill", "")) == "warp_gate", "unlock_warp_gate should be registered as the warp gate skill unlock")

	var effect_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/skills/smasher_warp_gate_effect_sheet_imagegen_v1.png")
	_expect(effect_texture != null and effect_texture.get_size() == Vector2(2048.0, 1024.0), "warp gate effect sheet should load from Godot assets")
	var warp_audio: AudioStream = ProjectResourceLoader.load_audio_stream("res://assets/sounds/warpgate.wav")
	_expect(warp_audio != null, "warp gate loop sound should load from Godot assets")

	var warp_gate_state: Object = WarpGateState.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var runtime_perk_state := FakeRuntimePerkState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var deps := {
		"skill_config": skill_config,
		"skill_state": skill_state,
		"runtime_perk_state": runtime_perk_state,
		"audio": audio,
		"feedback": feedback,
	}
	var config := {
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"play_left": 0.0,
		"play_right": 760.0,
	}

	var waiting_result: Dictionary = warp_gate_state.update_input(
		{"down_pressed": true},
		1000,
		150.0,
		Vector2(300.0, 700.0),
		config,
		deps
	)
	_expect(not bool(waiting_result.get("activated", false)), "warp gate should require the 0.5-second S/down hold")

	var result: Dictionary = warp_gate_state.update_input(
		{"down_pressed": true},
		1510,
		150.0,
		Vector2(300.0, 700.0),
		config,
		deps
	)
	_expect(bool(result.get("activated", false)), "warp gate should activate after the hold threshold")
	_expect(is_equal_approx(float(result.get("special_gauge", -1.0)), 50.0), "warp gate should spend 100 gauge on activation")
	_expect(warp_gate_state.is_active(), "warp gate should become active immediately")
	_expect(skill_state.triggered_skill == "warp_gate", "warp gate should trigger its shared cooldown")
	_expect(is_equal_approx(skill_state.triggered_cooldown_seconds, 50.0), "warp gate activation should request a 50-second cooldown")
	_expect(audio.loop_active and audio.played_count > 0, "warp gate should start its loop sound")
	_expect(feedback.gauge_flash_triggered and feedback.shake_strength > 0.0, "warp gate should trigger feedback")

	var status: Dictionary = warp_gate_state.get_status_context()
	_expect(int(status.get("total_duration_msec", 0)) == 30000, "extension_gear Lv.2 should extend warp gate to 30 seconds")

	var bounds: Dictionary = warp_gate_state.get_movement_bounds(0.0, 760.0, 155.0)
	_expect(is_equal_approx(float(bounds.get("play_left", 0.0)), -155.0), "active warp gate should allow crossing the left wall")
	_expect(is_equal_approx(float(bounds.get("play_right", 0.0)), 915.0), "active warp gate should allow crossing the right wall")

	var wrap_result: Dictionary = warp_gate_state.wrap_player_position(
		Vector2(-170.0, 700.0),
		Vector2(155.0, 50.0),
		80.0,
		deps
	)
	var wrapped_pos: Vector2 = wrap_result.get("player_pos", Vector2.ZERO)
	_expect(bool(wrap_result.get("wrapped", false)), "crossing fully past the wall should wrap the player")
	_expect(is_equal_approx(wrapped_pos.x, 590.0), "left-wall wrap should move the player to the opposite side")
	_expect(is_equal_approx(float(wrap_result.get("special_gauge", -1.0)), 80.0), "wall wrap should be free in the Godot port")
	_expect(is_equal_approx(warp_gate_state.get_mirror_offset_x(Vector2(-80.0, 700.0), 155.0), 760.0), "offscreen-left paddle should mirror to the right side")
	var draw_context: Dictionary = warp_gate_state.get_actor_draw_context(Vector2(-80.0, 700.0), Vector2(155.0, 50.0))
	_expect(
		is_equal_approx(float(draw_context.get("warp_gate_player_visual_offset_x", 0.0)), 760.0),
		"offscreen-left warp draw should shift the single visible player actor instead of drawing a duplicate"
	)
	draw_context = warp_gate_state.get_actor_draw_context(Vector2(-42.0, 700.0), Vector2(155.0, 50.0))
	_expect(
		is_equal_approx(float(draw_context.get("warp_gate_player_visual_offset_x", 999.0)), 0.0),
		"less-than-half left wall riding should keep the single visible actor on the original side"
	)

	var clamped_left_wrap: Dictionary = warp_gate_state.wrap_player_position(
		Vector2(-155.0, 700.0),
		Vector2(155.0, 50.0),
		42.0,
		deps
	)
	_expect(bool(clamped_left_wrap.get("wrapped", false)), "left clamp boundary should wrap during real movement")
	_expect(is_equal_approx(clamped_left_wrap.get("player_pos", Vector2.ZERO).x, 605.0), "left clamp boundary wrap should land at the right edge")
	_expect(is_equal_approx(float(clamped_left_wrap.get("special_gauge", -1.0)), 42.0), "left clamp boundary wrap should stay free")

	var clamped_right_wrap: Dictionary = warp_gate_state.wrap_player_position(
		Vector2(760.0, 700.0),
		Vector2(155.0, 50.0),
		37.0,
		deps
	)
	_expect(bool(clamped_right_wrap.get("wrapped", false)), "right clamp boundary should wrap during real movement")
	_expect(is_equal_approx(clamped_right_wrap.get("player_pos", Vector2.ZERO).x, 0.0), "right clamp boundary wrap should land at the left edge")
	_expect(is_equal_approx(float(clamped_right_wrap.get("special_gauge", -1.0)), 37.0), "right clamp boundary wrap should stay free")

	var item_effects: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(-42.0, 700.0)
	item_effects.sync_long_boost_owner_state(owner, warp_gate_state)
	_expect(
		is_equal_approx(owner.player_pos.x, -42.0),
		"active item size sync should not clamp an active warp-gate left wall ride back inside"
	)
	owner.player_pos = Vector2(620.0, 700.0)
	item_effects.sync_long_boost_owner_state(owner, warp_gate_state)
	_expect(
		is_equal_approx(owner.player_pos.x, 620.0),
		"active item size sync should not clamp an active warp-gate right wall ride back inside"
	)
	item_effects.long_boost_scale = 1.5
	owner.player_pos = Vector2(-42.0, 700.0)
	owner.player_paddle_width = 155.0
	item_effects.sync_long_boost_owner_state(owner, warp_gate_state)
	_expect(
		owner.player_pos.x < 0.0,
		"active item size changes should preserve active warp-gate left wall riding bounds"
	)
	owner.player_pos = Vector2(620.0, 700.0)
	owner.player_paddle_width = 155.0
	item_effects.sync_long_boost_owner_state(owner, warp_gate_state)
	_expect(
		owner.player_pos.x > 760.0 - owner.player_paddle_width,
		"active item size changes should preserve active warp-gate right wall riding bounds"
	)

	var registry := FakeRegistry.new({"smasher_warp_gate_state": warp_gate_state})
	var real_runtime_perks: Object = RuntimePerkState.new()
	owner = FakeOwner.new()
	owner.player_pos = Vector2(-42.0, 700.0)
	_expect(
		bool(real_runtime_perks.debug_set_perk_level("dash_lightweight", 1, owner, registry, catalog)),
		"runtime perk debug set should apply for warp-gate clamp regression coverage"
	)
	_expect(
		is_equal_approx(owner.player_pos.x, -42.0),
		"non-size runtime perk sync should not clamp an active warp-gate wall ride back inside"
	)

	real_runtime_perks = RuntimePerkState.new()
	owner = FakeOwner.new()
	owner.player_pos = Vector2(-42.0, 700.0)
	_expect(
		bool(real_runtime_perks.debug_set_perk_level("common_bulk_up", 1, owner, registry, catalog)),
		"runtime bulk-up perk should apply for warp-gate clamp regression coverage"
	)
	_expect(
		owner.player_pos.x < 0.0,
		"runtime perk size changes should preserve active warp-gate left wall riding bounds"
	)
	real_runtime_perks = RuntimePerkState.new()
	owner = FakeOwner.new()
	owner.player_pos = Vector2(620.0, 700.0)
	_expect(
		bool(real_runtime_perks.debug_set_perk_level("common_bulk_up", 1, owner, registry, catalog)),
		"runtime bulk-up perk should apply on the right wall"
	)
	_expect(
		owner.player_pos.x > 760.0 - owner.player_paddle_width,
		"runtime perk size changes should preserve active warp-gate right wall riding bounds"
	)

	var mythic_runtime: Object = MythicItemRuntime.new()
	owner = FakeOwner.new()
	owner.player_pos = Vector2(-42.0, 700.0)
	mythic_runtime.update(owner, registry, 1.0 / 60.0)
	_expect(
		is_equal_approx(owner.player_pos.x, -42.0),
		"per-frame mythic sync should not clamp an unchanged active warp-gate wall ride back inside"
	)
	owner = FakeOwner.new()
	owner.player_pos = Vector2(-42.0, 700.0)
	owner.runtime_paddle_scale = 1.2
	mythic_runtime.update(owner, registry, 1.0 / 60.0)
	_expect(
		owner.player_pos.x < 0.0,
		"mythic paddle-size sync should preserve active warp-gate left wall riding bounds"
	)
	owner = FakeOwner.new()
	owner.player_pos = Vector2(620.0, 700.0)
	owner.runtime_paddle_scale = 1.2
	mythic_runtime.update(owner, registry, 1.0 / 60.0)
	_expect(
		owner.player_pos.x > 760.0 - owner.player_paddle_width,
		"mythic paddle-size sync should preserve active warp-gate right wall riding bounds"
	)

	var collision_detector: Object = BallMotionCollisionDetector.new()
	var collision: Dictionary = collision_detector.check_paddles(Vector2(700.0, 725.0), Vector2(0.0, 12.0), 28.6, {
		"player_pos": Vector2(-80.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_paddle_mirror_offset_x": 760.0,
		"player_collision_cooldown": 0.0,
		"hitbox_padding": 5.0,
	})
	_expect(str(collision.get("event", "")) == "player_paddle", "mirrored warp paddle should block the ball on the opposite side")
	_expect(is_equal_approx(float(collision.get("paddle_x", 0.0)), 680.0), "mirrored paddle collision should use the mirrored paddle x")

	var event_processor: Object = BallMotionEventProcessor.new()
	var step_context: Dictionary = event_processor._build_step_context({
		"ball_size": 28.6,
		"width": 760.0,
		"height": 750.0,
		"player_pos": Vector2(-80.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2.ZERO,
		"boss_paddle_size": Vector2(100.0, 40.0),
		"hitbox_padding": 5.0,
		"warp_gate_active": true,
		"player_paddle_mirror_offset_x": 760.0,
	}, {
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}, {})
	_expect(
		is_equal_approx(float(step_context.get("player_paddle_mirror_offset_x", 0.0)), 760.0),
		"ball step context should preserve warp gate mirrored collision offset"
	)
	var step_collision: Dictionary = collision_detector.check_paddles(
		Vector2(700.0, 725.0),
		Vector2(0.0, 12.0),
		28.6,
		step_context
	)
	_expect(str(step_collision.get("event", "")) == "player_paddle", "ball event step should let the mirrored warp paddle block the ball")

	warp_gate_state.pause_between_rounds(5000)
	status = warp_gate_state.get_status_context()
	_expect(not warp_gate_state.is_active(), "round pause should temporarily close the gate")
	_expect(int(status.get("paused_remaining_msec", 0)) == 26510, "round pause should keep the remaining duration")
	_expect(audio.loop_active, "pause itself does not own audio; cleanup path stops the loop")

	audio.stop_warp_gate_loop()
	warp_gate_state.update_effects(1.0, {
		"current_msec": 6000,
		"ball_active": true,
		"ball_vel": Vector2(0.0, -12.0),
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}, deps)
	_expect(warp_gate_state.is_active(), "active ball should resume a paused warp gate")
	_expect(audio.loop_active, "resumed warp gate should restart the loop sound")
	_expect(
		is_equal_approx(warp_gate_state.get_remaining_ratio(6000), 26510.0 / 30000.0),
		"resumed warp gate timer should keep its pre-pause duration ratio"
	)

	warp_gate_state.update_effects(1.0, {
		"current_msec": 33000,
		"ball_active": true,
		"ball_vel": Vector2(0.0, -12.0),
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}, deps)
	_expect(not warp_gate_state.is_active(), "warp gate should expire at the preserved end time")
	_expect(not audio.loop_active and audio.stopped_count > 0, "warp gate should stop its loop sound on expiry")
	print("warp_gate_port_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
