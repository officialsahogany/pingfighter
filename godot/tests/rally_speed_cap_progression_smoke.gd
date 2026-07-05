extends SceneTree

const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const BallSpeedDebugOverlay := preload("res://scripts/hud/ball_speed_debug_overlay.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")


class FakeOwner:
	var battle_textures: Dictionary = {}
	var selected_character_type := "smasher"
	var current_stage := 1
	var ai_mode := "champion"
	var arena_mode_enabled := false
	var weather_type := ""
	var weather_event_active := false
	var ball_pos := Vector2(380.0, 400.0)
	var ball_vel := Vector2(0.0, -20.0)
	var ball_active := true
	var player_pos := Vector2(300.0, 700.0)
	var boss_pos := Vector2(330.0, 25.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var special_gauge_max := 500.0
	var rally_speed_cap_bonus := 0.0


func _init() -> void:
	_verify_scene_state_tracks_rally_cap_bonus()
	_verify_update_context_applies_bonus_to_active_cap()
	_verify_fire_context_keeps_bonus_under_fire_cap()
	_verify_paddle_hits_raise_the_round_cap()
	_verify_round_cap_bonus_saturates_at_max()
	_verify_stale_oversized_bonus_normalizes_to_max()
	_verify_round_snapshots_reset_the_bonus()
	_verify_debug_overlay_uses_bonus()
	print("rally_speed_cap_progression_smoke: ok")
	quit(0)


func _verify_scene_state_tracks_rally_cap_bonus() -> void:
	var scene_state := BattleSceneState.new()
	_expect(scene_state.has_key("rally_speed_cap_bonus"), "battle scene state should preserve rally speed cap bonus")
	_expect(is_equal_approx(float(scene_state.get_value("rally_speed_cap_bonus")), 0.0), "rally speed cap bonus should default to zero")


func _verify_update_context_applies_bonus_to_active_cap() -> void:
	var owner := FakeOwner.new()
	owner.rally_speed_cap_bonus = 1.5
	var context: Dictionary = BallUpdateContext.new().build_update_context(owner)
	_expect(is_equal_approx(float(context.get("max_ball_speed", 0.0)), 27.5), "champion rally cap should be 26 plus the round bonus")
	_expect(is_equal_approx(float(context.get("impact_boost_max_ball_speed", 0.0)), 27.5), "impact cap should receive the same round bonus")
	_expect(is_equal_approx(float(context.get("rally_speed_cap_increase_per_hit", 0.0)), 0.5), "paddle hits should add 0.5 cap per hit")
	_expect(is_equal_approx(float(context.get("rally_speed_cap_bonus_max", 0.0)), 10.0), "update context should carry the rally cap bonus ceiling")


func _verify_fire_context_keeps_bonus_under_fire_cap() -> void:
	var owner := FakeOwner.new()
	owner.weather_type = "fire"
	owner.weather_event_active = true
	owner.rally_speed_cap_bonus = 1.0
	var context: Dictionary = BallUpdateContext.new().build_update_context(owner)
	_expect(is_equal_approx(float(context.get("max_ball_speed", 0.0)), 36.0), "fire rally cap should be 35 plus the round bonus")
	_expect(is_equal_approx(float(context.get("impact_boost_max_ball_speed", 0.0)), 36.0), "fire impact cap should receive the round bonus")
	_expect(is_equal_approx(float(context.get("fire_weather_max_ball_speed", 0.0)), 36.0), "fire hard cap should move with the round bonus")


func _verify_paddle_hits_raise_the_round_cap() -> void:
	var controller := PaddleBounceController.new()
	var deps := {
		"ball_physics": BallPhysics.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
	}
	var context := {
		"ball_pos": Vector2(380.0, 60.0),
		"ball_vel": Vector2(0.0, -24.0),
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
		"min_ball_speed": 3.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"rally_speed_cap_bonus": 0.0,
		"rally_speed_cap_increase_per_hit": 0.5,
		"max_bounce_angle": 60.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_vel": 0.0,
		"selected_character_type": "smasher",
	}
	var first_result: Dictionary = controller.bounce(330.0, 100.0, false, context, deps)
	_expect(is_equal_approx(float(first_result.get("rally_speed_cap_bonus", 0.0)), 0.5), "first paddle hit should add 0.5 to the round cap bonus")
	_expect(is_equal_approx(float(first_result.get("max_ball_speed", 0.0)), 26.5), "first paddle hit should raise max speed cap to 26.5")
	context.merge(first_result, true)
	var second_result: Dictionary = controller.bounce(330.0, 100.0, false, context, deps)
	_expect(is_equal_approx(float(second_result.get("rally_speed_cap_bonus", 0.0)), 1.0), "second paddle hit should add another 0.5 bonus")
	_expect(is_equal_approx(float(second_result.get("max_ball_speed", 0.0)), 27.0), "second paddle hit should raise max speed cap to 27")


func _verify_round_cap_bonus_saturates_at_max() -> void:
	var controller := PaddleBounceController.new()
	var deps := {
		"ball_physics": BallPhysics.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
	}
	var context := {
		"ball_pos": Vector2(380.0, 60.0),
		"ball_vel": Vector2(0.0, -24.0),
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
		"min_ball_speed": 3.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"rally_speed_cap_bonus": 0.0,
		"rally_speed_cap_increase_per_hit": 0.5,
		"rally_speed_cap_bonus_max": 10.0,
		"max_bounce_angle": 60.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_vel": 0.0,
		"selected_character_type": "smasher",
	}
	for i in range(30):
		context["ball_pos"] = Vector2(380.0, 60.0)
		context["ball_vel"] = Vector2(0.0, -24.0)
		var result: Dictionary = controller.bounce(330.0, 100.0, false, context, deps)
		context.merge(result, true)
	_expect(is_equal_approx(float(context.get("rally_speed_cap_bonus", 0.0)), 10.0), "rally cap bonus should saturate at the bonus ceiling")
	_expect(is_equal_approx(float(context.get("max_ball_speed", 0.0)), 36.0), "max speed cap should stop growing at 26 plus the ceiling")
	_expect(is_equal_approx(float(context.get("impact_boost_max_ball_speed", 0.0)), 36.0), "impact cap should stop growing at 26 plus the ceiling")


func _verify_stale_oversized_bonus_normalizes_to_max() -> void:
	var owner := FakeOwner.new()
	owner.rally_speed_cap_bonus = 50.0
	var context: Dictionary = BallUpdateContext.new().build_update_context(owner)
	_expect(is_equal_approx(float(context.get("max_ball_speed", 0.0)), 36.0), "oversized stored bonus should clamp to the ceiling on consumption")
	_expect(is_equal_approx(float(context.get("impact_boost_max_ball_speed", 0.0)), 36.0), "oversized stored bonus should clamp the impact cap too")


func _verify_round_snapshots_reset_the_bonus() -> void:
	var round_state := BallRoundState.new()
	var reset_snapshot: Dictionary = round_state.build_reset_snapshot(760.0, 750.0)
	_expect(is_equal_approx(float(reset_snapshot.get("rally_speed_cap_bonus", -1.0)), 0.0), "ball reset should clear the round cap bonus")
	var serve_snapshot: Dictionary = round_state.build_serve_snapshot(
		true,
		Vector2(300.0, 700.0),
		Vector2(330.0, 25.0),
		700.0,
		25.0,
		155.0,
		100.0,
		40.0,
		28.6,
		28.6,
		BallPhysics.new()
	)
	_expect(is_equal_approx(float(serve_snapshot.get("rally_speed_cap_bonus", -1.0)), 0.0), "new serves should start the cap bonus at zero")


func _verify_debug_overlay_uses_bonus() -> void:
	var overlay := BallSpeedDebugOverlay.new()
	_expect(is_equal_approx(overlay._get_max_ball_speed(false, 1.0, "champion", null, 0.0, 1.5), 27.5), "F9 speed overlay should show the active rally cap bonus")
	_expect(is_equal_approx(overlay._get_max_ball_speed(false, 1.0, "champion", null, 0.0, 50.0), 36.0), "F9 speed overlay should clamp an oversized bonus to the ceiling")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
