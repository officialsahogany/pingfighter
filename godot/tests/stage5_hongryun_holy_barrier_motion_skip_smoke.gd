extends SceneTree

# 회귀: 홀리베리어(바닥 무적) 활성 중 홍련폭염(홍련 trail) 공이 무적 바닥을
# 무시하고 floor-miss로 새서 플레이어가 패배하던 버그.
#
# 원인: trail 공은 ball_hold로 skip_ball_motion_step=true라 normal step_motion()의
# check_holy_barrier()가 통째로 우회된다. skip 분기는 플레이어 가드와 floor-miss만
# 검사하고 홀리베리어를 검사하지 않았다.
#
# 수정: ball_update_controller가 skip 분기에서 플레이어 가드와 floor-miss 사이에
# _try_release_stage5_hongryun_holy_barrier 가드를 추가해, 베리어 띠에 닿은 trail
# 공을 위로 반사 + inferno 종료 + normal physics 복귀시킨다.

const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")

var _failures: Array[String] = []


class FakeHongryunState:
	extends RefCounted

	var inferno_active := true
	var hijack_reason := "hongryun_inferno_trail"
	var holy_barrier_calls := 0
	var floor_miss_calls := 0

	func should_skip_ball_motion_step() -> bool:
		return true

	func is_inferno_active() -> bool:
		return inferno_active

	func get_ball_hijack_reason() -> String:
		return hijack_reason

	func resolve_inferno_holy_barrier(_pos: Vector2, _deps: Dictionary = {}) -> Dictionary:
		holy_barrier_calls += 1
		inferno_active = false
		return {
			"skip_ball_motion_step": false,
			"stage5_hongryun_inferno_holy_barrier_block": true,
		}

	func resolve_inferno_player_miss(_pos: Vector2, _deps: Dictionary = {}) -> Dictionary:
		floor_miss_calls += 1
		inferno_active = false
		return {
			"skip_ball_motion_step": false,
			"stage5_hongryun_inferno_missed_player": true,
		}


class FakeActiveItemRuntime:
	extends RefCounted

	var holy_hit_count := 0
	var last_hit_pos := Vector2.ZERO

	func notify_holy_barrier_hit(impact_pos: Vector2) -> void:
		holy_hit_count += 1
		last_hit_pos = impact_pos


func _init() -> void:
	_verify_holy_barrier_catches_inferno_trail_ball()
	_verify_floor_miss_still_loses_without_barrier()
	_verify_resolve_inferno_holy_barrier_stops_real_state()

	if _failures.is_empty():
		print("stage5_hongryun_holy_barrier_motion_skip_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# 홀리베리어 활성 + trail 공이 베리어 띠에서 하강 → 패배 대신 위로 반사.
func _verify_holy_barrier_catches_inferno_trail_ball() -> void:
	var fake_state := FakeHongryunState.new()
	var fake_runtime := FakeActiveItemRuntime.new()
	var controller: Object = BallUpdateController.new()

	var context: Dictionary = _base_stage5_context()
	context["holy_barrier_active"] = true
	context["holy_barrier_y"] = 725.0
	context["holy_barrier_height"] = 20.0
	# 베리어 띠(725..745)에서 하강하는 공. 플레이어 패들과 X를 멀리 떼어
	# 플레이어 가드가 아니라 홀리베리어가 받아내도록 강제.
	context["ball_pos"] = Vector2(100.0, 730.0)
	context["ball_vel"] = Vector2(0.0, 12.0)
	context["player_pos"] = Vector2(600.0, 700.0)

	var deps: Dictionary = {
		"stage5_hongryun_state": fake_state,
		"active_item_runtime": fake_runtime,
	}

	var result: Dictionary = controller.update(1.0 / 60.0, context, deps)
	var snapshot: Dictionary = result.get("snapshot", {})

	_expect(str(result.get("score_event", "")) != "boss", "holy barrier should prevent the inferno trail floor-miss loss")
	_expect(fake_state.holy_barrier_calls == 1, "holy barrier catch should route through resolve_inferno_holy_barrier")
	_expect(fake_state.floor_miss_calls == 0, "holy barrier catch should pre-empt the floor-miss path")
	_expect(fake_runtime.holy_hit_count == 1, "holy barrier catch should notify the active item runtime for VFX")
	_expect(not bool(snapshot.get("skip_ball_motion_step", true)), "holy barrier catch should release the shared motion-skip flag")
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO).y < 0.0, "holy barrier catch should reflect the ball upward")


# 베리어 없으면 trail 공이 바닥에 닿을 때 정상적으로 패배(boss 득점)해야 한다.
func _verify_floor_miss_still_loses_without_barrier() -> void:
	var fake_state := FakeHongryunState.new()
	var controller: Object = BallUpdateController.new()

	var context: Dictionary = _base_stage5_context()
	context["holy_barrier_active"] = false
	# 공이 바닥(height 750)에 도달.
	context["ball_pos"] = Vector2(100.0, 742.0)
	context["ball_vel"] = Vector2(0.0, 12.0)
	context["player_pos"] = Vector2(600.0, 700.0)

	var deps: Dictionary = {
		"stage5_hongryun_state": fake_state,
	}

	var result: Dictionary = controller.update(1.0 / 60.0, context, deps)
	_expect(str(result.get("score_event", "")) == "boss", "without holy barrier the inferno trail floor-miss should still lose")
	_expect(fake_state.floor_miss_calls == 1, "floor-miss path should fire when no barrier is active")
	_expect(fake_state.holy_barrier_calls == 0, "holy barrier path should not fire when the barrier is inactive")


# 실제 Stage5HongryunState에서 resolve_inferno_holy_barrier가 inferno를 종료하는지.
func _verify_resolve_inferno_holy_barrier_stops_real_state() -> void:
	var state: Object = Stage5HongryunState.new()
	state.debug_force_inferno_ready()
	state.register_boss_paddle_contact(Vector2(0.0, 6.0), {}, {
		"current_stage": 5,
		"ball_pos": Vector2(380.0, 80.0),
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	})
	_expect(state.is_inferno_active(), "real state should start inferno on boss paddle contact when ready")

	var block: Dictionary = state.resolve_inferno_holy_barrier(Vector2(380.0, 725.0), {})
	_expect(not bool(block.get("skip_ball_motion_step", true)), "resolve_inferno_holy_barrier should release motion skip")
	_expect(bool(block.get("stage5_hongryun_inferno_holy_barrier_block", false)), "resolve_inferno_holy_barrier should flag the barrier block")
	_expect(not state.is_inferno_active(), "resolve_inferno_holy_barrier should stop the inferno")
	_expect(str(state.get_ball_hijack_reason()) == "", "resolve_inferno_holy_barrier should clear the ball hijack reason")
	_expect(not state.should_skip_ball_motion_step(), "resolve_inferno_holy_barrier should clear the motion-skip query")


func _base_stage5_context() -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"ball_active": true,
		"ball_size": 28.6,
		"skip_ball_motion_step": false,
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
		"vertical_bounce_count": 0,
		"ball_spin_strength": 0.0,
		"ball_spin_direction": 0,
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"special_gauge": 0.0,
		"player_speed": 0.0,
		"boss_vel": 0.0,
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(380.0, 60.0),
		"boss_paddle_size": Vector2(120.0, 40.0),
		"hitbox_padding": 5.0,
		"current_stage": 5,
		"width": 760.0,
		"height": 750.0,
		"max_ball_speed": 26.0,
		"power_smash_max_ball_speed": 35.0,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
