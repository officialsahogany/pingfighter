extends SceneTree

# Stage 6 테트리서 state 2a 스모크: 게이지(충전/cap/persist) + 낙하 테트로미노
# (스폰/조립→낙하→정착) + actor draw context 노출 검증.

const Stage6TetriserState := preload("res://scripts/stages/stage6/stage6_tetriser_state.gd")
const Stage6TetriserBossSkillHudRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd")
const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const STAGE6_PILLAR_SCENE_DRAWER_PATH := "res://scripts/stages/stage6/stage6_tetriser_pillar_scene_drawer.gd"

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


class FakeStatusEffectState:
	extends RefCounted
	var calls: Array = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		calls.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data,
			"source": source,
		})
		return {}


class FakeMovementState:
	extends RefCounted
	var calls: Array = []

	func start_knockback(velocity: float, frames: float, decay: float, interrupt_dash: bool = false, stun_locked: bool = false) -> void:
		calls.append({
			"velocity": velocity,
			"frames": frames,
			"decay": decay,
			"interrupt_dash": interrupt_dash,
			"stun_locked": stun_locked,
		})


class FakeCleanseState:
	extends RefCounted
	var immune := false

	func is_immune() -> bool:
		return immune


class FakeMythicItemRuntime:
	extends RefCounted
	var should_consume_celestial_armor := false
	var calls: Array = []

	func try_consume_celestial_armor_immunity(source: String, effect_type: String, deps: Dictionary) -> bool:
		calls.append({
			"source": source,
			"effect_type": effect_type,
			"context": deps.get("context", {}),
			"has_owner": deps.has("owner"),
		})
		return should_consume_celestial_armor


class FakeScoreState:
	extends RefCounted
	var player_score := 0
	var boss_score := 0
	var player_in_danger := false

	func get_snapshot() -> Dictionary:
		return {
			"player_score": player_score,
			"boss_score": boss_score,
		}

	func is_player_in_danger() -> bool:
		return player_in_danger


func _active_context() -> Dictionary:
	return {"current_stage": 6, "ball_active": true, "waiting_for_serve": false}


func _init() -> void:
	_test_gauge_charge_and_cap()
	_test_gauge_persist_across_reset()
	_test_pause_when_not_active()
	_test_tetromino_lifecycle()
	_test_falling_tetromino_uses_discrete_step_drop()
	_test_falling_rotation_uses_spawn_budget()
	_test_falling_rotation_rejects_wall_overlap()
	_test_tetromino_spawn_uses_boss_center_and_legacy_shape_pool()
	_test_tetromino_scheduler_passes_boss_context()
	_test_settled_tetromino_evaporates_after_lifetime()
	_test_actor_draw_context()
	_test_ball_reflects_and_destroys()
	_test_boss_serve_penetrates_tetromino_and_wall()
	_test_player_rally_after_serve_collides_with_tetromino()
	_test_power_smash_destroys_tetromino_and_wall_without_reflection()
	_test_super_tetromino_immune_to_ball()
	_test_super_tetromino_explodes_on_landing()
	_test_super_tetromino_explosion_radius_gate()
	_test_super_tetromino_explosion_respects_player_immunity()
	_test_guard_scheduler_spawns()
	_test_guard_ball_collision()
	_test_wall_spawn_uses_tetromino_pieces_and_collision_gate()
	_test_wall_position_preserves_original_top_anchor()
	_test_wall_lifetime_evaporates_piecewise()
	_test_dash_destroys_obstacle()
	_test_dash_destroys_super_tetromino()
	_test_smoke_and_explosion_destroy_obstacles()
	_test_super_activation_and_drain()
	_test_super_scale_and_tetromino()
	_test_cube_solve_clears_field()
	_test_cube_rebuild_reactivates()
	_test_natural_evaporation_does_not_rebuild_cube()
	_test_super_laser_melts_cube()
	_test_crystal_shield_score_schedules_and_starts()
	_test_crystal_shield_collision_and_reset()
	_test_stage6_score_context_reaches_crystal_shield()
	_test_boss_skill_hud()
	_test_pillar_scene_drawer_routes_background()
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


func _test_falling_tetromino_uses_discrete_step_drop() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", false)
	var start: Vector2 = state.debug_get_first_tetromino_origin()
	state.update(0.100, _active_context())
	state.update(0.009, _active_context())
	_expect(state.debug_get_first_tetromino_origin() == start, "falling tetromino does not slide before the 110ms step")
	state.update(0.001, _active_context())
	_expect(is_equal_approx(state.debug_get_first_tetromino_origin().y, start.y + 20.0), "falling tetromino drops exactly one 20px cell at 110ms")
	_advance_fall_steps(state, 1)
	_expect(is_equal_approx(state.debug_get_first_tetromino_origin().y, start.y + 40.0), "falling tetromino drops exactly two cells at 220ms")


func _test_falling_rotation_uses_spawn_budget() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 100.0), "L", false)
	state.debug_configure_first_tetromino_motion({
		"rotate_times_remaining": 1,
		"rotate_start_delay": 0.5,
		"rotate_interval_sec": 0.2,
		"rotate_timer_sec": 0.0,
		"rotate_dir": 1,
		"drift_cells_remaining": 0,
	})
	var initial_cells: String = _cells_signature(state.debug_get_first_tetromino_cells())
	for _i in range(4):
		_advance_fall_steps(state, 1)
	_expect(_cells_signature(state.debug_get_first_tetromino_cells()) == initial_cells, "rotation waits for its falling-start delay")
	_advance_fall_steps(state, 1)
	var rotated_cells: String = _cells_signature(state.debug_get_first_tetromino_cells())
	_expect(rotated_cells != initial_cells, "rotation consumes the once-at-spawn budget after the delay")
	_expect(int(state.debug_get_first_tetromino_motion().get("rotate_times_remaining", -1)) == 0, "rotation budget is consumed once")
	_advance_fall_steps(state, 5)
	_expect(_cells_signature(state.debug_get_first_tetromino_cells()) == rotated_cells, "rotation does not reroll every 0.45 seconds after its budget is spent")


func _test_falling_rotation_rejects_wall_overlap() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_wall_cell_at(Vector2(330.0, 90.0))
	state.debug_spawn_tetromino_at(Vector2(300.0, 100.0), "I", false)
	state.debug_configure_first_tetromino_motion({
		"rotate_times_remaining": 1,
		"rotate_start_delay": 0.0,
		"rotate_interval_sec": 0.110,
		"rotate_timer_sec": 0.0,
		"rotate_dir": 1,
		"drift_cells_remaining": 0,
	})
	var initial_cells: String = _cells_signature(state.debug_get_first_tetromino_cells())
	_advance_fall_steps(state, 1)
	_expect(_cells_signature(state.debug_get_first_tetromino_cells()) == initial_cells, "rotation is rejected when the rotated cells would overlap a wall/installed cell")
	_expect(int(state.debug_get_first_tetromino_motion().get("rotate_times_remaining", 0)) == 1, "rejected rotation does not consume the remaining budget")
	_expect(is_equal_approx(state.debug_get_first_tetromino_origin().y, 120.0), "rejected rotation still allows the normal 20px fall step")


func _test_tetromino_spawn_uses_boss_center_and_legacy_shape_pool() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_set_rng_seed(24680)
	var ctx := _active_context()
	ctx["boss_pos"] = Vector2(250.0, 45.0)
	ctx["boss_paddle_size"] = Vector2(160.0, 40.0)
	var boss_center_x: float = 330.0
	var allowed := {"T": true, "L": true, "Z": true, "I": true, "O": true}
	for _i in range(60):
		state.debug_force_spawn_tetromino(ctx)
	var spawned: Array = state.get_actor_draw_context().get("stage6_tetriser_tetrominoes", [])
	_expect(spawned.size() == 60, "precondition: debug force spawned tetrominoes")
	for entry in spawned:
		var shape := str((entry as Dictionary).get("shape", ""))
		_expect(allowed.has(shape), "falling tetromino spawn uses only T/L/Z/I/O shapes (got %s)" % shape)
		_expect(is_equal_approx(_tetromino_center_x(entry), boss_center_x), "falling tetromino spawn centers on boss paddle x")


func _test_tetromino_scheduler_passes_boss_context() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_set_rng_seed(13579)
	state.debug_set_gauge(40.0)
	state.debug_set_spawn_timer(0.0)
	var ctx := _active_context()
	ctx["boss_pos"] = Vector2(420.0, 45.0)
	ctx["boss_paddle_size"] = Vector2(120.0, 40.0)
	state.update(0.05, ctx)
	var spawned: Array = state.get_actor_draw_context().get("stage6_tetriser_tetrominoes", [])
	_expect(spawned.size() == 1, "live scheduler spawns one tetromino when the timer and gauge are ready")
	if spawned.size() == 1:
		_expect(is_equal_approx(_tetromino_center_x(spawned[0]), 480.0), "live scheduler passes boss context into tetromino spawn")


func _test_settled_tetromino_evaporates_after_lifetime() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", false)
	var settled := false
	for _i in range(6):
		state.update(0.1, _active_context())
		if state.debug_get_tetromino_states().has("settled"):
			settled = true
			break
	_expect(settled, "normal tetromino settles before its expiry timer starts")

	var evaporating := false
	for _i in range(18):
		state.update(0.1, _active_context())
		if state.debug_get_tetromino_states().has("evaporating"):
			evaporating = true
			break
	_expect(evaporating, "settled tetromino enters evaporation after 1.5 seconds")
	for _i in range(12):
		state.update(0.1, _active_context())
	_expect(state.debug_get_tetromino_count() == 0, "evaporating tetromino removes itself cell-by-cell")


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


func _test_boss_serve_penetrates_tetromino_and_wall() -> void:
	var tetro_state: Object = Stage6TetriserState.new()
	tetro_state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", false)
	var tetro_scene := {
		"ball_pos": Vector2(310.0, 305.0),
		"previous_ball_pos": Vector2(310.0, 280.0),
		"ball_vel": Vector2(1.0, 8.0),
	}
	var serve_ctx := {"current_stage": 6, "ball_size": 20.0, "ball_rally_count": 0, "last_hit_by": "boss"}
	var tetro_hit: bool = tetro_state.resolve_ball_collision(tetro_scene, serve_ctx, {})
	_expect(not tetro_hit, "boss serve at rally 0 penetrates falling tetrominoes")
	_expect(tetro_state.debug_get_tetromino_count() == 1, "boss serve penetration does not destroy the tetromino")
	_expect((tetro_scene["ball_vel"] as Vector2) == Vector2(1.0, 8.0), "boss serve penetration does not reflect the ball")

	var wall_state: Object = Stage6TetriserState.new()
	wall_state.debug_spawn_wall_cell_at(Vector2(0.0, 400.0))
	var wall_scene := _wall_hit_scene(Vector2(0.0, 400.0))
	var wall_hit: bool = wall_state.resolve_ball_collision(wall_scene, serve_ctx, {})
	_expect(not wall_hit, "boss serve at rally 0 penetrates tetro walls")
	_expect(wall_state.debug_get_wall_collidable_cell_count() == 1, "boss serve penetration does not destroy wall cells")
	_expect((wall_scene["ball_vel"] as Vector2) == Vector2(-5.0, 0.0), "boss serve wall penetration does not reflect the ball")


func _test_player_rally_after_serve_collides_with_tetromino() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", false)
	var scene := {
		"ball_pos": Vector2(310.0, 305.0),
		"previous_ball_pos": Vector2(310.0, 280.0),
		"ball_vel": Vector2(1.0, 8.0),
	}
	var ctx := {"current_stage": 6, "ball_size": 20.0, "ball_rally_count": 1, "last_hit_by": "player"}
	var hit: bool = state.resolve_ball_collision(scene, ctx, {})
	_expect(hit, "player rally after serve collides with Stage 6 tetrominoes")
	_expect((scene["ball_vel"] as Vector2).y < 0.0, "post-serve tetromino hit reflects the ball")
	_expect(state.debug_get_tetromino_count() == 0, "post-serve tetromino hit destroys normal tetrominoes")


func _test_power_smash_destroys_tetromino_and_wall_without_reflection() -> void:
	var tetro_state: Object = Stage6TetriserState.new()
	tetro_state.debug_spawn_tetromino_at(Vector2(300.0, 300.0), "O", true)
	var tetro_scene := {
		"ball_pos": Vector2(310.0, 305.0),
		"previous_ball_pos": Vector2(310.0, 280.0),
		"ball_vel": Vector2(2.0, 9.0),
	}
	var power_ctx := {"current_stage": 6, "ball_size": 20.0, "power_smashing_parabola_active": true, "ball_rally_count": 1, "last_hit_by": "player"}
	var tetro_hit: bool = tetro_state.resolve_ball_collision(tetro_scene, power_ctx, {})
	_expect(tetro_hit, "power smash reports tetromino contact")
	_expect(tetro_state.debug_get_tetromino_count() == 0, "power smash destroys even super tetrominoes")
	_expect((tetro_scene["ball_vel"] as Vector2) == Vector2(2.0, 9.0), "power smash tetromino contact does not reflect the ball")

	var wall_state: Object = Stage6TetriserState.new()
	wall_state.debug_spawn_wall_cell_at(Vector2(0.0, 400.0))
	var wall_scene := _wall_hit_scene(Vector2(0.0, 400.0))
	var wall_hit: bool = wall_state.resolve_ball_collision(wall_scene, power_ctx, {})
	_expect(wall_hit, "power smash reports wall contact")
	_expect(wall_state.debug_get_wall_collidable_cell_count() == 0, "power smash removes the whole owning wall piece from collision")
	_expect((wall_scene["ball_vel"] as Vector2) == Vector2(-5.0, 0.0), "power smash wall contact does not reflect the ball")


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


func _test_super_tetromino_explodes_on_landing() -> void:
	var state: Object = Stage6TetriserState.new()
	var status_state := FakeStatusEffectState.new()
	var movement_state := FakeMovementState.new()
	var audio := FakeAudio.new()
	var ctx := _active_context()
	ctx["player_pos"] = Vector2(302.0, 700.0)
	ctx["player_paddle_size"] = Vector2(60.0, 30.0)
	state.debug_spawn_tetromino_at(Vector2(300.0, 670.0), "O", true)

	for _i in range(12):
		state.update(0.1, ctx, {
			"status_effect_state": status_state,
			"movement_state": movement_state,
			"audio": audio,
		})
		if state.debug_get_tetromino_count() == 0:
			break

	_expect(state.debug_get_tetromino_count() == 0, "super tetromino explodes instead of settling on landing")
	_expect(not state.debug_get_tetromino_states().has("settled"), "super landing must not leave a permanent settled block")
	_expect(state.debug_get_debris_count() > 0, "super landing explosion emits tetromino debris")
	_expect(state.debug_get_emp_count() > 0, "super landing explosion emits a shockwave/EMP ripple")
	_expect(audio.calls.has("break"), "super landing explosion flushes the break sound")
	_expect(status_state.calls.size() == 1, "super landing explosion applies one player stun")
	if status_state.calls.size() == 1:
		var stun_call: Dictionary = status_state.calls[0]
		_expect(stun_call.get("target", "") == "player", "super landing stun targets the player")
		_expect(stun_call.get("status_id", "") == "stun", "super landing applies stun status")
		_expect(is_equal_approx(float(stun_call.get("duration_frames", 0.0)), 54.0), "super landing stun lasts 0.9 seconds")
	_expect(movement_state.calls.size() == 1, "super landing explosion starts player knockback")
	if movement_state.calls.size() == 1:
		var knock_call: Dictionary = movement_state.calls[0]
		_expect(is_equal_approx(absf(float(knock_call.get("velocity", 0.0))), 24.0), "super landing knockback maps base 12px to doubled 24px speed")
		_expect(is_equal_approx(float(knock_call.get("frames", 0.0)), 18.0), "super landing knockback uses the stage knockback window")
		_expect(is_equal_approx(float(knock_call.get("decay", 0.0)), 0.88), "super landing knockback uses the legacy decay curve")
		_expect(bool(knock_call.get("interrupt_dash", false)), "super landing knockback replaces current paddle knockback")
		_expect(bool(knock_call.get("stun_locked", false)), "super landing knockback is cleansable/stun-coupled")


func _test_super_tetromino_explosion_radius_gate() -> void:
	var origin := Vector2(300.0, 690.0)
	var super_cell_size := 34.0
	var explosion_center := origin + Vector2(super_cell_size, super_cell_size)
	var explosion_radius := 80.0 * (super_cell_size / 20.0)
	var player_size := Vector2(20.0, 20.0)

	var inside_status := FakeStatusEffectState.new()
	var inside_movement := FakeMovementState.new()
	var inside_ctx := _active_context()
	inside_ctx["player_pos"] = explosion_center + Vector2(explosion_radius - 0.25, 0.0) - player_size * 0.5
	inside_ctx["player_paddle_size"] = player_size
	var inside_state: Object = Stage6TetriserState.new()
	inside_state.debug_spawn_tetromino_at(origin, "O", true)
	_advance_time(inside_state, 0.110, inside_ctx, {
		"status_effect_state": inside_status,
		"movement_state": inside_movement,
	})
	_expect(inside_status.calls.size() == 1, "super explosion applies stun when the player center is just inside radius")
	_expect(inside_movement.calls.size() == 1, "super explosion applies knockback when the player center is just inside radius")

	var outside_status := FakeStatusEffectState.new()
	var outside_movement := FakeMovementState.new()
	var outside_ctx := _active_context()
	outside_ctx["player_pos"] = explosion_center + Vector2(explosion_radius + 0.25, 0.0) - player_size * 0.5
	outside_ctx["player_paddle_size"] = player_size
	var outside_state: Object = Stage6TetriserState.new()
	outside_state.debug_spawn_tetromino_at(origin, "O", true)
	_advance_time(outside_state, 0.110, outside_ctx, {
		"status_effect_state": outside_status,
		"movement_state": outside_movement,
	})
	_expect(outside_status.calls.is_empty(), "super explosion does not stun when the player center is just outside radius")
	_expect(outside_movement.calls.is_empty(), "super explosion does not knock back when the player center is just outside radius")


func _test_super_tetromino_explosion_respects_player_immunity() -> void:
	var origin := Vector2(300.0, 690.0)
	var ctx := _active_context()
	ctx["player_pos"] = Vector2(302.0, 700.0)
	ctx["player_paddle_size"] = Vector2(60.0, 30.0)

	var cleanse_status := FakeStatusEffectState.new()
	var cleanse_movement := FakeMovementState.new()
	var cleanse_state := FakeCleanseState.new()
	cleanse_state.immune = true
	var cleanse_mythic := FakeMythicItemRuntime.new()
	var cleanse_tetro: Object = Stage6TetriserState.new()
	cleanse_tetro.debug_spawn_tetromino_at(origin, "O", true)
	_advance_time(cleanse_tetro, 0.110, ctx, {
		"status_effect_state": cleanse_status,
		"movement_state": cleanse_movement,
		"smasher_cleanse_state": cleanse_state,
		"mythic_item_runtime": cleanse_mythic,
	})
	_expect(cleanse_status.calls.is_empty(), "cleanse immunity blocks super explosion stun")
	_expect(cleanse_movement.calls.is_empty(), "cleanse immunity blocks super explosion knockback")
	_expect(cleanse_mythic.calls.is_empty(), "cleanse immunity short-circuits before Celestial Armor consumption")

	var mythic_status := FakeStatusEffectState.new()
	var mythic_movement := FakeMovementState.new()
	var mythic_state := FakeMythicItemRuntime.new()
	mythic_state.should_consume_celestial_armor = true
	var mythic_tetro: Object = Stage6TetriserState.new()
	mythic_tetro.debug_spawn_tetromino_at(origin, "O", true)
	_advance_time(mythic_tetro, 0.110, ctx, {
		"status_effect_state": mythic_status,
		"movement_state": mythic_movement,
		"mythic_item_runtime": mythic_state,
	})
	_expect(mythic_status.calls.is_empty(), "Celestial Armor blocks super explosion stun")
	_expect(mythic_movement.calls.is_empty(), "Celestial Armor blocks super explosion knockback")
	_expect(mythic_state.calls.size() == 1, "super explosion asks Celestial Armor to consume one proc")
	if mythic_state.calls.size() == 1:
		var call: Dictionary = mythic_state.calls[0]
		_expect(str(call.get("source", "")) == "stage6_tetro_explosion", "Celestial Armor source identifies the tetro explosion")
		_expect(str(call.get("effect_type", "")) == "stun", "Celestial Armor consumes the stun half of the tetro explosion")
		_expect((call.get("context", {}) as Dictionary) == ctx, "Celestial Armor receives the live explosion context")


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
	state.debug_force_spawn_wall(4242)
	# 좌우 각 10행 x 4열 = 80셀.
	_expect(state.debug_get_wall_piece_count() == 20, "wall spawns 10 tetromino pieces per side")
	_expect(state.debug_get_wall_cell_count() == state.debug_get_wall_piece_count() * 4, "wall pieces keep 4-cell tetromino chunks")

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
	_expect(single.debug_get_wall_collidable_cell_count() == 0, "wall hit disables the whole owning piece from collision")


func _test_wall_lifetime_clears() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_force_spawn_wall(4242)
	_expect(state.debug_get_wall_cell_count() > 0, "precondition: wall present")
	for _i in range(70):   # ~7초 > 수명 6초
		state.update(0.1, _active_context())
	_expect(state.debug_get_wall_piece_count() > 0, "wall lifetime no longer clears every piece in one frame")


func _test_wall_spawn_uses_tetromino_pieces_and_collision_gate() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_force_spawn_wall(4242)
	_expect(state.debug_get_wall_piece_count() == 20, "wall spawns 10 tetromino pieces per side")
	_expect(state.debug_get_wall_cell_count() == state.debug_get_wall_piece_count() * 4, "wall pieces keep tetromino-sized 4-cell chunks")
	_expect(state.debug_get_wall_collidable_cell_count() == 0, "assembling wall pieces are not collidable")

	for _i in range(5):
		state.update(0.1, _active_context())
	var assembling_draw: Array = state.get_actor_draw_context().get("stage6_tetriser_wall_cells", [])
	_expect(assembling_draw.size() > 0 and assembling_draw.size() < state.debug_get_wall_cell_count(), "wall assembly reveals cells before collision activates")
	var ctx := {"current_stage": 6, "ball_size": 20.0}
	_expect(not state.resolve_ball_collision(_wall_hit_scene(_first_wall_cell_origin(state)), ctx, {}), "ball does not collide with assembling wall pieces")

	for _i in range(7):
		state.update(0.1, _active_context())
	_expect(state.debug_get_wall_states().has("installed"), "wall pieces become installed after assembly")
	_expect(state.debug_get_wall_collidable_cell_count() == state.debug_get_wall_cell_count(), "installed wall pieces expose all cells to collision")

	var before_cells: int = state.debug_get_wall_cell_count()
	var before_collidable: int = state.debug_get_wall_collidable_cell_count()
	var scene := _wall_hit_scene(_first_wall_cell_origin(state))
	var hit: bool = state.resolve_ball_collision(scene, ctx, {})
	_expect(hit, "ball hits installed wall piece")
	_expect(scene["ball_vel"].x > 0.0, "ball reflects rightward off wall edge (vx=%f)" % scene["ball_vel"].x)
	_expect(state.debug_get_wall_collidable_cell_count() == before_collidable - 4, "one hit removes the whole tetromino piece from collision")
	_expect(state.debug_get_wall_states().has("evaporating"), "hit wall piece fast-evaporates instead of erasing one cell")
	for _i in range(2):
		state.update(0.1, _active_context())
	_expect(state.debug_get_wall_cell_count() < before_cells, "fast evaporation removes the hit piece cell-by-cell after collision is disabled")


func _test_wall_position_preserves_original_top_anchor() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_force_spawn_wall(4242)
	for _i in range(11):
		state.update(0.1, _active_context())
	var actor_context: Dictionary = state.get_actor_draw_context()
	var cells: Array = actor_context.get("stage6_tetriser_wall_cells", [])
	_expect(cells.size() == state.debug_get_wall_cell_count(), "precondition: all seeded wall cells are visible after assembly")
	var cell_size: float = float(actor_context.get("stage6_tetriser_cell_size", 20.0))
	var min_top: float = INF
	var max_bottom: float = -INF
	for cell_entry in cells:
		var origin: Vector2 = (cell_entry as Dictionary).get("origin", Vector2.ZERO)
		min_top = minf(min_top, origin.y)
		max_bottom = maxf(max_bottom, origin.y + cell_size)
	_expect(min_top < 0.0, "wall preserves original top-clipped quirk (min_top=%f)" % min_top)
	_expect(max_bottom < 450.0, "wall stays in the original upper-field band, not floor anchored (max_bottom=%f)" % max_bottom)


func _test_wall_lifetime_evaporates_piecewise() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_force_spawn_wall(4242)
	_expect(state.debug_get_wall_cell_count() > 0, "precondition: wall present")
	for _i in range(11):
		state.update(0.1, _active_context())
	_expect(state.debug_get_wall_collidable_cell_count() == state.debug_get_wall_cell_count(), "precondition: assembled wall is collidable")
	for _i in range(59):
		state.update(0.1, _active_context())
	_expect(not state.debug_get_wall_states().has("evaporating"), "wall remains installed before the 6s lifetime expires")
	for _i in range(2):
		state.update(0.1, _active_context())
	_expect(state.debug_get_wall_states().has("evaporating"), "wall enters piecewise evaporation at lifetime expiry")
	_expect(state.debug_get_wall_piece_count() > 0, "wall does not clear all pieces in the expiry frame")
	for _i in range(12):
		state.update(0.1, _active_context())
	_expect(state.debug_get_wall_cell_count() == 0, "wall evaporation eventually removes every wall piece")


func _first_wall_cell_origin(state: Object) -> Vector2:
	var cells: Array = state.get_actor_draw_context().get("stage6_tetriser_wall_cells", [])
	if cells.is_empty():
		return Vector2.ZERO
	return (cells[0] as Dictionary).get("origin", Vector2.ZERO)


func _wall_hit_scene(cell_origin: Vector2) -> Dictionary:
	return {
		"ball_pos": cell_origin + Vector2(15.0, 10.0),
		"previous_ball_pos": cell_origin + Vector2(35.0, 10.0),
		"ball_vel": Vector2(-5.0, 0.0),
	}


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


func _test_natural_evaporation_does_not_rebuild_cube() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_force_cube_solve_pending()
	for _i in range(25):
		state.update(0.05, _active_context())
	_expect(state.debug_is_cube_rebuild(), "precondition: cube is waiting for player-caused tetromino kills")
	_expect(state.debug_get_cube_rebuild_progress() == 0, "precondition: rebuild progress starts at 0")

	state.debug_spawn_tetromino_at(Vector2(300.0, 700.0), "O", false)
	var settled := false
	for _i in range(6):
		state.update(0.1, _active_context())
		if state.debug_get_tetromino_states().has("settled"):
			settled = true
			break
	_expect(settled, "normal tetromino settles while cube is rebuilding")

	for _i in range(40):
		state.update(0.1, _active_context())
		if state.debug_get_tetromino_count() == 0:
			break
	_expect(state.debug_get_tetromino_count() == 0, "natural evaporation removes the settled tetromino")
	_expect(state.debug_is_cube_rebuild(), "natural evaporation does not reactivate the cube")
	_expect(state.debug_get_cube_rebuild_progress() == 0, "natural evaporation does not count as a rebuild kill")


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


func _test_crystal_shield_score_schedules_and_starts() -> void:
	var state: Object = Stage6TetriserState.new()
	var active_ctx := _active_context()
	active_ctx["player_score"] = 4
	active_ctx["boss_pos"] = Vector2(330.0, 45.0)
	active_ctx["boss_paddle_size"] = Vector2(100.0, 40.0)
	var active_result: Dictionary = state.update(0.05, active_ctx)
	_expect(state.debug_is_crystal_shield_pending(), "player score 4 schedules the crystal shield")
	_expect(not bool(active_result.get("skip_ball_motion_step", true)), "crystal shield scheduling must not hijack ball motion")

	var waiting_ctx: Dictionary = active_ctx.duplicate()
	waiting_ctx["ball_active"] = false
	waiting_ctx["waiting_for_serve"] = true
	var waiting_result: Dictionary = state.update(0.05, waiting_ctx)
	_expect(state.debug_is_crystal_shield_freeze_active(), "pending crystal shield starts forming on serve wait")
	_expect(bool(waiting_result.get("stage6_tetriser_crystal_shield_freeze_active", false)), "forming shield reports freeze flag")
	_expect(not bool(waiting_result.get("skip_ball_motion_step", true)), "crystal shield freeze flag must not set skip_ball_motion_step")
	var draw_context: Dictionary = state.get_actor_draw_context()
	_expect((draw_context.get("stage6_tetriser_crystal_shield_blocks", []) as Array).size() == 24, "crystal shield exposes 24 draw blocks")

	for _i in range(24):
		state.update(0.1, active_ctx)
	_expect(state.debug_is_crystal_shield_active(), "crystal shield becomes active after the formation freeze")
	_expect(state.debug_get_crystal_shield_block_count() == 24, "active crystal shield has 24 blocks")


func _test_crystal_shield_collision_and_reset() -> void:
	var state: Object = Stage6TetriserState.new()
	state.debug_start_crystal_shield(Vector2(380.0, 75.0), true)
	_expect(state.debug_is_crystal_shield_active(), "debug start should activate crystal shield immediately")
	var blocks: Array = state.get_actor_draw_context().get("stage6_tetriser_crystal_shield_blocks", [])
	_expect(blocks.size() == 24, "precondition: shield has 24 draw blocks")
	if blocks.is_empty():
		return
	var target_block: Dictionary = blocks[0]
	var hit_pos: Vector2 = target_block.get("position", Vector2.ZERO)
	var boss_scene := {
		"ball_pos": hit_pos,
		"previous_ball_pos": hit_pos - Vector2(0.0, 30.0),
		"ball_vel": Vector2(0.0, 12.0),
	}
	var boss_ctx := {"current_stage": 6, "ball_size": 20.0, "last_hit_by": "boss"}
	_expect(not state.resolve_ball_collision(boss_scene, boss_ctx, {}), "boss-owned ball should ignore crystal shield")
	_expect(state.debug_get_crystal_shield_block_count() == 24, "boss-owned ball should not destroy shield blocks")

	var player_scene := {
		"ball_pos": hit_pos,
		"previous_ball_pos": hit_pos - Vector2(0.0, 30.0),
		"ball_vel": Vector2(0.0, 12.0),
	}
	var player_ctx := {"current_stage": 6, "ball_size": 20.0, "last_hit_by": "player"}
	_expect(state.resolve_ball_collision(player_scene, player_ctx, {}), "player ball should hit crystal shield")
	_expect(state.debug_get_crystal_shield_block_count() == 21, "crystal shield hit evaporates the hit block and two neighbors")
	_expect((player_scene["ball_vel"] as Vector2).length() >= 10.0, "crystal shield reflection preserves a minimum ball speed")
	for _i in range(5):
		state.update(0.1, _active_context())
	_expect((state.get_actor_draw_context().get("stage6_tetriser_crystal_shield_blocks", []) as Array).size() == 21, "evaporated shield blocks are removed after fade")
	state.reset_round()
	_expect(not state.debug_is_crystal_shield_active(), "round reset clears active crystal shield")
	_expect(state.debug_get_crystal_shield_block_count() == 0, "round reset removes crystal shield blocks")


func _test_stage6_score_context_reaches_crystal_shield() -> void:
	var controller: Object = BattleEffectsUpdateController.new()
	var state: Object = Stage6TetriserState.new()
	var score_state := FakeScoreState.new()
	score_state.player_score = 4

	var deps := {
		"score_state": score_state,
		"stage6_tetriser_state": state,
	}
	var active_ctx := _active_context()
	active_ctx["player_score"] = 0
	active_ctx["boss_pos"] = Vector2(330.0, 45.0)
	active_ctx["boss_paddle_size"] = Vector2(100.0, 40.0)
	controller.update(0.05, active_ctx, deps)
	_expect(int(active_ctx.get("player_score", 0)) == 4, "effects controller should merge score_state before Stage 6 update")
	_expect(state.debug_is_crystal_shield_pending(), "effects controller score merge should schedule crystal shield at player score 4")

	var waiting_ctx := active_ctx.duplicate(true)
	waiting_ctx["ball_active"] = false
	waiting_ctx["waiting_for_serve"] = true
	controller.update(0.05, waiting_ctx, deps)
	_expect(state.debug_is_crystal_shield_freeze_active(), "effects controller should let pending shield start on serve wait")
	_expect(
		bool(waiting_ctx.get("stage6_tetriser_crystal_shield_freeze_active", false)),
		"effects controller should merge Stage 6 crystal shield update result into context"
	)
	_expect(
		not bool(waiting_ctx.get("skip_ball_motion_step", true)),
		"effects controller crystal shield path must not request ball-motion skip"
	)


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


func _test_pillar_scene_drawer_routes_background() -> void:
	var source := FileAccess.get_file_as_string(STAGE6_PILLAR_SCENE_DRAWER_PATH)
	_expect(source.find("func draw(_canvas") < 0, "Stage 6 pillar draw must not remain scaffold no-op")
	_expect(source.find("states.get(\"stage_background\"") >= 0, "Stage 6 pillar draw reads routed stage background")
	_expect(source.find("_draw_stage_background") >= 0, "Stage 6 pillar draw delegates stage background draw")
	_expect(source.find("stage_background.draw(") >= 0, "Stage 6 pillar draw invokes background renderer")
	_expect(source.find("stage6.pillar.background") >= 0, "Stage 6 background draw has a perf sample")


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


func _advance_fall_steps(state: Object, steps: int) -> void:
	for _i in range(steps):
		state.update(0.100, _active_context())
		state.update(0.010, _active_context())


func _advance_time(state: Object, seconds: float, context: Dictionary, deps: Dictionary = {}) -> void:
	var remaining: float = seconds
	while remaining > 0.0001:
		var step: float = minf(0.100, remaining)
		state.update(step, context, deps)
		remaining -= step


func _tetromino_center_x(entry: Dictionary) -> float:
	var origin: Vector2 = entry.get("origin", Vector2.ZERO)
	var cells: Array = entry.get("cells", [])
	var cell_size: float = float(entry.get("cell_size", 20.0))
	var min_x: float = INF
	var max_x: float = -INF
	for cell in cells:
		var p: Vector2 = cell
		min_x = minf(min_x, origin.x + p.x * cell_size)
		max_x = maxf(max_x, origin.x + p.x * cell_size + cell_size)
	if cells.is_empty():
		return origin.x
	return (min_x + max_x) * 0.5


func _cells_signature(cells: Array) -> String:
	var parts: Array[String] = []
	for cell in cells:
		var p: Vector2 = cell
		parts.append("%d,%d" % [int(round(p.x)), int(round(p.y))])
	parts.sort()
	return "|".join(parts)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
