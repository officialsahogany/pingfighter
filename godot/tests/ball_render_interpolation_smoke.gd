extends SceneTree

const BallRenderInterpolation := preload("res://scripts/ball/ball_render_interpolation.gd")
const BattleDrawBallContext := preload("res://scripts/core/battle_draw_ball_context.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleSceneShell := preload("res://scripts/core/battle_scene_shell.gd")

var _failures: Array[String] = []


class FakeRoundState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false

	func does_player_serve() -> bool:
		return true


class FakeBallEffects:
	extends RefCounted

	func get_ghost_trail() -> Array:
		return []

	func get_intensity_trail() -> Array:
		return []

	func get_intensity_particles() -> Array:
		return []


class FakeImpactEffects:
	extends RefCounted

	func get_energy_explosion_particles() -> Array:
		return []


class FakeBallIntensity:
	extends RefCounted

	func calculate(_ball_vel: Vector2) -> float:
		return 0.0

	func get_current_colors() -> Array:
		return []

	func get_current_glow_color() -> Color:
		return Color.WHITE


func _init() -> void:
	_verify_step_capture_and_reset()
	_verify_skip_motion_release_resets()
	_verify_manual_fraction_moves_between_previous_and_current()
	_verify_draw_uses_reset_safe_current_position()
	_verify_effect_context_uses_same_ball_position()
	_verify_boss_draw_interpolation_policy()
	_verify_project_interpolation_settings()
	_verify_shell_reset_api()
	_verify_source_anchors()

	if _failures.is_empty():
		print("ball_render_interpolation_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_step_capture_and_reset() -> void:
	var scene := {
		"ball_pos": Vector2(10.0, 20.0),
		"skip_ball_motion_step": false,
	}
	BallRenderInterpolation.begin_physics_step(scene)
	_expect(_as_vector2(scene.get("ball_pos_prev", Vector2.ZERO)).is_equal_approx(Vector2(10.0, 20.0)), "physics step should capture the previous ball position before motion")
	scene["ball_pos"] = Vector2(30.0, 40.0)
	BallRenderInterpolation.finalize_physics_step(scene)
	_expect(not bool(scene.get("ball_interp_reset_requested", false)), "normal continuous motion should not request interpolation reset")
	_expect(_as_vector2(scene.get("ball_pos_prev", Vector2.ZERO)).is_equal_approx(Vector2(10.0, 20.0)), "continuous motion should keep the pre-step ball position for render interpolation")

	BallRenderInterpolation.reset_ball_interpolation(scene)
	_expect(bool(scene.get("ball_interp_reset_requested", false)), "forced ball movement should request a one-frame interpolation reset")
	_expect(_as_vector2(scene.get("ball_pos_prev", Vector2.ZERO)).is_equal_approx(Vector2(30.0, 40.0)), "reset should collapse previous position to current position")
	_expect(BallRenderInterpolation.get_render_ball_pos(scene, Vector2.ZERO).is_equal_approx(Vector2(30.0, 40.0)), "reset draw should use the current ball position without lerp")


func _verify_skip_motion_release_resets() -> void:
	var scene := {
		"ball_pos": Vector2(7.0, 8.0),
		"skip_ball_motion_step": true,
	}
	BallRenderInterpolation.begin_physics_step(scene)
	scene["ball_pos"] = Vector2(80.0, 90.0)
	scene["skip_ball_motion_step"] = false
	BallRenderInterpolation.finalize_physics_step(scene)

	_expect(bool(scene.get("ball_interp_reset_requested", false)), "skip_ball_motion_step true-to-false release should reset interpolation")
	_expect(_as_vector2(scene.get("ball_pos_prev", Vector2.ZERO)).is_equal_approx(Vector2(80.0, 90.0)), "skip release reset should collapse previous position to released ball position")


func _verify_manual_fraction_moves_between_previous_and_current() -> void:
	var half_tick_usec: int = int(1000000.0 / 120.0)
	var scene := {
		"ball_pos": Vector2(100.0, 0.0),
		"ball_pos_prev": Vector2.ZERO,
		"ball_interp_reset_requested": false,
		"ball_interp_last_physics_usec": Time.get_ticks_usec() - half_tick_usec,
		"ball_render_interpolation_enabled": true,
	}
	var rendered_pos: Vector2 = BallRenderInterpolation.get_render_ball_pos(scene, Vector2.ZERO)
	_expect(rendered_pos.x > 1.0 and rendered_pos.x < 100.0, "manual interpolation fraction should render between previous and current ball positions")


func _verify_draw_uses_reset_safe_current_position() -> void:
	var builder: Object = BattleDrawBallContext.new()
	var context := {
		"ball_active": true,
		"ball_pos": Vector2(100.0, 120.0),
		"ball_pos_prev": Vector2(-500.0, -500.0),
		"ball_interp_reset_requested": true,
		"ball_render_interpolation_enabled": true,
		"textures": {},
	}
	var draw_context: Dictionary = builder.build_draw(context, {"round_state": FakeRoundState.new()})
	_expect(_as_vector2(draw_context.get("draw_pos", Vector2.ZERO)).is_equal_approx(Vector2(100.0, 120.0)), "ball draw should skip lerp during reset frames")

	context["ball_interp_reset_requested"] = false
	context["ball_render_interpolation_enabled"] = false
	draw_context = builder.build_draw(context, {"round_state": FakeRoundState.new()})
	_expect(_as_vector2(draw_context.get("draw_pos", Vector2.ZERO)).is_equal_approx(Vector2(100.0, 120.0)), "disabled interpolation should preserve current-position drawing")


func _verify_effect_context_uses_same_ball_position() -> void:
	var builder: Object = BattleDrawBallContext.new()
	var context := {
		"ball_active": true,
		"ball_pos": Vector2(150.0, 170.0),
		"ball_pos_prev": Vector2(-300.0, -300.0),
		"ball_interp_reset_requested": true,
		"ball_render_interpolation_enabled": true,
		"ball_vel": Vector2.RIGHT,
	}
	var deps := {
		"ball_effects": FakeBallEffects.new(),
		"ball_intensity": FakeBallIntensity.new(),
		"impact_effects": FakeImpactEffects.new(),
	}
	var effects_context: Dictionary = builder.build_effects_context(context, deps)
	_expect(_as_vector2(effects_context.get("ball_pos", Vector2.ZERO)).is_equal_approx(Vector2(150.0, 170.0)), "ball effects should share the same reset-safe rendered ball position")


func _verify_boss_draw_interpolation_policy() -> void:
	var builder: Object = BattleDrawActorContext.new()
	var context := {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"player_pos": Vector2(40.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(320.0, 25.0),
		"boss_pos_prev": Vector2(-300.0, -300.0),
		"boss_render_interpolation_enabled": false,
		"boss_paddle_size": Vector2(100.0, 40.0),
		"textures": {},
	}
	var actor_context: Dictionary = builder.build(context, {})
	_expect(_as_vector2(actor_context.get("boss_pos", Vector2.ZERO)).is_equal_approx(Vector2(320.0, 25.0)), "disabled boss interpolation should preserve the current boss paddle position")
	_expect(_as_vector2(actor_context.get("player_pos", Vector2.ZERO)).is_equal_approx(Vector2(40.0, 700.0)), "player paddle should keep latest-state rendering")


func _verify_project_interpolation_settings() -> void:
	_expect(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "manual render interpolation should enable Godot physics interpolation timing")
	_expect(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0)) == 72, "physics tick rate should stay aligned to the 72 FPS 144Hz-divisor render preset")
	_expect(is_equal_approx(float(ProjectSettings.get_setting("physics/common/physics_jitter_fix", 0.5)), 0.0), "manual render interpolation should disable physics jitter offset")


func _verify_shell_reset_api() -> void:
	var shell: Node = BattleSceneShell.new()
	shell.set("ball_pos", Vector2(222.0, 333.0))
	shell.reset_ball_interpolation()
	_expect(bool(shell.get("ball_interp_reset_requested")), "battle shell should expose reset_ball_interpolation for forced position changes")
	_expect(_as_vector2(shell.get("ball_pos_prev")).is_equal_approx(Vector2(222.0, 333.0)), "battle shell reset API should collapse previous position to current position")
	shell.free()


func _verify_source_anchors() -> void:
	var shell_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_shell.gd")
	var spawn_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_ball_spawn_intro.gd")
	var round_source: String = FileAccess.get_file_as_string("res://scripts/ball/ball_round_controller.gd")
	var update_source: String = FileAccess.get_file_as_string("res://scripts/ball/ball_update_controller.gd")
	var frame_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	var actor_update_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_actor_update_driver.gd")
	var playfield_context_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_draw_playfield_scene_context.gd")
	var actor_context_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_draw_actor_context.gd")

	_expect(shell_source.find("func reset_ball_interpolation()") >= 0, "shell should keep a single public reset_ball_interpolation API")
	_expect(spawn_source.find("reset_ball_interpolation") >= 0, "spawn intro forced ball placement should route through interpolation reset")
	_expect(round_source.find("reset_ball_interpolation(snapshot)") >= 0, "round reset and serve snapshots should reset interpolation")
	_expect(update_source.find("finalize_physics_step(scene)") >= 0, "ball update should finalize interpolation after motion and skip releases")
	_expect(playfield_context_source.find("\"ball_pos_prev\"") >= 0, "draw context should export previous ball position")
	_expect(playfield_context_source.find("\"ball_interp_reset_requested\"") >= 0, "draw context should export reset request state")
	_expect(playfield_context_source.find("\"ball_interp_last_physics_usec\"") >= 0, "draw context should export ball physics timestamp")
	_expect(frame_source.find("Manual render interpolation needs a fresh draw on render frames") >= 0, "frame process should queue redraw at render cadence for interpolation")
	_expect(actor_update_source.find("boss_pos_prev") >= 0, "boss update should capture the previous boss position before AI motion")
	_expect(actor_update_source.find("boss_interp_last_physics_usec") >= 0, "boss update should capture a physics timestamp for manual interpolation")
	_expect(playfield_context_source.find("\"boss_pos_prev\"") >= 0, "draw context should export previous boss position")
	_expect(playfield_context_source.find("\"boss_interp_last_physics_usec\"") >= 0, "draw context should export boss physics timestamp")
	_expect(playfield_context_source.find("\"boss_render_interpolation_enabled\"") >= 0, "draw context should export boss interpolation toggle")
	_expect(actor_context_source.find("_get_manual_interpolation_fraction") >= 0, "boss paddle draw should use render-time interpolation")
	_expect(actor_context_source.find("\"boss_pos\": boss_draw_pos") >= 0, "actor draw context should publish the interpolated boss position")
	_expect(actor_context_source.find("player_pos_prev") < 0, "player paddle should remain latest-state rendered")


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
