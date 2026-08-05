extends SceneTree

# 천뢰격(power_smashing) 콤보 소모 공속 계약 씰.
#
# 원본(pingfighter.py 186090-186092): 무콤보 발동은 속도 부스트가 25% 감소한다
# ("콤보 쌓아야 본래 성능 도달"). 이 페널티(POWER_SMASH_NO_COMBO_BOOST_MULT=0.75)가
# 1.0으로 평탄화되면 순항(target_speed)이 콤보 유무와 무관하게 동일해지고, 발사
# 캡(2.14x/2.40x)이 버스트를 양쪽 다 포화시켜 0.5초 버스트 외에는 "콤보를 모아
# 쏘나 그냥 쏘나 공속이 같은" 회귀가 된다. 이 스모크는 실제 핸들러 경로로 발사해
# 순항 target과 감쇄 이후 실측 순항 속도가 실제로 갈라지는 OUTCOME을 봉인한다.
#
# 반증검증(in-place 토글 — git reset/checkout/stash 금지):
#  - POWER_SMASH_NO_COMBO_BOOST_MULT := 0.75 → 1.0 임시 토글 시
#    cruise-target / measured-cruise 두 레그가 모두 FAIL해야 한다.

const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const PaddleBouncePowerHitHandler := preload("res://scripts/ball/paddle_bounce_power_hit_handler.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")

# ball_update_static_config.POWER_SMASH_{GRAVITY_EFFECT,BOOST_DURATION}
const POWER_SMASH_GRAVITY_EFFECT := 0.035
const POWER_SMASH_BOOST_DURATION := 0.50
const CRUISE_FRAMES := 40
# 통상 랠리의 하강 공속(중간 랠리). 캡 회피용 인위적 저속/고속을 쓰지 않는다.
const INCOMING_SPEED := 9.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_combo_split_cruise_target()
	_verify_combo_split_measured_cruise()
	_verify_no_combo_still_accelerates()

	if _failures.is_empty():
		print("smasher_power_smash_combo_speed_split_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _launch(combo_consumed: int) -> Dictionary:
	# 모션 경로의 chaos randf가 비교를 흔들지 않도록 두 발사가 같은 시드를 쓴다.
	seed(20260805)
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(0, 0.0, combo_consumed, 0.0, false, 0, 0.0)
	# freeze_duration 0 → 즉시 발사 프레임(파라볼라 시작)으로 진입. 이후
	# apply_motion이 실제 감쇄 경로(step_motion → _apply_initial_boost)를 탄다.
	power_state.update_freeze(1.0, 0.0)
	var physics: Object = BallPhysics.new()
	physics.configure_context(1, "champion")
	var handler: Object = PaddleBouncePowerHitHandler.new()
	var velocity: Vector2 = handler.apply(
		Vector2(380.0, 700.0),
		Vector2(0.0, -INCOMING_SPEED),
		155.0,
		true,
		power_state,
		physics,
		{
			"ai_mode": "champion",
			"player_pos": Vector2(302.5, 700.0),
			"paddle_width": 155.0,
			"base_ball_speed": BallPhysics.BALL_BASE_SPEED,
			"combo_min_count": 2,
			"ball_size": 28.6,
		},
		0.0
	)
	return {
		"launch_vel": velocity,
		"target_speed": float(power_state.runtime_state.get_target_speed()),
		"power_state": power_state,
	}


func _simulate_cruise_speed(power_state: Object, launch_vel: Vector2) -> float:
	# 초기부스트 창(0.5s=30프레임)을 넘겨 감쇄가 끝난 실측 순항 속도를 밟는다.
	var vel: Vector2 = launch_vel
	for _i in range(CRUISE_FRAMES):
		vel = power_state.apply_motion(
			vel,
			1.0,
			POWER_SMASH_GRAVITY_EFFECT,
			POWER_SMASH_BOOST_DURATION
		)
	return vel.length()


func _verify_combo_split_cruise_target() -> void:
	var combo: Dictionary = _launch(5)
	var plain: Dictionary = _launch(1)
	var combo_target: float = float(combo["target_speed"])
	var plain_target: float = float(plain["target_speed"])
	_expect(combo_target > 0.0 and plain_target > 0.0, "both launches should seed a target speed")
	_expect(
		combo_target > plain_target * 1.08,
		"combo power-smash cruise target should exceed the no-combo target by >8% (the no-combo penalty must reach target_speed, not only the clamped burst)"
	)


func _verify_combo_split_measured_cruise() -> void:
	var combo: Dictionary = _launch(5)
	var plain: Dictionary = _launch(1)
	var combo_cruise: float = _simulate_cruise_speed(combo["power_state"], combo["launch_vel"])
	var plain_cruise: float = _simulate_cruise_speed(plain["power_state"], plain["launch_vel"])
	_expect(combo_cruise > 0.0 and plain_cruise > 0.0, "cruise simulation should produce speed")
	_expect(
		combo_cruise > plain_cruise * 1.06,
		"after the 0.5s initial-boost decay the combo cruise speed must stay >6% above the no-combo cruise (felt speed split)"
	)


func _verify_no_combo_still_accelerates() -> void:
	# 과너프 가드(대조군): 무콤보 천뢰격도 여전히 타격 시점 공속보다는 빨라야 한다.
	var plain: Dictionary = _launch(1)
	_expect(
		float(plain["target_speed"]) > INCOMING_SPEED,
		"no-combo power smash must still accelerate the ball above the incoming speed"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
