extends SceneTree

const SmasherMagnumGripState := preload("res://scripts/characters/smasher_magnum_grip_state.gd")
const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")

var _failures: Array[String] = []


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func _init(new_snapshot: Dictionary = {}) -> void:
		snapshot = new_snapshot.duplicate(true)

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeAudio:
	extends RefCounted

	var play_calls := 0
	var stop_calls := 0

	func play_magnum_grip() -> void:
		play_calls += 1

	func stop_magnum_grip() -> void:
		stop_calls += 1


func _init() -> void:
	_verify_skill_lock_blocks_hold_activation()
	_verify_skill_lock_force_releases_active_grip()
	_verify_unlocked_hold_still_activates()

	if _failures.is_empty():
		print("smasher_magnum_grip_skill_lock_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_skill_lock_blocks_hold_activation() -> void:
	var magnum_state: Object = SmasherMagnumGripState.new()
	_prime_held_input(magnum_state)
	var audio := FakeAudio.new()
	var result: Dictionary = _run_controller(
		magnum_state,
		{"left_pressed": true, "right_pressed": true},
		true,
		audio
	)

	_expect(not bool(magnum_state.is_active()), "player_skill_input_locked should block Magnum Grip activation from preserved left/right input")
	_expect(not bool(magnum_state.activated_this_frame), "locked Magnum Grip should not report an activation edge")
	_expect(is_equal_approx(float(result.get("special_gauge", -1.0)), 100.0), "locked Magnum Grip should not spend gauge")
	_expect(audio.play_calls == 0, "locked Magnum Grip should not play its loop")
	_expect(int(magnum_state.both_held_start_msec) == 0, "locked Magnum Grip should clear the held-input timer")


func _verify_skill_lock_force_releases_active_grip() -> void:
	var magnum_state: Object = SmasherMagnumGripState.new()
	magnum_state.active = true
	magnum_state.start_msec = int(Time.get_ticks_msec())
	magnum_state.keys_released = false
	magnum_state.both_held_start_msec = int(Time.get_ticks_msec()) - 120
	magnum_state.release_hit_pending = true
	magnum_state.release_hit_speed_cap_active = true
	magnum_state.particles.append({"pos": Vector2(10.0, 10.0)})
	var audio := FakeAudio.new()

	_run_controller(
		magnum_state,
		{"left_pressed": true, "right_pressed": true},
		true,
		audio
	)

	_expect(not bool(magnum_state.is_active()), "player_skill_input_locked should force-release an already active Magnum Grip")
	_expect(not bool(magnum_state.release_hit_pending), "force-release should clear pending release-hit caps")
	_expect(not bool(magnum_state.release_hit_speed_cap_active), "force-release should clear active release-hit caps")
	_expect(magnum_state.particles.is_empty(), "force-release should clear Magnum Grip particles")
	_expect(int(magnum_state.both_held_start_msec) == 0, "force-release should clear the hold timer")
	_expect(bool(magnum_state.keys_released), "force-release should reset Magnum Grip key latch state")
	_expect(audio.stop_calls == 1, "force-release should stop the Magnum Grip loop immediately")


func _verify_unlocked_hold_still_activates() -> void:
	var magnum_state: Object = SmasherMagnumGripState.new()
	_prime_held_input(magnum_state)
	var audio := FakeAudio.new()
	var result: Dictionary = _run_controller(
		magnum_state,
		{"left_pressed": true, "right_pressed": true},
		false,
		audio
	)

	_expect(bool(magnum_state.is_active()), "unlocked Magnum Grip should still activate from left+right hold")
	_expect(bool(magnum_state.activated_this_frame), "unlocked Magnum Grip should keep its activation edge")
	_expect(is_equal_approx(float(result.get("special_gauge", -1.0)), 30.0), "unlocked Magnum Grip should still spend exactly 70 gauge")
	_expect(audio.play_calls == 1, "unlocked Magnum Grip should still play its loop on activation")
	_expect(audio.stop_calls == 0, "unlocked Magnum Grip activation should not stop its loop")


func _run_controller(magnum_state: Object, input_snapshot: Dictionary, skill_input_locked: bool, audio: Object) -> Dictionary:
	var controller: Object = SmasherPlayerController.new()
	var deps: Dictionary = _build_deps(magnum_state, input_snapshot, audio)
	return controller.update(
		1.0 / 60.0,
		0,
		Vector2(300.0, 700.0),
		0.0,
		_base_config(skill_input_locked),
		deps
	)


func _build_deps(magnum_state: Object, input_snapshot: Dictionary, audio: Object) -> Dictionary:
	var skill_config: Object = SmasherSkillConfig.new()
	_expect(bool(skill_config.unlock_and_equip_skill("magnum_grip")), "test setup should equip Magnum Grip")
	return {
		"input_reader": FakeInputReader.new(input_snapshot),
		"skill_config": skill_config,
		"skill_state": SmasherSkillState.new(),
		"smasher_magnum_grip_state": magnum_state,
		"audio": audio,
	}


func _base_config(skill_input_locked: bool) -> Dictionary:
	return {
		"special_gauge": 100.0,
		"player_skill_input_locked": skill_input_locked,
		"horizontal_input_locked": false,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
	}


func _prime_held_input(magnum_state: Object) -> void:
	var now_msec := int(Time.get_ticks_msec())
	if now_msec < 400:
		OS.delay_msec(400 - now_msec)
	magnum_state.keys_released = true
	magnum_state.both_held_start_msec = int(Time.get_ticks_msec()) - 350


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
