extends SceneTree

const ViperJetpackState := preload("res://scripts/characters/viper_jetpack_state.gd")
const ViperPlayerController := preload("res://scripts/characters/viper_player_controller.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"jetpack_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name in ["chaos_spear", "blade_rush"]

	func get_skill_cost(skill_name: String) -> float:
		if skill_name == "chaos_spear":
			return 150.0
		if skill_name == "blade_rush":
			return 200.0
		return 0.0


class FakeSkillState:
	var triggered: Array = []

	func trigger_configured_cooldown(skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		triggered.append(skill_name)

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakeActiveItemRuntime:
	func is_player_control_locked() -> bool:
		return false

	func is_aipill_active() -> bool:
		return false


class FakeFeedback:
	func set_screen_shake(_duration: float, _amount: float) -> void:
		pass

	func max_screen_shake(_duration: float, _amount: float) -> void:
		pass


class FakeAudio:
	func sync_viper_jetpack_loop(_next_active: bool) -> void:
		pass

	func play_chaos_spear_windup() -> void:
		pass

	func stop_chaos_spear_windup() -> void:
		pass

	func play_chaos_spear_flying() -> void:
		pass

	func stop_chaos_spear_flying() -> void:
		pass

	func play_chaos_spear_impact() -> void:
		pass

	func stop_chaos_spear_impact() -> void:
		pass

	func play_chaos_spear_blackhole_loop() -> void:
		pass

	func stop_chaos_spear_blackhole_loop() -> void:
		pass

	func play_viper_blade_spin() -> void:
		pass

	func stop_viper_blade_spin() -> void:
		pass


class FakePerkState:
	func get_runtime_skill_level(_skill_id: String) -> int:
		return 0


func _init() -> void:
	var runtime := ViperSkillRuntime.new()
	var jetpack := ViperJetpackState.new()
	var controller := ViperPlayerController.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var deps := {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"active_item_runtime": FakeActiveItemRuntime.new(),
		"feedback": FakeFeedback.new(),
		"audio": FakeAudio.new(),
		"runtime_perk_state": FakePerkState.new(),
		"viper_skill_runtime": runtime,
		"viper_jetpack_state": jetpack,
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
		"player_floor_y": 700.0,
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(140.0, 250.0),
		"ball_vel": Vector2(5.0, 4.0),
		"special_gauge": 500.0,
	}
	var player_pos := Vector2(302.5, 700.0)

	var chaos_result: Dictionary = runtime.call(
		"_start_chaos_spear",
		player_pos,
		500.0,
		config,
		deps,
		Time.get_ticks_msec()
	)
	_expect(str(chaos_result.get("skill_name", "")) == "chaos_spear", "test setup should start Chaos Spear")
	config["special_gauge"] = float(chaos_result.get("special_gauge", 350.0))

	input.snapshot["jetpack_pressed"] = true
	var result: Dictionary = controller.update(1.0 / 60.0, 10, player_pos, 0.0, config, deps)
	player_pos = _get_vector2(result, "player_pos", player_pos)
	_expect(player_pos.y < 700.0, "Chaos Spear startup should preserve vertical jetpack hover")
	_expect(abs(player_pos.x - 302.5) < 0.01, "Chaos Spear startup should still lock X")
	_expect(bool(result.get("viper_jetpack_airborne", false)), "Chaos Spear hover should publish airborne metadata")

	for _i in range(46):
		var effect_context := config.duplicate(true)
		effect_context["player_pos"] = player_pos
		effect_context["player_paddle_size"] = Vector2(155.0, 50.0)
		runtime.update_effects(1.0, Time.get_ticks_msec(), effect_context, deps)
	_expect(str(runtime.get_snapshot().get("chaos_state", "")) == "flying", "Chaos Spear should leave startup before follow-up W input")

	input.snapshot["up_pressed"] = true
	result = controller.update(1.0 / 60.0, 11, player_pos, 0.0, config, deps)
	_expect(bool(result.get("activated", false)), "Air Blade should activate after Chaos Spear hover")
	_expect(str(result.get("skill_name", "")) == "blade_rush", "Chaos Spear follow-up W should route to Air Blade")
	_expect(skill_state.triggered.has("blade_rush"), "Air Blade follow-up should trigger blade_rush cooldown")

	print("chaos_spear_hover_combo_smoke: ok")
	quit(0)


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
