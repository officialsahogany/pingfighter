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
const PowerSmashMotionController := preload("res://scripts/characters/smasher_power_smash_motion_controller.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")

var _failures: Array[String] = []


func _init() -> void:
	var conversion_was_enabled := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	_verify_chip_raises_launch_speed()
	_verify_no_combo_ignores_amp()
	_verify_chip_softens_decay()
	_verify_polish_amplifies_smash_and_decay_outcomes()
	_verify_motion_controller_passes_effective_decay_value()
	_verify_decay_lv0_baseline_unchanged()
	PerkConversionFlags.debug_set_enabled(conversion_was_enabled)

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


func _decay_speed(decay_reduction: float) -> float:
	# target=10, boosted=16, progress=0.1/0.5=0.2에서 보간 속도 비교.
	var resolver: Object = PowerSmashMotionResolver.new()
	var fake: Object = _FakeBoostState.new(10.0, 16.0)
	var result: Vector2 = resolver._apply_initial_boost(
		fake, Vector2(0.0, -16.0), 0.1, 0.5, decay_reduction
	)
	return result.length()


func _verify_chip_softens_decay() -> void:
	# 감쇄가 완만 = 부스트 속도(16)를 더 오래 유지 = 보간 속도가 더 큼.
	var lv0: float = _decay_speed(0)
	var lv5: float = _decay_speed(0.50)
	_expect(
		lv5 > lv0 + 0.001,
		"Lv5 chip should soften initial-boost decay (higher retained speed) vs Lv0"
	)


func _make_perk_state(polish_level: int) -> Object:
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels["combo_amplifier_chip"] = 1
	if polish_level > 0:
		state.runtime_skill_levels["item_polish"] = polish_level
	return state


func _verify_polish_amplifies_smash_and_decay_outcomes() -> void:
	var base_bonus: Dictionary = _make_perk_state(0).get_combo_amplifier_chip_bonus()
	var polished_bonus: Dictionary = _make_perk_state(1).get_combo_amplifier_chip_bonus()
	var base_launch := _launch_speed(3, float(base_bonus["smash_speed"]))
	var polished_launch := _launch_speed(3, float(polished_bonus["smash_speed"]))
	_expect(
		polished_launch > base_launch + 0.001,
		"item_polish should increase the production power-smash launch outcome"
	)
	var base_decay := _decay_speed(float(base_bonus["initial_boost_decay_reduction"]))
	var polished_decay := _decay_speed(float(polished_bonus["initial_boost_decay_reduction"]))
	_expect(
		polished_decay > base_decay + 0.001,
		"item_polish should increase the production initial-boost retention outcome"
	)


class _MotionCapturePowerState:
	var received_decay_reduction := -1.0

	func apply_motion(
		ball_velocity: Vector2,
		_fps_scale: float,
		_gravity_effect: float,
		_boost_duration: float,
		decay_reduction: float
	) -> Vector2:
		received_decay_reduction = decay_reduction
		return ball_velocity


func _verify_motion_controller_passes_effective_decay_value() -> void:
	var polished_state: Object = _make_perk_state(1)
	var expected := float(
		polished_state.get_combo_amplifier_chip_bonus()["initial_boost_decay_reduction"]
	)
	var power_state := _MotionCapturePowerState.new()
	var controller: Object = PowerSmashMotionController.new()
	controller.apply_motion(
		Vector2(0.0, -16.0),
		1.0,
		{"gravity_effect": 0.0, "boost_duration": 0.5},
		{"power_state": power_state, "runtime_perk_state": polished_state}
	)
	_expect(
		is_equal_approx(power_state.received_decay_reduction, expected),
		"power-smash motion controller should pass the Polish-amplified decay value"
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
