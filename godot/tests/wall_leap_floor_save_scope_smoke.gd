extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	var support := Support.new()
	var fixture: Dictionary = support.make_fixture()
	support.enter(fixture)
	support.advance_to_infiltrating(fixture)
	var detector := BallMotionCollisionDetector.new()
	var base := {
		"player_pos": Vector2(300.0, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
		"player_guard_available": false,
	}
	var body_ball := Vector2(377.5, 700.0)
	_expect(detector.check_paddles(body_ball, Vector2(0.0, 9.0), 28.6, base).is_empty(), "(a) body paddle must be disabled")
	var thor: Dictionary = base.duplicate(true)
	thor.merge({"blacksmith_thor_shield_active": true, "blacksmith_thor_shield_rect": Rect2(350.0, 680.0, 70.0, 50.0)}, true)
	var thor_hit: Dictionary = detector.check_paddles(body_ball, Vector2(0.0, 9.0), 28.6, thor)
	_expect(bool(thor_hit.get("blacksmith_thor_shield_hit", false)), "(b) Thor shield rect must remain live")
	var clone: Dictionary = base.duplicate(true)
	clone["viper_dual_glitch_clone_rects"] = [{"rect": Rect2(350.0, 680.0, 70.0, 50.0), "index": 0, "side": 1}]
	var clone_hit: Dictionary = detector.check_paddles(body_ball, Vector2(0.0, 9.0), 28.6, clone)
	_expect(bool(clone_hit.get("viper_dual_glitch_clone_hit", false)), "(b) dual-glitch clone rect must remain live")
	var holy_hit: Dictionary = detector.check_holy_barrier(Vector2(377.5, 730.0), Vector2(0.0, 9.0), 28.6, {"holy_barrier_active": true, "holy_barrier_y": 725.0, "holy_barrier_height": 20.0, "width": 760.0, "player_guard_available": false})
	_expect(str(holy_hit.get("event", "")) == "holy_barrier", "(c) holy barrier floor save must remain live")
	_verify_lingpet_dispatch_and_body(fixture)
	fixture["runtime"].wall_leap_state.force_return("scope_end", fixture["deps"])
	support.advance_frames(fixture, 14)
	var restored: Dictionary = base.duplicate(true)
	restored["player_guard_available"] = fixture["runtime"].is_player_guard_available()
	_expect(str(detector.check_paddles(body_ball, Vector2(0.0, 9.0), 28.6, restored).get("event", "")) == "player_paddle", "(e) body-paddle priority must return after landing")
	_finish()


func _verify_lingpet_dispatch_and_body(fixture: Dictionary) -> void:
	var owner: Object = fixture["owner"]
	owner.values["lingpet_ring_dash_force_roll_pct"] = 0.0
	owner.values["player_pos"] = Vector2(560.0, 680.0)
	owner.values["player_paddle_width"] = 170.0
	owner.values["ball_active"] = true
	owner.values["ball_pos"] = Vector2(640.0, 640.0)
	owner.values["ball_vel"] = Vector2(0.0, 12.0)
	var runtime := LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "lingpet_ring_dash", fixture["registry"], 0, 5), "lingpet fixture must activate Maribo with Linkport")
	var initial: Vector2 = owner.values.get("lingpet_companion_pos", Vector2.ZERO)
	runtime.configure_companion_motion_for_tests(Vector2(120.0, initial.y), 2, 0.0, false)
	runtime.update(0.12, owner, fixture["registry"])
	_expect(runtime.is_ring_dash_active_for_tests(), "(d) Linkport must dispatch when infiltrating player cannot guard")
	_expect(int(runtime.get_ring_dash_trigger_count_for_tests()) == 1, "(d) Linkport must spend one real dispatch")
	runtime.update(0.05, owner, fixture["registry"])
	var companion_pos: Vector2 = owner.values.get("lingpet_companion_pos", Vector2.ZERO)
	owner.values["ball_pos"] = companion_pos
	owner.values["ball_vel"] = Vector2(0.0, 12.0)
	var before_contacts: int = int(owner.values.get("lingpet_companion_contact_count", 0))
	runtime.update(0.05, owner, fixture["registry"])
	_expect(int(owner.values.get("lingpet_companion_contact_count", 0)) > before_contacts, "(d) guardian body must actually contact after Linkport")
	_expect((owner.values.get("ball_vel", Vector2.ZERO) as Vector2).y < 0.0, "(d) guardian body must actually reflect the ball")


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_floor_save_scope_smoke: ok")
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)
