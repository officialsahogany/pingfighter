extends SceneTree

const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const BallSpeedDebugOverlay := preload("res://scripts/hud/ball_speed_debug_overlay.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const CharacterSelectScreen := preload("res://scripts/ui/character_select_screen.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const Stage2BossSkillState := preload("res://scripts/stages/stage2/stage2_boss_skill_state.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


class FakeBossOwner:
	extends RefCounted

	var current_stage := 3
	var ai_mode := "limit league"
	var selected_character_type := "smasher"
	var stage1_boss_variant := "dalji"
	var ball_active := true
	var player_pos := Vector2(200.0, 690.0)
	var ball_pos := Vector2(320.0, 410.0)
	var ball_vel := Vector2(7.0, -3.0)


class FakeBallOwner:
	extends Node

	var current_stage := 3
	var ai_mode := "limit league"
	var selected_character_type := "smasher"
	var arena_mode_enabled := false
	var weather_type := ""
	var weather_active := false
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


func _init() -> void:
	_verify_config_normalization()
	_verify_boss_ai_limit_profile()
	_verify_ball_context_limit_profile()
	_verify_boss_dash_cooldown_alias()
	_verify_debug_overlay_limit_cap()
	_verify_character_select_four_league_layout()
	_verify_lingpet_unlock_equivalence()
	_verify_stage2_quake_parity()

	if _failures.is_empty():
		print("limit_league_tier_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_config_normalization() -> void:
	var config := BattleSceneConfig.new()
	_expect(BattleSceneConfig.normalize_league_mode("limit") == "limit", "limit id should normalize to itself")
	_expect(BattleSceneConfig.normalize_league_mode("limit league") == "limit", "limit league alias should normalize to limit")
	_expect(BattleSceneConfig.normalize_league_mode("limit") != "champion", "limit must not fall through to champion")
	_expect_close(config.get_league_boss_paddle_scale_for_mode("limit"), 1.07, "limit should request the 1.07 boss paddle scale")


func _verify_boss_ai_limit_profile() -> void:
	var builder := BossAiContextBuilder.new()
	var owner := FakeBossOwner.new()
	var context: Dictionary = builder.build_context(owner, FakeRegistry.new())
	var champion_owner := FakeBossOwner.new()
	champion_owner.ai_mode = "champion"
	var champion_context: Dictionary = builder.build_context(champion_owner, FakeRegistry.new())
	var mythic_owner := FakeBossOwner.new()
	mythic_owner.ai_mode = "mythic"
	var mythic_context: Dictionary = builder.build_context(mythic_owner, FakeRegistry.new())

	_expect_close(float(context.get("boss_league_movement_multiplier", 0.0)), 1.11, "limit boss movement multiplier should be locked at 1.11")
	_expect(float(champion_context.get("boss_movement_max_speed", 0.0)) < float(context.get("boss_movement_max_speed", 0.0)), "limit boss max speed should exceed champion")
	_expect(float(context.get("boss_movement_max_speed", 0.0)) < float(mythic_context.get("boss_movement_max_speed", 0.0)), "limit boss max speed should stay below mythic")
	_expect_close(float(context.get("boss_paddle_width", 0.0)), 107.0, "limit boss hitbox should widen to 107px")
	_expect_close(float(context.get("boss_dash_trigger_chance", 0.0)), 0.60, "limit dash trigger chance should be 60 percent")
	_expect(int(context.get("boss_dash_max_tokens", 0)) == 1, "limit should keep one dash token")
	_expect(not bool(context.get("boss_dash_chain_enabled", true)), "limit should not enable chained boss dash")
	_expect_close(float(context.get("boss_mistake_chance", 0.0)), 0.07, "limit mistake chance should be flat 7 percent")
	_expect_close(float(context.get("boss_mistake_error_min", 0.0)), 40.0, "limit mistake minimum error should be 40px")
	_expect_close(float(context.get("boss_mistake_error_max", 0.0)), 80.0, "limit mistake maximum error should be 80px")


func _verify_ball_context_limit_profile() -> void:
	var owner := FakeBallOwner.new()
	var ball_context: Dictionary = BallUpdateContext.new().build_update_context(owner)
	_expect_close(float(ball_context.get("boss_paddle_width", 0.0)), 107.0, "limit ball collision context should widen the boss hitbox")
	_expect(ball_context.get("boss_paddle_size", Vector2.ZERO) == Vector2(107.0, 40.0), "limit ball collision context should expose the widened boss paddle size")
	_expect_close(float(ball_context.get("max_ball_speed", 0.0)), 29.0, "limit ball context should use the 29px/frame ball speed cap")
	_expect_close(float(ball_context.get("impact_boost_max_ball_speed", 0.0)), 29.0, "limit impact boost cap should match the limit ball speed cap")

	var physics := BallPhysics.new()
	physics.configure_context(3, "limit league")
	var capped_velocity: Vector2 = physics.apply_companion_guard_bounce_speed(Vector2(0.0, -60.0))
	var champion_physics := BallPhysics.new()
	champion_physics.configure_context(3, "champion")
	var champion_capped: Vector2 = champion_physics.apply_companion_guard_bounce_speed(Vector2(0.0, -60.0))
	# The 60px/frame input is far above every cap, so the result must land
	# EXACTLY on the limit cap — a 27/28 regression would still pass a
	# <=29.001 ceiling check, so seal the exact lock value.
	_expect_close(capped_velocity.length(), 29.0, "limit companion guard bounce should land exactly on the 29px/frame cap")
	# Adversarial: a champion fallback (26 cap) would tie this value, so require limit to exceed champion.
	_expect(capped_velocity.length() > champion_capped.length() + 0.001, "limit companion guard bounce cap must exceed champion (proves the limit branch fires, not a silent champion fallback)")
	owner.free()


func _verify_boss_dash_cooldown_alias() -> void:
	var ai_state := BossAiState.new()
	_expect_close(float(ai_state.call("_get_boss_dash_league_cooldown_multiplier", "limit league")), 0.4, "limit dash recharge should use the advanced cooldown multiplier")


func _verify_character_select_four_league_layout() -> void:
	var screen := CharacterSelectScreen.new()
	var modes := ["junior", "champion", "limit", "mythic"]
	# 980~1300px desktop widths previously overlapped back (left) and the
	# floating confirm (right) — keep 1024/1280 in this sweep.
	for size_value in [
		Vector2(1920.0, 1080.0),
		Vector2(1280.0, 800.0),
		Vector2(1024.0, 768.0),
		Vector2(900.0, 700.0),
		Vector2(560.0, 900.0),
		Vector2(420.0, 700.0),
	]:
		var view_size: Vector2 = size_value
		var layout: Dictionary = screen.call("_action_bar_layout", view_size)
		var rects: Array[Rect2] = []
		for mode in modes:
			var rect: Rect2 = layout.get(mode, Rect2())
			rects.append(rect)
			_expect(rect.has_area(), "%s league tab should have a rect at %s" % [mode, _format_size(view_size)])
			_expect(rect.position.x >= 0.0 and rect.end.x <= view_size.x, "%s league tab should stay inside the view at %s" % [mode, _format_size(view_size)])
		for i in range(rects.size()):
			for j in range(i + 1, rects.size()):
				_expect(not rects[i].intersects(rects[j]), "league tabs should not overlap at %s" % _format_size(view_size))
		var confirm: Rect2 = layout.get("confirm", Rect2())
		var back: Rect2 = layout.get("back", Rect2())
		for rect in rects:
			_expect(not rect.intersects(confirm), "league tabs should not overlap confirm at %s" % _format_size(view_size))
			_expect(not rect.intersects(back), "league tabs should not overlap back at %s" % _format_size(view_size))
	_verify_league_cycle_input(screen)
	screen.free()


func _verify_league_cycle_input(screen: Object) -> void:
	# Keyboard/gamepad-only players cycle leagues via _cycle_league_mode
	# (TAB / shoulder buttons) — pointing devices must not be the only path.
	screen.set("selected_league_mode", "champion")
	screen.call("_cycle_league_mode", 1)
	_expect(str(screen.get("selected_league_mode")) == "limit", "league cycle forward from champion should reach limit")
	screen.call("_cycle_league_mode", 1)
	_expect(str(screen.get("selected_league_mode")) == "mythic", "league cycle forward from limit should reach mythic")
	screen.call("_cycle_league_mode", 1)
	_expect(str(screen.get("selected_league_mode")) == "junior", "league cycle should wrap from mythic to junior")
	screen.call("_cycle_league_mode", -1)
	_expect(str(screen.get("selected_league_mode")) == "mythic", "league cycle backward should wrap from junior to mythic")
	# Real input wiring: feed actual InputEvents through _unhandled_input —
	# direct _cycle_league_mode calls above would stay green even if the
	# TAB / shoulder-button branches were deleted.
	screen.set("selected_league_mode", "champion")
	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	tab_event.pressed = true
	screen.call("_unhandled_input", tab_event)
	_expect(str(screen.get("selected_league_mode")) == "limit", "TAB key event should cycle the league forward to limit")
	var shift_tab_event := InputEventKey.new()
	shift_tab_event.keycode = KEY_TAB
	shift_tab_event.pressed = true
	shift_tab_event.shift_pressed = true
	screen.call("_unhandled_input", shift_tab_event)
	_expect(str(screen.get("selected_league_mode")) == "champion", "Shift+TAB key event should cycle the league backward to champion")
	var next_shoulder_event := InputEventJoypadButton.new()
	next_shoulder_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	next_shoulder_event.pressed = true
	screen.call("_unhandled_input", next_shoulder_event)
	_expect(str(screen.get("selected_league_mode")) == "limit", "RB shoulder event should cycle the league forward to limit")
	var previous_shoulder_event := InputEventJoypadButton.new()
	previous_shoulder_event.button_index = JOY_BUTTON_LEFT_SHOULDER
	previous_shoulder_event.pressed = true
	screen.call("_unhandled_input", previous_shoulder_event)
	_expect(str(screen.get("selected_league_mode")) == "champion", "LB shoulder event should cycle the league backward to champion")


func _verify_debug_overlay_limit_cap() -> void:
	# F9 ball-speed debug overlay reads the STATIC config (pre-league-policy),
	# so it needs its own limit branch — seal the displayed cap per league.
	var overlay := BallSpeedDebugOverlay.new()
	_expect_close(float(overlay.call("_get_max_ball_speed", false, 1.0, "limit")), 29.0, "ball speed debug overlay should display the 29 cap for limit")
	_expect_close(float(overlay.call("_get_max_ball_speed", false, 1.0, "champion")), 26.0, "ball speed debug overlay should keep the 26 cap for champion")
	_expect_close(float(overlay.call("_get_max_ball_speed", false, 1.0, "mythic")), 32.0, "ball speed debug overlay should keep the 32 cap for mythic")


func _verify_lingpet_unlock_equivalence() -> void:
	var champion_entry := {"unlock": {"league_mode": "champion"}}
	var junior_entry := {"unlock": {"league_mode": "junior"}}
	_expect(LingpetCatalog._matches_unlock(champion_entry, {"league_mode": "limit"}), "limit should satisfy champion-equivalent lingpet unlock gates")
	_expect(not LingpetCatalog._matches_unlock(junior_entry, {"league_mode": "limit"}), "limit should not satisfy junior-only lingpet unlock gates")


func _verify_stage2_quake_parity() -> void:
	var stage2 := Stage2BossSkillState.new()
	var limit_range: Vector2i = stage2.call("_get_quake_rock_count_range", {"ai_mode": "limit"})
	var champion_range: Vector2i = stage2.call("_get_quake_rock_count_range", {"ai_mode": "champion"})
	var junior_range: Vector2i = stage2.call("_get_quake_rock_count_range", {"ai_mode": "junior"})
	_expect(limit_range == champion_range, "limit stage2 quake rock count should match champion (got %s vs %s)" % [limit_range, champion_range])
	_expect(limit_range == Vector2i(2, 4), "limit stage2 quake rock count should be 2~4 rocks (got %s)" % limit_range)
	_expect(limit_range != junior_range, "limit stage2 quake rock count must not fall through to the junior 1~2 range")


func _format_size(size: Vector2) -> String:
	return "%dx%d" % [int(size.x), int(size.y)]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) > 0.001:
		_failures.append("%s: got %.6f expected %.6f" % [message, actual, expected])
