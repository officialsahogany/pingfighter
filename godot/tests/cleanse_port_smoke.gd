extends SceneTree

const CleanseState := preload("res://scripts/characters/smasher_cleanse_state.gd")
const MovementState := preload("res://scripts/characters/player_movement_state.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")


class FakeMovementState:
	var cleared := false
	var knockback_active := true

	func has_status_effect() -> bool:
		return knockback_active

	func get_status_snapshot() -> Dictionary:
		return {
			"knockback_active": knockback_active,
		}

	func clear_status_effects() -> void:
		cleared = true
		knockback_active = false


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "cleanse"

	func get_skill_cost(skill_name: String) -> float:
		return 100.0 if skill_name == "cleanse" else 0.0


class FakeSkillState:
	var triggered_skill := ""

	func get_configured_cooldown_remaining(_skill_name: String, _current_msec: int, _skill_config: Object) -> float:
		return 0.0

	func trigger_configured_cooldown(skill_name: String, _current_msec: int, _skill_config: Object) -> void:
		triggered_skill = skill_name


class FakeAudio:
	var played_cleanse := false

	func play_cleanse() -> void:
		played_cleanse = true


class FakeFeedback:
	var gauge_flash_triggered := false
	var shake_strength := 0.0

	func set_screen_shake(_duration: float, strength: float) -> void:
		shake_strength = strength

	func trigger_gauge_flash() -> void:
		gauge_flash_triggered = true


class FakeRuntimePerkState:
	func get_runtime_skill_level(skill_id: String) -> int:
		return 2 if skill_id == "extension_gear" else 0


class FakeDashState:
	var active := false
	var recovering := false

	func is_active() -> bool:
		return active

	func is_recovering() -> bool:
		return recovering

	func get_snapshot() -> Dictionary:
		return {
			"active": active,
			"recovering": recovering,
		}


class FakeRouterMovementState:
	var call_count := 0
	var last_cleansable := true

	func start_knockback(
		_velocity: float,
		_frames: float = 18.0,
		_decay_per_frame: float = 0.92,
		_replace_current: bool = false,
		cleansable: bool = true
	) -> bool:
		call_count += 1
		last_cleansable = cleansable
		return true


func _init() -> void:
	var cleanse_source := FileAccess.get_file_as_string("res://scripts/characters/smasher_cleanse_state.gd")
	var flare_cache_source := FileAccess.get_file_as_string("res://scripts/effects/impact_flare_texture_cache.gd")
	var shockwave_cache_source := FileAccess.get_file_as_string("res://scripts/effects/impact_shockwave_texture_cache.gd")
	_expect(cleanse_source.find("func _init()") < 0, "cleanse state should not hard-prewarm procedural textures from _init")
	_expect(cleanse_source.find("func prewarm_assets_step()") >= 0, "cleanse state should expose staged asset prewarm")
	_expect(flare_cache_source.find("static func prewarm_step()") >= 0, "impact flare cache should expose one-texture-at-a-time prewarm")
	_expect(shockwave_cache_source.find("static func prewarm_step()") >= 0, "impact shockwave cache should expose one-texture-at-a-time prewarm")
	var staged_cleanse: Object = CleanseState.new()
	var staged_guard := 0
	while not bool(staged_cleanse.prewarm_assets_step()) and staged_guard < 16:
		staged_guard += 1
	_expect(staged_guard < 16, "cleanse staged asset prewarm should complete within its texture chunk count")
	_expect(bool(staged_cleanse.prewarm_assets_step()), "completed cleanse staged asset prewarm should remain idempotent")

	var hit_recoil_movement: Object = MovementState.new()
	hit_recoil_movement.start_knockback(9.0, 36.0, 0.85, true, false)
	_expect(not hit_recoil_movement.has_status_effect(), "paddle-hit recoil should not count as a cleanse status")
	var hit_recoil_snapshot: Dictionary = hit_recoil_movement.get_status_snapshot()
	_expect(bool(hit_recoil_snapshot.get("knockback_motion_active", false)), "paddle-hit recoil should still move the paddle")
	_expect(not bool(hit_recoil_snapshot.get("knockback_cleansable", true)), "paddle-hit recoil should be tagged non-cleansable")

	var recoil_cleanse_state: Object = CleanseState.new()
	var recoil_skill_state := FakeSkillState.new()
	var recoil_audio := FakeAudio.new()
	var recoil_result: Dictionary = recoil_cleanse_state.update_input(
		{"up_pressed": true},
		850,
		150.0,
		Vector2(300.0, 640.0),
		{"paddle_width": 155.0, "paddle_height": 50.0},
		{
			"movement_state": hit_recoil_movement,
			"skill_config": FakeSkillConfig.new(),
			"skill_state": recoil_skill_state,
			"audio": recoil_audio,
		}
	)
	_expect(not bool(recoil_result.get("activated", false)), "cleanse should not activate from paddle-hit recoil")
	_expect(is_equal_approx(float(recoil_result.get("special_gauge", -1.0)), 150.0), "recoil-blocked cleanse should not spend gauge")
	_expect(not recoil_audio.played_cleanse, "recoil-blocked cleanse should not play audio")
	_expect(recoil_skill_state.triggered_skill == "", "recoil-blocked cleanse should not trigger cooldown")

	var router_movement := FakeRouterMovementState.new()
	var bounce_router: Object = PaddleBounceEventRouter.new()
	bounce_router.register_rally_feedback(
		Vector2(380.0, 690.0),
		Vector2(16.0, -18.0),
		true,
		false,
		{"movement_state": router_movement},
		{
			"player_pos": Vector2(300.0, 700.0),
			"player_paddle_width": 155.0,
		}
	)
	_expect(router_movement.call_count == 1, "player paddle-hit recoil should route through movement state")
	_expect(not router_movement.last_cleansable, "player paddle-hit recoil should be passed as non-cleansable")

	var blocked_cleanse_state: Object = CleanseState.new()
	var blocked_movement := FakeMovementState.new()
	var blocked_skill_state := FakeSkillState.new()
	var blocked_audio := FakeAudio.new()
	var dash_state := FakeDashState.new()
	dash_state.recovering = true
	var blocked_result: Dictionary = blocked_cleanse_state.update_input(
		{"up_pressed": true},
		900,
		150.0,
		Vector2(300.0, 640.0),
		{"paddle_width": 155.0, "paddle_height": 50.0},
		{
			"movement_state": blocked_movement,
			"skill_config": FakeSkillConfig.new(),
			"skill_state": blocked_skill_state,
			"audio": blocked_audio,
			"dash_state": dash_state,
		}
	)
	_expect(not bool(blocked_result.get("activated", false)), "cleanse should not activate during dash recovery")
	_expect(is_equal_approx(float(blocked_result.get("special_gauge", -1.0)), 150.0), "blocked cleanse should not spend gauge")
	_expect(not blocked_movement.cleared, "blocked cleanse should not clear status effects")
	_expect(not blocked_audio.played_cleanse, "blocked cleanse should not play audio")
	_expect(blocked_skill_state.triggered_skill == "", "blocked cleanse should not trigger cooldown")

	var cleanse_state: Object = CleanseState.new()
	var movement := FakeMovementState.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var runtime_perk_state := FakeRuntimePerkState.new()
	var deps := {
		"movement_state": movement,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"audio": audio,
		"feedback": feedback,
		"runtime_perk_state": runtime_perk_state,
	}
	var result: Dictionary = cleanse_state.update_input(
		{"up_pressed": true},
		1000,
		150.0,
		Vector2(300.0, 640.0),
		{"paddle_width": 155.0, "paddle_height": 50.0},
		deps
	)
	_expect(bool(result.get("activated", false)), "cleanse should activate when a status effect exists")
	_expect(is_equal_approx(float(result.get("special_gauge", -1.0)), 50.0), "cleanse should spend 100 gauge")
	_expect(movement.cleared, "cleanse should clear player movement status effects")
	_expect(not movement.has_status_effect(), "movement status should be cleared after cleanse")
	_expect(audio.played_cleanse, "cleanse should play its cast sound")
	_expect(skill_state.triggered_skill == "cleanse", "cleanse should trigger shared cooldown")
	_expect(feedback.gauge_flash_triggered and feedback.shake_strength > 0.0, "cleanse should trigger feedback")
	_expect(cleanse_state.is_immune(), "cleanse immunity should start immediately")

	var immunity_context: Dictionary = cleanse_state.get_status_context()
	_expect(
		is_equal_approx(float(immunity_context.get("initial_timer_frames", 0.0)), 450.0),
		"extension_gear Lv.2 should extend immunity duration to 450 frames"
	)
	_expect(
		is_equal_approx(float(immunity_context.get("counter_window_frames", 0.0)), 120.0),
		"cleanse should open a 2-second counter window"
	)
	var boosted_ball_vel: Vector2 = cleanse_state.apply_counter_speed_bonus(Vector2(100.0, 0.0))
	_expect(is_equal_approx(boosted_ball_vel.length(), 101.5), "cleanse counter should boost first hit speed by 1.5%")
	_expect(
		is_equal_approx(float(cleanse_state.get_status_context().get("counter_window_frames", -1.0)), 0.0),
		"cleanse counter window should be consumed after one boosted hit"
	)
	cleanse_state.update_effects(31.0, {
		"player_pos": Vector2(320.0, 650.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}, deps)
	_expect(cleanse_state.is_immune(), "cleanse immunity should persist after the cast wave finishes")
	print("cleanse_port_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
