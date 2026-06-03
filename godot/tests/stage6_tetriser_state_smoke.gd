extends SceneTree

# Stage 6 테트리서 state 2a 스모크: 게이지(충전/cap/persist) + 낙하 테트로미노
# (스폰/조립→낙하→정착) + actor draw context 노출 검증.

const Stage6TetriserState := preload("res://scripts/stages/stage6/stage6_tetriser_state.gd")
const Stage6TetriserBossSkillHudRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd")

var _failures: Array[String] = []


class FakeThrowController:
	extends RefCounted
	var gas: Array = []
	var expl: Array = []
	func get_tear_gas_zones() -> Array:
		return gas
	func get_explosion_zones() -> Array:
		return expl


class FakeActiveItemRuntime:
	extends RefCounted
	var throw_controller


class FakeAudio:
	extends RefCounted
	var calls: Array = []
	func play_stage6_tetriser_break() -> void:
		calls.append("break")
	func play_stage6_tetriser_wall() -> void:
		calls.append("wall")
	func play_stage6_tetriser_super() -> void:
		calls.append("super")


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
	_test_dash_destroys_obstacle()
	_test_dash_destroys_super_tetromino()
	_test_smoke_and_explosion_destroy_obstacles()
	_test_super_activation_and_drain()
	_test_super_scale_and_tetromino()
	_test_cube_solve_clears_field()
	_test_cube_rebuild_reactivates()
	_test_super_laser_melts_cube()
	_test_boss_skill_hud()
	_test_sound_events()
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


func _test_dash_destroys_obstacle() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", false)
	var ctx := {
		"current_stage": 6, "ball_active": true, "waiting_for_serve": false,
		"dash_snapshot": {"active": true},
		"player_pos": Vector2(295.0, 695.0),
		"player_paddle_size": Vector2(60.0, 30.0),
	}
	state.update(0.05, ctx)
	_expect(state.debug_get_tetromino_count() == 0, "dash sweep destroys overlapping tetromino")


func _test_dash_destroys_super_tetromino() -> void:
	# 대시는 super 테트로도 파괴(공 반사 경로만 super 면역).
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", true)
	var ctx := {
		"current_stage": 6, "ball_active": true, "waiting_for_serve": false,
		"dash_snapshot": {"active": true},
		"player_pos": Vector2(295.0, 695.0),
		"player_paddle_size": Vector2(60.0, 30.0),
	}
	state.update(0.05, ctx)
	_expect(state.debug_get_tetromino_count() == 0, "dash destroys even super tetromino")


func _test_smoke_and_explosion_destroy_obstacles() -> void:
	# 연막(타원)이 테트로미노 파괴.
	var gas_tc := FakeThrowController.new()
	gas_tc.gas = [{"position": Vector2(310.0, 710.0), "radius": 120.0, "radius_x": 120.0, "opacity": 0.5}]
	var gas_air := FakeActiveItemRuntime.new()
	gas_air.throw_controller = gas_tc
	var gas_state: Object = Stage6TetriserState.new()
	gas_state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", false)
	gas_state.update(0.05, {"current_stage": 6, "ball_active": true, "waiting_for_serve": false}, {"active_item_runtime": gas_air})
	_expect(gas_state.debug_get_tetromino_count() == 0, "tear gas zone destroys obstacle in ellipse")

	# 폭발(원)이 가드 블록 파괴.
	var blast_tc := FakeThrowController.new()
	blast_tc.expl = [{"position": Vector2(310.0, 710.0), "radius": 120.0, "active": true}]
	var blast_air := FakeActiveItemRuntime.new()
	blast_air.throw_controller = blast_tc
	var blast_state: Object = Stage6TetriserState.new()
	blast_state.debug_spawn_guard_at(Vector2(300.0, 700.0), "left")
	blast_state.update(0.05, {"current_stage": 6, "ball_active": true, "waiting_for_serve": false}, {"active_item_runtime": blast_air})
	_expect(blast_state.debug_get_guard_count() == 0, "explosion zone destroys guard block in circle")


func _test_super_activation_and_drain() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_set_gauge(500.0)
	state.update(0.05, _active_context())
	_expect(state.debug_is_super_active(), "super activates at gauge 500")
	var g0: float = state.debug_get_gauge()
	state.update(0.1, _active_context())
	_expect(state.debug_get_gauge() < g0, "gauge drains (not charges) during super")
	state.debug_set_gauge(1.0)
	state.update(0.1, _active_context())
	_expect(not state.debug_is_super_active(), "super ends when gauge drains to 0")


func _test_super_scale_and_tetromino() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_set_gauge(500.0)
	for _i in range(20):
		state.update(0.05, _active_context())
	_expect(state.debug_get_super_scale() > 1.5, "boss scale lerps up during super (got %f)" % state.debug_get_super_scale())
	state.debug_force_spawn_tetromino()
	var list: Array = state.get_actor_draw_context().get("stage6_tetriser_tetrominoes", [])
	var found_big_super := false
	for t in list:
		if bool(t.get("super", false)) and float(t.get("cell_size", 20.0)) > 30.0:
			found_big_super = true
	_expect(found_big_super, "tetromino spawned during super is super + 1.7x cell (34px)")


func _test_cube_solve_clears_field() -> void:
	var state: Object = Stage6TetriserState.new()
	_expect(state.debug_is_cube_active(), "cube starts active")
	state.debug_spawn_tetromino_at(Vector2(300.0, 400.0), "O", false)
	state.debug_force_spawn_wall()
	_expect(state.debug_get_tetromino_count() + state.debug_get_wall_cell_count() > 0, "precondition: field has obstacles")
	state.debug_force_cube_solve_pending()
	for _i in range(25):   # 1.25s > solve delay 1.0s → 폭발
		state.update(0.05, _active_context())
	_expect(state.debug_get_tetromino_count() == 0, "cube explosion clears tetrominoes")
	_expect(state.debug_get_wall_cell_count() == 0, "cube explosion clears walls")
	_expect(state.debug_is_cube_rebuild() and not state.debug_is_cube_active(), "cube enters rebuild mode after explosion")


func _test_cube_rebuild_reactivates() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_force_cube_solve_pending()
	for _i in range(25):
		state.update(0.05, _active_context())
	_expect(state.debug_is_cube_rebuild(), "precondition: cube in rebuild")
	# 재조립 중 테트로미노 5개를 대시로 파괴 → 새 활성 큐브.
	var dash_ctx := {
		"current_stage": 6, "ball_active": true, "waiting_for_serve": false,
		"dash_snapshot": {"active": true},
		"player_pos": Vector2(295.0, 695.0),
		"player_paddle_size": Vector2(60.0, 30.0),
	}
	for _i in range(5):
		state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", false)
		state.update(0.05, dash_ctx)
	_expect(state.debug_is_cube_active(), "cube re-activates after 5 tetromino kills during rebuild")


func _test_super_laser_melts_cube() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 400.0), "O", false)
	state.debug_set_gauge(500.0)
	# 초인 발동 → 광선 충전(0.8s) → 발사 → 큐브 melt.
	for _i in range(25):   # 1.25s > 0.8s charge
		state.update(0.05, _active_context())
	_expect(state.debug_is_cube_rebuild(), "super laser melts cube into rebuild")
	_expect(state.debug_get_tetromino_count() == 0, "laser melt clears tetrominoes")
	_expect(state.debug_get_laser_state() == "firing", "laser is firing after charge (state=%s)" % state.debug_get_laser_state())
	_expect(state.debug_get_emp_count() > 0, "EMP ripple emitted on laser melt")


func _test_boss_skill_hud() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_set_gauge(40.0)   # tetro_drop(30) 가능, guard/wall(50) 불가
	var hud: Dictionary = state.get_hud_context()
	var skills: Array = hud.get("stage6_boss_skill_hud_skills", [])
	_expect(skills.size() == 4, "HUD exposes 4 boss skills")
	var by_id := {}
	for s in skills:
		by_id[str(s.get("id", ""))] = s
	_expect(bool(by_id.get("stage6_tetro_drop", {}).get("ready", false)), "tetro drop card ready at gauge>=30")
	_expect(not bool(by_id.get("stage6_guard", {}).get("ready", false)), "guard card not ready at gauge<50")

	var renderer: Object = Stage6TetriserBossSkillHudRenderer.new()
	var ctx: Dictionary = hud.duplicate(true)
	ctx["view_size"] = Vector2(920.0, 750.0)
	ctx["game_offset"] = Vector2(80.0, 0.0)
	ctx["game_size"] = Vector2(760.0, 750.0)
	ctx["current_stage"] = 6
	var layout: Dictionary = renderer.build_card_layout(ctx)
	_expect((layout.get("entries", []) as Array).size() == 4, "HUD layout builds 4 cards")
	_expect((layout.get("rects", []) as Array).size() == 4, "HUD layout builds 4 card rects")

	state.debug_set_gauge(500.0)
	state.update(0.05, _active_context())
	var found_super_active := false
	for s2 in state.get_hud_context().get("stage6_boss_skill_hud_skills", []):
		if str(s2.get("id", "")) == "stage6_super" and bool(s2.get("active", false)):
			found_super_active = true
	_expect(found_super_active, "super skill card shows active during 초인테트리서")


func _test_sound_events() -> void:
	# 초인 발동 → cry
	var super_audio := FakeAudio.new()
	var super_state: Object = Stage6TetriserState.new()
	super_state.debug_set_gauge(500.0)
	super_state.update(0.05, _active_context(), {"audio": super_audio})
	_expect(super_audio.calls.has("super"), "super activation plays roar/cry sound")

	# 테트로 벽 소환 → tetriswall
	var wall_audio := FakeAudio.new()
	var wall_state: Object = Stage6TetriserState.new()
	wall_state.debug_force_spawn_wall()
	wall_state.update(0.05, _active_context(), {"audio": wall_audio})
	_expect(wall_audio.calls.has("wall"), "wall spawn plays wall sound")

	# 대시 파괴 → tetrisbreak
	var break_audio := FakeAudio.new()
	var break_state: Object = Stage6TetriserState.new()
	break_state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", false)
	break_state.update(0.05, {
		"current_stage": 6, "ball_active": true, "waiting_for_serve": false,
		"dash_snapshot": {"active": true},
		"player_pos": Vector2(295.0, 695.0),
		"player_paddle_size": Vector2(60.0, 30.0),
	}, {"audio": break_audio})
	_expect(break_audio.calls.has("break"), "destroying a block plays break sound")


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
