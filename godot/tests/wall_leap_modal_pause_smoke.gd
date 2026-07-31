extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")

class ScoreboardProbe:
	extends RefCounted
	var active := true
	func is_active() -> bool: return active

class CallbacksProbe:
	extends RefCounted
	var fixture: Dictionary
	var effects := 0
	var player_ticks := 0
	func _init(next_fixture: Dictionary) -> void: fixture = next_fixture
	func update_effects(_delta: float) -> void: effects += 1
	func update_player_control(delta: float) -> void:
		player_ticks += 1
		fixture["input"].snapshot = {}
		var result: Dictionary = fixture["runtime"].try_activate_before_movement(delta, fixture["player_pos"], fixture["special_gauge"], fixture["context"], fixture["deps"])
		if result.has("player_pos"): fixture["player_pos"] = result["player_pos"]
	func noop(_delta: float = 0.0) -> void: pass
	func observe() -> void: pass

var _failures: Array[String] = []


func _init() -> void:
	var support := Support.new()
	var fixture: Dictionary = support.make_fixture()
	support.enter(fixture)
	support.advance_to_infiltrating(fixture)
	support.advance_frames(fixture, 16)
	support.route_once(fixture, {"secondary_action_pressed": true, "secondary_action_just_pressed": true})
	var before: float = float(fixture["runtime"].get_snapshot().get("wall_leap_raid_elapsed_seconds", -1.0))
	var scoreboard := ScoreboardProbe.new()
	var callbacks := CallbacksProbe.new(fixture)
	var flow := BattleFrameFlowController.new()
	var deps := {"scoreboard_state": scoreboard, "skill_orb_tooltip_active": false, "current_stage": 1, "round_state": fixture["round"]}
	var routes := {
		"update_effects": Callable(callbacks, "update_effects"),
		"update_player_control": Callable(callbacks, "update_player_control"),
		"update_weather": Callable(callbacks, "noop"),
		"update_mythic_items": Callable(callbacks, "noop"),
		"update_runtime_perk_resume": Callable(callbacks, "noop"),
		"update_active_items": Callable(callbacks, "noop"),
		"update_boss_ai": Callable(callbacks, "noop"),
		"update_ball": Callable(callbacks, "noop"),
		"update_lingpet": Callable(callbacks, "noop"),
		"observe_viper_wall_leap_ball_availability": Callable(callbacks, "observe"),
	}
	flow.update(0.25, deps, routes)
	var paused: float = float(fixture["runtime"].get_snapshot().get("wall_leap_raid_elapsed_seconds", -2.0))
	_expect(is_equal_approx(paused, before), "update_effects-only modal must freeze FUSE timer")
	_expect(callbacks.effects == 1 and callbacks.player_ticks == 0, "modal must tick effects without player state")
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "fuse", "modal must not force-return or cancel FUSE")
	scoreboard.active = false
	flow.update(0.10, deps, routes)
	var resumed: float = float(fixture["runtime"].get_snapshot().get("wall_leap_raid_elapsed_seconds", -3.0))
	_expect(resumed > paused and callbacks.player_ticks == 1, "closing modal must resume FUSE without softlock")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_modal_pause_smoke: ok")
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)
