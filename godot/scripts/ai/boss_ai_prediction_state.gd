extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")

const BOSS_ACCURACY: float = 1.0
const BOSS_ACCURACY_ERROR: float = 60.0
const BOSS_MISTAKE_CHANCE: float = 0.10
const BOSS_MISTAKE_ERROR_MIN: float = 78.0
const BOSS_MISTAKE_ERROR_MAX: float = 140.0
const BOSS_MISTAKE_SPEED_SCALE: float = 4.5
const JUNIOR_POWER_SMASH_MISTAKE_CHANCE: float = 0.80
const JUNIOR_POWER_SMASH_MISTAKE_ERROR_MIN: float = 170.0
const JUNIOR_POWER_SMASH_MISTAKE_ERROR_MAX: float = 260.0
const JUNIOR_POWER_SMASH_MISTAKE_SPEED_SCALE: float = 7.0
const BOSS_FAST_BALL_SPEED: float = 15.0
const BOSS_MEDIUM_BALL_SPEED: float = 10.0
const BOSS_FAST_PREDICT_FRAMES: float = 8.0
const BOSS_MEDIUM_PREDICT_FRAMES: float = 12.0
const BOSS_SLOW_PREDICT_FRAMES: float = 20.0
const WALL_REFLECTION_LIMIT: int = 4
const PREDICTION_SIMULATION_MAX_FRAMES: int = 120
# 킥 읽기 실패(쉐도우 백스텝 / 마샬 킥 적중 1회당 1굴림)가 당첨됐을 때, 보스가
# 확실히 비켜나도록 미스 임계(패들 반폭 + hitbox padding + 공 반폭)에 더 얹는 여유.
# 임계 그대로면 경계 케이스에서 그대로 막히므로 최소 마진을 둔다.
const KICK_READ_FAILURE_MISS_MARGIN_MIN: float = 6.0
const KICK_READ_FAILURE_MISS_MARGIN_MAX: float = 10.0
# 조기 return(대쉬 / 스턴 / 프리즈) 뒤에 밀린 킥 이벤트를 몰아서 굴릴 때의 상한.
const KICK_READ_MAX_PENDING_ROLLS: int = 4
const KICK_READ_REACH_SIM_MAX_FRAMES: int = 240
# 읽기 실패 확정 직후 보스의 '흠칫' 창(boss_ai_state가 소비). 도달 가능성 게이트가
# 이 비용을 알아야 하므로 값의 정본은 여기다 — 흠칫은 회피를 ~4.5프레임 늦춘다.
const KICK_READ_FLINCH_FRAMES: float = 9.0
const KICK_READ_FLINCH_REACTION_MULT: float = 0.4

var approach_decision_active := false
var approach_mistake_active := false
var boss_fail_error_offset: float = 0.0
# 마지막으로 관측한 바이퍼 킥 적중 이벤트 id. 이벤트는 단조 증가하며 라운드
# 리셋 시 0으로 돌아온다 — 0은 "이벤트 없음"이라 굴리지 않는다.
# ⚠️reset()에서 지우지 않는다. 지우면 남아있는 non-zero 소유자 id가 다음
# 프레임에 곧바로 '새 이벤트'로 오인돼 무관한 랠리에서 읽기 실패가 터진다.
var kick_read_event_id: int = 0
var kick_read_failure_active := false
var kick_read_failure_offset: float = 0.0
var kick_read_failure_flinch_pending := false


func reset() -> void:
	_reset_approach_decision()


# 이번 상승 구간에서 킥 읽기 실패가 새로 확정됐는지 1회성으로 소비한다.
# 보스 흠칫(반응 둔화) 연출 트리거 전용.
func consume_kick_read_failure_flinch() -> bool:
	if not kick_read_failure_flinch_pending:
		return false
	kick_read_failure_flinch_pending = false
	return true


func predict_future_x(
	ball_pos: Vector2,
	ball_vel: Vector2,
	fps_scale: float,
	play_left: float,
	play_right: float,
	boss_paddle_width: float,
	context: Dictionary = {}
) -> float:
	var effective_ball_vel: Vector2 = ball_vel * float(context.get("ball_impact_boost", 1.0))
	var predict_frame: float = _get_predict_frames(effective_ball_vel)
	# 인자 play_left/right는 '공 반사 경계'(홀로그램 기만 프레임은 분신의
	# 시각 여백으로 좁혀 들어온다). 보스 '목표 중심' 클램프는 컨텍스트의
	# 전역 play 경계 기준 — 반사 경계로 클램프하면 보스 목표 범위까지
	# 좁아진다. 일반 경로는 둘이 같아 동작 불변.
	var clamp_play_left: float = float(context.get("play_left", play_left))
	var clamp_play_right: float = float(context.get("play_right", play_right))
	var min_center: float = clamp_play_left + boss_paddle_width * 0.5
	var max_center: float = clamp_play_right - boss_paddle_width * 0.5
	var future_x: float = _predict_arrival_x(ball_pos, ball_vel, predict_frame, play_left, play_right, context, fps_scale)
	if ball_vel.y >= -0.001:
		_reset_approach_decision()
		return clamp(future_x, min_center, max_center)
	_observe_kick_read_event(context, boss_paddle_width, ball_pos, ball_vel, fps_scale, future_x)
	if kick_read_failure_active:
		return _apply_kick_read_failure(future_x, min_center, max_center, context)
	if not approach_decision_active:
		_roll_approach_decision(effective_ball_vel, context)
	future_x = _apply_approach_prediction_error(future_x)
	return clamp(future_x, min_center, max_center)


func predict_exact_arrival_x(
	ball_pos: Vector2,
	ball_vel: Vector2,
	play_left: float,
	play_right: float,
	boss_paddle_width: float,
	context: Dictionary = {},
	fps_scale: float = 1.0
) -> float:
	var effective_ball_vel: Vector2 = ball_vel * float(context.get("ball_impact_boost", 1.0))
	var predict_frame: float = _get_predict_frames(effective_ball_vel)
	# 반사 경계(인자)와 보스 목표 클램프(전역) 분리 — predict_future_x와
	# 동일한 계약.
	var clamp_play_left: float = float(context.get("play_left", play_left))
	var clamp_play_right: float = float(context.get("play_right", play_right))
	var min_center: float = clamp_play_left + boss_paddle_width * 0.5
	var max_center: float = clamp_play_right - boss_paddle_width * 0.5
	var future_x: float = _predict_arrival_x(ball_pos, ball_vel, predict_frame, play_left, play_right, context, fps_scale)
	return clamp(future_x, min_center, max_center)


func _apply_approach_prediction_error(future_x: float) -> float:
	if approach_mistake_active:
		return future_x + boss_fail_error_offset
	if randf() > BOSS_ACCURACY:
		return future_x + randf_range(-BOSS_ACCURACY_ERROR, BOSS_ACCURACY_ERROR)
	return future_x


# 쉐도우 백스텝 / 마샬 킥이 공을 때린 '그 1회'에 대해서만 도는 읽기 판정.
#
# 왜 별도 굴림인가: 일반 실수 굴림(_roll_approach_decision)은 상승 접근이 시작될
# 때 딱 한 번만 돌고, 극한/초월 리그의 오차 상한(80px / 20px)은 보스 패들 반폭 +
# 여유(72.8px / 76.8px)보다 작거나 비슷해서 사실상 전부 막힌다. 킥 계열 무공이
# 킥강화 없이는 무의미해지는 원인이라, 두 무공에만 '완전히 비켜나는' 판정을 준다.
#
# 두 번째 역할: 킥은 이미 상승 중인 공의 궤도를 새로 쓴다(쉐도우 → 마샬 연계,
# 마샬 → 더블마샬). 그런데 approach_decision_active가 이미 true라 기존 코드는
# 새 궤도에 대해 아무 판정도 다시 하지 않았다 — 이벤트가 오면 접근 판정 자체를
# 무효화해서 리그 공통으로 '킥마다 새로 읽는다'가 되게 한다.
func _observe_kick_read_event(
	context: Dictionary,
	boss_paddle_width: float,
	ball_pos: Vector2,
	ball_vel: Vector2,
	fps_scale: float,
	arrival_x: float
) -> void:
	var event_id: int = int(context.get("viper_kick_read_event_id", 0))
	if event_id == kick_read_event_id:
		return
	# 생산자 id는 라운드를 넘어서도 되감기지 않는 단조 serial이다. 차이가 곧
	# '내가 못 본 사이 들어온 킥 수' — 보스가 대쉬/스턴/프리즈 조기 return에
	# 걸려 있는 동안 연계 타격이 여러 번 들어오면 2 이상이 된다.
	var pending: int = event_id - kick_read_event_id
	kick_read_event_id = event_id
	if event_id <= 0 or pending <= 0:
		# pending <= 0 = 생산자가 새로 만들어진 경우. 재동기화만 하고 굴리지 않는다.
		return
	var chance: float = clamp(float(context.get("boss_kick_read_failure_chance", 0.0)), 0.0, 1.0)
	if bool(context.get("viper_kick_read_event_chained", false)):
		chance = clamp(chance + max(0.0, float(context.get("boss_kick_read_failure_chain_bonus", 0.0))), 0.0, 1.0)
	if chance <= 0.0:
		# 별도 판정이 없는 리그(주니어 / 챔피언)에서는 완전 no-op이어야 한다.
		# 여기서 접근 판정을 건드리면 일반 실수 굴림이 킥마다 추가로 돌아
		# "전역 실수율은 건드리지 않는다"는 계약이 깨진다.
		return
	# 새 타격은 궤도를 새로 쓴다 — 이전 킥의 읽기 실패 래치는 무효.
	kick_read_failure_active = false
	kick_read_failure_offset = 0.0
	var miss_threshold: float = (
		boss_paddle_width * 0.5
		+ float(context.get("hitbox_padding", 5.0))
		+ float(context.get("ball_size", 28.6)) * 0.5
	)
	# ⚠️도달 가능성 게이트. 목표만 어긋나게 잡는 것으로는 미스가 보장되지 않는다 —
	# 보스가 이미 정답 위치에 있고 접촉까지 남은 프레임이 짧으면, 잘못된 목표를
	# 향해 움직여도 히트박스를 벗어나기 전에 공이 닿는다(실측: 리드 6프레임에서
	# 100% 차단). 그런 킥은 애초에 '읽기 기회'가 아니므로 굴림을 소비하지 않는다.
	# 이 게이트가 있어야 표시 확률 = 실제 미스 확률이 된다.
	if not _can_kick_read_failure_clear_the_boss(context, ball_pos, ball_vel, fps_scale, miss_threshold):
		return
	var rolled_failure := false
	for _roll_index in range(mini(pending, KICK_READ_MAX_PENDING_ROLLS)):
		if randf() < chance:
			rolled_failure = true
			break
	if not rolled_failure:
		return
	# 이 킥의 판정은 확정 — 같은 상승 구간에서 일반 실수 굴림이 덮어쓰지 못하게 잠근다.
	approach_decision_active = true
	kick_read_failure_active = true
	kick_read_failure_flinch_pending = true
	var magnitude: float = miss_threshold + randf_range(KICK_READ_FAILURE_MISS_MARGIN_MIN, KICK_READ_FAILURE_MISS_MARGIN_MAX)
	kick_read_failure_offset = magnitude * _pick_kick_read_evasion_dir(context, arrival_x)


# 회피 방향은 무작위가 아니라 **보스의 현 위치에서 멀어지는 쪽**이다. 무작위로
# 잡으면 반대편에 있던 보스가 도착점을 관통해 지나가다가 접촉 프레임에 걸릴 수
# 있다. 보스 위치를 모르면(컨텍스트 미제공) 무작위로 떨어진다.
func _pick_kick_read_evasion_dir(context: Dictionary, arrival_x: float) -> float:
	var boss_center_x: float = float(context.get("boss_center_x", INF))
	if is_finite(boss_center_x):
		var delta: float = boss_center_x - arrival_x
		if absf(delta) > 1.0:
			return -1.0 if delta < 0.0 else 1.0
	return -1.0 if randf() < 0.5 else 1.0


# 접촉까지 남은 프레임 동안 보스가 '정답 위치에서 히트박스를 완전히 벗어날 만큼'
# 움직일 수 있는가. 흠칫 창(반응 0.4배)까지 포함해 적분한다 — 흠칫은 회피를
# 늦추므로 게이트가 그 비용을 모르면 게이트가 거짓말을 한다.
func _can_kick_read_failure_clear_the_boss(
	context: Dictionary,
	ball_pos: Vector2,
	ball_vel: Vector2,
	fps_scale: float,
	miss_threshold: float
) -> bool:
	var frames_to_contact: float = _get_frames_to_boss_line(context, ball_pos, ball_vel)
	if frames_to_contact <= 0.0:
		return false
	var required: float = miss_threshold + KICK_READ_FAILURE_MISS_MARGIN_MAX
	return _get_boss_reachable_distance(context, frames_to_contact, fps_scale) >= required


# ball_vel은 60fps 프레임당 px라 이 몫이 곧 60fps 프레임 수다(fps_scale 곱 금지).
func _get_frames_to_boss_line(context: Dictionary, ball_pos: Vector2, ball_vel: Vector2) -> float:
	var descent_speed: float = absf(ball_vel.y) * max(0.01, float(context.get("ball_impact_boost", 1.0)))
	if descent_speed <= 0.001:
		return 0.0
	return (ball_pos.y - _get_boss_intercept_y(context)) / descent_speed


func _get_boss_reachable_distance(context: Dictionary, frames: float, fps_scale: float) -> float:
	var accel: float = max(0.0001, float(context.get("boss_movement_accel", 1.2)))
	var max_speed: float = max(0.0001, float(context.get("boss_movement_max_speed", 9.5)))
	var whole_frames: int = mini(KICK_READ_REACH_SIM_MAX_FRAMES, int(floorf(frames / max(0.01, fps_scale))))
	var distance := 0.0
	var speed := 0.0
	var elapsed := 0.0
	for _frame_index in range(whole_frames):
		var mult: float = KICK_READ_FLINCH_REACTION_MULT if elapsed < KICK_READ_FLINCH_FRAMES else 1.0
		speed = minf(speed + accel * mult * fps_scale, max_speed * mult)
		distance += speed * fps_scale
		elapsed += fps_scale
	return distance


# 굴림 시점에 정한 방향이 벽 쪽이라 목표 클램프에 먹히면(도착 x가 벽에 가까울 때)
# 오프셋이 통째로 사라져 보스가 그대로 막는다 — 클램프 후 실제 분리 거리를 보고
# 반대 방향으로 뒤집는다. 양쪽 다 먹히면 더 멀어지는 쪽을 쓴다(최선 노력).
func _apply_kick_read_failure(future_x: float, min_center: float, max_center: float, context: Dictionary) -> float:
	var magnitude: float = absf(kick_read_failure_offset)
	var preferred_dir: float = -1.0 if kick_read_failure_offset < 0.0 else 1.0
	# ⚠️목표가 보스를 **안쪽으로 끌어당기면 안 된다**. 이미 회피 방향으로 magnitude
	# 보다 멀리 있는 보스에게 고정 오프셋 목표를 주면 보스가 공 쪽으로 되돌아오고,
	# 도착 프레임에 임계선(72.8px)에 0.1px 차이로 걸쳐 그대로 막는 사례가 나온다
	# (실측 21/756). 매 프레임 현재 위치로 재평가해 '나가는 방향'으로만 작동시킨다.
	var boss_center_x: float = float(context.get("boss_center_x", INF))
	if is_finite(boss_center_x):
		magnitude = maxf(magnitude, (boss_center_x - future_x) * preferred_dir)
	var preferred: float = clamp(future_x + preferred_dir * magnitude, min_center, max_center)
	if absf(preferred - future_x) >= magnitude - 0.001:
		return preferred
	var opposite: float = clamp(future_x - preferred_dir * magnitude, min_center, max_center)
	if absf(opposite - future_x) > absf(preferred - future_x):
		return opposite
	return preferred


func _roll_approach_decision(ball_vel: Vector2, context: Dictionary) -> void:
	approach_decision_active = true
	approach_mistake_active = false
	boss_fail_error_offset = 0.0
	var mistake_chance: float = clamp(float(context.get("boss_mistake_chance", BOSS_MISTAKE_CHANCE)), 0.0, 1.0)
	var junior_power_smash_active: bool = _is_junior_power_smash_active(context)
	if junior_power_smash_active:
		mistake_chance = max(mistake_chance, JUNIOR_POWER_SMASH_MISTAKE_CHANCE)
	elif bool(context.get("power_smashing_parabola_active", false)) and int(context.get("power_smashing_combo_consumed", 0)) >= 3:
		mistake_chance *= 0.5
	if randf() < mistake_chance:
		var current_speed: float = ball_vel.length()
		var mistake_error_min: float = JUNIOR_POWER_SMASH_MISTAKE_ERROR_MIN if junior_power_smash_active else BOSS_MISTAKE_ERROR_MIN
		var mistake_error_max: float = JUNIOR_POWER_SMASH_MISTAKE_ERROR_MAX if junior_power_smash_active else BOSS_MISTAKE_ERROR_MAX
		var mistake_speed_scale: float = JUNIOR_POWER_SMASH_MISTAKE_SPEED_SCALE if junior_power_smash_active else BOSS_MISTAKE_SPEED_SCALE
		if not junior_power_smash_active:
			mistake_error_min = max(0.0, float(context.get("boss_mistake_error_min", BOSS_MISTAKE_ERROR_MIN)))
			mistake_error_max = max(0.0, float(context.get("boss_mistake_error_max", BOSS_MISTAKE_ERROR_MAX)))
			mistake_speed_scale = max(0.0, float(context.get("boss_mistake_speed_scale", BOSS_MISTAKE_SPEED_SCALE)))
			mistake_error_max = max(mistake_error_min, mistake_error_max)
		var mistake_magnitude: float = min(
			mistake_error_max,
			max(mistake_error_min, current_speed * mistake_speed_scale)
		)
		var mistake_direction := -1.0 if randf() < 0.5 else 1.0
		approach_mistake_active = true
		boss_fail_error_offset = mistake_direction * mistake_magnitude


func _reset_approach_decision() -> void:
	approach_decision_active = false
	approach_mistake_active = false
	boss_fail_error_offset = 0.0
	# 읽기 실패는 '그 상승 구간 1회'짜리다. 하강 전환 / 라운드 리셋에서 함께 풀린다.
	# 대기 중인 흠칫 신호는 여기서 지우지 않는다 — 소비는 boss_ai_state가 같은
	# 프레임에 하고, 굴림 성공 프레임에 곧바로 이 함수가 다시 불릴 일은 없다.
	kick_read_failure_active = false
	kick_read_failure_offset = 0.0


func _get_predict_frames(ball_vel: Vector2) -> float:
	var ball_speed: float = abs(ball_vel.x) + abs(ball_vel.y)
	if ball_speed > BOSS_FAST_BALL_SPEED:
		return BOSS_FAST_PREDICT_FRAMES
	if ball_speed > BOSS_MEDIUM_BALL_SPEED:
		return BOSS_MEDIUM_PREDICT_FRAMES
	return BOSS_SLOW_PREDICT_FRAMES


func _is_junior_power_smash_active(context: Dictionary) -> bool:
	return (
		bool(context.get("power_smashing_parabola_active", false))
		and _normalize_league_mode(str(context.get("ai_mode", "champion"))) == "junior"
	)


func _normalize_league_mode(ai_mode: String) -> String:
	return BattleSceneConfig.normalize_league_mode(ai_mode)


func _predict_arrival_x(
	ball_pos: Vector2,
	ball_vel: Vector2,
	fallback_frames: float,
	play_left: float,
	play_right: float,
	context: Dictionary,
	fps_scale: float = 1.0
) -> float:
	if ball_vel.y >= -0.001:
		var effective_vx: float = ball_vel.x * float(context.get("ball_impact_boost", 1.0))
		return _predict_x_with_walls(ball_pos.x, effective_vx, fallback_frames, play_left, play_right)
	return _predict_x_until_boss_line(ball_pos, ball_vel, play_left, play_right, context, fps_scale)


func _predict_x_until_boss_line(
	ball_pos: Vector2,
	ball_vel: Vector2,
	play_left: float,
	play_right: float,
	context: Dictionary,
	fps_scale: float = 1.0
) -> float:
	var target_y: float = _get_boss_intercept_y(context)
	if ball_pos.y <= target_y or abs(ball_vel.y) < 0.001:
		return clamp(ball_pos.x, play_left, play_right)

	var predicted_pos: Vector2 = ball_pos
	var impact_boost: float = float(context.get("ball_impact_boost", 1.0))
	var min_boost: float = float(context.get("ball_min_boost", 0.70))
	var decay_rate: float = clamp(float(context.get("ball_boost_decay_rate", 0.975)), 0.01, 0.9999)
	# 홀로그램 기만 프레임 옵트인: 분신은 벽 반사 후 반전된 vel.x를 유지한
	# 채 raw velocity(부스트 계약 무력화 = boost/decay 상수)로 직진하므로,
	# 도착 프레임 수를 닫힌형으로 구하고 최초 signed vx × 총 프레임을
	# 삼각파 modulo로 접으면 O(1) exact arrival이다 — 프레임 컷도 반사
	# 횟수 제한도 없고, 물리 hot path에서 프레임당 Dictionary 할당(얕은
	# 궤적 기준 틱당 최대 1200회)도 발생하지 않는다. 실 공 경로(플래그
	# 부재)는 기존 근사(매 프레임 원래 vx)를 그대로 유지해 회귀가 없다.
	if bool(context.get("prediction_reflect_velocity", false)):
		# 실 분신은 vel × fps_scale로 이동한다(72Hz 기본 = 5/6) — 명목
		# 프레임으로 계산하면 live scale에서 parity가 깨진다. 정수-tick
		# 판정까지 미러: ticks = ceil(거리 / (하강분×fps_scale)),
		# dx = vx × fps_scale × ticks.
		var descent_per_tick: float = -ball_vel.y * impact_boost * max(0.0001, fps_scale)
		if descent_per_tick <= 0.0005:
			return clamp(ball_pos.x, play_left, play_right)
		var ticks_to_intercept: float = ceilf((ball_pos.y - target_y) / descent_per_tick)
		return _predict_x_reflected_modulo(
			ball_pos.x,
			ball_vel.x * impact_boost * max(0.0001, fps_scale) * ticks_to_intercept,
			play_left,
			play_right
		)
	for _frame_index in range(PREDICTION_SIMULATION_MAX_FRAMES):
		var move: Vector2 = ball_vel * impact_boost
		predicted_pos.x = _advance_x_with_walls(predicted_pos.x, move.x, play_left, play_right)
		predicted_pos.y += move.y
		if predicted_pos.y <= target_y:
			return clamp(predicted_pos.x, play_left, play_right)
		if impact_boost > min_boost:
			impact_boost = max(impact_boost * decay_rate, min_boost)
	return _predict_x_with_walls(
		ball_pos.x,
		ball_vel.x * float(context.get("ball_impact_boost", 1.0)),
		float(PREDICTION_SIMULATION_MAX_FRAMES),
		play_left,
		play_right
	)


func _get_boss_intercept_y(context: Dictionary) -> float:
	return (
		float(context.get("boss_y", 25.0))
		+ float(context.get("boss_hitbox_height", 40.0))
		+ float(context.get("hitbox_padding", 5.0))
		+ float(context.get("ball_size", 28.6)) * 0.5
	)


# 총 이동량을 삼각파 modulo로 접어 반사 횟수 제한 없이 정확한 최종 x를
# 돌려준다 — 홀로그램 기만 예측의 극단(초장거리 이동) 안전망.
func _predict_x_reflected_modulo(x: float, total_dx: float, play_left: float, play_right: float) -> float:
	var span: float = play_right - play_left
	if span <= 0.001:
		return clamp(x, play_left, play_right)
	var period: float = span * 2.0
	var phase: float = fposmod(clamp(x, play_left, play_right) - play_left + total_dx, period)
	if phase <= span:
		return play_left + phase
	return play_left + (period - phase)


func _advance_x_with_walls(x: float, dx: float, play_left: float, play_right: float) -> float:
	if abs(dx) < 0.001:
		return clamp(x, play_left, play_right)

	var remaining: float = dx
	var predicted_x: float = clamp(x, play_left, play_right)
	for _bounce_index in range(WALL_REFLECTION_LIMIT):
		var next_x: float = predicted_x + remaining
		if next_x >= play_left and next_x <= play_right:
			return next_x
		if next_x > play_right:
			remaining = -(next_x - play_right)
			predicted_x = play_right
		else:
			remaining = play_left - next_x
			predicted_x = play_left
	return clamp(predicted_x + remaining, play_left, play_right)


func _predict_x_with_walls(x: float, vx: float, frames: float, play_left: float, play_right: float) -> float:
	if abs(vx) < 0.001 or frames <= 0.0:
		return clamp(x, play_left, play_right)

	var remaining: float = frames
	var predicted_x: float = clamp(x, play_left, play_right)
	var predicted_vx: float = vx
	for _bounce_index in range(WALL_REFLECTION_LIMIT):
		if remaining <= 0.0:
			break

		var time_to_wall: float = INF
		if predicted_vx > 0.0:
			time_to_wall = (play_right - predicted_x) / predicted_vx
		elif predicted_vx < 0.0:
			time_to_wall = (play_left - predicted_x) / predicted_vx

		if time_to_wall <= 0.0 or time_to_wall >= remaining:
			predicted_x += predicted_vx * remaining
			remaining = 0.0
			break

		predicted_x += predicted_vx * time_to_wall
		remaining -= time_to_wall
		predicted_vx = -predicted_vx

	return clamp(predicted_x, play_left, play_right)
