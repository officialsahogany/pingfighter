extends SceneTree

const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherPlayerDashController := preload("res://scripts/characters/smasher_player_dash_controller.gd")

const BASE_PADDLE_HEIGHT := 50.0
var _failed := false


class FakeAudio:
	extends RefCounted

	var burst_up_count := 0
	var dash_start_count := 0
	var last_dash_start_half := false
	var stop_delay_count := 0

	func stop_dash_delay() -> void:
		stop_delay_count += 1

	func play_burst_up_dash() -> void:
		burst_up_count += 1

	func play_dash_start(is_half: bool) -> void:
		dash_start_count += 1
		last_dash_start_half = is_half


class FakeFeedback:
	extends RefCounted

	var shake_count := 0

	func set_screen_shake(_duration: float, _strength: float) -> void:
		shake_count += 1


class FakePaddleBounce:
	extends RefCounted

	var received_ball_pos := Vector2.ZERO

	func bounce(
		_paddle_x: float,
		_paddle_w: float,
		_is_player: bool,
		context: Dictionary,
		_deps: Dictionary,
		_callbacks: Dictionary = {}
	) -> Dictionary:
		received_ball_pos = context.get("ball_pos", Vector2.ZERO)
		var ball_vel: Vector2 = context.get("ball_vel", Vector2.ZERO)
		ball_vel.y = -abs(ball_vel.y)
		return {
			"ball_pos": received_ball_pos,
			"ball_vel": ball_vel,
		}


class FakeStage5HongryunState:
	extends RefCounted

	func is_inferno_active() -> bool:
		return true

	func resolve_inferno_player_guard(
		_ball_pos: Vector2,
		_deps: Dictionary = {},
		_paddle_x: float = INF,
		_paddle_w: float = 0.0
	) -> Dictionary:
		return {}


func _init() -> void:
	_verify_catalog_and_assets()
	_verify_catalog_offers_for_all_characters()
	_verify_runtime_scaling_and_collision()
	_verify_production_step_context_collision()
	_verify_dash_contact_separates_before_same_tick_reflection()
	_verify_stage5_inferno_guard_collision()
	_verify_controller_audio_routing()

	if _failed:
		quit(1)
		return
	print("dash_acceleration_perk_port_smoke: ok")
	quit(0)


func _verify_catalog_and_assets() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var data: Dictionary = catalog.get_perk_data("dash_acceleration")
	_expect(str(data.get("id", "")) == "dash_acceleration", "Great Roc Spreads Wings should be registered by id")
	_expect(str(data.get("name", "")) == "대붕전익", "Great Roc Spreads Wings should expose its adopted Korean Mugong name")
	_expect(int(data.get("max_level", 0)) == 5, "Great Roc Spreads Wings should scale to Lv.5")
	_expect(str(data.get("tree", "")) == "dash", "Great Roc Spreads Wings should live in the shared dash perk tree")
	_expect(str(data.get("character_restriction", "")) == "", "Great Roc Spreads Wings should not be character-restricted")
	_expect(ProjectResourceLoader.load_texture("res://assets/sprites/perks/dash_acceleration_perk_icon.png") != null, "Great Roc Spreads Wings perk icon should load")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/bustup.wav") != null, "Great Roc Spreads Wings dash sound should load")


func _verify_catalog_offers_for_all_characters() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	for character_type in ["smasher", "viper", "soldier", "commando", "blacksmith", "optimus"]:
		var choices: Array = catalog.get_choices(character_type, {}, true, 200)
		_expect(
			_has_choice_id(choices, "dash_acceleration"),
			"Great Roc Spreads Wings should be offered to %s as a shared dash perk" % character_type
		)


func _verify_runtime_scaling_and_collision() -> void:
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["dash_acceleration"] = 5
	perk_state.item_perk_level_bonus = 1
	_expect_close(perk_state.get_runtime_skill_bonus("dash_acceleration"), 4.2, "effective Lv.6 Great Roc Spreads Wings should grant 420% height bonus")
	_expect_close(perk_state.get_dash_acceleration_height_bonus(BASE_PADDLE_HEIGHT), 210.0, "effective Lv.6 Great Roc Spreads Wings should add 210px collision height")

	var dash_state: Object = SmasherDashState.new()
	dash_state.reset_full(1)
	_expect(dash_state.start(1.0, false, perk_state), "dash should start with Great Roc Spreads Wings invested")
	var snapshot: Dictionary = dash_state.get_snapshot()
	_expect(bool(snapshot.get("dash_acceleration_active", false)), "Great Roc Spreads Wings should be active while the dash is active")
	_expect_close(float(snapshot.get("dash_acceleration_height_bonus", 0.0)), 210.0, "dash snapshot should expose Great Roc Spreads Wings collision height")
	_expect_close(float(snapshot.get("dash_acceleration_width_bonus", 0.0)), 93.0, "dash snapshot should expose Great Roc Spreads Wings collision width")

	var detector: Object = BallMotionCollisionDetector.new()
	var base_context: Dictionary = {
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, BASE_PADDLE_HEIGHT),
		"player_collision_cooldown": 0.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"hitbox_padding": 5.0,
	}
	var ball_pos := Vector2(380.0, 650.0)
	var no_burst_hit: Dictionary = detector.check_paddles(ball_pos, Vector2(0.0, 5.0), 28.6, base_context)
	_expect(no_burst_hit.is_empty(), "ball above the normal paddle should miss without Great Roc Spreads Wings")

	var burst_context := base_context.duplicate(true)
	burst_context.merge(dash_state.get_ball_collision_context(), true)
	var burst_hit: Dictionary = detector.check_paddles(ball_pos, Vector2(0.0, 5.0), 28.6, burst_context)
	_expect(str(burst_hit.get("event", "")) == "player_paddle", "Great Roc Spreads Wings should extend the player paddle collision vertically")
	var side_ball_pos := Vector2(270.0, 725.0)
	var no_burst_side_hit: Dictionary = detector.check_paddles(side_ball_pos, Vector2(0.0, 5.0), 28.6, base_context)
	_expect(no_burst_side_hit.is_empty(), "ball beside the normal paddle should miss without Great Roc Spreads Wings")
	var burst_side_hit: Dictionary = detector.check_paddles(side_ball_pos, Vector2(0.0, 5.0), 28.6, burst_context)
	_expect(str(burst_side_hit.get("event", "")) == "player_paddle", "Great Roc Spreads Wings should extend the player paddle collision horizontally")

	dash_state.update(15.0 / 60.0, Vector2(302.5, 700.0), 0.0, 760.0, 155.0, perk_state)
	snapshot = dash_state.get_snapshot()
	_expect(not bool(snapshot.get("dash_acceleration_active", true)), "Great Roc Spreads Wings should clear when the dash ends")
	_expect_close(float(snapshot.get("dash_acceleration_height_bonus", 999.0)), 0.0, "ended dash should expose zero Great Roc Spreads Wings height")
	_expect_close(float(snapshot.get("dash_acceleration_width_bonus", 999.0)), 0.0, "ended dash should expose zero Great Roc Spreads Wings width")


func _verify_production_step_context_collision() -> void:
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["dash_acceleration"] = 5
	var dash_state: Object = SmasherDashState.new()
	dash_state.reset_full(1)
	_expect(dash_state.start(1.0, false, perk_state), "production collision probe dash should start")

	var frame_context: Dictionary = {
		"ball_size": 28.6,
		"width": 760.0,
		"height": 750.0,
		"max_step_distance": 12.0,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, BASE_PADDLE_HEIGHT),
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"hitbox_padding": 5.0,
	}
	var scene: Dictionary = {
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	var processor: Object = BallMotionEventProcessor.new()
	var stepper: Object = BallMotionStepper.new()
	var ball_pos := Vector2(380.0, 650.0)
	var ball_vel := Vector2(0.0, 5.0)

	var base_step_context: Dictionary = processor.call("_build_step_context", frame_context, scene, {})
	var base_result: Dictionary = stepper.step(ball_pos, Vector2.ZERO, ball_vel, base_step_context)
	_expect(str(base_result.get("event", "")) == "none", "production step should miss above the normal paddle")

	frame_context.merge(dash_state.get_ball_collision_context(), true)
	var expanded_step_context: Dictionary = processor.call("_build_step_context", frame_context, scene, {})
	_expect(bool(expanded_step_context.get("dash_acceleration_active", false)), "production step context should preserve the active Great Roc flag")
	_expect_close(float(expanded_step_context.get("dash_acceleration_height_bonus", 0.0)), 175.0, "production step context should preserve the Lv.5 collision height bonus")
	_expect_close(float(expanded_step_context.get("dash_acceleration_width_bonus", 0.0)), 77.5, "production step context should preserve the Lv.5 collision width bonus")
	var expanded_result: Dictionary = stepper.step(ball_pos, Vector2.ZERO, ball_vel, expanded_step_context)
	_expect(str(expanded_result.get("event", "")) == "player_paddle", "production motion step should hit the vertically expanded Lv.5 dash wing")
	var side_ball_pos := Vector2(270.0, 725.0)
	var base_side_result: Dictionary = stepper.step(side_ball_pos, Vector2.ZERO, ball_vel, base_step_context)
	_expect(str(base_side_result.get("event", "")) == "none", "production step should miss beside the normal paddle")
	var expanded_side_result: Dictionary = stepper.step(side_ball_pos, Vector2.ZERO, ball_vel, expanded_step_context)
	_expect(str(expanded_side_result.get("event", "")) == "player_paddle", "production motion step should hit the horizontally expanded Lv.5 dash wing")
	_expect_close(float(expanded_side_result.get("paddle_x", 0.0)), 263.75, "horizontal dash wing should stay centered on the live paddle")
	_expect_close(float(expanded_side_result.get("paddle_w", 0.0)), 232.5, "horizontal dash wing should report its expanded bounce width")


func _verify_dash_contact_separates_before_same_tick_reflection() -> void:
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["dash_acceleration"] = 5
	var dash_state: Object = SmasherDashState.new()
	dash_state.reset_full(1)
	_expect(dash_state.start(1.0, false, perk_state), "contact-separation probe dash should start")
	var frame_context: Dictionary = {
		"ball_size": 28.6,
		"width": 760.0,
		"height": 750.0,
		"max_step_distance": 12.0,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, BASE_PADDLE_HEIGHT),
		"paddle_width": 155.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"hitbox_padding": 5.0,
	}
	frame_context.merge(dash_state.get_ball_collision_context(), true)
	var processor: Object = BallMotionEventProcessor.new()
	var step_context: Dictionary = processor.call("_build_step_context", frame_context, {"player_collision_cooldown": 0.0}, {})
	var stepper: Object = BallMotionStepper.new()

	var top_result: Dictionary = stepper.step(Vector2(380.0, 588.0), Vector2(0.0, 10.0), Vector2(0.0, 10.0), step_context)
	_expect(str(top_result.get("event", "")) == "player_paddle", "falling ball should contact the top of the expanded dash wing")
	_expect_close(float((top_result.get("ball_pos", Vector2.ZERO) as Vector2).y), 593.19, "top contact should separate the ball to the visible wing boundary")
	_expect(bool(top_result.get("dash_acceleration_contact", false)), "expanded dash contact should identify its separation path")

	var side_result: Dictionary = stepper.step(Vector2(250.0, 715.0), Vector2(0.0, 10.0), Vector2(0.0, 10.0), step_context)
	_expect(str(side_result.get("event", "")) == "player_paddle", "falling ball should contact the horizontal dash wing edge")
	var separated_side_pos: Vector2 = side_result.get("ball_pos", Vector2.ZERO)
	_expect_close(separated_side_pos.x, 244.44, "side contact should separate through the nearest horizontal wing edge")
	_expect_close(separated_side_pos.y, 725.0, "side contact should not teleport to the distant top edge")

	var scene: Dictionary = {
		"ball_pos": Vector2(380.0, 588.0),
		"ball_vel": Vector2(0.0, 10.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	var fake_bounce := FakePaddleBounce.new()
	processor.step_motion(scene, 1.0, frame_context, {
		"motion_stepper": BallMotionStepper.new(),
		"paddle_bounce_controller": fake_bounce,
	}, {})
	_expect_close(fake_bounce.received_ball_pos.y, 593.19, "bounce should receive the already-separated contact position")
	_expect_close(float((scene.get("ball_pos", Vector2.ZERO) as Vector2).y), 593.19, "same-tick bounce should keep the ball outside the wing")
	_expect(float((scene.get("ball_vel", Vector2.ZERO) as Vector2).y) < 0.0, "same-tick bounce should immediately launch the ball upward")


func _verify_controller_audio_routing() -> void:
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["dash_acceleration"] = 1

	var controller: Object = SmasherPlayerDashController.new()
	var dash_state: Object = SmasherDashState.new()
	var audio := FakeAudio.new()
	var deps: Dictionary = {
		"dash_state": dash_state,
		"runtime_perk_state": perk_state,
		"audio": audio,
		"feedback": FakeFeedback.new(),
	}
	var config: Dictionary = {
		"special_gauge": 0.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 203.0,
		"paddle_height": 147.0,
	}
	dash_state.reset_full(1)
	var result: Dictionary = controller.handle_dash_input(true, 1.0, Vector2(302.5, 700.0), 0.0, config, deps)
	_expect(bool(result.get("handled_by_dash", false)), "controller should start a normal dash")
	_expect(audio.burst_up_count == 1 and audio.dash_start_count == 0, "normal Great Roc Spreads Wings dash should play bustup.wav instead of the default dash sound")
	_expect_close(float(dash_state.get_snapshot().get("dash_acceleration_height_bonus", 0.0)), 102.9, "normal dash should scale Great Roc Spreads Wings from the live paddle height")
	_expect_close(float(dash_state.get_snapshot().get("dash_acceleration_width_bonus", 0.0)), 20.3, "normal dash should scale Great Roc Spreads Wings from the live paddle width")

	var half_dash_state: Object = SmasherDashState.new()
	half_dash_state.reset_full(1)
	half_dash_state.token_state.dash_tokens = 0
	audio = FakeAudio.new()
	deps["dash_state"] = half_dash_state
	deps["audio"] = audio
	result = controller.handle_dash_input(true, -1.0, Vector2(302.5, 700.0), 0.0, config, deps)
	_expect(bool(result.get("handled_by_dash", false)), "controller should start a half dash when no token is available")
	_expect(audio.burst_up_count == 0 and audio.dash_start_count == 1 and audio.last_dash_start_half, "half dash should keep the half-dash sound path")

	var sensor_dash_state: Object = SmasherDashState.new()
	sensor_dash_state.reset_full(1)
	audio = FakeAudio.new()
	deps["dash_state"] = sensor_dash_state
	deps["audio"] = audio
	var sensor_result: Dictionary = controller.try_start_sensor_dash(1.0, Vector2(302.5, 700.0), config, deps)
	_expect(bool(sensor_result.get("started", false)), "danger sensor should start a free dash")
	_expect(audio.burst_up_count == 1 and audio.dash_start_count == 0, "danger sensor Great Roc Spreads Wings dash should play bustup.wav")
	_expect_close(float(sensor_dash_state.get_snapshot().get("dash_acceleration_height_bonus", 0.0)), 102.9, "danger sensor dash should scale Great Roc Spreads Wings from the live paddle height")
	_expect_close(float(sensor_dash_state.get_snapshot().get("dash_acceleration_width_bonus", 0.0)), 20.3, "danger sensor dash should scale Great Roc Spreads Wings from the live paddle width")


func _verify_stage5_inferno_guard_collision() -> void:
	var controller: Object = BallUpdateController.new()
	var scene: Dictionary = {
		"ball_pos": Vector2(380.0, 680.0),
	}
	var context: Dictionary = {
		"ball_size": 28.6,
		"hitbox_padding": 5.0,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, BASE_PADDLE_HEIGHT),
	}
	var normal_contact: Dictionary = controller.call("_get_stage5_hongryun_player_paddle_contact", scene, context)
	_expect(normal_contact.is_empty(), "Hongryun inferno ball above the normal guard range should miss")

	var accelerated_context := context.duplicate(true)
	accelerated_context["dash_acceleration_active"] = true
	accelerated_context["dash_acceleration_height_bonus"] = 175.0
	accelerated_context["dash_acceleration_width_bonus"] = 77.5
	var accelerated_contact: Dictionary = controller.call("_get_stage5_hongryun_player_paddle_contact", scene, accelerated_context)
	_expect(not accelerated_contact.is_empty(), "Great Roc Spreads Wings should extend Hongryun inferno guard collision")
	_expect_close(float((accelerated_contact.get("ball_pos", Vector2.ZERO) as Vector2).y), 593.68, "Hongryun dash guard should separate a top contact before reflection")
	var side_scene: Dictionary = {"ball_pos": Vector2(271.0, 725.0)}
	var normal_side_contact: Dictionary = controller.call("_get_stage5_hongryun_player_paddle_contact", side_scene, context)
	_expect(normal_side_contact.is_empty(), "Hongryun inferno ball beside the normal guard range should miss")
	var accelerated_side_contact: Dictionary = controller.call("_get_stage5_hongryun_player_paddle_contact", side_scene, accelerated_context)
	_expect(not accelerated_side_contact.is_empty(), "Great Roc Spreads Wings should extend Hongryun inferno guard collision horizontally")
	_expect_close(float((accelerated_side_contact.get("ball_pos", Vector2.ZERO) as Vector2).x), 270.94, "Hongryun side contact should separate through the nearby wing edge")
	_expect_close(float(accelerated_side_contact.get("paddle_x", 0.0)), 263.75, "Hongryun horizontal dash wing should stay centered on the live paddle")
	_expect_close(float(accelerated_side_contact.get("paddle_w", 0.0)), 232.5, "Hongryun horizontal dash wing should report its expanded bounce width")

	var guard_scene: Dictionary = {
		"ball_pos": Vector2(380.0, 680.0),
		"ball_vel": Vector2(0.0, 10.0),
	}
	var guard_context := accelerated_context.duplicate(true)
	guard_context["current_stage"] = 5
	guard_context["ball_vel"] = Vector2(0.0, 10.0)
	var fake_bounce := FakePaddleBounce.new()
	var guarded: bool = bool(controller.call(
		"_try_release_stage5_hongryun_player_paddle_hit",
		guard_scene,
		guard_context,
		{
			"stage5_hongryun_state": FakeStage5HongryunState.new(),
			"paddle_bounce_controller": fake_bounce,
		},
		{}
	))
	_expect(guarded, "Hongryun inferno bypass should commit the expanded dash guard")
	_expect_close(fake_bounce.received_ball_pos.y, 593.68, "Hongryun bounce should receive the separated wing contact position")
	_expect(float((guard_scene.get("ball_vel", Vector2.ZERO) as Vector2).y) < 0.0, "Hongryun dash guard should reflect upward in the same tick")


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) <= 0.02:
		return
	push_error("%s (actual %.3f, expected %.3f)" % [message, actual, expected])
	_failed = true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true


func _has_choice_id(choices: Array, skill_id: String) -> bool:
	for choice in choices:
		if str(choice.get("id", "")) == skill_id:
			return true
	return false
