extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")

class FlowCallbacks:
	extends RefCounted
	var fixture: Dictionary
	func _init(next_fixture: Dictionary) -> void: fixture = next_fixture
	func update_effects(_delta: float) -> void: pass
	func update_player_control(_delta: float) -> void: pass
	func update_boss_ai(_delta: float) -> void: fixture["power"].active = true
	func update_ball(_delta: float) -> void: pass
	func observe() -> void:
		fixture["runtime"].observe_wall_leap_ball_availability_from_owner(fixture["owner"], fixture["registry"])
	func queue_redraw() -> void: pass

var _support := Support.new()
var _failures: Array[String] = []


func _init() -> void:
	_verify_precommit_and_fuse_cost_contracts()
	_verify_power_freeze_through_production_deps()
	_verify_previous_frame_commit_observation_a()
	_verify_boss_ai_same_frame_commit()
	_verify_real_boss_contact_observation_b()
	_finish()


func _verify_precommit_and_fuse_cost_contracts() -> void:
	var pre: Dictionary = _support.make_fixture()
	_support.enter(pre)
	_support.advance_to_infiltrating(pre)
	var before_pre: float = pre["special_gauge"]
	_observe_with_ball_controller(pre, {"skip_ball_motion_step": true})
	_expect(str(pre["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "precommit unavailable must force return at observation A")
	_expect(is_equal_approx(float(pre["special_gauge"]), before_pre), "precommit forced return must not spend branch gauge")

	var fuse: Dictionary = _support.make_fixture()
	_support.enter(fuse)
	_support.advance_to_infiltrating(fuse)
	_support.advance_frames(fuse, 16)
	_support.route_once(fuse, {"secondary_action_pressed": true, "secondary_action_just_pressed": true})
	var committed: float = fuse["special_gauge"]
	_expect(is_equal_approx(committed, 250.0), "FUSE must commit 150 before forced-return observation")
	_observe_with_ball_controller(fuse, {"skip_ball_motion_step": true})
	_expect(str(fuse["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "FUSE unavailable must force return")
	_expect(is_equal_approx(float(fuse["special_gauge"]), committed), "FUSE forced return must neither refund nor double-charge")


func _verify_power_freeze_through_production_deps() -> void:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	fixture["power"].active = true
	var deps: Dictionary = BallDependencyContext.new().build_update_deps(fixture["registry"], {
		"selected_character_type": "viper",
		"current_stage": 1,
		"stage1_boss_variant": "dalji",
	})
	_expect(deps.get("ball_power_freeze_state", null) == fixture["power"], "production ball deps must retain live power freeze for Viper")
	BallUpdateController.new().update(1.0 / 60.0, _ball_context(), deps)
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "production observation A must force-return on live power freeze")


func _verify_previous_frame_commit_observation_a() -> void:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	var stage3 := Stage3BossSkillState.new()
	stage3.set("psychoball_hitstop_timer", 0.05)
	fixture["deps"]["stage3_boss_skill_state"] = stage3
	_observe_with_ball_controller(fixture, {}, {"stage3_boss_skill_state": stage3})
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "previous-frame psychoball commit must be caught before ball early-return")


func _verify_boss_ai_same_frame_commit() -> void:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	var probe := FlowCallbacks.new(fixture)
	BattleFrameFlowController.new().update(1.0 / 60.0, {
		"current_stage": 1,
		"scoreboard_state": null,
		"skill_orb_tooltip_active": false,
		"power_state": fixture["power"],
		"round_state": fixture["round"],
	}, {
		"update_effects": Callable(probe, "update_effects"),
		"update_player_control": Callable(probe, "update_player_control"),
		"update_boss_ai": Callable(probe, "update_boss_ai"),
		"update_ball": Callable(probe, "update_ball"),
		"observe_viper_wall_leap_ball_availability": Callable(probe, "observe"),
		"queue_redraw": Callable(probe, "queue_redraw"),
	})
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "boss-AI commit must be observed in the same frame before ball update")


func _verify_real_boss_contact_observation_b() -> void:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	var stage3 := Stage3BossSkillState.new()
	stage3.set("psycho_cooldown", 0.0)
	stage3.set("tears_cooldown", 10.0)
	stage3.set("curse_cooldown", 10.0)
	var context: Dictionary = _ball_context()
	context["current_stage"] = 3
	context["ball_pos"] = Vector2(377.5, 75.0)
	context["ball_vel"] = Vector2(0.0, -8.0)
	var deps: Dictionary = fixture["deps"].duplicate()
	deps.merge({
		"stage3_boss_skill_state": stage3,
		"motion_stepper": BallMotionStepper.new(),
		"paddle_bounce_controller": PaddleBounceController.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
	}, true)
	BallUpdateController.new().update(1.0 / 60.0, context, deps)
	_expect(stage3.is_psychoball_hitstop_active(), "real boss paddle contact must call register_boss_hit and start psychoball")
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "post-step live observation B must see same-frame psychoball commit")


func _observe_with_ball_controller(fixture: Dictionary, overrides: Dictionary, extra_deps: Dictionary = {}) -> void:
	var context: Dictionary = _ball_context()
	context.merge(overrides, true)
	var deps: Dictionary = fixture["deps"].duplicate()
	deps.merge(extra_deps, true)
	BallUpdateController.new().update(1.0 / 60.0, context, deps)


func _ball_context() -> Dictionary:
	var result: Dictionary = _support.base_context()
	result.merge({
		"ball_pos": Vector2(377.5, 360.0),
		"ball_vel": Vector2(0.0, -8.0),
		"ball_size": 28.6,
		"current_stage": 1,
		"player_pos": Vector2(300.0, 680.0),
		"boss_collision_cooldown": 0.0,
		"player_collision_cooldown": 0.0,
	}, true)
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_forced_return_smoke: ok")
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)
