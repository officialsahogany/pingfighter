extends SceneTree

# 킥 읽기 실패(쉐도우 백스텝 / 마샬 킥 적중 1회당 1굴림) 봉인.
#
# 회귀 대상: 극한/초월 리그에서 두 무공이 사실상 100% 막히던 문제. 일반 실수
# 오차 상한(80px / 20px)이 보스 미스 임계(패들 반폭 + hitbox padding + 공 반폭)
# 보다 작아서, 실수가 나도 보스가 그대로 막았다.
#
# ⚠️이 씰의 핵심은 '목표 x가 얼마나 떨어졌나'가 아니라 **실제로 공이 통과했나**다.
# 목표만 어긋나게 잡는 것으로는 미스가 보장되지 않는다(보스는 이후 이동하고,
# 대쉬는 도착점을 관통하며, 이미 바깥에 있던 보스는 오히려 안쪽으로 끌려온다).
# 그래서 outcome 레그는 실제 BossAiState.update() → BallMotionCollisionDetector
# 왕복을 관통한다. 목표 분리 거리만 재는 단언은 이 결함들을 전부 통과시킨다.

const BossAiPredictionState := preload("res://scripts/ai/boss_ai_prediction_state.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const BossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")

# 극한 리그 실측: 패들 100 * 1.07 = 107 → 53.5 + 5(padding) + 14.3(공 반폭) = 72.8
const LIMIT_BOSS_PADDLE_WIDTH: float = 107.0
const HITBOX_PADDING: float = 5.0
const BALL_SIZE: float = 28.6
const MISS_THRESHOLD: float = LIMIT_BOSS_PADDLE_WIDTH * 0.5 + HITBOX_PADDING + BALL_SIZE * 0.5
const BOSS_LINE_Y: float = 84.3

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 3
	var ai_mode := "limit"
	var ball_active := true
	var player_pos := Vector2(200.0, 690.0)
	var ball_pos := Vector2(380.0, 700.0)
	var ball_vel := Vector2(0.0, -20.0)
	var boss_pos := Vector2(326.5, 25.0)
	var boss_vel := 0.0
	var selected_character_type := "viper"


class FakeRoundState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false

	func does_player_serve() -> bool:
		return true

	func get_snapshot() -> Dictionary:
		return {"serve_timer": 0.0, "serve_delay": 1.0}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init() -> void:
		instances["round_flow_state"] = FakeRoundState.new()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name in ["shadow_step", "marshal_kick"]

	func get_skill_cost(skill_name: String) -> float:
		if skill_name == "shadow_step":
			return 100.0
		if skill_name == "marshal_kick":
			return 80.0
		return 0.0


class FakeSkillState:
	func trigger_configured_cooldown(_skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		pass

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakeOrbHud:
	func trigger_gauge_spin(_now_msec: int) -> void:
		pass


class FakeAudio:
	func play_viper_backstep() -> void:
		pass

	func play_viper_shadow_kick() -> void:
		pass

	func play_viper_marshal_kick() -> void:
		pass

	func play_viper_phantom_hit() -> void:
		pass

	func play_dash_start(_is_half: bool) -> void:
		pass

	func stop_dash_delay() -> void:
		pass


class FakeFeedback:
	func set_screen_shake(_duration: float, _amount: float) -> void:
		pass

	func max_screen_shake(_duration: float, _amount: float) -> void:
		pass


class FakePerkState:
	func get_runtime_skill_level(_skill_id: String) -> int:
		return 0

	func award_gold(amount: int) -> int:
		return max(0, amount)


class FakeBallPhysics:
	func apply_dampened_multiplier(_current_speed: float, raw_multiplier: float) -> float:
		return raw_multiplier


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# --- 결과(실제 미스) 계약 ---
	_test_armed_failure_actually_lets_the_ball_through()
	_test_control_no_failure_is_blocked()
	_test_late_contact_never_arms()
	# --- 굴림 계약 ---
	_test_zero_chance_league_is_a_strict_no_op()
	_test_offset_band_and_wall_clamp()
	_test_single_roll_per_kick_event()
	_test_new_kick_rerolls_mid_ascent()
	_test_chain_bonus_only_applies_to_chained_kicks()
	_test_pending_events_are_not_coalesced_into_one_roll()
	_test_expired_pending_never_lands_on_a_later_ordinary_ball()
	_test_producer_early_returns_still_expire_the_opportunity()
	_test_chained_kick_keeps_an_already_won_read_failure()
	_test_unreachable_follow_up_drops_the_latch()
	_test_movement_slow_debuffs_are_respected_by_the_gate()
	_test_full_chain_probability_matches_the_designed_union()
	# --- 리그 프로파일 ---
	_test_league_profile_chances()
	# --- 이벤트 발행 계약 ---
	_test_shadow_step_hit_publishes_event()
	_test_normal_marshal_publishes_chained_event()
	_test_double_marshal_does_not_publish_a_third_event()
	_test_round_reset_keeps_the_serial_monotonic()

	if _failures.is_empty():
		print("boss_kick_read_failure_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# --- 결과 계약 ---------------------------------------------------------------


# 당첨된 읽기 실패는 '목표가 멀어진다'가 아니라 '공이 실제로 통과한다'여야 한다.
# 보스 시작 위치(정답 위 / 좌우 / 반대편), 공 x(벽쪽 포함), 대쉬 on/off를 모두 돈다.
func _test_armed_failure_actually_lets_the_ball_through() -> void:
	var armed := 0
	var realistic_armed := 0
	# ⚠️(y, 속도) 조합을 넓게 돌아야 한다. y=700/v=20만 돌면 보스가 목표까지
	# 여유 있게 도착해버려서, '이미 바깥에 있던 보스를 안쪽으로 끌어당기는' 결함이
	# 임계선 0.1px 차이로 살아남는다(그 결함은 리드가 빠듯한 조합에서만 드러난다).
	for geometry in [
		{"y": 700.0, "v": 20.0},
		{"y": 600.0, "v": 26.0},
		{"y": 505.5, "v": 26.0},
		{"y": 500.0, "v": 20.0},
		{"y": 460.0, "v": 26.0},
		{"y": 420.0, "v": 14.0},
		{"y": 380.0, "v": 20.0},
	]:
		for boss_offset in [-320.0, -150.0, -60.0, -2.0, 0.0, 60.0, 150.0, 320.0]:
			for ball_x in [60.0, 380.0, 700.0]:
				for dash in [false, true]:
					# ⚠️보스 초기 속도 축이 없으면 "정지 상태에서 즉시 회피"만 검사하게
					# 된다. 회피 방향과 반대로 전속 주행 중이면 보스는 먼저 감속·역전
					# 해야 하고, 그 비용을 무시한 도달 판정은 거짓말을 한다.
					for boss_vel in [0.0, 11.1497, -11.1497, 5.5]:
						var outcome: Dictionary = _simulate_rally(float(geometry["y"]), float(geometry["v"]), boss_offset, ball_x, dash, 1.0, boss_vel)
						if not bool(outcome["armed"]):
							continue
						armed += 1
						if is_equal_approx(float(geometry["y"]), 700.0) and is_zero_approx(boss_vel):
							realistic_armed += 1
						if bool(outcome["blocked"]):
							_expect(false, "armed read failure was still blocked (y=%.0f v=%.0f boss_off=%.0f ball_x=%.0f dash=%s boss_vel=%.2f)" % [
								float(geometry["y"]), float(geometry["v"]), boss_offset, ball_x, str(dash), boss_vel])
							return
	_expect(realistic_armed >= 40, "a realistic kick (y=700) should always be a valid read-failure opportunity (armed %d/42)" % realistic_armed)
	_expect(armed >= 80, "the sweep should exercise a broad set of armed opportunities (got %d)" % armed)


# 대조군: 확률 0이면 같은 지오메트리에서 보스가 정상적으로 막는다. 이게 없으면
# 위 레그가 "원래 안 막히는 자리였다"로도 통과하는 공허-GREEN이 된다.
func _test_control_no_failure_is_blocked() -> void:
	var blocked := 0
	var trials := 0
	for boss_offset in [-60.0, 0.0, 60.0]:
		for ball_x in [380.0, 700.0]:
			trials += 1
			var outcome: Dictionary = _simulate_rally(700.0, 20.0, boss_offset, ball_x, false, 0.0)
			_expect(not bool(outcome["armed"]), "0% chance must never arm a read failure")
			if bool(outcome["blocked"]):
				blocked += 1
	_expect(blocked == trials, "control: without a read failure the boss should block every one of these (%d/%d)" % [blocked, trials])


# 보스 코앞에서 맞은 킥은 목표를 어긋나게 잡아도 히트박스를 못 벗어난다.
# 그런 킥은 '기회'가 아니므로 굴림을 소비해선 안 된다 — 이게 표시 확률과 실제
# 미스 확률을 같게 유지하는 계약이다.
func _test_late_contact_never_arms() -> void:
	for start_y in [110.0, 150.0, 200.0]:
		var outcome: Dictionary = _simulate_rally(start_y, 20.0, 0.0, 380.0, false, 1.0)
		_expect(
			not bool(outcome["armed"]),
			"contact at y=%.0f is unreachable, so it must not consume a read-failure roll" % start_y
		)


func _simulate_rally(
	start_y: float,
	speed: float,
	boss_offset: float,
	ball_x: float,
	dash_enabled: bool,
	chance: float,
	start_boss_vel: float = 0.0,
	extra_context: Dictionary = {}
) -> Dictionary:
	seed(int(start_y) * 977 + int(speed) * 131 + int(boss_offset) + int(ball_x) * 7 + (1 if dash_enabled else 0) + int(start_boss_vel * 10.0))
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var builder: Object = BossAiContextBuilder.new()
	var ai: Object = BossAiState.new()
	var detector: Object = BallMotionCollisionDetector.new()

	var ball_pos := Vector2(ball_x, start_y)
	var ball_vel := Vector2(0.0, -speed)
	var boss_center: float = clamp(ball_x + boss_offset, LIMIT_BOSS_PADDLE_WIDTH * 0.5, 760.0 - LIMIT_BOSS_PADDLE_WIDTH * 0.5)
	var boss_pos := Vector2(boss_center - LIMIT_BOSS_PADDLE_WIDTH * 0.5, 25.0)
	var boss_vel := start_boss_vel
	var armed := false

	for _frame in range(400):
		owner.ball_pos = ball_pos
		owner.ball_vel = ball_vel
		owner.boss_pos = boss_pos
		owner.boss_vel = boss_vel
		var context: Dictionary = builder.build_context(owner, registry)
		context["boss_pos"] = boss_pos
		context["boss_paddle_width"] = LIMIT_BOSS_PADDLE_WIDTH
		context["boss_paddle_size"] = Vector2(LIMIT_BOSS_PADDLE_WIDTH, 40.0)
		context["boss_kick_read_failure_chance"] = chance
		context["viper_kick_read_event_id"] = 1
		context["boss_dash_enabled"] = dash_enabled
		context["boss_collision_cooldown"] = 0.0
		context.merge(extra_context, true)

		var result: Dictionary = ai.update(1.0 / 60.0, boss_pos, boss_vel, context)
		boss_pos = result.get("boss_pos", boss_pos)
		boss_vel = float(result.get("boss_vel", boss_vel))
		# ⚠️이 스윕은 궤도가 **한 번도 다시 쓰이지 않는** 단일 킥 랠리다. 따라서
		# 계약은 강한 쪽 — "한 번이라도 armed면 반드시 통과한다"이다. 여기서
		# '접촉 시점 armed'로 재면 마지막 프레임 해제가 안전망으로 작동해 단언이
		# 거의 항상 참이 되고, 감속 배율 누락 같은 결함이 그대로 통과한다(실측).
		# 궤도가 다시 쓰이는 케이스는 _test_unreachable_follow_up_drops_the_latch가
		# 따로 '접촉 시점' 기준으로 본다.
		if ai.prediction_state.kick_read_failure_active:
			armed = true

		ball_pos += ball_vel
		context["boss_pos"] = boss_pos
		var hit: Dictionary = detector.check_paddles(ball_pos, ball_vel, BALL_SIZE, context)
		if str(hit.get("event", "")) == "boss_paddle":
			return {"armed": armed, "blocked": true}
		if ball_pos.y < BOSS_LINE_Y - 40.0:
			return {"armed": armed, "blocked": false}
	return {"armed": armed, "blocked": false}


# --- 굴림 계약 ---------------------------------------------------------------


# 주니어 / 챔피언은 별도 판정이 없다. 킥 이벤트가 와도 **일반 실수 굴림까지
# 포함해** 아무것도 달라지면 안 된다 — 접근 판정을 리셋하면 킥마다 전역 실수
# 기회가 하나씩 더 생겨 "전역 실수율은 건드리지 않는다"는 계약이 깨진다.
func _test_zero_chance_league_is_a_strict_no_op() -> void:
	for seed_value in range(20):
		seed(seed_value)
		var state: Object = BossAiPredictionState.new()
		var context: Dictionary = _base_context({
			"boss_mistake_chance": 1.0,
			"boss_kick_read_failure_chance": 0.0,
			"viper_kick_read_event_id": 0,
		})
		var before: float = _run_prediction(state, 380.0, context)
		var kicked: Dictionary = context.duplicate(true)
		kicked["viper_kick_read_event_id"] = 1
		var after: float = _run_prediction(state, 380.0, kicked)
		if absf(after - before) > 0.001:
			_expect(false, "zero kick-read chance must not re-roll the generic mistake on a kick (%.2f -> %.2f)" % [before, after])
			return


func _test_offset_band_and_wall_clamp() -> void:
	for arrival_x in [380.0, 18.0, 742.0]:
		for seed_value in range(40):
			var context: Dictionary = _base_context({
				"boss_mistake_chance": 0.0,
				"boss_kick_read_failure_chance": 1.0,
				"viper_kick_read_event_id": 1,
				# 보스가 도착점에 정확히 주차된 최악 케이스 = 클램프 뒤집기를 밟는다.
				"boss_center_x": arrival_x,
			})
			seed(seed_value)
			var state: Object = BossAiPredictionState.new()
			var target: float = _run_prediction(state, arrival_x, context)
			var separation: float = absf(target - arrival_x)
			if separation < MISS_THRESHOLD + BossAiPredictionState.KICK_READ_FAILURE_MISS_MARGIN_MIN - 0.001:
				_expect(false, "arrival %.0f: read-failure target still covers the ball (%.2fpx <= %.2fpx)" % [arrival_x, separation, MISS_THRESHOLD])
				return
			if separation > MISS_THRESHOLD + BossAiPredictionState.KICK_READ_FAILURE_MISS_MARGIN_MAX + 0.001:
				_expect(false, "arrival %.0f: offset escaped the configured margin band (%.2fpx)" % [arrival_x, separation])
				return


# per-opportunity 계약: 같은 이벤트 id로 프레임이 흘러도 재굴림하지 않는다.
func _test_single_roll_per_kick_event() -> void:
	seed(11)
	var state: Object = BossAiPredictionState.new()
	var context: Dictionary = _base_context({
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 0.5,
		"viper_kick_read_event_id": 1,
		"boss_center_x": 380.0,
	})
	var first: float = _run_prediction(state, 380.0, context)
	for _frame in range(30):
		if absf(_run_prediction(state, 380.0, context) - first) > 0.001:
			_expect(false, "kick-read failure must be rolled once per kick, not per frame")
			return


# 쉐도우 → 마샬 연계는 '이미 상승 중인' 공의 궤도를 다시 쓴다. 기존 코드는
# approach_decision_active가 이미 서 있어 아무 판정도 다시 하지 않았다.
func _test_new_kick_rerolls_mid_ascent() -> void:
	seed(3)
	var state: Object = BossAiPredictionState.new()
	var opener: Dictionary = _base_context({
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 1.0,
		"viper_kick_read_event_id": 0,
		"boss_center_x": 380.0,
	})
	_expect(absf(_run_prediction(state, 380.0, opener) - 380.0) <= 0.001, "control: no kick event yet, prediction should be exact")
	_expect(absf(_run_prediction(state, 380.0, opener) - 380.0) <= 0.001, "control: the same ascent must not spontaneously start missing")
	var chained: Dictionary = opener.duplicate(true)
	chained["viper_kick_read_event_id"] = 1
	_expect(
		absf(_run_prediction(state, 380.0, chained) - 380.0) >= MISS_THRESHOLD,
		"a kick landing mid-ascent must re-open the read judgement"
	)


func _test_chain_bonus_only_applies_to_chained_kicks() -> void:
	var overrides := {
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 0.0,
		"boss_kick_read_failure_chain_bonus": 1.0,
		"viper_kick_read_event_id": 1,
		"boss_center_x": 380.0,
	}
	var chained: Dictionary = overrides.duplicate(true)
	chained["viper_kick_read_chained_event_id"] = 1
	seed(7)
	var chained_state: Object = BossAiPredictionState.new()
	_expect(
		absf(_run_prediction(chained_state, 380.0, _base_context(chained)) - 380.0) >= MISS_THRESHOLD,
		"shadow-step chained kick should add the chain bonus to the read-failure chance"
	)
	var plain: Dictionary = overrides.duplicate(true)
	plain["viper_kick_read_chained_event_id"] = 0
	seed(7)
	var plain_state: Object = BossAiPredictionState.new()
	_expect(
		absf(_run_prediction(plain_state, 380.0, _base_context(plain)) - 380.0) <= 0.001,
		"non-chained kick must not consume the chain bonus"
	)


# 보스가 대쉬 / 스턴 / 프리즈 조기 return에 걸려 있는 동안 들어온 킥들은 관측이
# 밀린다. id 차이만큼 굴려야 "킥 적중마다 1회"가 지켜진다 — 하나로 합치면
# 연계 도중 대쉬가 끼는 순간 판정이 통째로 사라진다.
func _test_pending_events_are_not_coalesced_into_one_roll() -> void:
	var single := _count_arms_over_seeds(1, 0.3, 400)
	var triple := _count_arms_over_seeds(3, 0.3, 400)
	_expect(single > 80 and single < 165, "sanity: a single pending kick at 0.30 should arm roughly 120/400 (got %d)" % single)
	_expect(
		triple > single + 60,
		"three pending kicks must compound (1-0.7^3 = 0.657), not collapse to one roll (single %d vs triple %d)" % [single, triple]
	)


# 킥이 보스 대쉬/스턴 조기 return 중에 들어오면 그 상승 구간을 통째로 못 본다.
# 그 기회는 끝난 것이므로, 다음 평범한 공(킥 아님)이 올라올 때 지난 pending을
# 뒤늦게 승인해 읽기 실패를 걸면 안 된다.
func _test_expired_pending_never_lands_on_a_later_ordinary_ball() -> void:
	# 만료 경로는 둘이다(하강 전환 / 서브·비활성 리셋). 하나만 검사하면 다른 쪽
	# 구멍이 그대로 살아남으므로 각각 따로 돌린다.
	for expire_via_reset in [false, true]:
		for seed_value in range(20):
			seed(seed_value)
			var state: Object = BossAiPredictionState.new()
			var kicked: Dictionary = _base_context({
				"boss_mistake_chance": 0.0,
				"boss_kick_read_failure_chance": 1.0,
				"viper_kick_read_event_id": 1,
				"boss_center_x": 380.0,
			})
			# 상승 구간을 통째로 건너뛴다(= 보스가 대쉬 중이라 예측이 안 돌았다).
			if expire_via_reset:
				state.reset(kicked)
			else:
				state.predict_future_x(Vector2(380.0, 200.0), Vector2(0.0, 8.0), 1.0, 0.0, 760.0, LIMIT_BOSS_PADDLE_WIDTH, kicked)
			# 다음 랠리의 평범한 상승 공 — 새 킥 이벤트는 없다.
			var target: float = _run_prediction(state, 380.0, kicked.duplicate(true))
			if absf(target - 380.0) > 0.001:
				_expect(false, "an expired kick event must not apply a read failure to a later ordinary ball (expire_via_reset=%s, %.2f)" % [str(expire_via_reset), target])
				return


# ⚠️예측기를 직접 부르는 만료 레그는 **생산 조기 return을 우회한다**. 스톱워치
# 동결 / 스테이지2 이동잠금은 예측 호출 자체에 도달하지 않으므로, 실제
# BossAiState.update()를 관통해야만 이 구멍이 잡힌다.
func _test_producer_early_returns_still_expire_the_opportunity() -> void:
	for blocker in ["active_item_stopwatch_freeze_active", "stage2_boss_movement_locked", "lingpet_puppet_grab_active"]:
		var stale: bool = _run_early_return_expiry_probe(blocker)
		_expect(
			not stale,
			"a kick landing during '%s' must not arm a read failure on the next ordinary ball" % blocker
		)


func _run_early_return_expiry_probe(blocker: String) -> bool:
	seed(17)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var builder: Object = BossAiContextBuilder.new()
	var ai: Object = BossAiState.new()
	var boss_pos := Vector2(380.0 - LIMIT_BOSS_PADDLE_WIDTH * 0.5, 25.0)

	# 1) 조기 return 상태에서 킥 이벤트가 들어온다(공은 아직 상승 중).
	for _frame in range(6):
		var blocked_context: Dictionary = _make_probe_context(builder, owner, registry, boss_pos, Vector2(380.0, 400.0), Vector2(0.0, -20.0), 1)
		blocked_context[blocker] = true
		ai.update(1.0 / 60.0, boss_pos, 0.0, blocked_context)
	# 2) 같은 조기 return 상태에서 공이 하강으로 전환된다 = 기회 종료.
	for _frame in range(6):
		var descend_context: Dictionary = _make_probe_context(builder, owner, registry, boss_pos, Vector2(380.0, 300.0), Vector2(0.0, 20.0), 1)
		descend_context[blocker] = true
		ai.update(1.0 / 60.0, boss_pos, 0.0, descend_context)
	# 3) 상태가 풀리고 다음 평범한 상승 공이 온다(새 킥 이벤트 없음).
	var ordinary: Dictionary = _make_probe_context(builder, owner, registry, boss_pos, Vector2(380.0, 700.0), Vector2(0.0, -20.0), 1)
	ai.update(1.0 / 60.0, boss_pos, 0.0, ordinary)
	return bool(ai.prediction_state.kick_read_failure_active)


func _make_probe_context(
	builder: Object,
	owner: Object,
	registry: Object,
	boss_pos: Vector2,
	ball_pos: Vector2,
	ball_vel: Vector2,
	event_id: int
) -> Dictionary:
	owner.ball_pos = ball_pos
	owner.ball_vel = ball_vel
	owner.boss_pos = boss_pos
	var context: Dictionary = builder.build_context(owner, registry)
	context["boss_pos"] = boss_pos
	context["boss_paddle_width"] = LIMIT_BOSS_PADDLE_WIDTH
	context["boss_paddle_size"] = Vector2(LIMIT_BOSS_PADDLE_WIDTH, 40.0)
	context["boss_kick_read_failure_chance"] = 1.0
	context["viper_kick_read_event_id"] = event_id
	context["boss_dash_enabled"] = false
	context["boss_collision_cooldown"] = 0.0
	return context


# 후속 킥이 공을 보스 코앞으로 다시 보내면 그 궤도에서는 회피가 불가능하다.
# 그때도 래치를 들고 있으면 armed인 채로 막히는 거짓 약속이 된다.
func _test_unreachable_follow_up_drops_the_latch() -> void:
	for follow_up_y in [260.0, 220.0, 180.0, 150.0]:
		for follow_up_v in [20.0, 26.0, 32.0]:
			var outcome: Dictionary = _simulate_follow_up_rally(follow_up_y, follow_up_v)
			if bool(outcome["armed_at_contact"]) and bool(outcome["blocked"]):
				_expect(false, "unreachable follow-up (y=%.0f v=%.0f) kept the latch and was blocked" % [follow_up_y, follow_up_v])
				return


func _simulate_follow_up_rally(follow_up_y: float, follow_up_v: float) -> Dictionary:
	seed(int(follow_up_y) * 31 + int(follow_up_v))
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var builder: Object = BossAiContextBuilder.new()
	var ai: Object = BossAiState.new()
	var detector: Object = BallMotionCollisionDetector.new()
	var boss_pos := Vector2(380.0 - LIMIT_BOSS_PADDLE_WIDTH * 0.5, 25.0)
	var boss_vel := 0.0

	# 오프너: 여유 있는 궤도에서 읽기 실패를 확정시킨다.
	var ball_pos := Vector2(380.0, 700.0)
	var ball_vel := Vector2(0.0, -20.0)
	for _frame in range(6):
		var context: Dictionary = _make_probe_context(builder, owner, registry, boss_pos, ball_pos, ball_vel, 1)
		var result: Dictionary = ai.update(1.0 / 60.0, boss_pos, boss_vel, context)
		boss_pos = result.get("boss_pos", boss_pos)
		boss_vel = float(result.get("boss_vel", boss_vel))
		ball_pos += ball_vel

	# 후속 킥: 궤도를 보스 코앞으로 다시 쓴다.
	ball_pos = Vector2(boss_pos.x + LIMIT_BOSS_PADDLE_WIDTH * 0.5, follow_up_y)
	ball_vel = Vector2(0.0, -follow_up_v)
	var armed_at_contact := false
	for _frame in range(400):
		var context: Dictionary = _make_probe_context(builder, owner, registry, boss_pos, ball_pos, ball_vel, 2)
		var result: Dictionary = ai.update(1.0 / 60.0, boss_pos, boss_vel, context)
		boss_pos = result.get("boss_pos", boss_pos)
		boss_vel = float(result.get("boss_vel", boss_vel))
		armed_at_contact = bool(ai.prediction_state.kick_read_failure_active)
		ball_pos += ball_vel
		context["boss_pos"] = boss_pos
		var hit: Dictionary = detector.check_paddles(ball_pos, ball_vel, BALL_SIZE, context)
		if str(hit.get("event", "")) == "boss_paddle":
			return {"armed_at_contact": armed_at_contact, "blocked": true}
		if ball_pos.y < BOSS_LINE_Y - 40.0:
			return {"armed_at_contact": armed_at_contact, "blocked": false}
	return {"armed_at_contact": armed_at_contact, "blocked": false}


# 리졸버 출력 **뒤에** 붙는 이동 후처리를 시뮬레이션이 빼먹으면 게이트가 거짓말을
# 한다. 후처리는 하나가 아니다 — 감속 배율 계열과 비누 미끄러짐(마지막 단계)을
# 각각 축으로 돌려야 한 쪽만 미러링한 상태가 통과하지 않는다.
func _test_movement_slow_debuffs_are_respected_by_the_gate() -> void:
	var post_processing_cases: Array = [
		{"label": "spider mine 0.2", "ctx": {"active_item_spider_mine_slow_active": true, "active_item_spider_mine_slow_factor": 0.2}},
		{"label": "spider mine 0.4", "ctx": {"active_item_spider_mine_slow_active": true, "active_item_spider_mine_slow_factor": 0.4}},
		{"label": "spider mine 0.7", "ctx": {"active_item_spider_mine_slow_active": true, "active_item_spider_mine_slow_factor": 0.7}},
		{"label": "soap slip (default)", "ctx": {"active_item_soap_slip_active": true}},
		{"label": "soap slip (sticky)", "ctx": {"active_item_soap_slip_active": true, "active_item_soap_slip_blend": 0.08, "active_item_soap_slip_friction": 0.97}},
		{"label": "soap + spider mine", "ctx": {"active_item_soap_slip_active": true, "active_item_spider_mine_slow_active": true, "active_item_spider_mine_slow_factor": 0.4}},
		{"label": "dalji whip clamp", "ctx": {"stage1_dalji_whip_active": true}},
		{"label": "molotov slow", "ctx": {"active_item_molotov_slow_active": true, "active_item_molotov_slow_factor": 0.35}},
		{"label": "lingpet dwarf slow", "ctx": {"lingpet_dwarf_magic_boss_slow_active": true, "lingpet_dwarf_magic_boss_slow_multiplier": 0.3}},
		# 아래 둘은 리졸버 인자(반응/감속 배율)를 바꾸는 분기다. 보스를 더 빠르게
		# 만드는 방향이라 시뮬레이션이 이를 무시해도 '거짓 약속'은 안 나야 하는데,
		# 그 추론을 가정으로 두지 않고 축으로 돌려 확인한다.
		{"label": "stage2 speed defense", "ctx": {"stage2_speed_defense_active": true, "stage2_speed_defense_speed_multiplier": 1.8, "stage2_speed_defense_turn_multiplier": 1.6, "stage2_speed_defense_initial_speed_ratio": 0.5}},
		{"label": "whip deactivation drive", "ctx": {"stage1_dalji_whip_deactivation_active": true, "stage1_dalji_whip_deactivation_progress": 0.5}},
	]
	for start_y in [400.0, 500.0, 600.0, 700.0]:
		for speed in [14.0, 20.0, 26.0]:
			for entry in post_processing_cases:
				var outcome: Dictionary = _simulate_rally(start_y, speed, 0.0, 380.0, false, 1.0, 0.0, entry["ctx"])
				if bool(outcome["armed"]) and bool(outcome["blocked"]):
					_expect(false, "post-processed boss (y=%.0f v=%.0f, %s) armed a read failure it could not deliver" % [start_y, speed, str(entry["label"])])
					return


# 연계로 다시 때렸다고 이미 얻은 우위를 잃으면 '연계할수록 나빠지는' 역설이 된다.
func _test_chained_kick_keeps_an_already_won_read_failure() -> void:
	seed(9)
	var state: Object = BossAiPredictionState.new()
	var opener: Dictionary = _base_context({
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 1.0,
		"viper_kick_read_event_id": 1,
		"boss_center_x": 380.0,
	})
	_expect(absf(_run_prediction(state, 380.0, opener) - 380.0) >= MISS_THRESHOLD, "fixture: opener kick should win the read")
	# 후속 마샬의 굴림은 사실상 실패하지만(확률 0.0001), **확률 0이면 안 된다** —
	# 0이면 "판정 없는 리그" 조기 return으로 빠져 래치 유지 분기를 안 밟는다(변별력 0).
	var follow_up: Dictionary = opener.duplicate(true)
	follow_up["viper_kick_read_event_id"] = 2
	follow_up["boss_kick_read_failure_chance"] = 0.0001
	follow_up["boss_kick_read_failure_chain_bonus"] = 0.0
	_expect(
		absf(_run_prediction(state, 380.0, follow_up) - 380.0) >= MISS_THRESHOLD,
		"a follow-up kick must not cancel a read failure the player already won"
	)


# 승인된 계약 = 두 기회의 합집합. 극한 1-(1-0.12)(1-0.16) = 0.261.
# 최신 chained 플래그를 모든 굴림에 재사용하면 0.16 두 번(0.294)이 되고,
# 새 이벤트가 기존 래치를 지우면 마지막 굴림 하나(0.16)로 접힌다.
func _test_full_chain_probability_matches_the_designed_union() -> void:
	var trials := 3000
	var armed := 0
	for seed_value in range(trials):
		seed(seed_value)
		var state: Object = BossAiPredictionState.new()
		var shadow: Dictionary = _base_context({
			"boss_mistake_chance": 0.0,
			"boss_kick_read_failure_chance": BossAiContextBuilder.LIMIT_BOSS_KICK_READ_FAILURE_CHANCE,
			"boss_kick_read_failure_chain_bonus": BossAiContextBuilder.BOSS_KICK_READ_FAILURE_CHAIN_BONUS,
			"viper_kick_read_event_id": 1,
			"viper_kick_read_chained_event_id": 0,
			"boss_center_x": 380.0,
		})
		_run_prediction(state, 380.0, shadow)
		var marshal: Dictionary = shadow.duplicate(true)
		marshal["viper_kick_read_event_id"] = 2
		marshal["viper_kick_read_chained_event_id"] = 1
		_run_prediction(state, 380.0, marshal)
		if state.kick_read_failure_active:
			armed += 1
	var rate: float = float(armed) / float(trials)
	_expect(
		rate > 0.235 and rate < 0.288,
		"full shadow->marshal chain should land near the designed 0.261 union (measured %.3f)" % rate
	)


func _count_arms_over_seeds(pending: int, chance: float, trials: int) -> int:
	var arms := 0
	for seed_value in range(trials):
		seed(seed_value)
		var state: Object = BossAiPredictionState.new()
		var context: Dictionary = _base_context({
			"boss_mistake_chance": 0.0,
			"boss_kick_read_failure_chance": chance,
			"viper_kick_read_event_id": pending,
			"boss_center_x": 380.0,
		})
		_run_prediction(state, 380.0, context)
		if state.kick_read_failure_active:
			arms += 1
	return arms


# --- 리그 프로파일 -----------------------------------------------------------


func _test_league_profile_chances() -> void:
	var builder: Object = BossAiContextBuilder.new()
	var registry := FakeRegistry.new()

	var limit_owner := FakeOwner.new()
	limit_owner.ai_mode = "limit"
	var limit_context: Dictionary = builder.build_context(limit_owner, registry)
	_expect(
		absf(float(limit_context.get("boss_kick_read_failure_chance", -1.0)) - BossAiContextBuilder.LIMIT_BOSS_KICK_READ_FAILURE_CHANCE) <= 0.0001,
		"limit league boss context should publish the limit kick-read chance"
	)
	_expect(
		absf(float(limit_context.get("boss_kick_read_failure_chain_bonus", -1.0)) - BossAiContextBuilder.BOSS_KICK_READ_FAILURE_CHAIN_BONUS) <= 0.0001,
		"limit league boss context should publish the chain bonus"
	)
	_expect(
		absf(float(limit_context.get("boss_center_x", -1.0)) - (limit_owner.boss_pos.x + LIMIT_BOSS_PADDLE_WIDTH * 0.5)) <= 0.01,
		"boss context must publish boss_center_x for the evasion-direction / reachability checks"
	)

	var mythic_owner := FakeOwner.new()
	mythic_owner.ai_mode = "mythic"
	mythic_owner.current_stage = 8
	var mythic_context: Dictionary = builder.build_context(mythic_owner, registry)
	_expect(
		absf(float(mythic_context.get("boss_kick_read_failure_chance", -1.0)) - BossAiContextBuilder.MYTHIC_BOSS_KICK_READ_FAILURE_CHANCE) <= 0.0001,
		"mythic kick-read chance must NOT decay with stage (unlike the generic mistake rate)"
	)

	for easy_mode in ["champion", "junior"]:
		var easy_owner := FakeOwner.new()
		easy_owner.ai_mode = easy_mode
		var easy_context: Dictionary = builder.build_context(easy_owner, registry)
		_expect(
			absf(float(easy_context.get("boss_kick_read_failure_chance", -1.0))) <= 0.0001,
			"%s league should keep the generic mistake model (no separate kick-read roll)" % easy_mode
		)


# --- 이벤트 발행 계약 --------------------------------------------------------


func _test_shadow_step_hit_publishes_event() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var deps: Dictionary = _build_viper_deps()
	var config := _viper_config(Vector2(472.5, 705.0))
	runtime.dash_origin_pos = Vector2(120.0, 680.0)
	runtime.dash_origin_valid = true
	runtime.dash_grace_frames = 36.0
	deps["input_reader"].snapshot["down_pressed"] = true
	var activation: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, Vector2(420.0, 680.0), 300.0, config, deps)
	_expect(bool(activation.get("activated", false)), "fixture: shadow step should activate")
	_expect(int(runtime.kick_read_event_id) == 0, "activation alone must not publish a kick-read event (hit-only contract)")

	var scene := {
		"ball_pos": Vector2(472.5, 705.0),
		"ball_vel": Vector2(0.0, -8.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}
	var motion_context: Dictionary = config.duplicate(true)
	motion_context.merge(scene, true)
	var hit: Dictionary = runtime.apply_shadow_step_ball_motion(1.0, scene, motion_context, deps)
	_expect(hit.has("ball_vel"), "fixture: shadow step wave should hit the ball")
	_expect(int(runtime.kick_read_event_id) == 1, "shadow step ball hit should publish exactly one kick-read event")
	_expect(int(runtime.kick_read_chained_event_id) == 0, "shadow step opens the chain, so its own event is not chained")

	var published: Dictionary = runtime.get_boss_ai_context()
	_expect(int(published.get("viper_kick_read_event_id", -1)) == 1, "boss AI context should carry the kick-read event id")
	_expect(int(published.get("viper_kick_read_chained_event_id", -1)) == 0, "boss AI context should carry the chained serial")


func _test_normal_marshal_publishes_chained_event() -> void:
	var runtime: Object = _make_marshal_charge_runtime(false)
	var deps: Dictionary = _build_viper_deps()
	var result: Dictionary = {}
	runtime._update_marshal_charge_phase(_viper_config(Vector2(400.0, 300.0)), deps, result)
	_expect(bool(runtime.marshal_ball_hit), "fixture: marshal charge should have connected with the ball")
	_expect(int(runtime.kick_read_event_id) == 1, "marshal charge hit should publish exactly one kick-read event")
	_expect(int(runtime.kick_read_chained_event_id) == 1, "a marshal kick chained from shadow step should bump the chained serial")


# 팬텀 킥(더블 마샬)은 같은 _apply_charge_hit을 지나지만 새 기회가 아니다.
# 발행하면 풀연계가 2회가 아니라 3회 판정을 받아 극한 26% -> 37.9%로 부푼다.
func _test_double_marshal_does_not_publish_a_third_event() -> void:
	var runtime: Object = _make_marshal_charge_runtime(true)
	var deps: Dictionary = _build_viper_deps()
	var result: Dictionary = {}
	runtime._update_marshal_charge_phase(_viper_config(Vector2(400.0, 300.0)), deps, result)
	_expect(bool(runtime.marshal_ball_hit), "fixture: double marshal charge should have connected with the ball")
	_expect(
		int(runtime.kick_read_event_id) == 0,
		"double marshal (phantom kick) is the second half of the marshal opportunity, not a third roll"
	)


# 단조 serial 계약. 라운드 리셋이 id를 0으로 되감으면 ABA가 난다 — 소비자는
# 하강 프레임에서 관측 전에 조기 return하므로 되감김을 못 보고, 다음 라운드
# 첫 킥이 같은 id가 되어 "이미 본 이벤트"로 오인돼 판정이 통째로 생략된다.
func _test_round_reset_keeps_the_serial_monotonic() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	runtime.mark_kick_read_event(true)
	runtime.mark_kick_read_event(false)
	var before: int = int(runtime.kick_read_event_id)
	runtime.reset_round(_build_viper_deps())
	_expect(
		int(runtime.kick_read_event_id) >= before,
		"round reset must NOT rewind the kick-read serial (%d -> %d)" % [before, int(runtime.kick_read_event_id)]
	)

	# 소비자 쪽 재현: 라운드 A 킥 -> 하강(관측 전 조기 return) -> 라운드 B 첫 킥.
	seed(4)
	var state: Object = BossAiPredictionState.new()
	var round_a: Dictionary = _base_context({
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 1.0,
		"viper_kick_read_event_id": 1,
		"boss_center_x": 380.0,
	})
	_expect(absf(_run_prediction(state, 380.0, round_a) - 380.0) >= MISS_THRESHOLD, "round A kick should roll")
	var descending: Dictionary = round_a.duplicate(true)
	for _frame in range(20):
		state.predict_future_x(Vector2(380.0, 200.0), Vector2(0.0, 8.0), 1.0, 0.0, 760.0, LIMIT_BOSS_PADDLE_WIDTH, descending)
	var round_b: Dictionary = round_a.duplicate(true)
	round_b["viper_kick_read_event_id"] = 2
	_expect(
		absf(_run_prediction(state, 380.0, round_b) - 380.0) >= MISS_THRESHOLD,
		"the first kick of the next round must still get a read judgement"
	)


# --- helpers -----------------------------------------------------------------


func _make_marshal_charge_runtime(is_double: bool) -> Object:
	var runtime: Object = ViperSkillRuntime.new()
	var ball_pos := Vector2(400.0, 300.0)
	runtime.marshal_active = true
	runtime.marshal_phase = 2
	runtime.marshal_phase_frames = 0.0
	runtime.marshal_ball_hit = false
	runtime.marshal_is_double = is_double
	runtime.marshal_phantom_allowed = false
	runtime.marshal_wall_side = -1
	runtime.marshal_wall_pos = Vector2(0.0, 400.0)
	# 차지 시작점을 목표(공 중심)에 두면 진행도와 무관하게 hit_radius 안이다.
	runtime.marshal_charge_start_pos = ball_pos - Vector2(155.0, 50.0) * 0.5
	runtime.marshal_from_shadow_step_chain = true
	return runtime


func _viper_config(ball_pos: Vector2) -> Dictionary:
	return {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"ball_size": BALL_SIZE,
		"boss_pos": Vector2(380.0, 45.0),
		"ball_pos": ball_pos,
		"ball_vel": Vector2(0.0, -8.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
	}


func _build_viper_deps() -> Dictionary:
	return {
		"input_reader": FakeInput.new(),
		"skill_config": FakeSkillConfig.new(),
		"skill_state": FakeSkillState.new(),
		"orb_hud_state": FakeOrbHud.new(),
		"audio": FakeAudio.new(),
		"feedback": FakeFeedback.new(),
		"runtime_perk_state": FakePerkState.new(),
		"ball_physics": FakeBallPhysics.new(),
	}


func _base_context(overrides: Dictionary) -> Dictionary:
	var context := {
		"ai_mode": "limit",
		"play_left": 0.0,
		"play_right": 760.0,
		"hitbox_padding": HITBOX_PADDING,
		"ball_size": BALL_SIZE,
		"boss_y": 25.0,
		"boss_hitbox_height": 40.0,
		# 극한 스테이지3 실측 이동 파라미터 — 도달 가능성 게이트가 이걸 읽는다.
		"boss_movement_accel": 1.4082,
		"boss_movement_max_speed": 11.1497,
	}
	context.merge(overrides, true)
	return context


# 수직 상승(vx = 0)이라 도착 x == 현재 x — 목표와 도착점의 분리 거리를 그대로 잰다.
# y=700은 실제 킥 접점(플레이어 패들 부근)이라 도달 가능성 게이트를 통과한다.
func _run_prediction(state: Object, arrival_x: float, context: Dictionary) -> float:
	return float(state.predict_future_x(
		Vector2(arrival_x, 700.0),
		Vector2(0.0, -8.0),
		1.0,
		0.0,
		760.0,
		LIMIT_BOSS_PADDLE_WIDTH,
		context
	))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
