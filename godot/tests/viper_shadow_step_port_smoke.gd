extends SceneTree

const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeSkillConfig:
	var dark_blade_equipped := false

	func is_skill_equipped(skill_name: String) -> bool:
		if skill_name == "dark_blade":
			return dark_blade_equipped
		return skill_name in ["shadow_step", "marshal_kick"]

	func get_skill_cost(skill_name: String) -> float:
		if skill_name == "shadow_step":
			return 100.0
		if skill_name == "marshal_kick":
			return 80.0
		if skill_name == "dark_blade":
			return 150.0
		return 0.0


class FakeJetpackState:
	var airborne := false

	func is_airborne(_threshold: float = 0.0) -> bool:
		return airborne


class FakeSkillState:
	var triggered := ""

	func trigger_configured_cooldown(skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		triggered = skill_name

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakeOrbHud:
	var spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1


class FakeAudio:
	var backstep := 0
	var shadow_kick := 0
	var dash_start := 0
	var dash_delay_stopped := 0

	func play_viper_backstep() -> void:
		backstep += 1

	func play_viper_shadow_kick() -> void:
		shadow_kick += 1

	func play_dash_start(_is_half: bool) -> void:
		dash_start += 1

	func stop_dash_delay() -> void:
		dash_delay_stopped += 1


class FakeFeedback:
	var shakes := 0

	func set_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class FakePerkState:
	var gold := 0

	func get_runtime_skill_level(_skill_id: String) -> int:
		return 0

	func award_gold(amount: int) -> int:
		gold += max(0, amount)
		return gold


class FakeBallPhysics:
	func apply_dampened_multiplier(_current_speed: float, raw_multiplier: float) -> float:
		return raw_multiplier


class FakeRegistry:
	var instances := {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var left_hologram_sheet_value: Variant = runtime.call("_get_viper_hologram_attack_sheet", -1)
	_expect(left_hologram_sheet_value is Texture2D, "shadow step hologram should load Viper's left attack sheet")
	var left_hologram_sheet: Texture2D = left_hologram_sheet_value
	_expect(left_hologram_sheet.get_size() == Vector2(640.0, 320.0), "shadow step hologram should not use the old 250x120 Viper hit strip")
	var right_hologram_sheet_value: Variant = runtime.call("_get_viper_hologram_attack_sheet", 1)
	_expect(right_hologram_sheet_value is Texture2D, "shadow step hologram should load Viper's right attack sheet")
	var right_hologram_sheet: Texture2D = right_hologram_sheet_value
	_expect(right_hologram_sheet.get_size() == Vector2(640.0, 320.0), "shadow step right hologram should use the new 4x2 attack sheet")
	var first_region_value: Variant = runtime.call("_get_viper_hologram_attack_source_region", 0.0)
	_expect(first_region_value is Rect2, "shadow step hologram should expose a valid first source region")
	var first_region: Rect2 = first_region_value
	_expect(first_region == Rect2(0.0, 0.0, 160.0, 160.0), "shadow step hologram first frame should use a 160x160 attack cell")
	var last_region_value: Variant = runtime.call("_get_viper_hologram_attack_source_region", 1.0)
	_expect(last_region_value is Rect2, "shadow step hologram should expose a valid final source region")
	var last_region: Rect2 = last_region_value
	_expect(last_region == Rect2(480.0, 160.0, 160.0, 160.0), "shadow step hologram final frame should stay inside the 4x2 attack sheet")
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var orb := FakeOrbHud.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var perk_state := FakePerkState.new()
	var ball_physics := FakeBallPhysics.new()
	var deps := {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"orb_hud_state": orb,
		"audio": audio,
		"feedback": feedback,
		"runtime_perk_state": perk_state,
		"ball_physics": ball_physics,
	}
	var registry := FakeRegistry.new()
	registry.instances["viper_skill_config"] = skill_config
	registry.instances["viper_skill_state"] = skill_state
	var effects_context := BattleUpdateEffectsContext.new()
	var built_effect_deps: Dictionary = effects_context.build_deps(registry, 1)
	_expect(built_effect_deps.get("viper_skill_config", null) == skill_config, "effect-loop deps should include Viper skill config for chained skills")
	_expect(built_effect_deps.get("viper_skill_state", null) == skill_state, "effect-loop deps should include Viper skill state for chained cooldown checks")
	var config := {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(380.0, 45.0),
		"ball_pos": Vector2(472.5, 705.0),
		"ball_vel": Vector2(0.0, -8.0),
	}
	var player_pos := Vector2(420.0, 680.0)
	runtime.dash_origin_pos = Vector2(120.0, 680.0)
	runtime.dash_origin_valid = true
	runtime.dash_grace_frames = 36.0

	input.snapshot["down_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 300.0, config, deps)
	_expect(bool(result.get("activated", false)), "down edge during dash grace should activate shadow step")
	_expect(str(skill_state.triggered) == "shadow_step", "activation should trigger shadow step cooldown")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 200.0) < 0.01, "activation should spend 100 gauge")
	_expect(_get_vector2(result, "player_pos", Vector2.ZERO).x == 120.0, "activation should snap back to the dash origin")
	_expect(audio.backstep == 1 and audio.dash_start == 0, "activation should play the original backstep sound")
	_expect(orb.spins == 1, "activation should spin the orb HUD once")
	var snap: Dictionary = runtime.get_snapshot()
	_expect(bool(snap.get("shadow_hologram_active", false)), "activation should start the hologram kick window")
	_expect(bool(snap.get("shadow_wave_active", false)), "activation should launch the shadow wave")
	_expect(int(snap.get("shadow_hologram_kick_dir", 0)) == -1, "snapback to the left should kick left")

	var scene := {
		"ball_pos": Vector2(472.5, 705.0),
		"ball_vel": Vector2(0.0, -8.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}
	var motion_context: Dictionary = config.duplicate(true)
	motion_context.merge(scene, true)
	result = runtime.apply_shadow_step_ball_motion(1.0, scene, motion_context, deps)
	_expect(result.has("ball_vel"), "wave hit range should apply shadow step hit velocity")
	_expect(_get_vector2(result, "ball_vel", Vector2.ZERO).length() >= 10.0, "shadow kick should enforce the original minimum hit speed")
	_expect(audio.shadow_kick == 1, "ball hit should play the original shadowkick sound")
	_expect(perk_state.gold == 16, "ground shadow step hit should grant 16 skill gold")
	snap = runtime.get_snapshot()
	_expect(bool(snap.get("shadow_hit_consumed", false)), "shadow step hit should be consumed once")
	_expect(float(snap.get("shadow_curve_total", 0.0)) >= 10.0, "shadow step hit should start curved ball motion")
	_expect(float(snap.get("shadow_marshal_delay_frames", 0.0)) > 0.0, "shadow hit should schedule the marshal kick chain window")
	var effects_deps: Dictionary = deps.duplicate()
	effects_deps.erase("skill_config")
	effects_deps.erase("skill_state")
	effects_deps["viper_skill_config"] = skill_config
	effects_deps["viper_skill_state"] = skill_state
	for _i in range(18):
		runtime.update_effects(1.0, Time.get_ticks_msec(), motion_context, effects_deps)
	_expect(bool(runtime.get_snapshot().get("marshal_ready", false)), "marshal kick should become ready after the original first-chain delay with effect-loop Viper deps")
	_expect(not bool(runtime.get_snapshot().get("dark_blade_window", true)), "ground shadow step hit should NOT open Dark Blade window (Python airborne-only gate)")

	_test_airborne_shadow_step_opens_dark_blade_window()
	_test_whiff_does_not_open_marshal_via_paddle_hit()

	print("viper_shadow_step_port_smoke: ok")
	quit(0)


func _test_airborne_shadow_step_opens_dark_blade_window() -> void:
	# Python pingfighter.py:76338 equivalent — airborne shadow step ball hit opens dark_blade combo window.
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	skill_config.dark_blade_equipped = true
	var skill_state := FakeSkillState.new()
	var orb := FakeOrbHud.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var perk_state := FakePerkState.new()
	var ball_physics := FakeBallPhysics.new()
	var jetpack_state := FakeJetpackState.new()
	jetpack_state.airborne = true
	var deps := {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"orb_hud_state": orb,
		"audio": audio,
		"feedback": feedback,
		"runtime_perk_state": perk_state,
		"ball_physics": ball_physics,
		"viper_jetpack_state": jetpack_state,
	}
	var config := {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(380.0, 45.0),
		"ball_pos": Vector2(472.5, 410.0),
		"ball_vel": Vector2(0.0, -8.0),
	}
	var player_pos := Vector2(420.0, 400.0)
	runtime.dash_origin_pos = Vector2(120.0, 400.0)
	runtime.dash_origin_valid = true
	runtime.dash_grace_frames = 36.0
	input.snapshot["down_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 300.0, config, deps)
	_expect(bool(result.get("activated", false)), "airborne shadow step should still activate while jetpack-airborne")
	var scene := {
		"ball_pos": Vector2(472.5, 410.0),
		"ball_vel": Vector2(0.0, -8.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}
	var motion_context: Dictionary = config.duplicate(true)
	motion_context.merge(scene, true)
	result = runtime.apply_shadow_step_ball_motion(1.0, scene, motion_context, deps)
	_expect(result.has("ball_vel"), "airborne shadow step should hit the ball in wave range")
	var snap: Dictionary = runtime.get_snapshot()
	_expect(bool(snap.get("dark_blade_window", false)), "airborne shadow step hit should open Dark Blade combo window when equipped (Python parity)")
	_expect(float(snap.get("dark_blade_window_frames", 0.0)) > 0.0, "Dark Blade window frames should be primed after airborne shadow hit")


func _test_whiff_does_not_open_marshal_via_paddle_hit() -> void:
	# Regression (Python pingfighter.py:106225 parity): a shadow backstep that WHIFFS
	# (phantom-strike buff expires without a wave/hologram ball hit) must close the
	# paddle-hit fallback path. A later unrelated paddle bounce inside the 5s window
	# must NOT be treated as a shadow-step hit and must NOT open the Marshal Kick chain.
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var orb := FakeOrbHud.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var perk_state := FakePerkState.new()
	var ball_physics := FakeBallPhysics.new()
	var deps := {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"orb_hud_state": orb,
		"audio": audio,
		"feedback": feedback,
		"runtime_perk_state": perk_state,
		"ball_physics": ball_physics,
	}
	var config := {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(380.0, 45.0),
		# Ball parked high near the boss, far from the wave/hologram path → whiff.
		"ball_pos": Vector2(600.0, 150.0),
		"ball_vel": Vector2(0.0, -8.0),
	}
	var player_pos := Vector2(420.0, 680.0)
	runtime.dash_origin_pos = Vector2(120.0, 680.0)
	runtime.dash_origin_valid = true
	runtime.dash_grace_frames = 36.0
	input.snapshot["down_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 300.0, config, deps)
	_expect(bool(result.get("activated", false)), "whiff case: down edge during dash grace should activate shadow step")
	_expect(bool(runtime.get_snapshot().get("shadow_kick_ready", false)), "whiff case: activation should arm the paddle-hit fallback window")

	# Tick effects WITHOUT running any ball-motion hit (wave/hologram never catch the
	# high ball). After the 18-frame phantom-strike buff lapses on a whiff, the fix must
	# disarm the paddle-hit fallback so the shadow kick can no longer fire.
	var effects_context: Dictionary = config.duplicate(true)
	for _i in range(24):
		runtime.update_effects(1.0, Time.get_ticks_msec(), effects_context, deps)
	var snap: Dictionary = runtime.get_snapshot()
	_expect(not bool(snap.get("shadow_hit_consumed", true)), "whiff case: no ball hit should have been consumed")
	_expect(not bool(snap.get("shadow_kick_ready", true)), "whiff case: phantom-strike expiry must disarm the paddle-hit fallback (Python parity)")

	# A later ordinary paddle bounce (ball overlapping the paddle) must NOT register a
	# shadow-step hit now that the fallback is disarmed.
	var paddle_context: Dictionary = config.duplicate(true)
	paddle_context["player_pos"] = player_pos
	paddle_context["player_paddle_size"] = Vector2(155.0, 50.0)
	paddle_context["ball_pos"] = Vector2(497.5, 705.0)
	paddle_context["ball_impact_boost"] = 1.0
	var paddle_result: Dictionary = runtime.apply_shadow_step_paddle_hit(Vector2(0.0, -8.0), paddle_context, deps)
	_expect(paddle_result.is_empty(), "whiff case: a later paddle bounce must NOT be treated as a shadow-step hit")
	_expect(not bool(runtime.get_snapshot().get("shadow_hit_consumed", true)), "whiff case: paddle bounce must not consume a shadow hit")
	_expect(float(runtime.get_snapshot().get("shadow_marshal_delay_frames", 1.0)) <= 0.0, "whiff case: paddle bounce must not schedule the marshal chain delay")

	# Drive the chain window updater long enough to prove Marshal Kick never opens.
	for _i in range(30):
		runtime.update_effects(1.0, Time.get_ticks_msec(), effects_context, deps)
	_expect(not bool(runtime.get_snapshot().get("marshal_ready", false)), "whiff case: Marshal Kick chain window must stay closed after a whiff + paddle bounce")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
