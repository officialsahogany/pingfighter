extends SceneTree

# Stage 6 테트리서 state 2a 스모크: 게이지(충전/cap/persist) + 낙하 테트로미노
# (스폰/조립→낙하→정착) + actor draw context 노출 검증.

const Stage6TetriserState := preload("res://scripts/stages/stage6/stage6_tetriser_state.gd")

var _failures: Array[String] = []


func _active_context() -> Dictionary:
	return {"current_stage": 6, "ball_active": true, "waiting_for_serve": false}


func _init() -> void:
	_test_gauge_charge_and_cap()
	_test_gauge_persist_across_reset()
	_test_pause_when_not_active()
	_test_tetromino_lifecycle()
	_test_actor_draw_context()
	_test_ball_reflects_and_destroys()
	_test_super_tetromino_immune_to_ball()
	_test_guard_scheduler_spawns()
	_test_guard_ball_collision()
	_test_wall_spawn_and_ball_destroys_cell()
	_test_wall_lifetime_clears()
	_test_wrong_stage_resets()

	if _failures.is_empty():
		print("stage6_tetriser_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_gauge_charge_and_cap() -> void:
	var state: Object = Stage6TetriserState.new()
	_expect(state.debug_get_gauge() == 0.0, "gauge starts at 0")
	state.update(0.1, _active_context())
	# 25/초 * 0.1초 = 2.5 (첫 업데이트는 스폰 타이머 5~10초라 스폰 없음).
	_expect(is_equal_approx(state.debug_get_gauge(), 2.5), "gauge charges 25/sec (got %f)" % state.debug_get_gauge())
	# cap 불변식: 장시간 충전해도 500 초과 금지.
	for _i in range(400):
		state.update(0.1, _active_context())
	_expect(state.debug_get_gauge() <= 500.0, "gauge never exceeds 500 (got %f)" % state.debug_get_gauge())
	_expect(state.debug_get_gauge() > 0.0, "gauge stays positive while charging")


func _test_gauge_persist_across_reset() -> void:
	var state: Object = Stage6TetriserState.new()
	state.update(0.1, _active_context())
	var charged: float = state.debug_get_gauge()
	_expect(charged > 0.0, "precondition: gauge charged")
	state.reset_round()
	_expect(is_equal_approx(state.debug_get_gauge(), charged), "reset_round preserves gauge (persist across rounds)")
	state.reset()
	_expect(state.debug_get_gauge() == 0.0, "reset zeroes gauge (stage-leave)")


func _test_pause_when_not_active() -> void:
	var state: Object = Stage6TetriserState.new()
	var waiting := {"current_stage": 6, "ball_active": false, "waiting_for_serve": true}
	state.update(0.1, waiting)
	_expect(state.debug_get_gauge() == 0.0, "gauge does not charge while waiting for serve")
	state.debug_force_spawn_tetromino()
	state.update(0.1, waiting)
	# 정지 중에는 조립이 진행되지 않아야 한다.
	_expect(state.debug_get_tetromino_states().has("assembling"), "tetromino stays assembling while paused")


func _test_tetromino_lifecycle() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_force_spawn_tetromino()
	_expect(state.debug_get_tetromino_count() == 1, "force spawn adds one tetromino")
	_expect(state.debug_get_tetromino_states() == ["assembling"], "spawned tetromino begins assembling")

	# 조립(1.0초) 통과 → 낙하.
	for _i in range(12):
		state.update(0.1, _active_context())
	_expect(state.debug_get_tetromino_states().has("falling"), "tetromino transitions to falling after assembly")

	# 충분히 낙하 → 바닥 정착.
	var settled := false
	for _i in range(200):
		state.update(0.1, _active_context())
		if state.debug_get_tetromino_states().has("settled"):
			settled = true
			break
	_expect(settled, "tetromino settles on the floor after falling")


func _test_actor_draw_context() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_force_spawn_tetromino()
	var ctx: Dictionary = state.get_actor_draw_context()
	_expect(float(ctx.get("stage6_tetriser_cell_size", 0.0)) == 20.0, "draw context exposes cell size 20")
	var list: Array = ctx.get("stage6_tetriser_tetrominoes", [])
	_expect(list.size() == 1, "draw context exposes the spawned tetromino")
	if list.size() == 1:
		var t: Dictionary = list[0]
		_expect(t.has("origin") and t["origin"] is Vector2, "tetromino draw entry has origin")
		_expect((t.get("cells", []) as Array).size() == 4, "tetromino draw entry has 4 cells")
		_expect(t.get("color") is Color, "tetromino draw entry has color")
	var ai_ctx: Dictionary = state.get_boss_ai_context()
	_expect(ai_ctx.has("stage6_tetriser_boss_gauge"), "boss ai context exposes gauge")


func _test_ball_reflects_and_destroys() -> void:
	var state: Object = Stage6TetriserState.new()
	# O 블록 (300,300): 셀 2x2 → x 300..340, y 300..340.
	state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", false)
	# 공이 위에서 아래로 진입(중심 좌표). 직전 프레임은 블록 위.
	var scene := {
		"ball_pos": Vector2(310.0, 305.0),
		"previous_ball_pos": Vector2(310.0, 280.0),
		"ball_vel": Vector2(1.0, 8.0),
	}
	var ctx := {"current_stage": 6, "ball_size": 20.0}
	var hit: bool = state.resolve_ball_collision(scene, ctx, {})
	_expect(hit, "ball overlapping a tetromino reports a collision")
	_expect(scene["ball_vel"].y < 0.0, "ball reflects upward after hitting from above (vy=%f)" % scene["ball_vel"].y)
	_expect(absf(scene["ball_vel"].y) >= 6.0, "vertical reflection enforces min speed (vy=%f)" % scene["ball_vel"].y)
	_expect(state.debug_get_tetromino_count() == 0, "normal tetromino destroyed by ball")
	_expect(state.debug_get_debris_count() == 1, "destroyed tetromino leaves a debris flash")


func _test_super_tetromino_immune_to_ball() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", true)  # super
	var scene := {
		"ball_pos": Vector2(310.0, 305.0),
		"previous_ball_pos": Vector2(310.0, 280.0),
		"ball_vel": Vector2(1.0, 8.0),
	}
	var ctx := {"current_stage": 6, "ball_size": 20.0}
	var hit: bool = state.resolve_ball_collision(scene, ctx, {})
	_expect(hit, "ball still bounces off a super tetromino")
	_expect(scene["ball_vel"].y < 0.0, "ball reflects off super tetromino too")
	_expect(state.debug_get_tetromino_count() == 1, "super tetromino is NOT destroyed by a normal ball hit (codex review §2.5)")


func _test_guard_scheduler_spawns() -> void:
	var state: Object = Stage6TetriserState.new()
	state.boss_gauge = 200.0   # 가드 전개에 충분한 게이지 시드
	for _i in range(220):      # ~22초 → 가드 타이머(7~15초) 적어도 1회 발동
		state.update(0.1, _active_context())
	var gc: int = state.debug_get_guard_count()
	_expect(gc >= 1 and gc <= 4, "guard scheduler spawns 1..4 guard blocks over time (got %d)" % gc)


func _test_guard_ball_collision() -> void:
	var state: Object = Stage6TetriserState.new()
	# 가드 바 (300,100): 4셀 가로 → x 300..380, y 100..120.
	state.debug_spawn_guard_at(Vector2(300.0, 100.0), "left")
	_expect(state.debug_get_guard_count() == 1, "precondition: one guard block")
	# 공이 아래에서 위로 가드에 진입.
	var scene := {
		"ball_pos": Vector2(310.0, 115.0),
		"previous_ball_pos": Vector2(310.0, 140.0),
		"ball_vel": Vector2(1.0, -8.0),
	}
	var ctx := {"current_stage": 6, "ball_size": 20.0}
	var hit: bool = state.resolve_ball_collision(scene, ctx, {})
	_expect(hit, "ball hits guard block")
	_expect(scene["ball_vel"].y > 0.0, "ball reflects downward after hitting guard from below (vy=%f)" % scene["ball_vel"].y)
	_expect(state.debug_get_guard_count() == 0, "guard block destroyed by ball")


func _test_wall_spawn_and_ball_destroys_cell() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_force_spawn_wall()
	# 좌우 각 10행 x 4열 = 80셀.
	_expect(state.debug_get_wall_cell_count() == 80, "wall spawns 80 cells (2 sides x 10 rows x 4 cols), got %d" % state.debug_get_wall_cell_count())

	# 단일 셀 충돌 → 셀 단위 파괴.
	var single: Object = Stage6TetriserState.new()
	single.debug_spawn_wall_cell_at(Vector2(0.0, 400.0))   # x 0..20, y 400..420
	_expect(single.debug_get_wall_cell_count() == 1, "precondition: one wall cell")
	var scene := {
		"ball_pos": Vector2(15.0, 410.0),
		"previous_ball_pos": Vector2(35.0, 410.0),   # 오른쪽에서 왼쪽으로 진입
		"ball_vel": Vector2(-5.0, 0.0),
	}
	var ctx := {"current_stage": 6, "ball_size": 20.0}
	var hit: bool = single.resolve_ball_collision(scene, ctx, {})
	_expect(hit, "ball hits wall cell")
	_expect(scene["ball_vel"].x > 0.0, "ball reflects rightward off wall edge (vx=%f)" % scene["ball_vel"].x)
	_expect(single.debug_get_wall_cell_count() == 0, "wall destroyed per-cell by ball")


func _test_wall_lifetime_clears() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_force_spawn_wall()
	_expect(state.debug_get_wall_cell_count() > 0, "precondition: wall present")
	for _i in range(70):   # ~7초 > 수명 6초
		state.update(0.1, _active_context())
	_expect(state.debug_get_wall_cell_count() == 0, "wall clears after its lifetime expires")


func _test_wrong_stage_resets() -> void:
	var state: Object = Stage6TetriserState.new()
	state.update(0.1, _active_context())
	state.debug_force_spawn_tetromino()
	_expect(state.debug_get_tetromino_count() == 1, "precondition: tetromino present")
	# 다른 스테이지 context로 업데이트되면 자기 상태를 비운다.
	state.update(0.1, {"current_stage": 1, "ball_active": true, "waiting_for_serve": false})
	_expect(state.debug_get_tetromino_count() == 0, "wrong-stage update clears tetrominoes")
	_expect(state.debug_get_gauge() == 0.0, "wrong-stage update clears gauge")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
