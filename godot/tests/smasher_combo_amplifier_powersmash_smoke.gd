extends SceneTree

# Smasher 콤보증폭칩 — 파워스매시 증폭 OUTCOME 스모크.
# 베이스(콤보 속도 + 초기부스트 감쇄)는 이미 포팅됨. 이 스모크는 칩 레벨이
#  (a) 콤보 발사 공속을 (1+smash_speed_amp)로 올리고,
#  (b) 초기부스트 감쇄를 완만하게 해(D1=Option A) 부스트 속도를 더 오래 유지하는지
# OUTCOME으로 검증한다.
#
# 반증검증(수동 in-place 토글 — git reset/checkout/stash 금지):
#  - hit_velocity_resolver의 (1.0+smash_speed_amp) 제거 → _verify_chip_raises_launch_speed FAIL
#  - motion_resolver의 max(0.5,1.0-Lv*0.10) 제거 → _verify_chip_softens_decay FAIL

const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const PaddleBouncePowerHitHandler := preload("res://scripts/ball/paddle_bounce_power_hit_handler.gd")
const PowerSmashMotionResolver := preload("res://scripts/characters/smasher_power_smash_motion_resolver.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_chip_raises_launch_speed()
	_verify_no_combo_ignores_amp()
	_verify_chip_softens_decay()
	_verify_decay_lv0_baseline_unchanged()

	if _failures.is_empty():
		print("smasher_combo_amplifier_powersmash_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _launch_speed(combo_consumed: int, smash_speed_amp: float) -> float:
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(0, 0.0, combo_consumed, 0.0, false, 0, 0.0)
	var physics: Object = BallPhysics.new()
	physics.configure_context(1, "champion")
	var handler: Object = PaddleBouncePowerHitHandler.new()
	# 실제 런타임 조건: base_ball_speed = BALL_BASE_SPEED, 빠른 강하 공(콤보 랠리).
	# 일부러 큰 base로 캡을 회피하지 않는다 — 그러면 마스킹(고정 캡)을 못 잡는다(실측:
	# base=7.65에서 amp가 캡에 막혀 Lv0==Lv5==18.389이던 회귀).
	var velocity: Vector2 = handler.apply(
		Vector2(380.0, 700.0),
		Vector2(0.0, -16.0),
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
		smash_speed_amp
	)
	return velocity.length()


func _verify_chip_raises_launch_speed() -> void:
	# combo_consumed=3(>=2) → 콤보 부스트 활성. Lv5 smash amp = 5*0.45 = 2.25.
	# 실제 BALL_BASE_SPEED 조건에서 검증 — 고정 콤보 발사 캡이 amp를 마스킹하면
	# (캡 미완화) Lv0==Lv5가 되어 이 단언이 FAIL한다(반증검증 대상).
	var lv0: float = _launch_speed(3, 0.0)
	var lv5: float = _launch_speed(3, 2.25)
	_expect(lv0 > 0.0, "baseline power-smash launch should produce speed")
	_expect(
		lv5 > lv0 * 1.05,
		"Lv5 chip should raise combo power-smash launch speed >5%% vs Lv0 at BALL_BASE_SPEED (cap must scale with amp)"
	)


func _verify_no_combo_ignores_amp() -> void:
	# combo_consumed=1(<2) → 콤보 부스트 비활성 → smash amp 무관(동일해야).
	var lv0: float = _launch_speed(1, 0.0)
	var lv5: float = _launch_speed(1, 2.25)
	_expect(
		is_equal_approx(lv0, lv5),
		"below combo_min_count the smash amp must NOT change launch speed"
	)


# _apply_initial_boost가 호출하는 건 get_target_speed/get_boosted_speed 뿐 →
# 최소 덕타이핑 스텁으로 감쇄 공식만 결정론적으로 격리(randf 없음).
class _FakeBoostState:
	var _target: float
	var _boosted: float
	func _init(target: float, boosted: float) -> void:
		_target = target
		_boosted = boosted
	func get_target_speed() -> float:
		return _target
	func get_boosted_speed() -> float:
		return _boosted


func _decay_speed(chip_level: int) -> float:
	# target=10, boosted=16, progress=0.1/0.5=0.2에서 보간 속도 비교.
	var resolver: Object = PowerSmashMotionResolver.new()
	var fake: Object = _FakeBoostState.new(10.0, 16.0)
	var result: Vector2 = resolver._apply_initial_boost(
		fake, Vector2(0.0, -16.0), 0.1, 0.5, chip_level
	)
	return result.length()


func _verify_chip_softens_decay() -> void:
	# 감쇄가 완만 = 부스트 속도(16)를 더 오래 유지 = 보간 속도가 더 큼.
	var lv0: float = _decay_speed(0)
	var lv5: float = _decay_speed(5)
	_expect(
		lv5 > lv0 + 0.001,
		"Lv5 chip should soften initial-boost decay (higher retained speed) vs Lv0"
	)


func _verify_decay_lv0_baseline_unchanged() -> void:
	# Lv0 → Godot 베이스 감쇄(0.89024) 그대로. 16 - (16-10)*0.2*0.89024 ≈ 14.9317.
	var lv0: float = _decay_speed(0)
	var expected: float = 16.0 - (16.0 - 10.0) * 0.2 * PowerSmashMotionResolver.POWER_SMASH_INITIAL_DECAY_FACTOR
	_expect(
		is_equal_approx(lv0, expected),
		"Lv0 decay must equal the un-amped Godot baseline (0.89024), no regression"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
