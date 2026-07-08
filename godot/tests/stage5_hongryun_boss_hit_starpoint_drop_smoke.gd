extends SceneTree

# Stage 5 홍련 보스 피격 스타포인트 드랍 씰.
#
# 스펙: 홍련이 공에 맞을 때(보스 패들 접촉) 이벤트당 단일 굴림 1회 —
# [0, 0.02) → 2개 드랍, [0.02, 0.07) → 1개 드랍, 나머지 → 없음.
# (2% 확률 2개 / 5% 확률 1개, 상호배타.)
#
# 봉인 레그:
# 1. roll → count 매핑 경계값 (확률 정의 그 자체)
# 2. 라이브 프로듀서 배선 — register_boss_paddle_contact 실호출 굴림이
#    {0,1,2}개만 스폰하고 1개/2개 케이스 모두 실제 발생, 좌표 클램프
# 3. 플레이어 패들 수집 — collect_star_points 정확히 1회 + 드랍 소거 + 사운드
# 4. 라운드 리셋 / 스테이지 이탈 시 드랍·파티클 정리
# 5. actor draw context 로 렌더러 키 노출

const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")

var _failures: Array[String] = []


class FakeRuntimePerkState:
	var collect_calls := 0
	var last_amount := 0

	func collect_star_points(
		amount: int,
		_character_type: String,
		_catalog: Object,
		_owner: Object,
		_registry: Object,
		_skip_choice: bool = false
	) -> bool:
		collect_calls += 1
		last_amount = amount
		return false


class FakeAudio:
	var starpoint_collect_count := 0

	func play_starpoint_collect() -> void:
		starpoint_collect_count += 1


func _init() -> void:
	_verify_roll_mapping_boundaries()
	_verify_boss_hit_producer_rolls_drops()
	_verify_player_collection_grants_star_point()
	_verify_round_reset_clears_drops()
	_verify_stage_leave_clears_drops()
	_verify_actor_draw_context_exposes_drops()

	if _failures.is_empty():
		print("stage5_hongryun_boss_hit_starpoint_drop_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _base_context() -> Dictionary:
	return {
		"current_stage": 5,
		"width": 760.0,
		"height": 750.0,
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(380.0, 60.0),
		"ball_vel": Vector2(2.0, -6.0),
		"boss_pos": Vector2(330.0, 25.0),
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}


func _verify_roll_mapping_boundaries() -> void:
	var cases: Array = [
		[0.0, 2],
		[0.019, 2],
		[0.02, 1],
		[0.0699, 1],
		[0.07, 0],
		[0.5, 0],
		[0.99, 0],
	]
	for case_value in cases:
		var roll: float = float(case_value[0])
		var expected: int = int(case_value[1])
		var actual: int = Stage5HongryunState.resolve_boss_hit_starpoint_drop_count(roll)
		_expect(
			actual == expected,
			"roll %.4f should map to %d drops (got %d)" % [roll, expected, actual]
		)


func _verify_boss_hit_producer_rolls_drops() -> void:
	var state := Stage5HongryunState.new()
	state.rng.seed = 20260708
	var context: Dictionary = _base_context()
	var single_hits := 0
	var double_hits := 0
	var invalid_deltas := 0
	var out_of_bounds := 0
	var total_calls := 3000
	for _idx in range(total_calls):
		state.starpoint_drops.clear()
		state.register_boss_paddle_contact(Vector2(2.0, 6.0), {}, context)
		var delta: int = state.starpoint_drops.size()
		if delta == 1:
			single_hits += 1
		elif delta == 2:
			double_hits += 1
		elif delta != 0:
			invalid_deltas += 1
		for drop_value in state.starpoint_drops:
			var drop: Dictionary = drop_value if drop_value is Dictionary else {}
			var pos: Vector2 = drop.get("pos", Vector2.ZERO)
			if pos.x < 0.0 or pos.x > 760.0 or pos.y < 0.0 or pos.y > 750.0:
				out_of_bounds += 1
	_expect(invalid_deltas == 0, "boss hit must spawn only 0/1/2 drops per contact (saw %d invalid)" % invalid_deltas)
	_expect(single_hits > 0, "1-drop (5%% band) case should occur across %d seeded contacts" % total_calls)
	_expect(double_hits > 0, "2-drop (2%% band) case should occur across %d seeded contacts" % total_calls)
	var hit_ratio: float = float(single_hits + double_hits) / float(total_calls)
	_expect(
		hit_ratio > 0.02 and hit_ratio < 0.15,
		"combined drop rate should sit near 7%% (got %.4f)" % hit_ratio
	)
	_expect(out_of_bounds == 0, "drop positions must clamp inside the playfield (saw %d outside)" % out_of_bounds)
	_expect(not state.inferno_active, "starpoint roll must not start the inferno on its own")


func _verify_player_collection_grants_star_point() -> void:
	var state := Stage5HongryunState.new()
	var perk_state := FakeRuntimePerkState.new()
	var audio := FakeAudio.new()
	var context: Dictionary = _base_context()
	var deps := {
		"runtime_perk_state": perk_state,
		"audio": audio,
	}
	var player_center := Vector2(380.0, 715.0)
	state._spawn_starpoint_drop_at(player_center, deps, context)
	_expect(state.starpoint_drops.size() == 1, "spawn helper should append one drop")
	state.update(1.0 / 60.0, context, deps)
	_expect(perk_state.collect_calls == 1, "paddle overlap should collect exactly one star point (got %d)" % perk_state.collect_calls)
	_expect(perk_state.last_amount == 1, "collection should grant 1 star point per drop")
	_expect(state.starpoint_drops.is_empty(), "collected drop should leave the field array")
	_expect(audio.starpoint_collect_count == 1, "collection should play the shared starpoint collect cue")


func _verify_round_reset_clears_drops() -> void:
	var state := Stage5HongryunState.new()
	var context: Dictionary = _base_context()
	state._spawn_starpoint_drop_at(Vector2(380.0, 300.0), {}, context)
	_expect(not state.starpoint_drops.is_empty(), "precondition: drop spawned before round reset")
	_expect(not state.starpoint_particles.is_empty(), "precondition: spawn particles present before round reset")
	state.reset_round()
	_expect(state.starpoint_drops.is_empty(), "reset_round should clear boss-hit starpoint drops")
	_expect(state.starpoint_particles.is_empty(), "reset_round should clear starpoint particles")


func _verify_stage_leave_clears_drops() -> void:
	var state := Stage5HongryunState.new()
	var context: Dictionary = _base_context()
	state._spawn_starpoint_drop_at(Vector2(380.0, 300.0), {}, context)
	var leave_context: Dictionary = _base_context()
	leave_context["current_stage"] = 1
	state.update(1.0 / 60.0, leave_context, {})
	_expect(state.starpoint_drops.is_empty(), "leaving stage 5 should drop mid-flight starpoints")
	_expect(state.starpoint_particles.is_empty(), "leaving stage 5 should drop starpoint particles")


func _verify_actor_draw_context_exposes_drops() -> void:
	var state := Stage5HongryunState.new()
	var context: Dictionary = _base_context()
	state._spawn_starpoint_drop_at(Vector2(380.0, 300.0), {}, context)
	var draw_context: Dictionary = state.get_actor_draw_context()
	_expect(
		draw_context.has("stage5_hongryun_starpoint_drops"),
		"actor draw context should expose stage5_hongryun_starpoint_drops"
	)
	_expect(
		draw_context.has("stage5_hongryun_starpoint_particles"),
		"actor draw context should expose stage5_hongryun_starpoint_particles"
	)
	var drops: Array = draw_context.get("stage5_hongryun_starpoint_drops", [])
	_expect(drops.size() == 1, "draw context should carry the live drop payload")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
