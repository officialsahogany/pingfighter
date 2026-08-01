extends SceneTree

# 킥 읽기 실패(쉐도우 백스텝 / 마샬 킥 적중 1회당 1굴림) 봉인.
#
# 회귀 대상: 극한/초월 리그에서 두 무공이 사실상 100% 막히던 문제. 일반 실수
# 오차 상한(80px / 20px)이 보스 미스 임계(패들 반폭 + hitbox padding + 공 반폭)
# 보다 작아서, 실수가 나도 보스가 그대로 막았다.
#
# 이 씰이 지키는 계약 3개:
#   1) 당첨 시 목표가 '실제 도착 x'에서 미스 임계를 넘겨 벌어진다(벽 근처 포함).
#   2) 굴림은 킥 적중 1회당 1번이다(프레임마다 재굴림 금지).
#   3) 이벤트 발행은 실제 타격 경로에서 일어난다(쉐도우 백스텝 / 마샬 차지 히트).

const BossAiPredictionState := preload("res://scripts/ai/boss_ai_prediction_state.gd")
const BossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")

# 극한 리그 실측: 패들 100 * 1.07 = 107 → 53.5 + 5(padding) + 14.3(공 반폭) = 72.8
const LIMIT_BOSS_PADDLE_WIDTH: float = 107.0
const HITBOX_PADDING: float = 5.0
const BALL_SIZE: float = 28.6
const MISS_THRESHOLD: float = LIMIT_BOSS_PADDLE_WIDTH * 0.5 + HITBOX_PADDING + BALL_SIZE * 0.5

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 3
	var ai_mode := "limit"
	var ball_active := true
	var player_pos := Vector2(200.0, 690.0)
	var ball_pos := Vector2(320.0, 410.0)
	var ball_vel := Vector2(0.0, -8.0)
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
	_test_zero_chance_league_keeps_exact_prediction()
	_test_forced_failure_clears_the_boss_paddle()
	_test_failure_survives_wall_clamp()
	_test_chain_bonus_only_applies_to_chained_kicks()
	_test_single_roll_per_kick_event()
	_test_new_kick_rerolls_mid_ascent()
	_test_flinch_signal_is_one_shot()
	_test_league_profile_chances()
	_test_shadow_step_hit_publishes_event()
	_test_marshal_charge_hit_publishes_chained_event()

	if _failures.is_empty():
		print("boss_kick_read_failure_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# --- 예측 계약 -------------------------------------------------------------


# 주니어 / 챔피언은 별도 판정을 받지 않는다(확률 0). 킥 이벤트가 와도 예측이
# 흔들리면 안 된다 — 전역 실수율을 건드리지 않는다는 계약의 봉인.
func _test_zero_chance_league_keeps_exact_prediction() -> void:
	for seed_value in range(24):
		var target: float = _predict(380.0, seed_value, {
			"boss_mistake_chance": 0.0,
			"boss_kick_read_failure_chance": 0.0,
			"viper_kick_read_event_id": 1,
		})
		if absf(target - 380.0) > 0.001:
			_expect(false, "0% kick-read chance should leave the prediction untouched (got %.2f)" % target)
			return


func _test_forced_failure_clears_the_boss_paddle() -> void:
	for seed_value in range(40):
		var target: float = _predict(380.0, seed_value, {
			"boss_mistake_chance": 0.0,
			"boss_kick_read_failure_chance": 1.0,
			"viper_kick_read_event_id": 1,
		})
		var separation: float = absf(target - 380.0)
		if separation < MISS_THRESHOLD + BossAiPredictionState.KICK_READ_FAILURE_MISS_MARGIN_MIN - 0.001:
			_expect(false, "forced kick-read failure must clear the boss hitbox (%.2fpx <= %.2fpx threshold)" % [separation, MISS_THRESHOLD])
			return
		if separation > MISS_THRESHOLD + BossAiPredictionState.KICK_READ_FAILURE_MISS_MARGIN_MAX + 0.001:
			_expect(false, "kick-read failure offset should stay inside the configured margin band (got %.2fpx)" % separation)
			return


# 도착 x가 벽에 붙어 있으면 굴림 방향에 따라 목표 클램프가 오프셋을 통째로
# 먹는다 — 그 케이스에서 방향을 뒤집지 않으면 보스는 그대로 막는다.
func _test_failure_survives_wall_clamp() -> void:
	for arrival_x in [18.0, 742.0]:
		for seed_value in range(40):
			var target: float = _predict(arrival_x, seed_value, {
				"boss_mistake_chance": 0.0,
				"boss_kick_read_failure_chance": 1.0,
				"viper_kick_read_event_id": 1,
			})
			var separation: float = absf(target - arrival_x)
			if separation < MISS_THRESHOLD + BossAiPredictionState.KICK_READ_FAILURE_MISS_MARGIN_MIN - 0.001:
				_expect(false, "wall-side arrival %.0f: clamped kick-read failure still covers the ball (%.2fpx)" % [arrival_x, separation])
				return


func _test_chain_bonus_only_applies_to_chained_kicks() -> void:
	var chained: float = _predict(380.0, 7, {
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 0.0,
		"boss_kick_read_failure_chain_bonus": 1.0,
		"viper_kick_read_event_id": 1,
		"viper_kick_read_event_chained": true,
	})
	_expect(
		absf(chained - 380.0) >= MISS_THRESHOLD,
		"shadow-step chained kick should add the chain bonus to the read-failure chance"
	)
	var unchained: float = _predict(380.0, 7, {
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 0.0,
		"boss_kick_read_failure_chain_bonus": 1.0,
		"viper_kick_read_event_id": 1,
		"viper_kick_read_event_chained": false,
	})
	_expect(
		absf(unchained - 380.0) <= 0.001,
		"non-chained kick must not consume the chain bonus (got %.2f)" % unchained
	)


# per-opportunity 계약: 같은 이벤트 id로 프레임이 계속 흘러도 재굴림하지 않는다.
# (매 프레임 굴리면 확률이 사실상 100%로 붙고 리그 스케일링이 죽는다.)
func _test_single_roll_per_kick_event() -> void:
	seed(11)
	var state: Object = BossAiPredictionState.new()
	var context: Dictionary = _base_context({
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 0.5,
		"viper_kick_read_event_id": 1,
	})
	var first: float = _run_prediction(state, 380.0, context)
	for _frame in range(30):
		var later: float = _run_prediction(state, 380.0, context)
		if absf(later - first) > 0.001:
			_expect(false, "kick-read failure must be rolled once per kick, not per frame")
			return


# 쉐도우 → 마샬 연계는 '이미 상승 중인' 공의 궤도를 다시 쓴다. 기존 코드는
# approach_decision_active가 이미 서 있어 아무 판정도 다시 하지 않았다.
func _test_new_kick_rerolls_mid_ascent() -> void:
	seed(3)
	var state: Object = BossAiPredictionState.new()
	var opener_context: Dictionary = _base_context({
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 1.0,
		"viper_kick_read_event_id": 0,
	})
	var opener: float = _run_prediction(state, 380.0, opener_context)
	_expect(absf(opener - 380.0) <= 0.001, "control leg: no kick event yet, prediction should be exact")
	var holdover: float = _run_prediction(state, 380.0, opener_context)
	_expect(absf(holdover - 380.0) <= 0.001, "control leg: the same ascent must not spontaneously start missing")

	var chain_context: Dictionary = _base_context({
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 1.0,
		"viper_kick_read_event_id": 1,
	})
	var chained: float = _run_prediction(state, 380.0, chain_context)
	_expect(
		absf(chained - 380.0) >= MISS_THRESHOLD,
		"a kick landing mid-ascent must re-open the read judgement (got %.2f)" % chained
	)


func _test_flinch_signal_is_one_shot() -> void:
	seed(5)
	var state: Object = BossAiPredictionState.new()
	var context: Dictionary = _base_context({
		"boss_mistake_chance": 0.0,
		"boss_kick_read_failure_chance": 1.0,
		"viper_kick_read_event_id": 1,
	})
	_run_prediction(state, 380.0, context)
	_expect(bool(state.consume_kick_read_failure_flinch()), "a confirmed read failure should arm the boss flinch once")
	_expect(not bool(state.consume_kick_read_failure_flinch()), "the flinch signal must not re-fire on later frames")


# --- 리그 프로파일 ---------------------------------------------------------


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


# --- 실제 타격 경로에서의 이벤트 발행 --------------------------------------


func _test_shadow_step_hit_publishes_event() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var deps: Dictionary = _build_viper_deps()
	var config := {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(380.0, 45.0),
		"ball_pos": Vector2(472.5, 705.0),
		"ball_vel": Vector2(0.0, -8.0),
	}
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
	_expect(not bool(runtime.kick_read_event_chained), "shadow step opens the chain, so its own event is not chained")

	var published: Dictionary = runtime.get_boss_ai_context()
	_expect(int(published.get("viper_kick_read_event_id", -1)) == 1, "boss AI context should carry the kick-read event id")
	_expect(published.has("viper_kick_read_event_chained"), "boss AI context should carry the chained flag")


func _test_marshal_charge_hit_publishes_chained_event() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var deps: Dictionary = _build_viper_deps()
	var ball_pos := Vector2(400.0, 300.0)
	var config := {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(380.0, 45.0),
		"ball_pos": ball_pos,
		"ball_vel": Vector2(0.0, -8.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
	}
	# 차지 시작점을 목표(공 중심)에 두면 진행도와 무관하게 hit_radius 안이다.
	runtime.marshal_active = true
	runtime.marshal_phase = 2
	runtime.marshal_phase_frames = 0.0
	runtime.marshal_ball_hit = false
	runtime.marshal_is_double = false
	runtime.marshal_phantom_allowed = false
	runtime.marshal_wall_side = -1
	runtime.marshal_wall_pos = Vector2(0.0, 400.0)
	runtime.marshal_charge_start_pos = ball_pos - Vector2(155.0, 50.0) * 0.5
	runtime.marshal_from_shadow_step_chain = true

	var result: Dictionary = {}
	runtime._update_marshal_charge_phase(config, deps, result)
	_expect(bool(runtime.marshal_ball_hit), "fixture: marshal charge should have connected with the ball")
	_expect(int(runtime.kick_read_event_id) == 1, "marshal charge hit should publish exactly one kick-read event")
	_expect(bool(runtime.kick_read_event_chained), "a marshal kick chained from shadow step should flag the chain bonus")


# --- helpers ---------------------------------------------------------------


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
	}
	context.merge(overrides, true)
	return context


func _predict(arrival_x: float, seed_value: int, overrides: Dictionary) -> float:
	seed(seed_value)
	var state: Object = BossAiPredictionState.new()
	return _run_prediction(state, arrival_x, _base_context(overrides))


# 수직 상승(vx = 0)이라 도착 x == 현재 x — 목표와 도착점의 분리 거리를 그대로 잰다.
func _run_prediction(state: Object, arrival_x: float, context: Dictionary) -> float:
	return float(state.predict_future_x(
		Vector2(arrival_x, 500.0),
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
