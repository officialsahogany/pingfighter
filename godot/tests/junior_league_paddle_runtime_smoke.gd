extends SceneTree

const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")
const BattleSceneBootstrap := preload("res://scripts/core/battle_scene_bootstrap.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BallRoundController := preload("res://scripts/ball/ball_round_controller.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var current_stage := 1
	var ai_mode := "junior league"
	var selected_character_type := "smasher"
	var arena_mode_enabled := false
	var weather_type := ""
	var player_pos := Vector2.ZERO
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_paddle_visual_scale_override := -1.0
	var boss_pos := Vector2.ZERO
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeRegistry:
	extends RefCounted

	var dash_state := FakeDashState.new()
	var orb_hud_state := FakeOrbHudState.new()

	func get_instance(key: String) -> Object:
		match key:
			"smasher_dash_state":
				return dash_state
			"orb_hud_state":
				return orb_hud_state
		return null


class FakeDashState:
	extends RefCounted

	var reset_full_calls: Array[int] = []
	var tokens := 1
	var max_tokens := 1

	func reset_full(value: int) -> void:
		max_tokens = max(1, value)
		tokens = max_tokens
		reset_full_calls.append(max_tokens)

	func get_snapshot() -> Dictionary:
		return {"tokens": tokens, "max_tokens": max_tokens}


class FakeOrbHudState:
	extends RefCounted

	var reset_dash_token_calls: Array[int] = []

	func reset_dash_tokens(value: int) -> void:
		reset_dash_token_calls.append(value)


func _init() -> void:
	_verify_junior_paddle_runtime_size_without_visual_scale()
	_verify_mythic_boss_paddle_runtime_width()

	if _failures.is_empty():
		print("junior_league_paddle_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_junior_paddle_runtime_size_without_visual_scale() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var config := BattleSceneConfig.new()
	var startup_context: Dictionary = config.build_startup_context(owner)

	_expect(str(startup_context.get("ai_mode", "")) == "junior", "junior startup context should normalize the league mode")
	_expect(is_equal_approx(float(startup_context.get("league_player_paddle_scale", 0.0)), 1.5), "junior startup context should request a 50 percent larger runtime paddle")
	_expect(int(startup_context.get("starting_dash_tokens", 0)) == 2, "junior startup context should request two starting dash tokens")

	var bootstrap := BattleSceneBootstrap.new()
	var snapshot: Dictionary = bootstrap.initialize(owner, startup_context, registry)
	_expect(registry.dash_state.reset_full_calls == [2], "junior bootstrap should fill two dash tokens")
	_expect(registry.orb_hud_state.reset_dash_token_calls == [2], "junior bootstrap should sync the dash-token HUD to two charges")
	_expect(int(snapshot.get("starting_dash_tokens", 0)) == 2, "junior bootstrap snapshot should preserve the league dash-token baseline")
	_expect(is_equal_approx(float(snapshot.get("player_paddle_width", 0.0)), 232.5), "junior runtime paddle width should increase by 50 percent")
	_expect(is_equal_approx(float(snapshot.get("player_paddle_height", 0.0)), 75.0), "junior runtime paddle height should increase by 50 percent")
	_expect(is_equal_approx(float(snapshot.get("runtime_paddle_base_width", 0.0)), 232.5), "junior runtime base width should include the league bonus")
	_expect(is_equal_approx(float(snapshot.get("runtime_paddle_base_height", 0.0)), 75.0), "junior runtime base height should include the league bonus")
	_expect(is_equal_approx(float(snapshot.get("player_paddle_scale", 0.0)), 1.5), "junior logical paddle scale should reflect the wider hitbox")
	_expect(is_equal_approx(float(snapshot.get("player_paddle_visual_scale_override", 0.0)), 1.0), "junior visual scale override should keep the player image at normal size")
	var player_pos: Vector2 = snapshot.get("player_pos", Vector2.ZERO)
	_expect(is_equal_approx(player_pos.x, 760.0 * 0.5 - 232.5 * 0.5), "junior paddle should spawn centered with its larger hitbox")
	_expect(is_equal_approx(player_pos.y + 75.0, 750.0), "junior paddle should stay floor aligned")

	owner.player_pos = player_pos
	owner.player_paddle_width = float(snapshot.get("player_paddle_width", 0.0))
	owner.player_paddle_height = float(snapshot.get("player_paddle_height", 0.0))
	owner.player_paddle_scale = float(snapshot.get("player_paddle_scale", 1.0))
	owner.player_paddle_visual_scale_override = float(snapshot.get("player_paddle_visual_scale_override", -1.0))
	var draw_context: Dictionary = BattleDrawPlayfieldSceneContext.new().build(owner, Vector2.ZERO, registry)
	_expect(draw_context.get("player_paddle_size", Vector2.ZERO) == Vector2(232.5, 75.0), "draw context should keep the enlarged runtime paddle size")
	_expect(is_equal_approx(float(draw_context.get("player_paddle_scale", 0.0)), 1.0), "draw context should render the player image at normal scale in junior league")

	var reset_config: Dictionary = BallUpdateContext.new().build_reset_config(owner)
	_expect(is_equal_approx(float(reset_config.get("player_paddle_width", 0.0)), 232.5), "junior ball reset config should use the enlarged player paddle width")
	_expect(is_equal_approx(float(reset_config.get("player_y", 0.0)), 675.0), "junior ball reset config should preserve the floor-aligned player y")
	var reset_result: Dictionary = BallRoundController.new().reset_ball(reset_config, {}, {})
	var reset_player_pos: Vector2 = reset_result.get("player_pos", Vector2.ZERO)
	_expect(is_equal_approx(reset_player_pos.x, 760.0 * 0.5 - 232.5 * 0.5), "junior ball reset should keep the enlarged player paddle centered")
	_expect(is_equal_approx(reset_player_pos.y, 675.0), "junior ball reset should keep the enlarged player paddle floor aligned")
	owner.free()


func _verify_mythic_boss_paddle_runtime_width() -> void:
	var owner := FakeOwner.new()
	owner.ai_mode = "mythic league"
	var registry := FakeRegistry.new()
	var config := BattleSceneConfig.new()
	var startup_context: Dictionary = config.build_startup_context(owner)

	_expect(str(startup_context.get("ai_mode", "")) == "mythic", "mythic startup context should normalize the league mode")
	_expect(is_equal_approx(float(startup_context.get("league_boss_paddle_scale", 0.0)), 1.15), "mythic startup context should request a 15 percent wider boss hitbox")
	_expect(is_equal_approx(float(startup_context.get("boss_paddle_width", 0.0)), 115.0), "mythic startup context should widen the boss hitbox to 115px")

	var bootstrap := BattleSceneBootstrap.new()
	var snapshot: Dictionary = bootstrap.initialize(owner, startup_context, registry)
	_expect(is_equal_approx(float(snapshot.get("boss_paddle_width", 0.0)), 115.0), "mythic bootstrap snapshot should preserve the wider boss hitbox")
	_expect(is_equal_approx(float(snapshot.get("boss_hitbox_height", 0.0)), 40.0), "mythic bootstrap snapshot should keep boss hitbox height unchanged")
	var boss_pos: Vector2 = snapshot.get("boss_pos", Vector2.ZERO)
	_expect(is_equal_approx(boss_pos.x, 760.0 * 0.5 - 115.0 * 0.5), "mythic boss should spawn centered with its wider hitbox")

	owner.boss_pos = boss_pos
	owner.boss_paddle_width = float(snapshot.get("boss_paddle_width", 0.0))
	owner.boss_hitbox_height = float(snapshot.get("boss_hitbox_height", 0.0))
	var draw_context: Dictionary = BattleDrawPlayfieldSceneContext.new().build(owner, Vector2.ZERO, registry)
	_expect(draw_context.get("boss_paddle_size", Vector2.ZERO) == Vector2(115.0, 40.0), "draw context should expose the widened mythic boss hitbox")
	_expect(is_equal_approx(float(draw_context.get("boss_paddle_width", 0.0)), 115.0), "draw context should expose mythic boss paddle width")

	var ball_context: Dictionary = BallUpdateContext.new().build_update_context(owner)
	_expect(ball_context.get("boss_paddle_size", Vector2.ZERO) == Vector2(115.0, 40.0), "ball collision context should use the widened mythic boss hitbox")
	_expect(is_equal_approx(float(ball_context.get("boss_paddle_width", 0.0)), 115.0), "ball collision context should expose mythic boss paddle width")
	_expect(is_equal_approx(float(ball_context.get("max_ball_speed", 0.0)), 32.0), "mythic league alias should still receive the mythic ball speed cap")

	var reset_config: Dictionary = BallUpdateContext.new().build_reset_config(owner)
	_expect(is_equal_approx(float(reset_config.get("boss_paddle_width", 0.0)), 115.0), "mythic ball reset config should use the widened boss hitbox")
	var reset_result: Dictionary = BallRoundController.new().reset_ball(reset_config, {}, {})
	var reset_boss_pos: Vector2 = reset_result.get("boss_pos", Vector2.ZERO)
	_expect(is_equal_approx(reset_boss_pos.x, 760.0 * 0.5 - 115.0 * 0.5), "mythic ball reset should keep the wider boss hitbox centered")

	var serve_config: Dictionary = BallUpdateContext.new().build_serve_config(owner)
	_expect(is_equal_approx(float(serve_config.get("boss_paddle_width", 0.0)), 115.0), "mythic serve config should use the widened boss hitbox")
	owner.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
