extends SceneTree

const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherPlayerDashController := preload("res://scripts/characters/smasher_player_dash_controller.gd")

const BASE_PADDLE_HEIGHT := 50.0


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


func _init() -> void:
	_verify_catalog_and_assets()
	_verify_runtime_scaling_and_collision()
	_verify_controller_audio_routing()

	print("dash_acceleration_perk_port_smoke: ok")
	quit(0)


func _verify_catalog_and_assets() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var data: Dictionary = catalog.get_perk_data("dash_acceleration")
	_expect(str(data.get("name", "")) == "버스트업", "Burst Up should be registered with the Korean name")
	_expect(int(data.get("max_level", 0)) == 5, "Burst Up should scale to Lv.5")
	_expect(str(data.get("tree", "")) == "smasher", "Burst Up should live in the Smasher perk tree")
	_expect(str(data.get("character_restriction", "")) == "smasher", "Burst Up should be Smasher-restricted")
	_expect(ProjectResourceLoader.load_texture("res://assets/sprites/perks/dash_acceleration_perk_icon.png") != null, "Burst Up perk icon should load")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/bustup.wav") != null, "Burst Up dash sound should load")


func _verify_runtime_scaling_and_collision() -> void:
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["dash_acceleration"] = 5
	perk_state.item_perk_level_bonus = 1
	_expect_close(perk_state.get_runtime_skill_bonus("dash_acceleration"), 4.2, "effective Lv.6 Burst Up should grant 420% height bonus")
	_expect_close(perk_state.get_dash_acceleration_height_bonus(BASE_PADDLE_HEIGHT), 210.0, "effective Lv.6 Burst Up should add 210px collision height")

	var dash_state: Object = SmasherDashState.new()
	dash_state.reset_full(1)
	_expect(dash_state.start(1.0, false, perk_state), "dash should start with Burst Up invested")
	var snapshot: Dictionary = dash_state.get_snapshot()
	_expect(bool(snapshot.get("dash_acceleration_active", false)), "Burst Up should be active while the dash is active")
	_expect_close(float(snapshot.get("dash_acceleration_height_bonus", 0.0)), 210.0, "dash snapshot should expose Burst Up collision height")

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
	_expect(no_burst_hit.is_empty(), "ball above the normal paddle should miss without Burst Up")

	var burst_context := base_context.duplicate(true)
	burst_context.merge(dash_state.get_ball_collision_context(), true)
	var burst_hit: Dictionary = detector.check_paddles(ball_pos, Vector2(0.0, 5.0), 28.6, burst_context)
	_expect(str(burst_hit.get("event", "")) == "player_paddle", "Burst Up should extend the player paddle collision vertically")

	dash_state.update(15.0 / 60.0, Vector2(302.5, 700.0), 0.0, 760.0, 155.0, perk_state)
	snapshot = dash_state.get_snapshot()
	_expect(not bool(snapshot.get("dash_acceleration_active", true)), "Burst Up should clear when the dash ends")
	_expect_close(float(snapshot.get("dash_acceleration_height_bonus", 999.0)), 0.0, "ended dash should expose zero Burst Up height")


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
		"paddle_width": 155.0,
		"paddle_height": BASE_PADDLE_HEIGHT,
	}
	dash_state.reset_full(1)
	var result: Dictionary = controller.handle_dash_input(true, 1.0, Vector2(302.5, 700.0), 0.0, config, deps)
	_expect(bool(result.get("handled_by_dash", false)), "controller should start a normal dash")
	_expect(audio.burst_up_count == 1 and audio.dash_start_count == 0, "normal Burst Up dash should play bustup.wav instead of the default dash sound")

	var half_dash_state: Object = SmasherDashState.new()
	half_dash_state.reset_full(1)
	half_dash_state.token_state.dash_tokens = 0
	audio = FakeAudio.new()
	deps["dash_state"] = half_dash_state
	deps["audio"] = audio
	result = controller.handle_dash_input(true, -1.0, Vector2(302.5, 700.0), 0.0, config, deps)
	_expect(bool(result.get("handled_by_dash", false)), "controller should start a half dash when no token is available")
	_expect(audio.burst_up_count == 0 and audio.dash_start_count == 1 and audio.last_dash_start_half, "half dash should keep the half-dash sound path")


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) <= 0.02:
		return
	push_error("%s (actual %.3f, expected %.3f)" % [message, actual, expected])
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
