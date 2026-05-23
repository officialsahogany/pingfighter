extends SceneTree

const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")
const Stage5HongryunFireMachineEvent := preload("res://scripts/stages/stage5/stage5_hongryun_fire_machine_event.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class FakeAudio:
	var fireball_count := 0
	var charge_count := 0
	var shoot_count := 0
	var hurt_count := 0
	var stop_fireball_count := 0
	var stop_charge_count := 0
	var door_count := 0
	var machine_count := 0

	func play_stage5_hongryun_fireball() -> void:
		fireball_count += 1

	func play_stage5_hongryun_charge() -> void:
		charge_count += 1

	func play_stage5_hongryun_shoot() -> void:
		shoot_count += 1

	func play_stage5_hongryun_hurt() -> void:
		hurt_count += 1

	func stop_stage5_hongryun_fireball() -> void:
		stop_fireball_count += 1

	func stop_stage5_hongryun_charge() -> void:
		stop_charge_count += 1

	func play_stage1_balloon_door() -> void:
		door_count += 1

	func play_stage1_balloon_machine() -> void:
		machine_count += 1


class FakeMovementState:
	var knockback_count := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0

	func start_knockback(
		velocity: float,
		frames: float = 18.0,
		decay_per_frame: float = 0.92,
		_replace_current: bool = false,
		_cleansable: bool = true
	) -> bool:
		knockback_count += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay_per_frame
		return true


class FakeImmuneRuntime:
	var parry_count := 0

	func is_boss_skill_immune() -> bool:
		return true

	func trigger_magic_anti_potion_parry(_label: String, _pos: Vector2, _cooldown_key: String) -> void:
		parry_count += 1


class FakeStageBackground:
	var spiral_count := 0
	var inferno_modes: Array[bool] = []
	var impacts: Array[Vector2] = []

	func trigger_spiral_burst(_inferno: bool = false) -> void:
		spiral_count += 1

	func set_inferno_mode(active: bool) -> void:
		inferno_modes.append(active)

	func add_fire_impact(x: float, y: float) -> void:
		impacts.append(Vector2(x, y))


class FakeStage5SkipState:
	var skipping := false

	func should_skip_ball_motion_step() -> bool:
		return skipping


class FakePerfLogger:
	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	_verify_stage5_bgm_asset_loads()
	_verify_fireball_spawn_and_pause()
	_verify_stage5_perf_labels()
	_verify_fireball_hit_and_parry()
	_verify_round_reset_preserves_dragon_orbs()
	_verify_inferno_phase_machine_and_cleanup()
	_verify_inferno_trail_keeps_original_lateral_pressure()
	_verify_inferno_landing_target_locks_on_start()
	_verify_inferno_guard_hover_releases_ball_hijack()
	_verify_inferno_glance_bounce_paddle_edge()
	_verify_inferno_floor_miss_scores_boss_before_late_guard()
	_verify_fire_machine_event_phase_collision_and_draw_context()
	_verify_fire_machine_renderer_does_not_reset_canvas_transform()
	_verify_inferno_flame_dragon_renderer_removed()
	_verify_inferno_pillar_flourish_renderer_contract()
	_verify_ball_update_hijack_query_clears_stale_skip()

	if _failures.is_empty():
		print("stage5_hongryun_mvp_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage5_bgm_asset_loads() -> void:
	_expect(
		ProjectResourceLoader.load_audio_stream("res://assets/bgm/stage5_hongryun_bgm.ogg") != null,
		"Stage 5 Hongryun BGM should load from the OGG runtime asset"
	)


func _verify_fireball_spawn_and_pause() -> void:
	var state := Stage5HongryunState.new()
	var audio := FakeAudio.new()
	var background := FakeStageBackground.new()
	var context: Dictionary = _base_context()
	var deps := {
		"audio": audio,
		"stage_background": background,
	}

	for _i in range(149):
		state.update(1.0 / 60.0, context, deps)
	_expect(state.fireball_projectiles.is_empty(), "Hongryun should wait the 2.5s opening grace before firing")

	context["active_item_boss_skill_cooldown_paused"] = true
	state.update(1.0 / 60.0, context, deps)
	_expect(state.fireball_projectiles.is_empty(), "boss-skill pause should hold the fireball cooldown at the ready edge")
	context["active_item_boss_skill_cooldown_paused"] = false

	var spawn_result: Dictionary = state.update(1.0 / 60.0, context, deps)
	_expect(int(spawn_result.get("stage5_hongryun_fireball_spawned", 0)) >= 1, "Hongryun should spawn at least one fireball after cooldown")
	_expect(state.fireball_projectiles.size() >= 1, "spawned fireballs should be retained for motion")
	var spawned_projectile: Dictionary = state.fireball_projectiles[0]
	_expect(is_equal_approx(float(spawned_projectile.get("radius", 0.0)), 12.8), "Hongryun fireball projectile radius should be 20% smaller than 16px")
	_expect(float(state.fireball_cooldown_total) >= 3.5 and float(state.fireball_cooldown_total) <= 5.0, "next fireball cooldown should be 3.5~5.0 seconds")
	_expect(bool(spawn_result.get("stage5_hongryun_boss_throwing", false)), "fireball spawn should expose the boss throwing windup")
	_expect(audio.fireball_count == 1, "fireball volley should play the original Stage 5 fireball cue")
	_expect(audio.shoot_count == 0, "fireball volley should not reuse the Hongryun inferno shoot cue")
	_expect(background.spiral_count == 1, "fireball volley should notify the Stage 5 background burst hook")


func _verify_stage5_perf_labels() -> void:
	var state := Stage5HongryunState.new()
	state.fireball_cooldown = 0.0
	var perf_logger := FakePerfLogger.new()
	var context: Dictionary = _base_context()
	state.update(1.0 / 60.0, context, {"perf_logger": perf_logger})
	_expect(perf_logger.labels.has("physics.stage5.hongryun.fireball_skill"), "Hongryun update should label the fireball skill section")
	_expect(perf_logger.labels.has("physics.stage5.hongryun.fireball_spawn"), "Hongryun update should label fireball spawn work")
	_expect(perf_logger.labels.has("physics.stage5.hongryun.projectiles"), "Hongryun update should label projectile motion work")

	var inferno_state := Stage5HongryunState.new()
	var inferno_logger := FakePerfLogger.new()
	inferno_state.inferno_active = true
	inferno_state.inferno_phase = 2
	inferno_state.ball_hold_active = true
	inferno_state.ball_hijack_reason = "hongryun_inferno_trail"
	inferno_state.inferno_base_vel = Vector2.DOWN
	inferno_state.update(1.0 / 60.0, context, {"perf_logger": inferno_logger})
	_expect(inferno_logger.labels.has("physics.stage5.hongryun.inferno"), "Hongryun update should label the inferno section")
	_expect(inferno_logger.labels.has("physics.stage5.hongryun.inferno_setup"), "Hongryun inferno should label setup/trail append work")
	_expect(inferno_logger.labels.has("physics.stage5.hongryun.inferno_trail_motion"), "Hongryun inferno should label trail motion work")


func _verify_fireball_hit_and_parry() -> void:
	var state := Stage5HongryunState.new()
	var audio := FakeAudio.new()
	var movement := FakeMovementState.new()
	var status := StatusEffectState.new()
	var context: Dictionary = _base_context()
	var player_center: Vector2 = _player_center(context)
	var deps := {
		"audio": audio,
		"movement_state": movement,
		"status_effect_state": status,
	}

	state.fireball_projectiles = [{
		"pos": player_center,
		"vel": Vector2.ZERO,
		"radius": Stage5HongryunState.FIREBALL_RADIUS,
	}]
	var hit_result: Dictionary = state.update(1.0 / 60.0, context, deps)
	_expect(state.fireball_projectiles.is_empty(), "player collision should remove the fireball")
	_expect(bool(hit_result.get("stage5_hongryun_fireball_hit_player", false)), "fireball hit should be reported")
	_expect(is_equal_approx(float(hit_result.get("stage5_hongryun_dragon_orb_count", 0.0)), 1.0), "fireball hit should charge one dragon orb")
	_expect(status.has_status("player", "stun"), "fireball hit should apply player stun")
	_expect(movement.knockback_count == 1 and abs(movement.last_velocity) == 12.0, "fireball hit should apply the original 12px knockback")
	_expect(audio.hurt_count == 1, "fireball hit should play a Hongryun hurt cue")

	var immune_state := Stage5HongryunState.new()
	var immune_runtime := FakeImmuneRuntime.new()
	immune_state.fireball_projectiles = [{
		"pos": player_center,
		"vel": Vector2.ZERO,
		"radius": Stage5HongryunState.FIREBALL_RADIUS,
	}]
	var parry_result: Dictionary = immune_state.update(1.0 / 60.0, context, {"active_item_runtime": immune_runtime})
	_expect(bool(parry_result.get("stage5_hongryun_fireball_parried", false)), "boss-skill immunity should parry Hongryun fireballs")
	_expect(is_equal_approx(immune_state.dragon_orb_count, 0.0), "parried fireballs should not charge dragon orbs")
	_expect(immune_runtime.parry_count == 1, "magic anti hook should be notified for parried fireballs")


func _verify_round_reset_preserves_dragon_orbs() -> void:
	var state := Stage5HongryunState.new()
	state.debug_set_dragon_orb_count(3)
	state.reset_round()
	_expect(is_equal_approx(state.dragon_orb_count, 3.0), "round reset should preserve Hongryun dragon orbs in the Godot port")
	_expect(not state.inferno_ready, "round reset should keep non-full dragon orbs not-ready")

	state.debug_force_inferno_ready()
	state.reset_round()
	_expect(is_equal_approx(state.dragon_orb_count, 5.0), "round reset should preserve a full Hongryun dragon orb gauge")
	_expect(state.inferno_ready, "round reset should preserve Hongryun inferno readiness when the gauge is full")


func _verify_inferno_phase_machine_and_cleanup() -> void:
	var state := Stage5HongryunState.new()
	var audio := FakeAudio.new()
	var background := FakeStageBackground.new()
	var context: Dictionary = _base_context()
	context["ball_pos"] = Vector2(380.0, 260.0)
	context["ball_vel"] = Vector2(0.0, -8.0)
	var deps := {
		"audio": audio,
		"stage_background": background,
	}

	state.debug_force_inferno_ready()
	var start_result: Dictionary = state.register_boss_paddle_contact(Vector2(0.0, -8.0), deps, context)
	var expected_base_dir: Vector2 = (_inferno_expected_target(context) - _get_vector2(context, "ball_pos", Vector2.ZERO)).normalized()
	_expect(bool(start_result.get("stage5_hongryun_inferno_started", false)), "boss paddle contact should start inferno when ready")
	_expect(state.inferno_base_vel.dot(expected_base_dir) > 0.999, "inferno should start toward the locked floor plunge target")
	_expect(state.should_skip_ball_motion_step(), "inferno charge should own the ball motion step")
	_expect(audio.charge_count == 1, "inferno start should play the charge cue")
	_expect(background.inferno_modes == [true], "inferno start should enable background inferno mode")

	var result: Dictionary = {}
	var charge_steps := int(ceil(Stage5HongryunState.INFERNO_CHARGE_SEC * 60.0)) + 1
	for _i in range(charge_steps):
		result = state.update(1.0 / 60.0, context, deps)
		if result.has("ball_pos"):
			context["ball_pos"] = result["ball_pos"]
		if result.has("ball_vel"):
			context["ball_vel"] = result["ball_vel"]
	_expect(int(result.get("stage5_hongryun_inferno_phase", 0)) == 2, "inferno should transition from charge to trail after the configured charge window")
	_expect(audio.shoot_count == 1, "inferno trail phase should play the shoot cue once")
	_expect(state.should_skip_ball_motion_step(), "inferno trail should still own ball motion")

	var miss_result: Dictionary = state.resolve_inferno_player_miss(_get_vector2(context, "ball_pos", Vector2.ZERO), deps)
	_expect(bool(miss_result.get("stage5_hongryun_inferno_missed_player", false)), "inferno miss should expose the boss-score cleanup marker")
	_expect(not state.should_skip_ball_motion_step(), "inferno miss should release the ball motion hijack")
	_expect(background.inferno_modes == [true, false], "inferno cleanup should disable background inferno mode")

	state.debug_force_inferno_ready()
	state.register_boss_paddle_contact(Vector2(0.0, 8.0), deps, context)
	state.reset_for_result()
	_expect(not state.should_skip_ball_motion_step(), "result reset should clear Hongryun ball hijack")
	_expect(state.fireball_projectiles.is_empty(), "result reset should clear Hongryun fireballs")


func _verify_inferno_trail_keeps_original_lateral_pressure() -> void:
	var state := Stage5HongryunState.new()
	var context: Dictionary = _base_context()
	context["ball_pos"] = Vector2(745.0, 220.0)
	context["ball_vel"] = Vector2(0.0, -8.0)
	context["player_pos"] = Vector2(302.5, 690.0)
	context["width"] = 760.0
	context["height"] = 750.0
	var deps := {}

	state.debug_force_inferno_ready()
	state.register_boss_paddle_contact(Vector2(0.0, -8.0), deps, context)
	var player_half_width: float = _get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0)).x * 0.5
	var guard_min_x := player_half_width
	var guard_max_x := float(context.get("width", 760.0)) - player_half_width
	var ball_half := float(context.get("ball_size", 28.6)) * 0.5
	var field_width := float(context.get("width", 760.0))
	var lateral_pressure_y := _get_vector2(context, "player_pos", Vector2.ZERO).y - 140.0
	var saw_trail := false
	var saw_midflight_lane_pressure := false
	var saw_wide_flourish := false
	var saw_pillar_overshoot := false  # 사용자 손맛 요청 — trail phase ball이 letterbox로 자유 침범
	var reached_floor := false
	var previous_ball_pos := _get_vector2(context, "ball_pos", Vector2.ZERO)
	var max_step_distance := 0.0

	for _i in range(540):
		var result: Dictionary = state.update(1.0 / 60.0, context, deps)
		if result.has("ball_pos"):
			var ball_pos: Vector2 = result["ball_pos"]
			if state.inferno_phase == 2:
				max_step_distance = maxf(max_step_distance, ball_pos.distance_to(previous_ball_pos))
			previous_ball_pos = ball_pos
			context["ball_pos"] = ball_pos
			if state.inferno_phase == 2:
				saw_trail = true
				_expect(ball_pos.y >= ball_half - 0.01 and ball_pos.y <= float(context.get("height", 750.0)) - ball_half + 0.01, "inferno trail should stay inside the playfield vertically")
				if ball_pos.y < lateral_pressure_y and (ball_pos.x < guard_min_x - 0.01 or ball_pos.x > guard_max_x + 0.01):
					saw_midflight_lane_pressure = true
				if ball_pos.y < lateral_pressure_y and (ball_pos.x <= ball_half + 36.0 or ball_pos.x >= field_width - ball_half - 36.0):
					saw_wide_flourish = true
				# 2026-05-18 사용자 손맛 요청: trail phase ball이 letterbox
				# 영역으로 자유 침범 (원본 동작 패리티). Codex review에서는
				# letterbox 위반 우려를 표명했으나 사용자 의도가 우선.
				if ball_pos.y < lateral_pressure_y and (ball_pos.x < -0.01 or ball_pos.x > field_width + 0.01):
					saw_pillar_overshoot = true
				if ball_pos.y + ball_half >= float(context.get("height", 750.0)) - 0.01:
					reached_floor = true
					break
		if result.has("ball_vel"):
			context["ball_vel"] = result["ball_vel"]

	_expect(saw_trail, "inferno guard-lane smoke should reach the trail phase")
	_expect(saw_midflight_lane_pressure, "inferno should keep midflight side pressure instead of clamping to the guard lane for the whole trail")
	_expect(saw_wide_flourish, "inferno should flourish broadly near the playfield edges before the final plunge")
	# Restored (2026-05-18 사용자 손맛 요청): trail phase ball이 letterbox로
	# 실제 침범해야 함. 원본 게임 패리티 — 필러 가로지르는 손맛이 핵심.
	_expect(saw_pillar_overshoot, "inferno should let the real ball physically cross into the pillar letterbox during trail (user 손맛 requirement)")
	_expect(reached_floor, "inferno should keep plunging until the floor-miss scoring gate can close the round")
	_expect(max_step_distance <= 60.0, "inferno should not move so far per frame that the final guard becomes unreadable")


func _verify_inferno_landing_target_locks_on_start() -> void:
	var state := Stage5HongryunState.new()
	var context: Dictionary = _base_context()
	context["ball_pos"] = Vector2(380.0, 260.0)
	context["ball_vel"] = Vector2(0.0, -8.0)
	context["player_pos"] = Vector2(122.5, 690.0)
	var original_target := _inferno_expected_target(context)
	var moved_target := Vector2(580.0, original_target.y)
	var deps := {}

	state.debug_force_inferno_ready()
	state.register_boss_paddle_contact(Vector2(0.0, -8.0), deps, context)
	_expect(state.inferno_guard_target_locked, "inferno should lock a landing target when it starts")
	_expect(state.inferno_guard_target.distance_to(original_target) <= 0.01, "inferno landing target should start at the player's original guard point")

	context["player_pos"] = moved_target - _get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0)) * 0.5
	for _i in range(72):
		var result: Dictionary = state.update(1.0 / 60.0, context, deps)
		if result.has("ball_pos"):
			context["ball_pos"] = result["ball_pos"]
		if result.has("ball_vel"):
			context["ball_vel"] = result["ball_vel"]

	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var original_dir: Vector2 = (original_target - ball_pos).normalized()
	var moved_dir: Vector2 = (moved_target - ball_pos).normalized()
	_expect(state.inferno_guard_target.distance_to(original_target) <= 0.01, "inferno locked landing target should not follow later player movement")
	_expect(original_dir.dot(moved_dir) < 0.98, "inferno target-lock smoke should move the player far enough to catch live tracking")


func _verify_inferno_guard_hover_releases_ball_hijack() -> void:
	var state := Stage5HongryunState.new()
	var controller := BallUpdateController.new()
	var context: Dictionary = _base_context()
	var ball_size: float = float(context.get("ball_size", 28.6))
	context["ball_pos"] = Vector2(380.0, 690.0 - ball_size * 0.5 - 2.0)
	context["ball_vel"] = Vector2(5.0, 0.0)
	context["hitbox_padding"] = 5.0
	context["min_ball_speed"] = 3.0
	context["max_ball_speed"] = 20.0
	state.inferno_active = true
	state.inferno_phase = 2
	state.ball_hold_active = true
	state.ball_hijack_reason = "hongryun_inferno_trail"
	state.inferno_base_vel = Vector2.RIGHT

	var result: Dictionary = controller.update(1.0 / 60.0, context, {"stage5_hongryun_state": state})
	var snapshot: Dictionary = result.get("snapshot", {})
	_expect(bool(snapshot.get("stage5_hongryun_inferno_guarded", false)), "inferno hover at the player guard band should register as a paddle guard")
	_expect(not state.should_skip_ball_motion_step(), "inferno guard should release the Stage 5 ball hijack")
	_expect(not bool(snapshot.get("skip_ball_motion_step", true)), "inferno guard should let normal ball motion resume")
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO).y < 0.0, "inferno guard should bounce the ball upward instead of letting it slide sideways")


# Codex review 2026-05-18: glance vs 정타 분기 검증. paddle 가장자리 hit
# (paddle 중심에서 폭 35% 초과)에서는 stage5_hongryun_inferno_glance_bounce
# 신호가 나와야 한다 (stun 없는 빠른 역공). paddle 중심 hit은 기존
# stage5_hongryun_inferno_guarded 신호 유지.
func _verify_inferno_glance_bounce_paddle_edge() -> void:
	var state := Stage5HongryunState.new()
	var controller := BallUpdateController.new()
	var context: Dictionary = _base_context()
	var ball_size: float = float(context.get("ball_size", 28.6))
	var paddle_w: float = 155.0
	var ball_x: float = 380.0
	# paddle 중심을 ball.x에서 paddle_w * 0.40 떨어뜨려 glance threshold(35%) 초과
	var paddle_center: float = ball_x - paddle_w * 0.40
	var player_pos := Vector2(paddle_center - paddle_w * 0.5, 690.0)
	context["ball_pos"] = Vector2(ball_x, 690.0 - ball_size * 0.5 - 2.0)
	context["ball_vel"] = Vector2(5.0, 0.0)
	context["player_pos"] = player_pos
	context["hitbox_padding"] = 5.0
	context["min_ball_speed"] = 3.0
	context["max_ball_speed"] = 20.0
	state.inferno_active = true
	state.inferno_phase = 2
	state.ball_hold_active = true
	state.ball_hijack_reason = "hongryun_inferno_trail"
	state.inferno_base_vel = Vector2.DOWN

	var result: Dictionary = controller.update(1.0 / 60.0, context, {"stage5_hongryun_state": state})
	var snapshot: Dictionary = result.get("snapshot", {})
	_expect(bool(snapshot.get("stage5_hongryun_inferno_glance_bounce", false)), "paddle edge hit (>35%) should register as glance bounce (counter-attack)")
	_expect(not bool(snapshot.get("stage5_hongryun_inferno_guarded", false)), "glance bounce path should not also flag the standard guard")
	_expect(not state.should_skip_ball_motion_step(), "glance bounce should release the ball hijack")
	_expect(not state.inferno_active, "glance bounce should end the inferno trail")


func _verify_inferno_floor_miss_scores_boss_before_late_guard() -> void:
	var state := Stage5HongryunState.new()
	var controller := BallUpdateController.new()
	var context: Dictionary = _base_context()
	var ball_size: float = float(context.get("ball_size", 28.6))
	context["ball_pos"] = Vector2(92.0, float(context.get("height", 750.0)) - ball_size * 0.5)
	context["ball_vel"] = Vector2(4.0, 0.0)
	context["hitbox_padding"] = 5.0
	state.inferno_active = true
	state.inferno_phase = 2
	state.ball_hold_active = true
	state.ball_hijack_reason = "hongryun_inferno_trail"
	state.inferno_base_vel = Vector2.DOWN

	var result: Dictionary = controller.update(1.0 / 60.0, context, {"stage5_hongryun_state": state})
	var snapshot: Dictionary = result.get("snapshot", {})
	_expect(str(result.get("score_event", "")) == "boss", "inferno floor miss should immediately score for the boss")
	_expect(bool(snapshot.get("stage5_hongryun_inferno_missed_player", false)), "inferno floor miss should expose the miss marker")
	_expect(not state.should_skip_ball_motion_step(), "inferno floor miss should clear the Stage 5 ball hijack before a late guard")
	_expect(not bool(snapshot.get("skip_ball_motion_step", true)), "inferno floor miss should let the score flow own the next ball reset")


func _verify_fire_machine_event_phase_collision_and_draw_context() -> void:
	var event := Stage5HongryunFireMachineEvent.new()
	var audio := FakeAudio.new()
	var movement := FakeMovementState.new()
	var context: Dictionary = _base_context()
	context["play_left"] = 0.0
	context["play_right"] = 760.0
	context["height"] = 750.0
	var deps := {
		"audio": audio,
		"movement_state": movement,
	}

	event.debug_force_ready()
	var result: Dictionary = event.update(1.0 / 60.0, context, deps)
	_expect(bool(result.get("stage5_hongryun_fire_machine_active", false)), "fire machine should activate when its timer expires on Stage 5")
	var saw_breath := false
	var saw_zone := false
	for _i in range(520):
		result = event.update(1.0 / 60.0, context, deps)
		if bool(result.get("stage5_hongryun_fire_machine_breath_fired", false)):
			saw_breath = true
		if int(result.get("stage5_hongryun_fire_machine_fire_zone_count", 0)) > 0:
			saw_zone = true
			break
	_expect(audio.door_count >= 1, "fire machine should reuse the original door cue")
	_expect(audio.machine_count >= 1, "fire machine should reuse the original machine rise cue")
	_expect(audio.fireball_count >= 1, "fire machine breath should play the Hongryun fire cue")
	_expect(saw_breath, "fire machine should fire a dragon breath stream during spraying")
	_expect(saw_zone, "fire machine breath should leave a floor fire zone")

	var hud_skill: Dictionary = event.get_hud_skill_context()
	_expect(str(hud_skill.get("id", "")) == "hongryun_fire_machine", "fire machine should expose the reserved Stage 5 HUD card id")
	_expect(float(hud_skill.get("cooldown_total", 0.0)) > 0.0, "fire machine HUD card should expose cooldown metadata")

	var draw_context: Dictionary = event.get_actor_draw_context()
	_expect(draw_context.has("stage5_hongryun_fire_machine_dragons"), "fire machine draw context should expose dragon head state")
	_expect(_as_array(draw_context.get("stage5_hongryun_fire_machine_streams", [])).size() >= 0, "fire machine draw context should expose stream state")
	_expect(_as_array(draw_context.get("stage5_hongryun_fire_machine_zones", [])).size() >= 1, "fire machine draw context should expose fire zones")

	var player_center := _player_center(context)
	event.fire_zones = [{
		"pos": player_center,
		"width": 80.0,
		"height": 32.0,
		"duration": 150.0,
		"spread_timer": 0.0,
		"flames": [],
	}]
	event.player_in_fire_zone = false
	event.fire_zone_hit_cooldown = 0.0
	result = event.update(1.0 / 60.0, context, deps)
	_expect(bool(result.get("stage5_hongryun_fire_machine_zone_hit_player", false)), "fire machine fire zone should knock the player when touched")
	_expect(movement.knockback_count >= 1 and abs(movement.last_velocity) == 25.0, "fire machine fire zone should use the original 25px push strength")

	context["dash_snapshot"] = {"active": true}
	event.fire_zones = [{
		"pos": player_center,
		"width": 80.0,
		"height": 32.0,
		"duration": 150.0,
		"spread_timer": 0.0,
		"flames": [],
	}]
	event.player_in_fire_zone = false
	result = event.update(1.0 / 60.0, context, deps)
	_expect(bool(result.get("stage5_hongryun_fire_machine_zone_extinguished", false)), "player dash should extinguish a fire machine fire zone")
	_expect(event.fire_zones.is_empty(), "extinguished fire zones should be removed immediately")

	event.reset_for_result()
	_expect(not event.is_active(), "fire machine result reset should clear active phase")
	_expect(event.fire_zones.is_empty(), "fire machine result reset should clear fire zones")


func _verify_fire_machine_renderer_does_not_reset_canvas_transform() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_playfield_renderer.gd")
	var body := _source_function_body(source, "func _draw_fire_machine_dragon_head")
	_expect(not body.is_empty(), "Stage 5 fire machine dragon head renderer should exist")
	_expect(body.find("draw_set_transform") < 0, "Stage 5 playfield renderer must not reset CanvasItem transform while drawing fire machine dragons")
	_expect(body.find("_draw_rotated_texture_region") >= 0, "Stage 5 fire machine dragon head should use transform-free rotated texture polygons")


func _verify_inferno_pillar_flourish_renderer_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd")
	_expect(source.find("func _draw_inferno_pillar_flourish") >= 0, "Stage 5 pillar scene drawer should expose an inferno pillar flourish pass")
	_expect(source.find("INFERNO_PILLAR_AURA_OUTSIDE_MARGIN") >= 0, "Stage 5 inferno pillar flourish should declare an outside-margin aura constant")
	_expect(source.find("stage5_hongryun_inferno_trail") >= 0, "inferno pillar flourish should consume the runtime inferno trail")
	_expect(source.find("game_offset.x + 10.0") >= 0, "inferno pillar flourish should bridge from the left game edge into the pillar")
	_expect(source.find("game_offset.x + game_size.x - 10.0") >= 0, "inferno pillar flourish should bridge from the right game edge into the pillar")
	_expect(source.find("head_left_overshoot") >= 0, "inferno pillar flourish should react to the real ball head left overshoot")
	_expect(source.find("head_right_overshoot") >= 0, "inferno pillar flourish should react to the real ball head right overshoot")
	# Synthetic snake-shape free pillar proxy was removed once the real ball was
	# allowed to cross into the pillar letterbox via the transformed playfield
	# pass. Guard against re-introducing it.
	_expect(source.find("func _draw_inferno_free_pillar_proxy") < 0, "Stage 5 inferno should no longer rely on the synthetic free pillar proxy now that the real trail flows into the letterbox")
	_expect(source.find("INFERNO_FREE_PILLAR_PROXY_NODES") < 0, "Stage 5 inferno should not retain the synthetic free pillar proxy constants")


func _verify_inferno_flame_dragon_renderer_removed() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_playfield_renderer.gd")
	_expect(source.find("stage5_hongryun_inferno_flame_dragon_sheet") < 0, "Stage 5 inferno should not load the removed flame dragon sheet")
	_expect(source.find("func _draw_inferno_dragon_echo") < 0, "Stage 5 inferno should not draw flame dragon echoes after the visual rollback")
	_expect(source.find("INFERNO_DRAGON_") < 0, "Stage 5 inferno should not retain flame dragon renderer constants")


func _verify_ball_update_hijack_query_clears_stale_skip() -> void:
	var controller := BallUpdateController.new()
	var fake_state := FakeStage5SkipState.new()
	var scene := {"skip_ball_motion_step": true}
	controller._apply_stage5_ball_motion_hijack(scene, {"current_stage": 5}, {"stage5_hongryun_state": fake_state})
	_expect(not bool(scene.get("skip_ball_motion_step", true)), "Stage 5 ball update query should clear a stale shared skip flag")
	fake_state.skipping = true
	controller._apply_stage5_ball_motion_hijack(scene, {"current_stage": 5}, {"stage5_hongryun_state": fake_state})
	_expect(bool(scene.get("skip_ball_motion_step", false)), "Stage 5 ball update query should set skip while Hongryun owns the ball")


func _base_context() -> Dictionary:
	return {
		"current_stage": 5,
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(380.0, 360.0),
		"ball_vel": Vector2(0.0, 8.0),
		"ball_size": 28.6,
		"boss_pos": Vector2(330.0, 55.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
	}


func _player_center(context: Dictionary) -> Vector2:
	return _get_vector2(context, "player_pos", Vector2.ZERO) + _get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0)) * 0.5


func _inferno_expected_target(context: Dictionary) -> Vector2:
	return _player_center(context)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _source_function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + signature.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
