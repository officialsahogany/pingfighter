extends SceneTree

# Smasher 콤보증폭칩 — 드라이브 증폭 OUTCOME 스모크.
# 베이스 콤보 스케일링은 이미 포팅돼 있고(smasher_drive_initial_bounce_resolver),
# 이 스모크는 칩 레벨이 콤보 비례 항(공속 bypass / 스핀 / 스핀캡)을 (1+amp)로
# 실제로 증폭하는지 OUTCOME(발사 공속·스핀)으로 검증한다.
#
# 반증검증(수동, in-place Edit 토글 — git reset/checkout/stash 금지):
#  resolver의 (1.0 + combo_amp_speed) / (1.0 + combo_amp_curve)를 제거하면
	#  S3 ceiling==Lv0이 되어 _verify_chip_raises_drive_speed / _spin 이 FAIL해야 한다.

const SmasherDriveInitialBounceResolver := preload("res://scripts/characters/smasher_drive_initial_bounce_resolver.gd")
const SmasherDriveActivationController := preload("res://scripts/characters/smasher_drive_activation_controller.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")

const _SEED := 987654321
const _COMBO := 2          # 작은 콤보: 발사 속도 캡(미증폭)에 막히지 않게
const _BASE_SPEED := 8.0

var _failures: Array[String] = []


func _init() -> void:
	var conversion_was_enabled := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	_verify_bonus_helper_values()
	_verify_polish_amplifies_all_runtime_lanes()
	_verify_drive_controller_passes_effective_values()
	_verify_curve_lane_caps_at_lv3()
	_verify_chip_raises_drive_speed()
	_verify_chip_raises_drive_spin()
	_verify_lv0_is_noop()
	PerkConversionFlags.debug_set_enabled(conversion_was_enabled)

	if _failures.is_empty():
		print("smasher_combo_amplifier_drive_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_perk_state(level: int, polish_level: int = 0) -> Object:
	var rps: Object = RuntimePerkState.new()
	if level > 0:
		rps.runtime_skill_levels["combo_amplifier_chip"] = level
	if polish_level > 0:
		rps.runtime_skill_levels["item_polish"] = polish_level
	return rps


func _amp(level: int, polish_level: int = 0) -> Dictionary:
	return _make_perk_state(level, polish_level).get_combo_amplifier_chip_bonus()


func _apply_drive(amp_speed: float, amp_curve: float) -> Dictionary:
	# 동일 seed로 resolver 내부 randf_range(base 배율)를 고정 → amp만 차이가 되게.
	seed(_SEED)
	var resolver: Object = SmasherDriveInitialBounceResolver.new()
	return resolver.apply(
		_BASE_SPEED, 0.0, -1, _COMBO, 1.0, null, 2, 0.0, amp_speed, amp_curve
	)


func _verify_bonus_helper_values() -> void:
	var lv0: Dictionary = _amp(0)
	_expect(
		is_equal_approx(float(lv0["drive_speed"]), 0.0)
			and is_equal_approx(float(lv0["drive_curve"]), 0.0)
			and is_equal_approx(float(lv0["smash_speed"]), 0.0)
			and is_equal_approx(float(lv0["initial_boost_decay_reduction"]), 0.0),
		"Lv0 chip bonus should be all zero"
	)
	var lv1: Dictionary = _amp(1)
	_expect(is_equal_approx(float(lv1["drive_speed"]), 1.125), "S3 Lv1 drive_speed should be +112.5%")
	_expect(is_equal_approx(float(lv1["drive_curve"]), 0.0375), "S3 Lv1 drive_curve should be +3.75%")
	_expect(is_equal_approx(float(lv1["smash_speed"]), 0.5625), "S3 Lv1 smash_speed should be +56.25%")
	_expect(
		is_equal_approx(float(lv1["initial_boost_decay_reduction"]), 0.125),
		"S3 Lv1 initial boost decay reduction should be 12.5%"
	)
	var lv3: Dictionary = _amp(3)
	_expect(is_equal_approx(float(lv3["drive_speed"]), 4.50), "S3 Lv3 drive_speed should preserve the +450% ceiling")
	_expect(is_equal_approx(float(lv3["smash_speed"]), 2.25), "S3 Lv3 smash_speed should preserve the +225% ceiling")


func _verify_polish_amplifies_all_runtime_lanes() -> void:
	var base_state: Object = _make_perk_state(1, 0)
	var polished_state: Object = _make_perk_state(1, 1)
	var base: Dictionary = base_state.get_combo_amplifier_chip_bonus()
	var polished: Dictionary = polished_state.get_combo_amplifier_chip_bonus()
	print(
		"Z5_COMBO_POLISH base=%s polished=%s multiplier=%.6f levels=%s" % [
			base,
			polished,
			float(polished_state.get_perk_amplify_multiplier("combo_amplifier_chip")),
			polished_state.get_effective_runtime_skill_levels(),
		]
	)
	var expected_multiplier := 1.0625
	for key in [
		"drive_speed",
		"drive_curve",
		"smash_speed",
		"initial_boost_decay_reduction",
	]:
		_expect(
			is_equal_approx(float(polished[key]), float(base[key]) * expected_multiplier),
			"item_polish Lv1 should amplify combo_amplifier_chip runtime lane %s" % key
		)
	var base_drive := _apply_drive(float(base["drive_speed"]), float(base["drive_curve"]))
	var polished_drive := _apply_drive(
		float(polished["drive_speed"]),
		float(polished["drive_curve"])
	)
	_expect(
		float(polished_drive["speed"]) > float(base_drive["speed"]) + 0.001,
		"item_polish should increase the production drive launch outcome"
	)
	_expect(
		float(polished_drive["spin_strength"]) > float(base_drive["spin_strength"]) + 0.00001,
		"item_polish should increase the production drive curve outcome"
	)


class _ReadyRoundState:
	func is_waiting_for_serve() -> bool:
		return false


class _DriveInputState:
	func is_frame_cooldown_blocked() -> bool:
		return false
	func consume_direction(_gameplay_frame: int) -> int:
		return -1
	func trigger_frame_cooldowns(_perfect_frames: float, _global_frames: float) -> void:
		pass


class _ComboState:
	func get_effective_combo() -> int:
		return 2
	func reset_combo() -> void:
		pass


class _DriveBounceCapture:
	var received_speed_amp := -1.0
	var received_curve_amp := -1.0
	func apply_initial_bounce(
		speed: float,
		_angle_rad: float,
		direction: int,
		_combo: int,
		_accel_scale: float,
		_ball_physics: Object,
		_combo_min_count: int,
		text_duration_frames: float,
		speed_amp: float,
		curve_amp: float
	) -> Dictionary:
		received_speed_amp = speed_amp
		received_curve_amp = curve_amp
		return {
			"speed": speed,
			"angle_rad": 0.0,
			"spin_strength": 0.0,
			"spin_direction": direction,
			"speed_increase": 0.0,
			"text_timer_frames": text_duration_frames,
			"consume_combo": false,
		}


func _verify_drive_controller_passes_effective_values() -> void:
	var polished_state: Object = _make_perk_state(1, 1)
	var expected: Dictionary = polished_state.get_combo_amplifier_chip_bonus()
	var capture := _DriveBounceCapture.new()
	var controller: Object = SmasherDriveActivationController.new()
	controller.try_activate(
		_BASE_SPEED,
		0.0,
		0.0,
		1.0,
		100,
		{"ball_active": true, "special_gauge": 10.0, "gauge_cost": 1.0},
		{
			"round_state": _ReadyRoundState.new(),
			"drive_input_state": _DriveInputState.new(),
			"drive_bounce_state": capture,
			"combo_state": _ComboState.new(),
			"runtime_perk_state": polished_state,
		}
	)
	_expect(
		is_equal_approx(capture.received_speed_amp, float(expected["drive_speed"])),
		"drive activation controller should pass the Polish-amplified speed value"
	)
	_expect(
		is_equal_approx(capture.received_curve_amp, float(expected["drive_curve"])),
		"drive activation controller should pass the Polish-amplified curve value"
	)


func _verify_curve_lane_caps_at_lv3() -> void:
	# 공속/스매시는 계속 스케일, 커브만 Lv3에서 하드캡(+15%).
	var lv3: Dictionary = _amp(3)
	var lv4: Dictionary = _amp(4)
	var lv5: Dictionary = _amp(5)
	_expect(is_equal_approx(float(lv3["drive_curve"]), 0.15), "Lv3 drive_curve should be +15% (cap)")
	_expect(is_equal_approx(float(lv4["drive_curve"]), 0.15), "Lv4 drive_curve should stay +15% (Lv3 cap)")
	_expect(is_equal_approx(float(lv5["drive_curve"]), 0.15), "Lv5 drive_curve should stay +15% (Lv3 cap)")
	_expect(
		float(lv5["drive_speed"]) > float(lv3["drive_speed"]) + 0.001,
		"drive_speed lane should keep scaling past Lv3 (no curve cap)"
	)


func _verify_chip_raises_drive_speed() -> void:
	var lv0: Dictionary = _apply_drive(0.0, 0.0)
	var amp5: Dictionary = _amp(5)
	var lv5: Dictionary = _apply_drive(float(amp5["drive_speed"]), float(amp5["drive_curve"]))
	_expect(
		float(lv5["speed"]) > float(lv0["speed"]) + 0.001,
		"Lv5 chip should raise drive launch speed vs Lv0 (combo speed bypass amped)"
	)


func _verify_chip_raises_drive_spin() -> void:
	var lv0: Dictionary = _apply_drive(0.0, 0.0)
	var amp5: Dictionary = _amp(5)
	var lv5: Dictionary = _apply_drive(float(amp5["drive_speed"]), float(amp5["drive_curve"]))
	_expect(
		float(lv5["spin_strength"]) > float(lv0["spin_strength"]) + 0.001,
		"Lv5 chip should raise drive spin_strength vs Lv0 (combo spin amped)"
	)


func _verify_lv0_is_noop() -> void:
	# amp 0 → 기존 base 값 그대로(회귀 가드). 명시 0,0 호출과 amp 인자 생략(default)이 동일해야.
	var explicit_zero: Dictionary = _apply_drive(0.0, 0.0)
	seed(_SEED)
	var resolver: Object = SmasherDriveInitialBounceResolver.new()
	var defaults: Dictionary = resolver.apply(_BASE_SPEED, 0.0, -1, _COMBO, 1.0, null, 2, 0.0)
	_expect(
		is_equal_approx(float(explicit_zero["speed"]), float(defaults["speed"]))
			and is_equal_approx(float(explicit_zero["spin_strength"]), float(defaults["spin_strength"])),
		"amp 0.0 must be a true no-op (equal to no-amp default call)"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
