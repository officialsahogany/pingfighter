extends SceneTree

const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const PaddleBounceRallyFeedbackRouter := preload("res://scripts/ball/paddle_bounce_rally_feedback_router.gd")
const ViperJetpackState := preload("res://scripts/characters/viper_jetpack_state.gd")
const ViperPlayerController := preload("res://scripts/characters/viper_player_controller.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")

var _failed := false


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"action_pressed": false,
		"jetpack_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeRoundState:
	var waiting := false
	var player_serves := true

	func is_waiting_for_serve() -> bool:
		return waiting

	func does_player_serve() -> bool:
		return player_serves


class FakeActiveItemRuntime:
	func is_player_control_locked() -> bool:
		return false

	func is_aipill_active() -> bool:
		return false


class FakeAudio:
	var play_count := 0
	var stop_count := 0
	var active := false
	var paddle_hit_count := 0

	func sync_viper_jetpack_loop(next_active: bool) -> void:
		active = next_active
		if next_active:
			play_count += 1
		else:
			stop_count += 1

	func play_paddle_hit(_source_x: float = 380.0) -> void:
		paddle_hit_count += 1


class FakeFeedback:
	var shakes := 0

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class FakeImpactEffects:
	var hit_particles := 0
	var explosions := 0

	func spawn_hit_particles(_pos: Vector2, _color: Color, _direction: Vector2, _intensity: float, _impact_speed: float) -> void:
		hit_particles += 1

	func create_energy_explosion(_pos: Vector2, _scale: float, _intensity: float) -> void:
		explosions += 1


class FakeBallEffects:
	var pulse_count := 0
	var last_kind := ""
	var last_intensity := 0.0

	func register_hit_pulse(_pos: Vector2, _velocity: Vector2, intensity: float = 0.0, kind: String = "hit") -> void:
		pulse_count += 1
		last_kind = kind
		last_intensity = intensity


class FakePerkState:
	var level := 0
	var gold := 0

	func get_runtime_skill_level(skill_id: String) -> int:
		if skill_id == "jetpack_enhance":
			return level
		return 0

	func award_gold(amount: int) -> int:
		gold += max(0, amount)
		return gold


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "chaos_spear"

	func get_skill_cost(skill_name: String) -> float:
		return 150.0 if skill_name == "chaos_spear" else 0.0


class FakeSkillState:
	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


func _init() -> void:
	var jetpack: Object = ViperJetpackState.new()
	var input := FakeInput.new()
	var round_state := FakeRoundState.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var impact_effects := FakeImpactEffects.new()
	var perk_state := FakePerkState.new()
	var viper_runtime := ViperSkillRuntime.new()
	var deps := {
		"input_reader": input,
		"round_state": round_state,
		"active_item_runtime": active_item_runtime,
		"audio": audio,
		"feedback": feedback,
		"impact_effects": impact_effects,
		"runtime_perk_state": perk_state,
		"viper_skill_runtime": viper_runtime,
		"viper_jetpack_state": jetpack,
	}
	var config := {
		"ball_active": true,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_floor_y": 700.0,
		"gauge_max": 500.0,
	}
	var player_pos := Vector2(302.5, 700.0)

	input.snapshot["jetpack_pressed"] = true
	var result: Dictionary = {}
	for _i in range(5):
		result = jetpack.update(1.0 / 60.0, player_pos, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
	_expect(player_pos.y < 700.0, "holding jetpack should raise Viper's actual player Y")
	_expect(round_state.player_serves, "test should keep player serve ownership true after serve")
	_expect(bool(result.get("viper_jetpack_airborne", false)), "Viper should report airborne while rising")
	_expect(audio.play_count == 1 and audio.active, "jetpack should start its loop audio once")
	_expect(jetpack.get_ball_collision_context().get("player_y", 700.0) < 700.0, "ball collision context should inherit airborne player_y")
	var sheet_jetpack: Object = ViperJetpackState.new()
	var sheet_deps: Dictionary = deps.duplicate()
	sheet_deps["viper_jetpack_state"] = sheet_jetpack
	var sheet_config: Dictionary = config.duplicate()
	sheet_config["viper_jetpack_hover_sheet_fx"] = true
	var sheet_pos := Vector2(302.5, 700.0)
	for _sheet_i in range(5):
		var sheet_result: Dictionary = sheet_jetpack.update(1.0 / 60.0, sheet_pos, sheet_config, sheet_deps)
		sheet_pos = _get_vector2(sheet_result, "player_pos", sheet_pos)
	_expect(bool(sheet_jetpack.get_actor_draw_context().get("viper_jetpack_airborne", false)), "hover-sheet jetpack path should keep airborne gameplay state")
	_expect(_as_array(sheet_jetpack.get_actor_draw_context().get("viper_jetpack_particles", [])).is_empty(), "hover-sheet jetpack path should skip invisible procedural particles")
	jetpack.offset_y = -200.0
	_expect(abs(float(jetpack.get_movement_bonus_multiplier()) - 3.15) < 0.001, "max-height jetpack should apply the original 3.15x movement multiplier")
	var collision_context: Dictionary = jetpack.get_ball_collision_context(Vector2(420.0, 700.0), Vector2(155.0, 50.0))
	_expect(abs(_get_vector2(collision_context, "player_pos", Vector2.ZERO).x - 420.0) < 0.01, "ball collision context should keep the latest moved player X")
	jetpack.active = true
	jetpack.offset_y = -5.0
	var low_air_result: Dictionary = jetpack.apply_air_strike_post_hit(
		Vector2(0.0, -10.0),
		100.0,
		150.0,
		{"ball_pos": Vector2(320.0, 690.0), "gauge_max": 500.0},
		deps
	)
	_expect(abs(_get_vector2(low_air_result, "ball_vel", Vector2.ZERO).length() - 10.0) < 0.01, "sub-threshold jetpack height should not trigger Air Strike speed")
	_expect(abs(float(low_air_result.get("special_gauge", 0.0)) - 150.0) < 0.01, "sub-threshold jetpack height should not add Air Strike gauge")
	_expect(perk_state.gold == 0, "sub-threshold jetpack height should not grant Air Strike gold")

	input.snapshot["jetpack_pressed"] = false
	for _i in range(90):
		result = jetpack.update(1.0 / 60.0, player_pos, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
	_expect(abs(player_pos.y - 700.0) < 0.01, "released jetpack should fall back to the floor")
	_expect(not bool(jetpack.is_airborne(0.1)), "landing should clear airborne state")
	_expect(audio.stop_count >= 1 and not audio.active, "landing/release should stop loop audio")

	perk_state.level = 3
	_expect(abs(float(jetpack.get_max_hold_frames(deps)) - 360.0) < 0.01, "S3 ceiling should preserve the legacy double max hold")
	perk_state.level = 5
	_expect(abs(float(jetpack.get_max_hold_frames(deps)) - 432.0) < 0.01, "S3 Lv.5 should equal legacy Lv.7")
	_expect(int(jetpack.get_jetpack_enhance_gauge_bonus_pct(deps)) == 50, "S3 Lv.5 airborne gauge bonus should equal legacy Lv.7 at 50%")

	perk_state.level = 3
	jetpack.offset_y = -100.0
	var air_result: Dictionary = jetpack.apply_air_strike_post_hit(
		Vector2(0.0, -10.0),
		100.0,
		150.0,
		{"ball_pos": Vector2(320.0, 580.0), "gauge_max": 500.0},
		deps
	)
	_expect(abs(_get_vector2(air_result, "ball_vel", Vector2.ZERO).length() - 11.5) < 0.01, "Air Strike should apply the 1.15x speed bonus")
	_expect(abs(float(air_result.get("special_gauge", 0.0)) - 171.0) < 0.01, "Air Strike should add height bonus before jetpack_enhance gauge scaling")
	_expect(perk_state.gold == 3 and int(air_result.get("runtime_perk_gold", 0)) == 3, "Air Strike should grant 3 perk gold")
	_expect(feedback.shakes >= 1 and impact_effects.hit_particles >= 1, "Air Strike should spawn hit feedback")
	_expect(float(jetpack.get_actor_draw_context().get("viper_air_strike_text_timer", 0.0)) <= 0.0, "Air Strike should keep bonus-gauge text hidden")
	var pulse_jetpack: Object = ViperJetpackState.new()
	pulse_jetpack.offset_y = -100.0
	var pulse_impact := FakeImpactEffects.new()
	var pulse_ball := FakeBallEffects.new()
	var pulse_deps: Dictionary = deps.duplicate()
	pulse_deps["impact_effects"] = pulse_impact
	pulse_deps["ball_effects"] = pulse_ball
	var pulse_air_result: Dictionary = pulse_jetpack.apply_air_strike_post_hit(
		Vector2(0.0, -10.0),
		100.0,
		150.0,
		{"ball_pos": Vector2(320.0, 580.0), "gauge_max": 500.0},
		pulse_deps
	)
	_expect(str(pulse_air_result.get("paddle_hit_pulse_kind", "")) == "viper_air_strike", "Air Strike should expose a single merged hit-pulse kind")
	_expect(float(pulse_air_result.get("paddle_hit_pulse_intensity", 0.0)) > 0.8, "Air Strike should expose a strong merged hit-pulse intensity")
	_expect(pulse_impact.hit_particles == 0 and pulse_impact.explosions == 0, "Air Strike should not spawn duplicate impact effects when ball pulse FX is available")
	var pulse_router := PaddleBounceRallyFeedbackRouter.new()
	pulse_router.register(
		Vector2(320.0, 580.0),
		_get_vector2(pulse_air_result, "ball_vel", Vector2.ZERO),
		true,
		false,
		pulse_deps,
		pulse_air_result
	)
	_expect(pulse_ball.pulse_count == 1, "Air Strike merged pulse should route through the normal rally feedback pulse")
	_expect(pulse_ball.last_kind == "viper_air_strike", "Air Strike merged pulse should preserve its Viper pulse kind")

	var controller := ViperPlayerController.new()
	var controller_deps := deps.duplicate()
	controller_deps["movement_state"] = PlayerMovementState.new()
	input.snapshot["jetpack_pressed"] = true
	input.snapshot["direction"] = 1.0
	input.snapshot["right_pressed"] = true
	jetpack.reset_round(deps)
	jetpack.offset_y = -100.0
	result = controller.update(1.0 / 60.0, 10, Vector2(302.5, 700.0), 0.0, config, controller_deps)
	_expect(int(result.get("frame_counter", 0)) == 11, "Viper controller should still advance frame counter")
	var controller_pos: Vector2 = _get_vector2(result, "player_pos", Vector2.ZERO)
	_expect(controller_pos.y < 700.0, "Viper controller should apply jetpack Y after horizontal movement, got %s result=%s" % [str(controller_pos), str(result)])
	_expect(float(result.get("player_speed", 0.0)) > 0.70, "Viper controller should boost airborne horizontal acceleration")
	input.snapshot["direction"] = 0.0
	input.snapshot["right_pressed"] = false

	var chaos_deps := {
		"skill_config": FakeSkillConfig.new(),
		"skill_state": FakeSkillState.new(),
		"round_state": round_state,
		"viper_jetpack_state": jetpack,
	}
	jetpack.offset_y = -32.0
	var can_chaos: bool = bool(viper_runtime.call("_can_start_chaos_spear", 500.0, config, chaos_deps, Time.get_ticks_msec()))
	_expect(not can_chaos, "Chaos Spear should be gated while Viper is airborne")

	if _failed:
		return
	print("viper_jetpack_port_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
	quit(1)


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
