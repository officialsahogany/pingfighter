extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2RockRuntimeState := preload("res://scripts/stages/stage2/stage2_rock_runtime_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_visual_timer_update()
	_verify_water_target_helpers()
	_verify_background_delegates_rock_runtime_state()

	if _failures.is_empty():
		print("stage2_rock_runtime_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_visual_timer_update() -> void:
	var rock := {
		"flash": 0.3,
		"water_target_flash": 0.2,
		"phase": 1.0,
	}
	Stage2RockRuntimeState.update_visual_timers(rock, 0.1)
	_expect(is_equal_approx(float(rock.get("flash", 0.0)), 0.2), "rock runtime state should decay flash")
	_expect(is_equal_approx(float(rock.get("water_target_flash", 0.0)), 0.1), "rock runtime state should decay target flash")
	_expect(is_equal_approx(float(rock.get("phase", 0.0)), 1.4), "rock runtime state should advance phase")
	Stage2RockRuntimeState.update_visual_timers(rock, 1.0)
	_expect(is_equal_approx(float(rock.get("flash", 1.0)), 0.0), "rock runtime state should clamp flash to zero")
	_expect(is_equal_approx(float(rock.get("water_target_flash", 1.0)), 0.0), "rock runtime state should clamp target flash to zero")


func _verify_water_target_helpers() -> void:
	var rocks := [
		{"id": 10, "water_target_flash": 0.0},
		{"id": 20, "water_target_flash": 0.0},
	]
	_expect(Stage2RockRuntimeState.mark_water_target(rocks, 20), "rock runtime state should mark matching water target")
	_expect(is_equal_approx(float((rocks[1] as Dictionary).get("water_target_flash", 0.0)), 1.0), "rock runtime state should set target flash")
	_expect(not Stage2RockRuntimeState.mark_water_target(rocks, 99), "rock runtime state should report missing target ids")
	var rock: Dictionary = rocks[1]
	Stage2RockRuntimeState.clear_water_target_flash(rock)
	_expect(is_equal_approx(float(rock.get("water_target_flash", 1.0)), 0.0), "rock runtime state should clear target flash")


func _verify_background_delegates_rock_runtime_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2RockRuntimeState.update_visual_timers") >= 0,
		"Stage 2 background source should delegate rock visual timer updates"
	)
	_expect(
		source.find("Stage2RockRuntimeState.mark_water_target") >= 0,
		"Stage 2 background source should delegate water target marking"
	)
	_expect(
		source.find("Stage2RockRuntimeState.clear_water_target_flash") >= 0,
		"Stage 2 background source should delegate water target clearing"
	)

	var background := Stage2PillarBackground.new()
	background.rocks = [{"id": 5, "water_target_flash": 0.0}]
	background.water_cannon_target_id = 5
	Stage2RockRuntimeState.mark_water_target(background.rocks, background.water_cannon_target_id)
	_expect(
		is_equal_approx(float((background.rocks[0] as Dictionary).get("water_target_flash", 0.0)), 1.0),
		"Stage 2 background rock arrays should accept delegated water target marking"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
