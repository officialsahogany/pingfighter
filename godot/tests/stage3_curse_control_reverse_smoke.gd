extends SceneTree

const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const Stage3CurseControlInputProxy := preload("res://scripts/stages/stage3/stage3_curse_control_input_proxy.gd")


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


func _init() -> void:
	_verify_proxy_swaps_horizontal_input_only_while_cursed()
	_verify_cursed_movement_reverses_horizontal_direction()
	_verify_cursed_full_dash_reverses_direction()
	_verify_cursed_half_dash_reverses_direction()
	print("stage3_curse_control_reverse_smoke: ok")
	quit(0)


func _verify_proxy_swaps_horizontal_input_only_while_cursed() -> void:
	var input := FakeInputReader.new()
	input.snapshot = _input_snapshot(false, true, false)
	var stage_state := Stage3BossSkillState.new()
	var proxy: Object = Stage3CurseControlInputProxy.new().configure(input, stage_state)
	var raw_snapshot: Dictionary = proxy.get_snapshot()
	_expect(bool(raw_snapshot.get("right_pressed", false)), "inactive curse proxy should preserve right input")
	_expect(is_equal_approx(float(raw_snapshot.get("direction", 0.0)), 1.0), "inactive curse proxy should preserve right direction")
	stage_state.set("curse_reverse_timer", 1.0)
	var reversed_snapshot: Dictionary = proxy.get_snapshot()
	_expect(bool(reversed_snapshot.get("left_pressed", false)), "curse proxy should expose raw right input as left")
	_expect(not bool(reversed_snapshot.get("right_pressed", true)), "curse proxy should clear right when raw right becomes left")
	_expect(is_equal_approx(float(reversed_snapshot.get("direction", 0.0)), -1.0), "curse proxy should flip horizontal direction")
	_expect(int(reversed_snapshot.get("power_smash_direction", 0)) == -1, "curse proxy should flip direction metadata")


func _verify_cursed_movement_reverses_horizontal_direction() -> void:
	var controller := SmasherPlayerController.new()
	var input := FakeInputReader.new()
	input.snapshot = _input_snapshot(false, true, false)
	var stage_state := Stage3BossSkillState.new()
	stage_state.set("curse_reverse_timer", 1.0)
	var deps := _controller_deps(input, stage_state, SmasherDashState.new(), PlayerMovementState.new())
	var result: Dictionary = controller.update(1.0 / 60.0, 0, Vector2(300.0, 700.0), 0.0, _movement_config(), deps)
	_expect(float(result.get("player_speed", 0.0)) < 0.0, "cursed raw right movement should accelerate left")
	var pos: Vector2 = result.get("player_pos", Vector2.ZERO)
	_expect(pos.x < 300.0, "cursed raw right movement should move the player left")


func _verify_cursed_full_dash_reverses_direction() -> void:
	var dash_state := SmasherDashState.new()
	dash_state.reset_full(1)
	var result := _run_dash_input(dash_state, false)
	var dash_snapshot: Dictionary = dash_state.get_snapshot()
	_expect(bool(result.get("handled_by_dash", false)) or bool(dash_snapshot.get("active", false)), "cursed full dash input should be handled")
	_expect(bool(dash_snapshot.get("active", false)), "cursed full dash should start")
	_expect(not bool(dash_snapshot.get("is_half", true)), "cursed full dash should consume a full dash token")
	_expect(is_equal_approx(float(dash_snapshot.get("direction", 0.0)), -1.0), "cursed raw right full dash should dash left")


func _verify_cursed_half_dash_reverses_direction() -> void:
	var dash_state := SmasherDashState.new()
	dash_state.reset_full(1)
	dash_state.token_state.dash_tokens = 0
	dash_state.token_state.dash_charge_timer = 120.0
	var result := _run_dash_input(dash_state, true)
	var dash_snapshot: Dictionary = dash_state.get_snapshot()
	_expect(bool(result.get("handled_by_dash", false)) or bool(dash_snapshot.get("active", false)), "cursed half dash input should be handled")
	_expect(bool(dash_snapshot.get("active", false)), "cursed half dash should start")
	_expect(bool(dash_snapshot.get("is_half", false)), "cursed no-token dash should stay a half dash")
	_expect(is_equal_approx(float(dash_snapshot.get("direction", 0.0)), -1.0), "cursed raw right half dash should dash left")


func _run_dash_input(dash_state: Object, _expect_half: bool) -> Dictionary:
	var controller := SmasherPlayerController.new()
	var input := FakeInputReader.new()
	input.snapshot = _input_snapshot(false, true, true)
	var stage_state := Stage3BossSkillState.new()
	stage_state.set("curse_reverse_timer", 1.0)
	var deps := _controller_deps(input, stage_state, dash_state, PlayerMovementState.new())
	return controller.update(1.0 / 60.0, 0, Vector2(300.0, 700.0), 0.0, _movement_config(), deps)


func _controller_deps(input: Object, stage_state: Object, dash_state: Object, movement_state: Object) -> Dictionary:
	return {
		"input_reader": Stage3CurseControlInputProxy.new().configure(input, stage_state),
		"stage3_boss_skill_state": stage_state,
		"dash_state": dash_state,
		"movement_state": movement_state,
	}


func _movement_config() -> Dictionary:
	return {
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"paddle_max_speed": 6.0,
		"paddle_accel": 0.5,
		"paddle_decel": 0.5,
		"paddle_turn_decel": 1.0,
		"special_gauge": 0.0,
	}


func _input_snapshot(left_pressed: bool, right_pressed: bool, down_pressed: bool) -> Dictionary:
	var direction := 0.0
	if left_pressed:
		direction -= 1.0
	if right_pressed:
		direction += 1.0
	return {
		"left_pressed": left_pressed,
		"right_pressed": right_pressed,
		"down_pressed": down_pressed,
		"up_pressed": false,
		"action_pressed": false,
		"direction": direction,
		"power_smash_direction": -1 if left_pressed and not right_pressed else (1 if right_pressed and not left_pressed else 0),
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
