extends SceneTree

# 천뢰격(power_smashing) 콤보 상향(2026-08-05 설계 결정) 씰.
#
# 계약(캐릭터 스킬 체크리스트 §3.2 2026-08-05 amendment): 콤보 소모 발동은 콤보
# 속도 보너스를 set_target_speed 이전에 곱해 순항(감쇄 후) 속도까지 올리고, 콤보
# 발사 천장은 (1+base bonus)로 완화된다. 무콤보 중화(Option C)는 불변.
# 콤보/무콤보 상태는 스모크가 주입하지 않고 실제 활성화 컨트롤러(try_activate)가
# combo_state에서 소비해 만든다 — 기준 미달이면 0, 충족이면 실 콤보가 저장되는
# 실게임 생성 경로만 사용(비생성 상태 직접 주입 금지).
#
# 반증검증(in-place 토글 — git reset/checkout/stash 금지, 2026-08-05 확인):
#  - 리졸버의 콤보 곱을 set_target_speed 뒤로 옮기면 target/실측 순항 레그 FAIL.
#  - _clamp_launch_speed의 (1+combo_base_bonus) 완화를 제거하면 발사 레그 FAIL
#    (기본 캡 비율 차 1.123 < 1.15 임계).

const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const PaddleBouncePowerHitHandler := preload("res://scripts/ball/paddle_bounce_power_hit_handler.gd")
const SmasherPowerSmashActivationController := preload("res://scripts/characters/smasher_power_smash_activation_controller.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")

# ball_update_static_config.POWER_SMASH_{GRAVITY_EFFECT,BOOST_DURATION}
const POWER_SMASH_GRAVITY_EFFECT := 0.035
const POWER_SMASH_BOOST_DURATION := 0.50
const CRUISE_FRAMES := 40
# 통상 랠리의 하강 공속. 캡 회피용 인위적 저속/고속을 쓰지 않는다.
const INCOMING_SPEED := 9.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_combo_cruise_target_split()
	_verify_combo_measured_cruise_split()
	_verify_combo_launch_split()

	if _failures.is_empty():
		print("smasher_power_smash_combo_cruise_bonus_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


class FakeInputReader:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {"action_pressed": true, "power_smash_direction": 0}


class FakeComboState:
	extends RefCounted

	var _combo: int = 0

	func _init(combo: int) -> void:
		_combo = combo

	func get_effective_combo() -> int:
		return _combo

	func reset_combo() -> void:
		_combo = 0


class FakeRoundState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false


# 실제 활성화 컨트롤러 → update_freeze 발사 → 실제 파워히트 핸들러 순서.
# combo_consumed는 컨트롤러가 combo_state에서 소비한 값만 쓴다.
func _launch(rally_combo: int) -> Dictionary:
	seed(20260805)
	var power_state: Object = SmasherPowerSmashState.new()
	var controller: Object = SmasherPowerSmashActivationController.new()
	var context: Dictionary = {
		"current_msec": 1000,
		"ball_active": true,
		"special_gauge": 500.0,
		"gauge_cost": 300.0,
		"combo_min_count": 2,
		"text_duration_frames": 0.0,
		"power_smash_freeze_duration": 0.0,
	}
	var deps: Dictionary = {
		"input_reader": FakeInputReader.new(),
		"power_state": power_state,
		"combo_state": FakeComboState.new(rally_combo),
		"round_state": FakeRoundState.new(),
	}
	var activation: Dictionary = controller.try_activate(context, deps, {})
	if not bool(activation.get("activated", false)):
		_failures.append("activation controller should activate power smash (rally_combo=%d)" % rally_combo)
		return {}
	# freeze_duration 0 → 즉시 발사 프레임(파라볼라 시작)으로 진입.
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
		"combo_consumed": int(power_state.get_combo_consumed()),
		"launch_speed": velocity.length(),
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


func _verify_combo_cruise_target_split() -> void:
	var combo: Dictionary = _launch(5)
	var plain: Dictionary = _launch(0)
	if combo.is_empty() or plain.is_empty():
		return
	_expect(int(combo["combo_consumed"]) == 5, "real activation should consume the rally combo (5)")
	_expect(int(plain["combo_consumed"]) == 0, "below-threshold rally combo should store 0 through the real controller")
	_expect(
		float(combo["target_speed"]) > float(plain["target_speed"]) * 1.05,
		"combo bonus must reach cruise target_speed (>5% split vs no-combo)"
	)


func _verify_combo_measured_cruise_split() -> void:
	var combo: Dictionary = _launch(5)
	var plain: Dictionary = _launch(0)
	if combo.is_empty() or plain.is_empty():
		return
	var combo_cruise: float = _simulate_cruise_speed(combo["power_state"], combo["launch_vel"])
	var plain_cruise: float = _simulate_cruise_speed(plain["power_state"], plain["launch_vel"])
	_expect(combo_cruise > 0.0 and plain_cruise > 0.0, "cruise simulation should produce speed")
	_expect(
		combo_cruise > plain_cruise * 1.04,
		"after the 0.5s initial-boost decay the combo cruise speed must stay >4% above no-combo"
	)


func _verify_combo_launch_split() -> void:
	var combo: Dictionary = _launch(5)
	var plain: Dictionary = _launch(0)
	if combo.is_empty() or plain.is_empty():
		return
	# 1.15 임계: 기본 캡 비율 차(2.4037/2.1403=1.123)만으로는 통과 불가 —
	# (1+base bonus) 천장 완화가 실제로 걸려야만 넘는 값(기대 ~1.197).
	_expect(
		float(combo["launch_speed"]) > float(plain["launch_speed"]) * 1.15,
		"combo launch ceiling must scale with the base combo bonus (>15% launch split at real BALL_BASE_SPEED)"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
